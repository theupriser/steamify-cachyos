#!/bin/bash
# gamescope's own gaming mode on NVIDIA: a patched gamescope that allocates its scan-out buffers with GBM, which cures
# the corrupted picture (https://github.com/ValveSoftware/gamescope/issues/2309). The patch and the build recipe are in
# patches/ (kept in sync with https://github.com/theupriser/steamify-gamescope-nvidia, where new gamescope versions are
# prepared); the package `steamify-gamescope-nvidia` is built here, on the PC, and replaces `gamescope` (it provides it). The patch is opt-in: gamescope reads `gamescope_drm_gbm_scanout=1` from its
# environment, which is set for the gaming session (gamescope-session's environment file, and environment.d).
# Used by the SteamOS conversion (`gaming_enable`/`gaming_disable`) on every NVIDIA PC (`nvidia_present`); the kernel
# parameters and the rest of lib/nvidia.sh's setup only on a supported card (`nvidia_supported`): GTX 16 / RTX 20 series or
# newer (Turing and later, what NVIDIA's open kernel driver supports). Tested on an RTX 5080 only.
# Sourced by steamify.sh; not meant to be run on its own.

GSN_PKG=steamify-gamescope-nvidia
GSN_ENV_LINE='gamescope_drm_gbm_scanout=1'
GSN_ENV_D="${GSN_ENV_D:-$HOME/.config/environment.d/99-steamify-gamescope-nvidia.conf}"
GSN_SESSION_ENV="${GSN_SESSION_ENV:-$HOME/.config/gamescope-session/environment}"

gsn_package_installed() { pacman -Q "$GSN_PKG" >/dev/null 2>&1; }

gsn_env_set() { [[ -f "$GSN_ENV_D" ]] && grep -qsx "$GSN_ENV_LINE" "$GSN_SESSION_ENV"; }

gsn_status() { gsn_package_installed && gsn_env_set; }

gsn_install_package() {
    # Builds the package from the recipe and patch Steamify carries (patches/, so a Steamify release builds exactly the
    # gamescope version it was tested with) and installs it. makepkg runs as the user, never as root, and downloads
    # gamescope's sources (Valve's repository at the PKGBUILD's pkgver, and its submodules). The build needs a few minutes:
    # gamescope compiles from source. --ask 4 lets pacman replace the stock gamescope it conflicts with.
    gsn_package_installed && return 0
    info "Building the patched gamescope for NVIDIA (a few minutes)..."
    sudo pacman -S --needed --noconfirm base-devel git || { err "Installing the build tools failed."; return 1; }
    local dir pkg cache="${XDG_CACHE_HOME:-$HOME/.cache}/steamify"
    # On disk, not /tmp: the installer's chroot has a tmpfs there (RAM), and the build is 1-2 GB.
    mkdir -p "$cache" && dir="$(mktemp -d -p "$cache" gamescope-build.XXXXXX)" || return 1
    patch_file gamescope-nvidia.PKGBUILD > "$dir/PKGBUILD" &&
        patch_file gamescope-gbm-scanout.patch > "$dir/gamescope-gbm-scanout.patch" || {
        err "Couldn't write the build files."
        rm -rf "$dir"; return 1
    }
    if ! (cd "$dir" && makepkg -sf --noconfirm --nocheck); then
        err "Building the patched gamescope failed (see above). The stock gamescope stays."
        rm -rf "$dir"; return 1
    fi
    pkg="$(ls "$dir"/"$GSN_PKG"-*.pkg.tar.* 2>/dev/null | grep -v -- '-debug-' | head -1)"
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
    nvidia_present || return 0
    # A PC that had "Gaming on NVIDIA" on: Steam must not also start on the desktop.
    nvidia_swap_out
    # What NVIDIA's DRM stack wants (lib/nvidia.sh; a supported card only, the functions check): modeset/fbdev on the
    # kernel command line, the modules in the initramfs, video memory kept over suspend, the 32-bit libraries. Takes
    # effect at the next boot, like the session.
    nvidia_kernel_enable || return 1
    nvidia_extras_enable || return 1
    gsn_install_package || return 1
    gsn_env_enable
    ok "gamescope draws NVIDIA's picture through GBM (gamescope_drm_gbm_scanout=1) from the next gaming mode start."
}

gsn_disable() {
    # The setting goes, and what nvidia_*_enable added; the packages stay (patched gamescope, 32-bit libraries), like
    # the other packages of the conversion (steam, gamescope-session-cachyos).
    gsn_env_disable
    nvidia_present || return 0
    nvidia_extras_disable
    nvidia_kernel_disable
}
