#!/bin/bash
# Interactive menu: detects which components are on, lets the user pick what
# they want, then turns components on or off to match.
# Sourced by steamify.sh; not meant to be run on its own.

# Menu order. Components are turned on in this order and off in reverse;
# gaming must come first (single user builds on it).
COMPONENTS=(gaming boot nvidia bigpicture theme glyphs single launcher steamgame notify vram cec machine poweroff kpin hdmi bios)
# One-off actions rather than on/off components: never preselected, never
# re-applied, not listed as on or off.
ACTIONS=(bios)
# Sub-options, shown indented under their parent and only while it's ticked.
declare -A PARENT=([boot]=gaming [bigpicture]=nvidia [steamgame]=launcher [poweroff]=machine [kpin]=machine [hdmi]=machine [bios]=machine)
# Never preselected on a first run: booting into the desktop is a choice,
# gamescope is the default; HDMI-CEC is opt-in (it can wake the machine or
# upset other devices on the TV, even on SteamOS), except on a Steam Machine,
# which has CEC like on SteamOS. HDMI refresh boost needs someone at the
# screen to confirm each step.
NO_PRESELECT=(boot cec kpin hdmi)
# Feature versions: the Steamify version in which what a component's enable
# sets up last changed; set it to the new VERSION whenever you change one.
# Each successful run records it (state "features"); a component that's on
# with an older one is ticked and re-applied by a normal run, and the app
# shows it as an update. A setup from before these were recorded counts as
# FEATURE_BASELINE.
FEATURE_BASELINE=2.1.0
declare -A FEATURE_VERSION=(
    [gaming]=2.9.0 [boot]=2.1.0 [nvidia]=2.10.0 [bigpicture]=2.10.0 [theme]=2.1.0 [glyphs]=2.1.0 [single]=2.1.0
    [launcher]=2.1.0 [cec]=2.7.0 [machine]=2.9.0 [poweroff]=2.2.0 [vram]=2.3.0 [notify]=2.5.0 [steamgame]=2.5.1
    [kpin]=2.1.0 [hdmi]=2.1.0
)

declare -A LABEL=(
    [gaming]="SteamOS conversion: boot into gaming mode, Steam on the desktop"
    [boot]="Boot into the desktop instead of gaming mode"
    [nvidia]="Gaming on NVIDIA: Steam on the desktop, started at login"
    [bigpicture]="Steam starts in Big Picture: the controller-friendly Steam (untick: Steam's normal window)"
    [theme]="Install SteamOS theme: Vapor look (cachyos-vapor)"
    [glyphs]="Install Steam Deck/Machine icons: Deck button icons in gaming mode"
    [single]="Single user mode: no password, lock screen or log out (SDDM)"
    [launcher]="Steamify shortcut: the app on the desktop, Steamify Terminal in the launcher"
    [steamgame]="Add as non-Steam game: Steamify in your Steam library, for the controller and gaming mode"
    [notify]="Update notifications: a notification when there's a new Steamify, never updates by itself"
    [vram]="VRAM booster: the game in front keeps its VRAM, background apps make room"
    [cec]="HDMI-CEC: use Steam with the TV remote, TV on/off with the PC (experimental)"
    [machine]="Steam Machine support: LED bar driver, hardware settings in Steam"
    [poweroff]="Power-off fix: the Steam Machine stays off after shutting down"
    [kpin]="Pin the kernel to $PINNED_KERNEL_VER (untick for CachyOS's current kernel)"
    [hdmi]="HDMI refresh boost: highest refresh your HDMI display runs"
    [bios]="Update BIOS"
)
declare -A CURRENT WANTED

component_available() {
    case "$1" in
        # gamescope's own session is broken on NVIDIA: the conversion is replaced by "Gaming on NVIDIA" there (shown
        # anyway when it's already on, so it can be turned off).
        gaming|boot|glyphs) ! nvidia_present || gaming_status ;;
        nvidia) nvidia_available ;;
        bigpicture) bigpicture_available ;;
        machine|poweroff) machine_available ;;
        vram) vram_available ;;
        # Steamify in the Steam library is for gaming mode's controller: not needed for Big Picture on the desktop (NVIDIA PCs;
        # shown anyway when it's already on, so it can be turned off).
        steamgame) steamgame_available && { ! nvidia_present || steamgame_status; } ;;
        kpin) kpin_available ;;
        hdmi) hdmi_available ;;
        bios) bios_available ;;
    esac
}

is_action() { [[ " ${ACTIONS[*]} " == *" $1 "* ]]; }

boot_mode() {
    # boot_mode 0|1: the "Boot into" choice as a word, for messages; "turn
    # off boot into the desktop" reads as the opposite of what was chosen.
    if [[ "$1" == 1 ]]; then echo desktop; else echo gamescope; fi
}

menu_visible() {
    # Shown in the menu. A sub-option ("Boot into", the kernel pin) only
    # while its parent is ticked.
    component_available "$1" || return 1
    [[ -z "${PARENT[$1]:-}" || "${WANTED[${PARENT[$1]}]:-0}" == 1 ]]
}

feature_record_unticked() {
    # After a run the user confirmed: options shown but left unticked that
    # have no record yet count as turned off, or the next run would offer a
    # default one again as "new" (feature_new) and tick it: e.g. single user
    # mode unticked on a first run came back ticked when anything else
    # changed. Hidden sub-options weren't a choice, so they're left alone.
    local c
    for c in "${COMPONENTS[@]}"; do
        is_action "$c" && continue
        menu_visible "$c" || continue
        [[ "${WANTED[$c]:-0}" == 0 && -z "$(state_get features "$c")" ]] && state_set features "$c" off
    done
    return 0
}

feature_record() {
    # feature_record <component> <enable|disable>: after a successful run.
    if [[ "$2" == enable ]]; then state_set features "$1" "${FEATURE_VERSION[$1]:-$FEATURE_BASELINE}"
    else state_set features "$1" off; fi
}

feature_outdated() {
    # On, but set up by an older version of that feature (compared as
    # versions: 2.10.0 is newer than 2.9.0).
    local have want
    [[ "${CURRENT[$1]:-0}" == 1 ]] || return 1
    have="$(state_get features "$1" "$FEATURE_BASELINE")"
    [[ "$have" == off ]] && have="$FEATURE_BASELINE"
    want="${FEATURE_VERSION[$1]:-$FEATURE_BASELINE}"
    [[ "$have" != "$want" && "$(printf '%s\n' "$have" "$want" | sort -V | head -n 1)" == "$have" ]]
}

menu_label() {
    # The label, with "(update)" after the name when a newer version of it
    # will be applied, "(new)" for a default sub-option added since the
    # last run.
    local l="${LABEL[$1]}" b=""
    if feature_outdated "$1"; then b="${c_yellow}(update)${c_reset}"
    elif feature_new "$1"; then b="${c_green}(new)${c_reset}"; fi
    if [[ -n "$b" ]]; then
        if [[ "$l" == *:* ]]; then l="${l%%:*} $b:${l#*:}"
        else l+=" $b"; fi
    fi
    printf '%s' "$l"
}

feature_new() {
    # A default option added after its parent was set up (e.g. the power-off
    # fix under Steam Machine support; a top-level one counts the SteamOS
    # conversion as its parent): never turned on or off.
    local p="${PARENT[$1]:-gaming}"
    [[ "$1" != gaming && "${CURRENT[$p]:-0}" == 1 && "${CURRENT[$1]:-0}" == 0 ]] &&
        ! is_action "$1" && component_selectable "$1" && [[ " ${NO_PRESELECT[*]} " != *" $1 "* ]] &&
        [[ -z "$(state_get features "$1")" ]]
}

component_selectable() {
    # Greyed out and not tickable when it has nothing to do.
    case "$1" in
        bios) bios_selectable ;;
        vram) vram_selectable ;;
    esac
}

detect_components() {
    local c any=false
    for c in "${COMPONENTS[@]}"; do CURRENT[$c]=0; WANTED[$c]=0; done
    for c in "${COMPONENTS[@]}"; do
        component_available "$c" || continue
        if "${c}_status"; then CURRENT[$c]=1; any=true; else CURRENT[$c]=0; fi
        WANTED[$c]=${CURRENT[$c]}
    done
    # HDMI-CEC set up by an older version: tick it, so a normal run fixes it.
    component_available cec && cec_repair && WANTED[cec]=1
    # Updated features and new default sub-options: ticked, so a normal run
    # applies them.
    for c in "${COMPONENTS[@]}"; do
        component_available "$c" || continue
        { feature_outdated "$c" || feature_new "$c"; } && WANTED[$c]=1
    done
    # The kernel pin is no longer needed (the power-off fix), and HDMI
    # refresh boost needed the pin: whatever is left of either is unticked,
    # so a normal run removes it.
    component_available kpin && WANTED[kpin]=0
    component_available hdmi && WANTED[hdmi]=0
    # The terminal-only Steamify shortcut from before 2.0.1: tick it, so a
    # normal run replaces it with the app.
    launcher_repair && WANTED[launcher]=1
    # Shows the current and newest BIOS version.
    bios_available && { bios_lookup_newest; LABEL[bios]="$(bios_label)"; }
    # Greyed out with an NVIDIA card: say why, and what to do.
    if component_available vram && ! vram_selectable; then
        VRAM_NVIDIA_CASE="$(vram_nvidia_case)"
        LABEL[vram]="VRAM booster: $(vram_nvidia_hint "$VRAM_NVIDIA_CASE")"
    fi
    # First run: preselect the full SteamOS experience (never an action).
    if [[ "$any" == false ]]; then
        for c in "${COMPONENTS[@]}"; do
            component_available "$c" && component_selectable "$c" && ! is_action "$c" &&
                [[ " ${NO_PRESELECT[*]} " != *" $c "* ]] && WANTED[$c]=1
        done
        machine_available && WANTED[cec]=1
    fi
}

defaults_options() {
    # defaults_options [--options <id>[,<id>...]] [--boot gamescope|desktop]:
    # what --defaults sets up, from the Steam Machine ISO's installer page.
    # --options: exactly these items on, every other off (without it, the
    # menu's preselection). An item that's on brings its parent (single user
    # the conversion, like ticking it in the menu); one this PC can't use is
    # left off with a warning. --boot desktop needs the conversion. Returns 1
    # on an unknown option, item or value.
    local c ids list=false boot=""
    while [[ $# -gt 0 ]]; do
        # Both take a value: without one, shift 2 fails and never shifts, so
        # the loop would spin forever.
        [[ "$1" == --options || "$1" == --boot ]] && [[ $# -lt 2 ]] && { err "$1 needs a value"; return 1; }
        case "$1" in
            --options)
                list=true
                IFS=, read -ra ids <<< "$2"
                shift 2 ;;
            --boot)
                case "$2" in
                    gamescope|desktop) boot="$2" ;;
                    *) err "--boot takes gamescope or desktop"; return 1 ;;
                esac
                shift 2 ;;
            *) err "Unknown option: $1"; return 1 ;;
        esac
    done
    if [[ "$list" == true ]]; then
        for c in "${ids[@]}"; do
            [[ -n "$c" ]] || continue
            [[ -n "${LABEL[$c]:-}" ]] || { err "Unknown item: $c"; return 1; }
            [[ "$c" == boot ]] && { err "Where to start is --boot, not an item."; return 1; }
            is_action "$c" && { err "$c can't be part of the install."; return 1; }
        done
        for c in "${COMPONENTS[@]}"; do WANTED[$c]=0; done
        for c in "${ids[@]}"; do
            [[ -n "$c" ]] || continue
            if component_available "$c" && component_selectable "$c"; then
                WANTED[$c]=1
            else
                warn "Leaving out ${LABEL[$c]%%:*}: not available on this PC."
            fi
        done
        [[ "${WANTED[single]}" == 1 ]] && component_available gaming && WANTED[gaming]=1
        for c in "${COMPONENTS[@]}"; do
            [[ "${WANTED[$c]}" == 1 && -n "${PARENT[$c]:-}" ]] && WANTED[${PARENT[$c]}]=1
        done
    fi
    case "$boot" in
        desktop)
            [[ "${WANTED[gaming]}" == 1 ]] || { err "--boot desktop needs the SteamOS conversion (gaming)."; return 1; }
            WANTED[boot]=1 ;;
        gamescope) WANTED[boot]=0 ;;
    esac
    return 0
}

defaults_list() {
    # --defaults --list: what --defaults can set up on this PC, as one JSON
    # array, for an installer page (the Steam Machine ISO builds its Steamify
    # page from it, so new items show up without a new ISO). Per item: id,
    # label, hint, kind (toggle, or choice for boot: on = desktop), parent,
    # on (preselected like a first run) and selectable. Actions, retired
    # items and items this PC can't use (e.g. no Steam account yet) are
    # left out. Read-only: no sudo, no state.
    local c kind on sel items=""
    for c in "${COMPONENTS[@]}"; do
        component_available "$c" || continue
        is_action "$c" && continue
        [[ "$c" == kpin || "$c" == hdmi ]] && continue
        kind=toggle; [[ "$c" == boot ]] && kind=choice
        sel=false; component_selectable "$c" && sel=true
        on=false
        [[ "$sel" == true && " ${NO_PRESELECT[*]} " != *" $c "* ]] && on=true
        [[ "$c" == cec ]] && machine_available && on=true
        items+="${items:+,}{\"id\":$(json_str "$c"),\"label\":$(json_str "${LABEL[$c]%%:*}")"
        items+=",\"hint\":$(json_str "$( [[ "${LABEL[$c]}" == *:* ]] && echo "${LABEL[$c]#*: }")")"
        items+=",\"kind\":\"$kind\",\"parent\":$(json_str "${PARENT[$c]:-}"),\"on\":$on,\"selectable\":$sel}"
    done
    printf '[%s]\n' "$items"
}

toggle_component() {
    local c="$1"
    component_selectable "$c" || return 1
    WANTED[$c]=$(( 1 - WANTED[$c] ))
    # Single user mode only makes sense on top of the SteamOS conversion.
    # (On NVIDIA the conversion isn't offered: single user mode logs in by itself, see lib/single-user.sh.)
    if [[ "$c" == single && "${WANTED[single]}" == 1 ]] && component_available gaming; then WANTED[gaming]=1; fi
    if [[ "$c" == gaming && "${WANTED[gaming]}" == 0 ]]; then WANTED[single]=0; WANTED[boot]=0; fi
    # Where to boot to is part of the conversion, too.
    if [[ "$c" == boot && "${WANTED[boot]}" == 1 ]]; then WANTED[gaming]=1; fi
    # Big Picture is opt-out: ticked along with "Gaming on NVIDIA".
    if [[ "$c" == nvidia ]]; then WANTED[bigpicture]=${WANTED[nvidia]}; fi
    if [[ "$c" == bigpicture && "${WANTED[bigpicture]}" == 1 ]]; then WANTED[nvidia]=1; fi
    # The power-off fix is opt-out: ticked along with Steam Machine support.
    if [[ "$c" == machine ]]; then WANTED[poweroff]=${WANTED[machine]}; fi
    if [[ "$c" == poweroff && "${WANTED[poweroff]}" == 1 ]]; then WANTED[machine]=1; fi
    if [[ "$c" == machine && "${WANTED[machine]}" == 0 ]]; then WANTED[kpin]=0; WANTED[bios]=0; fi
    if [[ "$c" == kpin && "${WANTED[kpin]}" == 1 ]]; then WANTED[machine]=1; fi
    if [[ "$c" == bios && "${WANTED[bios]}" == 1 ]]; then WANTED[machine]=1; fi
    # Steam starts Steamify through the shortcut's start script.
    # Opt-out, like the power-off fix: ticked along with the shortcut.
    if [[ "$c" == launcher ]] && component_available steamgame; then WANTED[steamgame]=${WANTED[launcher]}; fi
    if [[ "$c" == steamgame && "${WANTED[steamgame]}" == 1 ]]; then WANTED[launcher]=1; fi
}

show_menu() {
    local i=0 c now want
    echo
    printf "  ${c_bold}%-3s %-6s %-6s %s${c_reset}\n" "#" "Now" "Want" "Component"
    MENU_ITEMS=()
    for c in "${COMPONENTS[@]}"; do
        menu_visible "$c" || continue
        i=$((i + 1)); MENU_ITEMS[$i]=$c
        # Pad the plain word, then colour it: colour codes would count as width.
        now="off"; [[ "${CURRENT[$c]}" == 1 ]] && now="on"
        is_action "$c" && now="-"
        now="$(printf '%-6s' "$now")"
        [[ "${CURRENT[$c]}" == 1 ]] && now="${now/on/${c_green}on${c_reset}}"
        want="[ ]"; [[ "${WANTED[$c]}" == 1 ]] && want="[x]"
        if [[ "$c" == boot ]]; then
            # A choice rather than a checkbox: Now/Want show the mode.
            now="gaming"; [[ "${CURRENT[boot]}" == 1 ]] && now="desk"
            [[ "${CURRENT[gaming]}" == 1 ]] || now="-"
            want="gaming"; [[ "${WANTED[boot]}" == 1 ]] && want="desk"
            printf "  %-3s %-6s %-6s   └ %s\n" "$i" "$now" "$want" "$(boot_choice "${WANTED[boot]}")"
        elif ! component_selectable "$c"; then
            local tree=""; [[ -n "${PARENT[$c]:-}" ]] && tree="  └ "
            printf "  %b%-3s %-6s %-6s %s%s (not available)%b\n" "$c_dim" "$i" "$now" "$want" "$tree" "${LABEL[$c]}" "$c_reset"
        elif [[ -n "${PARENT[$c]:-}" ]]; then
            printf "  %-3s %b %-6s   └ %b\n" "$i" "$now" "$want" "$(menu_label "$c")"
        else
            printf "  %-3s %b %-6s %b\n" "$i" "$now" "$want" "$(menu_label "$c")"
        fi
    done
    echo
    echo -e "$KERNEL_OVERVIEW"
    echo
}

run_menu() {
    # Sets REAPPLY. Returns 1 if the user quit. A checkbox list on a
    # terminal; a plain numbered prompt when input is piped (scripted runs).
    REAPPLY=false
    # Built once: the TUI redraws on every key press.
    KERNEL_OVERVIEW="$(kernel_overview)"
    if [[ -t 0 && -t 1 ]]; then
        run_menu_tui
    else
        run_menu_lines
    fi
}

draw_menu_tui() {
    local cursor="$1" i=0 c box state line
    printf '\033[H\033[2J'
    echo -e "${c_bold}Steamify CachyOS${c_reset} v$VERSION"
    echo "Pick what you want. Anything you untick is put back the way it was."
    echo
    MENU_ITEMS=()
    for c in "${COMPONENTS[@]}"; do
        menu_visible "$c" || continue
        MENU_ITEMS[$i]=$c
        box="[ ]"; [[ "${WANTED[$c]}" == 1 ]] && box="[${c_green}x${c_reset}]"
        state="  (now: off)"; [[ "${CURRENT[$c]}" == 1 ]] && state="  (now: ${c_green}on${c_reset})"
        is_action "$c" && state="  (opt-in, runs once)"
        line="$box ${LABEL[$c]}"
        if [[ "$c" == boot ]]; then
            # A choice rather than a checkbox; Space switches it.
            # Indented under the conversion, whose sub-option it is.
            line="$(boot_choice "${WANTED[boot]}")"
            line="    └ ${line/\[/[${c_green}}"; line="${line/\]/${c_reset}]}"
            local mode=gamescope; [[ "${CURRENT[boot]}" == 1 ]] && mode=desktop
            state="  (${c_bold}←/→${c_reset} choose)"
            [[ "${CURRENT[gaming]}" == 1 ]] && state="  (now: $mode; ${c_bold}←/→${c_reset} choose)"
        elif [[ -n "${PARENT[$c]:-}" ]]; then
            line="    └ $line"
        fi
        if ! component_selectable "$c"; then
            # Greyed out: nothing to do (e.g. BIOS already up to date).
            local mark="   " tree=""; (( i == cursor )) && mark=" ${c_cyan}>${c_reset} "
            [[ -n "${PARENT[$c]:-}" ]] && tree="    └ "
            echo -e "${mark}${c_dim}${tree}[ ] ${LABEL[$c]}  (not available)${c_reset}"
        elif (( i == cursor )); then
            # The green x's reset would end the bold too: re-enable it after.
            echo -e " ${c_cyan}>${c_reset} ${c_bold}${line//"$c_reset"/"$c_reset$c_bold"}${c_reset}${state}"
        else
            echo -e "   ${line}${state}"
        fi
        i=$((i + 1))
    done
    echo
    echo -e "$KERNEL_OVERVIEW"
    echo
    echo -e "  ${c_bold}Up/Down${c_reset} move   ${c_bold}Space${c_reset} select   ${c_bold}Left/Right${c_reset} choose   ${c_bold}Enter${c_reset} run"
    echo -e "  ${c_bold}a${c_reset} run + re-apply what's on   ${c_bold}q${c_reset} quit"
}

run_menu_tui() {
    local cursor=0 key rest count
    tput civis 2>/dev/null
    trap 'tput cnorm 2>/dev/null' EXIT
    while true; do
        draw_menu_tui "$cursor"
        count=${#MENU_ITEMS[@]}
        # The list shrinks when the conversion (and its sub-option) is unticked.
        if (( cursor >= count )); then cursor=$(( count - 1 )); draw_menu_tui "$cursor"; fi
        IFS= read -rsn1 key
        if [[ "$key" == $'\e' ]]; then
            IFS= read -rsn2 -t 0.05 rest
            key+="$rest"
        fi
        case "$key" in
            $'\e[A'|k) (( cursor = (cursor + count - 1) % count )) ;;
            $'\e[B'|j) (( cursor = (cursor + 1) % count )) ;;
            " ") toggle_component "${MENU_ITEMS[$cursor]}" ;;
            # On the "Boot into" row: left = gamescope, right = desktop.
            $'\e[D'|h) [[ "${MENU_ITEMS[$cursor]}" == boot && "${WANTED[boot]}" == 1 ]] && toggle_component boot ;;
            $'\e[C'|l) [[ "${MENU_ITEMS[$cursor]}" == boot && "${WANTED[boot]}" == 0 ]] && toggle_component boot ;;
            "") break ;;
            a|A) REAPPLY=true; break ;;
            q|Q) tput cnorm 2>/dev/null; echo; return 1 ;;
        esac
    done
    tput cnorm 2>/dev/null
    echo
    return 0
}

run_menu_lines() {
    local reply
    while true; do
        show_menu
        read -rp "$(echo -e "${c_bold}Type a number to toggle, Enter to continue, a = also re-apply what's on, q = quit:${c_reset} ")" reply || return 1
        case "$reply" in
            "") return 0 ;;
            a|A) REAPPLY=true; return 0 ;;
            q|Q) return 1 ;;
            *)
                if [[ "$reply" =~ ^[0-9]+$ && -n "${MENU_ITEMS[$reply]:-}" ]]; then
                    toggle_component "${MENU_ITEMS[$reply]}" ||
                        warn "Not available: ${LABEL[${MENU_ITEMS[$reply]}]}"
                else
                    warn "Unknown choice: $reply"
                fi
                ;;
        esac
    done
}

plan_changes() {
    # Fills TO_DISABLE (reverse order) and TO_ENABLE. Switching single user
    # on or off moves gaming mode to the other login manager, so gaming
    # mode is re-applied then too.
    TO_DISABLE=(); TO_ENABLE=()
    local c i
    for (( i = ${#COMPONENTS[@]} - 1; i >= 0; i-- )); do
        c=${COMPONENTS[$i]}
        component_available "$c" || continue
        [[ "${CURRENT[$c]}" == 1 && "${WANTED[$c]}" == 0 ]] && TO_DISABLE+=("$c")
    done
    for c in "${COMPONENTS[@]}"; do
        component_available "$c" || continue
        [[ "${WANTED[$c]}" == 1 ]] || continue
        if is_action "$c"; then TO_ENABLE+=("$c"); continue; fi
        if [[ "${CURRENT[$c]}" == 0 || "$REAPPLY" == true ]] || feature_outdated "$c" ||
            [[ "$c" == gaming && "${CURRENT[single]}" != "${WANTED[single]}" ]]; then
            TO_ENABLE+=("$c")
        fi
    done
}

apply_changes() {
    local c failed=()
    LOGIN_MANAGER=plasmalogin
    [[ "${WANTED[single]}" == 1 ]] && LOGIN_MANAGER=sddm

    for c in "${TO_DISABLE[@]}"; do
        if [[ "$c" == boot ]]; then echo; echo -e "${c_bold}Boot into: gamescope${c_reset}"
        else echo; echo -e "${c_bold}Turning off: ${LABEL[$c]}${c_reset}"; fi
        if "${c}_disable"; then feature_record "$c" disable; else failed+=("$c"); fi
    done
    for c in "${TO_ENABLE[@]}"; do
        if [[ "$c" == boot ]]; then echo; echo -e "${c_bold}Boot into: desktop${c_reset}"
        elif is_action "$c"; then echo; echo -e "${c_bold}Running: ${LABEL[$c]%%:*}${c_reset}"
        else echo; echo -e "${c_bold}Turning on: ${LABEL[$c]}${c_reset}"; fi
        if "${c}_enable"; then is_action "$c" || feature_record "$c" enable; else failed+=("$c"); fi
    done
    feature_record_unticked
    os_version_refresh
    FAILED=("${failed[@]}")
}
