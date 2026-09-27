#!/bin/bash
# Output helpers, prompts and small shared utilities.
# Sourced by steamify.sh; not meant to be run on its own.

c_reset="\033[0m"; c_bold="\033[1m"; c_green="\033[32m"; c_yellow="\033[33m"; c_red="\033[31m"; c_cyan="\033[36m"; c_dim="\033[2m"

info()  { echo -e "${c_cyan}[INFO]${c_reset} $*"; }
ok()    { echo -e "${c_green}[OK]${c_reset} $*"; }
# patch_file <name>: a file from patches/ (module sources, patches). The
# single-file build replaces this with one that has them embedded.
patch_file() { cat "$SCRIPT_DIR/patches/$1"; }
# service_file <name> [KEY=value...]: a systemd unit from services/, filled
# in. The single-file build replaces service_raw like patch_file.
service_raw() { cat "$SCRIPT_DIR/services/$1"; }
service_file() { local name="$1"; shift; service_raw "$name" | fill "$@"; }
# fill [KEY=value...]: stdin with each @KEY@ replaced by its value, taken
# literally (a home folder may contain sed's "&", "\" or "|").
fill() {
    local kv v
    local -a subst=(-e '')
    for kv in "$@"; do
        v="${kv#*=}"; v="${v//\\/\\\\}"; v="${v//&/\\&}"; v="${v//|/\\|}"
        subst+=(-e "s|@${kv%%=*}@|$v|g")
    done
    sed "${subst[@]}"
}
warn()  { echo -e "${c_yellow}[WARN]${c_reset} $*"; }
err()   { echo -e "${c_red}[ERROR] $*${c_reset}" >&2; }
ask_yn() {
    local prompt="$1" default="${2:-y}" reply
    local hint="[Y/n]"; [[ "$default" == "n" ]] && hint="[y/N]"
    read -rp "$(echo -e "${c_bold}${prompt}${c_reset} ${hint} ")" reply
    reply="${reply:-$default}"
    [[ "$reply" =~ ^[Yy]$ ]]
}

require_root_helper() {
    # Re-exec any privileged step through sudo rather than requiring the
    # whole script to run as root, so $HOME/whoami stay correct for the
    # target user detection below.
    if [[ $EUID -eq 0 && -z "${SUDO_USER:-}" ]]; then
        err "Please run this script as your normal user (it will call sudo itself), not directly as root."
        exit 1
    fi
}

user_session() {
    # A running user systemd and session bus. Not in the installer's chroot,
    # where the ISO applies Steamify for a user who has never logged in.
    [[ -S "${XDG_RUNTIME_DIR:-/nonexistent}/bus" ]]
}

user_systemctl() {
    # systemctl --user, also without a session: then only the unit files
    # change (enable/disable through --root); starting and stopping is left
    # to the first login, which starts what's enabled anyway.
    if user_session; then systemctl --user "$@"; return; fi
    local a verb="" args=()
    for a in "$@"; do
        [[ "$a" == --now ]] && continue
        [[ -z "$verb" && "$a" != -* ]] && verb="$a"
        args+=("$a")
    done
    case "$verb" in
        enable|disable|is-enabled|mask|unmask) systemctl --user --root=/ "${args[@]}" ;;
        is-active) return 1 ;;
        *) return 0 ;;
    esac
}

plasma_applets() {
    # Print "containment:applet" for every applet of plugin $1 in the
    # user's Plasma layout, for kwriteconfig6 --group paths.
    local conf="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
    [[ -f "$conf" ]] || return 0
    awk -v plugin="$1" '
        /^\[Containments\]\[[0-9]+\]\[Applets\]\[[0-9]+\]$/ { split($0, p, /[][]+/); sect = p[3] ":" p[5] }
        /^\[/ && !/\]\[Applets\]\[[0-9]+\]$/ { sect = "" }
        $0 == "plugin=" plugin && sect != "" { print sect }
    ' "$conf"
}

backup_file() {
    local f="$1"
    if [[ -f "$f" && ! -f "${f}.bak-gamescope-wizard" ]]; then
        sudo cp -a "$f" "${f}.bak-gamescope-wizard"
        info "Backed up $f -> ${f}.bak-gamescope-wizard"
    fi
}

# plasmashell keeps its config in memory and writes it back on exit, so
# edits to its files (panels, applets, wallpaper) must be made while it is
# stopped. It is restarted through systemd so it keeps the session's
# environment (platform theme etc.); a plain --replace from this shell
# may not, which gives a light-themed desktop.
stop_plasmashell_for_edit() {
    PLASMASHELL_WAS_RUNNING=false
    if pgrep -u "$USER" -x plasmashell >/dev/null; then
        PLASMASHELL_WAS_RUNNING=true
        systemctl --user stop plasma-plasmashell.service 2>/dev/null
        pkill -u "$USER" -x plasmashell && sleep 2
    fi
}

restart_plasmashell_if_stopped() {
    if [[ "${PLASMASHELL_WAS_RUNNING:-false}" == true ]]; then
        rm -rf ~/.cache/plasmashell* ~/.cache/org.kde.dirmodel-qml.kcache
        systemctl --user start plasma-plasmashell.service 2>/dev/null ||
            { setsid plasmashell >/dev/null 2>&1 & }
    fi
}
