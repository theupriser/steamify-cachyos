#!/bin/bash
# Tests lib/nvidia.sh against a fake RTX 5080 (PCI 10de:2c02) beside an
# Intel iGPU, a stub modinfo, and temp copies of the boot loader files. No
# root, VM or NVIDIA hardware needed: bash tests/nvidia-test.sh
cd "$(dirname "$0")/.." || exit 1
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

source lib/common.sh; source lib/hdmi-refresh.sh; source lib/nvidia.sh
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
mkdir -p "$T/mods/6.1.0-cachyos/kernel"; : > "$T/mods/6.1.0-cachyos/kernel/nvidia-drm.ko.zst"
NVIDIA_MODULES_DIR="$T/mods"

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
    check "$loader: backup made, rebuilt once" '[[ -f "$F.bak" && $REBUILDS == 1 ]]'
    SUM="$(cat "$F")"; nvidia_enable
    check "$loader: second run changes nothing" '[[ "$(cat "$F")" == "$SUM" && $REBUILDS == 1 ]]'
    nvidia_disable
    check "$loader: disable restores the file and drops the drop-in" '[[ "$(cat "$F")" == "$ORIG" && ! -f "$NVIDIA_INITRAMFS_CONF" ]]'
done

# A second kernel without the NVIDIA modules: no early-load drop-in, parameters still set.
mkdir -p "$T/mods/6.6.0-lts/kernel"; F="$T/sdboot-manage.conf"; printf 'LINUX_OPTIONS="quiet"\n' > "$F"
nvidia_boot_file() { echo "$F"; }; rm -f "$NVIDIA_INITRAMFS_CONF"; REBUILDS=0; nvidia_enable
check "kernel without nvidia modules: no drop-in, parameters set" '[[ ! -f "$NVIDIA_INITRAMFS_CONF" ]] && grep -q "nvidia-drm.fbdev=1" "$F"'
rm -rf "$T/mods/6.6.0-lts"
FAKE_DRIVER=0; printf 'LINUX_OPTIONS="quiet"\n' > "$T/sdboot"; F="$T/sdboot"; REBUILDS=0; nvidia_enable
check "no NVIDIA driver: nothing touched" '[[ "$(cat "$F")" == "LINUX_OPTIONS=\"quiet\"" && $REBUILDS == 0 ]]'
exit $fail
