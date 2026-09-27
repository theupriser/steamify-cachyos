#!/bin/bash
# Installed by Steamify: install missing -headers for every
# installed kernel, so DKMS builds leds-valve for it.
set -u
missing=()
for k in $(pacman -Qqo /usr/lib/modules/*/pkgbase 2>/dev/null | sort -u); do
    pacman -Q "${k}-headers" >/dev/null 2>&1 && continue
    pacman -Si "${k}-headers" >/dev/null 2>&1 && missing+=("${k}-headers")
done
[[ ${#missing[@]} -eq 0 ]] && exit 0
# Another pacman is running (e.g. an update): try again next boot.
[[ -e /var/lib/pacman/db.lck ]] && { echo "pacman is busy, skipping"; exit 0; }
echo "Installing missing kernel headers: ${missing[*]}"
exec pacman -S --needed --noconfirm "${missing[@]}"
