#!/bin/bash
# "Update notifications" menu item (notify), ticked by default: a systemd
# user timer checks GitHub's newest release once a day and at each Plasma
# login. When it's newer than the last Steamify that ran here, it shows a
# notification (Open Steamify / Skip this version) and a tray icon until
# then; it never updates anything itself (patches/steamify-notifier.py).
# Sourced by steamify.sh; not meant to be run on its own.

NOTIFY_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/cachyos-gamescope-boot"
NOTIFY_SCRIPT="$NOTIFY_DIR/steamify-notifier"
NOTIFY_UNITS="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
NOTIFY_NAME=steamify-update-check

notify_status() {
    [[ -f "$NOTIFY_SCRIPT" ]] &&
        systemctl --user is-enabled -q "$NOTIFY_NAME.timer" 2>/dev/null &&
        systemctl --user is-enabled -q "$NOTIFY_NAME.service" 2>/dev/null
}

notify_seen() {
    # Every run records its version: the notifier compares the newest
    # release with it, so opening Steamify ends a reminder. Also whether it
    # was the app or the terminal menu: the notification opens the same.
    notify_status || return 0
    state_set notify seen "$VERSION"
    if [[ "$BACKEND" == true ]]; then state_set notify frontend app; else state_set notify frontend terminal; fi
}

notify_enable() {
    local p missing=()
    info "Adding update notifications..."
    # PySide6 for the tray icon, notify-send for the notification's buttons.
    python3 -c 'import PySide6.QtWidgets' 2>/dev/null || missing+=(pyside6)
    command -v notify-send >/dev/null || missing+=(libnotify)
    if ((${#missing[@]})); then
        sudo pacman -S --needed --noconfirm "${missing[@]}" ||
            { err "Installing ${missing[*]} failed."; return 1; }
    fi
    patch_file steamify-notifier.py | install_executable "$NOTIFY_SCRIPT" 755 ||
        { err "Couldn't write $NOTIFY_SCRIPT."; return 1; }
    mkdir -p "$NOTIFY_UNITS"
    # PartOf the graphical session: the tray icon goes with a logout. The
    # short wait at login lets the tray come up first (in the script: an
    # ExecStartPre sleep runs into the start timeout).
    cat > "$NOTIFY_UNITS/$NOTIFY_NAME.service" << EOF
[Unit]
Description=Steamify: check for a new release
After=plasma-workspace.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=$NOTIFY_SCRIPT --delay 60

[Install]
WantedBy=plasma-workspace.target
EOF
    cat > "$NOTIFY_UNITS/$NOTIFY_NAME.timer" << EOF
[Unit]
Description=Steamify: check for a new release daily

[Timer]
OnCalendar=daily
RandomizedDelaySec=1h
Persistent=true

[Install]
WantedBy=timers.target
EOF
    systemctl --user daemon-reload
    systemctl --user enable "$NOTIFY_NAME.service" >/dev/null 2>&1 &&
        systemctl --user enable --now "$NOTIFY_NAME.timer" >/dev/null 2>&1 ||
        { err "Enabling the update check failed."; return 1; }
    state_set notify seen "$VERSION"
    ok "Update notifications on: you'll get a notification when there's a new Steamify."
}

notify_disable() {
    systemctl --user disable --now "$NOTIFY_NAME.timer" "$NOTIFY_NAME.service" >/dev/null 2>&1
    rm -f "$NOTIFY_UNITS/$NOTIFY_NAME.service" "$NOTIFY_UNITS/$NOTIFY_NAME.timer" "$NOTIFY_SCRIPT"
    rmdir "$NOTIFY_DIR" 2>/dev/null || true
    systemctl --user daemon-reload
    state_clear notify
    ok "Update notifications off."
}
