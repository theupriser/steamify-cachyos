#!/bin/bash
# NVIDIA fix for gaming mode, part of the SteamOS conversion
# (gaming_enable/gaming_disable). gamescope drives the display itself
# through DRM/KMS; with NVIDIA that needs kernel modesetting and the
# framebuffer driver (nvidia-drm.modeset=1 nvidia-drm.fbdev=1) and the
# driver in the initramfs, or the screen shows a corrupted image.
# Does nothing without a supported NVIDIA GPU (RTX 20 series or newer) that has
# its driver installed.
# Sourced by steamify.sh; not meant to be run on its own.

NVIDIA_PARAMS="nvidia-drm.modeset=1 nvidia-drm.fbdev=1"
NVIDIA_INITRAMFS_CONF=/etc/mkinitcpio.conf.d/90-steamify-nvidia.conf
# The script and pacman hook that keep the initramfs file right at every kernel change.
NVIDIA_SCRIPT=${NVIDIA_SCRIPT:-/usr/local/libexec/steamify-nvidia-initramfs}
NVIDIA_HOOK=${NVIDIA_HOOK:-/etc/pacman.d/hooks/85-steamify-nvidia-initramfs.hook}
# The DRM devices in sysfs; the tests point this at a fake tree.
NVIDIA_DRM_DIR=${NVIDIA_DRM_DIR:-/sys/class/drm}

nvidia_present() {
    # A supported NVIDIA GPU: PCI vendor 0x10de, display class, its kernel
    # driver installed, and not older than the RTX 20 series, decided like the
    # VRAM booster does (vram_nvidia_legacy_id: chwd's legacy card lists, every
    # other card runs NVIDIA's open modules). Older cards are left alone.
    local d
    for d in "$NVIDIA_DRM_DIR"/card[0-9]*/device; do
        [[ "$(cat "$d/vendor" 2>/dev/null)" == 0x10de ]] || continue
        [[ "$(cat "$d/class" 2>/dev/null)" == 0x03* ]] || continue
        vram_nvidia_legacy_id "$(cat "$d/device" 2>/dev/null)" && continue
        modinfo nvidia_drm >/dev/null 2>&1 && return 0
    done
    return 1
}

nvidia_legacy_gpu() {
    # 0 when the only NVIDIA GPU(s) are older than RTX 20 (reported, not fixed).
    local d found=0
    for d in "$NVIDIA_DRM_DIR"/card[0-9]*/device; do
        [[ "$(cat "$d/vendor" 2>/dev/null)" == 0x10de && "$(cat "$d/class" 2>/dev/null)" == 0x03* ]] || continue
        vram_nvidia_legacy_id "$(cat "$d/device" 2>/dev/null)" || return 1
        found=1
    done
    [[ $found == 1 ]]
}

nvidia_boot_file() {
    # Same boot loaders as the kernel command line elsewhere (lib/hdmi-refresh.sh).
    hdmi_boot_file
}

nvidia_param_set() {
    # 0 when $1 (e.g. nvidia-drm.modeset=1) is on the kernel command line or
    # already in the boot loader's file (not booted yet).
    # The kernel treats "nvidia_drm" and "nvidia-drm" alike: CachyOS' own
    # setup may already have written the underscore spelling.
    local f re; f="$(nvidia_boot_file)"; re="${1//nvidia-drm/nvidia[-_]drm}"
    grep -qwE -- "$re" /proc/cmdline 2>/dev/null ||
        { [[ -n "$f" ]] && grep -qwE -- "$re" "$f" 2>/dev/null; }
}

nvidia_params_missing() {
    local p
    for p in $NVIDIA_PARAMS; do nvidia_param_set "$p" || return 0; done
    return 1
}

nvidia_initramfs_ok() {
    [[ -f "$NVIDIA_INITRAMFS_CONF" ]] || grep -qE '^MODULES=.*nvidia_drm' /etc/mkinitcpio.conf 2>/dev/null
}

nvidia_modules_everywhere() {
    # 0 when every installed kernel has the nvidia_drm module (the script's own check).
    patch_file steamify-nvidia-initramfs.sh | NVIDIA_MODULES_DIR="${NVIDIA_MODULES_DIR:-/usr/lib/modules}" bash -s check
}

nvidia_hook_install() {
    # Never installs an empty script or hook (a piped patch_file that failed
    # still lets install succeed with no input).
    local script hook
    script="$(patch_file steamify-nvidia-initramfs.sh)" && [[ -n "$script" ]] &&
        hook="$(patch_file steamify-nvidia-initramfs.hook | fill SCRIPT="$NVIDIA_SCRIPT")" && [[ -n "$hook" ]] || return 1
    printf '%s\n' "$script" | sudo install -Dm755 /dev/stdin "$NVIDIA_SCRIPT" &&
        printf '%s\n' "$hook" | sudo install -Dm644 /dev/stdin "$NVIDIA_HOOK"
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

nvidia_boot_has_params() {
    # 0 when the generated boot entries carry the parameters (or can't be
    # checked): limine.conf, systemd-boot's entries, grub.cfg.
    local target
    case "$1" in
        */limine) target="${NVIDIA_LIMINE_CONF:-/boot/limine.conf}" ;;
        */sdboot-manage.conf) target="${NVIDIA_SDBOOT_DIR:-/boot/loader/entries}" ;;
        */grub) target="${NVIDIA_GRUB_CFG:-/boot/grub/grub.cfg}" ;;
        *) return 0 ;;
    esac
    sudo test -e "$target" || return 0
    sudo grep -rqs 'nvidia-drm.modeset=1' "$target"
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
                    sudo sed -i -E "s/^(KERNEL_CMDLINE\[default\]\+?=\"[^\"]*)\"/\1 $NVIDIA_PARAMS\"/" "$f" ;;
                */sdboot-manage.conf)
                    sudo sed -i -E "s/^(LINUX_OPTIONS=\"[^\"]*)\"/\1 $NVIDIA_PARAMS\"/" "$f" ;;
                */grub)
                    sudo sed -i -E "s/^(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*)\"/\1 $NVIDIA_PARAMS\"/" "$f" ;;
            esac
            if ! grep -q "nvidia-drm.fbdev=1" "$f"; then
                err "Couldn't add the NVIDIA parameters to $f (no kernel command line setting in it): add '$NVIDIA_PARAMS' yourself."
                return 1
            fi
            changed=1
        fi
    fi
    nvidia_hook_install || { err "Installing the NVIDIA initramfs hook failed."; return 1; }
    local had=0; [[ -f "$NVIDIA_INITRAMFS_CONF" ]] && had=1
    sudo env NVIDIA_INITRAMFS_CONF="$NVIDIA_INITRAMFS_CONF" NVIDIA_MODULES_DIR="${NVIDIA_MODULES_DIR:-/usr/lib/modules}" "$NVIDIA_SCRIPT" sync
    if [[ -f "$NVIDIA_INITRAMFS_CONF" && $had == 0 ]]; then
        info "Loading the NVIDIA modules early (initramfs)..."
        changed=1
    elif [[ ! -f "$NVIDIA_INITRAMFS_CONF" && $had == 1 ]]; then
        warn "A kernel without the NVIDIA modules is installed: not loading them early any more (rebuilding the initramfs without them)."
        changed=1
    elif [[ ! -f "$NVIDIA_INITRAMFS_CONF" ]] && ! nvidia_initramfs_ok; then
        warn "Not every installed kernel has the NVIDIA modules: not loading them early for now (the kernel parameters still apply; this is checked again at every kernel update)."
    fi
    if [[ $changed == 1 ]]; then
        nvidia_rebuild_boot || { err "Rebuilding the boot entries failed."; return 1; }
        if ! nvidia_boot_has_params "$f"; then
            err "The boot entries don't have the NVIDIA parameters: the initramfs or boot entry build failed (see above)."
            return 1
        fi
        ok "NVIDIA gaming mode fix applied; it takes effect after a reboot."
    fi
    return 0
}

nvidia_disable() {
    local f changed=0; f="$(nvidia_boot_file)"
    if [[ -n "$f" ]] && grep -q "$NVIDIA_PARAMS" "$f" 2>/dev/null; then
        sudo sed -i "s/ \?$NVIDIA_PARAMS//" "$f"
        changed=1
    fi
    [[ -f "$NVIDIA_INITRAMFS_CONF" ]] && { sudo rm -f "$NVIDIA_INITRAMFS_CONF"; changed=1; }
    sudo rm -f "$NVIDIA_HOOK" "$NVIDIA_SCRIPT"
    [[ $changed == 1 ]] && nvidia_rebuild_boot
    return 0
}
