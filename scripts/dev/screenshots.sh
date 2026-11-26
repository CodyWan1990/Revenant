#!/usr/bin/env bash
# Take the README screenshots (docs/screenshots/) in a throwaway desktop:
# a nested X server (Xephyr) running i3 and this shell for an empty home
# folder, with generated wallpapers and the theme you name. Nothing of yours
# shows up in them, and nothing of yours is changed. A Xephyr window opens on
# your desktop while it runs (about 20 s).
#
# Usage: screenshots.sh [theme-slug]          default: tokyonight
# Needs: Xephyr, i3, qs, maim, ImageMagick (magick), xwallpaper.
set -euo pipefail

shell_root() { local d; d=$(cd "$(dirname "$(readlink -f "$0")")" && pwd); while [[ ! -e $d/shell.qml && $d != / ]]; do d=$(dirname "$d"); done; printf '%s\n' "$d"; }
root="$(shell_root)"
name="$(basename "$root")"
theme="${1:-tokyonight}"
[[ -f $root/themes/$theme.json ]] || { echo "screenshots: no theme $theme in themes/" >&2; exit 2; }
for tool in Xephyr i3 qs maim magick xwallpaper; do
    command -v "$tool" >/dev/null || { echo "screenshots: $tool is not installed" >&2; exit 2; }
done

out="$root/docs/screenshots"
box="$(mktemp -d)"
# Quickshell's IPC socket lives under XDG_RUNTIME_DIR, and a socket path must
# stay under ~108 bytes: keep that one short.
run="$(mktemp -d /tmp/rv.XXXX)"
pids=()
cleanup() {
    for p in "${pids[@]}"; do kill -TERM -- "-$p" 2>/dev/null || kill "$p" 2>/dev/null || true; done
    rm -rf "$box" "$run"
}
trap cleanup EXIT

# A free display number.
d=70; while [[ -e /tmp/.X11-unix/X$d || -e /tmp/.X$d-lock ]]; do d=$((d + 1)); done
w=1600 h=900

home="$box/home"
mkdir -p "$home/.config/quickshell" "$home/.config/revenant" "$home/.local/state/$name" "$home/walls"
chmod 700 "$run"
ln -s "$root" "$home/.config/quickshell/$name"
printf '%s' "$theme" > "$home/.local/state/$name/current"

# Wallpapers: soft plasma clouds in the theme's colours.
pal() { jq -r ".palette.$1" "$root/themes/$theme.json"; }
magick -size ${w}x${h} "plasma:#$(pal bg)-#$(pal blue)" -blur 0x18 -modulate 70,80 "$home/walls/clouds.jpg"
magick -size ${w}x${h} "plasma:#$(pal bg)-#$(pal mauve)" -blur 0x24 -modulate 60,90 "$home/walls/dusk.jpg"
magick -size ${w}x${h} "gradient:#$(pal bg)-#$(pal cyan)" -modulate 60,70 "$home/walls/tide.jpg"
magick -size ${w}x${h} "radial-gradient:#$(pal selection)-#$(pal bg)" "$home/walls/glow.jpg"
cat > "$home/.config/revenant/settings.json" <<EOF
{
  "general": { "wallpaperDir": "$home/walls" },
  "theme": { "presets": [
    { "id": "night", "name": "Night", "theme": "$theme", "wallpapers": "$home/walls/clouds.jpg" },
    { "id": "dusk", "name": "Dusk", "theme": "$theme", "wallpapers": "$home/walls/dusk.jpg" }
  ] }
}
EOF

# Apps: a made-up generic set, so the launcher doesn't show what this machine
# has installed. Icons and fonts are borrowed from the system and from your
# ~/.local/share/fonts (the Nerd Font the bar's glyphs need lives there).
share="$box/share"
mkdir -p "$share/applications" "$home/.local/share"
ln -s /usr/share/icons "$share/icons"
[[ -d /usr/share/pixmaps ]] && ln -s /usr/share/pixmaps "$share/pixmaps"
ln -s /usr/share/glib-2.0 "$share/glib-2.0"   # GSettings schemas
[[ -d $HOME/.local/share/fonts ]] && ln -s "$HOME/.local/share/fonts" "$home/.local/share/fonts"
while IFS='|' read -r app icon; do
    printf '[Desktop Entry]\nType=Application\nName=%s\nExec=true\nIcon=%s\n' "$app" "$icon" \
        > "$share/applications/${app// /-}.desktop"
done <<'APPS'
Terminal|utilities-terminal
Files|system-file-manager
Text Editor|accessories-text-editor
Calculator|accessories-calculator
Videos|multimedia-video-player
Image Viewer|applications-graphics
Mail|mail-client
Settings|preferences-system
Music|multimedia-audio-player
Calendar|office-calendar
Notes|accessories-notes
Archive Manager|file-roller
Disks|gnome-disks
System Monitor|utilities-system-monitor
Screenshot|accessories-screenshot
Web Browser|web-browser
APPS

# i3 with only the shell's own window rules.
printf 'font pango:monospace 9\ndefault_border pixel 2\ninclude %s\n' "$root/i3/revenant.config" > "$box/i3.config"

# The test stand-ins for xset/pactl/nmcli, so the shell reads canned values;
# not xwallpaper (it should really draw, on the nested display) nor i3-msg.
bin="$box/bin"; mkdir -p "$bin"; cp "$root"/tests/bin/{xset,pactl,nmcli} "$bin/"
# -u I3SOCK / SWAYSOCK: i3-msg prefers I3SOCK over the display's own i3, so
# an inherited one would point this shell at *your* i3 (it then sees your
# monitors and windows, and its panel-fit commands reach your windows).
env=(env -u I3SOCK -u SWAYSOCK HOME="$home" XDG_CONFIG_HOME="$home/.config" XDG_STATE_HOME="$home/.local/state"
     XDG_CACHE_HOME="$home/.cache" XDG_DATA_HOME="$home/.local/share" XDG_DATA_DIRS="$share"
     QS_ICON_THEME=Papirus-Dark XDG_RUNTIME_DIR="$run" DISPLAY=":$d" I3SHELL_TEST=1
     PATH="$bin:$PATH")

Xephyr ":$d" -screen ${w}x${h} -br -ac -noreset >/dev/null 2>&1 &
pids+=($!)
for _ in $(seq 50); do [[ -e /tmp/.X11-unix/X$d ]] && break; sleep 0.1; done
setsid "${env[@]}" i3 -c "$box/i3.config" >/dev/null 2>&1 &
pids+=($!)
sleep 1.5
# Refuse to go on unless i3-msg reaches the nested i3, not yours.
nested=$("${env[@]}" i3-msg -t get_outputs 2>/dev/null | jq -r '[.[] | select(.active) | .name] | join(",")' || true)
if [[ -z $nested ]] || [[ -n ${I3SOCK:-} && $("${env[@]}" i3 --get-socketpath 2>/dev/null) == "$I3SOCK" ]]; then
    echo "screenshots: the nested i3 isn't answering (got outputs: '${nested}'); stopping" >&2
    exit 1
fi
setsid "${env[@]}" dbus-run-session -- qs -c "$name" >"$box/qs.log" 2>&1 &
pids+=($!)
sleep 5
"${env[@]}" bash "$root/scripts/theming/wallpaper.sh" --set "$home/walls/clouds.jpg"
ipc() { "${env[@]}" qs -c "$name" ipc call shell "$@" >/dev/null; }
shot() { sleep "${2:-1.5}"; DISPLAY=":$d" maim "$box/$1.png"; }

mkdir -p "$out"
shot desktop 1
ipc launcher;                 shot launcher
ipc launcher;                 sleep 0.5
ipc settingsPage presets;     shot settings 2
for s in desktop launcher settings; do
    crop=()
    # The Settings page ends on the wallpaper folder field, which shows this
    # sandbox's temporary path: leave that row out.
    [[ $s == settings ]] && crop=(-crop "${w}x$((h - 60))+0+0" +repage)
    magick "$box/$s.png" "${crop[@]}" -strip -quality 86 "$out/$s.jpg"
done

if grep -E 'ERROR|TypeError|ReferenceError' "$box/qs.log" | grep -v -E 'pipewire|portal' >&2; then
    echo "screenshots: the shell logged errors (above); the images may be off" >&2
fi
echo "screenshots: wrote ${out#"$root/"}/{desktop,launcher,settings}.jpg ($theme)"
