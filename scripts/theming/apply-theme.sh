#!/usr/bin/env bash
# Push a colour scheme to everything outside the window manager, for
# switchers that have a palette but no Revenant theme file (awesome's
# switcher.sh). It runs the same theme
# hooks as the shell's own switch (theme-hooks.py: i3, rofi, kitty, GTK, Qt,
# KDE and yours in <config>/hooks/theme.d/), and honours the on/off switches
# in Settings -> Appearance -> Theme hooks.
#
# Usage: apply-theme.sh NAME BG FG COMMENT SELECTION RED GREEN YELLOW BLUE MAUVE CYAN
#        (hex, '#' optional)
set -euo pipefail
exec python3 -B "$(dirname "$(readlink -f "$0")")/theme-hooks.py" run "$@"
