#!/usr/bin/env bash
# Copy the shell's AGENTS.md (the guide for coding agents) into the user's
# config dir, where agents asked to change the shell start looking, the way
# Herdr writes its own into ~/.config/herdr-app. Rewritten only when it would
# change; the person's own notes go in AGENTS.local.md, never touched here.
# Also creates <config dir>/CLAUDE.md once (Claude Code reads CLAUDE.md, not
# AGENTS.md), importing both; after that it's the person's file.
# Usage: agents-doc.sh <shell AGENTS.md> <config dir>
set -euo pipefail
src=${1:?usage: agents-doc.sh <AGENTS.md> <config dir>} dir=${2:?usage: agents-doc.sh <AGENTS.md> <config dir>}
[[ -f $src ]] || exit 0
text="<!-- Written by the shell on every start, from $src. Edits here are overwritten: put your own notes in AGENTS.local.md, next to this file. -->

$(<"$src")"
dest=$dir/AGENTS.md
mkdir -p "$dir"
if [[ ! -e $dir/CLAUDE.md && ! -L $dir/CLAUDE.md ]]; then
    printf '%s\n' "<!-- Created once by the shell, so Claude Code reads the shell's guide and your notes. Yours to edit. -->" \
        "@AGENTS.md" "@AGENTS.local.md" > "$dir/CLAUDE.md"
fi
[[ -f $dest && $(<"$dest") == "$text" ]] && exit 0
tmp=$(mktemp "$dir/.AGENTS.md.XXXXXX")
printf '%s\n' "$text" > "$tmp" && mv -f "$tmp" "$dest"
