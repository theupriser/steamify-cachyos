#!/bin/bash
# "VRAM booster" menu item (vram), ticked by default, like SteamOS 3.9's
# dGPU VRAM management: the game in front keeps its VRAM, background apps
# are evicted first, so a game that needs most of it doesn't spill into
# system RAM and stutter. The kernel side is the dmem cgroup controller
# (7.2; amdgpu and xe register their VRAM, NVIDIA's driver doesn't), so it's
# only offered when the kernel lists a VRAM region of at least 2 GB. CachyOS packages the userspace
# side: dmemcg-booster (a system service that enables the controller and
# sets the limits, plus a user service) and plasma-foreground-booster, which
# tells it which window is in front on the desktop. The latter only starts
# with "autostart" set in kcgroupsrc.
# Sourced by steamify.sh; not meant to be run on its own.

VRAM_PKGS=(dmemcg-booster plasma-foreground-booster)
VRAM_MIN_BYTES=$((2 * 1024 * 1024 * 1024))

vram_supported() {
    # WIZARD_VRAM_FAKE_NVIDIA=1 (tests): as with an NVIDIA card.
    [[ -n "${WIZARD_VRAM_FAKE_NVIDIA:-}" ]] && return 1
    # Only for a GPU with its own VRAM: an integrated GPU registers a small
    # carve-out too, but mostly uses system RAM, so there's little to boost.
    awk -v min="$VRAM_MIN_BYTES" '$1 ~ /\/vram$/ && $2 >= min { found = 1 } END { exit !found }' \
        /sys/fs/cgroup/dmem.capacity 2>/dev/null
}

vram_nvidia() {
    # An NVIDIA display controller (PCI vendor 10de, class 03xxxx).
    local d
    [[ -n "${WIZARD_VRAM_FAKE_NVIDIA:-}" ]] && return 0
    for d in /sys/bus/pci/devices/*; do
        [[ "$(cat "$d/vendor" 2>/dev/null)" == 0x10de && "$(cat "$d/class" 2>/dev/null)" == 0x03* ]] && return 0
    done
    return 1
}

# Shown where it works, and greyed out with an NVIDIA card, whose driver
# doesn't register its VRAM with the kernel (yet): so it's clear why it
# can't be turned on. Hidden elsewhere (integrated graphics, older kernel).
vram_available() { vram_supported || vram_status || vram_nvidia; }
vram_selectable() { vram_supported || vram_status; }

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
