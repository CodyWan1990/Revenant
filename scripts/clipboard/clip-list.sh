#!/bin/sh
# Print clipmenu's history, one "[N] first line" per clip, newest first.
out="$(mktemp)"; trap 'rm -f "$out"' EXIT
CLIP_MODE=list CLIP_OUT="$out" CM_LAUNCHER="$(dirname "$0")/clip-launcher.sh" clipmenu
cat "$out"
