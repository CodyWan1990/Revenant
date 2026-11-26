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
#   1. packages   everything a fresh system needs, with sudo, on Debian/Ubuntu,
#                 Arch and Fedora: where Quickshell 0.3 comes from (Debian 13:
#                 trixie-backports; Fedora: the errornointernet/quickshell
#                 COPR), a refresh (Arch: pacman -Syu), then the full list
#                 (the shell, sound, network, fonts, icons, kitty, qt5ct/qt6ct,
#                 xsettingsd, and an X server and LightDM, enabled, if there's
#                 no login screen). Builds clipmenu 7 (no distro has it) and,
#                 where they aren't packaged, xwallpaper and adw-gtk3
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
#                 colours), appended between marker lines to the file your
#                 login script reads (~/.xsessionrc on Debian/Ubuntu,
#                 ~/.xprofile on Arch, ~/.profile on Fedora); skipped if your
#                 session files set them already
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

# REVENANT_OS_RELEASE: another os-release file, to try other distros' branches.
. "${REVENANT_OS_RELEASE:-/etc/os-release}" 2>/dev/null || true
printf '\n%sRevenant%s %s· i3 desktop shell installer%s\n' "$bold" "$off" "$dim" "$off"
mode="asks before each step"
(( yes )) && mode="answering yes to everything"
(( dry )) && mode="dry run: nothing is changed"
printf '%s%s · %s%s\n' "$dim" "${PRETTY_NAME:-${ID:-unknown system}}" "$mode" "$off"

# ─── 1. packages ───────────────────────────────────────────────────────────
step "Packages"
ids=" ${ID:-} ${ID_LIKE:-} "
# Per distro: the install command (mgr), an optional refresh, the packages,
# the X server and login screen for a bare system, and a hint for when
# Quickshell is missing or too old. Every list was checked against the
# distro's own package index; names a release lacks are dropped (apt,
# pacman) or skipped (dnf) rather than failing the whole install.
fam="" pkgs=() mgr=() refresh=() xorg_pkgs=() dm_pkgs=() missing=() quickshell_hint=""
case "$ids" in
    *" debian "*|*" ubuntu "*)
        fam=apt
        mgr=(sudo apt-get install -y -q)
        refresh=(sudo apt-get update -q)
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
            # to build clipmenu and unpack adw-gtk3 (below): neither is packaged
            git build-essential libx11-dev libxfixes-dev xz-utils
        )
        # power-profiles-daemon conflicts with tlp: apt would remove it.
        dpkg -s tlp >/dev/null 2>&1 || pkgs+=(power-profiles-daemon)
        xorg_pkgs=(xserver-xorg xinit) dm_pkgs=(lightdm lightdm-gtk-greeter)
        quickshell_hint="If your release has no Quickshell 0.3, build it from https://quickshell.org." ;;
    *" arch "*)
        fam=pacman
        mgr=(sudo pacman -S --needed --noconfirm)
        # Arch doesn't support partial upgrades: sync and upgrade together.
        refresh=(sudo pacman -Syu --noconfirm)
        pkgs=(
            quickshell i3-wm xclip xdotool maim imagemagick xwallpaper jq xorg-xset xorg-xrandr
            xorg-xinput libnotify xdg-utils curl python python-xlib python-gobject qt6-declarative
            networkmanager pipewire pipewire-pulse wireplumber libpulse bluez bluez-utils upower
            brightnessctl lm_sensors cava dex
            ttf-cascadia-code-nerd noto-fonts-emoji papirus-icon-theme fontconfig
            kitty qt5ct qt6ct xsettingsd glib2 gtk3 adw-gtk-theme
            # Arch's clipmenu is 6.x; version 7 is built below
            git base-devel libx11 libxfixes xz
        )
        pacman -Q tlp >/dev/null 2>&1 || pkgs+=(power-profiles-daemon)
        xorg_pkgs=(xorg-server xorg-xinit) dm_pkgs=(lightdm lightdm-gtk-greeter)
        quickshell_hint="Quickshell is in Arch's extra repository: 'sudo pacman -Syu quickshell'." ;;
    *" fedora "*)
        fam=dnf
        # --skip-unavailable: a release without one of these still gets the rest.
        mgr=(sudo dnf install -y --skip-unavailable)
        pkgs=(
            quickshell i3 xclip xdotool maim ImageMagick jq xset xrandr xinput libnotify xdg-utils
            curl python3 python3-xlib python3-gobject qt6-qtdeclarative
            NetworkManager pipewire pipewire-pulseaudio wireplumber pulseaudio-utils bluez upower
            brightnessctl lm_sensors cava dex-autostart
            cascadia-code-nf-fonts google-noto-color-emoji-fonts papirus-icon-theme fontconfig
            kitty qt5ct qt6ct xsettingsd glib2 gtk3 adw-gtk3-theme
            # to build clipmenu and xwallpaper (below): Fedora packages neither
            git gcc make xz libX11-devel libXfixes-devel pixman-devel libxcb-devel xcb-util-devel
            xcb-util-image-devel libpng-devel libjpeg-turbo-devel libXpm-devel
        )
        # Fedora's power profiles come from tuned-ppd; it conflicts with tlp
        # and power-profiles-daemon, so leave either of those alone.
        rpm -q tlp >/dev/null 2>&1 || rpm -q power-profiles-daemon >/dev/null 2>&1 || pkgs+=(tuned-ppd)
        xorg_pkgs=(xorg-x11-server-Xorg xorg-x11-xinit) dm_pkgs=(lightdm lightdm-gtk)
        quickshell_hint="Fedora's own quickshell is older than 0.3: use the COPR, 'sudo dnf copr enable errornointernet/quickshell && sudo dnf upgrade quickshell'." ;;
esac

# A bare system: an X server, and a login screen if none is set up.
add_dm=0
if [[ -n $fam ]]; then
    [[ -x /usr/lib/xorg/Xorg || -x /usr/bin/Xorg || -x /usr/libexec/Xorg ]] || pkgs+=("${xorg_pkgs[@]}")
    if [[ ! -e /etc/systemd/system/display-manager.service && ! -s /etc/X11/default-display-manager ]]; then
        pkgs+=("${dm_pkgs[@]}")
        add_dm=1
    fi
fi

if (( packages )) && [[ -n $fam ]]; then
    # Where Quickshell 0.3 comes from outside the main repositories.
    if [[ $fam == apt && ${ID:-} == debian && -n ${VERSION_CODENAME:-} ]]; then
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
    elif [[ $fam == dnf ]]; then
        copr="errornointernet/quickshell"
        if compgen -G "/etc/yum.repos.d/*errornointernet*quickshell*.repo" >/dev/null; then
            ok "The $copr COPR is enabled."
        else
            say "Fedora's own Quickshell is older than 0.3; the $copr COPR has the current release."
            if ask "Enable the $copr COPR?"; then
                # `dnf copr` is a plugin: dnf5-plugins (dnf-plugins-core before Fedora 41).
                dnf copr --help >/dev/null 2>&1 \
                    || run sudo dnf install -y -q dnf5-plugins \
                    || run sudo dnf install -y -q dnf-plugins-core || true
                if run sudo dnf copr enable -y "$copr"; then ok "COPR enabled."
                else warn "Couldn't enable the $copr COPR (see above)."; fi
            fi
        fi
    fi

    if (( ${#refresh[@]} )); then
        if [[ $fam == pacman ]]; then
            say "Arch installs from an up-to-date package database only, so this upgrades the system first."
            prompt="Sync and upgrade the system (pacman -Syu)?"
        else
            prompt="Refresh the package lists?"
        fi
        if ask "$prompt"; then
            if run "${refresh[@]}"; then ok "Package lists are up to date."
            else warn "The refresh failed: the package lists may be out of date."; fi
        fi
    fi

    # apt-get and pacman install nothing if one name is unknown: drop those.
    if [[ $fam == apt || $fam == pacman ]]; then
        found=() missing=()
        for p in "${pkgs[@]}"; do
            if [[ $fam == apt ]]; then apt-cache show "$p" >/dev/null 2>&1
            else pacman -Si "$p" >/dev/null 2>&1; fi && found+=("$p") || missing+=("$p")
        done
        pkgs=("${found[@]}")
    fi
    # Backports' quickshell needs a newer libpipewire than main's
    # pipewire-pulse accepts: then take the whole set from backports where it
    # has them. Captured, not piped into grep -q (see the fc-list note below).
    if [[ $fam == apt && ${ID:-} == debian && -n ${VERSION_CODENAME:-} ]]; then
        qs_policy="$(LC_ALL=C apt-cache policy quickshell 2>/dev/null || true)"
        [[ $qs_policy == *"Candidate: "*"~bpo"* ]] && mgr+=(-t "${VERSION_CODENAME}-backports")
    fi
fi

if (( ! packages )); then
    say "Skipped (--no-packages)."
elif [[ -z $fam ]]; then
    warn "Unknown distro (${ID:-?}): install the packages in the README's Packages section by hand."
elif (( ${#pkgs[@]} == 0 )); then
    warn "None of the packages are in your package lists: refresh them (answer yes above), then run this again."
else
    say "${#pkgs[@]} packages:"
    wrap "${pkgs[*]}"
    (( ${#missing[@]} )) && say "Not in your package lists, so left out: ${missing[*]}"
    if ask "Install them?"; then
        if run "${mgr[@]}" "${pkgs[@]}"; then
            ok "Packages installed."
            if (( add_dm )) && ! (( dry )); then
                # Debian enables a newly installed login screen itself; Arch
                # and Fedora don't, and a minimal install boots to a console.
                if run sudo systemctl enable lightdm && run sudo systemctl set-default graphical.target; then
                    ok "LightDM is enabled: the next boot shows a login screen."
                else
                    warn "Couldn't enable LightDM: run 'sudo systemctl enable lightdm' and 'sudo systemctl set-default graphical.target'."
                fi
            fi
        else
            fail "The package step failed (see above); the other steps still run."
        fi
    fi
fi

# Services the shell talks to. Debian and Fedora enable them when they're
# installed; Arch leaves that to you. NetworkManager only if nothing else
# manages the network, since two network managers fight over it.
if (( packages )) && [[ -n $fam ]] && command -v systemctl >/dev/null; then
    services=()
    [[ $(systemctl is-enabled bluetooth.service 2>/dev/null) == disabled ]] && services+=(bluetooth)
    if [[ $(systemctl is-enabled NetworkManager.service 2>/dev/null) == disabled ]]; then
        other=""
        for unit in systemd-networkd dhcpcd iwd connman netctl; do
            systemctl is-active --quiet "$unit" 2>/dev/null && { other=$unit; break; }
        done
        if [[ -n $other ]]; then
            say "NetworkManager isn't enabled: $other manages your network, so it's left as it is (the shell's Wi-Fi and network panels need NetworkManager)."
        else
            services+=(NetworkManager)
        fi
    fi
    if (( ${#services[@]} )); then
        say "Installed but not enabled: ${services[*]} (Bluetooth and network panels need them)."
        if ask "Enable and start them?"; then
            if run sudo systemctl enable --now "${services[@]/%/.service}"; then ok "Enabled: ${services[*]}."
            else warn "Couldn't enable ${services[*]}: run 'sudo systemctl enable --now ${services[*]/%/.service}'."; fi
        fi
    fi
fi
if ! command -v qs >/dev/null; then
    if (( dry )); then say "Quickshell isn't installed yet (the package step installs it)."
    else warn "Quickshell (qs) isn't installed. $quickshell_hint"; fi
else
    # Revenant needs 0.3. Captured and matched with sed, not piped into
    # grep|head (see the fc-list note below).
    qs_version="$(qs --version 2>/dev/null | sed -nE '1s/^[Qq]uickshell v?([0-9]+(\.[0-9]+)+).*/\1/p' || true)"
    if [[ -z $qs_version ]]; then
        say "Couldn't read Quickshell's version; Revenant needs 0.3 or newer."
    elif [[ $(sort -V <<<"0.3"$'\n'"$qs_version" | sed -n 1p) == 0.3 ]]; then
        ok "Quickshell $qs_version is installed."
    else
        warn "Quickshell $qs_version is too old: Revenant needs 0.3 or newer. $quickshell_hint"
    fi
fi

build_root="${XDG_CACHE_HOME:-$HOME/.cache}/$name"

# clipmenu 7 (text clipboard history): no distro packages it (Arch's is the
# older 6.x shell script), so build it. Version 7 is a compiled program.
clipmenud_path="$(command -v clipmenud || true)"
clip_old=0
[[ -n $clipmenud_path && $(head -c2 "$clipmenud_path" 2>/dev/null) == '#!' ]] && clip_old=1
if (( packages )) && [[ -z $clipmenud_path ]] || (( packages && clip_old )); then
    cm="$build_root/clipmenu"
    if (( clip_old )); then
        say "$clipmenud_path is clipmenu 6 (a shell script); the clipboard panel needs clipmenu 7."
    else
        say "clipmenu 7 (clipboard history) isn't packaged here: it is built from github.com/cdown/clipmenu."
    fi
    if ask "Build and install clipmenu 7 into /usr/local?"; then
        if (( dry )); then
            say "${dim}would clone or update $(t "$cm"), run make, then sudo make install${off}"
        elif ! command -v make >/dev/null || ! command -v git >/dev/null; then
            warn "Building clipmenu needs git and make: install them, then run this again."
        else
            if { if [[ -d $cm/.git ]]; then git -C "$cm" pull -q --ff-only
                 else mkdir -p "$build_root" && git clone -q --depth 1 https://github.com/cdown/clipmenu "$cm"; fi; } \
               && make -s -C "$cm" && run sudo make -s -C "$cm" install; then
                ok "clipmenu 7 installed in /usr/local/bin."
            else
                fail "Building clipmenu failed (see above): the clipboard's text history needs it."
            fi
        fi
    fi
elif (( packages )); then
    ok "clipmenu 7 is installed."
fi

# xwallpaper (sets the wallpaper): Fedora doesn't package it, so build the
# release, which ships a ready configure script.
if (( packages )) && ! command -v xwallpaper >/dev/null; then
    xw="$build_root/xwallpaper"
    say "xwallpaper (sets the wallpaper) isn't packaged here: it is built from its release (github.com/stoeckmann/xwallpaper)."
    if ask "Build and install xwallpaper into /usr/local?"; then
        if (( dry )); then
            say "${dim}would download the latest xwallpaper release, configure, make and sudo make install${off}"
        else
            url="$(curl -fsSL https://api.github.com/repos/stoeckmann/xwallpaper/releases/latest 2>/dev/null \
                   | jq -r 'first(.assets[] | select(.name | endswith(".tar.xz")) | .browser_download_url) // empty' 2>/dev/null || true)"
            if [[ -n $url ]] && rm -rf "$xw" && mkdir -p "$xw" && curl -fsSL "$url" | tar -xJ -C "$xw" --strip-components=1 \
               && ( cd "$xw" && ./configure -q && make -s ) && run sudo make -s -C "$xw" install; then
                ok "xwallpaper installed in /usr/local/bin (${url##*/})."
            else
                fail "Building xwallpaper failed (see above): the shell can't set a wallpaper without it."
            fi
        fi
    fi
fi

# adw-gtk3: the GTK hook builds its themes on it (else GTK 3 apps stay plain
# Adwaita). Arch and Fedora package it; Debian and Ubuntu don't, so fetch it.
gtk_themes="${XDG_DATA_HOME:-$HOME/.local/share}/themes"
if (( packages )) && [[ ! -d $gtk_themes/adw-gtk3-dark && ! -d /usr/share/themes/adw-gtk3-dark ]]; then
    say "The GTK theme hook builds on adw-gtk3, which isn't installed (github.com/lassekongo83/adw-gtk3)."
    if ask "Download adw-gtk3 into ${gtk_themes/#$HOME/\~}?"; then
        if (( dry )); then
            say "${dim}would download the latest adw-gtk3 release${off}"
        else
            url="$(curl -fsSL https://api.github.com/repos/lassekongo83/adw-gtk3/releases/latest 2>/dev/null \
                   | jq -r 'first(.assets[] | select(.name | endswith(".tar.xz")) | .browser_download_url) // empty' 2>/dev/null || true)"
            if [[ -n $url ]] && mkdir -p "$gtk_themes" && curl -fsSL "$url" | tar -xJ -C "$gtk_themes"; then
                ok "adw-gtk3 installed (${url##*/})."
            else
                warn "Couldn't download adw-gtk3 (needs curl, jq, xz and a network): GTK 3 apps get plain Adwaita colours until it's in $gtk_themes."
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
    say "No Nerd Font yet (the package step installs Cascadia Code NF)."
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
# the wallpaper itself. Two variables have to come from the session, and
# each distro's login script reads a different file: Debian/Ubuntu's Xsession
# ~/.xsessionrc (Debian's ignores ~/.xprofile), Arch's LightDM wrapper
# ~/.xprofile, Fedora's xinitrc-common ~/.profile. Ask the scripts rather
# than the distro name.
step "Session environment"
session_scripts=(/etc/lightdm/Xsession /usr/bin/lightdm-session /usr/sbin/lightdm-session
                 /etc/X11/xinit/Xsession /etc/X11/xinit/xinitrc-common /etc/X11/Xsession)
if compgen -G "/etc/X11/Xsession.d/*xsessionrc" >/dev/null; then
    envfile="$HOME/.xsessionrc"
elif grep -qs 'HOME/\.xprofile' "${session_scripts[@]}"; then
    envfile="$HOME/.xprofile"
elif grep -qs 'HOME/\.profile' "${session_scripts[@]}"; then
    envfile="$HOME/.profile"
else
    envfile="$HOME/.xprofile"
fi
env_begin="# >>> revenant environment (added by install.sh) >>>"
env_end="# <<< revenant environment <<<"
env_block="$env_begin
# Tray icons are looked up in this icon theme (without one they show as checkerboards).
export QS_ICON_THEME=\"\${QS_ICON_THEME:-Papirus-Dark}\"
# Qt apps take the theme's colours from qt5ct / qt6ct (qt6ct answers to qt5ct too).
export QT_QPA_PLATFORMTHEME=\"\${QT_QPA_PLATFORMTHEME:-qt5ct}\"
$env_end"
# Set already, by this script or by hand, in any file a session reads?
# The installer's own block counts only in the file this login reads (an
# older run may have put it in one that isn't read); one you wrote yourself
# counts anywhere.
setenv="$(cat "$HOME/.xprofile" "$HOME/.xsessionrc" "$HOME/.profile" 2>/dev/null || true)"
ownenv="${setenv//"$env_block"/}"
if grep -qsF "$env_begin" "$envfile"; then
    ok "QS_ICON_THEME and QT_QPA_PLATFORMTHEME are set (installer block in $(t "$envfile"))."
elif [[ $ownenv == *QS_ICON_THEME=* && $ownenv == *QT_QPA_PLATFORMTHEME=* ]]; then
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
