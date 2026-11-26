#!/usr/bin/env python3
"""Your own bar widgets: list what is in <config>/widgets/ (~/.config/revenant/widgets/).

    <config>/widgets/<id>/
      widget.json   {"name": "…", "icon": "<Icons.qml key>", "about": "…", "options": [rows]}
      Widget.qml    the widget (import qs.services / qs.components.bar like the shell's own)

The type is "user:<id>". Option rows use services/WidgetCatalog.qml's schema.

Usage:
    user-widgets.py list           -> {"widgets": [...], "errors": [...], "dir": "..."}
    user-widgets.py check <folder> -> the same for one folder (any path), exit 1 on errors
"""

import json
import os
from pathlib import Path
import re
import sys

ROW_TYPES = {"bool", "text", "note", "csv", "int", "float", "preset", "choice", "enum", "palette", "multi"}
# Instance keys every widget already has (Settings.normalizeWidget); options can't reuse them.
RESERVED = {"id", "type", "style", "color", "iconSet", "surface"}
ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]*$")


def shell_root():
    here = Path(__file__).resolve().parent
    for d in [here, *here.parents]:
        if (d / "shell.qml").exists():
            return d
    return here


CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / shell_root().name
WIDGETS = CONFIG / "widgets"


def check_options(options):
    if not isinstance(options, list):
        return "options must be a list"
    seen = set()
    for i, row in enumerate(options):
        where = f"options[{i}]"
        if not isinstance(row, dict):
            return f"{where} must be an object"
        if "section" in row:
            continue
        kind = row.get("type")
        if kind not in ROW_TYPES:
            return f"{where}: type {kind!r} is not one of {', '.join(sorted(ROW_TYPES))}"
        if kind == "note":
            continue
        key = row.get("key")
        if not isinstance(key, str) or not key:
            return f"{where}: needs a \"key\""
        if key in RESERVED:
            return f"{where}: key {key!r} is reserved ({', '.join(sorted(RESERVED))})"
        if key in seen:
            return f"{where}: key {key!r} is used twice"
        seen.add(key)
        if not isinstance(row.get("label", ""), str):
            return f"{where}: label must be text"
        if kind in ("preset", "choice", "enum") and not isinstance(row.get("choices"), list):
            return f"{where}: a {kind} row needs \"choices\""
    return None


def read_widget(folder):
    """(entry, None) or (None, message)."""
    wid = folder.name
    if not ID.match(wid):
        return None, "folder name must be letters, digits, - or _"
    spec_path, qml = folder / "widget.json", folder / "Widget.qml"
    if not spec_path.is_file():
        return None, "no widget.json"
    if not qml.is_file():
        return None, "no Widget.qml"
    try:
        spec = json.loads(spec_path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        return None, f"widget.json: {error}"
    if not isinstance(spec, dict):
        return None, "widget.json must be an object"
    for key in ("name", "icon", "about"):
        if not isinstance(spec.get(key, ""), str):
            return None, f"widget.json: {key} must be text"
    problem = check_options(spec.get("options", []))
    if problem:
        return None, f"widget.json: {problem}"
    mtime = max(spec_path.stat().st_mtime_ns, qml.stat().st_mtime_ns)
    return {
        "type": "user:" + wid,
        "id": wid,
        "name": spec.get("name") or wid,
        "icon": spec.get("icon", ""),
        "about": spec.get("about", ""),
        "options": spec.get("options", []),
        "path": str(qml.resolve()),
        "mtime": mtime,
    }, None


def scan(folders):
    widgets, errors = [], []
    for folder in folders:
        entry, error = read_widget(folder)
        if entry:
            widgets.append(entry)
        else:
            errors.append({"id": folder.name, "message": error})
    return widgets, errors


def main():
    if len(sys.argv) >= 2 and sys.argv[1] == "list":
        try:
            folders = sorted(p for p in WIDGETS.iterdir() if p.is_dir() and not p.name.startswith("."))
        except OSError:
            folders = []
        widgets, errors = scan(folders)
        print(json.dumps({"widgets": widgets, "errors": errors, "dir": str(WIDGETS)}))
        return 0
    if len(sys.argv) == 3 and sys.argv[1] == "check":
        widgets, errors = scan([Path(sys.argv[2]).resolve()])
        print(json.dumps({"widgets": widgets, "errors": errors, "dir": str(WIDGETS)}))
        return 1 if errors else 0
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
