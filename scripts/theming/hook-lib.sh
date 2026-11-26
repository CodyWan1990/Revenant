#!/usr/bin/env bash
# Shared by the built-in theme hooks (hooks/*.sh); not a hook itself.
# theme-hooks.py runs every hook with THEME_<KEY> (hex, no '#') in the
# environment; this sets BG, FG, ... with the '#' for the hooks that write CSS.
# Your own hooks don't need it: read "$@" or the THEME_* variables directly.

for _k in BG FG COMMENT SELECTION RED GREEN YELLOW BLUE MAUVE CYAN ORANGE TEAL MAROON LAVENDER; do
    _v="THEME_$_k"
    [[ -n ${!_v:-} ]] || { echo "${0##*/}: THEME_$_k not set; run me through theme-hooks.py" >&2; exit 2; }
    printf -v "$_k" '#%s' "${!_v}"
done
unset _k _v
NAME=${THEME_NAME:-theme}
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
# The shell's config dir (~/.config/revenant), from theme-hooks.py.
SHELL_CONFIG=${REVENANT_CONFIG:?run me through theme-hooks.py}

# Serialize GTK, qtct and xsettingsd updates with Desktop Appearance
# (desktop-appearance.py takes the same lock).
appearance_lock() {
    mkdir -p "$CFG/xsettingsd"
    exec 9>"$CFG/xsettingsd/.revenant-appearance.lock"
    flock 9
}

# Write $2 to file $1 only if different (replacing a symlink with a real file).
# Returns 0 if the file changed, 1 if it was already up to date.
write_if_changed() {
    local file=$1 content=$2
    [[ -f $file && ! -L $file && $(<"$file") == "$content" ]] && return 1
    mkdir -p "${file%/*}"
    rm -f "$file"
    printf '%s\n' "$content" > "$file"
}
