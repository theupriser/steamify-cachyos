#!/bin/bash
# "HDMI refresh boost" menu item (hdmi), retired in 2.2.0: it saved an EDID
# override per display (with a hotplug script loading it) so the pinned
# 7.1.6 kernel ran HDMI displays above 60 Hz. Newer kernels read the whole
# EDID themselves, and the kernel pin is gone with the power-off fix, so
# only its removal is left: shown while anything of it is on the system,
# always unticked, so a normal run removes it.
# Sourced by steamify.sh; not meant to be run on its own.

HDMI_FW_DIR=/usr/lib/firmware/edid
# Before 2.1.0 the override was on the kernel command line.
HDMI_INITRAMFS_CONF=/etc/mkinitcpio.conf.d/90-steamify-edid.conf
# The saved displays; their EDIDs are $HDMI_FW_DIR/steamify-<id>.bin.
HDMI_MAP=/etc/steamify/hdmi-edid.conf
HDMI_RUN=/run/steamify-edid
HDMI_HOTPLUG=/usr/local/bin/steamify-edid-hotplug
HDMI_UNIT_NAME=steamify-edid.service
HDMI_UNIT="/etc/systemd/system/$HDMI_UNIT_NAME"
HDMI_UDEV_RULE=/etc/udev/rules.d/90-steamify-edid.rules

hdmi_connectors() {
    # Connected HDMI outputs, as "<card>-<connector>" (e.g. card1-HDMI-A-1).
    local d
    for d in /sys/class/drm/card*-HDMI-A-*; do
        [[ "$(cat "$d/status" 2>/dev/null)" == connected ]] && basename "$d"
    done
}

hdmi_boot_file() {
    # The file holding the kernel command line, per boot loader.
    if [[ -f /etc/default/limine ]]; then echo /etc/default/limine
    elif [[ -f /etc/sdboot-manage.conf ]] && command -v sdboot-manage >/dev/null; then echo /etc/sdboot-manage.conf
    elif [[ -f /etc/default/grub ]]; then echo /etc/default/grub
    fi
}

hdmi_cmdline_param() {
    # The drm.edid_firmware= value we set, or nothing.
    local f; f="$(hdmi_boot_file)"
    [[ -n "$f" ]] && grep -oE 'drm\.edid_firmware=[^ "]*steamify-[^ "]*' "$f" 2>/dev/null | head -n 1
}

hdmi_available() { detect_valve_fremont && hdmi_status; }

hdmi_status() {
    # On while anything of it is left: saved displays, the hotplug script,
    # an EDID file, or the kernel parameter of versions before 2.1.0.
    [[ -s "$HDMI_MAP" || -f "$HDMI_UNIT" || -n "$(hdmi_cmdline_param)" ]] ||
        compgen -G "$HDMI_FW_DIR/steamify-*.bin" >/dev/null
}

hdmi_reset_live() {
    # Puts a connected display back on its own EDID right away. debugfs is
    # root-only, so the glob runs under sudo; the kernel takes exactly
    # "reset", without a newline.
    local d
    d="$(sudo sh -c 'for d in /sys/kernel/debug/dri/*/"$1"; do [ -e "$d/edid_override" ] && { echo "$d"; break; }; done' _ "${1#card*-}")"
    [[ -n "$d" ]] || return 1
    printf reset | sudo tee "$d/edid_override" >/dev/null &&
        echo 1 | sudo tee "$d/trigger_hotplug" >/dev/null
}

hdmi_remove_boot_param() {
    # Removes the drm.edid_firmware= older versions put on the kernel command
    # line, then rebuilds the initramfs and boot entries.
    local f
    [[ -n "$(hdmi_cmdline_param)" ]] || { sudo rm -f "$HDMI_INITRAMFS_CONF"; return 0; }
    f="$(hdmi_boot_file)"
    backup_file "$f"
    sudo sed -i -E 's/drm\.edid_firmware=[^ "]*steamify-[^ "]* ?//' "$f"
    sudo rm -f "$HDMI_INITRAMFS_CONF"
    info "Rebuilding the initramfs and boot entries..."
    case "$f" in
        /etc/default/limine) sudo limine-mkinitcpio ;;
        /etc/sdboot-manage.conf) sudo /usr/bin/mkinitcpio -P && sudo sdboot-manage gen ;;
        /etc/default/grub) sudo /usr/bin/mkinitcpio -P && sudo grub-mkconfig -o /boot/grub/grub.cfg ;;
    esac
}

hdmi_forget_all() {
    # Every saved display and the hotplug script that loaded their EDIDs.
    local conn
    sudo rm -f "$HDMI_FW_DIR"/steamify-*.bin
    sudo systemctl disable "$HDMI_UNIT_NAME" >/dev/null 2>&1
    sudo rm -f "$HDMI_UDEV_RULE" "$HDMI_UNIT" "$HDMI_HOTPLUG" "$HDMI_MAP"
    sudo rm -rf "$HDMI_RUN"
    sudo systemctl daemon-reload
    sudo udevadm control --reload
    for conn in $(hdmi_connectors); do hdmi_reset_live "$conn" 2>/dev/null; done
    return 0
}

hdmi_enable() {
    err "HDMI refresh boost is no longer offered: current kernels run HDMI displays at their full rate."
    return 1
}

hdmi_disable() {
    hdmi_forget_all
    hdmi_remove_boot_param || return 1
    state_clear hdmi
    ok "HDMI refresh boost removed; displays use their own EDID again."
}
