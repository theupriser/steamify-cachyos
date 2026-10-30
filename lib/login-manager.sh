#!/bin/bash
# Booting into gaming mode: autologin into gamescope with
# plasma-login-manager (CachyOS's login manager). The session is chosen by
# conf.d fragments only (see configure_autologin), so what steam-set-session
# and steamos-manager write is honoured without a bridge. With single user
# mode on the PC logs in by itself at every start; with it off it boots to the
# login screen, and only a session switch logs in again by itself
# (relogin_helper_install).
# Sourced by steamify.sh; not meant to be run on its own.

BASE_CONF="/etc/plasmalogin.conf"
GDM_CONF="/etc/gdm/custom.conf"
GDM_FIX_DIR=/usr/local/share/steamify-gdm
GDM_HOOK=/etc/pacman.d/hooks/95-steamify-gdm.hook
GDM_SUDOERS=/etc/sudoers.d/steamify-gdm-relogin
GDM_RELOGIN=/usr/local/libexec/steamify-gdm-relogin
CONF_DIR="/etc/plasmalogin.conf.d"
AUTOLOGIN_CONF="$CONF_DIR/10-gamescope-autologin.conf"
# One drop-in for plasmalogin.service (plasmalogin_dropin_write). Before 2.16.0 it was two files.
PLM_DROPIN="/etc/systemd/system/plasmalogin.service.d/zz-steamify.conf"
OLD_PLM_DROPINS=(/etc/systemd/system/plasmalogin.service.d/zz-steamify-temp-login.conf
    /etc/systemd/system/plasmalogin.service.d/zz-steamify-greeter-session.conf)
RELOGIN_CONF="$CONF_DIR/zzt-steamify-relogin.conf"
RELOGIN_SCRIPT="/usr/local/libexec/steamify-relogin"
RELOGIN_UNIT="steamify-relogin"
GREETER_SCRIPT="/usr/local/libexec/steamify-greeter-session"

# The "SteamOS conversion" menu item: gaming mode boot, the Return to
# Gaming Mode shortcut and Steam on the desktop (lib/steam-desktop.sh).
gaming_status() {
    # Autologin into gamescope is configured for this user. The layouts of
    # versions before 2.12.1 count as on too: the update (feature_outdated)
    # moves them to the current one.
    case "$(current_display_manager)" in
        plasmalogin)
            plasmalogin_conversion_installed && return 0
            grep -qx "User=$USER" "$AUTOLOGIN_CONF" 2>/dev/null && return 0
            # Autologin in the base config, plus the sync bridge.
            sed -n '/^\[Autologin\]/,/^\[/p' "$BASE_CONF" 2>/dev/null | grep -qx "User=$USER" &&
                [[ -f /etc/systemd/system/sync-steamos-session.path ]] ;;
        gdm)
            sed -n '/^\[daemon\]/,/^\[/p' /etc/gdm/custom.conf 2>/dev/null | grep -qx "AutomaticLogin=$USER" &&
                [[ -f "$GDM_FIX_DIR/steam-set-session" ]] ;;
        sddm) [[ -f /etc/sddm.conf.d/10-gamescope-autologin.conf ]] ;;
        *) return 1 ;;
    esac
}

# What Steam shows in its System settings besides the OS name (which stays
# CachyOS's, for legal clarity and because limine-snapper-sync finds the boot
# entries by it): the SteamOS release as the OS version, steam-machine as the
# codename, Steamify with its version as the variant (os-release VERSION_ID,
# VERSION_CODENAME, VARIANT_ID; see patches/steamify-os-release.sh).
OS_NAME_SCRIPT=/usr/local/libexec/steamify-os-release
OS_NAME_HOOK=/etc/pacman.d/hooks/zz-steamify-os-release.hook
# limine's tools take the OS name from TARGET_OS_NAME, else os-release's
# PRETTY_NAME: pinned to CachyOS, the boot entries never depend on os-release.
LIMINE_DEFAULTS=/etc/default/limine

steamos_release() {
    # The SteamOS release Steamify follows: Valve's newest jupiter-X.Y repo
    # (where the SteamOS extras come from), as an os-release ID (no spaces or
    # capitals: steamos-3.9). Offline (e.g. in the installer): the one set
    # before, if any.
    local v
    v="$(valve_newest_repo jupiter 15)"
    if [[ -n "$v" ]]; then echo "steamos-${v#jupiter-}"
    else sed -n 's/^VERSION_ID=\(steamos-.*\)$/\1/p' /etc/os-release 2>/dev/null; fi
}

os_name_enable() {
    # 2.9.0 pre-releases renamed the OS itself; the name stays CachyOS's.
    if grep -q '^DISTRIB_DESCRIPTION=.*with Steamify' /etc/lsb-release 2>/dev/null &&
        [[ -x /usr/share/libalpm/scripts/cachyos-branding ]]; then
        sudo /usr/share/libalpm/scripts/cachyos-branding lsb-release
    fi
    [[ -n "$(kreadconfig6 --file kcm-about-distrorc --group General --key Name 2>/dev/null)" ]] &&
        kset gaming kcm-about-distrorc General Name --delete
    # About this System: os-release's VERSION (CachyOS has none) instead of
    # VERSION_ID, which is the SteamOS release now.
    kset gaming kcm-about-distrorc General UseOSReleaseVersion true
    patch_file steamify-os-release.sh | fill VERSION="$VERSION" STEAMOS="$(steamos_release)" |
        sudo install -Dm755 /dev/stdin "$OS_NAME_SCRIPT" &&
        patch_file steamify-os-release.hook | fill SCRIPT="$OS_NAME_SCRIPT" |
            sudo install -Dm644 /dev/stdin "$OS_NAME_HOOK" &&
        sudo "$OS_NAME_SCRIPT" || { err "Setting Steamify's version for Steam failed."; return 1; }
    if [[ -f "$LIMINE_DEFAULTS" ]] && ! grep -q '^TARGET_OS_NAME=' "$LIMINE_DEFAULTS"; then
        backup_file "$LIMINE_DEFAULTS"
        printf '%s\n' 'TARGET_OS_NAME="CachyOS"' | sudo tee -a "$LIMINE_DEFAULTS" > /dev/null
        state_set gaming limine_target 1
    fi
    return 0
}

os_name_disable() {
    sudo rm -f "$OS_NAME_HOOK" "$OS_NAME_SCRIPT"
    [[ -f /etc/os-release ]] && sudo sed -i -e '/^VARIANT=/d' -e '/^VARIANT_ID=/d' -e '/^VERSION_ID=/d' -e '/^VERSION_CODENAME=/d' /etc/os-release
    # CachyOS's own values back, the way its hooks write them.
    if [[ -x /usr/share/libalpm/scripts/cachyos-branding ]]; then
        sudo /usr/share/libalpm/scripts/cachyos-branding os-release
        # Undoes 2.9.0 pre-releases, which changed lsb-release's name too.
        sudo /usr/share/libalpm/scripts/cachyos-branding lsb-release
    fi
    if [[ -n "$(state_get gaming limine_target)" ]]; then
        sudo sed -i '/^TARGET_OS_NAME="CachyOS"$/d' "$LIMINE_DEFAULTS"
        state_set gaming limine_target ""
    fi
    return 0
}

os_version_refresh() {
    # After every run that changed something (sudo is at hand then): Steam's
    # OS version follows Steamify's, not just the one that set it up. Silent:
    # the app reads the backend's stdout as JSON.
    gaming_status 2>/dev/null || return 0
    grep -qx "VARIANT_ID=steamify-$VERSION" /etc/os-release 2>/dev/null && return 0
    os_name_enable > /dev/null 2>&1
    return 0
}

gaming_enable() {
    local login_manager
    login_manager="$(choose_login_manager)"
    install_required_packages || return 1
    # NVIDIA: gamescope's picture is corrupted unless it is the patched one (no-op elsewhere).
    gsn_enable || return 1
    case "$login_manager" in
        plasmalogin)
            switch_to_plasmalogin || return 1
            remove_legacy_login_setup
            configure_autologin || return 1
            ;;
        gdm)
            # GNOME (prototype): GDM autologin, plus CachyOS's session tools made GDM-aware.
            remove_legacy_login_setup
            remove_autologin_conf
            switch_to_gdm || return 1
            configure_gdm_autologin || return 1
            ;;
    esac
    # CachyOS's own session tools only go to Plasma and only know plasma-login-manager: with GNOME installed ours replace them.
    if [[ "$login_manager" == gdm ]] || desktop_installed gnome; then session_tools_install "$login_manager" || return 1; fi
    # (NVIDIA with single user mode from before the conversion: its desktop autologin would pin the Plasma session.)
    single_login_release
    systemd_reload
    create_desktop_shortcut
    steam_enable
    os_name_enable || return 1
}

gaming_disable() {
    # Back to a normal desktop boot with CachyOS's default login manager.
    # Packages (steam, gamescope-session-cachyos, ...) are kept.
    info "Turning off booting into gaming mode..."
    remove_legacy_login_setup
    session_tools_remove
    remove_autologin_conf
    if [[ "$(current_display_manager)" == gdm ]]; then
        restore_gdm_config
    else
        restore_plasmalogin_config
        switch_to_plasmalogin
    fi
    systemd_reload
    remove_desktop_shortcut
    steam_disable
    gsn_disable
    krevert gaming
    os_name_disable
    # NVIDIA with single user mode still on: nothing else logs in by itself any more.
    nvidia_present && single_status && single_login_enable
    gnome_extras_release
    ok "The PC boots to the normal login screen again (from the next boot)."
}

switch_to_plasmalogin() {
    [[ "$(current_display_manager)" == plasmalogin ]] && return 0
    info "Switching the login manager to plasma-login-manager..."
    sudo pacman -S --needed --noconfirm plasma-login-manager || { err "Installing plasma-login-manager failed."; return 1; }
    local current
    current="$(systemctl show -p Id --value display-manager 2>/dev/null)"
    [[ -n "$current" && "$current" != plasmalogin.service ]] && sudo systemctl disable "$current"
    sudo systemctl enable -f plasmalogin.service || { err "Enabling plasmalogin failed."; return 1; }
    ok "plasma-login-manager is the login manager from the next boot on."
}

# --- Files for systemd (units and drop-ins) are written and removed through these; they only mark that
# systemd has to read them again, and systemd_reload does that once (before something is enabled or
# started, and at the end of a step).
SYSTEMD_RELOAD_PENDING=false

unit_write() {
    # unit_write <path>: stdin becomes the file, as root (its folder is made).
    sudo mkdir -p "$(dirname "$1")" && sudo tee "$1" > /dev/null || return 1
    SYSTEMD_RELOAD_PENDING=true
}

unit_remove() {
    # unit_remove <path>...: removes what exists.
    local f
    for f in "$@"; do
        [[ -e "$f" ]] || continue
        sudo rm -f "$f" && SYSTEMD_RELOAD_PENDING=true
    done
    return 0
}

systemd_reload() {
    [[ "$SYSTEMD_RELOAD_PENDING" == true ]] || return 0
    sudo systemctl daemon-reload && SYSTEMD_RELOAD_PENDING=false
}

# --- What earlier versions left behind. One function, called when the conversion is set up or turned off
# (and by single user mode's own login step), so an update leaves nothing of an older layout.
remove_legacy_login_setup() {
    # SDDM: single user mode before 2.12.1 put the PC on it. steam-set-session's file for it only matters
    # while SDDM is the login manager.
    best_effort sudo rm -f /etc/sddm.conf.d/10-gamescope-autologin.conf /etc/sddm.conf.d/zzz-steamify-autologin.conf
    [[ "$(current_display_manager)" == sddm ]] || best_effort sudo rm -f /etc/sddm.conf.d/zz-steamos-autologin.conf
    best_effort sudo rmdir /etc/sddm.conf.d
    # The session sync bridge (before 2.13.0 it copied the session into the base config, which has none now).
    if [[ -f /etc/systemd/system/sync-steamos-session.path ]]; then
        info "Removing the old session sync bridge (not needed any more)..."
        best_effort sudo systemctl disable --now sync-steamos-session.path
    fi
    unit_remove /etc/systemd/system/sync-steamos-session.path /etc/systemd/system/sync-steamos-session.service \
        /usr/local/bin/sync-steamos-session.sh
    # The shortcut restarted the login manager through this rule (before 2.13.0).
    best_effort sudo rm -f /etc/sudoers.d/gamescope-session-switch
    # The two drop-ins of 2.13.x (one file now) and manual attempts at an autologin fragment.
    unit_remove "${OLD_PLM_DROPINS[@]}"
    best_effort sudo rm -f "$CONF_DIR"/zzz-steamos-autologin*.conf
}

# --- plasma-login-manager and the conversion: one drop-in, one fragment, the helpers of multi-user mode.
plasmalogin_conversion_installed() { [[ -f "$PLM_DROPIN" || -f "${OLD_PLM_DROPINS[0]}" ]]; }

plasmalogin_dropin_write() {
    # plasmalogin_dropin_write single|multi. plasma-login-manager lists the conf.d files once, when it
    # starts: a file created later (the one-shot login steamos-manager writes for Steam's "Switch to
    # Desktop") is never read, and the login manager logs straight back in to gamescope. steamos-manager's
    # own drop-in removes those files at every start, so ours (it sorts after) creates them empty, which puts
    # them on the list. The relogin file of multi-user mode is emptied too: a start of the login manager is
    # a fresh boot (or restart) to the login screen, and there the login screen preselects "Boot into".
    {
        echo "[Service]"
        echo "ExecStartPre=-/usr/bin/touch $CONF_DIR/zzt-holo-temp-login.conf $CONF_DIR/zzt-steamos-temp-login.conf"
        echo "ExecStartPre=-/bin/sh -c ': > $RELOGIN_CONF'"
        # (An if, not "&&": the group's status is the pipeline's under pipefail.)
        if [[ "$1" == multi ]]; then echo "ExecStartPre=-$GREETER_SCRIPT"; fi
    } | unit_write "$PLM_DROPIN"
}

remove_autologin_conf() {
    # Our fragment and what steam-set-session / steamos-manager wrote: the session they name would still
    # beat the restored base config. And everything of ours that goes with them.
    sudo rm -f "$AUTOLOGIN_CONF" "$CONF_DIR"/zz-steamos-autologin.conf "$CONF_DIR"/zzt-*-temp-login.conf
    relogin_helper_remove
    unit_remove "$GREETER_SCRIPT" "$PLM_DROPIN"
}

restore_plasmalogin_config() {
    # Put back the original /etc/plasmalogin.conf from the first run's
    # backup, or at least drop our [Autologin] section.
    if [[ -f "${BASE_CONF}.bak-gamescope-wizard" ]]; then
        sudo cp -a "${BASE_CONF}.bak-gamescope-wizard" "$BASE_CONF"
    elif [[ -f "$BASE_CONF" ]]; then
        sudo awk '/^\[Autologin\]/ { skip=1; next } /^\[/ { skip=0 } !skip { print }' "$BASE_CONF" |
            sudo tee "${BASE_CONF}.tmp" > /dev/null && sudo mv "${BASE_CONF}.tmp" "$BASE_CONF"
    fi
}

remove_base_autologin() {
    # The base config beats conf.d: an [Autologin] there would override every
    # session switch.
    if [[ -f "$BASE_CONF" ]] && grep -q '^\[Autologin\]' "$BASE_CONF"; then
        backup_file "$BASE_CONF"
        sudo awk '/^\[Autologin\]/ { skip=1; next } /^\[/ { skip=0 } !skip { print }' "$BASE_CONF" |
            sudo tee "${BASE_CONF}.tmp" > /dev/null && sudo mv "${BASE_CONF}.tmp" "$BASE_CONF"
        info "Removed [Autologin] from $BASE_CONF (backup kept)."
    fi
}

configure_autologin() {
    # The base config has no [Autologin] (CachyOS ships Session=plasma there, and the base config beats
    # conf.d). The session comes from conf.d: steam-set-session writes zz-steamos-autologin.conf and
    # steamos-manager zzt-holo-temp-login.conf, which win over the default (the latter only if it existed
    # when the login manager started: plasmalogin_dropin_write). Who logs in by itself, and when, is
    # set_login_mode.
    info "Configuring plasma-login-manager for $TARGET_USER, starting in gamescope..."
    sudo mkdir -p "$CONF_DIR" || return 1
    remove_base_autologin
    # A one-shot switch left over.
    sudo rm -f "$CONF_DIR"/zzt-*-temp-login.conf
    # Start in gamescope, through CachyOS's own tool so its file is current.
    sudo /usr/lib/steamos/steam-set-session gamescope-session.desktop || return 1
    login_mode_apply "$(is_wanted single && echo single || echo multi)" || return 1
    echo
}

set_login_mode() {
    # single user mode turned on (single) or off (multi) while the conversion is installed: the one place
    # that changes how the PC logs in. Nothing to do without the conversion on plasma-login-manager.
    plasmalogin_conversion_installed || return 0
    login_mode_apply "$1" && systemd_reload
}

login_mode_apply() {
    # login_mode_apply single|multi
    #   single - autologin at every start (our fragment);
    #   multi  - the login screen at start: only a session switch logs in again (the helper's --relogin), and
    #            the login screen preselects what "Boot into" says (the greeter session script).
    # The session helper is there in both: the last pick of a session wins over a stale one-shot login.
    case "$1" in
        single)
            unit_remove "$GREETER_SCRIPT"
            sudo rm -f "$RELOGIN_CONF"
            relogin_helper_install "" || return 1
            plasmalogin_dropin_write single || return 1
            sudo tee "$AUTOLOGIN_CONF" > /dev/null << EOF || return 1
[Autologin]
User=$TARGET_USER
Session=gamescope-session.desktop
Relogin=true
EOF
            systemd_reload
            sudo systemctl enable --now "$RELOGIN_UNIT.path" || return 1
            ok "Single user: autologin for $TARGET_USER."
            ;;
        multi)
            sudo rm -f "$AUTOLOGIN_CONF"
            relogin_helper_install --relogin || return 1
            patch_file steamify-greeter-session.sh | fill USER="$TARGET_USER" | sudo install -Dm755 /dev/stdin "$GREETER_SCRIPT" || return 1
            plasmalogin_dropin_write multi || return 1
            systemd_reload
            sudo systemctl enable --now "$RELOGIN_UNIT.path" || return 1
            best_effort sudo "$GREETER_SCRIPT"
            ok "Multi-user: the PC starts at the login screen; switching between gaming mode and the desktop logs in again by itself."
            ;;
        *) return 1 ;;
    esac
}

relogin_helper_install() {
    # relogin_helper_install <args of the script>: --relogin in multi-user mode, nothing in single user mode.
    patch_file steamify-relogin.sh | sudo install -Dm755 /dev/stdin "$RELOGIN_SCRIPT" || return 1
    service_file "$RELOGIN_UNIT.path" | unit_write "/etc/systemd/system/$RELOGIN_UNIT.path" || return 1
    service_file "$RELOGIN_UNIT.service" ARGS="${1:-}" | unit_write "/etc/systemd/system/$RELOGIN_UNIT.service"
}

relogin_helper_remove() {
    [[ -f "/etc/systemd/system/$RELOGIN_UNIT.path" ]] && best_effort sudo systemctl disable --now "$RELOGIN_UNIT.path"
    unit_remove "/etc/systemd/system/$RELOGIN_UNIT.path" "/etc/systemd/system/$RELOGIN_UNIT.service" "$RELOGIN_SCRIPT" "$RELOGIN_CONF"
}

switch_to_gdm() {
    # Already the login manager on a GNOME install; this only makes sure it is installed and enabled.
    [[ "$(current_display_manager)" == gdm ]] && return 0
    info "Installing and enabling GDM..."
    sudo pacman -S --needed --noconfirm gdm || { err "Installing gdm failed."; return 1; }
    local current
    current="$(systemctl show -p Id --value display-manager 2>/dev/null)"
    [[ -n "$current" && "$current" != gdm.service ]] && sudo systemctl disable "$current"
    sudo systemctl enable -f gdm.service || { err "Enabling gdm failed."; return 1; }
    ok "GDM is the login manager from the next boot on."
}

configure_gdm_autologin() {
    # [daemon] AutomaticLogin: GDM reads it when it starts, which is why the
    # session tools restart GDM to log in again (see patches/steamify-gdm-session-select.sh).
    info "Configuring GDM autologin for $TARGET_USER"
    sudo mkdir -p /etc/gdm
    sudo touch "$GDM_CONF"
    [[ -f "$GDM_CONF.bak-steamify" ]] || sudo cp -a "$GDM_CONF" "$GDM_CONF.bak-steamify"
    sudo awk '
        /^\[daemon\]/ { print; indaemon=1; next }
        /^\[/ { indaemon=0 }
        indaemon && /^(AutomaticLoginEnable|AutomaticLogin)=/ { next }
        { print }
    ' "$GDM_CONF" | sudo tee "$GDM_CONF.tmp" > /dev/null
    grep -q '^\[daemon\]' "$GDM_CONF.tmp" || printf '[daemon]\n' | sudo tee -a "$GDM_CONF.tmp" > /dev/null
    sudo sed -i "/^\[daemon\]/a AutomaticLoginEnable=True\nAutomaticLogin=$TARGET_USER" "$GDM_CONF.tmp"
    sudo mv "$GDM_CONF.tmp" "$GDM_CONF"
    ok "GDM autologin configured."
}

restore_gdm_config() {
    if [[ -f "$GDM_CONF.bak-steamify" ]]; then
        sudo cp -a "$GDM_CONF.bak-steamify" "$GDM_CONF" && sudo rm -f "$GDM_CONF.bak-steamify"
    else
        sudo sed -i '/^AutomaticLoginEnable=/d;/^AutomaticLogin=/d' "$GDM_CONF" 2>/dev/null
    fi
}

session_tools_install() {
    # CachyOS's steam-set-session and steamos-session-select only know
    # plasma-login-manager and KDE. Ours replace them at the same paths
    # (Steam's Switch to Desktop calls them by path); a pacman hook puts them
    # back after every update of gamescope-session-cachyos.
    info "Making the session switching GDM-aware..."
    sudo mkdir -p "$GDM_FIX_DIR"
    patch_file steamify-gdm-steam-set-session.sh | sudo install -Dm755 /dev/stdin "$GDM_FIX_DIR/steam-set-session" &&
        patch_file steamify-gdm-session-select.sh |
            sudo install -Dm755 /dev/stdin "$GDM_FIX_DIR/steamos-session-select" || { err "Installing the GDM session tools failed."; return 1; }
    patch_file steamify-gdm.hook | fill DIR="$GDM_FIX_DIR" | sudo install -Dm644 /dev/stdin "$GDM_HOOK"
    if [[ "$(current_display_manager)" == gdm || "${1:-}" == gdm ]]; then
        # steamos-session-select logs in again through this helper (no password: it runs from the gaming session and from a shortcut).
        patch_file steamify-gdm-relogin.sh | sudo install -Dm755 /dev/stdin "$GDM_RELOGIN"
        echo "$TARGET_USER ALL=(root) NOPASSWD: $GDM_RELOGIN" | sudo install -Dm440 /dev/stdin "$GDM_SUDOERS"
        sudo visudo -cf "$GDM_SUDOERS" > /dev/null || { sudo rm -f "$GDM_SUDOERS"; err "The sudoers rule for GDM is invalid."; return 1; }
    fi
    for f in /usr/lib/steamos/steam-set-session /usr/bin/steamos-session-select; do
        [[ -f "$f" && ! -f "$f.bak-steamify" ]] && sudo cp -a "$f" "$f.bak-steamify"
    done
    sudo install -m755 "$GDM_FIX_DIR/steam-set-session" /usr/lib/steamos/steam-set-session &&
        sudo install -m755 "$GDM_FIX_DIR/steamos-session-select" /usr/bin/steamos-session-select || return 1
    # Start in gamescope, as with the other login managers.
    sudo /usr/lib/steamos/steam-set-session gamescope-session.desktop
    ok "GDM autologin into gamescope is set up."
}

session_tools_remove() {
    sudo rm -f "$GDM_HOOK" "$GDM_SUDOERS" "$GDM_RELOGIN"
    for f in /usr/lib/steamos/steam-set-session /usr/bin/steamos-session-select; do
        [[ -f "$f.bak-steamify" ]] && sudo mv "$f.bak-steamify" "$f"
    done
    sudo rm -rf "$GDM_FIX_DIR"
}
