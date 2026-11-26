#!/usr/bin/env bash
# theme-hook: i3 window borders
# Writes <config>/i3-colors.config (client.* lines) and reloads i3 if your i3 config includes it.
set -uo pipefail
source "$(dirname "$(readlink -f "$0")")/../hook-lib.sh"

i3_colors="$SHELL_CONFIG/i3-colors.config"
i3_text="# Written by the shell's theme switch ($NAME). Include it from your i3
# config, after your own colours:  include $i3_colors
#class                  border   backgr.  text     indicator child_border
client.focused          $BLUE $BG $FG $BLUE $BLUE
client.focused_inactive $SELECTION $BG $FG $SELECTION $SELECTION
client.unfocused        $SELECTION $BG $FG $SELECTION $SELECTION
client.urgent           $RED $BG $FG $RED $RED
client.placeholder      $SELECTION $BG $FG $SELECTION $SELECTION
client.background       $BG"
if [[ ! -f $i3_colors || $(<"$i3_colors") != "$i3_text" ]]; then
    mkdir -p "$SHELL_CONFIG" && printf '%s\n' "$i3_text" > "$i3_colors"
    # Reload only if the running config includes it. get_config is the raw
    # text, where the path may be spelled ~/…, $HOME/… or in full: match the
    # part after the home dir.
    if i3-msg -t get_config 2>/dev/null | grep -qF "${i3_colors#"$HOME"/}"; then
        i3-msg reload >/dev/null 2>&1 || true
    fi
fi
exit 0
