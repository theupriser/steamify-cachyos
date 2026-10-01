#!/bin/bash
# Extended controller support: the Xbox wireless dongle (xone, with its firmware) and Xbox controllers over Bluetooth (xpadneo).
# The kernel has no driver for the dongle, and without xpadneo a Bluetooth Xbox controller works as a plain gamepad (buttons and
# sticks) but misses rumble (trigger motors too), proper button mapping and the battery level. Both are DKMS modules from CachyOS's
# own repo, built for every installed kernel (so every kernel needs its headers). Sourced by steamify.sh; not meant to be run on
# its own.

controller_xone_pkg() {
    # A PC with the AUR's xone-dkms-git already works: the repo's xone-dkms would conflict with it.
    pacman -Q xone-dkms-git >/dev/null 2>&1 && echo xone-dkms-git || echo xone-dkms
}

controller_pkgs() { echo "xpadneo-dkms $(controller_xone_pkg) xone-dongle-firmware"; }

extended_controller_support_status() {
    # shellcheck disable=SC2046 # a list of package names
    pacman -Q $(controller_pkgs) >/dev/null 2>&1
}

extended_controller_support_enable() {
    local p prev missing=()
    info "Installing extended controller support (Xbox wireless dongle, Xbox Bluetooth)..."
    install_kernel_headers || return 1
    for p in $(controller_pkgs); do pacman -Q "$p" >/dev/null 2>&1 || missing+=("$p"); done
    if ((${#missing[@]})); then
        sudo pacman -S --needed --noconfirm "${missing[@]}" ||
            { err "Installing ${missing[*]} failed."; return 1; }
        # What a first, half-finished run installed stays on the list.
        prev="$(state_get extended_controller_support installed_pkgs)"
        state_set extended_controller_support installed_pkgs "$(echo "$prev ${missing[*]}" | xargs)"
    fi
    ok "Extended controller support on: plug the dongle in again (or reconnect the controller) to use it."
}

extended_controller_support_disable() {
    local pkgs
    pkgs="$(state_get extended_controller_support installed_pkgs)"
    # Only what Steamify installed; kernel headers stay.
    # shellcheck disable=SC2086 # a list of package names
    [[ -n "$pkgs" ]] && sudo pacman -Rns --noconfirm $pkgs >/dev/null 2>&1
    state_clear extended_controller_support
    ok "Extended controller support off."
}
