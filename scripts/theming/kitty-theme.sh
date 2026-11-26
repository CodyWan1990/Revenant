#!/usr/bin/env bash
# Write ~/.config/kitty/current-theme.conf from a palette and make running
# kitty windows reload it (SIGUSR1). Called by apply-theme.sh.
#
# Usage: kitty-theme.sh NAME BG FG COMMENT SELECTION RED GREEN YELLOW BLUE MAUVE CYAN
#        (hex, with or without a leading '#')
#
# kitty.conf must `include current-theme.conf` at its end (kitty is
# last-value-wins): if it doesn't mention current-theme.conf at all, the line
# is appended (and kitty.conf created if there is none). Windows are only
# signalled when the colours changed, so re-applying the same theme does
# nothing visible.

set -euo pipefail

if (( $# != 11 )); then
    echo "usage: ${0##*/} NAME BG FG COMMENT SELECTION RED GREEN YELLOW BLUE MAUVE CYAN" >&2
    exit 2
fi

name=$1; shift
c=()
for v in "$@"; do c+=("#${v#\#}"); done
read -r BG FG COMMENT SELECTION RED GREEN YELLOW BLUE MAUVE CYAN <<< "${c[*]}"

KITTY_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/kitty"
OUT="$KITTY_DIR/current-theme.conf"
CONF="$KITTY_DIR/kitty.conf"
mkdir -p "$KITTY_DIR"

# Without the include, kitty never reads the file below. Any mention counts
# (even commented out), so someone who removed it on purpose isn't overruled.
included=0
if [[ -f $CONF ]]; then
    conf=$(<"$CONF")
    [[ $conf == *current-theme.conf* ]] && included=1
fi
if (( ! included )); then
    printf '\n# Colours from the active Revenant theme (rewritten on every theme switch).\ninclude current-theme.conf\n' >> "$CONF"
    reload=1
fi

new=$(cat <<EOF
# theme: $name (written by the shell's kitty-theme.sh)
foreground            $FG
background            $BG
selection_foreground  $BG
selection_background  $SELECTION
cursor                $FG
cursor_text_color     background
url_color             $CYAN
color0  $BG
color8  $COMMENT
color1  $RED
color9  $RED
color2  $GREEN
color10 $GREEN
color3  $YELLOW
color11 $YELLOW
color4  $BLUE
color12 $BLUE
color5  $MAUVE
color13 $MAUVE
color6  $CYAN
color14 $CYAN
color7  $FG
color15 $FG
active_tab_foreground   $BG
active_tab_background   $FG
inactive_tab_foreground $BG
inactive_tab_background $COMMENT
EOF
)

# Unchanged: nothing to do (avoids recolouring every window at each login)
if [[ -f $OUT && $(<"$OUT") == "$new" ]]; then
    (( ${reload:-0} )) && { pkill -USR1 -x kitty 2>/dev/null || true; }
    exit 0
fi

rm -f "$OUT"   # may be a symlink: write a real file rather than its target
printf '%s\n' "$new" > "$OUT"

# kitty re-reads its config (and so this include) on SIGUSR1
pkill -USR1 -x kitty 2>/dev/null || true
