#!/bin/bash
# "Power-off fix" menu item (poweroff), a sub-option of Steam Machine support
# ticked along with it (opt-out): the Steam Machine powers off instead of
# booting up again. Recent kernels (7.2, and the 6.x, 7.0 and 7.1 updates
# that got the change backported) keep the S4/S5 wake bit the firmware
# leaves set on GPIO pin 18 ("pinctrl-amd: Don't clear S4 wake bits at
# probe"), so the machine starts again right after powering off (the reason
# for the old kernel pin). Valve's kernel clears it at probe on Fremont, in
# a patch not meant for upstream, so CachyOS won't get it. A small module
# (patches/steamify-fremont-poweroff.c) clears it right before power-off;
# DKMS builds it for each installed kernel. On a kernel that clears it
# itself it does nothing.
# Sourced by steamify.sh; not meant to be run on its own.

POWEROFF_DKMS_NAME=steamify-fremont-poweroff
POWEROFF_DKMS_VER=1
POWEROFF_DKMS_SRC="/usr/src/$POWEROFF_DKMS_NAME-$POWEROFF_DKMS_VER"
POWEROFF_MODULES_LOAD=/etc/modules-load.d/steamify-fremont-poweroff.conf

poweroff_fix_installed() { [[ -f "$POWEROFF_DKMS_SRC/dkms.conf" && -f "$POWEROFF_MODULES_LOAD" ]]; }

poweroff_fix_enable() {
    detect_valve_fremont || return 0
    local tmp k
    if ! pacman -Q dkms >/dev/null 2>&1; then
        sudo pacman -S --needed --noconfirm dkms || { err "Installing dkms failed."; return 1; }
    fi
    install_kernel_headers || return 1
    tmp="$(mktemp -d)"
    patch_file "$POWEROFF_DKMS_NAME.c" > "$tmp/$POWEROFF_DKMS_NAME.c"
    echo "obj-m += $POWEROFF_DKMS_NAME.o" >"$tmp/Makefile"
    printf '%s\n' "# Written by Steamify: the Steam Machine powers off instead of booting up again." \
        "PACKAGE_NAME=\"$POWEROFF_DKMS_NAME\"" "PACKAGE_VERSION=\"$POWEROFF_DKMS_VER\"" \
        "BUILT_MODULE_NAME[0]=\"$POWEROFF_DKMS_NAME\"" 'DEST_MODULE_LOCATION[0]="/updates/dkms"' \
        'AUTOINSTALL="yes"' >"$tmp/dkms.conf"
    sudo dkms remove "$POWEROFF_DKMS_NAME/$POWEROFF_DKMS_VER" --all >/dev/null 2>&1
    sudo rm -rf "$POWEROFF_DKMS_SRC"
    sudo install -d "$POWEROFF_DKMS_SRC" &&
        sudo install -m644 "$tmp"/{"$POWEROFF_DKMS_NAME.c",Makefile,dkms.conf} "$POWEROFF_DKMS_SRC/"
    rm -rf "$tmp"
    sudo dkms add "$POWEROFF_DKMS_NAME/$POWEROFF_DKMS_VER" >/dev/null ||
        { err "Adding the power-off fix to DKMS failed."; return 1; }
    for k in /usr/lib/modules/*/build; do
        k="$(basename "$(dirname "$k")")"
        info "Building the power-off fix for $k..."
        sudo dkms install "$POWEROFF_DKMS_NAME/$POWEROFF_DKMS_VER" -k "$k" >/dev/null ||
            warn "Building the power-off fix for $k failed; with that kernel it may start again after shutting down."
    done
    echo "$POWEROFF_DKMS_NAME" | sudo tee "$POWEROFF_MODULES_LOAD" >/dev/null
    sudo modprobe "$POWEROFF_DKMS_NAME" 2>/dev/null
    return 0
}

poweroff_fix_disable() {
    sudo rm -f "$POWEROFF_MODULES_LOAD"
    sudo modprobe -r "$POWEROFF_DKMS_NAME" 2>/dev/null
    [[ -d "$POWEROFF_DKMS_SRC" ]] || return 0
    sudo dkms remove "$POWEROFF_DKMS_NAME/$POWEROFF_DKMS_VER" --all >/dev/null 2>&1
    sudo rm -rf "$POWEROFF_DKMS_SRC"
}

poweroff_status() { poweroff_fix_installed; }
poweroff_enable() {
    info "Installing the power-off fix (the machine stays off after shutting down)..."
    poweroff_fix_enable || { err "Installing the power-off fix failed."; return 1; }
    ok "Power-off fix on: the Steam Machine stays off after shutting down."
}
poweroff_disable() {
    poweroff_fix_disable
    ok "Power-off fix removed; with recent kernels the Steam Machine may start again after shutting down."
}
