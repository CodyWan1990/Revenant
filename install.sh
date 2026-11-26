#!/usr/bin/env bash
# Install Revenant for the current user. Run from the cloned repository:
#
#     ./install.sh               ask before each step
#     ./install.sh --yes         do every step without asking
#     ./install.sh --dry-run     only say what would happen
#     ./install.sh --no-packages skip the package step (no sudo)
#     ./install.sh --i3-starter  replace your i3 config with the starter one
#                                (the old ~/.config/i3 is kept as a backup)
#
# Steps (each can be declined, and running it again changes nothing):
#   1. packages   everything a fresh system needs, with sudo. Debian/Ubuntu:
#                 enables Debian's backports (Quickshell is only there on
#                 Debian 13), apt-get update, then the full list (the shell,
#                 sound, network, fonts, icons, kitty, qt5ct/qt6ct, xsettingsd,
#                 and an X server and login screen if there are none); builds
#                 clipmenu 7 and fetches the adw-gtk3 GTK theme, which aren't
#                 packaged. Arch and Fedora: the README's package list
#   2. location   the shell at ~/.config/quickshell/revenant: nothing to do if
#                 you cloned it there; otherwise a copy of this folder, which a
#                 later run updates (git pull here, then run this again)
#   3. i3         with no i3 config yet, or only the one i3-config-wizard
#                 wrote: the starter config from i3/starter/ (keys, gaps and
#                 colours set up for the shell, editable in Settings).
#                 With your own config: the shell's include lines and
#                 `exec qs -c revenant`, added at the end between marker
#                 lines. Either way a backup is kept, and it is put back if
#                 `i3 -C` rejects the result
#   4. environment  QS_ICON_THEME (tray icons) and QT_QPA_PLATFORMTHEME (Qt
#                 colours), appended between marker lines to ~/.xsessionrc
#                 (Debian/Ubuntu: their Xsession reads it) or ~/.xprofile;
#                 skipped if your session files set them already
#   5. theme      runs the theme hooks once, so i3, kitty, GTK and Qt match
#                 the shell's theme from the first login
# It never removes anything of yours: polybar, dunst or an i3bar block are
# only pointed out.
set -euo pipefail

yes=0 dry=0 packages=1 i3starter=0
for arg in "$@"; do
    case "$arg" in
        -y|--yes) yes=1 ;;
        -n|--dry-run) dry=1 ;;
        --no-packages) packages=0 ;;
        --i3-starter) i3starter=1 ;;
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

# ─── output ────────────────────────────────────────────────────────────────
if [[ -t 1 && -z ${NO_COLOR:-} ]]; then
    bold=$'\e[1m' dim=$'\e[2m' off=$'\e[0m'
    red=$'\e[31m' green=$'\e[32m' yellow=$'\e[33m' blue=$'\e[34m' cyan=$'\e[36m'
else
    bold="" dim="" off="" red="" green="" yellow="" blue="" cyan=""
fi
steps=5 stepno=0 attention=()
step() { stepno=$((stepno + 1)); printf '\n%s%s[%d/%d]%s %s%s%s\n' "$bold" "$blue" "$stepno" "$steps" "$off" "$bold" "$1" "$off"; }
say()  { printf '    %s\n' "$*"; }                                  # a detail
ok()   { printf '  %s✓%s %s\n' "$green" "$off" "$*"; }               # done, or already fine
warn() { printf '  %s!%s %s\n' "$yellow" "$off" "$*"; attention+=("$*"); }   # needs you; repeated at the end
fail() { printf '  %s✗%s %s\n' "$red" "$off" "$*"; attention+=("$*"); }
quote() { sed "s/^/      ${dim}/; s/\$/${off}/"; }                    # someone else's output, indented
wrap() { fold -s -w 68 <<<"$*" | sed "s/^/      ${dim}/; s/ *\$/${off}/"; }   # a long list of words
ask() {   # ask "question" → 0 for yes
    (( dry )) && { printf '  %s?%s %s %s(dry run: would ask)%s\n' "$cyan" "$off" "$1" "$dim" "$off"; return 1; }
    (( yes )) && { printf '  %s?%s %s %s(yes)%s\n' "$cyan" "$off" "$1" "$dim" "$off"; return 0; }
    local reply
    printf '  %s?%s %s%s%s [Y/n] ' "$cyan" "$off" "$bold" "$1" "$off"
    read -r reply || return 1
    [[ -z $reply || $reply =~ ^[Yy] ]]
}
t() { printf %s "${1/#$HOME/\~}"; }   # a path as ~/… for messages
run() {   # show a command, then run it (or only show it on a dry run)
    if (( dry )); then say "${dim}would run: $*${off}"; else say "${dim}\$ $*${off}"; "$@"; fi
}

. /etc/os-release 2>/dev/null || true
printf '\n%sRevenant%s %s· i3 desktop shell installer%s\n' "$bold" "$off" "$dim" "$off"
mode="asks before each step"
(( yes )) && mode="answering yes to everything"
(( dry )) && mode="dry run: nothing is changed"
printf '%s%s · %s%s\n' "$dim" "${PRETTY_NAME:-${ID:-unknown system}}" "$mode" "$off"

# ─── 1. packages ───────────────────────────────────────────────────────────
step "Packages"
ids=" ${ID:-} ${ID_LIKE:-} "
pkgs=() mgr=() missing=() quickshell_hint="" apt=0
case "$ids" in
    *" debian "*|*" ubuntu "*)
        apt=1
        mgr=(sudo apt-get install -y -q)
        # Everything a fresh install needs. Names a release lacks are dropped
        # below (after apt-get update), so one list serves Debian and Ubuntu.
        pkgs=(
            # the shell, and the programs it runs
            quickshell i3 xclip xdotool maim imagemagick xwallpaper jq x11-xserver-utils
            xinput libnotify-bin xdg-utils curl python3 python3-xlib python3-gi
            qml6-module-qt-labs-folderlistmodel qml6-module-qtquick-effects
            # network, sound, Bluetooth, power, sensors, autostart
            network-manager pipewire pipewire-pulse wireplumber pulseaudio-utils bluez rfkill
            upower brightnessctl lm-sensors cava dex
            # fonts and icons: Cascadia Code NF is the bar's default font
            fonts-cascadia-code fonts-noto-color-emoji papirus-icon-theme fontconfig
            # what the theme hooks recolour, and the tools they use
            kitty qt5ct qt6ct xsettingsd libglib2.0-bin libgtk-3-bin
            # to build clipmenu (below) and unpack adw-gtk3: neither is packaged
            git build-essential libx11-dev libxfixes-dev xz-utils
        )
        # power-profiles-daemon conflicts with tlp: apt would remove it.
        dpkg -s tlp >/dev/null 2>&1 || pkgs+=(power-profiles-daemon)
        # A bare system: an X server, and a login screen if there's none.
        [[ -x /usr/lib/xorg/Xorg || -x /usr/bin/Xorg ]] || pkgs+=(xserver-xorg xinit)
        [[ -s /etc/X11/default-display-manager ]] || pkgs+=(lightdm lightdm-gtk-greeter)
        quickshell_hint="Your release doesn't package quickshell yet: build it from https://quickshell.org (0.3 or newer)." ;;
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

if (( packages && apt )); then
    # Debian 13 has quickshell only in backports.
    if [[ ${ID:-} == debian && -n ${VERSION_CODENAME:-} ]]; then
        bpo="${VERSION_CODENAME}-backports"
        sources="$(cat /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null || true)"
        if [[ $sources == *"$bpo"* ]]; then
            ok "$bpo is enabled."
        else
            say "Debian ${VERSION_ID:-} has Quickshell only in $bpo, which isn't enabled."
            say "Only packages that need it come from there; the rest stay on Debian ${VERSION_ID:-}."
            if ask "Enable $bpo?"; then
                run sudo sh -c "echo 'deb http://deb.debian.org/debian $bpo main' > /etc/apt/sources.list.d/$bpo.list" \
                    && ok "Enabled ($bpo in /etc/apt/sources.list.d/$bpo.list)."
            fi
        fi
    fi
    if ask "Refresh the package lists?"; then
        if run sudo apt-get update -q; then ok "Package lists refreshed."
        else warn "apt-get update failed: the package lists may be out of date."; fi
    fi
    # apt-get installs nothing if one name is unknown: drop those.
    found=() missing=()
    for p in "${pkgs[@]}"; do
        if apt-cache show "$p" >/dev/null 2>&1; then found+=("$p"); else missing+=("$p"); fi
    done
    pkgs=("${found[@]}")
    # Backports' quickshell needs a newer libpipewire than main's
    # pipewire-pulse accepts: then take the whole set from backports where it
    # has them. Captured, not piped into grep -q (see the fc-list note below).
    qs_policy="$(LC_ALL=C apt-cache policy quickshell 2>/dev/null || true)"
    if [[ ${ID:-} == debian && -n ${VERSION_CODENAME:-} && $qs_policy == *"Candidate: "*"~bpo"* ]]; then
        mgr+=(-t "${VERSION_CODENAME}-backports")
    fi
fi

if (( ! packages )); then
    say "Skipped (--no-packages)."
elif (( ${#pkgs[@]} == 0 )); then
    warn "Unknown distro (${ID:-?}): install the packages in the README's Requirements by hand."
else
    say "${#pkgs[@]} packages:"
    wrap "${pkgs[*]}"
    (( ${#missing[@]} )) && say "Not in your package lists, so left out: ${missing[*]}"
    if ask "Install them?"; then
        if run "${mgr[@]}" "${pkgs[@]}"; then ok "Packages installed."
        else fail "The package step failed (see above); the other steps still run."; fi
    fi
fi
if ! command -v qs >/dev/null; then
    if (( dry )); then say "Quickshell isn't installed yet (the package step installs it)."
    else warn "Quickshell (qs) isn't installed. $quickshell_hint"; fi
fi

# clipmenu 7 (text clipboard history) isn't packaged on Debian/Ubuntu.
if (( packages )) && ! command -v clipmenud >/dev/null; then
    cm="${XDG_CACHE_HOME:-$HOME/.cache}/$name/clipmenu"
    say "clipmenu 7 (clipboard history) isn't packaged here: it is built from github.com/cdown/clipmenu."
    if ask "Build and install clipmenu?"; then
        if (( dry )); then
            say "${dim}would clone or update $(t "$cm"), run make, then sudo make install${off}"
        elif ! command -v make >/dev/null || ! command -v git >/dev/null; then
            warn "Building clipmenu needs git and make (build-essential): install them, then run this again."
        else
            if { if [[ -d $cm/.git ]]; then git -C "$cm" pull -q --ff-only
                 else mkdir -p "${cm%/*}" && git clone -q --depth 1 https://github.com/cdown/clipmenu "$cm"; fi; } \
               && make -s -C "$cm" && run sudo make -s -C "$cm" install; then
                ok "clipmenu installed in /usr/local/bin."
            else
                fail "Building clipmenu failed (see above): the clipboard's text history needs it."
            fi
        fi
    fi
elif (( packages )); then
    ok "clipmenu is installed."
fi

# adw-gtk3: the GTK hook builds its themes on it (else GTK 3 apps stay plain
# Adwaita). Debian and Ubuntu don't package it, so fetch the release.
gtk_themes="${XDG_DATA_HOME:-$HOME/.local/share}/themes"
if (( packages )) && [[ ! -d $gtk_themes/adw-gtk3-dark && ! -d /usr/share/themes/adw-gtk3-dark ]]; then
    say "The GTK theme hook builds on adw-gtk3, which isn't packaged here (github.com/lassekongo83/adw-gtk3)."
    if ask "Download adw-gtk3 into ${gtk_themes/#$HOME/\~}?"; then
        if (( dry )); then
            say "${dim}would download the latest adw-gtk3 release${off}"
        else
            url="$(curl -fsSL https://api.github.com/repos/lassekongo83/adw-gtk3/releases/latest 2>/dev/null \
                   | jq -r 'first(.assets[] | select(.name | endswith(".tar.xz")) | .browser_download_url) // empty' 2>/dev/null || true)"
            if [[ -n $url ]] && mkdir -p "$gtk_themes" && curl -fsSL "$url" | tar -xJ -C "$gtk_themes"; then
                ok "adw-gtk3 installed (${url##*/})."
            else
                warn "Couldn't download adw-gtk3 (needs curl, jq, xz and a network): GTK 3 apps get plain Adwaita colours until it's in $(t "$gtk_themes")."
            fi
        fi
    fi
elif (( packages )); then
    ok "adw-gtk3 is installed."
fi

# Captured, not piped into grep -q: grep quitting early kills fc-list, and
# pipefail would read that as "no match". "NF" is how Cascadia names its
# Nerd Font build (the same test the shell's Settings uses).
fonts="$(fc-list : family 2>/dev/null || true)"
if [[ ${fonts,,} == *nerd* || $fonts =~ (^|[^[:alpha:]])NF[MP]?([^[:alpha:]]|$) ]]; then
    ok "A Nerd Font is installed (the bar's icons)."
elif (( dry )); then
    say "No Nerd Font yet (the package step installs Cascadia Code NF where it's packaged)."
else
    warn "No Nerd Font found: the bar's icons need one (e.g. Cascadia Code NF, or one from https://www.nerdfonts.com)."
fi

# ─── 2. location ───────────────────────────────────────────────────────────
step "Shell folder"
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
    ok "$(t "$dest") is this folder ('git pull' here updates it)."
elif [[ -L $dest ]]; then
    ok "$(t "$dest") links to $(t "$(readlink -f "$dest")"); leaving it alone."
    say "Remove the link and run this again to put a copy there instead."
elif [[ -f $dest/$marker ]]; then
    say "$(t "$dest") is a copy from $(t "$(sed -n 1p "$dest/$marker")") (version $(sed -n 2p "$dest/$marker"))."
    if ask "Update it from $(t "$src")?"; then
        if (( dry )); then say "${dim}would replace $(t "$dest") with a fresh copy of $(t "$src")${off}"
        else put_copy; ok "Updated. Restart a running shell with: pkill -x qs; setsid -f qs -c $name"; fi
    fi
elif [[ -e $dest ]]; then
    warn "$(t "$dest") exists and wasn't made by this installer, so it was left alone: move it aside and run this again."
elif ask "Copy the shell to $(t "$dest")?"; then
    if (( dry )); then say "${dim}would copy $(t "$src") to $(t "$dest")${off}"
    else put_copy; ok "Copied. To update later: 'git pull' here, then run this again."; fi
fi
[[ -d $userdir ]] || run mkdir -p "$userdir"
# Included by the i3 block below; the i3 theme hook fills it on the first theme switch.
[[ -e $userdir/i3-colors.config ]] || run touch "$userdir/i3-colors.config"

# ─── 3. i3 ─────────────────────────────────────────────────────────────────
step "i3 config"
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
# Clipboard history, and the XSETTINGS daemon GTK apps take their theme from.
exec --no-startup-id sh -c 'pgrep -x clipmenud >/dev/null || exec clipmenud'
exec --no-startup-id sh -c 'pgrep -x xsettingsd >/dev/null || [ ! -f \"\${XDG_CONFIG_HOME:-\$HOME/.config}/xsettingsd/xsettingsd.conf\" ] || exec xsettingsd'
$end"
i3dir="$config/i3"
wizard=0
[[ -n $i3conf ]] && head -1 "$i3conf" | grep -q 'auto-generated by i3-config-wizard' && wizard=1
if [[ -z $i3conf ]] || (( wizard || i3starter )); then
    # The starter: a whole config laid out the way Settings → Keybinds and
    # i3 Options edit it (modules/keys/*.config, modules/window-options.config).
    if [[ -z $i3conf ]]; then
        say "No i3 config yet."
    elif (( wizard )); then
        say "$(t "$i3conf") is i3's generated default: its \$mod+d/s/v/e binds clash with the shell's."
    fi
    say "The starter config: Super+d launcher, Super+s settings, Super+v clipboard, Super+Return"
    say "terminal, Super+h/j/k/l focus, Super+/ every shortcut. Keys, gaps and borders are editable in Settings."
    if ask "Install it in $(t "$i3dir")${i3conf:+ (the old folder is kept as a backup)}?"; then
        if (( dry )); then
            say "${dim}would copy $(t "$src")/i3/starter/ to $(t "$i3dir")/${off}"
        else
            backup=""
            if [[ -e $i3dir ]]; then
                backup="$i3dir.before-revenant"
                [[ -e $backup ]] && backup="$backup-$(date +%Y%m%d-%H%M%S)"
                mv "$i3dir" "$backup"
            fi
            mkdir -p "$i3dir"
            cp -r "$src/i3/starter/." "$i3dir/"
            errors=""
            if command -v i3 >/dev/null && ! errors="$(i3 -C -c "$i3dir/config" 2>&1)"; then
                rm -rf "$i3dir"
                [[ -n $backup ]] && mv "$backup" "$i3dir"
                fail "i3 -C rejected the starter config${backup:+, so your old one is back}. Its errors:"
                head -10 <<<"$errors" | quote
            else
                ok "Starter config installed.${backup:+ Your old config is in $(t "$backup").}"
                # i3 restart keeps the open windows; it also starts the shell
                # through the new config's exec if it isn't running.
                if i3-msg -t get_version >/dev/null 2>&1 && ask "i3 is running: restart it now to load the new config?"; then
                    i3-msg restart >/dev/null 2>&1 || true
                    pgrep -x qs >/dev/null || setsid -f qs -c "$name" >/dev/null 2>&1
                    ok "i3 restarted."
                fi
            fi
        fi
    fi
elif head -1 "$i3conf" | grep -q "^# i3 config from Revenant's starter"; then
    ok "$(t "$i3conf") is Revenant's starter config (--i3-starter installs a fresh one)."
elif grep -qF "$begin" "$i3conf"; then
    ok "$(t "$i3conf") has the Revenant block already."
elif grep -qE "quickshell/$name/i3/revenant\.config|qs -c $name\b" "$i3conf"; then
    ok "$(t "$i3conf") already includes the shell or starts it (set up by hand); leaving it alone."
elif command -v i3 >/dev/null && ! i3 -C -c "$i3conf" >/dev/null 2>&1; then
    warn "$(t "$i3conf") already fails 'i3 -C -c $(t "$i3conf")': fix that first, then run this again."
else
    grep -nE '^[[:space:]]*bar[[:space:]]*\{' "$i3conf" >/dev/null \
        && warn "$(t "$i3conf") has an i3bar 'bar { }' block: remove it, or you get two bars."
    grep -nE 'exec.*\b(polybar|dunst|mako|rofi .*-show)\b' "$i3conf" | sed 's/^/line /' | quote || true
    if ask "Add the Revenant block to the end of $(t "$i3conf")?"; then
        if (( dry )); then
            say "${dim}would append:${off}"; quote <<<"$block"
        else
            backup="$i3conf.before-revenant"
            cp -p "$i3conf" "$backup"
            printf '\n%s\n' "$block" >> "$i3conf"
            errors=""
            if command -v i3 >/dev/null && ! errors="$(i3 -C -c "$i3conf" 2>&1)"; then
                cp -p "$backup" "$i3conf"
                fail "i3 -C rejected the result, so $(t "$i3conf") is back as it was. Its errors:"
                head -10 <<<"$errors" | quote
                [[ $errors == *"Duplicate keybinding"* ]] &&
                    say "Your binds clash with the shell's defaults: run this again with --i3-starter for its config (yours is kept as a backup), or add the block yourself without the revenant-keys.config line."
            else
                ok "Added. Your old config is in $(t "$backup")."
            fi
        fi
    fi
fi

# ─── 4. environment ────────────────────────────────────────────────────────
# The shell applies key repeat, blanking, power saving, the login volume and
# the wallpaper itself. Two variables have to come from the session: the
# login screen's Xsession reads ~/.xsessionrc on Debian and Ubuntu (Debian's
# ignores ~/.xprofile), ~/.xprofile elsewhere.
step "Session environment"
envfile="$HOME/.xprofile"
compgen -G "/etc/X11/Xsession.d/*xsessionrc" >/dev/null && envfile="$HOME/.xsessionrc"
env_begin="# >>> revenant environment (added by install.sh) >>>"
env_end="# <<< revenant environment <<<"
env_block="$env_begin
# Tray icons are looked up in this icon theme (without one they show as checkerboards).
export QS_ICON_THEME=\"\${QS_ICON_THEME:-Papirus-Dark}\"
# Qt apps take the theme's colours from qt5ct / qt6ct (qt6ct answers to qt5ct too).
export QT_QPA_PLATFORMTHEME=\"\${QT_QPA_PLATFORMTHEME:-qt5ct}\"
$env_end"
# Set already, by this script or by hand, in any file a session reads?
setenv="$(cat "$HOME/.xprofile" "$HOME/.xsessionrc" "$HOME/.profile" 2>/dev/null || true)"
if [[ $setenv == *"$env_begin"* ]]; then
    ok "QS_ICON_THEME and QT_QPA_PLATFORMTHEME are set (installer block)."
elif [[ $setenv == *QS_ICON_THEME=* && $setenv == *QT_QPA_PLATFORMTHEME=* ]]; then
    ok "QS_ICON_THEME and QT_QPA_PLATFORMTHEME are set in your session files."
else
    say "Tray icons need an icon theme (QS_ICON_THEME), and Qt apps follow the theme through qt5ct (QT_QPA_PLATFORMTHEME)."
    if ask "Set them in ${envfile/#$HOME/\~}?"; then
        if (( dry )); then
            say "${dim}would append:${off}"; quote <<<"$env_block"
        else
            printf '\n%s\n' "$env_block" >> "$envfile"
            ok "Added to ${envfile/#$HOME/\~} (read at your next login)."
        fi
    fi
fi

# ─── 5. theme ──────────────────────────────────────────────────────────────
# The theme hooks recolour kitty, GTK and Qt, but only run on a theme switch:
# run them once now for the current theme, so a new install is themed from
# the first login.
step "Theme"
shell_dir="$dest"; [[ -f $shell_dir/shell.qml ]] || shell_dir="$src"
slug="$(cat "${XDG_STATE_HOME:-$HOME/.local/state}/$name/current" 2>/dev/null || true)"
slug="${slug:-dracula}"
say "The theme hooks recolour i3, kitty, GTK and Qt apps to match the shell on every theme switch."
if ask "Apply the '$slug' theme to them now?"; then
    if (( dry )); then
        say "${dim}would run: $shell_dir/scripts/theming/apply-theme-externals.sh $slug${off}"
    elif bash "$shell_dir/scripts/theming/apply-theme-externals.sh" "$slug" 2>&1 | quote; then
        ok "Applied '$slug'. Change it any time in Settings → Themes & wallpapers."
    else
        warn "Some theme hooks failed (above); the others still ran."
    fi
fi

# ─── done ──────────────────────────────────────────────────────────────────
printf '\n%s%sDone%s\n' "$bold" "$green" "$off"
if (( dry )); then
    say "Dry run: nothing was changed."
    exit 0
fi
if (( ${#attention[@]} )); then
    printf '\n  %sNeeds attention:%s\n' "$yellow" "$off"
    for a in "${attention[@]}"; do printf '    %s!%s %s\n' "$yellow" "$off" "$a"; done
fi
printf '\n  %sNext:%s\n' "$bold" "$off"
say "1. Log out, pick i3 at the login screen and log in: the shell starts with the session."
say "2. Super+/ lists every shortcut: Super+d launcher, Super+Return terminal, Super+s settings."
say "3. Your settings live in $(t "$userdir")."
