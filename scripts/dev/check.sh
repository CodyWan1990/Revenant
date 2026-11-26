#!/usr/bin/env bash
# The gate for Revenant — run before committing. Takes a few seconds.
#
# 1. qmllint over every shell .qml in one run. It catches syntax errors, bad
#    imports and broken bindings, not behaviour (smoke-test live with
#    `qs -c revenant`). The `unqualified` category is off because this
#    shell deliberately uses outer ids (root.bar.x). Any warning fails too:
#    the shell is warning-free, so a new one is news. Where qmllint is wrong
#    because Quickshell does not expose a type to it (QProcess::ExitStatus in
#    onExited, PopupAnchor, BluetoothAdapter, PanelWindow), end that one line
#    with `// qmllint disable <category>`; for a duck-typed object (a Loader's
#    item, an ancestor), hold it in a `var` instead. tests/ is skipped: those
#    files import the staged layout run-qs-tests.sh builds.
# 2. check-architecture.sh: ownership and registration rules.
# 3. bash -n on the shell scripts, a compile check on the Python helpers.
# 4. run-qs-tests.sh: the QML regression tests in tests/, in parallel.
# 5. check-widget.sh on each example in examples/widgets/.
set -euo pipefail

# The shell's directory: the nearest one up from here holding shell.qml.
shell_root() { local d; d=$(cd "$(dirname "$(readlink -f "$0")")" && pwd); while [[ ! -e $d/shell.qml && $d != / ]]; do d=$(dirname "$d"); done; printf '%s\n' "$d"; }
root="$(shell_root)"
start=$SECONDS

# Fedora ships it as qmllint-qt6 under lib64; Arch as qmllint under lib.
qmllint=""
for c in qmllint qmllint-qt6 /usr/lib64/qt6/bin/qmllint /usr/lib/qt6/bin/qmllint; do
    p="$(command -v "$c" 2>/dev/null || true)"
    [[ -n "$p" && -x "$p" ]] && { qmllint="$p"; break; }
done
[[ -n "$qmllint" ]] || { echo "qmllint not found (install qt6-declarative / qt6-qtdeclarative-devel)" >&2; exit 2; }

# Where Quickshell's own QML modules live, so `import Quickshell` resolves.
qmldir="$(qmake6 -query QT_INSTALL_QML 2>/dev/null || true)"
[[ -d "${qmldir:-}" ]] || for d in /usr/lib64/qt6/qml /usr/lib/qt6/qml; do
    [[ -d "$d" ]] && { qmldir="$d"; break; }
done

# examples/ is skipped too: user widgets import the shell as qs.*, which only
# Quickshell resolves; step 5 loads them with check-widget.sh instead.
mapfile -t qml < <(find "$root" -name '*.qml' -not -path "$root/tests/*" -not -path "$root/examples/*" | sort)
lint="$("$qmllint" -I "$qmldir" --unqualified disable "${qml[@]}" 2>&1)" || {
    echo "$lint" >&2
    echo "check: qmllint found errors" >&2
    exit 1
}
if grep -qE '^Warning|Unused import' <<<"$lint"; then
    grep -A2 -E '^Warning|Unused import' <<<"$lint" >&2
    echo "check: qmllint warnings (see above)" >&2
    exit 1
fi
echo "qmllint: ${#qml[@]} files, no warnings"

bash "$root/scripts/dev/check-architecture.sh"

# bash -n, not sh -n: they use [[ ]].
for s in "$root"/install.sh "$root"/scripts/*/*.sh "$root"/scripts/*/*/*.sh; do
    [[ -e $s ]] || continue
    bash -n "$s" || exit 1
done
# compile(), not py_compile: that would leave __pycache__ in the shell folder.
python3 -B - "$root"/scripts/*/*.py <<'EOF'
import sys
for path in sys.argv[1:]:
    compile(open(path, encoding="utf-8").read(), path, "exec")
EOF

bash "$root/scripts/dev/run-qs-tests.sh"

# 5. The example user widgets load (and so the qs.* imports they document work).
for w in "$root"/examples/widgets/*/; do
    bash "$root/scripts/dev/check-widget.sh" "$w"
done

echo "check: passed in $((SECONDS - start))s"
