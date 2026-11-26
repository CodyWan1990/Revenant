#!/bin/sh
# Copy one clipmenu history entry to CLIPBOARD + PRIMARY.
# Usage: clip-select.sh "<line from clip-list.sh>"
# clipmenu leaves clipserve running to own the selection; detach it from our
# stdio so a caller waiting for EOF (Quickshell's Process) is not held open.
CLIP_MODE=pick CLIP_LINE="${1:?usage: clip-select.sh <line>}" \
    CM_LAUNCHER="$(dirname "$0")/clip-launcher.sh" \
    setsid -f clipmenu </dev/null >/dev/null 2>&1
