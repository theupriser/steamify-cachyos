#!/bin/bash
# Tests lib/controllers.sh (extended controller support: xone, the Xbox wireless dongle, and xpadneo, Xbox Bluetooth) with a stub pacman
# and a temp home. No root, VM or hardware needed: bash tests/controllers-test.sh
cd "$(dirname "$0")/.." || exit 1
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

SCRIPT_DIR="$PWD"; HOME="$T/home"; mkdir -p "$HOME"
source lib/common.sh; source lib/state.sh; source lib/controllers.sh; source lib/menu.sh
# Runs as the user, and refuses anything under the real system folders: a test must never touch them.
sudo() { local a; for a in "$@"; do case "$a" in /etc/*|/usr/*|/boot/*|/var/*) echo "REFUSED sudo $*" >&2; return 1 ;; esac; done; "$@"; }
info() { :; }; ok() { :; }; warn() { :; }; err() { echo "ERR $*"; }
kwriteconfig6() { local f="" k="" v=""; while [[ $# -gt 0 ]]; do case "$1" in --file) f="$2"; shift ;; --key) k="$2"; shift ;; --group) shift ;; *) v="$1" ;; esac; shift; done; mkdir -p "$(dirname "$f")"; sed -i "/^$k=/d" "$f" 2>/dev/null; printf '%s=%s\n' "$k" "$v" >> "$f"; }
kreadconfig6() { local f="" k=""; while [[ $# -gt 0 ]]; do case "$1" in --file) f="$2"; shift ;; --key) k="$2"; shift ;; --group|--default) shift ;; esac; shift; done; sed -n "s/^$k=//p" "$f" 2>/dev/null; }
# A pretend package database.
PKGS=""; PACMAN_LOG="$T/pacman.log"; : > "$PACMAN_LOG"; PACMAN_FAIL=0
pacman() {
    case "$1" in
        -Q) local p; for p in "${@:2}"; do [[ " $PKGS " == *" $p "* ]] || return 1; done ;;
        -S) [[ $PACMAN_FAIL == 1 ]] && return 1; echo "S ${*:4}" >> "$PACMAN_LOG"; PKGS+=" ${*:4}" ;;
        -Rns) echo "R ${*:3}" >> "$PACMAN_LOG"; local p; for p in ${*:3}; do PKGS=" ${PKGS// $p / } "; done ;;
    esac
}
HEADERS=0; install_kernel_headers() { HEADERS=$((HEADERS + 1)); }

check "off to begin with" '! extended_controller_support_status'
extended_controller_support_enable
check "installs the repo's xpadneo-dkms, xone-dkms and the dongle firmware" 'pacman -Q xpadneo-dkms xone-dkms xone-dongle-firmware'
check "kernel headers are made sure of first" '[[ $HEADERS == 1 ]]'
check "what we installed is recorded" '[[ "$(state_get extended_controller_support installed_pkgs)" == "xpadneo-dkms xone-dkms xone-dongle-firmware" ]]'
check "it is on" extended_controller_support_status
n="$(wc -l < "$PACMAN_LOG")"; extended_controller_support_enable
check "a second run installs nothing again" '[[ "$(wc -l < "$PACMAN_LOG")" == "$n" ]]'
extended_controller_support_disable
check "off: the three packages are removed again" '! pacman -Q xpadneo-dkms 2>/dev/null && ! pacman -Q xone-dkms 2>/dev/null && ! pacman -Q xone-dongle-firmware 2>/dev/null && [[ -z "$(state_get extended_controller_support installed_pkgs)" ]]'

# The AUR's xone-dkms-git conflicts with the repo's xone-dkms: it counts, and is kept.
PKGS=" xone-dkms-git xone-dongle-firmware xpadneo-dkms"; : > "$PACMAN_LOG"
check "xone-dkms-git counts as xone: already on" extended_controller_support_status
extended_controller_support_enable; extended_controller_support_disable
check "with xone-dkms-git: nothing installed and nothing removed" '[[ ! -s "$PACMAN_LOG" ]] && pacman -Q xone-dkms-git xpadneo-dkms xone-dongle-firmware'
PKGS=" xone-dkms-git"
extended_controller_support_enable
check "xone-dkms-git present: only the missing ones are installed, never xone-dkms" 'grep -q "^S xpadneo-dkms xone-dongle-firmware$" "$PACMAN_LOG" && ! pacman -Q xone-dkms 2>/dev/null'
extended_controller_support_disable
check "and off removes only those two, xone-dkms-git stays" 'pacman -Q xone-dkms-git && ! pacman -Q xpadneo-dkms 2>/dev/null'

# A failed install is an error and records nothing.
PKGS=""; PACMAN_FAIL=1
check "a failed pacman is an error" '! extended_controller_support_enable >/dev/null'
check "...and records nothing" '[[ -z "$(state_get extended_controller_support installed_pkgs)" ]]'
PACMAN_FAIL=0

# Packages that were already there are never removed by turning it off.
PKGS=" xpadneo-dkms xone-dkms xone-dongle-firmware"; : > "$PACMAN_LOG"
extended_controller_support_enable; extended_controller_support_disable
check "packages you had before stay" 'pacman -Q xpadneo-dkms xone-dkms xone-dongle-firmware && [[ ! -s "$PACMAN_LOG" ]]'

# The menu.
check "offered on every PC" 'component_available extended_controller_support'
check "not preselected: it builds kernel modules for every kernel" '[[ " ${NO_PRESELECT[*]} " == *" extended_controller_support "* ]]'
check "a top-level item with a label" '[[ -z "${PARENT[extended_controller_support]:-}" && -n "${LABEL[extended_controller_support]}" ]]'

# The "new" badge: an opt-in option added after setup shows it, but is never ticked for you.
component_selectable() { return 0; }
declare -A CURRENT=([gaming]=1 [nvidia]=0 [extended_controller_support]=0 [vram]=0 [boot]=0)
rm -f "$STATE_DIR/features.state"
check "new opt-in option (conversion on, no record): the new badge" 'feature_new_optin extended_controller_support'
check "...but it is not ticked for you (not a new default option)" '! feature_new extended_controller_support'
check "...and the menu label says (new)" '[[ "$(menu_label extended_controller_support)" == *"(new)"* ]]'
check "a new default option is still ticked for you, and is not the opt-in kind" 'feature_new vram && ! feature_new_optin vram'
check "Boot into never gets the badge (it is a choice row)" '! feature_new_optin boot'
state_set_features() { kwriteconfig6 --file "$STATE_DIR/features.state" --group State --key "$1" "$2"; }
state_set_features extended_controller_support off
check "once a run recorded it as off, the badge is gone" '! feature_new_optin extended_controller_support'
rm -f "$STATE_DIR/features.state"
CURRENT[gaming]=0; CURRENT[nvidia]=1
check "on an NVIDIA PC (Gaming on NVIDIA on, no conversion) it shows too" 'feature_new_optin extended_controller_support'
CURRENT[nvidia]=0
check "with neither the conversion nor Gaming on NVIDIA on (a fresh PC) nothing is new" '! feature_new_optin extended_controller_support && ! feature_new vram'
CURRENT[gaming]=1; CURRENT[extended_controller_support]=1
check "already on: not new" '! feature_new_optin extended_controller_support'
exit $fail
