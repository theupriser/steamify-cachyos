#!/bin/bash
# Tests lib/nvidia.sh against a fake RTX 5080 (PCI 10de:2c02) beside an
# Intel iGPU, a stub modinfo, and temp copies of the boot loader files. No
# root, VM or NVIDIA hardware needed: bash tests/nvidia-test.sh
cd "$(dirname "$0")/.." || exit 1
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

SCRIPT_DIR="$PWD"; source lib/common.sh; source lib/hdmi-refresh.sh; source lib/nvidia.sh
sudo() { "$@"; }
info() { :; }; ok() { :; }; warn() { :; }; err() { echo "ERR $*"; }
backup_file() { [[ -f "$1.bak" ]] || cp "$1" "$1.bak"; }
modinfo() { [[ "$FAKE_DRIVER" == 1 ]]; }
REBUILDS=0; nvidia_rebuild_boot() { REBUILDS=$((REBUILDS + 1)); }
NVIDIA_INITRAMFS_CONF="$T/90-steamify-nvidia.conf"
mkdir -p "$T/drm/card0/device" "$T/drm/card1/device"
echo 0x8086 > "$T/drm/card0/device/vendor"; echo 0x030000 > "$T/drm/card0/device/class"
echo 0x10de > "$T/drm/card1/device/vendor"; echo 0x030000 > "$T/drm/card1/device/class"
echo 0x2c02 > "$T/drm/card1/device/device"
NVIDIA_DRM_DIR="$T/drm"
mkdir -p "$T/mods/6.1.0-cachyos/kernel"; : > "$T/mods/6.1.0-cachyos/kernel/nvidia-drm.ko.zst"; : > "$T/mods/6.1.0-cachyos/pkgbase"
NVIDIA_SCRIPT="$T/libexec/steamify-nvidia-initramfs"; NVIDIA_HOOK="$T/hooks/85-steamify-nvidia-initramfs.hook"
NVIDIA_MODULES_DIR="$T/mods"
NVIDIA_LIMINE_CONF="$T/none/limine.conf"; NVIDIA_SDBOOT_DIR="$T/none/entries"; NVIDIA_GRUB_CFG="$T/none/grub.cfg"   # not generated here: not checked

FAKE_DRIVER=1; check "finds the NVIDIA card as card1 beside an iGPU" nvidia_present
FAKE_DRIVER=0; check "skips when the driver isn't installed" '! nvidia_present'
FAKE_DRIVER=1; NVIDIA_DRM_DIR="$T/none"; check "skips without an NVIDIA GPU" '! nvidia_present'
NVIDIA_DRM_DIR="$T/drm"

for loader in limine sdboot grub; do
    case $loader in
        limine) F="$T/limine"; printf 'KERNEL_CMDLINE[default]="quiet splash"\n' > "$F" ;;
        sdboot) F="$T/sdboot-manage.conf"; printf 'LINUX_OPTIONS="quiet splash"\n' > "$F" ;;
        grub)   F="$T/grub";   printf 'GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"\n' > "$F" ;;
    esac
    nvidia_boot_file() { echo "$F"; }
    rm -f "$NVIDIA_INITRAMFS_CONF"; REBUILDS=0; ORIG="$(cat "$F")"
    nvidia_enable
    check "$loader: parameters added" 'grep -q "nvidia-drm.modeset=1" "$F" && grep -q "nvidia-drm.fbdev=1" "$F"'
    check "$loader: initramfs drop-in written" 'grep -q nvidia_drm "$NVIDIA_INITRAMFS_CONF"'
    check "$loader: script and pacman hook installed" '[[ -x "$NVIDIA_SCRIPT" ]] && grep -q "^Exec = $NVIDIA_SCRIPT sync" "$NVIDIA_HOOK"'
    check "$loader: backup made, rebuilt once" '[[ -f "$F.bak" && $REBUILDS == 1 ]]'
    SUM="$(cat "$F")"; nvidia_enable
    check "$loader: second run changes nothing" '[[ "$(cat "$F")" == "$SUM" && $REBUILDS == 1 ]]'
    nvidia_disable
    check "$loader: disable restores the file, drops the drop-in, script and hook" '[[ "$(cat "$F")" == "$ORIG" && ! -f "$NVIDIA_INITRAMFS_CONF" && ! -e "$NVIDIA_SCRIPT" && ! -e "$NVIDIA_HOOK" ]]'
done

# The pacman hook's script decides again at every kernel change.
syncit() { NVIDIA_INITRAMFS_CONF="$NVIDIA_INITRAMFS_CONF" NVIDIA_MODULES_DIR="$NVIDIA_MODULES_DIR" bash "$NVIDIA_SCRIPT" sync; }
nvidia_hook_install; rm -f "$NVIDIA_INITRAMFS_CONF"
syncit; check "hook script: every kernel has the modules -> drop-in written" '[[ -f "$NVIDIA_INITRAMFS_CONF" ]]'
mkdir -p "$T/mods/6.6.0-lts/kernel"; : > "$T/mods/6.6.0-lts/pkgbase"
syncit; check "hook script: a new kernel without modules -> drop-in removed" '[[ ! -f "$NVIDIA_INITRAMFS_CONF" ]]'
: > "$T/mods/6.6.0-lts/kernel/nvidia-drm.ko.zst"
syncit; check "hook script: the modules arrive (DKMS built) -> drop-in back" '[[ -f "$NVIDIA_INITRAMFS_CONF" ]]'
rm -rf "$T/mods/6.6.0-lts"; mkdir -p "$T/mods/5.0.0-leftover"; : > "$T/mods/5.0.0-leftover/modules.dep"
syncit; check "hook script: a leftover folder of a removed kernel is ignored" '[[ -f "$NVIDIA_INITRAMFS_CONF" ]]'
rm -rf "$T/mods/5.0.0-leftover"; nvidia_disable
# A second kernel without the NVIDIA modules: no early-load drop-in, parameters still set.
mkdir -p "$T/mods/6.6.0-lts/kernel"; : > "$T/mods/6.6.0-lts/pkgbase"; F="$T/sdboot-manage.conf"; printf 'LINUX_OPTIONS="quiet"\n' > "$F"
nvidia_boot_file() { echo "$F"; }; rm -f "$NVIDIA_INITRAMFS_CONF"; REBUILDS=0; nvidia_enable
check "kernel without nvidia modules: no drop-in, parameters set" '[[ ! -f "$NVIDIA_INITRAMFS_CONF" ]] && grep -q "nvidia-drm.fbdev=1" "$F"'
rm -rf "$T/mods/6.6.0-lts"
# Generated boot entries without the parameters (the initramfs build failed): an error.
printf 'linux /vmlinuz root=/dev/sda1\n' > "$T/grub.cfg"; NVIDIA_GRUB_CFG="$T/grub.cfg"
F="$T/grub"; printf 'GRUB_CMDLINE_LINUX_DEFAULT="quiet"\n' > "$F"; nvidia_boot_file() { echo "$F"; }; rm -f "$NVIDIA_INITRAMFS_CONF"
check "boot entries without the parameters: error" '! nvidia_enable >/dev/null'
NVIDIA_GRUB_CFG="$T/none/grub.cfg"
# A config file without the setting to edit: an error, not "applied".
F="$T/sdboot-manage.conf"; printf '#LINUX_OPTIONS=""\n' > "$F"; nvidia_boot_file() { echo "$F"; }; REBUILDS=0
check "no setting to edit: error, nothing rebuilt" '! nvidia_enable >/dev/null && [[ $REBUILDS == 0 ]]'
FAKE_DRIVER=0; printf 'LINUX_OPTIONS="quiet"\n' > "$T/sdboot"; F="$T/sdboot"; REBUILDS=0; nvidia_enable
check "no NVIDIA driver: nothing touched" '[[ "$(cat "$F")" == "LINUX_OPTIONS=\"quiet\"" && $REBUILDS == 0 ]]'
exit $fail
