#!/bin/bash
# gamescope's own gaming mode on NVIDIA: a patched gamescope that allocates its scan-out buffers with GBM, which cures
# the corrupted picture (https://github.com/ValveSoftware/gamescope/issues/2309). The patch is opt-in: gamescope reads
# `gamescope_drm_gbm_scanout=1` from its environment, which is set for the gaming session (gamescope-session's
# environment file, and environment.d).
#
# gamescope changes every few weeks, so the package is not carried but downloaded: the newest release of
# https://github.com/theupriser/steamify-gamescope-nvidia (CI builds it in CachyOS's container, a person merges the
# version bump), and a newer one than the installed package shows as an update of the SteamOS conversion
# (`gsn_update_pending`). What this Steamify release was tested with is the fallback: the pinned package (sha256 below),
# a copy that came with the ISO, and last a build here from the recipe and patch in patches/. Simple files that don't change
# stay in patches/ and are used as they are.
#
# Used by the SteamOS conversion (`gaming_enable`/`gaming_disable`) on every NVIDIA PC (`nvidia_present`); the kernel
# parameters and the rest of lib/nvidia.sh's setup only on a supported card (`nvidia_supported`): GTX 16 / RTX 20 series or
# newer (Turing and later, what NVIDIA's open kernel driver supports). Tested on an RTX 5080 only.
# Sourced by steamify.sh; not meant to be run on its own.

GSN_PKG=steamify-gamescope-nvidia
GSN_RELEASES="${GSN_RELEASES:-https://github.com/theupriser/steamify-gamescope-nvidia/releases}"
# The package this Steamify release was tested with (patches/gamescope-nvidia.PKGBUILD names the same version): the
# fallback. A new pin: the release's tag, the package's sha256, and the PKGBUILD's pkgver/pkgrel.
GSN_VERSION=3.16.31-2
GSN_SHA256=3b981bed4dfdac383d22b8c22feaef191c2f2863bccf5676d1ec959c2c5ee3a3
# Where the ISO leaves a copy of the pinned package, for installs without GitHub.
GSN_BACKUP_DIR="${GSN_BACKUP_DIR:-/usr/local/share/steamify/gamescope}"
# How long a look at GitHub for a newer release counts (seconds), so opening the menu doesn't ask every time.
GSN_CHECK_EVERY="${GSN_CHECK_EVERY:-21600}"
GSN_ENV_LINE='gamescope_drm_gbm_scanout=1'
GSN_ENV_D="${GSN_ENV_D:-$HOME/.config/environment.d/99-steamify-gamescope-nvidia.conf}"
GSN_SESSION_ENV="${GSN_SESSION_ENV:-$HOME/.config/gamescope-session/environment}"

gsn_package_installed() { pacman -Q "$GSN_PKG" >/dev/null 2>&1; }

gsn_installed_version() { pacman -Q "$GSN_PKG" 2>/dev/null | awk '{print $2}'; }

gsn_env_set() { [[ -f "$GSN_ENV_D" ]] && grep -qsx "$GSN_ENV_LINE" "$GSN_SESSION_ENV"; }

gsn_status() { gsn_package_installed && gsn_env_set; }

gsn_newer() {
    # gsn_newer <a> <b>: version a is newer than b (pacman's own comparison).
    [[ "$(vercmp "$1" "$2" 2>/dev/null)" == 1 ]]
}

gsn_latest_tag() {
    # The newest release's tag (<gamescope version>-<package release>), from GitHub; nothing when it can't be reached or
    # there is no release. Follows the redirect of /releases/latest: no API, no rate limit, no JSON. gsn_latest_tag [seconds]
    local url
    url="$(curl -fsL --connect-timeout 4 --max-time "${1:-10}" -o /dev/null -w '%{url_effective}' "$GSN_RELEASES/latest" 2>/dev/null)" || return 1
    url="${url##*/}"
    [[ "$url" =~ ^[0-9][0-9A-Za-z._]*-[0-9]+$ ]] || return 1
    echo "$url"
}

gsn_update_pending() {
    # The patched gamescope is installed and GitHub has a newer release: the menu shows the conversion as an update.
    # Looked up at most every GSN_CHECK_EVERY seconds (the answer is kept in the state), quickly, and silently when
    # offline: no network is never a reason to show or hide anything.
    gsn_package_installed || return 1
    local now checked latest
    now="$(date +%s)"; checked="$(state_get gamescope_nvidia checked 0)"
    if (( now - ${checked:-0} > GSN_CHECK_EVERY )); then
        state_set gamescope_nvidia checked "$now"
        latest="$(gsn_latest_tag 5)" && state_set gamescope_nvidia latest "$latest"
    fi
    latest="$(state_get gamescope_nvidia latest)"
    [[ -n "$latest" ]] && gsn_newer "$latest" "$(gsn_installed_version)"
}

gsn_sha_of() {
    # The hash a release file is expected to have: the pinned one for the pinned version, else the .sha256 next to the
    # package in the same release (it shows the download wasn't damaged, not who made it).
    local tag="$1" file="$2"
    if [[ "$tag" == "$GSN_VERSION" ]]; then echo "$GSN_SHA256"; return 0; fi
    curl -fsL --connect-timeout 10 --max-time 30 "$GSN_RELEASES/download/$tag/$file.sha256" 2>/dev/null | awk 'NR==1 {print $1}'
}

gsn_download() {
    # gsn_download <tag>: the release's package, verified, in the cache; prints its path.
    local tag="$1" cache="${XDG_CACHE_HOME:-$HOME/.cache}/steamify" file want got
    file="$GSN_PKG-$tag-x86_64.pkg.tar.zst"
    mkdir -p "$cache" || return 1
    want="$(gsn_sha_of "$tag" "$file")"
    [[ "$want" =~ ^[0-9a-f]{64}$ ]] || return 1
    if [[ -f "$cache/$file" ]] && [[ "$(sha256sum "$cache/$file" | awk '{print $1}')" == "$want" ]]; then echo "$cache/$file"; return 0; fi
    curl -fsL --retry 2 --connect-timeout 15 --max-time 300 -o "$cache/$file.part" "$GSN_RELEASES/download/$tag/$file" || { rm -f "$cache/$file.part"; return 1; }
    got="$(sha256sum "$cache/$file.part" | awk '{print $1}')"
    if [[ "$got" != "$want" ]]; then rm -f "$cache/$file.part"; return 1; fi
    mv -f "$cache/$file.part" "$cache/$file"
    echo "$cache/$file"
}

gsn_fetch_package() {
    # The package to install, as a path, newest first: the newest release on GitHub (not older than the pinned one), else
    # the pinned package (GitHub, the cache, or the copy that came with the ISO). Only files with the expected sha256 count.
    local tag pkg cache="${XDG_CACHE_HOME:-$HOME/.cache}/steamify" file="$GSN_PKG-$GSN_VERSION-x86_64.pkg.tar.zst" copy
    tag="$(gsn_latest_tag)" || tag=""
    if [[ -n "$tag" && "$tag" != "$GSN_VERSION" ]] && gsn_newer "$tag" "$GSN_VERSION"; then
        info "Downloading the newest patched gamescope ($tag)..." >&2
        if pkg="$(gsn_download "$tag")"; then echo "$pkg"; return 0; fi
        warn "Downloading the newest patched gamescope ($tag) failed: using the version this Steamify was tested with ($GSN_VERSION)." >&2
    fi
    info "Downloading the patched gamescope ($GSN_VERSION)..." >&2
    if pkg="$(gsn_download "$GSN_VERSION")"; then echo "$pkg"; return 0; fi
    warn "Downloading the patched gamescope failed (or its checksum didn't match)." >&2
    for copy in "$GSN_BACKUP_DIR/$file" "$cache/$file"; do
        if [[ -f "$copy" ]] && [[ "$(sha256sum "$copy" | awk '{print $1}')" == "$GSN_SHA256" ]]; then
            info "Using the copy that came with Steamify: $copy" >&2
            echo "$copy"; return 0
        fi
    done
    return 1
}

gsn_build_package() {
    # Last resort: builds the pinned package from the recipe and patch Steamify carries (patches/), as the user. It
    # downloads gamescope's sources (Valve's repository at the PKGBUILD's pkgver, and its submodules) and compiles them: a
    # few minutes. Prints the package's path.
    local dir cache="${XDG_CACHE_HOME:-$HOME/.cache}/steamify"
    info "Building the patched gamescope here instead (a few minutes)..." >&2
    sudo pacman -S --needed --noconfirm base-devel git >&2 || { err "Installing the build tools failed." >&2; return 1; }
    # On disk, not /tmp: the installer's chroot has a tmpfs there (RAM), and the build is 1-2 GB.
    mkdir -p "$cache" && dir="$(mktemp -d -p "$cache" gamescope-build.XXXXXX)" || return 1
    patch_file gamescope-nvidia.PKGBUILD > "$dir/PKGBUILD" &&
        patch_file gamescope-gbm-scanout.patch > "$dir/gamescope-gbm-scanout.patch" &&
        patch_file gamescope-ui-native.patch > "$dir/gamescope-ui-native.patch" || {
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
    # The patched gamescope, newest first, each step only when the one before failed: the newest release from GitHub, the
    # pinned package (GitHub, cache or the copy that came with the ISO), a build here. A package that downloaded fine but
    # doesn't install (its libraries differ from this PC's) goes on to the next step too. Nothing else changes before one of
    # them is installed, so a failure leaves the PC as it was, with what it had. --ask 4 lets pacman replace the stock
    # gamescope it conflicts with, and an older patched one.
    local pkg latest have
    have="$(gsn_installed_version)"
    latest="$(gsn_latest_tag)" || latest=""
    # Already the newest (or, offline, the pinned version or newer): nothing to do.
    if [[ -n "$have" ]]; then
        if [[ -n "$latest" ]] && ! gsn_newer "$latest" "$have"; then return 0; fi
        if [[ -z "$latest" ]] && ! gsn_newer "$GSN_VERSION" "$have"; then return 0; fi
    fi
    if pkg="$(gsn_fetch_package)" && sudo pacman -U --noconfirm --ask 4 "$pkg"; then
        ok "Patched gamescope installed."
        return 0
    fi
    warn "The ready-made patched gamescope couldn't be installed."
    [[ -n "$have" ]] && { warn "The installed one ($have) stays."; return 0; }
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

# --- The session starts gamescope on the display's own mode
#
# gamescope-session starts gamescope without a size or a refresh rate, so it takes the display's *preferred* mode, which
# many monitors declare as 60 Hz while the desktop runs them at their highest. patches/gamescope-display-wrapper.sh (put
# first in the gaming session's PATH by a drop-in of gamescope-session.service) starts it on the mode KDE has saved for
# the connected display, else the biggest mode at the highest refresh rate, read at every session start.
GSN_DISPLAY_WRAPPER="${GSN_DISPLAY_WRAPPER:-$STEAMIFY_BIN/gamescope}"
GSN_DISPLAY_DROPIN="${GSN_DISPLAY_DROPIN:-$HOME/.config/systemd/user/gamescope-session.service.d/steamify-display.conf}"

gsn_display_status() { [[ -x "$GSN_DISPLAY_WRAPPER" && -f "$GSN_DISPLAY_DROPIN" ]]; }

gsn_display_pending() {
    # The patched gamescope is in use but the session still starts it on the display's preferred mode: a normal run sets it up.
    gsn_package_installed && gsn_env_set && ! gsn_display_status
}

gsn_display_enable() {
    patch_file gamescope-display-wrapper.sh | install_executable "$GSN_DISPLAY_WRAPPER" 755 || return 1
    mkdir -p "$(dirname "$GSN_DISPLAY_DROPIN")"
    cat > "$GSN_DISPLAY_DROPIN" << EOF
# Steamify: the gaming session starts gamescope on the display's own mode (see lib/gamescope-nvidia.sh). Turning the
# SteamOS conversion off removes this file.
[Service]
ExecStart=
ExecStart=/usr/bin/bash -c 'PATH="$(dirname "$GSN_DISPLAY_WRAPPER"):\$PATH" exec /usr/lib/steamos/gamescope-session'
EOF
    user_systemctl daemon-reload
}

gsn_display_disable() {
    # Only our own files: the wrapper is recognised by its first comment line.
    grep -qs "^# Steamify: gamescope-session starts gamescope" "$GSN_DISPLAY_WRAPPER" && rm -f "$GSN_DISPLAY_WRAPPER"
    [[ -f "$GSN_DISPLAY_DROPIN" ]] && rm -f "$GSN_DISPLAY_DROPIN" && rmdir "$(dirname "$GSN_DISPLAY_DROPIN")" 2>/dev/null
    user_systemctl daemon-reload
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
    gsn_display_enable || warn "Couldn't set up the display mode for gaming mode: gamescope takes the display's preferred mode."
    ok "gamescope draws NVIDIA's picture through GBM (gamescope_drm_gbm_scanout=1) from the next gaming mode start."
}

gsn_disable() {
    # The setting goes, and what nvidia_*_enable added; the packages stay (patched gamescope, 32-bit libraries), like
    # the other packages of the conversion (steam, gamescope-session-cachyos).
    gsn_env_disable
    gsn_display_disable
    nvidia_present || return 0
    nvidia_extras_disable
    nvidia_kernel_disable
}
