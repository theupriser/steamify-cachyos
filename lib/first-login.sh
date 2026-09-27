#!/bin/bash
# The ISO applies Steamify in the installer, before the user ever logged
# in (steamify.sh --defaults without a session). What needs Plasma's first
# layout is finished at the first desktop login, by a one-time autostart
# that then opens the app, next to CachyOS Hello.
# Sourced by steamify.sh; not meant to be run on its own.

FIRST_LOGIN_ENTRY="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/steamify-first-login.desktop"
FIRST_LOGIN_SCRIPT="$STEAMIFY_BIN/first-login"

first_login_schedule() {
    install_executable "$FIRST_LOGIN_SCRIPT" 755 << EOF2
#!/bin/bash
# Installed by Steamify CachyOS: runs once, at the first desktop login.
set -o pipefail
curl -fsSL --max-time 30 "$WIZARD_URL" | bash -s -- --first-login
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
    if single_status; then
        stop_plasmashell_for_edit
        single_launcher
        restart_plasmashell_if_stopped
    fi
    return 0
}
