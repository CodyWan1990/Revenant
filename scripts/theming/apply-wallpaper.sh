#!/usr/bin/env bash
# Set the wallpaper (wallpaper.sh: xwallpaper, remembered; `wallpaper.sh
# --restore` at login brings it back).
# Usage: apply-wallpaper.sh <image-path> [output]
#   no output: every monitor (drops the per-monitor choices)
#   output:    only that monitor (an xrandr name such as DisplayPort-0)
set -euo pipefail
img="${1:?usage: apply-wallpaper.sh <image-path> [output]}"
[[ -f "$img" ]] || { echo "apply-wallpaper: not found: $img" >&2; exit 1; }
exec "$(dirname "$0")/wallpaper.sh" --set "${2:+$2=}$img"
