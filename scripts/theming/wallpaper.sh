#!/usr/bin/env bash
# Set the wallpaper with xwallpaper, on every monitor or per monitor, and
# remember the choice. The shell's Wallpapers page and theme bindings call
# --set; the shell runs --restore whenever it starts, to bring it back.
#
# Usage: wallpaper.sh --set SPEC...  set and remember. Each SPEC is
#                                    PATH          every monitor (drops the
#                                                  per-monitor choices)
#                                    OUTPUT=PATH   only that monitor (an
#                                                  xrandr name); the others keep
#                                                  theirs
#        wallpaper.sh --restore    re-apply the last choice
#        wallpaper.sh --state      print the choice: "<output>\t<image>" per
#                                  line, output "*" = every other monitor
#        wallpaper.sh --random     a random image from WALL_DIR
#        wallpaper.sh --list       "<image>\t<thumbnail>" per image in WALL_DIR
#                                  (makes missing thumbnails first)
# Env:   WALL_DIR   image folder for --random / --list (default ~/Pictures/Wallpapers)
#        WALL_MODE  xwallpaper scaling: zoom | maximize | stretch | center
#                   (default zoom = fill the screen, crop the overflow)
# Needs xwallpaper; ImageMagick for --list thumbnails.

set -uo pipefail

WALL_DIR="${WALL_DIR:-$HOME/Pictures/Wallpapers}"
WALL_MODE="${WALL_MODE:-zoom}"
# Named after the shell's directory (scripts/..), like its other state.
# The shell's directory: the nearest one up from here holding shell.qml.
shell_root() { local d; d=$(cd "$(dirname "$(readlink -f "$0")")" && pwd); while [[ ! -e $d/shell.qml && $d != / ]]; do d=$(dirname "$d"); done; printf '%s\n' "$d"; }
shell=$(basename "$(shell_root)")
# The current choice: "*\t<image>" for every monitor, then "<output>\t<image>"
# per monitor with its own. An older one-line file is just the "*" image.
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/$shell/wallpaper"
THUMBS="${XDG_CACHE_HOME:-$HOME/.cache}/$shell/wallpaper-thumbs"       # --list previews

notify() { command -v notify-send >/dev/null && notify-send -a wallpaper "Wallpaper" "$1"; }

# choice[output]=image, "*" = every monitor without its own.
declare -A choice=()
read_state() {
    choice=()
    [[ -f $STATE ]] || return 0
    local out img
    while IFS=$'\t' read -r out img; do
        [[ -z $img ]] && { img=$out; out="*"; }     # the old one-line file
        [[ -n $out && -f $img ]] && choice[$out]=$img
    done < "$STATE"
}

# Fold one SPEC into choice[]: a bare path replaces everything.
add_spec() {
    if [[ $1 =~ ^([^/=]+)=(/.*)$ ]]; then
        choice[${BASH_REMATCH[1]}]=${BASH_REMATCH[2]}
    else
        choice=(["*"]="$1")
    fi
}

# --daemon: xwallpaper forks and stays up, redrawing on every RandR change, so
# the wallpaper follows the shell's monitor-layout restore at login (which
# runs as the shell starts), Settings → Monitors and hotplugs. One daemon per session:
# stop the previous one, or it would repaint the old image.
# Later arguments paint over earlier ones, so "--output all" goes first: a
# monitor without its own image (one plugged in later too) gets the "*" one.
apply() {
    local args=() out
    [[ -n ${choice["*"]:-} ]] && args+=(--output all "--$WALL_MODE" "${choice["*"]}")
    for out in "${!choice[@]}"; do
        [[ $out == "*" ]] || args+=(--output "$out" "--$WALL_MODE" "${choice[$out]}")
    done
    (( ${#args[@]} )) || return 0
    pkill -u "$UID" -x xwallpaper 2>/dev/null
    if xwallpaper --daemon "${args[@]}"; then
        mkdir -p "$(dirname "$STATE")"
        { [[ -n ${choice["*"]:-} ]] && printf '*\t%s\n' "${choice["*"]}"
          for out in "${!choice[@]}"; do [[ $out == "*" ]] || printf '%s\t%s\n' "$out" "${choice[$out]}"; done
        } > "$STATE.tmp" && mv -f "$STATE.tmp" "$STATE"
    else
        notify "Failed to set the wallpaper"
        return 1
    fi
}

list_walls() {
    find -L "$WALL_DIR" -type f -iregex '.*\.\(jpe?g\|png\|webp\)' 2>/dev/null | sort
}

# Small cached thumbnails so the pickers don't load full-size images.
thumb_path() { printf '%s/%s.png' "$THUMBS" "$(printf '%s' "$1" | md5sum | cut -d' ' -f1)"; }

make_thumb() {   # make_thumb <src> <thumb>
    magick "${1}[0]" -thumbnail '400x225^' -gravity center -extent 400x225 "$2" 2>/dev/null
}
export -f make_thumb

# Fill walls[] (images) and icons[] (their thumbnails, or the image itself if
# there's no thumbnail), building missing/stale thumbnails in parallel.
load_walls() {
    mapfile -t walls < <(list_walls)
    icons=()
    local i
    for i in "${!walls[@]}"; do icons[i]=$(thumb_path "${walls[$i]}"); done
    if command -v magick >/dev/null; then
        mkdir -p "$THUMBS"
        # shellcheck disable=SC2016  # $1/$2 expand in the child bash, not here
        for i in "${!walls[@]}"; do
            [[ -f ${icons[$i]} && ! ${walls[$i]} -nt ${icons[$i]} ]] || printf '%s\0%s\0' "${walls[$i]}" "${icons[$i]}"
        done | xargs -0 -r -n2 -P"$(nproc)" bash -c 'make_thumb "$1" "$2"' _
    fi
    for i in "${!walls[@]}"; do [[ -f ${icons[$i]} ]] || icons[i]=${walls[$i]}; done
}

command -v xwallpaper >/dev/null || { notify "xwallpaper is not installed"; exit 1; }

case "${1:-}" in
    --restore)
        read_state
        apply
        exit 0
        ;;
    --random)
        pick=$(list_walls | shuf -n1)
        [[ -n $pick ]] && { choice=(["*"]="$pick"); apply; }
        exit 0
        ;;
    --list)
        load_walls
        for i in "${!walls[@]}"; do printf '%s\t%s\n' "${walls[$i]}" "${icons[$i]}"; done
        exit 0
        ;;
    --state)
        read_state
        for out in "${!choice[@]}"; do printf '%s\t%s\n' "$out" "${choice[$out]}"; done | sort
        exit 0
        ;;
    --set)
        shift
        (( $# )) || { echo "${0##*/}: --set needs an image" >&2; exit 2; }
        read_state
        for spec in "$@"; do
            img=${spec#*=}; [[ $spec == /* ]] && img=$spec
            [[ -f $img ]] || { echo "${0##*/}: no such image: $img" >&2; exit 2; }
            add_spec "$spec"
        done
        apply
        exit
        ;;
    *)
        echo "usage: ${0##*/} --set [OUTPUT=]PATH... | --restore | --state | --random | --list" >&2
        exit 2
        ;;
esac
