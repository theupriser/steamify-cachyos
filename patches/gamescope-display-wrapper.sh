#!/bin/bash
# Steamify: gamescope-session starts gamescope without a size or a refresh rate, so it takes the display's *preferred* mode,
# which many monitors declare as 60 Hz (the faster modes sit in an extension block of the EDID). This starts it the way the
# desktop runs that display: the mode KDE has saved for the connected display (System Settings > Display), when the display
# still has it, else its biggest mode at the highest refresh rate.
# Read at every session start (modetest, part of libdrm which gamescope needs, and KDE's ~/.config/kwinoutputconfig.json), so
# changing the resolution in KDE, another monitor or a TV just works. Anything unclear (no modetest output, no modes, more than
# one display connected: gamescope chooses which one it uses) leaves gamescope's own choice alone.
real=/usr/bin/gamescope

modes() {
    # One line per mode of every connected connector: "<connector> <width> <height> <refresh>"
    local m
    for m in nvidia-drm amdgpu i915 xe nouveau radeon; do
        timeout 10 modetest -M "$m" -c 2>/dev/null | awk '
            /^[0-9]+[ \t]+[0-9]+[ \t]+(connected|disconnected|unknown)/ { conn = ($3 == "connected") ? $4 : ""; next }
            conn != "" && /^[ \t]+#[0-9]+ [0-9]+x[0-9]+ [0-9.]+ / && !/interlace/ {
                split($2, wh, "x"); printf "%s %d %d %.0f\n", conn, wh[1], wh[2], $3
            }'
    done
}

kde_mode() {
    # kde_mode <connector>: "<width> <height> <refresh>" as KDE has it saved for that connector, or nothing.
    python3 -I - "$1" "${XDG_CONFIG_HOME:-$HOME/.config}/kwinoutputconfig.json" 2>/dev/null << 'EOF'
import json, sys
try:
    for block in json.load(open(sys.argv[2])):
        if block.get("name") == "outputs":
            for o in block.get("data", []):
                m = o.get("mode")
                if o.get("connectorName") == sys.argv[1] and m:
                    print(m["width"], m["height"], round(m["refreshRate"] / 1000))
except Exception:
    pass
EOF
}

args=()
all="$(modes)"
conn="$(awk '{print $1}' <<< "$all" | sort -u)"
if [[ -n "$conn" && "$(wc -l <<< "$conn")" == 1 ]]; then
    read -r w h r <<< "$(kde_mode "$conn")"
    # KDE's mode only counts when the display really has it (a refresh rate within 1 Hz).
    if [[ -z "${w:-}" ]] || ! awk -v w="$w" -v h="${h:-0}" -v r="${r:-0}" '$2 == w && $3 == h && ($4 - r < 2 && r - $4 < 2) {f = 1} END {exit !f}' <<< "$all"; then
        read -r _ w h r < <(awk '{print $2 * $3, $2, $3, $4}' <<< "$all" | sort -k1,1nr -k4,4nr | head -1 | awk '{print "x", $2, $3, $4}')
    fi
    [[ "${w:-0}" -gt 0 && "${h:-0}" -gt 0 && "${r:-0}" -gt 0 ]] && args=(-W "$w" -H "$h" -r "$r")
fi
if [[ "${1:-}" == --print-args ]]; then echo "${args[*]}"; exit 0; fi
exec "$real" "${args[@]}" "$@"
