#!/usr/bin/env bash
# Pending system package updates as JSON: [{"name","current","new"}, ...]
# Used by services/Updates.qml. Never needs root: it only reads the package
# lists already on disk (apt's daily timer / pacman-contrib / dnf refresh them).
#
#   sys-updates.sh check     print the JSON list (default)
#   sys-updates.sh manager   print the detected manager: apt | pacman | dnf | none
#   sys-updates.sh upgrade   interactive upgrade, run inside a terminal (the
#                            package manager asks for your password itself)
#   sys-updates.sh snap      pending snap refreshes, same JSON shape
#   sys-updates.sh flatpak   pending Flatpak updates: [{"name","id"}, ...]
#   sys-updates.sh snap-upgrade     refresh snaps in a terminal
#   sys-updates.sh flatpak-upgrade  update Flatpaks in a terminal
#
# Every upgrade ends by asking the shell to check again over IPC, so the
# badge is right even when the terminal forks and its process exits at once.
#
# The apt parsing follows Dux Shell's sysupdate backend (MIT): parse
# `apt list --upgradable` and drop held packages, which `apt upgrade` skips.
set -uo pipefail

manager() {
    if command -v apt-get >/dev/null 2>&1 && command -v apt >/dev/null 2>&1; then echo apt
    elif command -v checkupdates >/dev/null 2>&1; then echo pacman
    elif command -v dnf >/dev/null 2>&1; then echo dnf
    else echo none; fi
}

# name<TAB>current<TAB>new lines on stdin -> JSON array
to_json() {
    jq -Rsc '[split("\n")[] | select(length > 0) | split("\t")
              | {name: .[0], current: (.[1] // ""), new: (.[2] // "")}]'
}

check() {
    case "$(manager)" in
    apt)
        # "name/suite new arch [upgradable from: current]"
        local held
        held=$(apt-mark showhold 2>/dev/null | tr '\n' ' ')
        apt list --upgradable 2>/dev/null | awk -v held=" $held " '
            /\[upgradable from: / {
                split($1, n, "/"); name = n[1]
                if (index(held, " " name " ")) next
                cur = $0; sub(/.*\[upgradable from: /, "", cur); sub(/\].*/, "", cur)
                printf "%s\t%s\t%s\n", name, cur, $2
            }' | to_json ;;
    pacman)
        # "name current -> new"
        checkupdates 2>/dev/null | awk '{printf "%s\t%s\t%s\n", $1, $2, $4}' | to_json ;;
    dnf)
        # exits 100 when updates exist; lines are "name.arch new repo"
        dnf check-update -q 2>/dev/null | awk 'NF == 3 && $1 ~ /\./ {
            name = $1; sub(/\.[^.]*$/, "", name); printf "%s\t\t%s\n", name, $2 }' | to_json ;;
    *) echo '[]' ;;
    esac
}

# Snap: `snap refresh --list` needs no root. Its rows are
# "name new-version rev size publisher notes"; the installed version comes
# from `snap list`. Prints [] when snapd isn't there or all are current.
snap_check() {
    command -v snap >/dev/null 2>&1 || { echo '[]'; return; }
    local pending
    pending=$(snap refresh --list 2>/dev/null | awk 'NR > 1 && NF >= 2 {print $1 "\t" $2}')
    [[ -n $pending ]] || { echo '[]'; return; }
    awk -F'\t' 'NR == FNR { cur[$1] = $2; next } { printf "%s\t%s\t%s\n", $1, cur[$1], $2 }' \
        <(snap list 2>/dev/null | awk 'NR > 1 {print $1 "\t" $2}') <(printf '%s\n' "$pending") | to_json
}

flatpak_check() {
    command -v flatpak >/dev/null 2>&1 || { echo '[]'; return; }
    flatpak remote-ls --updates --columns=name,application 2>/dev/null \
        | jq -Rsc '[split("\n")[] | select(length > 0) | split("\t") | {name: .[0], id: (.[1] // "")}]'
}

# The config name this copy runs as (e.g. revenant): the directory
# above scripts/, after resolving any symlink to it.
# The shell's directory: the nearest one up from here holding shell.qml.
shell_root() { local d; d=$(cd "$(dirname "$(readlink -f "$0")")" && pwd); while [[ ! -e $d/shell.qml && $d != / ]]; do d=$(dirname "$d"); done; printf '%s\n' "$d"; }
shell_name() { basename "$(shell_root)"; }

run_upgrade() {
    local status=0
    "$@" || status=$?
    echo
    if (( status == 0 )); then
        echo "Update command completed."
    else
        printf 'Update failed (exit status %d). See the output above.\n' "$status" >&2
    fi
    qs -c "$(shell_name)" ipc call shell updatesRefresh >/dev/null 2>&1 || true
    read -rp "Press Enter to close..." _
    return "$status"
}

upgrade() {
    case "$(manager)" in
        apt) run_upgrade bash -c 'sudo apt update && sudo apt upgrade' ;;
        pacman) run_upgrade sudo pacman -Syu ;;
        dnf) run_upgrade sudo dnf upgrade ;;
        *) echo "No supported package manager found." >&2; return 1 ;;
    esac
}

case "${1:-check}" in
    check) check ;;
    manager) manager ;;
    upgrade) upgrade ;;
    snap) snap_check ;;
    flatpak) flatpak_check ;;
    snap-upgrade) run_upgrade sudo snap refresh ;;
    flatpak-upgrade) run_upgrade flatpak update ;;
    *) echo "usage: ${0##*/} [check|manager|upgrade|snap|flatpak|snap-upgrade|flatpak-upgrade]" >&2; exit 2 ;;
esac
