#!/usr/bin/env bash
# Freeze every monitor and open the shell's screenshot selector
# (panels/ScreenshotSelector.qml) over Quickshell IPC.
# Usage: screenshot-capture.sh [region|window|screen|menu]
#   region  pick a window or monitor with a click, or drag an area (default)
#   window  the same, with the focused window already selected
#   screen  the same, with the monitor under the mouse already selected
#   menu    wait four seconds (open your menu), then region
# Needs maim, xdotool, xrandr, python3, qs. Copy/save happen in
# screenshot-deliver.sh after the selection.
set -uo pipefail

# The shell's directory: the nearest one up from here holding shell.qml.
shell_root() { local d; d=$(cd "$(dirname "$(readlink -f "$0")")" && pwd); while [[ ! -e $d/shell.qml && $d != / ]]; do d=$(dirname "$d"); done; printf '%s\n' "$d"; }
shell=$(basename "$(shell_root)")   # the config name, e.g. revenant
# Per-user and 0700, so captures aren't world-readable (Paths.runtimeDir).
run="${XDG_RUNTIME_DIR:-/tmp/$shell-$USER}"
[[ -d $run ]] || mkdir -p -m 700 "$run" || exit 1
mode=${1:-region}

case $mode in
    region | window | screen | menu) ;;
    *) echo "usage: ${0##*/} [region|window|screen|menu]" >&2; exit 2 ;;
esac

# Print held down autorepeats, and a second Print while the selector is up
# would capture the selector itself: one capture at a time.
xdotool search --onlyvisible --name "^$shell-shot\$" >/dev/null 2>&1 && exit 0
exec 9>"$run/$shell-shot.lock"
flock -n 9 || exit 0

if [[ $mode == menu ]]; then
    notify-send -a Screenshot -t 1500 Screenshot "Capturing in 4 seconds…"
    sleep 4
fi

# BMP: maim's PNG encode of the whole root takes ~1 s, BMP ~0.1 s. The
# selector shows it; screenshot-deliver.sh encodes only the part you keep.
# Captures left over if the shell died mid-selection. Only older ones: the
# lock is gone once this script hands over, so a capture still on screen
# from a moment ago must survive a second Print.
find "$run" -maxdepth 1 -name "$shell-shot-*.bmp" -mmin +1 -delete 2>/dev/null
img=$(mktemp "$run/$shell-shot-XXXXXX.bmp") || exit 1
if ! maim -u -f bmp "$img"; then
    rm -f -- "$img"
    notify-send -u critical Screenshot "maim could not capture the screen."
    exit 1
fi

# Visible windows (for click-to-pick), topmost first, as "x,y,w,h;…", and the
# focused one on its own line. Floating windows sit above tiled ones; only the
# shown tab of a tabbed/stacked container counts.
# shellcheck disable=SC2016
tree_py='
import json, sys
tree = json.load(sys.stdin)
cons = {}
def index(n):
    cons[n["id"]] = n
    for c in n.get("nodes", []) + n.get("floating_nodes", []): index(c)
index(tree)
def rect(n):
    r = n["rect"]
    return "%d,%d,%d,%d" % (r["x"], r["y"], r["width"], r["height"])
def ordered(ids, kids):
    order = {i: k for k, i in enumerate(ids)}
    return sorted(kids, key=lambda c: order.get(c["id"], len(order)))
def windows(n):
    if n.get("window") is not None:
        return [n]
    kids = n.get("nodes", [])
    if n.get("layout") in ("tabbed", "stacked") and kids:
        kids = ordered(n.get("focus", []), kids)[:1]
    out = []
    for c in ordered(n.get("focus", []), n.get("floating_nodes", [])):
        out += windows(c)
    for c in kids:
        out += windows(c)
    return out
found, focused = [], ""
for out in tree.get("nodes", []):
    if out["name"].startswith("__"): continue
    for content in out.get("nodes", []):
        if content.get("type") != "con" or not content.get("focus"): continue
        ws = cons.get(content["focus"][0])
        if not ws: continue
        full = [c for c in windows(ws) if c.get("fullscreen_mode")]
        found += full or windows(ws)
for c in found:
    if c.get("focused"): focused = rect(c)
print(focused)
print(";".join(rect(c) for c in found))
'
mapfile -t tree < <(i3-msg -t get_tree 2>/dev/null | python3 -c "$tree_py" 2>/dev/null)
focused=${tree[0]:-}
windows=${tree[1]:-}

# "x,y,w,h" of the monitor under the mouse.
mouse_monitor() {
    local X Y
    eval "$(xdotool getmouselocation --shell)"
    xrandr --listmonitors | awk -v mx="$X" -v my="$Y" 'NR > 1 {
        split($3, g, /[\/x+]/)      # 3440/797x1440/333+2560+0 -> w, mm, h, mm, x, y
        if (mx >= g[5] && mx < g[5] + g[1] && my >= g[6] && my < g[6] + g[3]) {
            printf "%d,%d,%d,%d\n", g[5], g[6], g[1], g[3]; exit
        }
    }'
}

preset=""
case $mode in
    window) preset=$focused ;;
    screen) preset=$(mouse_monitor) ;;
esac

qs -c "$shell" ipc call shell screenshotSelect "$img" "$windows" "$preset" >/dev/null || {
    rm -f -- "$img"
    notify-send -u critical Screenshot "The $shell shell isn't running."
    exit 1
}
