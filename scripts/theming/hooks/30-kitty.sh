#!/usr/bin/env bash
# theme-hook: kitty
# Writes ~/.config/kitty/current-theme.conf, includes it from kitty.conf, and reloads open kitty windows. Skipped if kitty isn't installed.
set -uo pipefail
command -v kitty >/dev/null || [[ -d ${XDG_CONFIG_HOME:-$HOME/.config}/kitty ]] || exit 0
exec "$(dirname "$(readlink -f "$0")")/../kitty-theme.sh" "$@"
