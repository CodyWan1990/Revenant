#!/usr/bin/env bash
# Make a standalone git repository of this shell, as one fresh first commit.
#
# For when the shell lives inside a bigger repository (a dotfiles repo, say)
# and should be published on its own. It takes what is *committed* there
# (git archive), never uncommitted edits, so nothing half-done leaks out; the
# old history stays behind (it may hold files that were never meant to be
# public). Before committing it:
#   - fills the README's @REPO_URL@ with --url
#   - stops if your home path, user name, git e-mail or host name appear in
#     any file (case-sensitive; your name in LICENSE is expected and fine)
#   - runs scripts/dev/check.sh in the copy (skip with --no-check)
# It sets `origin` to --url but never pushes.
#
# Usage: export-repo.sh --url URL [--branch main] [--no-check] TARGET_DIR
#   TARGET_DIR must not exist yet, or be empty.
set -euo pipefail

usage() { sed -n '2,/^set -euo/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit "${1:-2}"; }
url="" branch="main" check=1 target=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --url) url="${2:-}"; shift 2 ;;
        --branch) branch="${2:-}"; shift 2 ;;
        --no-check) check=0; shift ;;
        -h|--help) usage 0 ;;
        -*) echo "export-repo: unknown option $1" >&2; usage ;;
        *) [[ -z $target ]] || usage; target="$1"; shift ;;
    esac
done
[[ -n $url && -n $target ]] || usage
[[ $url != *@REPO_URL@* ]] || { echo "export-repo: --url is still the placeholder" >&2; exit 2; }

shell_root() { local d; d=$(cd "$(dirname "$(readlink -f "$0")")" && pwd); while [[ ! -e $d/shell.qml && $d != / ]]; do d=$(dirname "$d"); done; printf '%s\n' "$d"; }
root="$(shell_root)"
repo="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null)" \
    || { echo "export-repo: $root is not inside a git repository" >&2; exit 1; }
prefix="$(realpath --relative-to="$repo" "$root")"

if [[ -e $target ]] && [[ -n $(ls -A "$target" 2>/dev/null) ]]; then
    echo "export-repo: $target exists and is not empty" >&2; exit 1
fi
if [[ -n $(git -C "$repo" status --porcelain -- "$prefix") ]]; then
    echo "export-repo: note: uncommitted changes in $prefix are left out (only HEAD is exported):" >&2
    git -C "$repo" status --short -- "$prefix" | sed 's/^/  /' >&2
fi

mkdir -p "$target"
target="$(cd "$target" && pwd)"
git -C "$repo" archive --format=tar "HEAD:$prefix" | tar -x -C "$target"
source_rev="$(git -C "$repo" rev-parse --short HEAD)"

# The README's clone URL.
{ grep -rl --null '@REPO_URL@' "$target" || true; } | xargs -0 -r sed -i "s|@REPO_URL@|$url|g"

# Personal details that must not ship. Case-sensitive and whole-word for the
# user name, so "CodyWan" in LICENSE (a deliberate credit) doesn't trip it.
leaks=0
check_leak() {   # check_leak <what> <grep args...>
    local what="$1"; shift
    local hits
    hits="$(grep -rnI "$@" "$target" --exclude-dir=.git 2>/dev/null | head -5 || true)"
    if [[ -n $hits ]]; then
        echo "export-repo: found your $what:" >&2
        sed "s|$target/|  |" <<<"$hits" >&2
        leaks=1
    fi
}
check_leak "home path ($HOME)" -F "$HOME"
check_leak "user name ($USER)" -w -F "$USER"
email="$(git -C "$repo" config user.email || true)"
[[ -n $email ]] && check_leak "git e-mail" -F "$email"
host="$(hostname 2>/dev/null || true)"
[[ -n $host ]] && check_leak "host name ($host)" -w -F "$host"
if (( leaks )); then
    echo "export-repo: stopped; nothing was committed. Fix those in $prefix, commit, run again." >&2
    exit 1
fi

if (( check )); then
    echo "export-repo: running the checks in the copy…"
    if ! (cd "$target" && bash scripts/dev/check.sh); then
        echo "export-repo: the checks failed in the copy; nothing was committed" >&2
        exit 1
    fi
    find "$target" -name __pycache__ -type d -prune -exec rm -rf {} +
fi

git -C "$target" init -q -b "$branch"
git -C "$target" add -A
git -C "$target" commit -q -m "Revenant

Imported from $(basename "$repo") at $source_rev ($prefix)."
git -C "$target" remote add origin "$url"

echo "export-repo: $(git -C "$target" ls-files | wc -l) files committed in $target ($branch)"
echo "export-repo: origin is $url; nothing was pushed. When it looks right:"
echo "    git -C \"$target\" push -u origin $branch"
