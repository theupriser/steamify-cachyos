#!/bin/bash
# Tests lib/nvidia.sh ("Gaming on NVIDIA" and its Big Picture option) and the menu rules around it, against a fake RTX 5080
# (PCI 10de:2c02) beside an Intel iGPU, a stub modinfo, pacman and systemctl, and a temp home. No root, VM or NVIDIA
# hardware needed: bash tests/nvidia-test.sh
cd "$(dirname "$0")/.." || exit 1
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

SCRIPT_DIR="$PWD"; HOME="$T/home"; mkdir -p "$HOME"
source lib/common.sh; source lib/state.sh; source lib/login-manager.sh; source lib/single-user.sh; source lib/hdmi-refresh.sh; source lib/vram-booster.sh; source lib/nvidia.sh; source lib/menu.sh
# Runs as the user, and refuses anything under the real system folders: a test must never touch them.
sudo() { local a; for a in "$@"; do case "$a" in /etc/*|/usr/*|/boot/*|/var/*) echo "REFUSED sudo $*" >&2; return 1 ;; esac; done; "$@"; }
info() { :; }; ok() { :; }; warn() { :; }; err() { echo "ERR $*"; }
kwriteconfig6() { local f g k v; while [[ $# -gt 0 ]]; do case "$1" in --file) f="$2";; --key) k="$2";; esac; [[ $# -ge 2 ]] && v="$2"; shift; done; printf '%s=%s\n' "$k" "$v" > "$f"; }
kreadconfig6() { local f k; while [[ $# -gt 0 ]]; do case "$1" in --file) f="$2";; --key) k="$2";; esac; shift; done; sed -n "s/^$k=//p" "$f" 2>/dev/null; }
# A pretend package database and systemd: what the tests assert on.
PKGS=""; PACMAN_LOG="$T/pacman.log"; : > "$PACMAN_LOG"; ENABLED=0
pacman() {
    case "$1" in
        -Q) [[ " $PKGS " == *" $2 "* ]] ;;
        -S) echo "S $*" >> "$PACMAN_LOG"; PKGS+=" ${*: -1}" ;;
        -Rns) echo "R $*" >> "$PACMAN_LOG"; PKGS=" ${PKGS//${*: -1}/} " ;;
    esac
}
user_systemctl() {
    case "$1" in
        enable) ENABLED=1 ;;
        disable) ENABLED=0 ;;
        is-enabled) [[ $ENABLED == 1 ]] ;;
    esac
    return 0
}
FAKE_DRIVER=1; modinfo() { [[ "$FAKE_DRIVER" == 1 ]]; }
GAMING_ON=0; gaming_status() { [[ "$GAMING_ON" == 1 ]]; }
UNIT="$HOME/.config/systemd/user/$NVIDIA_UNIT"

mkdir -p "$T/drm/card0/device" "$T/drm/card1/device"
echo 0x8086 > "$T/drm/card0/device/vendor"; echo 0x030000 > "$T/drm/card0/device/class"
echo 0x10de > "$T/drm/card1/device/vendor"; echo 0x030000 > "$T/drm/card1/device/class"
echo 0x2c02 > "$T/drm/card1/device/device"
NVIDIA_DRM_DIR="$T/drm"
backup_file() { [[ -f "$1.bak" ]] || cp "$1" "$1.bak"; }
REBUILDS=0; nvidia_rebuild_boot() { REBUILDS=$((REBUILDS + 1)); }
: > "$T/cmdline"; NVIDIA_CMDLINE="$T/cmdline"   # the running kernel's command line: without the parameters
NVIDIA_INITRAMFS_CONF="$T/90-steamify-nvidia.conf"
NVIDIA_SCRIPT="$T/libexec/steamify-nvidia-initramfs"; NVIDIA_HOOK="$T/hooks/85-steamify-nvidia-initramfs.hook"
mkdir -p "$T/mods/6.1.0-cachyos/kernel"; : > "$T/mods/6.1.0-cachyos/kernel/nvidia-drm.ko.zst"; : > "$T/mods/6.1.0-cachyos/pkgbase"
NVIDIA_MODULES_DIR="$T/mods"
NVIDIA_LIMINE_CONF="$T/none/limine.conf"; NVIDIA_SDBOOT_DIR="$T/none/entries"; NVIDIA_GRUB_CFG="$T/none/grub.cfg"   # not generated here: not checked
mkdir -p "$T/chwd"; VRAM_CHWD_IDS="$T/chwd"
# The component's kernel step edits this boot loader file (systemd-boot's) in the tests, never a real one.
printf 'LINUX_OPTIONS="quiet"\n' > "$T/sdboot-manage.conf"; nvidia_boot_file() { echo "$T/sdboot-manage.conf"; }

# --- detection
check "finds the NVIDIA card as card1 beside an iGPU" nvidia_present
FAKE_DRIVER=0; check "no nvidia_drm module (nouveau): not an NVIDIA PC" '! nvidia_present'
FAKE_DRIVER=1; NVIDIA_DRM_DIR="$T/none"; check "no NVIDIA GPU: not an NVIDIA PC" '! nvidia_present'
NVIDIA_DRM_DIR="$T/drm"

# --- which items the menu shows
check "NVIDIA PC: the SteamOS conversion and its gamescope options are hidden" '! component_available gaming && ! component_available boot && ! component_available glyphs'
check "NVIDIA PC: Gaming on NVIDIA and Big Picture are shown" 'component_available nvidia && component_available bigpicture'
GAMING_ON=1
check "NVIDIA PC with the conversion already on: it is shown, so it can be turned off" 'component_available gaming && component_available boot'
check "...and Gaming on NVIDIA is hidden (both would start Steam)" '! component_available nvidia && ! component_available bigpicture'
GAMING_ON=0; NVIDIA_DRM_DIR="$T/none"
check "no NVIDIA: the conversion is shown as before" 'component_available gaming && component_available boot'
check "...and Gaming on NVIDIA is hidden" '! component_available nvidia && ! component_available bigpicture'
NVIDIA_DRM_DIR="$T/drm"

# --- turning it on
check "off to begin with" '! nvidia_status && ! bigpicture_status'
nvidia_enable
check "Steam is installed when missing, and recorded as ours" 'grep -q "^S " "$PACMAN_LOG" && [[ "$(state_get nvidia installed_pkgs)" == steam ]]'
check "the autostart unit is written: Steam without arguments" 'grep -q "^ExecStart=/usr/bin/steam $" "$UNIT"'
check "it is on" 'nvidia_status && ! bigpicture_status'
n="$(wc -l < "$PACMAN_LOG")"; nvidia_enable
check "a second run installs nothing again" '[[ "$(wc -l < "$PACMAN_LOG")" == "$n" ]]'

# --- Big Picture
bigpicture_enable
check "Big Picture: Steam starts with -gamepadui" 'grep -q "^ExecStart=/usr/bin/steam -gamepadui$" "$UNIT" && bigpicture_status'
nvidia_enable
check "turning Gaming on NVIDIA on again keeps Big Picture" 'bigpicture_status'
bigpicture_disable
check "Big Picture off: Steam's normal window again" '! bigpicture_status && nvidia_status'

# --- turning it off
bigpicture_enable; nvidia_disable
check "off: the unit is gone and Steam, which we installed, is removed" '! nvidia_status && [[ ! -e "$UNIT" ]] && ! pacman -Q steam && [[ -z "$(state_get nvidia installed_pkgs)" ]]'
check "Big Picture without the unit does nothing" 'bigpicture_enable && bigpicture_disable && [[ ! -e "$UNIT" ]]'

# --- Steam that was there already is never removed
PKGS=" steam"; : > "$PACMAN_LOG"
nvidia_enable; nvidia_disable
check "Steam installed before is kept, and not installed again" '[[ ! -s "$PACMAN_LOG" ]] && pacman -Q steam'

# --- kernel parameters and early modules (a supported card only: RTX 20 series or newer)
check "RTX 5080 (2c02) is supported: no chwd legacy lists" nvidia_supported
printf '1c03\n1b80\n' > "$T/chwd/nvidia-580.ids"   # a GTX 1060 and a GTX 1080: chwd's 580xx legacy list
check "RTX 5080 is not on a legacy list" 'nvidia_supported && ! nvidia_legacy_gpu'
echo 0x1c03 > "$T/drm/card1/device/device"
check "GTX 1060 (older than RTX 20): no kernel setup, but still an NVIDIA PC" '! nvidia_supported && nvidia_legacy_gpu && nvidia_present'
echo 0x2c02 > "$T/drm/card1/device/device"

for loader in limine limineplus sdboot grub; do
    case $loader in
        limine) F="$T/limine"; printf 'KERNEL_CMDLINE[default]="quiet splash"\n' > "$F" ;;
        # CachyOS writes its line as "+=" and may already have nvidia_drm.modeset=1 in it.
        limineplus) F="$T/limine"; printf 'KERNEL_CMDLINE[default]+="quiet splash nvidia_drm.modeset=1"\n' > "$F" ;;
        sdboot) F="$T/sdboot-manage.conf"; printf 'LINUX_OPTIONS="quiet splash"\n' > "$F" ;;
        grub)   F="$T/grub";   printf 'GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"\n' > "$F" ;;
    esac
    nvidia_boot_file() { echo "$F"; }
    rm -f "$NVIDIA_INITRAMFS_CONF"; REBUILDS=0; ORIG="$(cat "$F")"
    nvidia_kernel_enable
    check "$loader: parameters added" 'grep -q "nvidia-drm.modeset=1" "$F" && grep -q "nvidia-drm.fbdev=1" "$F"'
    check "$loader: initramfs drop-in written" 'grep -q nvidia_drm "$NVIDIA_INITRAMFS_CONF"'
    check "$loader: script and pacman hook installed" '[[ -x "$NVIDIA_SCRIPT" ]] && grep -q "^Exec = $NVIDIA_SCRIPT sync" "$NVIDIA_HOOK"'
    check "$loader: backup made, rebuilt once" '[[ -f "$F.bak" && $REBUILDS == 1 ]]'
    SUM="$(cat "$F")"; nvidia_kernel_enable
    check "$loader: second run changes nothing" '[[ "$(cat "$F")" == "$SUM" && $REBUILDS == 1 ]]'
    nvidia_kernel_disable
    check "$loader: disable restores the file, drops the drop-in, script and hook" '[[ "$(cat "$F")" == "$ORIG" && ! -f "$NVIDIA_INITRAMFS_CONF" && ! -e "$NVIDIA_SCRIPT" && ! -e "$NVIDIA_HOOK" ]]'
done

# A missing patches/ file must be an error, never an empty script or hook.
( SCRIPT_DIR="$T/no-patches"; NVIDIA_SCRIPT="$T/empty/script"; NVIDIA_HOOK="$T/empty/hook"; ! nvidia_hook_install 2>/dev/null && [[ ! -s "$T/empty/script" ]] ) && echo "ok   a missing patch file is an error, nothing empty installed" || { echo "FAIL a missing patch file is an error, nothing empty installed"; fail=1; }
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
rm -rf "$T/mods/5.0.0-leftover"; nvidia_kernel_disable
# A second kernel without the NVIDIA modules: no early-load drop-in, parameters still set.
mkdir -p "$T/mods/6.6.0-lts/kernel"; : > "$T/mods/6.6.0-lts/pkgbase"; F="$T/sdboot-manage.conf"; printf 'LINUX_OPTIONS="quiet"\n' > "$F"
nvidia_boot_file() { echo "$F"; }; rm -f "$NVIDIA_INITRAMFS_CONF"; REBUILDS=0; nvidia_kernel_enable
check "kernel without nvidia modules: no drop-in, parameters set" '[[ ! -f "$NVIDIA_INITRAMFS_CONF" ]] && grep -q "nvidia-drm.fbdev=1" "$F"'
rm -rf "$T/mods/6.6.0-lts"
# Generated boot entries without the parameters (the initramfs build failed): an error.
printf 'linux /vmlinuz root=/dev/sda1\n' > "$T/grub.cfg"; NVIDIA_GRUB_CFG="$T/grub.cfg"
F="$T/grub"; printf 'GRUB_CMDLINE_LINUX_DEFAULT="quiet"\n' > "$F"; nvidia_boot_file() { echo "$F"; }; rm -f "$NVIDIA_INITRAMFS_CONF"
check "boot entries without the parameters: error" '! nvidia_kernel_enable >/dev/null'
NVIDIA_GRUB_CFG="$T/none/grub.cfg"
# A config file without the setting to edit: an error, not "applied".
F="$T/sdboot-manage.conf"; printf '#LINUX_OPTIONS=""\n' > "$F"; nvidia_boot_file() { echo "$F"; }; REBUILDS=0
check "no setting to edit: error, nothing rebuilt" '! nvidia_kernel_enable >/dev/null && [[ $REBUILDS == 0 ]]'
FAKE_DRIVER=0; NVIDIA_DRM_DIR="$T/drm"; printf 'LINUX_OPTIONS="quiet"\n' > "$T/sdboot"; F="$T/sdboot"; REBUILDS=0; nvidia_kernel_enable
check "no NVIDIA driver: nothing touched" '[[ "$(cat "$F")" == "LINUX_OPTIONS=\"quiet\"" && $REBUILDS == 0 ]]'

# --- single user mode on NVIDIA: its own login step (SDDM, autologin into Plasma) without the conversion
FAKE_DRIVER=1; NVIDIA_DRM_DIR="$T/drm"   # an earlier section ended without the driver
SW="$T/switches.log"; : > "$SW"; TARGET_USER=tester; SINGLE_AUTOLOGIN="$T/sddm.conf.d/zzz-steamify-autologin.conf"
switch_to_sddm() { echo sddm >> "$SW"; }; switch_to_plasmalogin() { echo plasmalogin >> "$SW"; }
remove_sddm_base_autologin() { :; }   # would look at the real /etc/sddm.conf
GAMING_ON=0
check "single user mode is offered on NVIDIA without the conversion..." 'component_available single'
GAMING_ON=1; check "...and with it" 'component_available single'; GAMING_ON=0
single_login_enable
check "single user: SDDM, autologin of the user into the Plasma session" 'grep -qx "User=tester" "$SINGLE_AUTOLOGIN" && grep -qx "Session=plasma.desktop" "$SINGLE_AUTOLOGIN" && grep -qx "Relogin=true" "$SINGLE_AUTOLOGIN" && grep -qx sddm "$SW"'
c1="$(cat "$SINGLE_AUTOLOGIN")"; single_login_enable
check "single user login: a second run changes nothing" '[[ "$(cat "$SINGLE_AUTOLOGIN")" == "$c1" ]]'
single_login_disable
check "single user off: the file is gone and plasma-login-manager is the login manager again" '[[ ! -e "$SINGLE_AUTOLOGIN" ]] && grep -qx plasmalogin "$SW"'
: > "$SW"; GAMING_ON=1; single_login_enable
check "with the conversion on, single user mode leaves the login to it" '[[ ! -e "$SINGLE_AUTOLOGIN" && ! -s "$SW" ]]'
GAMING_ON=0
# --- the menu rules
declare -A WANTED=([nvidia]=1 [bigpicture]=1 [gaming]=0 [boot]=0 [single]=0 [machine]=0 [poweroff]=0 [launcher]=0 [steamgame]=0)
component_selectable() { return 0; }
toggle_component nvidia
check "unticking Gaming on NVIDIA unticks Big Picture" '[[ "${WANTED[nvidia]}" == 0 && "${WANTED[bigpicture]}" == 0 ]]'
toggle_component bigpicture
check "ticking Big Picture ticks Gaming on NVIDIA" '[[ "${WANTED[nvidia]}" == 1 && "${WANTED[bigpicture]}" == 1 ]]'
WANTED[single]=0; WANTED[gaming]=0; toggle_component single
check "ticking single user mode does not tick the conversion where it isn't offered" '[[ "${WANTED[single]}" == 1 && "${WANTED[gaming]}" == 0 ]]'
check "Big Picture follows Gaming on NVIDIA in the menu" '[[ " ${COMPONENTS[*]} " == *" nvidia bigpicture "* && "${PARENT[bigpicture]}" == nvidia ]]'

exit $fail
