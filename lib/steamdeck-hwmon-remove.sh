#!/bin/bash
# Reboot-based removal of Fremont fan monitoring/control. The service receives
# its regular firmware handoff, but loaded modules are never unloaded.
# Sourced by steamify.sh; not meant to be run on its own.

steamdeck_remove_fail() {
    err "$1"
    return 1
}

steamdeck_interrupted_source_is_ours() {
    [[ "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" operation)" == install &&
       -d "$STEAMDECK_DKMS_SOURCE" && ! -L "$STEAMDECK_DKMS_SOURCE" ]] || return 1
    steamdeck_ownership_source_marker_matches && return 0
    [[ -z "$(find "$STEAMDECK_DKMS_SOURCE" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]
}

steamdeck_removal_source_is_ours() {
    steamdeck_ownership_source_marker_matches && return 0
    [[ "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" operation)" == remove &&
       "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" dkms_owned)" == 1 &&
       -d "$STEAMDECK_DKMS_SOURCE" && ! -L "$STEAMDECK_DKMS_SOURCE" ]] || return 1
    # install -d may have completed immediately before the owner marker was
    # copied. operation=install was reconciled to owned before removal.
    [[ -z "$(find "$STEAMDECK_DKMS_SOURCE" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]
}

steamdeck_reconcile_interrupted_install() {
    local registration
    registration="$STEAMDECK_DKMS_ROOT/$STEAMDECK_OWN_DKMS_PACKAGE/$STEAMDECK_DKMS_VERSION/source"
    [[ "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" operation)" == install ]] || return 0

    if [[ "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" dkms_owned)" == 0 ]] &&
        [[ -e "$STEAMDECK_DKMS_SOURCE" || -L "$STEAMDECK_DKMS_SOURCE" ||
           -e "$registration" || -L "$registration" ]]; then
        steamdeck_interrupted_source_is_ours || return 1
        if [[ -e "$registration" || -L "$registration" ]]; then
            steamdeck_ownership_dkms_registration_matches || return 1
        fi
        steamdeck_ownership_write dkms_owned 1 || return 1
    fi
    if [[ "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" autoload_owned)" == 0 ]] &&
        [[ -e "$STEAMDECK_AUTOLOAD_FILE" || -L "$STEAMDECK_AUTOLOAD_FILE" ]]; then
        steamdeck_autoload_matches || return 1
        steamdeck_ownership_write autoload_owned 1 || return 1
    fi
    if [[ "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" jupiter_origin)" == none ]] &&
        pacman -Q "$STEAMDECK_JUPITER_PACKAGE" >/dev/null 2>&1; then
        if steamdeck_ownership_jupiter_is_official; then
            steamdeck_ownership_set_jupiter_origin installed || return 1
        else
            steamdeck_ownership_set_jupiter_origin preexisting || return 1
        fi
    fi
}

steamdeck_removal_prepare_state() {
    local status operation
    STEAMDECK_REMOVE_NOOP=0
    steamdeck_ownership_status || true
    status="$STEAMDECK_OWNERSHIP_STATUS"
    case "$status" in
        none)
            STEAMDECK_REMOVE_NOOP=1
            return 0
            ;;
        valid) ;;
        *) return 1 ;;
    esac
    steamdeck_ownership_refresh_restart || return 1
    operation="$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" operation)"
    if [[ "$operation" == install ]]; then
        steamdeck_reconcile_interrupted_install || return 1
    elif [[ "$operation" == remove ]]; then
        # At least one destructive operation may have completed before its
        # state write. A conservative reboot request is safer than losing it.
        steamdeck_note_system_change
        return 0
    fi
    steamdeck_ownership_write operation remove
}

steamdeck_kernel_foreign_dependents() {
    local kernel="$1" check_mfd="$2" check_hwmon="$3"
    local dependency_file line dependent dependencies dependency
    local dependent_name dependency_name
    dependency_file="$STEAMDECK_MODULES_ROOT/$kernel/modules.dep"
    [[ -r "$dependency_file" ]] || return 1
    while IFS= read -r line; do
        [[ "$line" == *:* ]] || continue
        dependent="${line%%:*}"
        dependencies="${line#*:}"
        dependent_name="$(steamdeck_provider_normalize_name "$dependent")"
        case "$dependent_name" in steamdeck|steamdeck_hwmon) continue ;; esac
        for dependency in $dependencies; do
            dependency_name="$(steamdeck_provider_normalize_name "$dependency")"
            case "$dependency_name" in
                steamdeck)
                    [[ "$check_mfd" == 1 ]] || continue
                    printf '%s\n' "$dependent_name"
                    break
                    ;;
                steamdeck_hwmon)
                    [[ "$check_hwmon" == 1 ]] || continue
                    printf '%s\n' "$dependent_name"
                    break
                    ;;
            esac
        done
    done < "$dependency_file"
}

steamdeck_removal_preflight() {
    local kernel dependents mfd_state hwmon_state check_mfd check_hwmon registration
    local -a kernels=()
    registration="$STEAMDECK_DKMS_ROOT/$STEAMDECK_OWN_DKMS_PACKAGE/$STEAMDECK_DKMS_VERSION/source"
    if [[ "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" dkms_owned)" == 1 ||
          "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" autoload_owned)" == 1 ]]; then
        mapfile -t kernels < <(steamdeck_installed_kernels)
        [[ ${#kernels[@]} -gt 0 ]] || return 1
        for kernel in "${kernels[@]}"; do
            steamdeck_check_kernel_providers "$kernel" || return 1
            if [[ "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" dkms_owned)" == 1 ]]; then
                steamdeck_detect_provider "$kernel" mfd || return 1
                mfd_state="$STEAMDECK_PROVIDER_STATE"
                steamdeck_detect_provider "$kernel" hwmon || return 1
                hwmon_state="$STEAMDECK_PROVIDER_STATE"
                check_mfd=0; check_hwmon=0
                [[ "$mfd_state" == steamify-dkms ]] && check_mfd=1
                [[ "$hwmon_state" == steamify-dkms ]] && check_hwmon=1
                dependents="$(steamdeck_kernel_foreign_dependents \
                    "$kernel" "$check_mfd" "$check_hwmon")" || return 1
                [[ -z "$dependents" ]] || return 1
            fi
        done
    fi

    if [[ "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" autoload_owned)" == 1 &&
          ( -e "$STEAMDECK_AUTOLOAD_FILE" || -L "$STEAMDECK_AUTOLOAD_FILE" ) ]]; then
        steamdeck_autoload_matches || return 1
    fi
    if [[ "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" dkms_owned)" == 1 ]]; then
        if [[ -e "$STEAMDECK_DKMS_SOURCE" || -L "$STEAMDECK_DKMS_SOURCE" ]]; then
            steamdeck_removal_source_is_ours || return 1
        fi
        if [[ -e "$registration" || -L "$registration" ]]; then
            steamdeck_ownership_dkms_registration_matches || return 1
        fi
    fi
    case "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" jupiter_origin)" in
        installed|adopted)
            if pacman -Q "$STEAMDECK_JUPITER_PACKAGE" >/dev/null 2>&1; then
                steamdeck_ownership_jupiter_is_official || return 1
            elif [[ "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" operation)" != remove ]]; then
                return 1
            fi
            ;;
    esac
}

steamdeck_stop_fan_service() {
    local active stopped
    active="$(steamdeck_service_active_state)"
    case "$active" in
        active|activating|deactivating)
            steamdeck_run_root systemctl stop "$STEAMDECK_JUPITER_UNIT" || return 1
            stopped="$(steamdeck_service_active_state)"
            [[ "$stopped" == inactive || "$stopped" == failed ]] || return 1
            steamdeck_note_system_change
            ;;
        inactive|failed) ;;
        *) return 1 ;;
    esac
}

steamdeck_retained_package_needs_block() {
    local kernel mfd_state hwmon_state
    local -a kernels=()
    [[ "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" jupiter_origin)" == preexisting ]] || return 1
    pacman -Q "$STEAMDECK_JUPITER_PACKAGE" >/dev/null 2>&1 || return 1
    [[ "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" dkms_owned)" == 1 ||
       "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" autoload_owned)" == 1 ]] || return 1
    mapfile -t kernels < <(steamdeck_installed_kernels)
    for kernel in "${kernels[@]}"; do
        steamdeck_detect_provider "$kernel" mfd || return 0
        mfd_state="$STEAMDECK_PROVIDER_STATE"
        steamdeck_detect_provider "$kernel" hwmon || return 0
        hwmon_state="$STEAMDECK_PROVIDER_STATE"
        [[ "$mfd_state" == native-* && "$hwmon_state" == native-* ]] || return 0
    done
    return 1
}

steamdeck_block_retained_service() {
    local enabled previous owned
    steamdeck_retained_package_needs_block || return 0
    enabled="$(steamdeck_service_enabled_state)"
    previous="$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" service_previous_enabled)"
    owned="$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" service_mask_owned)"
    if [[ "$enabled" == masked ]]; then
        if [[ "$owned" == 0 && -n "$previous" && "$previous" != masked ]]; then
            # An interrupted remove recorded the pre-mask state and systemctl
            # completed before service_mask_owned was written.
            steamdeck_ownership_write service_mask_owned 1 || return 1
            steamdeck_note_system_change
        fi
        return 0
    fi
    [[ "$owned" == 0 ]] || return 1
    steamdeck_ownership_write service_previous_enabled "$enabled" || return 1
    steamdeck_run_root systemctl mask "$STEAMDECK_JUPITER_UNIT" >/dev/null || return 1
    [[ "$(steamdeck_service_enabled_state)" == masked ]] || return 1
    steamdeck_note_system_change
    steamdeck_ownership_write service_mask_owned 1
}

steamdeck_remove_jupiter_package() {
    local origin
    origin="$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" jupiter_origin)"
    case "$origin" in installed|adopted) ;; *) return 0 ;; esac
    if pacman -Q "$STEAMDECK_JUPITER_PACKAGE" >/dev/null 2>&1; then
        steamdeck_ownership_jupiter_is_official || return 1
        steamdeck_run_root pacman -R --noconfirm "$STEAMDECK_JUPITER_PACKAGE" || return 1
        pacman -Q "$STEAMDECK_JUPITER_PACKAGE" >/dev/null 2>&1 && return 1
        steamdeck_note_system_change
    else
        steamdeck_note_system_change
    fi
    steamdeck_ownership_set_jupiter_origin none
}

steamdeck_remove_autoload() {
    [[ "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" autoload_owned)" == 1 ]] || return 0
    if [[ -e "$STEAMDECK_AUTOLOAD_FILE" || -L "$STEAMDECK_AUTOLOAD_FILE" ]]; then
        steamdeck_autoload_matches || return 1
        steamdeck_run_root rm -f "$STEAMDECK_AUTOLOAD_FILE" || return 1
        [[ ! -e "$STEAMDECK_AUTOLOAD_FILE" && ! -L "$STEAMDECK_AUTOLOAD_FILE" ]] || return 1
        steamdeck_note_system_change
    else
        steamdeck_note_system_change
    fi
    steamdeck_ownership_write autoload_owned 0
}

steamdeck_remove_dkms() {
    local registration
    registration="$STEAMDECK_DKMS_ROOT/$STEAMDECK_OWN_DKMS_PACKAGE/$STEAMDECK_DKMS_VERSION/source"
    [[ "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" dkms_owned)" == 1 ]] || return 0
    if [[ -e "$registration" || -L "$registration" ]]; then
        steamdeck_ownership_source_marker_matches || return 1
        steamdeck_ownership_dkms_registration_matches || return 1
        steamdeck_run_root dkms remove "$STEAMDECK_OWN_DKMS_PACKAGE/$STEAMDECK_DKMS_VERSION" --all >/dev/null || return 1
        [[ ! -e "$registration" && ! -L "$registration" ]] || return 1
        steamdeck_note_system_change
    fi
    if [[ -e "$STEAMDECK_DKMS_SOURCE" || -L "$STEAMDECK_DKMS_SOURCE" ]]; then
        steamdeck_removal_source_is_ours || return 1
        steamdeck_run_root rm -rf "$STEAMDECK_DKMS_SOURCE" || return 1
        [[ ! -e "$STEAMDECK_DKMS_SOURCE" && ! -L "$STEAMDECK_DKMS_SOURCE" ]] || return 1
        steamdeck_note_system_change
    else
        steamdeck_note_system_change
    fi
    steamdeck_ownership_write dkms_owned 0
}

steamdeck_remove_finish() {
    if [[ $STEAMDECK_SYSTEM_CHANGED -eq 1 ]]; then
        steamdeck_ownership_mark_restart_required || return 1
    fi
    steamdeck_ownership_write operation none || return 1
    if steamdeck_ownership_restart_pending; then
        # shellcheck disable=SC2034
        RESTART_FOR_LOGIN=true
    fi
}

steamdeck_fancontrol_remove() {
    local ownership_detail=""
    STEAMDECK_SYSTEM_CHANGED=0
    if ! steamdeck_removal_prepare_state; then
        [[ -z "${STEAMDECK_OWNERSHIP_REASON:-}" ]] || ownership_detail=": $STEAMDECK_OWNERSHIP_REASON"
        steamdeck_remove_fail "Cannot establish safe ownership state for Fremont fan-control removal${ownership_detail}."
        return 1
    fi
    [[ "$STEAMDECK_REMOVE_NOOP" == 0 ]] || return 0
    steamdeck_removal_preflight || { steamdeck_remove_fail "Ownership or provider preflight failed; nothing was removed."; return 1; }
    steamdeck_stop_fan_service || { steamdeck_remove_fail "Stopping jupiter-fan-control failed; DKMS was left untouched."; return 1; }
    steamdeck_block_retained_service || { steamdeck_remove_fail "Preventing unsafe service autostart failed; DKMS was left untouched."; return 1; }
    steamdeck_remove_jupiter_package || { steamdeck_remove_fail "Removing jupiter-fan-control failed; DKMS was left untouched."; return 1; }
    steamdeck_remove_autoload || { steamdeck_remove_fail "Removing Steamify module autoload failed; DKMS was left untouched."; return 1; }
    steamdeck_remove_dkms || { steamdeck_remove_fail "Removing Steamify DKMS artifacts failed."; return 1; }
    steamdeck_remove_finish
}

fancontrol_disable() {
    info "Removing Fremont fan monitoring and control..."
    steamdeck_fancontrol_remove || return 1
    ok "Fan monitoring and control removed."
}
