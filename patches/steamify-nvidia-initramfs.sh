#!/bin/bash
# Installed by Steamify CachyOS (SteamOS conversion, NVIDIA fix), run by the
# pacman hook steamify-nvidia-initramfs.hook before the initramfs is built.
# The NVIDIA modules go into the initramfs (early KMS) only while EVERY
# installed kernel has them: mkinitcpio fails on a module a kernel lacks, and
# limine-mkinitcpio then skips that kernel's boot entry, kernel parameters
# included. Decided again at every kernel or driver change, so a new kernel
# without the modules (another kernel, a failed DKMS build, a downgrade) gets
# a working initramfs and the file comes back once it has them.
#   steamify-nvidia-initramfs [sync|check]
#   sync   (default) write or remove the drop-in to match
#   check  exit status 0 when every installed kernel has nvidia_drm
conf="${NVIDIA_INITRAMFS_CONF:-/etc/mkinitcpio.conf.d/90-steamify-nvidia.conf}"
mods="${NVIDIA_MODULES_DIR:-/usr/lib/modules}"

everywhere() {
    local k found=0
    for k in "$mods"/*/; do
        [[ -f "$k/vmlinuz" || -f "$k/pkgbase" ]] || continue   # an installed kernel, not a leftover folder
        find "$k" -name 'nvidia-drm.ko*' -print -quit 2>/dev/null | grep -q . || return 1
        found=1
    done
    [[ $found == 1 ]]
}

case "${1:-sync}" in
    check) everywhere ;;
    sync)
        if everywhere; then
            [[ -f "$conf" ]] || { mkdir -p "$(dirname "$conf")" &&
                echo 'MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)' > "$conf"; }
        else
            rm -f "$conf"
        fi ;;
    *) echo "usage: $0 [sync|check]" >&2; exit 2 ;;
esac
