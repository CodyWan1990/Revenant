#!/usr/bin/env bash
# theme-hook: GTK apps
# GTK 3 recolours live through a generated X11ThemeA/B theme and xsettingsd; GTK 4 and libadwaita apps pick up ~/.config/gtk-4.0/gtk.css when they start.
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../hook-lib.sh"
GTK3_THEME="adw-gtk3-dark"
appearance_lock

# ── GTK 3 / 4 ─────────────────────────────────────────────────────────────────
GTK_MARK='/* nirishell theme:'   # kept: other shells (nirishell) treat this marker as managed
gtk_css=$(cat <<EOF
$GTK_MARK $NAME (written by the shell's apply-theme.sh) - libadwaita / adw-gtk3 named colours */
@define-color accent_color        $BLUE;
@define-color accent_bg_color     $BLUE;
@define-color accent_fg_color     $BG;

@define-color window_bg_color     $BG;
@define-color window_fg_color     $FG;
@define-color view_bg_color       $BG;
@define-color view_fg_color       $FG;

@define-color headerbar_bg_color  $SELECTION;
@define-color headerbar_fg_color  $FG;
@define-color headerbar_border_color $SELECTION;
@define-color headerbar_backdrop_color $BG;

@define-color card_bg_color       $SELECTION;
@define-color card_fg_color       $FG;
@define-color popover_bg_color    $SELECTION;
@define-color popover_fg_color    $FG;
@define-color dialog_bg_color     $BG;
@define-color dialog_fg_color     $FG;
@define-color sidebar_bg_color    $BG;
@define-color sidebar_fg_color    $FG;

@define-color destructive_bg_color $RED;
@define-color destructive_fg_color $BG;
@define-color destructive_color    $RED;
@define-color success_color        $GREEN;
@define-color success_bg_color     $GREEN;
@define-color warning_color        $YELLOW;
@define-color warning_bg_color     $YELLOW;
@define-color error_color          $RED;
@define-color error_bg_color       $RED;

/* legacy GTK names */
@define-color theme_bg_color          $BG;
@define-color theme_fg_color          $FG;
@define-color theme_base_color        $BG;
@define-color theme_text_color        $FG;
@define-color theme_selected_bg_color $BLUE;
@define-color theme_selected_fg_color $BG;
@define-color insensitive_bg_color    $BG;
@define-color insensitive_fg_color    $COMMENT;
@define-color insensitive_base_color  $SELECTION;
@define-color borders                 $SELECTION;
@define-color unfocused_borders       $SELECTION;
EOF
)

# User gtk.css files. They load at *user* priority, above the theme, and are
# only read when an app starts:
#   GTK4/libadwaita ignores themes, so its gtk.css carries the colours (new
#     GTK4 windows get them; open ones can't be recoloured).
#   GTK3 gets the colours from the generated theme below instead. Its gtk.css
#     must NOT define colours: they would override the theme and freeze open
#     apps on whatever palette they started with. Only the marker stays, so
#     nirishell still recognises the file as managed.
gtk3_css="$GTK_MARK $NAME (written by the shell's apply-theme.sh) - colours come from the X11ThemeA/B GTK theme */"
for g in "$CFG/gtk-3.0/gtk.css" "$CFG/gtk-4.0/gtk.css"; do
    # Keep one backup of a gtk.css none of the theme scripts wrote (same name
    # nirishell uses, so its "off" switch restores it).
    if [[ -f $g ]] && ! grep -qF "$GTK_MARK" "$g"; then cp -n "$g" "$g.nirbak" 2>/dev/null || true; fi
done
write_if_changed "$CFG/gtk-3.0/gtk.css" "$gtk3_css" || true
write_if_changed "$CFG/gtk-4.0/gtk.css" "$gtk_css"  || true

# GTK3 live: running GTK3 apps reload their *theme* when xsettingsd announces
# a new theme name, but not gtk.css. So the colours also go into a tiny
# generated theme (adw-gtk3-dark + the overrides above) in one of two slots,
# X11ThemeA / X11ThemeB, alternating so every change is a new name.
THEMES="${XDG_DATA_HOME:-$HOME/.local/share}/themes"
# adw-gtk3 isn't packaged everywhere (not in Ubuntu's archive, so it may be a
# user install): look in the user themes dir first, then the system one.
GTK_BASE=""
for d in "$THEMES" /usr/share/themes; do
    [[ -d $d/$GTK3_THEME/gtk-3.0 ]] && { GTK_BASE=$d/$GTK3_THEME/gtk-3.0; break; }
done
XS="$CFG/xsettingsd/xsettingsd.conf"

theme_css() {   # $1 = gtk.css | gtk-dark.css of the base theme to import
    printf '@import url("file://%s/%s");\n\n%s\n' "$GTK_BASE" "$1" "$gtk_css"
}

active_gtk=$(sed -n 's/^Net\/ThemeName "\(.*\)"/\1/p' "$XS" 2>/dev/null || true)   # no file yet: set -e would end the script here
gtk_theme=Adwaita-dark                         # fallback: GTK's built-in dark theme
if [[ -n $GTK_BASE ]]; then
    case "$active_gtk" in
        X11ThemeA) cur=X11ThemeA next=X11ThemeB ;;
        X11ThemeB) cur=X11ThemeB next=X11ThemeA ;;
        *)         cur=""        next=X11ThemeA ;;
    esac
    if [[ -n $cur && $(cat "$THEMES/$cur/gtk-3.0/gtk.css" 2>/dev/null) == "$(theme_css gtk.css)" ]]; then
        gtk_theme=$cur                          # already showing these colours
    else
        gtk_theme=$next
        mkdir -p "$THEMES/$next/gtk-3.0"
        theme_css gtk.css      > "$THEMES/$next/gtk-3.0/gtk.css"
        theme_css gtk-dark.css > "$THEMES/$next/gtk-3.0/gtk-dark.css"
        printf '[Desktop Entry]\nType=X-GNOME-Metatheme\nName=%s\nComment=%s (generated by apply-theme.sh)\n' \
            "$next" "$NAME" > "$THEMES/$next/index.theme"
    fi
fi

# Point everything at that theme: settings.ini (apps started without an
# XSETTINGS daemon), gsettings, and xsettingsd (running apps, live).
for ini in "$CFG/gtk-3.0/settings.ini" "$CFG/gtk-4.0/settings.ini"; do
    [[ -f $ini ]] || continue
    grep -qx "gtk-theme-name=$gtk_theme" "$ini" && continue
    if grep -q '^gtk-theme-name=' "$ini"; then
        sed --follow-symlinks -i "s/^gtk-theme-name=.*/gtk-theme-name=$gtk_theme/" "$ini"
    else
        sed --follow-symlinks -i "/^\[Settings\]/a gtk-theme-name=$gtk_theme" "$ini"
    fi
done
if command -v gsettings >/dev/null 2>&1 \
   && [[ $(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null) != "'$gtk_theme'" ]]; then
    gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme" 2>/dev/null || true
fi
# No xsettingsd config yet (Plasma used to write one; GNOME uses its own
# gsd-xsettings instead): seed it with the icons/cursor/font GNOME had, so
# GTK apps outside GNOME keep them. Desktop Appearance manages icon and cursor choices.
if [[ ! -f $XS ]] && command -v xsettingsd >/dev/null 2>&1; then
    gs() { gsettings get org.gnome.desktop.interface "$1" 2>/dev/null | tr -d "'"; }
    icons=$(gs icon-theme) cursor=$(gs cursor-theme) csize=$(gs cursor-size) font=$(gs font-name)
    mkdir -p "${XS%/*}"
    cat > "$XS" <<EOF
Net/ThemeName "$gtk_theme"
Net/IconThemeName "${icons:-Adwaita}"
Gtk/CursorThemeName "${cursor:-Adwaita}"
Gtk/CursorThemeSize ${csize:-24}
Gtk/FontName "${font:-Sans 10}"
Xft/Antialias 1
Xft/Hinting 1
Xft/HintStyle "hintslight"
Xft/RGBA "rgb"
EOF
fi
if [[ -f $XS ]]; then
    # Make sure the daemon is up (Plasma used to start it); open GTK apps
    # attach to it as soon as it appears.
    if ! pgrep -x xsettingsd >/dev/null; then
        systemctl --user start xsettingsd.service 2>/dev/null || { setsid -f xsettingsd 9>&- >/dev/null 2>&1 || true; }
        sleep 0.3
    fi
    if [[ $active_gtk != "$gtk_theme" ]]; then
        if grep -q '^Net/ThemeName' "$XS"; then
            sed --follow-symlinks -i "s|^Net/ThemeName .*|Net/ThemeName \"$gtk_theme\"|" "$XS"
        else
            printf 'Net/ThemeName "%s"\n' "$gtk_theme" >> "$XS"
        fi
        pkill -HUP -x xsettingsd || true
    fi
fi

exit 0
