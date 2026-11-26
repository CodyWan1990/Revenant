#!/usr/bin/env bash
# theme-hook: kitty
# Writes ~/.config/kitty/current-theme.conf and reloads open kitty windows. Skipped if kitty isn't set up.
set -uo pipefail
[[ -d ${XDG_CONFIG_HOME:-$HOME/.config}/kitty ]] || exit 0
exec "$(dirname "$(readlink -f "$0")")/../kitty-theme.sh" "$@"
