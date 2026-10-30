#!/bin/bash
# Provider detection and conflict protection for the Steam Deck MFD and hwmon
# modules used by Fremont. Installation and service management intentionally
# live outside this file.
# Sourced by steamify.sh; not meant to be run on its own.

STEAMDECK_MODULES_ROOT="${STEAMDECK_MODULES_ROOT:-/usr/lib/modules}"
STEAMDECK_DKMS_ROOT="${STEAMDECK_DKMS_ROOT:-/var/lib/dkms}"
STEAMDECK_OWN_DKMS_PACKAGE="${STEAMDECK_OWN_DKMS_PACKAGE:-steamify-steamdeck}"
STEAMDECK_DKMS_VERSION=1
STEAMDECK_MFD_SOURCE_SHA256=c5bd4be144bbfc8833384eae795178cd308c8dcba0e593b387100361cba9c86c
STEAMDECK_HWMON_SOURCE_SHA256=54dbd7673f8b48b7f8737d5f1213e4863dc7a2a3b94de9b60ab4bb4a7b15290c

steamdeck_provider_module_name() {
    case "$1" in
        mfd) printf '%s\n' steamdeck ;;
        hwmon) printf '%s\n' steamdeck_hwmon ;;
        *) return 1 ;;
    esac
}

steamdeck_provider_config_symbol() {
    case "$1" in
        mfd) printf '%s\n' CONFIG_MFD_STEAMDECK ;;
        hwmon) printf '%s\n' CONFIG_SENSORS_STEAMDECK ;;
        *) return 1 ;;
    esac
}

steamdeck_provider_normalize_name() {
    local name="${1##*/}"
    name="${name%.zst}"
    name="${name%.xz}"
    name="${name%.gz}"
    name="${name%.ko}"
    printf '%s\n' "${name//-/_}"
}

steamdeck_provider_path_matches() {
    [[ "$(steamdeck_provider_normalize_name "$1")" == "$2" ]]
}

steamdeck_provider_kernel_config() {
    local kernel="$1" candidate
    for candidate in \
        "$STEAMDECK_MODULES_ROOT/$kernel/build/.config" \
        "$STEAMDECK_MODULES_ROOT/$kernel/source/.config" \
        "$STEAMDECK_MODULES_ROOT/$kernel/config"; do
        [[ -r "$candidate" ]] && { printf '%s\n' "$candidate"; return 0; }
    done
    return 1
}

steamdeck_provider_config_state() {
    local kernel="$1" component="$2" config symbol value
    config="$(steamdeck_provider_kernel_config "$kernel")" || { printf '%s\n' unknown; return 0; }
    symbol="$(steamdeck_provider_config_symbol "$component")" || return 1
    value="$(sed -n "s/^${symbol}=//p" "$config" | tail -n 1)"
    case "$value" in
        y|m) printf '%s\n' "$value" ;;
        *) printf '%s\n' off ;;
    esac
}

steamdeck_provider_module_files() {
    local kernel="$1" module="$2" path
    local root="$STEAMDECK_MODULES_ROOT/$kernel"
    [[ -d "$root" ]] || return 0
    while IFS= read -r -d '' path; do
        steamdeck_provider_path_matches "$path" "$module" && printf '%s\n' "$path"
    done < <(find "$root" \
        \( -path "$root/build" -o -path "$root/source" \) -prune -o \
        -type f -name '*.ko*' -print0 2>/dev/null)
}

steamdeck_provider_builtin_path() {
    local kernel="$1" module="$2" path
    local builtin="$STEAMDECK_MODULES_ROOT/$kernel/modules.builtin"
    [[ -r "$builtin" ]] || return 1
    while IFS= read -r path; do
        if steamdeck_provider_path_matches "$path" "$module"; then
            printf '%s/%s\n' "$STEAMDECK_MODULES_ROOT/$kernel" "$path"
            return 0
        fi
    done < "$builtin"
    return 1
}

steamdeck_provider_effective_path() {
    local kernel="$1" module="$2" alternate
    command -v modinfo >/dev/null 2>&1 || return 1
    modinfo -k "$kernel" -n "$module" 2>/dev/null && return 0
    alternate="${module//_/-}"
    [[ "$alternate" != "$module" ]] || return 1
    modinfo -k "$kernel" -n "$alternate" 2>/dev/null
}

steamdeck_provider_dkms_config_claims() {
    local config="$1" module="$2" line value
    [[ -r "$config" ]] || return 1
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*BUILT_MODULE_NAME(\[[^]]+\])?[[:space:]]*=[[:space:]]*(.*)$ ]] || continue
        value="${BASH_REMATCH[2]}"
        value="${value%%#*}"
        value="${value#\"}"; value="${value%\"}"
        value="${value#\'}"; value="${value%\'}"
        [[ "$(steamdeck_provider_normalize_name "$value")" == "$module" ]] && return 0
    done < "$config"
    return 1
}

steamdeck_provider_dkms_artifact_exists() {
    local kernel="$1" package="$2" version="$3" module="$4" path
    local root="$STEAMDECK_DKMS_ROOT/$package/$version/$kernel"
    [[ -d "$root" ]] || return 1
    while IFS= read -r -d '' path; do
        steamdeck_provider_path_matches "$path" "$module" && return 0
    done < <(find "$root" -type f -path '*/module/*.ko*' -print0 2>/dev/null)
    return 1
}

steamdeck_provider_dkms_packages() {
    # $3 = artifacts: require a per-kernel module saved by DKMS; declared:
    # only require the installed package's dkms.conf to name the module.
    local kernel="$1" module="$2" mode="$3" line ref package version config
    command -v dkms >/dev/null 2>&1 || return 0
    while IFS= read -r line; do
        [[ "$line" == *": installed"* ]] || continue
        ref="${line%%,*}"
        [[ "$ref" == */* ]] || continue
        package="${ref%%/*}"
        version="${ref#*/}"
        config="$STEAMDECK_DKMS_ROOT/$package/$version/source/dkms.conf"
        if [[ "$package" != "$STEAMDECK_OWN_DKMS_PACKAGE" ]]; then
            steamdeck_provider_dkms_config_claims "$config" "$module" || continue
        fi
        if [[ "$mode" == artifacts ]]; then
            steamdeck_provider_dkms_artifact_exists "$kernel" "$package" "$version" "$module" || continue
        fi
        printf '%s/%s\n' "$package" "$version"
    done < <(dkms status -k "$kernel" 2>/dev/null || true)
}

steamdeck_provider_dkms_claimants() {
    steamdeck_provider_dkms_packages "$1" "$2" artifacts
}

steamdeck_provider_dkms_declarations() {
    steamdeck_provider_dkms_packages "$1" "$2" declared
}

steamdeck_provider_same_file() {
    local left="$1" right="$2"
    [[ "$left" == "$right" ]] && return 0
    [[ -e "$left" && -e "$right" ]] || return 1
    [[ "$(readlink -f "$left")" == "$(readlink -f "$right")" ]]
}

steamdeck_provider_effective_is_one_of() {
    local effective="$1"; shift
    local candidate
    for candidate in "$@"; do
        steamdeck_provider_same_file "$effective" "$candidate" && return 0
    done
    return 1
}

# These result variables are the function's public API for later phases.
# shellcheck disable=SC2034
steamdeck_provider_result() {
    STEAMDECK_PROVIDER_STATE="$1"
    STEAMDECK_PROVIDER_PATH="${2:-}"
    STEAMDECK_PROVIDER_REASON="${3:-}"
}

steamdeck_detect_provider() {
    # Sets STEAMDECK_PROVIDER_{STATE,PATH,REASON}. It never changes the
    # target kernel: .config, modules.builtin, module files, DKMS status and
    # modinfo's effective result are all cross-checked read-only.
    local kernel="$1" component="$2" module config_state builtin="" effective=""
    local claimant package own_claims=0 foreign_claims=0
    local -a files=() native_files=() external_files=() claimants=() declarations=()

    module="$(steamdeck_provider_module_name "$component")" || {
        steamdeck_provider_result inconsistent "" "unknown component: $component"
        return 1
    }
    config_state="$(steamdeck_provider_config_state "$kernel" "$component")" || {
        steamdeck_provider_result inconsistent "" "cannot read the kernel configuration"
        return 1
    }
    builtin="$(steamdeck_provider_builtin_path "$kernel" "$module" 2>/dev/null || true)"
    mapfile -t files < <(steamdeck_provider_module_files "$kernel" "$module")
    local path
    for path in "${files[@]}"; do
        if [[ "$path" == "$STEAMDECK_MODULES_ROOT/$kernel/kernel/"* ]]; then
            native_files+=("$path")
        else
            external_files+=("$path")
        fi
    done
    mapfile -t claimants < <(steamdeck_provider_dkms_claimants "$kernel" "$module")
    mapfile -t declarations < <(steamdeck_provider_dkms_declarations "$kernel" "$module")
    for claimant in "${claimants[@]}"; do
        package="${claimant%%/*}"
        if [[ "$package" == "$STEAMDECK_OWN_DKMS_PACKAGE" ]]; then
            own_claims=$((own_claims + 1))
        else
            foreign_claims=$((foreign_claims + 1))
        fi
    done
    effective="$(steamdeck_provider_effective_path "$kernel" "$module" 2>/dev/null || true)"

    if [[ "$config_state" == unknown ]]; then
        steamdeck_provider_result inconsistent "$effective" "kernel $kernel has no readable .config"
        return 0
    fi
    if [[ ${#native_files[@]} -gt 1 || ${#external_files[@]} -gt 1 ]]; then
        steamdeck_provider_result conflict "$effective" "multiple module files provide $module"
        return 0
    fi
    if [[ $own_claims -gt 0 && $foreign_claims -gt 0 ]]; then
        steamdeck_provider_result conflict "$effective" "Steamify and foreign DKMS packages both claim $module"
        return 0
    fi

    case "$config_state" in
        y)
            if [[ -z "$builtin" ]]; then
                steamdeck_provider_result inconsistent "$effective" "$module is configured built-in but absent from modules.builtin"
            elif [[ ${#files[@]} -gt 0 || ${#claimants[@]} -gt 0 ]]; then
                steamdeck_provider_result conflict "$effective" "a loadable provider shadows built-in $module"
            elif [[ "$effective" != "(builtin)" ]]; then
                steamdeck_provider_result inconsistent "$effective" "modinfo does not select built-in $module"
            else
                steamdeck_provider_result native-builtin "$builtin" "provided by kernel $kernel"
            fi
            ;;
        m)
            if [[ -n "$builtin" ]]; then
                steamdeck_provider_result inconsistent "$effective" "$module is configured as a module but listed built-in"
            elif [[ ${#native_files[@]} -eq 0 ]]; then
                if [[ ${#external_files[@]} -gt 0 || ${#claimants[@]} -gt 0 ]]; then
                    steamdeck_provider_result conflict "$effective" "an external provider replaces the configured native module $module"
                else
                    steamdeck_provider_result inconsistent "$effective" "$module is configured as a module but its native file is missing"
                fi
            elif [[ ${#external_files[@]} -gt 0 || ${#claimants[@]} -gt 0 ]]; then
                steamdeck_provider_result conflict "$effective" "native and DKMS providers both exist for $module"
            elif [[ -z "$effective" ]] || ! steamdeck_provider_effective_is_one_of "$effective" "${native_files[@]}"; then
                steamdeck_provider_result inconsistent "$effective" "modinfo does not select the native $module file"
            else
                steamdeck_provider_result native-module "${native_files[0]}" "provided by kernel $kernel"
            fi
            ;;
        off)
            if [[ -n "$builtin" || ${#native_files[@]} -gt 0 ]]; then
                steamdeck_provider_result inconsistent "$effective" "$module exists although its kernel option is disabled"
            elif [[ ${#external_files[@]} -eq 0 ]]; then
                if [[ -n "$effective" ]]; then
                    steamdeck_provider_result conflict "$effective" "modinfo selects $module but no matching module file was found"
                elif [[ ${#declarations[@]} -gt 0 ]]; then
                    steamdeck_provider_result inconsistent "" "DKMS reports $module installed but its module file is missing"
                else
                    steamdeck_provider_result missing "" "$module is not provided for kernel $kernel"
                fi
            elif [[ -z "$effective" ]] || ! steamdeck_provider_effective_is_one_of "$effective" "${external_files[@]}"; then
                steamdeck_provider_result inconsistent "$effective" "modinfo does not select the external $module file"
            elif [[ $own_claims -gt 0 ]]; then
                steamdeck_provider_result steamify-dkms "$effective" "provided by $STEAMDECK_OWN_DKMS_PACKAGE"
            else
                steamdeck_provider_result foreign-dkms "$effective" "external provider is not owned by Steamify"
            fi
            ;;
    esac
    return 0
}

steamdeck_dkms_stage_sources() {
    # Build a complete /usr/src-style tree in a caller-owned staging folder.
    # Installation into /usr/src is deliberately left to a later phase.
    local destination="$1"
    mkdir -p "$destination" || return 1
    patch_file steamdeck.c > "$destination/steamdeck.c" || return 1
    patch_file steamdeck_hwmon.c > "$destination/steamdeck_hwmon.c" || return 1
    patch_file steamify-steamdeck.Makefile > "$destination/Makefile" || return 1
    patch_file steamify-steamdeck.dkms.conf |
        fill NAME="$STEAMDECK_OWN_DKMS_PACKAGE" VERSION="$STEAMDECK_DKMS_VERSION" > "$destination/dkms.conf" || return 1

    echo "$STEAMDECK_MFD_SOURCE_SHA256  $destination/steamdeck.c" | sha256sum -c --quiet - || return 1
    echo "$STEAMDECK_HWMON_SOURCE_SHA256  $destination/steamdeck_hwmon.c" | sha256sum -c --quiet - || return 1
    ! grep -Eq '@(NAME|VERSION)@' "$destination/dkms.conf"
}

# These plan variables are read by the later installation phase.
# shellcheck disable=SC2034
steamdeck_kernel_dkms_plan() {
    local kernel="$1"
    if ! steamdeck_check_kernel_providers "$kernel"; then
        STEAMDECK_DKMS_PLAN=blocked
        STEAMDECK_DKMS_PLAN_REASON="$STEAMDECK_KERNEL_PROVIDER_REASON"
        return 1
    fi
    if [[ "$STEAMDECK_KERNEL_PROVIDER_STATES" == *missing* ]]; then
        STEAMDECK_DKMS_PLAN=build
        STEAMDECK_DKMS_PLAN_REASON="one or more modules are missing"
    else
        STEAMDECK_DKMS_PLAN=reuse
        STEAMDECK_DKMS_PLAN_REASON="both modules already have safe providers"
    fi
}

# The caller reads the normalized build result after checking the return code.
# shellcheck disable=SC2034
steamdeck_dkms_accept_build_result() {
    # DKMS returns 77 when BUILD_EXCLUSIVE excludes every module. Accept that
    # only after both providers are independently confirmed as native.
    local kernel="$1" result="$2" mfd_state hwmon_state
    if [[ $result -eq 0 ]]; then
        STEAMDECK_DKMS_BUILD_RESULT=built
        return 0
    fi
    if [[ $result -ne 77 ]]; then
        STEAMDECK_DKMS_BUILD_RESULT=failed
        return "$result"
    fi

    steamdeck_detect_provider "$kernel" mfd || return 1
    mfd_state="$STEAMDECK_PROVIDER_STATE"
    steamdeck_detect_provider "$kernel" hwmon || return 1
    hwmon_state="$STEAMDECK_PROVIDER_STATE"
    if [[ "$mfd_state" == native-* && "$hwmon_state" == native-* ]]; then
        STEAMDECK_DKMS_BUILD_RESULT=skipped-native
        return 0
    fi
    STEAMDECK_DKMS_BUILD_RESULT=unexpected-skip
    return 1
}

# The caller reads the result globals after this function returns.
# shellcheck disable=SC2034
steamdeck_check_kernel_providers() {
    # A partial foreign provider blocks installation of the missing module:
    # a DKMS package owning both names could otherwise overwrite that module.
    local kernel="$1" mfd_state hwmon_state
    steamdeck_detect_provider "$kernel" mfd || return 1
    mfd_state="$STEAMDECK_PROVIDER_STATE"
    local mfd_reason="$STEAMDECK_PROVIDER_REASON"
    steamdeck_detect_provider "$kernel" hwmon || return 1
    hwmon_state="$STEAMDECK_PROVIDER_STATE"
    local hwmon_reason="$STEAMDECK_PROVIDER_REASON"

    STEAMDECK_KERNEL_PROVIDER_STATES="mfd=$mfd_state hwmon=$hwmon_state"
    STEAMDECK_KERNEL_PROVIDER_REASON=""
    case "$mfd_state:$hwmon_state" in
        conflict:*|inconsistent:*|*:conflict|*:inconsistent)
            STEAMDECK_KERNEL_PROVIDER_RESULT=blocked
            STEAMDECK_KERNEL_PROVIDER_REASON="mfd: $mfd_reason; hwmon: $hwmon_reason"
            return 1
            ;;
        foreign-dkms:missing|missing:foreign-dkms)
            STEAMDECK_KERNEL_PROVIDER_RESULT=blocked
            STEAMDECK_KERNEL_PROVIDER_REASON="a foreign DKMS provider supplies only one required module"
            return 1
            ;;
        *)
            STEAMDECK_KERNEL_PROVIDER_RESULT=safe
            return 0
            ;;
    esac
}
