#!/usr/bin/env bash
# Delete one clipmenu history entry.
# Usage: clip-delete.sh "<line from clip-list.sh>"
#
# clipdel matches on content, not on an index, and its regex works line by line
# (^ and $ match at every newline). clipmenu lists a multi-line clip as
# "first line (N lines)", so that suffix is dropped and the clip is matched by
# its whole first line: ^first line$.
# Since ^…$ can also match a line further down another clip, the matches are
# checked first: clipdel lists each one by its first line, and if any of them
# starts differently, nothing is deleted. Identical clips go together, which
# is fine: they are the same text.
set -uo pipefail
line="${1:?usage: clip-delete.sh <line>}"
text="${line#\[*\] }"                                   # drop the "[N] " prefix

escape() { printf '%s' "$1" | sed 's/[][\.*^$+?(){}|/\\]/\\&/g'; }

# The line as shown first (a one-line clip could itself end in "(2 lines)"),
# then without the multi-line suffix.
candidates=("$text")
[[ $text =~ ^(.*)\ \([0-9]+\ lines\)$ ]] && candidates+=("${BASH_REMATCH[1]}")

for first in "${candidates[@]}"; do
    pattern="^$(escape "$first")\$"
    mapfile -t hits < <(clipdel "$pattern")
    (( ${#hits[@]} )) || continue
    for hit in "${hits[@]}"; do
        if [[ $hit != "$first" ]]; then
            notify-send -a Clipboard Clipboard \
                "Not deleted: another clip contains the same line, and clipmenu can only delete by content."
            exit 1
        fi
    done
    clipdel -d "$pattern" >/dev/null
    exit 0
done
exit 1
