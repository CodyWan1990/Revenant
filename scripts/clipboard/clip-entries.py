#!/usr/bin/env python3
"""clipmenu's history as JSON for the clipboard panel's Text section:
[{"line": "[N] label", "display": "label", "text": "the whole clip",
  "binary": bool}, ...], newest first. "binary" is a clip that isn't valid
UTF-8 (or has NUL bytes): an image clipmenud stored as text, because xclip
answers its text request with the image bytes.

The order and labels come from clip-list.sh (clipmenu's own menu, so they
always agree with clip-select.sh / clip-delete.sh). clipmenu's menu shows only
"first line (N lines)" for a multi-line clip, so the full text is read from its
store, $CM_DIR (default $XDG_RUNTIME_DIR)/clipmenu.7.<uid>/<hash>/<n>, and
matched to a label by first line and line count. If that fails (a store layout
this doesn't know), "text" is the label, as before.
"""
import json
import os
import re
import subprocess
import sys

MAX_TEXT = 20000   # enough for a preview; a huge clip shouldn't stall the panel

here = os.path.dirname(os.path.abspath(__file__))
# Bytes, decoded by hand: text=True would turn on universal newlines and break
# a binary clip's label at its \r (the PNG signature has one) into two entries.
menu = subprocess.run(["sh", os.path.join(here, "clip-list.sh")],
                      capture_output=True).stdout.decode("utf-8", errors="replace")

base = os.environ.get("CM_DIR") or os.environ.get("XDG_RUNTIME_DIR") or "/tmp"
store = os.path.join(base, "clipmenu.7.%d" % os.getuid())


def label_of(text):
    """clipmenu's menu label for a clip: its first line, plus the line count."""
    lines = text.split("\n")
    if lines and lines[-1] == "":
        lines.pop()   # a trailing newline doesn't make another line
    first = lines[0] if lines else ""
    return first + (" (%d lines)" % len(lines) if len(lines) > 1 else "")


# label -> [(mtime, text)], newest first
by_label = {}
by_first = {}
try:
    for name in os.listdir(store):
        folder = os.path.join(store, name)
        if not os.path.isdir(folder):
            continue
        copies = sorted(os.listdir(folder))
        if not copies:
            continue
        path = os.path.join(folder, copies[0])
        try:
            with open(path, "rb") as f:
                raw = f.read(MAX_TEXT * 4)
            try:
                raw.decode("utf-8")
                binary = b"\0" in raw
            except UnicodeDecodeError as e:
                # Only a cut at the read limit is allowed to end mid-character.
                binary = not (len(raw) == MAX_TEXT * 4 and e.start >= len(raw) - 3)
            text = raw.decode("utf-8", errors="replace")[:MAX_TEXT]
            mtime = max(os.path.getmtime(os.path.join(folder, c)) for c in copies)
        except OSError:
            continue
        by_label.setdefault(label_of(text), []).append((mtime, text, binary))
        by_first.setdefault(text.split("\n", 1)[0], []).append((mtime, text, binary))
except OSError:
    pass
for table in (by_label, by_first):
    for found in table.values():
        found.sort(reverse=True)

out = []
# split("\n"), not splitlines(), which also splits on \r and other separators.
for line in menu.split("\n"):
    if not line:
        continue
    display = re.sub(r"^\[\s*\d+\] ", "", line)   # clipmenu pads: "[ 9] "
    found = by_label.get(display)
    if not found:
        m = re.match(r"^(.*) \(\d+ lines\)$", display)
        found = by_first.get(m.group(1) if m else display)
    out.append({"line": line, "display": display,
                "text": found[0][1] if found else display,
                # Unmatched: fall back to the old guess, a U+FFFD in the label.
                "binary": found[0][2] if found else "\ufffd" in display})

json.dump(out, sys.stdout)
