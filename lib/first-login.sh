#!/bin/bash
# The ISO applies Steamify in the installer, before the user ever logged
# in (steamify.sh --defaults without a session). What needs Plasma's first
# layout is finished at the first desktop login, by a one-time autostart
# that then opens the app, next to CachyOS Hello.
# Sourced by steamify.sh; not meant to be run on its own.

FIRST_LOGIN_ENTRY="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/steamify-first-login.desktop"
FIRST_LOGIN_SCRIPT="$STEAMIFY_BIN/first-login"
FIRST_LOGIN_BUNDLE="$STEAMIFY_BIN/first-login-steamify.sh"

first_login_schedule() {
    # The newest release's Steamify runs at the first login. STEAMIFY_NO_DOWNLOAD (the ISO was started with
    # steamify.nodownload, to test an unreleased Steamify): this very bundle runs instead.
    # (Only a single-file bundle can be copied; SCRIPT_DIR doesn't exist in one.)
    local run self="${BASH_SOURCE[0]:-}"
    if [[ -n "${STEAMIFY_NO_DOWNLOAD:-}" && -f "$self" ]] && grep -q '^# Single-file build' "$self"; then
        install_executable "$FIRST_LOGIN_BUNDLE" 755 < "$self"
        run="bash \"$FIRST_LOGIN_BUNDLE\" --first-login; rm -f \"$FIRST_LOGIN_BUNDLE\""
    else
        run="curl -fsSL --max-time 30 \"$WIZARD_URL\" | bash -s -- --first-login"
    fi
    install_executable "$FIRST_LOGIN_SCRIPT" 755 << EOF2
#!/bin/bash
# Installed by Steamify CachyOS: runs once, at the first desktop login.
set -o pipefail
mkdir -p ~/.cache
{ $run; } > ~/.cache/steamify-first-login.log 2>&1
rm -f "$FIRST_LOGIN_ENTRY" "\$0"
[[ -x "$WIZARD_APP_LAUNCHER" ]] && exec "$WIZARD_APP_LAUNCHER"
EOF2
    printf '%s\n' '[Desktop Entry]' 'Type=Application' 'Name=Steamify first login' \
        "Exec=$FIRST_LOGIN_SCRIPT" 'OnlyShowIn=KDE;' 'X-KDE-autostart-phase=2' 'NoDisplay=true' |
        install_executable "$FIRST_LOGIN_ENTRY" 644
}

first_login_run() {
    # plasmashell has just laid out the desktop from the look-and-feel
    # package; wait for its config, then put single user's launcher
    # settings on the new launcher.
    local _
    for _ in $(seq 30); do
        [[ -n "$(plasma_applets org.kde.plasma.kickoff)" ]] && break
        sleep 2
    done
    stop_plasmashell_for_edit
    taskbar_drop_discover
    single_status && single_launcher
    restart_plasmashell_if_stopped
    return 0
}
