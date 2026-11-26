#!/usr/bin/env bash
# Check one of your own bar widgets before calling it done:
#   1. widget.json: valid, known option row types, no reserved keys
#      (scripts/system/user-widgets.py check).
#   2. Widget.qml: loaded once in a sandbox shell (offscreen, its own HOME and
#      D-Bus session, the tests/bin stand-ins first on PATH, like
#      run-qs-tests.sh) with every option at its fallback. Fails if it doesn't
#      load or prints a QML warning or error from its own folder in the first
#      seconds.
# It doesn't lay the widget out on a real bar or click it: look at it live too.
#
# Usage: check-widget.sh <widget folder>     e.g. ~/.config/revenant/widgets/vpn
set -euo pipefail

shell_root() { local d; d=$(cd "$(dirname "$(readlink -f "$0")")" && pwd); while [[ ! -e $d/shell.qml && $d != / ]]; do d=$(dirname "$d"); done; printf '%s\n' "$d"; }
root="$(shell_root)"
folder="$(cd "${1:?usage: check-widget.sh <widget folder>}" && pwd)"
settle_s="${CHECK_SETTLE:-2}"

spec="$(python3 -B "$root/scripts/system/user-widgets.py" check "$folder")" || {
    jq -r '.errors[] | "check-widget: \(.id): \(.message)"' <<<"$spec" >&2
    exit 1
}
command -v qs >/dev/null 2>&1 || { echo "check-widget: widget.json ok; qs not found, Widget.qml not loaded" >&2; exit 0; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/cfg" "$work/home"
cp -a "$root"/{assets,components,lib,panels,scripts,services,widgets} "$work/cfg/"

# Every option at its fallback, as Settings → Bar → Widgets would add it.
instance="$(jq -c '.widgets[0] | {id: "check", type, style: "underline", color: "auto", iconSet: "auto", surface: "inherit"}
    + ([.options[] | select(.key != null and .fallback != null) | {(.key): .fallback}] | add // {})' <<<"$spec")"
qml_url="file://$folder/Widget.qml"

# Quickshell registers a qs.<dir> module only for folders the shell's own
# files import (it scans from shell.qml), so import them here as the real
# shell.qml does through its panels: a widget's `import qs.lib` resolves.
cat > "$work/cfg/shell.qml" <<EOF
import QtQuick
import Quickshell
import "services" as Services
import "lib" as Lib
import "components" as Components
import "components/bar" as BarUi
import "components/settings" as SettingsUi
import "panels" as Panels
ShellRoot {
    FloatingWindow {
        implicitWidth: 600; implicitHeight: 40; visible: true
        Row {
            anchors.fill: parent
            Loader {
                id: loader
                height: parent.height
                source: "$qml_url"
                onLoaded: { if ("instance" in item) item.instance = $instance; }
            }
        }
    }
    Timer {
        interval: $settle_s * 1000; running: true
        onTriggered: {
            if (loader.status !== Loader.Ready) console.log("RESULT: did not load (status " + loader.status + ")");
            else console.log("RESULT: loaded, width " + loader.item.implicitWidth);
        }
    }
}
EOF

dbus=()
command -v dbus-run-session >/dev/null 2>&1 && dbus=(dbus-run-session --)
box="$work/home"
HOME="$box" XDG_CONFIG_HOME="$box/.config" XDG_CACHE_HOME="$box/.cache" XDG_STATE_HOME="$box/.state" \
    PATH="$root/tests/bin:$PATH" I3SHELL_TEST=1 QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    setsid "${dbus[@]}" qs -p "$work/cfg" >"$work/raw.log" 2>&1 &
pid=$!
timeout $((settle_s + 20)) tail --pid="$pid" -n +1 -f "$work/raw.log" 2>/dev/null | grep -q -m1 'RESULT:' || true
kill -TERM -- "-$pid" 2>/dev/null || true
wait "$pid" 2>/dev/null || true
log="$(sed 's/\x1b\[[0-9;]*m//g' "$work/raw.log")"

problems="$(grep -F "$folder/" <<<"$log" | grep -viE 'DEBUG|INFO' || true)"
result="$(grep -o 'RESULT: .*' <<<"$log" | head -1 || true)"
if [[ $result == "RESULT: loaded"* && -z $problems ]]; then
    echo "check-widget: $(basename "$folder") ok (${result#RESULT: })"
    exit 0
fi
echo "check-widget: $(basename "$folder") FAILED${result:+: ${result#RESULT: }}" >&2
[[ -n $problems ]] && echo "$problems" >&2
[[ -z $result ]] && tail -15 <<<"$log" >&2
exit 1
