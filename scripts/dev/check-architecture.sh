#!/usr/bin/env bash
# Stable ownership checks for QML patterns that have intentionally been shared.
set -euo pipefail

# The shell's directory: the nearest one up from here holding shell.qml.
shell_root() { local d; d=$(cd "$(dirname "$(readlink -f "$0")")" && pwd); while [[ ! -e $d/shell.qml && $d != / ]]; do d=$(dirname "$d"); done; printf '%s\n' "$d"; }
root="$(shell_root)"
fail=0

problem() {
    echo "architecture: $*" >&2
    fail=$((fail + 1))
}

mapfile -t mpris_owners < <(rg -l '^import Quickshell\.Services\.Mpris' "$root" --glob '*.qml' | sort)
[[ ${#mpris_owners[@]} -eq 1 && ${mpris_owners[0]} == "$root/services/Media.qml" ]] \
    || problem "services/Media.qml must be the only direct MPRIS importer"

mapfile -t safe_markup_owners < <(rg -l 'Fmt\.(safeMarkup|openableUrl)' "$root" --glob '*.qml' | sort)
[[ ${#safe_markup_owners[@]} -eq 1 && ${safe_markup_owners[0]} == "$root/components/NotificationContent.qml" ]] \
    || problem "components/NotificationContent.qml must own notification markup and URL handling"

[[ $(rg -c 'BarUi\.BarSection[[:space:]]*\{' "$root/panels/TopBar.qml") -eq 3 ]] \
    || problem "TopBar must contain exactly three shared BarSection instances"
rg -q 'delegate:[[:space:]]*Loader' "$root/panels/TopBar.qml" \
    && problem "TopBar contains an inline widget Loader instead of BarSection"

# Settings window pages must be SettingsPages: that is what gives them the
# keyboard row cursor SettingsWindow drives. (BarWidgetsPage uses KeyNavCursor itself.)
for page in "$root"/panels/settings/pages/*.qml; do
    [[ $(basename "$page") == BarWidgetsPage.qml ]] && continue   # drives KeyNavCursor itself
    rg -q '^SettingsUi\.SettingsPage[[:space:]]*\{' "$page" \
        || problem "${page#"$root/"} must use SettingsPage"
done

# services/I3.qml is the only window-manager seam (the i3 config editors are
# Python scripts, not QML services), so no paw/niri service may survive.
rg -q 'Services\.(Paw|PawConfig|Outputs|Xkb|Niri)\b' "$root" --glob '*.qml' \
    && problem "a paw/niri compositor service reference survived the port"
rg -q 'Quickshell\.Wayland|WlrLayershell' "$root" --glob '*.qml' \
    && problem "Wayland-only API in an X11 shell"
# …and the Wayland CLI tools nirishell used; the X11 equivalents are xclip /
# clipmenu, maim / slop, xdotool and scripts/theming/wallpaper.sh.
rg -q '\b(wl-copy|wl-paste|cliphist|grim|slurp|swaybg|swww|wtype|ydotool|niri)\b' "$root" \
    --glob '*.qml' --glob '*.sh' --glob '!check-architecture.sh' \
    && problem "a Wayland-only tool is called (use the X11 equivalent)"

# services/WidgetCatalog.qml is the one widget registration: every entry's
# file must exist, and every widgets/*.qml must be some entry's file.
mapfile -t catalog_files < <(rg -o '\bfile: "[^"]+"' -r '$0' "$root/services/WidgetCatalog.qml" \
    | sed 's/file: "\(.*\)"/\1/' | sort -u)
for file in "${catalog_files[@]}"; do
    [[ -f "$root/widgets/$file" ]] || problem "WidgetCatalog names widgets/$file, which does not exist"
done
for widget in "$root"/widgets/*.qml; do
    printf '%s\n' "${catalog_files[@]}" | grep -qxF "$(basename "$widget")" \
        || problem "widgets/$(basename "$widget") has no WidgetCatalog entry"
done
# A widget's file is named after its catalog type (type "diskUsage" ->
# DiskUsage.qml); `optionsFrom` aliases (spacer) share their source's file.
while IFS=$'\t' read -r type file; do
    want="$(tr '[:lower:]' '[:upper:]' <<< "${type:0:1}")${type:1}.qml"
    [[ $file == "$want" ]] || problem "widget type $type should live in widgets/$want, not $file"
done < <(rg -o 'type: "[A-Za-z]+", name: "[^"]*", icon: "[^"]*", file: "[^"]+"(, hidden: true, optionsFrom)?' \
    "$root/services/WidgetCatalog.qml" | grep -v 'optionsFrom' \
    | sed -E 's/type: "([^"]+)".*file: "([^"]+)".*/\1\t\2/')
# Text sizes come from Services.Ui (textBody, textTitle, …, or Ui.px(n)),
# so Settings → Fonts → Panel text size scales them; bar text follows
# Settings.fontSize. A literal pixel size skips both.
rg -n 'pixelSize:[[:space:]]*[0-9]' "$root" --glob '*.qml' --glob '!tests/**' \
    && problem "a literal font pixelSize (use Services.Ui.text* or Ui.px())"
rg -q 'widgetRegistry|inlineWidgets|widgetSpecs|availableWidgets|widgetInfo' "$root" --glob '*.qml' \
    && problem "a widget list outside services/WidgetCatalog.qml"

rg -q '^[[:space:]]*component[[:space:]]+[A-Za-z]' "$root/panels" "$root/widgets" --glob '*.qml' \
    && problem "panels/widgets contain a named inline component that belongs in components/"

rg -q 'id:[[:space:]]*(boolComp|sliderComp|paletteComp|presetComp|textComp|noteComp)' \
    "$root/panels/settings/pages/BarWidgetsPage.qml" \
    && problem "settings tabs contain obsolete inline option editors"

rg -q 'launcher\.gridStep|function[[:space:]]+gridStep' "$root/panels/AppLauncher.qml" "$root/panels/launcher" --glob '*.qml' \
    && problem "launcher views must consume Ui.gridStep directly"

# Every component (components/, its area folders, lib/) has a user: Name { or
# Alias.Name { / property Alias.Name, or a Loader by path (`source:
# ".../Name.qml"`: SystemTray loads TintedIcon that way so a missing
# QtQuick.Effects module degrades to a plain icon).
while IFS= read -r component; do
    name="$(basename "$component" .qml)"
    if ! rg -q "(\\b\\w+\\.)?${name}[[:space:]]*\\{|property[[:space:]]+(\\w+\\.)?${name}\\b|/${name}\\.qml\"" "$root" \
            --glob '*.qml' --glob "!${component#"$root/"}"; then
        problem "${component#"$root/"} has no QML consumer"
    fi
done < <(find "$root/components" "$root/lib" -name '*.qml' | sort)

# The bundled Material Symbols font is subset to lib/MaterialCodepoints.js,
# so a Settings sidebar icon name missing there renders as nothing.
while IFS= read -r icon; do
    grep -qE "^[[:space:]]+${icon}:" "$root/lib/MaterialCodepoints.js" \
        || problem "services/SettingsTabs.qml: material icon \"$icon\" is not in lib/MaterialCodepoints.js (the font is subset to it)"
done < <(grep -oE 'material: "[a-z_0-9]+"' "$root/services/SettingsTabs.qml" | cut -d'"' -f2 | sort -u)

# Qt's JavaScript engine (V4) lacks some newer built-ins; calling one throws
# a TypeError at run time that qmllint doesn't see (the user-widget watchers
# and the theme dropdowns each broke this way). Comments are fine.
while IFS= read -r hit; do
    problem "${hit%%|*}: Qt's JS engine has no ${hit##*|} (use a loop or reduce)"
done < <(rg -n --no-heading -o '^[^/]*?(Object\.fromEntries|\.flatMap)\(' \
    "$root" --glob '*.qml' --glob '*.js' --glob '!examples/**' --replace '$1' 2>/dev/null | sed -E "s|^$root/([^:]+):([0-9]+):|\\1:\\2\||")

if [[ $fail -gt 0 ]]; then
    echo "architecture: $fail ownership check(s) failed" >&2
    exit 1
fi
echo "architecture: shared-component ownership checks passed"
