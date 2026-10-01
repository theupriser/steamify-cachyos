#!/bin/bash
# NVIDIA fix for gaming mode, part of the SteamOS conversion
# (gaming_enable/gaming_disable). gamescope drives the display itself
# through DRM/KMS; with NVIDIA that needs kernel modesetting and the
# framebuffer driver (nvidia-drm.modeset=1 nvidia-drm.fbdev=1) and the
# driver in the initramfs, or the screen shows a corrupted image.
# Does nothing without an NVIDIA GPU that has its driver installed.
# Sourced by steamify.sh; not meant to be run on its own.

NVIDIA_PARAMS="nvidia-drm.modeset=1 nvidia-drm.fbdev=1"
NVIDIA_INITRAMFS_CONF=/etc/mkinitcpio.conf.d/90-steamify-nvidia.conf
NVIDIA_MARK="# steamify-nvidia"
# The DRM devices in sysfs; the tests point this at a fake tree.
NVIDIA_DRM_DIR=${NVIDIA_DRM_DIR:-/sys/class/drm}

nvidia_present() {
    # An NVIDIA GPU (PCI vendor 0x10de, display class) and its kernel driver.
    local d
    for d in "$NVIDIA_DRM_DIR"/card[0-9]*/device; do
        [[ "$(cat "$d/vendor" 2>/dev/null)" == 0x10de ]] || continue
        [[ "$(cat "$d/class" 2>/dev/null)" == 0x03* ]] && modinfo nvidia_drm >/dev/null 2>&1 && return 0
    done
    return 1
}

nvidia_boot_file() {
    # Same boot loaders as the kernel command line elsewhere (lib/hdmi-refresh.sh).
    hdmi_boot_file
}

nvidia_param_set() {
    # 0 when $1 (e.g. nvidia-drm.modeset=1) is on the kernel command line or
    # already in the boot loader's file (not booted yet).
    local f; f="$(nvidia_boot_file)"
    grep -qw -- "$1" /proc/cmdline 2>/dev/null ||
        { [[ -n "$f" ]] && grep -qw -- "$1" "$f" 2>/dev/null; }
}

nvidia_params_missing() {
    local p
    for p in $NVIDIA_PARAMS; do nvidia_param_set "$p" || return 0; done
    return 1
}

nvidia_initramfs_ok() {
    [[ -f "$NVIDIA_INITRAMFS_CONF" ]] || grep -qE '^MODULES=.*nvidia_drm' /etc/mkinitcpio.conf 2>/dev/null
}

nvidia_rebuild_boot() {
    local f; f="$(nvidia_boot_file)"
    info "Rebuilding the initramfs and boot entries..."
    case "$f" in
        /etc/default/limine) sudo limine-mkinitcpio ;;
        /etc/sdboot-manage.conf) sudo /usr/bin/mkinitcpio -P && sudo sdboot-manage gen ;;
        /etc/default/grub) sudo /usr/bin/mkinitcpio -P && sudo grub-mkconfig -o /boot/grub/grub.cfg ;;
        *) sudo /usr/bin/mkinitcpio -P ;;
    esac
}

nvidia_enable() {
    nvidia_present || return 0
    local f changed=0 p; f="$(nvidia_boot_file)"
    if nvidia_params_missing; then
        if [[ -z "$f" ]]; then
            warn "NVIDIA GPU found, but no supported boot loader: add '$NVIDIA_PARAMS' to the kernel command line yourself."
        else
            info "NVIDIA GPU found: adding $NVIDIA_PARAMS to the kernel command line (fixes a corrupted screen in gaming mode)..."
            backup_file "$f"
            case "$f" in
                */limine)
                    printf 'KERNEL_CMDLINE[default]+=" %s" %s\n' "$NVIDIA_PARAMS" "$NVIDIA_MARK" | sudo tee -a "$f" >/dev/null ;;
                */sdboot-manage.conf)
                    sudo sed -i -E "s/^(LINUX_OPTIONS=\"[^\"]*)\"/\1 $NVIDIA_PARAMS\"/" "$f" ;;
                */grub)
                    sudo sed -i -E "s/^(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*)\"/\1 $NVIDIA_PARAMS\"/" "$f" ;;
            esac
            changed=1
        fi
    fi
    if ! nvidia_initramfs_ok; then
        info "Loading the NVIDIA modules early (initramfs)..."
        printf 'MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)\n' |
            sudo install -Dm644 /dev/stdin "$NVIDIA_INITRAMFS_CONF" && changed=1
    fi
    if [[ $changed == 1 ]]; then
        nvidia_rebuild_boot || { err "Rebuilding the boot entries failed."; return 1; }
        ok "NVIDIA gaming mode fix applied; it takes effect after a reboot."
    fi
    return 0
}

nvidia_disable() {
    local f changed=0; f="$(nvidia_boot_file)"
    if [[ -n "$f" ]] && grep -q "$NVIDIA_PARAMS" "$f" 2>/dev/null; then
        case "$f" in
            */limine) sudo sed -i "/$NVIDIA_MARK\$/d" "$f" ;;
            *) sudo sed -i "s/ \?$NVIDIA_PARAMS//" "$f" ;;
        esac
        changed=1
    fi
    [[ -f "$NVIDIA_INITRAMFS_CONF" ]] && { sudo rm -f "$NVIDIA_INITRAMFS_CONF"; changed=1; }
    [[ $changed == 1 ]] && nvidia_rebuild_boot
    return 0
}
