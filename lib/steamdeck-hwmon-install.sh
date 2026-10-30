#!/bin/bash
# Idempotent installation of Fremont fan monitoring/control. It prepares DKMS,
# the CachyOS package and module autoloading for the next boot, but never loads
# modules or starts/stops/restarts the service.
# Sourced by steamify.sh; not meant to be run on its own.

STEAMDECK_SOURCE_MARKER_TEXT="Steamify $STEAMDECK_OWN_DKMS_PACKAGE/$STEAMDECK_DKMS_VERSION"

steamdeck_run_root() {
    sudo "$@"
}

steamdeck_install_fail() {
    err "$1"
    return 1
}

steamdeck_note_system_change() {
    STEAMDECK_SYSTEM_CHANGED=1
}

steamdeck_service_enabled_state() {
    local state
    state="$(systemctl is-enabled "$STEAMDECK_JUPITER_UNIT" 2>/dev/null || true)"
    steamdeck_ownership_unit_state_valid "$state" && printf '%s\n' "$state" || printf '%s\n' unknown
}

steamdeck_service_active_state() {
    local state
    state="$(systemctl is-active "$STEAMDECK_JUPITER_UNIT" 2>/dev/null || true)"
    case "$state" in
        active|inactive|failed|activating|deactivating) printf '%s\n' "$state" ;;
        *) printf '%s\n' unknown ;;
    esac
}

steamdeck_jupiter_vendor_wants_valid() {
    local vendor_dir="${STEAMDECK_SYSTEMD_VENDOR_DIR:-/usr/lib/systemd/system}"
    local unit="$vendor_dir/$STEAMDECK_JUPITER_UNIT"
    local wants="$vendor_dir/multi-user.target.wants/$STEAMDECK_JUPITER_UNIT"

    [[ -f "$unit" && -L "$wants" ]] || return 1
    [[ "$(readlink -f "$wants" 2>/dev/null)" == "$(readlink -f "$unit" 2>/dev/null)" ]] || return 1
    [[ "$(pacman -Qqo "$unit" 2>/dev/null)" == "$STEAMDECK_JUPITER_PACKAGE" ]] || return 1
    [[ "$(pacman -Qqo "$wants" 2>/dev/null)" == "$STEAMDECK_JUPITER_PACKAGE" ]]
}

steamdeck_installed_kernels() {
    local directory
    for directory in "$STEAMDECK_MODULES_ROOT"/*; do
        [[ -d "$directory" && -f "$directory/pkgbase" ]] || continue
        basename "$directory"
    done
}

steamdeck_autoload_content() {
    printf '%s\n' '# Written by Steamify: Fremont fan monitoring and control.' steamdeck steamdeck_hwmon
}

steamdeck_autoload_matches() {
    [[ -f "$STEAMDECK_AUTOLOAD_FILE" && ! -L "$STEAMDECK_AUTOLOAD_FILE" &&
       "$(cat "$STEAMDECK_AUTOLOAD_FILE")" == "$(steamdeck_autoload_content)" ]]
}

steamdeck_install_has_unknown_artifacts() {
    if [[ "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" dkms_owned)" == 0 ]] &&
        [[ -e "$STEAMDECK_DKMS_SOURCE" || -L "$STEAMDECK_DKMS_SOURCE" ||
           -L "$STEAMDECK_DKMS_ROOT/$STEAMDECK_OWN_DKMS_PACKAGE" ]]; then
        return 0
    fi
    if [[ "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" dkms_owned)" == 0 ]] &&
        steamdeck_ownership_dkms_records_exist; then
        return 0
    fi
    if [[ "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" autoload_owned)" == 0 ]] &&
        [[ -e "$STEAMDECK_AUTOLOAD_FILE" || -L "$STEAMDECK_AUTOLOAD_FILE" ]]; then
        return 0
    fi
    return 1
}

steamdeck_install_prepare_state() {
    local package_installed="$1" status operation origin
    STEAMDECK_INSTALL_UNRESOLVED=0
    steamdeck_ownership_status || true
    status="$STEAMDECK_OWNERSHIP_STATUS"
    case "$status" in
        none)
            origin=none
            [[ "$package_installed" == yes ]] && origin=preexisting
            steamdeck_ownership_initialize "$origin" || return 1
            ;;
        lost)
            # Only the official package may be adopted. Unknown DKMS and
            # autoload artifacts stay unowned and stop this enable run.
            [[ "$package_installed" == yes ]] || return 1
            origin=preexisting
            steamdeck_ownership_jupiter_is_official && origin=adopted
            steamdeck_ownership_initialize "$origin" || return 1
            STEAMDECK_INSTALL_UNRESOLVED=1
            return 0
            ;;
        valid) ;;
        *) return 1 ;;
    esac

    steamdeck_ownership_refresh_restart || return 1
    operation="$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" operation)"
    case "$operation" in
        remove) return 1 ;;
        install) return 0 ;;
        none) ;;
    esac

    steamdeck_install_has_unknown_artifacts && return 1
    origin="$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" jupiter_origin)"
    if [[ "$origin" == none && "$package_installed" == yes ]]; then
        steamdeck_ownership_set_jupiter_origin preexisting || return 1
    fi
    steamdeck_ownership_set_operation install
}

steamdeck_ensure_dkms_tool() {
    command -v dkms >/dev/null 2>&1 && return 0
    pacman -Si dkms >/dev/null 2>&1 || return 1
    steamdeck_run_root pacman -S --needed --noconfirm dkms || return 1
    command -v dkms >/dev/null 2>&1
}

steamdeck_source_repair_allowed() {
    [[ "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" operation)" == install &&
       "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" dkms_owned)" == 0 &&
       -d "$STEAMDECK_DKMS_SOURCE" && ! -L "$STEAMDECK_DKMS_SOURCE" ]] || return 1
    steamdeck_ownership_source_marker_matches && return 0
    [[ -z "$(find "$STEAMDECK_DKMS_SOURCE" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]
}

steamdeck_install_dkms_source() {
    local staging marker_file registration source_exists=0 recovered=0
    registration="$STEAMDECK_DKMS_ROOT/$STEAMDECK_OWN_DKMS_PACKAGE/$STEAMDECK_DKMS_VERSION/source"
    [[ ! -L "$STEAMDECK_DKMS_SOURCE" ]] || return 1

    if steamdeck_ownership_dkms_tree_matches; then
        steamdeck_ownership_source_marker_matches || return 1
        [[ "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" dkms_owned)" == 1 ]] || recovered=1
    else
        [[ "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" dkms_owned)" == 0 ]] || return 1
        [[ -e "$STEAMDECK_DKMS_SOURCE" ]] && source_exists=1
        if [[ $source_exists -eq 1 ]] && ! steamdeck_source_repair_allowed; then
            return 1
        fi
        staging="$(mktemp -d)" || return 1
        if ! steamdeck_dkms_stage_sources "$staging"; then
            rm -rf "$staging"
            return 1
        fi
        marker_file="$staging/.steamify-owner"
        printf '%s\n' "$STEAMDECK_SOURCE_MARKER_TEXT" > "$marker_file"
        if ! steamdeck_run_root install -d -m755 "$STEAMDECK_DKMS_SOURCE" ||
            ! steamdeck_run_root install -m644 "$marker_file" "$STEAMDECK_DKMS_SOURCE/.steamify-owner" ||
            ! steamdeck_run_root install -m644 "$staging/steamdeck.c" "$staging/steamdeck_hwmon.c" \
                "$staging/Makefile" "$staging/dkms.conf" "$STEAMDECK_DKMS_SOURCE/"; then
            rm -rf "$staging"
            return 1
        fi
        rm -rf "$staging"
        steamdeck_note_system_change
        steamdeck_ownership_dkms_tree_matches || return 1
    fi

    if ! steamdeck_ownership_dkms_registration_matches; then
        [[ ! -e "$registration" && ! -L "$registration" ]] || return 1
        steamdeck_run_root dkms add "$STEAMDECK_OWN_DKMS_PACKAGE/$STEAMDECK_DKMS_VERSION" >/dev/null || return 1
        steamdeck_note_system_change
        steamdeck_ownership_dkms_registration_matches || return 1
    fi
    if [[ $recovered -eq 1 ]]; then
        # operation=install proves the exact tree was created by an
        # interrupted run; otherwise prepare_state would have rejected it.
        steamdeck_note_system_change
    fi
    steamdeck_ownership_write dkms_owned 1
}

steamdeck_build_for_kernel() {
    local kernel="$1" result
    steamdeck_run_root dkms install "$STEAMDECK_OWN_DKMS_PACKAGE/$STEAMDECK_DKMS_VERSION" -k "$kernel" >/dev/null
    result=$?
    steamdeck_dkms_accept_build_result "$kernel" "$result" || return 1
    if [[ "$STEAMDECK_DKMS_BUILD_RESULT" == built ]]; then
        steamdeck_note_system_change
    fi
    steamdeck_kernel_dkms_plan "$kernel" || return 1
    [[ "$STEAMDECK_DKMS_PLAN" == reuse ]]
}

steamdeck_verify_managed_jupiter_service() {
    local origin current_enabled
    origin="$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" jupiter_origin)"
    case "$origin" in installed|adopted) ;; *) return 0 ;; esac

    # The official package is vendor-enabled. Check this on every run for a
    # managed package, including a retry after pacman already completed.
    current_enabled="$(steamdeck_service_enabled_state)"
    case "$current_enabled" in
        enabled|enabled-runtime|linked|linked-runtime|alias|static|indirect|generated) return 0 ;;
    esac
    # CachyOS ships this unit through a package-owned vendor wants link.
    # systemctl still reports that valid package layout as "disabled".
    steamdeck_jupiter_vendor_wants_valid
}

steamdeck_install_jupiter_package() {
    local origin
    origin="$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" jupiter_origin)"
    if pacman -Q "$STEAMDECK_JUPITER_PACKAGE" >/dev/null 2>&1; then
        if [[ "$origin" == none ]]; then
            [[ "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" operation)" == install ]] || return 1
            # The package was absent when operation=install was recorded. Its
            # presence now proves pacman completed before an interruption.
            if steamdeck_ownership_jupiter_is_official; then
                steamdeck_ownership_set_jupiter_origin installed || return 1
            else
                steamdeck_ownership_set_jupiter_origin preexisting || return 1
            fi
            steamdeck_note_system_change
        fi
        origin="$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" jupiter_origin)"
        case "$origin" in
            installed|adopted) steamdeck_ownership_jupiter_is_official || return 1 ;;
        esac
    else
        [[ "$origin" != preexisting ]] || return 1
        steamdeck_ownership_jupiter_sync_is_official || return 1
        steamdeck_run_root pacman -S --needed --noconfirm \
            "$STEAMDECK_JUPITER_SYNC_REPOSITORY/$STEAMDECK_JUPITER_PACKAGE" || return 1
        steamdeck_note_system_change
        steamdeck_ownership_jupiter_is_official || return 1
        [[ "$origin" != none ]] || steamdeck_ownership_set_jupiter_origin installed || return 1
    fi
    steamdeck_verify_managed_jupiter_service
}

steamdeck_install_autoload() {
    local temporary
    if steamdeck_autoload_matches; then
        if [[ "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" autoload_owned)" == 0 ]]; then
            [[ "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" operation)" == install ]] || return 1
            steamdeck_note_system_change
            steamdeck_ownership_write autoload_owned 1 || return 1
        fi
        return 0
    fi
    [[ ! -e "$STEAMDECK_AUTOLOAD_FILE" && ! -L "$STEAMDECK_AUTOLOAD_FILE" ]] || return 1
    temporary="$(mktemp)" || return 1
    steamdeck_autoload_content > "$temporary"
    if ! steamdeck_run_root install -Dm644 "$temporary" "$STEAMDECK_AUTOLOAD_FILE"; then
        rm -f "$temporary"
        return 1
    fi
    rm -f "$temporary"
    steamdeck_note_system_change
    steamdeck_autoload_matches || return 1
    steamdeck_ownership_write autoload_owned 1
}

steamdeck_install_finish() {
    if [[ $STEAMDECK_SYSTEM_CHANGED -eq 1 ]]; then
        steamdeck_ownership_mark_restart_required || return 1
    fi
    steamdeck_ownership_set_operation none || return 1
    if steamdeck_ownership_restart_pending; then
        # shellcheck disable=SC2034
        RESTART_FOR_LOGIN=true
    fi
}

steamdeck_restore_owned_service_mask() {
    local owned previous current
    owned="$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" service_mask_owned)"
    previous="$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" service_previous_enabled)"
    [[ "$owned" == 1 ]] || {
        # A crash after clearing the ownership bit may leave only this
        # harmless recovery value behind.
        [[ -z "$previous" ]] || steamdeck_ownership_write service_previous_enabled ""
        return
    }

    current="$(steamdeck_service_enabled_state)"
    if [[ "$current" == masked ]]; then
        steamdeck_run_root systemctl unmask "$STEAMDECK_JUPITER_UNIT" >/dev/null || return 1
        steamdeck_note_system_change
        current="$(steamdeck_service_enabled_state)"
    elif [[ "$current" == "$previous" ]]; then
        # systemctl completed immediately before an interrupted state write.
        steamdeck_note_system_change
    else
        return 1
    fi
    [[ "$current" == "$previous" ]] || return 1
    steamdeck_ownership_write service_mask_owned 0 || return 1
    steamdeck_ownership_write service_previous_enabled ""
}

steamdeck_fancontrol_install() {
    local package_installed=no kernel headers_changed=0
    local -a kernels=() build_kernels=()
    STEAMDECK_SYSTEM_CHANGED=0

    pacman -Q "$STEAMDECK_JUPITER_PACKAGE" >/dev/null 2>&1 && package_installed=yes
    if [[ "$package_installed" == no ]]; then
        steamdeck_ownership_jupiter_sync_is_official || {
            steamdeck_install_fail "The official CachyOS jupiter-fan-control package is unavailable."
            return 1
        }
    fi
    if ! steamdeck_install_prepare_state "$package_installed"; then
        steamdeck_install_fail "Cannot establish safe ownership state for Fremont fan control."
        return 1
    fi
    if [[ "$STEAMDECK_INSTALL_UNRESOLVED" == 1 ]]; then
        steamdeck_install_fail "Unknown DKMS or autoload artifacts require manual ownership resolution."
        return 1
    fi

    mapfile -t kernels < <(steamdeck_installed_kernels)
    [[ ${#kernels[@]} -gt 0 ]] || { steamdeck_install_fail "No installed kernel could be identified."; return 1; }
    for kernel in "${kernels[@]}"; do
        [[ -d "$STEAMDECK_MODULES_ROOT/$kernel/build" ]] || headers_changed=1
    done
    install_kernel_headers || { steamdeck_install_fail "Kernel headers are unavailable for Fremont fan control."; return 1; }
    [[ $headers_changed -eq 0 ]] || steamdeck_note_system_change
    for kernel in "${kernels[@]}"; do
        [[ -d "$STEAMDECK_MODULES_ROOT/$kernel/build" ]] || {
            steamdeck_install_fail "Kernel headers are missing for $kernel."
            return 1
        }
        if ! steamdeck_kernel_dkms_plan "$kernel"; then
            steamdeck_install_fail "Unsafe module provider for $kernel: $STEAMDECK_DKMS_PLAN_REASON"
            return 1
        fi
        [[ "$STEAMDECK_DKMS_PLAN" == build ]] && build_kernels+=("$kernel")
    done

    if [[ ${#build_kernels[@]} -gt 0 ]]; then
        steamdeck_ensure_dkms_tool || { steamdeck_install_fail "Installing the DKMS tooling failed."; return 1; }
        steamdeck_install_dkms_source || { steamdeck_install_fail "Preparing the Steamify DKMS source failed."; return 1; }
        for kernel in "${build_kernels[@]}"; do
            info "Building Fremont fan modules for $kernel..."
            steamdeck_build_for_kernel "$kernel" || {
                steamdeck_install_fail "DKMS build for $kernel failed."
                return 1
            }
        done
    fi

    steamdeck_install_jupiter_package || {
        steamdeck_install_fail "Installing or verifying jupiter-fan-control failed."
        return 1
    }
    steamdeck_install_autoload || {
        steamdeck_install_fail "Preparing module autoload for the next boot failed."
        return 1
    }
    steamdeck_restore_owned_service_mask || {
        steamdeck_install_fail "Restoring the service state after Steamify's mask failed."
        return 1
    }
    steamdeck_install_finish
}

fancontrol_available() {
    machine_available
}

fancontrol_operation() {
    steamdeck_ownership_status >/dev/null 2>&1 || return 1
    state_get "$STEAMDECK_OWNERSHIP_COMPONENT" operation
}

fancontrol_status() {
    local origin kernel
    local -a kernels=()
    steamdeck_ownership_status >/dev/null 2>&1 || return 1
    [[ "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" operation)" == none ]] || return 1
    origin="$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" jupiter_origin)"
    [[ "$origin" != none ]] || return 1
    pacman -Q "$STEAMDECK_JUPITER_PACKAGE" >/dev/null 2>&1 || return 1
    [[ "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" autoload_owned)" == 1 ]] || return 1
    steamdeck_autoload_matches || return 1
    if [[ "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" dkms_owned)" == 1 ]]; then
        steamdeck_ownership_dkms_is_ours || return 1
    fi
    # Keep the normal status path cheap: confirm that both names resolve for
    # every installed kernel, while the detailed origin/conflict diagnosis
    # remains in the install/remove preflight.
    mapfile -t kernels < <(steamdeck_installed_kernels)
    [[ ${#kernels[@]} -gt 0 ]] || return 1
    for kernel in "${kernels[@]}"; do
        steamdeck_provider_effective_path "$kernel" steamdeck >/dev/null || return 1
        steamdeck_provider_effective_path "$kernel" steamdeck_hwmon >/dev/null || return 1
    done
}

fancontrol_adoption_notice() {
    printf '%s\n' "Steamify recovered ownership of the existing official jupiter-fan-control package. It is now managed by this option and may be removed when you turn it off; your custom configuration is kept."
}

fancontrol_enable() {
    info "Preparing Fremont fan monitoring and control for the next boot..."
    steamdeck_fancontrol_install || return 1
    ok "Fan monitoring and control ready."
}
