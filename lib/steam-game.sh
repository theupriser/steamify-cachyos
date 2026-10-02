#!/bin/bash
# "Add as non-Steam game" (steamgame), a sub-option of the Steamify shortcut:
# Steamify CachyOS in the Steam library, so Steam can start it: with Steam
# Input it then gets the controller (a Steam Controller only talks to Steam
# while Steam runs), in gaming mode too. Steam reads its non-Steam games
# (userdata/<id>/config/shortcuts.vdf, binary; patches/steam-shortcuts.py)
# only at startup and writes them back on exit, so Steam is closed for the
# edit and started again. That's refused while a Steam session depends on it:
# in gaming mode, or with this run started from Steam itself. What it did is
# recorded per Steam account (state steamgame, "<account>": "<appid> added"
# or "<appid> updated", for an entry that was there already): Steam rewrites
# the file on exit, so a mark inside the entry could be lost; the start
# script's path in it is the other sign it's ours.
# Sourced by steamify.sh; not meant to be run on its own.

STEAM_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/Steam"
STEAMGAME_NAME="Steamify CachyOS"
# Steam shows no SVG icons: the shortcut's icon rendered as PNG.
STEAMGAME_ICON="$STEAMIFY_DATA/steamify.png"

steamgame_files() {
    # Every Steam account's shortcuts.vdf (the file may not exist yet).
    local d
    for d in "$STEAM_ROOT"/userdata/*/config; do
        [[ -d "$d" && "$(basename "$(dirname "$d")")" != 0 ]] && echo "$d/shortcuts.vdf"
    done
}

steamgame_tool() {
    python3 <(patch_file steam-shortcuts.py) "$@"
}

steamgame_available() { [[ -n "$(steamgame_files)" ]]; }

steamgame_status() {
    local f
    while IFS= read -r f; do
        [[ -f "$f" ]] && steamgame_tool find "$f" "$WIZARD_APP_LAUNCHER" >/dev/null && return 0
    done < <(steamgame_files)
    return 1
}

steamgame_steam_busy() {
    # Closing Steam would end what's running: gaming mode is Steam's own
    # session, and a run started from Steam is one of its games.
    if [[ -n "${SteamGameId:-}" ]]; then
        err "Steamify was started from Steam, which has to close for this. Start it from the desktop icon, or run Steamify Terminal."
        return 0
    fi
    if pgrep -x gamescope >/dev/null || pgrep -f gamescope-session >/dev/null; then
        err "Steam has to close for this, which would end gaming mode. Do it from the desktop."
        return 0
    fi
    return 1
}

steamgame_edit() {
    # steamgame_edit <function>: runs it with Steam closed, then starts Steam
    # again if it was running (silently, in the tray).
    local was_running=false i
    if pgrep -x steam >/dev/null; then
        steamgame_steam_busy && return 1
        was_running=true
        info "Closing Steam for a moment (it only reads its games list at startup)..."
        # A Steam that's still starting ignores the request: ask again.
        for ((i = 0; i < 90; i++)); do
            ((i % 15 == 0)) && steam -shutdown >/dev/null 2>&1
            pgrep -x steam >/dev/null || break
            sleep 1
        done
        pgrep -x steam >/dev/null && { err "Steam didn't close; nothing changed."; return 1; }
    fi
    "$1"; local rc=$?
    if [[ "$was_running" == true ]]; then
        systemd-run --user --collect -q steam -silent >/dev/null 2>&1
        info "Steam is starting again."
    fi
    return "$rc"
}

steamgame_icon() {
    # The PNG, or the SVG when it can't be rendered (librsvg comes with KDE).
    if [[ -f "$WIZARD_ICON" ]] && command -v rsvg-convert >/dev/null &&
        mkdir -p "$STEAMIFY_DATA" && rsvg-convert -w 256 -h 256 -o "$STEAMGAME_ICON" "$WIZARD_ICON" 2>/dev/null; then
        echo "$STEAMGAME_ICON"
    else
        echo "$WIZARD_ICON"
    fi
}

steamgame_add_all() {
    local f out icon
    icon="$(steamgame_icon)"
    while IFS= read -r f; do
        # A copy of each account's list before the first change.
        [[ -f "$f" && ! -f "$STATE_DIR/shortcuts-$(basename "$(dirname "$(dirname "$f")")").vdf" ]] &&
            mkdir -p "$STATE_DIR" && cp -a "$f" "$STATE_DIR/shortcuts-$(basename "$(dirname "$(dirname "$f")")").vdf"
        out="$(steamgame_tool add "$f" "$STEAMGAME_NAME" "$WIZARD_APP_LAUNCHER" "$icon" "$WIZARD_APP_ENTRY")" ||
            { err "Couldn't add Steamify to $f."; return 1; }
        state_set steamgame "$(basename "$(dirname "$(dirname "$f")")")" "${out#* } ${out%% *}"
        info "Steam library ($(basename "$(dirname "$(dirname "$f")")")): ${out%% *} $STEAMGAME_NAME."
    done < <(steamgame_files)
}

steamgame_remove_all() {
    local f id
    while IFS= read -r f; do
        [[ -f "$f" ]] || continue
        # Any entry for our start script: it can't start anything without it.
        while id="$(steamgame_tool find "$f" "$WIZARD_APP_LAUNCHER")"; do
            steamgame_tool remove "$f" "$id" || return 1
        done
    done < <(steamgame_files)
}

steamgame_enable() {
    [[ -x "$WIZARD_APP_LAUNCHER" ]] || { err "The Steamify shortcut isn't set up; turn that on first."; return 1; }
    info "Adding $STEAMGAME_NAME to your Steam library..."
    steamgame_edit steamgame_add_all || return 1
    ok "Steamify is in your Steam library (non-Steam games): start it from there for the controller, in gaming mode too."
}

steamgame_disable() {
    info "Removing $STEAMGAME_NAME from your Steam library..."
    steamgame_edit steamgame_remove_all || return 1
    state_clear steamgame
    rm -f "$STEAMGAME_ICON"
    ok "Steamify removed from your Steam library."
}
