#!/usr/bin/env bash
# Finish a screenshot exported by panels/ScreenshotSelector.qml: encode the BMP
# as PNG, then copy it, save it, or both. Runs detached, so the slow parts (PNG
# encode, the notification waiting for a click) never hold the shell.
# Usage: screenshot-deliver.sh copy|save|both|open SRC.bmp [DIR [NAME.png]]
#   SRC is deleted. DIR and NAME come from Settings → Screenshots (the shell
#   formats the date-time name); a taken NAME gets " (2)", " (3)", ….
# Needs ImageMagick, xclip, notify-send; xdg-open for "open".
set -uo pipefail

action=$1
src=$2
dir=${3:-$HOME/Pictures/Screenshots}
dir=${dir/#\~/$HOME}
name=${4:-Screenshot_$(date +%Y-%m-%d_%H-%M-%S).png}
name=${name//\//-}   # a file name, never a path

magick=$(command -v magick || command -v convert) || {
    notify-send -u critical Screenshot "ImageMagick is needed to encode screenshots."
    rm -f -- "$src"; exit 1
}

png=$(mktemp "${src%.*}.XXXXXX.png") || { rm -f -- "$src"; exit 1; }
trap 'rm -f -- "$src" "$png"' EXIT
"$magick" "$src" "png:$png" || {
    notify-send -u critical Screenshot "Could not encode the screenshot."
    exit 1
}

copy() {
    # xclip reads the whole file, then forks a child that serves the clipboard
    # until something else takes it; detach its stdio so we don't wait on it.
    xclip -selection clipboard -t image/png -i "$png" </dev/null >/dev/null 2>&1
}

save() {
    mkdir -p -- "$dir" || return 1
    local base=${name%.png} n=2
    # noclobber: create the file only if it doesn't exist, so a name that's
    # taken (or two saves in one second) never overwrites an older screenshot.
    until (set -C; cat -- "$png" >"$dir/$name") 2>/dev/null; do
        [[ -e $dir/$name ]] || return 1   # failed for another reason
        name="$base ($n).png"
        ((n++))
    done
}

# Saved: offer Open / Show in folder. notify-send -A blocks until the
# notification is clicked or dismissed and prints the chosen action.
announce_saved() {
    rm -f -- "$src" "$png"
    local key
    key=$(notify-send -a Screenshot -h "string:image-path:$dir/$name" \
        -A open=Open -A reveal="Show in folder" Screenshot "$1 $name")
    case $key in
        open) xdg-open "$dir/$name" ;;
        reveal) xdg-open "$dir" ;;
    esac
}

case $action in
    copy) copy && notify-send -a Screenshot Screenshot "Copied to clipboard" ;;
    save) save && announce_saved "Saved as" ;;
    both) copy && save && announce_saved "Copied and saved as" ;;
    open) save && xdg-open "$dir/$name" ;;
    *) echo "usage: ${0##*/} copy|save|both|open FILE" >&2; exit 2 ;;
esac || notify-send -u critical Screenshot "Could not $action the screenshot."
