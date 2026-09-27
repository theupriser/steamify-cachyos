#!/bin/bash
# "VRAM booster" menu item (vram), a sub-option of Steam Machine support
# ticked along with it (opt-out), like SteamOS 3.9's dGPU VRAM management:
# the game in front keeps its VRAM, background apps are evicted first, so a
# game on the 8 GB GPU doesn't spill into system RAM and stutter. The kernel
# side is the dmem cgroup controller (7.2); CachyOS packages the userspace
# side: dmemcg-booster (a system service that enables the controller and
# sets the limits, plus a user service) and plasma-foreground-booster, which
# tells it which window is in front on the desktop. The latter only starts
# with "autostart" set in kcgroupsrc.
# Sourced by steamify.sh; not meant to be run on its own.

VRAM_PKGS=(dmemcg-booster plasma-foreground-booster)

vram_status() {
    pacman -Q "${VRAM_PKGS[@]}" >/dev/null 2>&1 &&
        systemctl is-enabled -q dmemcg-booster-system.service 2>/dev/null &&
        systemctl --user is-enabled -q dmemcg-booster-user.service 2>/dev/null
}

vram_enable() {
    local p missing=()
    info "Installing the VRAM booster (the game in front keeps its VRAM)..."
    for p in "${VRAM_PKGS[@]}"; do pacman -Q "$p" >/dev/null 2>&1 || missing+=("$p"); done
    if ((${#missing[@]})); then
        sudo pacman -S --needed --noconfirm "${missing[@]}" ||
            { err "Installing ${missing[*]} failed."; return 1; }
        state_set vram installed_pkgs "${missing[*]}"
    fi
    sudo systemctl enable --now dmemcg-booster-system.service >/dev/null 2>&1 ||
        { err "Starting dmemcg-booster failed."; return 1; }
    systemctl --user enable --now dmemcg-booster-user.service >/dev/null 2>&1 ||
        { err "Starting dmemcg-booster for $USER failed."; return 1; }
    kset vram kcgroupsrc "Foreground Booster" autostart true
    # Started by the Plasma session from now on; start it in this one too.
    [[ "${XDG_CURRENT_DESKTOP:-}" == KDE ]] &&
        systemctl --user start plasma-foreground-booster.service >/dev/null 2>&1
    ok "VRAM booster on: the game in front keeps its VRAM."
}

vram_disable() {
    local pkgs
    systemctl --user disable --now plasma-foreground-booster.service dmemcg-booster-user.service >/dev/null 2>&1
    sudo systemctl disable --now dmemcg-booster-system.service >/dev/null 2>&1
    krevert vram
    pkgs="$(state_get vram installed_pkgs)"
    # shellcheck disable=SC2086 # a list of package names
    [[ -n "$pkgs" ]] && sudo pacman -Rns --noconfirm $pkgs >/dev/null 2>&1
    state_clear vram
    ok "VRAM booster off."
}
