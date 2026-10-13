#!/bin/bash
# Required packages and AUR helper handling.
# Sourced by steamify.sh; not meant to be run on its own.

aur_noninteractive_flags() {
    # Fully non-interactive install flags for the given AUR helper: no
    # PKGBUILD diff/edit/cleanbuild prompts, no provider-selection prompts
    # (e.g. picking kernel headers for DKMS), and makepkg itself silenced.
    case "$1" in
        yay)
            echo --needed --noconfirm --answerclean None --answerdiff None \
                 --answeredit None --mflags "--noconfirm"
            ;;
        paru)
            echo --needed --noconfirm --skipreview --mflags "--noconfirm"
            ;;
    esac
}

find_aur_helper() {
    if command -v yay >/dev/null 2>&1; then
        echo yay
    elif command -v paru >/dev/null 2>&1; then
        echo paru
    fi
}

bootstrap_yay() {
    # Builds and installs yay from the AUR using only makepkg + base-devel
    # (both from the official repos), so we have an AUR helper available
    # without assuming the user already set one up.
    info "Installing base-devel and git (needed to build an AUR helper)..."
    sudo pacman -S --needed --noconfirm base-devel git || return 1

    local tmp_dir
    tmp_dir="$(mktemp -d)"
    info "Cloning yay-bin from the AUR..."
    if ! git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp_dir/yay-bin"; then
        err "Failed to clone yay-bin from the AUR."
        rm -rf "$tmp_dir"
        return 1
    fi

    # Build only, then install it ourselves: makepkg -i runs `sudo -k pacman`,
    # which forgets the cached sudo password and asks for it again.
    info "Building and installing yay (this runs makepkg as your user, not root)..."
    local -a pkgs
    if (cd "$tmp_dir/yay-bin" && makepkg --noconfirm) &&
        mapfile -t pkgs < <(cd "$tmp_dir/yay-bin" && makepkg --packagelist | grep -v -- '-debug-') &&
        sudo pacman -U --noconfirm "${pkgs[@]}"; then
        ok "yay installed."
        rm -rf "$tmp_dir"
        return 0
    else
        err "Building yay failed. See errors above."
        rm -rf "$tmp_dir"
        return 1
    fi
}

python_hid_shim_ensure() {
    # jupiter-hw-support (a dependency of gamescope-session-cachyos) wants python-hid, which conflicts with python-hidapi, and
    # a PC can need python-hidapi (liquidctl does). Only Valve's Steam Deck controller firmware updater uses python-hid, which
    # a PC doesn't run: so a placeholder package that provides python-hid keeps python-hidapi and satisfies the dependency
    # (also at later updates, which a one-time --assume-installed wouldn't). It stays when the conversion goes off:
    # jupiter-hw-support, which stays, depends on it.
    pacman -Q python-hidapi >/dev/null 2>&1 || return 0
    pacman -Q python-hid steamify-python-hid-shim >/dev/null 2>&1 && return 0
    local dir pkg cache="${XDG_CACHE_HOME:-$HOME/.cache}/steamify"
    warn "python-hidapi is installed (liquidctl and others need it) and conflicts with python-hid, which Steam Deck's tools ask for: keeping python-hidapi, with a small placeholder package for python-hid."
    sudo pacman -S --needed --noconfirm base-devel >/dev/null || { err "Installing the build tools failed."; return 1; }
    mkdir -p "$cache" && dir="$(mktemp -d -p "$cache" hid-shim.XXXXXX)" || return 1
    patch_file python-hid-shim.PKGBUILD > "$dir/PKGBUILD" || { rm -rf "$dir"; return 1; }
    if ! (cd "$dir" && makepkg -f --noconfirm >/dev/null) ||
        ! pkg="$(ls "$dir"/steamify-python-hid-shim-*.pkg.tar.* 2>/dev/null | head -1)" ||
        ! sudo pacman -U --noconfirm "$pkg"; then
        rm -rf "$dir"
        err "Couldn't set up the python-hid placeholder: python-hidapi and python-hid conflict, so the packages can't be installed."
        return 1
    fi
    rm -rf "$dir"
    ok "python-hidapi kept; python-hid is covered by a placeholder."
}

install_required_packages() {
    # Step 2: gamescope/Steam and the desktop helpers the rest of the setup uses.
    local -a MISSING
    info "Checking required packages: gamescope-session-cachyos, steam, mangohud, xterm, ttf-liberation, wqy-zenhei, plasma-keyboard"
    mapfile -t MISSING < <(pacman -T gamescope-session-cachyos steam mangohud xterm ttf-liberation wqy-zenhei plasma-keyboard)

    if [[ ${#MISSING[@]} -gt 0 ]]; then
        python_hid_shim_ensure || return 1
        info "Installing missing packages: ${MISSING[*]}"
        sudo pacman -S --needed --noconfirm "${MISSING[@]}" || { err "Package installation failed."; return 1; }
    else
        ok "All required packages already installed."
    fi
}

ensure_aur_helper() {
    # yay or paru, bootstrapping yay from the AUR when neither is installed.
    if [[ -n "$(find_aur_helper)" ]]; then
        ok "AUR helper already present."
    else
        info "No AUR helper (yay/paru) found. Installing yay..."
        bootstrap_yay
    fi
}
