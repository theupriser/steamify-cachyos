#!/bin/bash
# Compact ownership state for Fremont fan support. Actual package, DKMS and
# file state is re-observed on every run; only facts that cannot be recovered
# safely from the system are persisted here.
# Sourced by steamify.sh; not meant to be run on its own.

STEAMDECK_OWNERSHIP_COMPONENT=steamdeck_hwmon
STEAMDECK_OWNERSHIP_SCHEMA=5
STEAMDECK_BOOT_ID_FILE="${STEAMDECK_BOOT_ID_FILE:-/proc/sys/kernel/random/boot_id}"
STEAMDECK_DKMS_SOURCE="${STEAMDECK_DKMS_SOURCE:-/usr/src/$STEAMDECK_OWN_DKMS_PACKAGE-$STEAMDECK_DKMS_VERSION}"
STEAMDECK_AUTOLOAD_FILE="${STEAMDECK_AUTOLOAD_FILE:-/etc/modules-load.d/steamify-steamdeck.conf}"
STEAMDECK_JUPITER_PACKAGE=jupiter-fan-control
# Used by the install/remove modules sourced after this state module.
# shellcheck disable=SC2034
STEAMDECK_JUPITER_UNIT=jupiter-fan-control.service

steamdeck_ownership_file() {
    printf '%s/%s.state\n' "$STATE_DIR" "$STEAMDECK_OWNERSHIP_COMPONENT"
}

steamdeck_ownership_write() {
    local key="$1" value="$2"
    state_set "$STEAMDECK_OWNERSHIP_COMPONENT" "$key" "$value" || return 1
    [[ "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" "$key")" == "$value" ]]
}

steamdeck_ownership_flag_valid() {
    case "$1" in 0|1) return 0 ;; *) return 1 ;; esac
}

steamdeck_ownership_operation_valid() {
    case "$1" in none|install|remove) return 0 ;; *) return 1 ;; esac
}

steamdeck_ownership_origin_valid() {
    case "$1" in none|preexisting|installed|adopted) return 0 ;; *) return 1 ;; esac
}

steamdeck_ownership_unit_state_valid() {
    case "$1" in
        ""|enabled|enabled-runtime|linked|linked-runtime|alias|static|indirect|generated|disabled|masked|masked-runtime|not-found|unknown)
            return 0
            ;;
        *) return 1 ;;
    esac
}

steamdeck_ownership_dkms_records_exist() {
    local package_root="$STEAMDECK_DKMS_ROOT/$STEAMDECK_OWN_DKMS_PACKAGE"
    [[ -L "$package_root" ]] && return 0
    [[ -d "$package_root" ]] || return 1
    [[ -n "$(find "$package_root" -mindepth 1 -print -quit 2>/dev/null)" ]]
}

steamdeck_ownership_system_markers_exist() {
    [[ -e "$STEAMDECK_DKMS_SOURCE" || -L "$STEAMDECK_DKMS_SOURCE" ||
       -e "$STEAMDECK_AUTOLOAD_FILE" || -L "$STEAMDECK_AUTOLOAD_FILE" ]] ||
        steamdeck_ownership_dkms_records_exist
}

steamdeck_ownership_file_belongs_to_user() {
    local file="$1"
    [[ ! -L "$file" && "$(stat -c %u "$file" 2>/dev/null)" == "$(id -u)" ]]
}

steamdeck_ownership_validate() {
    local file operation origin mask_owned previous restart_id
    file="$(steamdeck_ownership_file)"
    [[ -f "$file" ]] || return 1
    steamdeck_ownership_file_belongs_to_user "$file" || return 1
    [[ "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" schema)" == "$STEAMDECK_OWNERSHIP_SCHEMA" ]] || return 1

    operation="$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" operation)"
    origin="$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" jupiter_origin)"
    mask_owned="$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" service_mask_owned)"
    previous="$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" service_previous_enabled)"
    restart_id="$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" restart_boot_id)"

    steamdeck_ownership_operation_valid "$operation" || return 1
    steamdeck_ownership_origin_valid "$origin" || return 1
    steamdeck_ownership_flag_valid "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" dkms_owned)" || return 1
    steamdeck_ownership_flag_valid "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" autoload_owned)" || return 1
    steamdeck_ownership_flag_valid "$mask_owned" || return 1
    steamdeck_ownership_unit_state_valid "$previous" || return 1
    [[ -z "$restart_id" || "$restart_id" =~ ^[[:xdigit:]-]+$ ]] || return 1
    [[ "$mask_owned" == 0 || -n "$previous" ]] || return 1
}

# Callers read STEAMDECK_OWNERSHIP_STATUS and STEAMDECK_OWNERSHIP_REASON.
# shellcheck disable=SC2034
steamdeck_ownership_status() {
    local file
    file="$(steamdeck_ownership_file)"
    STEAMDECK_OWNERSHIP_REASON=""
    if [[ -e "$STATE_DIR" || -L "$STATE_DIR" ]]; then
        if [[ -L "$STATE_DIR" || "$(stat -c %u "$STATE_DIR" 2>/dev/null)" != "$(id -u)" ]]; then
            STEAMDECK_OWNERSHIP_STATUS=wrong-user
            STEAMDECK_OWNERSHIP_REASON="state directory is not owned directly by the invoking user"
            return 1
        fi
    fi
    if [[ -L "$file" ]]; then
        STEAMDECK_OWNERSHIP_STATUS=wrong-user
        STEAMDECK_OWNERSHIP_REASON="ownership state must not be a symbolic link"
        return 1
    fi
    if [[ ! -e "$file" ]]; then
        if steamdeck_ownership_system_markers_exist; then
            STEAMDECK_OWNERSHIP_STATUS=lost
            STEAMDECK_OWNERSHIP_REASON="Steamify markers exist without ownership state"
            return 1
        fi
        STEAMDECK_OWNERSHIP_STATUS=none
        return 0
    fi
    if [[ ! -f "$file" ]] || ! steamdeck_ownership_file_belongs_to_user "$file"; then
        STEAMDECK_OWNERSHIP_STATUS=wrong-user
        STEAMDECK_OWNERSHIP_REASON="ownership state is not a regular file owned by the invoking user"
        return 1
    fi
    if ! steamdeck_ownership_validate; then
        STEAMDECK_OWNERSHIP_STATUS=damaged
        STEAMDECK_OWNERSHIP_REASON="ownership state is incomplete or invalid"
        return 1
    fi
    STEAMDECK_OWNERSHIP_STATUS=valid
}

steamdeck_ownership_inconsistent_artifacts() {
    # A missing state without system markers is the normal never-installed
    # case. Lost or damaged state beside Steamify artifacts must instead be
    # routed through the fail-closed remove path when the user asks for off.
    steamdeck_ownership_status >/dev/null 2>&1 && return 1
    case "$STEAMDECK_OWNERSHIP_STATUS" in
        lost|damaged) steamdeck_ownership_system_markers_exist ;;
        *) return 1 ;;
    esac
}

steamdeck_ownership_initialize() {
    local origin="${1:-none}" file temporary key value
    steamdeck_ownership_origin_valid "$origin" || return 1
    mkdir -p "$STATE_DIR" || return 1
    [[ ! -L "$STATE_DIR" && "$(stat -c %u "$STATE_DIR" 2>/dev/null)" == "$(id -u)" ]] || return 1
    file="$(steamdeck_ownership_file)"
    [[ ! -e "$file" && ! -L "$file" ]] || return 1
    temporary="$(mktemp "$STATE_DIR/.steamdeck-hwmon.XXXXXX")" || return 1
    chmod 600 "$temporary" || { rm -f "$temporary"; return 1; }
    while IFS='=' read -r key value; do
        kwriteconfig6 --file "$temporary" --group State --key "$key" "$value" || {
            rm -f "$temporary"
            return 1
        }
    done <<EOF
schema=$STEAMDECK_OWNERSHIP_SCHEMA
operation=none
dkms_owned=0
autoload_owned=0
jupiter_origin=$origin
service_mask_owned=0
service_previous_enabled=
restart_boot_id=
EOF
    mv "$temporary" "$file"
}

steamdeck_ownership_set_operation() {
    local operation="$1" current
    steamdeck_ownership_operation_valid "$operation" || return 1
    steamdeck_ownership_status || return 1
    current="$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" operation)"
    case "$current:$operation" in
        install:remove|remove:install) return 1 ;;
    esac
    steamdeck_ownership_write operation "$operation"
}

steamdeck_ownership_dkms_tree_matches() {
    [[ -d "$STEAMDECK_DKMS_SOURCE" && ! -L "$STEAMDECK_DKMS_SOURCE" ]] || return 1
    [[ -f "$STEAMDECK_DKMS_SOURCE/dkms.conf" ]] || return 1
    grep -qx "PACKAGE_NAME=\"$STEAMDECK_OWN_DKMS_PACKAGE\"" "$STEAMDECK_DKMS_SOURCE/dkms.conf" || return 1
    grep -qx "PACKAGE_VERSION=\"$STEAMDECK_DKMS_VERSION\"" "$STEAMDECK_DKMS_SOURCE/dkms.conf" || return 1
    echo "$STEAMDECK_MFD_SOURCE_SHA256  $STEAMDECK_DKMS_SOURCE/steamdeck.c" | sha256sum -c --quiet - >/dev/null 2>&1 || return 1
    echo "$STEAMDECK_HWMON_SOURCE_SHA256  $STEAMDECK_DKMS_SOURCE/steamdeck_hwmon.c" | sha256sum -c --quiet - >/dev/null 2>&1
}

steamdeck_ownership_source_marker_matches() {
    [[ -d "$STEAMDECK_DKMS_SOURCE" && ! -L "$STEAMDECK_DKMS_SOURCE" &&
       -f "$STEAMDECK_DKMS_SOURCE/.steamify-owner" ]] || return 1
    [[ "$(cat "$STEAMDECK_DKMS_SOURCE/.steamify-owner")" == "$STEAMDECK_SOURCE_MARKER_TEXT" ]]
}

steamdeck_ownership_dkms_registration_matches() {
    local source="$STEAMDECK_DKMS_ROOT/$STEAMDECK_OWN_DKMS_PACKAGE/$STEAMDECK_DKMS_VERSION/source"
    [[ -L "$source" && "$(readlink -f "$source")" == "$(readlink -f "$STEAMDECK_DKMS_SOURCE")" ]]
}

steamdeck_ownership_dkms_is_ours() {
    steamdeck_ownership_status || return 1
    [[ "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" dkms_owned)" == 1 ]] || return 1
    steamdeck_ownership_source_marker_matches || return 1
    steamdeck_ownership_dkms_registration_matches
}

steamdeck_ownership_jupiter_sync_is_official() {
    local sync_info repo name
    sync_info="$(LC_ALL=C pacman -Si "$STEAMDECK_JUPITER_PACKAGE" 2>/dev/null)" || return 1
    repo="$(sed -n 's/^Repository[[:space:]]*:[[:space:]]*//p' <<< "$sync_info" | head -n 1)"
    name="$(sed -n 's/^Name[[:space:]]*:[[:space:]]*//p' <<< "$sync_info" | head -n 1)"
    [[ "$name" == "$STEAMDECK_JUPITER_PACKAGE" && "$repo" == cachyos* ]] || return 1
    # shellcheck disable=SC2034
    STEAMDECK_JUPITER_SYNC_REPOSITORY="$repo"
}

steamdeck_ownership_jupiter_is_official() {
    # pacman -Qn only proves that a package of this name exists in a sync
    # database. Adoption also requires the installed package to plausibly be
    # the exact CachyOS build currently described by that database.
    local installed_info sync_info repo field installed_value sync_value
    installed_info="$(LC_ALL=C pacman -Qi "$STEAMDECK_JUPITER_PACKAGE" 2>/dev/null)" || return 1
    sync_info="$(LC_ALL=C pacman -Si "$STEAMDECK_JUPITER_PACKAGE" 2>/dev/null)" || return 1
    repo="$(sed -n 's/^Repository[[:space:]]*:[[:space:]]*//p' <<< "$sync_info" | head -n 1)"
    [[ "$repo" == cachyos* ]] || return 1
    for field in Name Version Architecture Packager 'Build Date'; do
        installed_value="$(sed -n "s/^${field}[[:space:]]*:[[:space:]]*//p" <<< "$installed_info" | head -n 1)"
        sync_value="$(sed -n "s/^${field}[[:space:]]*:[[:space:]]*//p" <<< "$sync_info" | head -n 1)"
        [[ -n "$installed_value" && "$installed_value" == "$sync_value" ]] || return 1
    done
}

steamdeck_ownership_set_jupiter_origin() {
    local origin="$1"
    steamdeck_ownership_origin_valid "$origin" || return 1
    steamdeck_ownership_write jupiter_origin "$origin"
}

steamdeck_ownership_jupiter_adoption_notice() {
    steamdeck_ownership_status >/dev/null 2>&1 || return 1
    [[ "$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" jupiter_origin)" == adopted ]]
}

steamdeck_current_boot_id() {
    [[ -r "$STEAMDECK_BOOT_ID_FILE" ]] || return 1
    tr -d '[:space:]' < "$STEAMDECK_BOOT_ID_FILE"
}

steamdeck_ownership_refresh_restart() {
    local recorded current
    recorded="$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" restart_boot_id)"
    [[ -n "$recorded" ]] || return 0
    current="$(steamdeck_current_boot_id)" || return 1
    [[ "$recorded" == "$current" ]] || steamdeck_ownership_write restart_boot_id ""
}

steamdeck_ownership_restart_pending() {
    local recorded current
    recorded="$(state_get "$STEAMDECK_OWNERSHIP_COMPONENT" restart_boot_id)"
    current="$(steamdeck_current_boot_id)" || return 1
    [[ -n "$recorded" && "$recorded" == "$current" ]]
}

steamdeck_ownership_mark_restart_required() {
    local current
    current="$(steamdeck_current_boot_id)" || return 1
    [[ -n "$current" ]] || return 1
    steamdeck_ownership_write restart_boot_id "$current"
}
