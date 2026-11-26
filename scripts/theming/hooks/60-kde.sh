#!/usr/bin/env bash
# theme-hook: KDE apps
# Dolphin, Kate, Okular…: a generated KDE colour scheme, applied with plasma-apply-colorscheme. Skipped if that tool isn't installed.
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../hook-lib.sh"
# ── KDE apps (Dolphin, Kate, Okular, ...) ─────────────────────────────────────
# KDE Frameworks apps ignore the qt5ct/qt6ct palette: at startup they apply the
# KDE colour scheme from kdeglobals instead. So generate a .colors scheme and
# apply it with plasma-apply-colorscheme, which also tells running KDE apps to
# recolour (D-Bus). That tool refuses to re-apply the active scheme's name, so
# the scheme alternates between two slots, X11ThemeA and X11ThemeB.
if command -v plasma-apply-colorscheme >/dev/null 2>&1; then
    rgb() { local h=${1#\#}; printf '%d,%d,%d' "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"; }
    BG_=$(rgb "$BG"); FG_=$(rgb "$FG"); CM_=$(rgb "$COMMENT"); SL_=$(rgb "$SELECTION")
    RD_=$(rgb "$RED"); GN_=$(rgb "$GREEN"); YL_=$(rgb "$YELLOW"); BL_=$(rgb "$BLUE"); MV_=$(rgb "$MAUVE")

    # One [Colors:*] group: background normal/alternate, then shared foregrounds
    kde_group() {   # name bg_normal bg_alt [fg_normal]
        cat <<G
[Colors:$1]
BackgroundAlternate=$3
BackgroundNormal=$2
DecorationFocus=$BL_
DecorationHover=$BL_
ForegroundActive=$BL_
ForegroundInactive=$CM_
ForegroundLink=$BL_
ForegroundNegative=$RD_
ForegroundNeutral=$YL_
ForegroundNormal=${4:-$FG_}
ForegroundPositive=$GN_
ForegroundVisited=$MV_

G
    }

    kde_scheme() {   # slot name
        cat <<K
[General]
ColorScheme=$1
Name=$1 ($NAME)

[KDE]
contrast=4

[ColorEffects:Disabled]
Color=$BG_
ColorAmount=0
ColorEffect=0
ContrastAmount=0.65
ContrastEffect=1
IntensityAmount=0.1
IntensityEffect=2

[ColorEffects:Inactive]
ChangeSelectionColor=true
Color=$BG_
ColorAmount=0.025
ColorEffect=2
ContrastAmount=0.1
ContrastEffect=2
Enable=false
IntensityAmount=0
IntensityEffect=0

$(kde_group Window "$BG_" "$SL_")
$(kde_group View "$BG_" "$SL_")
$(kde_group Button "$SL_" "$BG_")
$(kde_group Header "$BG_" "$SL_")
$(kde_group "Header][Inactive" "$BG_" "$SL_")
$(kde_group Tooltip "$SL_" "$BG_")
$(kde_group Complementary "$BG_" "$SL_")
$(kde_group Selection "$BL_" "$SL_" "$BG_")
[WM]
activeBackground=$BG_
activeBlend=$FG_
activeForeground=$FG_
inactiveBackground=$BG_
inactiveBlend=$CM_
inactiveForeground=$CM_
K
    }

    CS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/color-schemes"
    active=$(sed -n 's/^ColorScheme=//p' "$CFG/kdeglobals" 2>/dev/null | head -1)
    case "$active" in
        X11ThemeA) cur=X11ThemeA next=X11ThemeB ;;
        X11ThemeB) cur=X11ThemeB next=X11ThemeA ;;
        *)         cur=""        next=X11ThemeA ;;
    esac
    # Already showing exactly these colours: nothing to do
    if [[ -z $cur || $(cat "$CS_DIR/$cur.colors" 2>/dev/null) != "$(kde_scheme "$cur")" ]]; then
        mkdir -p "$CS_DIR"
        kde_scheme "$next" > "$CS_DIR/$next.colors"
        plasma-apply-colorscheme "$next" >/dev/null 2>&1 || true
    fi
fi
exit 0
