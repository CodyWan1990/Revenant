#!/usr/bin/env bash
# theme-hook: Qt apps
# qt5ct / qt6ct palette with the Fusion style; open Qt apps update about 3 s later. Needs QT_QPA_PLATFORMTHEME=qt5ct in the session.
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../hook-lib.sh"
appearance_lock

# ── Qt 5 / 6 (qt5ct / qt6ct) ──────────────────────────────────────────────────
# Palette roles, in qt5ct/qt6ct order: windowText button light midlight dark mid
# text brightText buttonText base window shadow highlight highlightedText link
# linkVisited alternateBase noRole toolTipBase toolTipText placeholderText accent
active="$FG, $SELECTION, $FG, $COMMENT, $BG, $COMMENT, $FG, $FG, $FG, $BG, $BG, #000000, $BLUE, $BG, $BLUE, $MAUVE, $SELECTION, $BG, $SELECTION, $FG, $COMMENT, $BLUE"
disabled="$COMMENT, $SELECTION, $FG, $COMMENT, $BG, $COMMENT, $COMMENT, $FG, $COMMENT, $BG, $BG, #000000, $SELECTION, $COMMENT, $BLUE, $MAUVE, $SELECTION, $BG, $SELECTION, $FG, $COMMENT, $BLUE"
qt_palette=$(cat <<EOF
[ColorScheme]
# theme: $NAME (written by the shell's apply-theme.sh)
active_colors=$active
disabled_colors=$disabled
inactive_colors=$active
EOF
)

# Set `key=value` in a qt5ct/qt6ct .conf's [Appearance] section.
# Returns 0 if the file was changed, 1 if it already had that value.
set_qt_key() {
    local conf=$1 key=$2 value=$3
    grep -qxF "$key=$value" "$conf" && return 1
    if grep -q "^$key=" "$conf"; then
        sed --follow-symlinks -i "s|^$key=.*|$key=$value|" "$conf"
    else
        sed --follow-symlinks -i "/^\[Appearance\]/a $key=$value" "$conf"
    fi
}

for ct in qt5ct qt6ct; do
    palette="$CFG/$ct/colors/x11-theme.conf"
    conf="$CFG/$ct/$ct.conf"
    # Not installed and never set up: leave it alone.
    command -v "$ct" >/dev/null || [[ -d $CFG/$ct ]] || continue
    mkdir -p "$CFG/$ct/colors"
    [[ -f $conf ]] || printf '[Appearance]\n' > "$conf"

    palette_changed=0 conf_changed=0
    write_if_changed "$palette" "$qt_palette" && palette_changed=1
    set_qt_key "$conf" color_scheme_path "$palette" && conf_changed=1
    set_qt_key "$conf" custom_palette true          && conf_changed=1
    # Fusion draws everything from the palette. Breeze (KDE's style) paints
    # with its own colour scheme on top, so a custom palette barely shows.
    set_qt_key "$conf" style Fusion                  && conf_changed=1

    # Running apps re-read settings ~3 s after qt5ct/qt6ct see their config
    # *dir* change; they don't watch colors/. So if only the palette changed,
    # re-save the .conf (sed -i writes a new file and renames it in).
    if (( palette_changed && ! conf_changed )); then
        sed --follow-symlinks -i -e '' "$conf"
    fi
done

exit 0
