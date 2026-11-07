#!/bin/bash
# Steamify: gamescope-session starts gamescope without a size or a refresh rate, so it takes the display's *preferred* mode,
# which many monitors declare as 60 Hz (the faster modes sit in an extension block of the EDID), and without variable
# refresh or HDR. This starts it the way the desktop runs that display (System Settings > Display): the mode KDE has saved
# for the connected display, when the display still has it, else its biggest mode at the highest refresh rate; variable
# refresh rate (--adaptive-sync) unless KDE's policy for that display is "Never"; HDR (--hdr-enabled, SDR content at KDE's
# SDR brightness) when KDE has HDR on for it.
# Read at every session start (modetest, part of libdrm which gamescope needs, the display's EDID in /sys/class/drm and
# KDE's ~/.config/kwinoutputconfig.json), so changing the resolution in KDE, another monitor or a TV just works. Anything
# unclear (no modetest output, no modes, more than one display connected: gamescope chooses which one it uses) leaves
# gamescope's own choice alone.
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

kde_display() {
    # kde_display <connector>: "<width> <height> <refresh> <vrr 0|1> <hdr 0|1> <sdr nits>" as KDE has it saved for the
    # display that is connected there now, or nothing. kwinoutputconfig.json keeps one entry per display it has ever
    # seen on a connector (a TV and a monitor both on HDMI-A-1), told apart by the identifier KDE builds from the EDID
    # ("<PNP id> <product> <serial> <week> <year> <model year>"): the connector alone would pick the wrong one.
    python3 -I - "$1" "${XDG_CONFIG_HOME:-$HOME/.config}/kwinoutputconfig.json" 2>/dev/null << 'EOF'
import glob, json, sys

conn, cfg = sys.argv[1], sys.argv[2]

def edid_prefix():
    for path in glob.glob("/sys/class/drm/card*-%s/edid" % conn):
        e = open(path, "rb").read(128)
        if len(e) < 18:
            continue
        v = (e[8] << 8) | e[9]
        pnp = "".join(chr(64 + ((v >> s) & 31)) for s in (10, 5, 0))
        return "%s %d %d %d %d " % (pnp, e[10] | (e[11] << 8), int.from_bytes(e[12:16], "little"), e[16], 1990 + e[17])

def mode_of(m):
    # A mode KDE took from the display's list: width, height, refreshRate (mHz). One it made itself (a custom or
    # CVT/reduced-blanking mode, which is how it saves 4K at 120 Hz): the timing, refresh = clock / (htotal * vtotal).
    if "cvt" in m:
        c = m["cvt"]
        return c["hdisplay"], c["vdisplay"], c["clock"] * 1000.0 / (c["htotal"] * c["vtotal"])
    return m["width"], m["height"], m["refreshRate"] / 1000.0

try:
    prefix = edid_prefix()
    if prefix:
        for block in json.load(open(cfg)):
            if block.get("name") != "outputs":
                continue
            for o in block.get("data", []):
                if o.get("connectorName") != conn or not o.get("mode"):
                    continue
                if not str(o.get("edidIdentifier", "")).startswith(prefix):
                    continue
                w, h, r = mode_of(o["mode"])
                print(w, h, round(r), 0 if o.get("vrrPolicy") == "Never" else 1,
                      1 if o.get("highDynamicRange") else 0, int(o.get("sdrBrightness") or 200))
                raise SystemExit
except SystemExit:
    pass
except Exception:
    pass
EOF
}

args=()
all="$(modes)"
conn="$(awk '{print $1}' <<< "$all" | sort -u)"
if [[ -n "$conn" && "$(wc -l <<< "$conn")" == 1 ]]; then
    read -r w h r vrr hdr nits <<< "$(kde_display "$conn")"
    # KDE's mode only counts when the display really has it (a refresh rate within 1 Hz).
    if [[ -z "${w:-}" ]] || ! awk -v w="$w" -v h="${h:-0}" -v r="${r:-0}" '$2 == w && $3 == h && ($4 - r < 2 && r - $4 < 2) {f = 1} END {exit !f}' <<< "$all"; then
        read -r _ w h r < <(awk '{print $2 * $3, $2, $3, $4}' <<< "$all" | sort -k1,1nr -k4,4nr | head -1 | awk '{print "x", $2, $3, $4}')
    fi
    [[ "${w:-0}" -gt 0 && "${h:-0}" -gt 0 && "${r:-0}" -gt 0 ]] && args=(-W "$w" -H "$h" -r "$r")
    # The settings of the display KDE knows (vrr/hdr are empty when it has no entry for it: gamescope's defaults).
    [[ "${vrr:-0}" == 1 ]] && args+=(--adaptive-sync)
    [[ "${hdr:-0}" == 1 ]] && args+=(--hdr-enabled --hdr-sdr-content-nits "${nits:-200}")
fi
if [[ "${1:-}" == --print-args ]]; then echo "${args[*]}"; exit 0; fi
exec "$real" "${args[@]}" "$@"
