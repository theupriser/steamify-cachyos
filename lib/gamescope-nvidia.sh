#!/bin/bash
# gamescope's own gaming mode on NVIDIA: a patched gamescope that allocates its scan-out buffers with GBM, which cures
# the corrupted picture (https://github.com/ValveSoftware/gamescope/issues/2309). The patch and the build recipe live in
# https://github.com/theupriser/steamify-gamescope-nvidia; the package `steamify-gamescope-nvidia` is built here, on the PC,
# and replaces `gamescope` (it provides it). The patch is opt-in: gamescope reads `gamescope_drm_gbm_scanout=1` from its
# environment, which is set for the gaming session (gamescope-session's environment file, and environment.d).
# Used by the SteamOS conversion (`gaming_enable`/`gaming_disable`) on a supported NVIDIA card (`nvidia_supported`):
# GTX 16 / RTX 20 series or newer (Turing and later, what NVIDIA's open kernel driver supports).
# Sourced by steamify.sh; not meant to be run on its own.

GSN_PKG=steamify-gamescope-nvidia
GSN_REPO=${GSN_REPO:-https://github.com/theupriser/steamify-gamescope-nvidia.git}
GSN_ENV_LINE='gamescope_drm_gbm_scanout=1'
GSN_ENV_D="${GSN_ENV_D:-$HOME/.config/environment.d/99-steamify-gamescope-nvidia.conf}"
GSN_SESSION_ENV="${GSN_SESSION_ENV:-$HOME/.config/gamescope-session/environment}"

gsn_package_installed() { pacman -Q "$GSN_PKG" >/dev/null 2>&1; }

gsn_env_set() { [[ -f "$GSN_ENV_D" ]] && grep -qsx "$GSN_ENV_LINE" "$GSN_SESSION_ENV"; }

gsn_status() { gsn_package_installed && gsn_env_set; }

gsn_install_package() {
    # Builds the package from the repo (makepkg runs as the user, never as root) and installs it. The build needs a few
    # minutes: gamescope compiles from source. --ask 4 lets pacman replace the stock gamescope it conflicts with.
    gsn_package_installed && return 0
    info "Building the patched gamescope for NVIDIA (a few minutes)..."
    sudo pacman -S --needed --noconfirm base-devel git || { err "Installing the build tools failed."; return 1; }
    local dir pkg
    dir="$(mktemp -d)" || return 1
    if ! git clone --depth 1 "$GSN_REPO" "$dir/src"; then
        err "Couldn't download $GSN_REPO."
        rm -rf "$dir"; return 1
    fi
    if ! (cd "$dir/src" && makepkg -sf --noconfirm --nocheck); then
        err "Building the patched gamescope failed (see above). The stock gamescope stays."
        rm -rf "$dir"; return 1
    fi
    pkg="$(ls "$dir"/src/"$GSN_PKG"-*.pkg.tar.* 2>/dev/null | grep -v -- '-debug-' | head -1)"
    if [[ -z "$pkg" ]] || ! sudo pacman -U --noconfirm --ask 4 "$pkg"; then
        err "Installing the patched gamescope failed. The stock gamescope stays."
        rm -rf "$dir"; return 1
    fi
    rm -rf "$dir"
    ok "Patched gamescope installed."
}

gsn_env_enable() {
    mkdir -p "$(dirname "$GSN_ENV_D")" "$(dirname "$GSN_SESSION_ENV")"
    echo "$GSN_ENV_LINE" > "$GSN_ENV_D"
    touch "$GSN_SESSION_ENV"
    grep -qsx "$GSN_ENV_LINE" "$GSN_SESSION_ENV" || echo "$GSN_ENV_LINE" >> "$GSN_SESSION_ENV"
}

gsn_env_disable() {
    rm -f "$GSN_ENV_D"
    [[ -f "$GSN_SESSION_ENV" ]] && sed -i "/^${GSN_ENV_LINE}\$/d" "$GSN_SESSION_ENV"
    return 0
}

gsn_enable() {
    # Only on a supported NVIDIA card; elsewhere the stock gamescope is right.
    nvidia_supported || return 0
    gsn_install_package || return 1
    gsn_env_enable
    ok "gamescope draws NVIDIA's picture through GBM (gamescope_drm_gbm_scanout=1) from the next gaming mode start."
}

gsn_disable() {
    # The setting goes; the patched package stays, like the other packages (steam, gamescope-session-cachyos).
    gsn_env_disable
}
