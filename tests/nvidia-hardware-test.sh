#!/bin/bash
# Test of the NVIDIA fix on a real PC with an NVIDIA GPU (the unit test fakes
# one: tests/nvidia-test.sh). Run from the Steamify checkout:
#   bash tests/nvidia-hardware-test.sh check    read-only: what is detected, what the live kernel uses, what apply would change
#   bash tests/nvidia-hardware-test.sh apply    really applies the fix (sudo), then reboot and run check again
#   bash tests/nvidia-hardware-test.sh visual   after trying gaming mode: was the picture clean? (asks you)
# Every run appends to ~/steamify-nvidia-report.txt: paste that file when asking for help.
cd "$(dirname "$0")/.." || exit 1
# patch_file (lib/common.sh) reads the hook script from $SCRIPT_DIR/patches.
SCRIPT_DIR="$PWD"
REPORT="${NVIDIA_REPORT:-$HOME/steamify-nvidia-report.txt}"
source lib/common.sh; source lib/hdmi-refresh.sh; source lib/vram-booster.sh; source lib/nvidia.sh
mode="${1:-check}"
fail=0
say() { echo "$*" | tee -a "$REPORT"; }
pass() { say "PASS $*"; }
bad()  { say "FAIL $*"; fail=1; }
note() { say "     $*"; }
root_cat() { cat "$1" 2>/dev/null || sudo cat "$1" 2>/dev/null || echo "(unreadable)"; }

say ""; say "===== $(date '+%F %T')  mode=$mode  kernel=$(uname -r)"

report_system() {
    say "-- GPU and software"
    lspci -nn 2>/dev/null | grep -iE 'vga|3d|display' | while read -r l; do note "$l"; done
    command -v nvidia-smi >/dev/null && note "driver: $(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>&1 | head -n 1)"
    for p in nvidia-open nvidia-utils nvidia-dkms gamescope gamescope-session-cachyos linux-cachyos-nvidia-open; do
        v="$(pacman -Q "$p" 2>/dev/null)" && note "$v"
    done
    note "boot loader file: $(nvidia_boot_file || true)"
    note "cmdline: $(cat /proc/cmdline)"
}

check_state() {
    say "-- Steamify's view"
    if nvidia_present; then pass "a supported NVIDIA GPU (RTX 20 series or newer) with its driver is detected"
    elif nvidia_legacy_gpu; then bad "the NVIDIA GPU is older than RTX 20 (on chwd's legacy lists in $VRAM_CHWD_IDS): the fix is not applied"
    else bad "no NVIDIA GPU with its driver detected: the fix does nothing here"; fi
    for c in /sys/class/drm/card[0-9]*/device; do
        [[ "$(cat "$c/vendor" 2>/dev/null)" == 0x10de ]] && note "NVIDIA PCI device id $(cat "$c/device") $(vram_nvidia_legacy_id "$(cat "$c/device")" && echo '(on a chwd legacy list)' || echo '(not on a legacy list: RTX 20 or newer)')"
    done
    ls "$VRAM_CHWD_IDS"/nvidia-*.ids >/dev/null 2>&1 || note "no chwd legacy lists found: every NVIDIA card counts as supported"
    local p
    for p in $NVIDIA_PARAMS; do
        if grep -qw -- "$p" /proc/cmdline; then pass "$p is on the running kernel's command line"
        elif nvidia_param_set "$p"; then bad "$p is in the boot loader's file but not booted yet: reboot"
        else bad "$p is missing (run: bash tests/nvidia-hardware-test.sh apply)"; fi
    done
    say "-- the live NVIDIA driver"
    local m
    for m in modeset fbdev; do
        v="$(root_cat /sys/module/nvidia_drm/parameters/$m)"
        if [[ "$v" == Y ]]; then pass "nvidia_drm $m = Y"; else bad "nvidia_drm $m = $v (want Y)"; fi
    done
    lsmod | grep -q '^nvidia_drm' && pass "nvidia_drm is loaded" || bad "nvidia_drm is not loaded"
    local c found=0
    for c in /sys/class/drm/card[0-9]*/device; do
        [[ "$(cat "$c/vendor" 2>/dev/null)" == 0x10de ]] || continue
        found=1; note "NVIDIA card: ${c%/device} driver=$(basename "$(readlink -f "$c/driver" 2>/dev/null)")"
        for s in "${c%/device}"/card*-*/status; do [[ -f "$s" ]] && note "  $(basename "$(dirname "$s")"): $(cat "$s")"; done
    done
    [[ $found == 1 ]] || bad "no NVIDIA card in /sys/class/drm"
    say "-- initramfs"
    if nvidia_modules_everywhere; then note "every installed kernel has nvidia_drm: the early-load drop-in is used"
    else note "not every installed kernel has nvidia_drm: the early-load drop-in is skipped (parameters still apply)"; fi
    nvidia_initramfs_ok && note "NVIDIA modules are in the initramfs config" || note "NVIDIA modules are not in the initramfs config"
    say "-- what apply would change"
    if nvidia_params_missing; then note "adds $NVIDIA_PARAMS to $(nvidia_boot_file)"; else note "kernel parameters: nothing to change"; fi
    if ! nvidia_initramfs_ok && nvidia_modules_everywhere; then note "writes $NVIDIA_INITRAMFS_CONF"; fi
}

case "$mode" in
    check)
        report_system; check_state ;;
    apply)
        report_system
        say "-- applying"
        if nvidia_enable 2>&1 | tee -a "$REPORT"; [[ ${PIPESTATUS[0]} == 0 ]]; then pass "nvidia_enable finished"
        else bad "nvidia_enable failed (output above)"; fi
        say "Now reboot, then run: bash tests/nvidia-hardware-test.sh check" ;;
    visual)
        report_system
        say "-- try gaming mode now (log in to it or reboot into it), look at the screen, then answer"
        read -rp "Is the gaming mode picture clean (no corruption, no flicker)? [y/n/partly] " a
        read -rp "What did you see (one line, e.g. 'garbled colours at start, fine after login')? " what
        say "visual result: $a: $what"
        [[ "$a" == y ]] && pass "picture clean" || bad "picture not clean ($a)"
        say "-- gamescope and NVIDIA lines from this boot's log"
        { journalctl -b --no-pager 2>/dev/null || sudo journalctl -b --no-pager 2>/dev/null; } |
            grep -iE 'gamescope|nvidia|drm|nvrm|wlserver|vulkan' | tail -n 80 | tee -a "$REPORT" | tail -n 5
        note "(more in $REPORT)" ;;
    *) echo "usage: $0 check|apply|visual"; exit 2 ;;
esac
say ""; say "Report: $REPORT"
exit $fail
