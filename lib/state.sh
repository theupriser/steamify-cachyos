#!/bin/bash
# Undo journal for per-user KDE settings, so every component can be turned
# off again exactly: the first time a component changes a key, the key's
# previous value is recorded, and reverting the component puts it back (or
# deletes the key if it didn't exist before).
# Sourced by steamify.sh; not meant to be run on its own.

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/steamify"
# Steamify's own files in the home folder: the app (app/, from
# steamify-app.sh) and the shortcut's and notifier's scripts (bin/).
STEAMIFY_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/steamify"
STEAMIFY_BIN="$STEAMIFY_DATA/bin"
UNSET=$'\x01'

kset() {
    # kset <component> <file> <group[|group...]> <key> <value>
    # kwriteconfig6, recording the old value in the component's journal.
    # <value> "--delete" removes the key.
    local component="$1" file="$2" groups="$3" key="$4" value="$5"
    local journal="$STATE_DIR/$component.journal" old id
    local -a gargs=() g
    local groups_item
    IFS='|' read -ra g <<< "$groups"
    for groups_item in "${g[@]}"; do gargs+=(--group "$groups_item"); done

    mkdir -p "$STATE_DIR"
    id="$(printf '%s\t%s\t%s' "$file" "$groups" "$key")"
    if ! grep -qxF -- "$id" <(cut -f1-3 "$journal" 2>/dev/null); then
        old="$(kreadconfig6 --file "$file" "${gargs[@]}" --key "$key" --default "$UNSET")"
        printf '%s\t%s\n' "$id" "$(printf '%s' "$old" | base64 -w0)" >> "$journal"
    fi

    if [[ "$value" == "--delete" ]]; then
        kwriteconfig6 --file "$file" "${gargs[@]}" --key "$key" --delete
    else
        kwriteconfig6 --file "$file" "${gargs[@]}" --key "$key" "$value"
    fi
}

krevert() {
    # krevert <component>: restore every key the component changed, newest
    # first, then forget the journal.
    local component="$1"
    local journal="$STATE_DIR/$component.journal"
    local file groups key old groups_item
    local -a g
    [[ -f "$journal" ]] || return 0
    while IFS=$'\t' read -r file groups key old; do
        local -a gargs=()
        IFS='|' read -ra g <<< "$groups"
        for groups_item in "${g[@]}"; do gargs+=(--group "$groups_item"); done
        old="$(printf '%s' "$old" | base64 -d)"
        if [[ "$old" == "$UNSET" ]]; then
            kwriteconfig6 --file "$file" "${gargs[@]}" --key "$key" --delete
        else
            kwriteconfig6 --file "$file" "${gargs[@]}" --key "$key" "$old"
        fi
    done < <(tac "$journal")
    rm -f "$journal"
}

has_journal() {
    [[ -s "$STATE_DIR/$1.journal" ]]
}

state_set() {
    # state_set <component> <name> <value>: remember a value for later.
    mkdir -p "$STATE_DIR"
    kwriteconfig6 --file "$STATE_DIR/$1.state" --group State --key "$2" "$3"
}

state_get() {
    # state_get <component> <name> [default]
    kreadconfig6 --file "$STATE_DIR/$1.state" --group State --key "$2" --default "${3:-}"
}

state_clear() {
    rm -f "$STATE_DIR/$1.state"
}

current_display_manager() {
    systemctl show -p Id --value display-manager 2>/dev/null | sed 's/\.service$//'
}

migrate_dir() {
    # migrate_dir <old> <new>: moves <old> to <new> and leaves a symlink.
    # When both exist (an older release ran after a newer one), what <new>
    # lacks is moved over; a file in both keeps <new>'s copy and <old> stays
    # as it is. Returns 0 when something moved.
    local old="$1" new="$2" f moved=1
    [[ -d "$old" && ! -L "$old" ]] || return 1
    if [[ ! -e "$new" ]]; then
        mkdir -p "$(dirname "$new")"
        mv "$old" "$new" && ln -s "$new" "$old"
        return 0
    fi
    for f in "$old"/* "$old"/.[!.]*; do
        [[ -e "$f" || -L "$f" ]] || continue
        [[ -e "$new/${f##*/}" ]] && continue
        mv "$f" "$new/" && moved=0
    done
    rmdir "$old" 2>/dev/null && ln -s "$new" "$old"
    return "$moved"
}

migrate_layout() {
    # Before 2.5.0 the state and scripts were under the project's old name
    # (cachyos-gamescope-boot). Moved once; the old names stay as symlinks,
    # so an older release that still runs finds the same state.
    local old_state="${XDG_STATE_HOME:-$HOME/.local/state}/cachyos-gamescope-boot"
    local old_bin="${XDG_DATA_HOME:-$HOME/.local/share}/cachyos-gamescope-boot"
    local old_icon="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/scalable/apps/cachyos-gamescope-boot-wizard.svg"
    local f
    # Links left pointing at nothing once their component was turned off.
    for f in "$old_state" "$old_bin"; do [[ -L "$f" && ! -e "$f" ]] && rm -f "$f"; done
    migrate_dir "$old_state" "$STATE_DIR"
    if migrate_dir "$old_bin" "$STEAMIFY_BIN"; then
        # The notifier had the old paths built in; its unit and the
        # shortcut's entries point at the scripts.
        [[ -f "$STEAMIFY_BIN/steamify-notifier" ]] &&
            patch_file steamify-notifier.py | install_executable "$STEAMIFY_BIN/steamify-notifier" 755
        for f in "$NOTIFY_UNITS/$NOTIFY_NAME.service" "$WIZARD_APP_ENTRY" "$WIZARD_TERMINAL_ENTRY" \
            "$(wizard_desktop_dir)/$WIZARD_DESKTOP_NAME"; do
            [[ -f "$f" ]] && sed -i "s|$old_bin/|$STEAMIFY_BIN/|g" "$f"
        done
        systemctl --user daemon-reload 2>/dev/null
    fi
    if [[ -f "$old_icon" ]]; then
        if [[ -e "$WIZARD_ICON" ]]; then rm -f "$old_icon"; else mv "$old_icon" "$WIZARD_ICON"; fi
        gtk-update-icon-cache -q -f -t "$(dirname "$(dirname "$(dirname "$WIZARD_ICON")")")" 2>/dev/null || true
    fi
    for f in "$WIZARD_APP_ENTRY" "$WIZARD_TERMINAL_ENTRY" "$(wizard_desktop_dir)/$WIZARD_DESKTOP_NAME"; do
        [[ -f "$f" ]] && grep -q '^Icon=cachyos-gamescope-boot-wizard$' "$f" &&
            sed -i 's|^Icon=cachyos-gamescope-boot-wizard$|Icon=steamify|' "$f"
    done
    return 0
}
