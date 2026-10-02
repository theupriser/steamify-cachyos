#!/bin/bash
# Steam in the Plasma desktop session: gamepad UI args, virtual keyboard,
# autostart. Part of the SteamOS conversion (gaming_enable/gaming_disable).
# Sourced by steamify.sh; not meant to be run on its own.

steam_enable() {
    info "Applying non-optional SteamOS environment & keyboard fixes..."
    local steam_env_dir
    steam_env_dir="$HOME/.config/environment.d"
    mkdir -p "$steam_env_dir"

    # 2. Prevent KDE Wayland from blocking the virtual keyboard overlay
    echo "KWIN_IM_SHOW_ALWAYS=1" > "$steam_env_dir/99-kde-virtual-keyboard.conf"

    ok "Steam UI parameters and keyboard fix deployed successfully."
}

# Sub-option of the SteamOS conversion: Steam starts silently (in the tray,
# no window) on the Plasma desktop. It is Steam's own autostart entry, the file
# Steam's setting "Run Steam when my computer starts" creates and removes, so
# that setting shows what Steamify did (and the other way around). Steam's copy
# is the system steam.desktop; ours has -silent in its Exec line.
STEAM_AUTOSTART="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/steam.desktop"
STEAM_SYSTEM_DESKTOP=/usr/share/applications/steam.desktop

silent_status() {
    # The old systemd unit counts as on too (until it is migrated by an update of this option).
    grep -qs '^Exec=.*-silent' "$STEAM_AUTOSTART" ||
        [[ -f "$HOME/.config/systemd/user/steam-desktop-autostart.service" ]]
}

silent_old_unit_remove() {
    # Before 2.11.0 the option was a systemd user unit: it would start Steam a second time.
    local unit="$HOME/.config/systemd/user/steam-desktop-autostart.service"
    [[ -f "$unit" ]] || return 0
    user_systemctl disable --now steam-desktop-autostart.service 2>/dev/null
    rm -f "$unit"
    user_systemctl daemon-reload
}

silent_enable() {
    silent_old_unit_remove
    mkdir -p "$(dirname "$STEAM_AUTOSTART")"
    if [[ -f "$STEAM_SYSTEM_DESKTOP" ]]; then
        sed 's|^Exec=/usr/bin/steam %U$|Exec=/usr/bin/steam -silent %U|' "$STEAM_SYSTEM_DESKTOP" > "$STEAM_AUTOSTART"
    fi
    silent_status || printf '%s\n' '[Desktop Entry]' 'Name=Steam' 'Exec=/usr/bin/steam -silent %U' \
        'Icon=steam' 'Terminal=false' 'Type=Application' 'Categories=Network;FileTransfer;Game;' > "$STEAM_AUTOSTART"
    ok "Steam starts silently on the desktop from the next login."
}

silent_disable() {
    silent_old_unit_remove
    silent_status && rm -f "$STEAM_AUTOSTART"
    ok "Steam no longer starts by itself on the desktop."
}

steam_disable() {
    info "Removing Steam desktop settings..."
    # The autostart entry is the `silent` option's: removed with it, and here
    # too for when the conversion goes off by itself.
    silent_status && silent_disable
    silent_old_unit_remove
    rm -f "$HOME/.config/environment.d/99-kde-virtual-keyboard.conf"
    ok "Steam desktop settings removed (takes full effect at next login)."
}

# "Steam Deck/Machine icons" menu item: Steam's gamepad UI in SteamOS 3
# mode, which shows Steam Deck button glyphs in gaming mode.
glyphs_status() {
    [[ -f "$HOME/.config/environment.d/99-gamescope-steam-glyphs.conf" ]]
}

glyphs_enable() {
    local gs_env="$HOME/.config/gamescope-session/environment"
    mkdir -p "$HOME/.config/environment.d"
    echo 'STEAM_GAMEPADUI_ARGS="-gamepadui -steamos3"' > "$HOME/.config/environment.d/99-gamescope-steam-glyphs.conf"
    if [[ -d "$HOME/.config/gamescope-session" ]]; then
        touch "$gs_env"
        sed -i '/^STEAM_GAMEPADUI_ARGS=/d' "$gs_env"
        echo 'STEAM_GAMEPADUI_ARGS="-gamepadui -steamos3"' >> "$gs_env"
    fi
    ok "Steam Deck/Machine icons on (from the next gaming mode start)."
}

glyphs_disable() {
    rm -f "$HOME/.config/environment.d/99-gamescope-steam-glyphs.conf"
    [[ -f "$HOME/.config/gamescope-session/environment" ]] &&
        sed -i '/^STEAM_GAMEPADUI_ARGS=/d' "$HOME/.config/gamescope-session/environment"
    ok "Steam's default button icons are back (from the next gaming mode start)."
}
