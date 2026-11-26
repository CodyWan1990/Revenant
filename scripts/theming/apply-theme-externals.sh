#!/usr/bin/env bash
# Push the active theme to everything outside the shell, by running the theme
# hooks (theme-hooks.py, next to this): the built-ins in hooks/ (i3 borders,
# rofi, kitty, GTK, Qt, KDE) and yours in <config>/hooks/theme.d/, minus the
# ones switched off in Settings -> Appearance -> Theme hooks.
# <config> is ${XDG_CONFIG_HOME:-~/.config}/<shell>, e.g. ~/.config/revenant.
# This script only loads and checks the palette; see theme-hooks.py for the
# hook interface. Each hook only rewrites (and reloads) what changed, so
# re-applying the current theme touches nothing.
# Usage: apply-theme-externals.sh <slug>
set -uo pipefail
slug="${1:?usage: apply-theme-externals.sh <slug>}"
# The shell's directory: the nearest one up from here holding shell.qml.
shell_root() { local d; d=$(cd "$(dirname "$(readlink -f "$0")")" && pwd); while [[ ! -e $d/shell.qml && $d != / ]]; do d=$(dirname "$d"); done; printf '%s\n' "$d"; }
here="$(shell_root)"
config="${XDG_CONFIG_HOME:-$HOME/.config}/$(basename "$here")"
# A theme made in the builder (the user's config dir) wins over a shipped one.
json="$config/themes/$slug.json"
[[ -f "$json" ]] || json="$here/themes/$slug.json"
[[ -f "$json" ]] || { echo "apply-theme-externals: no theme $slug" >&2; exit 0; }

# Load palette into BG/FG/RED/... shell vars (uppercase keys, no leading #).
# A missing or empty key falls back to fg, then to white. @sh shell-quotes each
# value so a hostile palette cannot inject through the eval below; the hex
# check right after is the real gate on what reaches sed and the heredocs.
eval "$(jq -r '
    .palette as $p
    | ["bg","fg","red","green","yellow","blue","mauve","cyan",
       "comment","selection","orange","teal","maroon","lavender"][]
    | . as $k
    | (($p[$k] // "") | tostring) as $v
    | (if $v == "" then (($p.fg // "ffffff") | tostring) else $v end) as $v
    | "\($k | ascii_upcase)=\($v | @sh)"
' "$json")"
NAME="$(jq -r '.meta.name // empty' "$json")"
NAME="${NAME:-$slug}"

for _c in BG FG RED GREEN YELLOW BLUE MAUVE CYAN COMMENT SELECTION ORANGE TEAL MAROON LAVENDER; do
    [[ "${!_c}" =~ ^[0-9a-fA-F]{3,8}$ ]] || {
        echo "apply-theme-externals: $slug palette $_c is not a hex color; aborting" >&2
        exit 1
    }
done

# The extra palette keys reach hooks only through the environment (the
# positional arguments stay the 11 apply-theme.sh has always taken).
export THEME_ORANGE=$ORANGE THEME_TEAL=$TEAL THEME_MAROON=$MAROON THEME_LAVENDER=$LAVENDER
exec python3 -B "$(dirname "$(readlink -f "$0")")/theme-hooks.py" run --slug "$slug" \
    "$NAME" "$BG" "$FG" "$COMMENT" "$SELECTION" "$RED" "$GREEN" "$YELLOW" "$BLUE" "$MAUVE" "$CYAN"
