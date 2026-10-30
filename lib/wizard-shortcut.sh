#!/bin/bash
# "Steamify shortcut" menu item: "Steamify CachyOS" on the desktop and in the
# app launcher opens the newest release of the app (curl | bash of
# steamify-app.sh, like the install command in the README), so it's never out
# of date; "Steamify Terminal" in the launcher opens the terminal menu in
# Konsole the same way.
# Sourced by steamify.sh; not meant to be run on its own.

WIZARD_RELEASE="https://github.com/theupriser/steamify-cachyos/releases/latest/download"
WIZARD_URL="$WIZARD_RELEASE/steamify.sh"
WIZARD_APP_URL="$WIZARD_RELEASE/steamify-app.sh"
# Steam logo with a gear (assets/ in the repo, published with every release).
WIZARD_ICON="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/scalable/apps/steamify.svg"
WIZARD_LAUNCHER="$STEAMIFY_BIN/run-wizard"
WIZARD_APP_LAUNCHER="$STEAMIFY_BIN/run-app"
WIZARD_APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
# io.github.theupriser.Steamify: the id the app gives itself (reverse-DNS: GNOME matches windows only by such ids), so its window belongs to this
# entry. steamify-app.sh leaves an entry with X-Steamify-Shortcut alone.
WIZARD_DESKTOP_NAME="io.github.theupriser.Steamify.desktop"
# Until 2.12.0 the id was steamify-ui.
WIZARD_ID_BEFORE_ENTRY="steamify-ui.desktop"
WIZARD_APP_ENTRY="$WIZARD_APPS/$WIZARD_DESKTOP_NAME"
WIZARD_TERMINAL_ENTRY="$WIZARD_APPS/steamify-terminal.desktop"
# Before 2.0.1 the shortcut opened the terminal menu under this name.
WIZARD_OLD_NAME="cachyos-gamescope-boot-wizard.desktop"

wizard_terminal() {
    # The command prefix that runs a program in a terminal window: Konsole on
    # Plasma, on GNOME whichever of Ptyxis, Console or GNOME Terminal is there.
    if [[ "$(desktop_kind)" == gnome ]]; then
        if command -v ptyxis >/dev/null; then echo "ptyxis --"
        elif command -v kgx >/dev/null; then echo "kgx -e"
        else echo "gnome-terminal --"; fi
    else
        echo "konsole -e"
    fi
}

wizard_desktop_dir() {
    xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop"
}

install_executable() {
    # install_executable <dest> <mode>: stdin to <dest>, with its mode set
    # before it appears. Plasma treats a desktop icon it saw while it wasn't
    # executable yet as untrusted and opens it in an editor.
    local dest="$1" tmp
    mkdir -p "$(dirname "$dest")"
    tmp="$(mktemp "$(dirname "$dest")/.tmp.XXXXXX")"
    cat > "$tmp"
    chmod "$2" "$tmp"
    mv -f "$tmp" "$dest"
}

launcher_status() {
    [[ -x "$WIZARD_APP_LAUNCHER" && -x "$WIZARD_LAUNCHER" && -f "$WIZARD_APP_ENTRY" && -f "$WIZARD_TERMINAL_ENTRY" ]]
}

# A shortcut from before 2.0.1 (terminal only): the menu ticks the item, so a
# normal run replaces it.
launcher_repair() {
    # Also the shortcut from before the reverse-DNS app id (its entry carries the marker): the menu ticks it, a normal run replaces it.
    ! launcher_status || return 1
    [[ -f "$WIZARD_APPS/$WIZARD_OLD_NAME" ]] ||
        grep -q '^X-Steamify-Shortcut=true' "$WIZARD_APPS/$WIZARD_ID_BEFORE_ENTRY" 2>/dev/null
}

launcher_enable() {
    local terminal
    terminal="$(wizard_terminal)"
    info "Adding the Steamify shortcut (the app on the desktop and in the launcher, Steamify Terminal in the launcher)..."
    # Both scripts download the newest release when they run (patches/).
    patch_file steamify-start.sh | fill URL="$WIZARD_URL" | install_executable "$WIZARD_LAUNCHER" 755
    # The app, without a terminal. Only the first time, when PySide6 still
    # has to be installed, it runs in a terminal: sudo asks for the password there.
    patch_file steamify-app-start.sh | fill URL="$WIZARD_APP_URL" TERMINAL="$terminal" | install_executable "$WIZARD_APP_LAUNCHER" 755

    # The icon comes with the release; without it, Steam's own icon.
    local icon=steam tmp
    tmp="$(mktemp)"
    local theme="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor"
    # A PNG, by name, first: GNOME's dock can't always draw an SVG (blank icon, "Could not load a pixbuf from icon theme").
    # (Releases before 2.16.0 only have the SVG.)
    if curl -fsSL --max-time 20 "$WIZARD_RELEASE/steam-gaming-settings.png" -o "$tmp" && head -c 8 "$tmp" | grep -q PNG; then
        install -D -m 644 "$tmp" "$theme/256x256/apps/io.github.theupriser.Steamify.png"
        icon=io.github.theupriser.Steamify
        gtk-update-icon-cache -q -f -t "$theme" 2>/dev/null || true
    elif curl -fsSL --max-time 20 "$WIZARD_RELEASE/steam-gaming-settings.svg" -o "$tmp" && grep -q '<svg' "$tmp"; then
        install -D -m 644 "$tmp" "$WIZARD_ICON"
        # The full path: GNOME Shell's dock doesn't find a name in the user's icon folder (blank icon), and every desktop takes a path.
        icon="$WIZARD_ICON"
        gtk-update-icon-cache -q -f -t "${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor" 2>/dev/null || true
    else
        warn "Couldn't download the shortcut's icon; using Steam's icon instead."
    fi
    rm -f "$tmp"

    local entry
    entry="[Desktop Entry]
Type=Application
Name=Steamify CachyOS
Comment=Turn the SteamOS-style parts of this PC on or off
Exec=$WIZARD_APP_LAUNCHER
Icon=$icon
Terminal=false
Categories=Game;System;Settings;
StartupWMClass=io.github.theupriser.Steamify
X-Steamify-Shortcut=true"
    printf '%s\n' "$entry" | install_executable "$WIZARD_APP_ENTRY" 644
    printf '%s\n' "$entry" | install_executable "$(wizard_desktop_dir)/$WIZARD_DESKTOP_NAME" 755
    # GNOME only starts desktop launchers it trusts.
    gio set "$(wizard_desktop_dir)/$WIZARD_DESKTOP_NAME" metadata::trusted true 2>/dev/null || true
    printf '%s\n' "[Desktop Entry]
Type=Application
Name=Steamify Terminal
Comment=Steamify CachyOS's menu in a terminal
Exec=$terminal $WIZARD_LAUNCHER
Icon=$icon
Terminal=false
Categories=Game;System;Settings;" | install_executable "$WIZARD_TERMINAL_ENTRY" 644
    # The terminal-only shortcut from before 2.0.1, and the app's entry under its id before the reverse-DNS one.
    rm -f "$(wizard_desktop_dir)/$WIZARD_OLD_NAME" "$WIZARD_APPS/$WIZARD_OLD_NAME" \
        "$(wizard_desktop_dir)/$WIZARD_ID_BEFORE_ENTRY" "$WIZARD_APPS/$WIZARD_ID_BEFORE_ENTRY"
    kbuildsycoca6 >/dev/null 2>&1 || true
    ok "Steamify shortcut added: \"Steamify CachyOS\" (the app) on the desktop and in the launcher, \"Steamify Terminal\" in the launcher."
}

launcher_disable() {
    # The launcher entry only if it's ours: steamify-app.sh writes its own
    # under the same name when there's no shortcut.
    grep -q '^X-Steamify-Shortcut=true' "$WIZARD_APP_ENTRY" 2>/dev/null && rm -f "$WIZARD_APP_ENTRY"
    rm -f "$(wizard_desktop_dir)/$WIZARD_DESKTOP_NAME" "$WIZARD_TERMINAL_ENTRY" \
        "$(wizard_desktop_dir)/$WIZARD_OLD_NAME" "$WIZARD_APPS/$WIZARD_OLD_NAME" \
        "$(wizard_desktop_dir)/$WIZARD_ID_BEFORE_ENTRY" "$WIZARD_APPS/$WIZARD_ID_BEFORE_ENTRY" \
        "$WIZARD_LAUNCHER" "$WIZARD_APP_LAUNCHER" "$WIZARD_ICON"
    rmdir "$(dirname "$WIZARD_LAUNCHER")" 2>/dev/null || true
    kbuildsycoca6 >/dev/null 2>&1 || true
    ok "Steamify shortcut removed."
}
