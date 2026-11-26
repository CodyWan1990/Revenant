#!/usr/bin/env bash
# Install Revenant for the current user. Run from the cloned repository:
#
#     ./install.sh               ask before each step
#     ./install.sh --yes         do every step without asking
#     ./install.sh --dry-run     only say what would happen
#     ./install.sh --no-packages skip the package step (no sudo)
#
# Steps (each can be declined, and running it again changes nothing):
#   1. packages   the distro's packages from the README (Debian/Ubuntu, Arch,
#                 Fedora), with sudo; Quickshell itself is pointed out where
#                 the distro doesn't ship it
#   2. location   the shell at ~/.config/quickshell/revenant: nothing to do if
#                 you cloned it there; otherwise a copy of this folder, which a
#                 later run updates (git pull here, then run this again)
#   3. i3         the shell's include lines and `exec qs -c revenant`, added
#                 at the end of your i3 config between marker lines; a backup
#                 is kept, and the file is put back if `i3 -C` rejects it
#   4. environment  only advice: two optional variables for your session (the
#                 shell applies its session settings and wallpaper itself, so
#                 no login file is edited)
# It never removes anything of yours: polybar, dunst or an i3bar block are
# only pointed out.
set -euo pipefail

yes=0 dry=0 packages=1
for arg in "$@"; do
    case "$arg" in
        -y|--yes) yes=1 ;;
        -n|--dry-run) dry=1 ;;
        --no-packages) packages=0 ;;
        -h|--help) sed -n '2,/^set -euo/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
        *) echo "install: unknown option $arg (see --help)" >&2; exit 2 ;;
    esac
done

src="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
[[ -f $src/shell.qml ]] || { echo "install: run this from the Revenant folder" >&2; exit 1; }
name="revenant"
config="${XDG_CONFIG_HOME:-$HOME/.config}"
dest="$config/quickshell/$name"
userdir="$config/$name"
begin="# >>> revenant (added by install.sh) >>>"
end="# <<< revenant <<<"

bold=$'\e[1m' dim=$'\e[2m' off=$'\e[0m'
[[ -t 1 ]] || bold="" dim="" off=""
step() { printf '\n%s== %s ==%s\n' "$bold" "$1" "$off"; }
say() { printf '  %s\n' "$*"; }
ask() {   # ask "question" → 0 for yes
    (( dry )) && { say "${dim}(dry run: would ask) $1${off}"; return 1; }
    (( yes )) && return 0
    local reply; read -r -p "  $1 [Y/n] " reply || return 1
    [[ -z $reply || $reply =~ ^[Yy] ]]
}
run() {   # run a command, or show it on a dry run
    if (( dry )); then say "${dim}would run: $*${off}"; else "$@"; fi
}

# ─── 1. packages ───────────────────────────────────────────────────────────
step "1. Packages"
. /etc/os-release 2>/dev/null || true
ids=" ${ID:-} ${ID_LIKE:-} "
pkgs=() mgr=() quickshell_hint=""
case "$ids" in
    *" debian "*|*" ubuntu "*)
        mgr=(sudo apt-get install -y)
        pkgs=(quickshell i3 clipmenu xclip xdotool maim imagemagick xwallpaper jq x11-xserver-utils
              libnotify-bin xdg-utils network-manager pipewire-pulse python3-xlib python3-gi
              fonts-noto-color-emoji)
        quickshell_hint="If apt can't find quickshell, your release doesn't package it yet: build it from https://quickshell.org (0.3 or newer)." ;;
    *" arch "*)
        mgr=(sudo pacman -S --needed --noconfirm)
        pkgs=(i3-wm clipmenu xclip xdotool maim imagemagick xwallpaper jq xorg-xset xorg-xrandr libnotify
              xdg-utils networkmanager pipewire-pulse python-xlib python-gobject noto-fonts-emoji)
        quickshell_hint="Quickshell is in the AUR: e.g. 'paru -S quickshell' or 'yay -S quickshell'." ;;
    *" fedora "*)
        mgr=(sudo dnf install -y)
        pkgs=(i3 clipmenu xclip xdotool maim ImageMagick xwallpaper jq xset xrandr libnotify xdg-utils
              NetworkManager pipewire-pulseaudio python3-xlib python3-gobject google-noto-color-emoji-fonts)
        quickshell_hint="Quickshell comes from a COPR: 'sudo dnf copr enable errornointernet/quickshell && sudo dnf install quickshell'." ;;
esac
if (( ! packages )); then
    say "skipped (--no-packages)"
elif (( ${#pkgs[@]} == 0 )); then
    say "Unknown distro (${ID:-?}): install the packages in the README's Requirements by hand."
else
    say "${PRETTY_NAME:-$ID}: ${pkgs[*]}"
    if ask "Install these with ${mgr[0]} ${mgr[1]}?"; then
        run "${mgr[@]}" "${pkgs[@]}" || say "The package step failed; the rest can still run. See the message above."
    fi
fi
command -v qs >/dev/null || { say "Quickshell (qs) is not installed yet."; [[ -n $quickshell_hint ]] && say "$quickshell_hint"; }
# Captured, not piped into grep -q: grep quitting early kills fc-list, and
# pipefail would read that as "no match".
fonts="$(fc-list : family 2>/dev/null || true)"
if [[ ${fonts,,} != *nerd* ]]; then
    say "No Nerd Font found: the bar's icons need one (e.g. JetBrainsMono Nerd Font from https://www.nerdfonts.com)."
fi

# ─── 2. location ───────────────────────────────────────────────────────────
step "2. Shell folder"
# A copy made here carries this marker (where it came from, and when), which
# is what lets a later run update it and never touch a folder it didn't make.
marker=".installed-from"
put_copy() {   # build the copy beside the old one, then swap: never half-updated
    local new="$dest.new.$$" old="$dest.old.$$"
    mkdir -p "$(dirname "$dest")"
    rm -rf "$new"
    cp -a "$src/." "$new/"
    rm -rf "$new/.git"
    find "$new" -name __pycache__ -type d -prune -exec rm -rf {} +
    printf '%s\n%s\n' "$src" "$(git -C "$src" rev-parse --short HEAD 2>/dev/null || date -u +%F)" > "$new/$marker"
    [[ -e $dest ]] && mv "$dest" "$old"
    mv "$new" "$dest"
    rm -rf "$old"
}
if [[ $(readlink -f "$dest" 2>/dev/null) == "$src" ]]; then
    say "$dest is this folder already (cloned in place: 'git pull' updates it)."
elif [[ -L $dest ]]; then
    say "$dest is a link to $(readlink -f "$dest"); leaving it alone."
    say "Remove the link and run this again to put a copy there instead."
elif [[ -f $dest/$marker ]]; then
    say "$dest is a copy from $(sed -n 1p "$dest/$marker") (version $(sed -n 2p "$dest/$marker"))."
    if ask "Update it from $src?"; then
        if (( dry )); then say "${dim}would replace $dest with a fresh copy of $src${off}"
        else put_copy; say "Updated. Restart the shell: pkill -x qs; setsid -f qs -c $name"; fi
    fi
elif [[ -e $dest ]]; then
    say "$dest exists and wasn't made by this installer; leaving it alone."
    say "Move it aside and run this again to put a copy there."
elif ask "Copy the shell to $dest?"; then
    if (( dry )); then say "${dim}would copy $src to $dest${off}"
    else put_copy; say "Copied. To update later: 'git pull' here, then run this again."; fi
fi
[[ -d $userdir ]] || run mkdir -p "$userdir"
# Included by the i3 block below; the i3 theme hook fills it on the first theme switch.
[[ -e $userdir/i3-colors.config ]] || run touch "$userdir/i3-colors.config"

# ─── 3. i3 ─────────────────────────────────────────────────────────────────
step "3. i3 config"
i3conf=""
for c in "$config/i3/config" "$HOME/.i3/config"; do [[ -f $c ]] && { i3conf="$c"; break; }; done
block="$begin
# Window rules for the shell's panels, and \$rev / \$rev_shot for your own binds.
include $dest/i3/revenant.config
# Default shortcuts (Super+D launcher, Super+V clipboard, Print, …); drop this
# line to keep only your own.
include $dest/i3/revenant-keys.config
# Window colours, rewritten on every theme switch.
include $userdir/i3-colors.config
exec --no-startup-id qs -c $name
$end"
if [[ -z $i3conf ]]; then
    say "No i3 config found (~/.config/i3/config). Run i3 once to make one, then this again."
elif grep -qF "$begin" "$i3conf"; then
    say "$i3conf has the Revenant block already."
elif grep -qE "quickshell/$name/i3/revenant\.config|qs -c $name\b" "$i3conf"; then
    say "$i3conf already includes the shell or starts it (set up by hand); leaving it alone."
elif command -v i3 >/dev/null && ! i3 -C -c "$i3conf" >/dev/null 2>&1; then
    say "$i3conf already fails 'i3 -C -c $i3conf'; fix that first, then run this again."
else
    grep -nE '^[[:space:]]*bar[[:space:]]*\{' "$i3conf" >/dev/null && say "Note: $i3conf has an i3bar 'bar { }' block; remove it, or you get two bars."
    grep -nE 'exec.*\b(polybar|dunst|mako|rofi .*-show)\b' "$i3conf" | sed 's/^/  Note: line /' || true
    if ask "Add the Revenant block to the end of $i3conf?"; then
        if (( dry )); then
            say "${dim}would append:${off}"; sed 's/^/      /' <<<"$block"
        else
            backup="$i3conf.before-revenant"
            cp -p "$i3conf" "$backup"
            printf '\n%s\n' "$block" >> "$i3conf"
            errors=""
            if command -v i3 >/dev/null && ! errors="$(i3 -C -c "$i3conf" 2>&1)"; then
                cp -p "$backup" "$i3conf"
                say "i3 -C rejected the result, so $i3conf is back as it was. Its errors:"
                sed 's/^/    /' <<<"$errors" | head -10
            else
                say "Added. Your old config is in $backup."
            fi
        fi
    fi
fi

# ─── 4. environment ────────────────────────────────────────────────────────
# Nothing to install: the shell applies key repeat, blanking, power saving,
# the login volume and the wallpaper itself when it starts. Two optional
# environment variables have to come from your session, so only say so.
step "4. Session environment (optional)"
[[ -n ${QS_ICON_THEME:-} ]] \
    && say "QS_ICON_THEME=$QS_ICON_THEME (tray icons)." \
    || say "For tray icons, set an icon theme in your session, e.g. in ~/.profile: export QS_ICON_THEME=Papirus-Dark"
[[ ${QT_QPA_PLATFORMTHEME:-} == qt[56]ct ]] \
    && say "QT_QPA_PLATFORMTHEME=$QT_QPA_PLATFORMTHEME (Qt apps follow the theme)." \
    || say "For Qt apps to follow the theme: export QT_QPA_PLATFORMTHEME=qt5ct (needs qt5ct / qt6ct)."

step "Done"
if (( dry )); then
    say "Dry run: nothing was changed."
else
    say "Log out and pick i3 at the login screen (or reload i3 with \$mod+Shift+r and run 'qs -c $name')."
    say "Settings: Super+S, or 'qs -c $name ipc call shell settings'. Your settings live in $userdir."
fi
