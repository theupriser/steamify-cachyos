#!/bin/bash
# "VRAM booster" menu item (vram), ticked by default, like SteamOS 3.9's
# dGPU VRAM management: the game in front keeps its VRAM, background apps
# are evicted first, so a game that needs most of it doesn't spill into
# system RAM and stutter. The kernel side is the dmem cgroup controller
# (7.2; amdgpu and xe register their VRAM, NVIDIA's driver doesn't), so it's
# only offered when the kernel lists a VRAM region (vram or vidmem) of at least 2 GB. CachyOS packages the userspace
# side: dmemcg-booster (a system service that enables the controller and
# sets the limits, plus a user service) and plasma-foreground-booster, which
# tells it which window is in front on the desktop. The latter only starts
# with "autostart" set in kcgroupsrc.
# Sourced by steamify.sh; not meant to be run on its own.

VRAM_PKGS=(dmemcg-booster plasma-foreground-booster)
VRAM_MIN_BYTES=$((2 * 1024 * 1024 * 1024))
# The regions the kernel's dmem controller lists (a file under /sys/fs/cgroup;
# a variable so tests can point it at a copy).
VRAM_CAPACITY="${WIZARD_VRAM_CAPACITY:-/sys/fs/cgroup/dmem.capacity}"

vram_supported() {
    # WIZARD_VRAM_FAKE_NVIDIA (tests): as with an NVIDIA card whose driver
    # doesn't register its VRAM; see vram_nvidia_case.
    [[ -n "${WIZARD_VRAM_FAKE_NVIDIA:-}" ]] && return 1
    # Only for a GPU with its own VRAM: an integrated GPU registers a small
    # carve-out too, but mostly uses system RAM, so there's little to boost.
    # By what the driver registers, not the brand: amdgpu and xe name the
    # region "vram", other drivers "vidmem" (numbered with several), so an
    # NVIDIA driver that registers its memory is offered right away.
    awk -v min="$VRAM_MIN_BYTES" '$1 ~ /\/(vram|vidmem)[0-9]*$/ && $2 >= min { found = 1 } END { exit !found }' \
        "$VRAM_CAPACITY" 2>/dev/null
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

# chwd's lists of NVIDIA cards that need a closed legacy branch (580xx,
# 470xx, 390xx); every other NVIDIA card runs the open kernel modules.
VRAM_CHWD_IDS=/var/lib/chwd/ids

vram_nvidia_legacy_id() {
    # vram_nvidia_legacy_id <pci device id, with or without 0x>: 0 when chwd
    # lists the card for a closed legacy branch, i.e. it is older than the
    # RTX 20 series. Also what lib/nvidia.sh uses to decide if a card is supported.
    grep -qwi "${1#0x}" "$VRAM_CHWD_IDS"/nvidia-*.ids 2>/dev/null
}

vram_nvidia_case() {
    # Why an NVIDIA card's VRAM isn't registered, so the menu can say what to
    # do: "update" (open modules older than 615), "switch <chwd profile>"
    # (closed driver on a card the open one supports), "legacy" (card only
    # runs a closed legacy branch), "nouveau" (no NVIDIA module).
    # WIZARD_VRAM_FAKE_NVIDIA=1 fakes "switch nvidia-dkms-580xx", or name a case.
    local fake="${WIZARD_VRAM_FAKE_NVIDIA:-}" license d id p
    if [[ -n "$fake" ]]; then
        [[ "$fake" == 1 ]] && fake="switch nvidia-dkms-580xx"
        echo "$fake"; return
    fi
    license="$(modinfo -F license nvidia 2>/dev/null)"
    case "$license" in
        "Dual MIT/GPL") echo update; return ;;
        "") echo nouveau; return ;;
    esac
    for d in /sys/bus/pci/devices/*; do
        [[ "$(cat "$d/vendor" 2>/dev/null)" == 0x10de && "$(cat "$d/class" 2>/dev/null)" == 0x03* ]] || continue
        vram_nvidia_legacy_id "$(cat "$d/device")" && { echo legacy; return; }
    done
    for p in 580xx 470xx 390xx; do
        pacman -Q "nvidia-$p-dkms" >/dev/null 2>&1 && { echo "switch nvidia-dkms-$p"; return; }
    done
    echo switch
}

vram_nvidia_hint() {
    # vram_nvidia_hint <case>: the short reason (terminal menu, the app's row).
    case "$1" in
        update) echo "update NVIDIA's driver to 615 or newer (sudo pacman -Syu)" ;;
        switch*) echo "needs NVIDIA's open driver, which your card supports" ;;
        legacy) echo "your NVIDIA card's driver doesn't support it (older than RTX 20)" ;;
        *) echo "the nouveau driver doesn't support it yet" ;;
    esac
}

vram_nvidia_note() {
    # vram_nvidia_note <case>: the full explanation, with what to do.
    local profile="${1#switch}"; profile="${profile# }"
    case "$1" in
        update) echo "NVIDIA's open driver tells Linux how its video memory is used from version 615 on; yours is older ($(cat /sys/module/nvidia/version 2>/dev/null || echo unknown)). Update your system (sudo pacman -Syu), restart, and it's available here." ;;
        switch*) echo "Your card also runs NVIDIA's open driver, the one CachyOS installs by default, and only that one tells Linux how its video memory is used. You're using NVIDIA's closed driver. Switch in a terminal with: ${profile:+sudo chwd -r $profile && }sudo chwd -i nvidia-open-dkms, then restart: it's available here after that. Steamify doesn't switch it for you: if something goes wrong, the screen stays black after the restart." ;;
        legacy) echo "Your NVIDIA card is older than the RTX 20 series and only runs NVIDIA's closed driver, which doesn't tell Linux how its video memory is used. Newer NVIDIA cards (RTX 20 series and up), and AMD and Intel graphics cards, support it." ;;
        *) echo "The open-source nouveau driver doesn't tell Linux how its video memory is used yet (a patch is on its way into the kernel). NVIDIA's own open driver does, from version 615 on (sudo chwd -a installs the right one)." ;;
    esac
}

# Shown where it works, and greyed out with an NVIDIA card whose driver
# doesn't register its VRAM with the kernel (yet): so it's clear why it
# can't be turned on. Hidden elsewhere (integrated graphics, older kernel).
vram_available() { vram_supported || vram_status || vram_nvidia; }
vram_selectable() { vram_supported || vram_status; }

vram_status() {
    pacman -Q "${VRAM_PKGS[@]}" >/dev/null 2>&1 &&
        systemctl is-enabled -q dmemcg-booster-system.service 2>/dev/null &&
        user_systemctl is-enabled -q dmemcg-booster-user.service 2>/dev/null
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
    user_systemctl enable --now dmemcg-booster-user.service >/dev/null 2>&1 ||
        { err "Starting dmemcg-booster for $USER failed."; return 1; }
    kset vram kcgroupsrc "Foreground Booster" autostart true
    # Started by the Plasma session from now on; start it in this one too.
    [[ "${XDG_CURRENT_DESKTOP:-}" == KDE ]] &&
        user_systemctl start plasma-foreground-booster.service >/dev/null 2>&1
    ok "VRAM booster on: the game in front keeps its VRAM."
}

vram_disable() {
    local pkgs
    user_systemctl disable --now plasma-foreground-booster.service dmemcg-booster-user.service >/dev/null 2>&1
    sudo systemctl disable --now dmemcg-booster-system.service >/dev/null 2>&1
    krevert vram
    pkgs="$(state_get vram installed_pkgs)"
    # shellcheck disable=SC2086 # a list of package names
    [[ -n "$pkgs" ]] && sudo pacman -Rns --noconfirm $pkgs >/dev/null 2>&1
    state_clear vram
    ok "VRAM booster off."
}
