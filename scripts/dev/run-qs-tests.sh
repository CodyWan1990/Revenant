#!/usr/bin/env bash
# Run the QML regression tests in tests/ — all in parallel, each stopped as
# soon as it prints its `RESULT:` line.
#
#   run-qs-tests.sh              every tests/*.qml
#   run-qs-tests.sh navcursor …  just those (names without .qml)
#
# Staging: Quickshell will not import a module from outside its config folder,
# so each test is copied in as shell.qml beside copies of the shell's dirs.
# Isolation: HOME/XDG dirs point into the staging box (Settings writes a real
# dotfile), each run gets its own D-Bus session, so a test's notification
# server or tray never collides with the live shell, and tests/bin comes first
# on PATH: its xset and pactl only log to $HOME, so no test can change the real
# X server's key repeat or blanking, or the volume.
#
# Qt.quit() does not stop Quickshell, so a run is judged by what it printed:
# a test passes when it prints "RESULT: all … passed". TEST_TIMEOUT (seconds,
# default 60) bounds a test that hangs or never reports.
set -euo pipefail

# The shell's directory: the nearest one up from here holding shell.qml.
shell_root() { local d; d=$(cd "$(dirname "$(readlink -f "$0")")" && pwd); while [[ ! -e $d/shell.qml && $d != / ]]; do d=$(dirname "$d"); done; printf '%s\n' "$d"; }
root="$(shell_root)"
timeout_s="${TEST_TIMEOUT:-60}"

command -v qs >/dev/null 2>&1 || {
    echo "tests: quickshell (qs) not found, skipping QML tests" >&2
    exit 0
}
dbus=()
command -v dbus-run-session >/dev/null 2>&1 && dbus=(dbus-run-session --)

if [[ $# -gt 0 ]]; then
    names=("$@")
else
    names=()
    for t in "$root"/tests/*.qml; do names+=("$(basename "$t" .qml)"); done
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Run one test to completion; leaves its cleaned log in $work/<name>.log.
run_one() {
    local name="$1" box="$work/$1"
    mkdir -p "$box/cfg" "$box/home"
    cp -a "$root"/{assets,components,lib,panels,scripts,services,widgets} "$box/cfg/"
    cp "$root/tests/$name.qml" "$box/cfg/shell.qml"

    # setsid: qs and its D-Bus daemon share one new process group, so a single
    # kill below takes down the whole run.
    HOME="$box/home" XDG_CONFIG_HOME="$box/home/.config" \
        XDG_CACHE_HOME="$box/home/.cache" XDG_STATE_HOME="$box/home/.state" \
        PATH="$root/tests/bin:$PATH" I3SHELL_TEST=1 \
        QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
        setsid "${dbus[@]}" qs -p "$box/cfg" >"$box/raw.log" 2>&1 &
    local pid=$!

    # Block until the RESULT line, the process exiting, or the timeout —
    # tail --pid ends with the process, so a crash doesn't wait out the clock.
    timeout "$timeout_s" tail --pid="$pid" -n +1 -f "$box/raw.log" 2>/dev/null \
        | grep -q -m1 'RESULT:' || true
    kill -TERM -- "-$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    sed 's/\x1b\[[0-9;]*m//g' "$box/raw.log" >"$work/$name.log"
}

start=$SECONDS
for name in "${names[@]}"; do
    [[ -f "$root/tests/$name.qml" ]] || { echo "tests: no tests/$name.qml" >&2; exit 2; }
    run_one "$name" &
done
wait

failed=0
for name in "${names[@]}"; do
    log="$work/$name.log"
    if grep -q 'RESULT: all .* passed' "$log"; then
        echo "tests: $name — $(grep -c '  ok:' "$log") assertions passed"
    else
        failed=$((failed + 1))
        echo "tests: $name FAILED" >&2
        grep -E 'FAIL|RESULT|ERROR|caused by' "$log" >&2 \
            || { echo "  (no RESULT line within ${timeout_s}s; last output:)" >&2; tail -15 "$log" >&2; }
    fi
done
echo "tests: ${#names[@]} run in $((SECONDS - start))s"
[[ $failed -eq 0 ]]
