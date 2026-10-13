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
# The package this Steamify release was tested with (the recipe in patches/ names the same version): built by CI in
# CachyOS's container and published as a release of steamify-gamescope-nvidia. A new pin: the release, its sha256, and
# patches/gamescope-nvidia.PKGBUILD's pkgver/pkgrel.
GSN_VERSION=3.16.31-1
GSN_SHA256=9f20e5243866d1ddeb9ba0c6828bc7be1945f623f9a5d8094391f0df043002e1
GSN_URL="${GSN_URL:-https://github.com/theupriser/steamify-gamescope-nvidia/releases/download/$GSN_VERSION}"
# Where the ISO leaves a copy of the same package, for installs without GitHub.
GSN_BACKUP_DIR="${GSN_BACKUP_DIR:-/usr/local/share/steamify/gamescope}"
GSN_ENV_LINE='gamescope_drm_gbm_scanout=1'
GSN_ENV_D="${GSN_ENV_D:-$HOME/.config/environment.d/99-steamify-gamescope-nvidia.conf}"
GSN_SESSION_ENV="${GSN_SESSION_ENV:-$HOME/.config/gamescope-session/environment}"

gsn_package_installed() { pacman -Q "$GSN_PKG" >/dev/null 2>&1; }

gsn_env_set() { [[ -f "$GSN_ENV_D" ]] && grep -qsx "$GSN_ENV_LINE" "$GSN_SESSION_ENV"; }

gsn_status() { gsn_package_installed && gsn_env_set; }

gsn_package_current() {
    # The pinned version is installed (a newer Steamify pins a newer one, which then installs over it).
    [[ "$(pacman -Q "$GSN_PKG" 2>/dev/null | awk '{print $2}')" == "$GSN_VERSION" ]]
}

gsn_sha_ok() { echo "$GSN_SHA256  $1" | sha256sum -c --quiet - >/dev/null 2>&1; }

gsn_fetch_package() {
    # The pinned, verified package, on stdout as a path: first from GitHub (built by CI in CachyOS's container), else the
    # copy that came with the ISO. Both only count when their sha256 is the one pinned here: a Steamify release names
    # exactly the package it was tested with, so an unchanged or swapped file is refused.
    local cache="${XDG_CACHE_HOME:-$HOME/.cache}/steamify" file="$GSN_PKG-$GSN_VERSION-x86_64.pkg.tar.zst" backup
    mkdir -p "$cache" || return 1
    if [[ -f "$cache/$file" ]] && gsn_sha_ok "$cache/$file"; then echo "$cache/$file"; return 0; fi
    info "Downloading the patched gamescope (GitHub release $GSN_VERSION)..." >&2
    if curl -fsL --retry 2 --connect-timeout 15 --max-time 300 -o "$cache/$file.part" "$GSN_URL/$file" &&
        gsn_sha_ok "$cache/$file.part"; then
        mv -f "$cache/$file.part" "$cache/$file"
        echo "$cache/$file"; return 0
    fi
    rm -f "$cache/$file.part"
    warn "Downloading the patched gamescope failed (or its checksum didn't match)." >&2
    for backup in "$GSN_BACKUP_DIR/$file" "$cache/$file"; do
        if [[ -f "$backup" ]] && gsn_sha_ok "$backup"; then
            info "Using the copy that came with Steamify: $backup" >&2
            echo "$backup"; return 0
        fi
    done
    return 1
}

gsn_build_package() {
    # Last resort: builds the package from the recipe and patch Steamify carries (patches/), as the user. It downloads
    # gamescope's sources (Valve's repository at the PKGBUILD's pkgver, and its submodules) and compiles them: a few
    # minutes. Prints the package's path.
    local dir cache="${XDG_CACHE_HOME:-$HOME/.cache}/steamify"
    info "Building the patched gamescope here instead (a few minutes)..." >&2
    sudo pacman -S --needed --noconfirm base-devel git >&2 || { err "Installing the build tools failed." >&2; return 1; }
    # On disk, not /tmp: the installer's chroot has a tmpfs there (RAM), and the build is 1-2 GB.
    mkdir -p "$cache" && dir="$(mktemp -d -p "$cache" gamescope-build.XXXXXX)" || return 1
    patch_file gamescope-nvidia.PKGBUILD > "$dir/PKGBUILD" &&
        patch_file gamescope-gbm-scanout.patch > "$dir/gamescope-gbm-scanout.patch" || {
        err "Couldn't write the build files." >&2
        rm -rf "$dir"; return 1
    }
    if ! (cd "$dir" && makepkg -sf --noconfirm --nocheck >&2); then
        err "Building the patched gamescope failed (see above)." >&2
        rm -rf "$dir"; return 1
    fi
    # Moved out, so the build folder can go.
    mv "$(ls "$dir"/"$GSN_PKG"-*.pkg.tar.* 2>/dev/null | grep -v -- '-debug-' | head -1)" "$cache/gamescope-local-build.pkg.tar.zst" ||
        { rm -rf "$dir"; return 1; }
    rm -rf "$dir"
    echo "$cache/gamescope-local-build.pkg.tar.zst"
}

gsn_install_package() {
    # The patched gamescope, in this order, each step only when the one before failed: the pinned package from GitHub, the
    # copy that came with the ISO, a build here. A package that downloaded fine but doesn't install (its libraries differ from
    # this PC's) goes on to the build too. Nothing else changes before one of them is installed, so a failure leaves the PC as
    # it was, with the stock gamescope. --ask 4 lets pacman replace the stock gamescope it conflicts with.
    gsn_package_current && return 0
    local pkg
    if pkg="$(gsn_fetch_package)" && sudo pacman -U --noconfirm --ask 4 "$pkg"; then
        ok "Patched gamescope installed."
        return 0
    fi
    warn "The ready-made patched gamescope couldn't be installed."
    if pkg="$(gsn_build_package)" && sudo pacman -U --noconfirm --ask 4 "$pkg"; then
        ok "Patched gamescope built and installed."
        return 0
    fi
    err "The patched gamescope couldn't be installed. The stock gamescope stays."
    return 1
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
