#!/usr/bin/env python3
"""Theme hooks: the one place that knows which hooks exist, their order, and
which are switched off.

A hook is an executable that gets the active palette and recolours one thing.

  built-in  <shell>/scripts/theming/hooks/NN-<id>.sh   (i3, rofi, kitty, gtk, ...)
  yours     <config>/hooks/theme.d/[NN-]<id>[.ext]      (<config> = ~/.config/<shell>)

The id is the file name without the NN- prefix and the extension. A hook of
yours with a built-in's id replaces that built-in. Hooks run in NN order
(no prefix = 90), then by id. Switched-off ids are settings.json
theme.hooksDisabled (Settings -> Appearance -> Theme hooks), or the JSON list
in $REVENANT_HOOKS_DISABLED, which the shell passes so a change counts at once.

Each hook is called as
    hook NAME BG FG COMMENT SELECTION RED GREEN YELLOW BLUE MAUVE CYAN
(hex, no '#') with THEME_NAME, THEME_SLUG, THEME_<KEY> for all 14 palette keys
(BG FG COMMENT SELECTION RED GREEN YELLOW BLUE MAUVE CYAN ORANGE TEAL MAROON
LAVENDER) and REVENANT_CONFIG in its environment.

A header in the first lines names it on the Settings page:
    # theme-hook: Herdr
    # Recolours Herdr's panels and terminals.

Usage:
    theme-hooks.py list                      -> {"hooks": [...]} (JsonScript contract)
    theme-hooks.py run [--slug S] NAME BG FG COMMENT SELECTION RED GREEN YELLOW BLUE MAUVE CYAN
"""

import json
import os
from pathlib import Path
import re
import subprocess
import sys

ARG_KEYS = ["bg", "fg", "comment", "selection", "red", "green", "yellow", "blue", "mauve", "cyan"]
EXTRA_KEYS = ["orange", "teal", "maroon", "lavender"]
HEX = re.compile(r"^[0-9a-fA-F]{3,8}$")
PREFIX = re.compile(r"^(\d+)-")
HOOK_TIMEOUT = 30  # seconds; a stuck hook must not hold up the theme queue
NO_PREFIX_ORDER = 90


def shell_root():
    here = Path(__file__).resolve().parent
    for d in [here, *here.parents]:
        if (d / "shell.qml").exists():
            return d
    return here


ROOT = shell_root()
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / ROOT.name
BUILTIN_DIR = ROOT / "scripts/theming/hooks"
USER_DIR = CONFIG / "hooks/theme.d"


def skipped_name(name):
    """Hidden files, editor leftovers and docs are not hooks."""
    return name.startswith(".") or name.endswith(("~", ".swp", ".md", ".txt", ".off", ".disabled"))


def parse_name(path):
    """(order, id) from NN-<id>.<ext>."""
    stem = path.name
    m = PREFIX.match(stem)
    order = int(m.group(1)) if m else NO_PREFIX_ORDER
    if m:
        stem = stem[m.end():]
    if "." in stem:
        stem = stem.rsplit(".", 1)[0]
    return order, stem


def parse_header(path):
    """Label and description from '# theme-hook: Label' and the comment lines after it."""
    label, desc = "", []
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            lines = [next(f, "") for _ in range(30)]
    except OSError:
        return label, ""
    in_header = False
    for line in lines:
        line = line.rstrip("\n")
        if not in_header:
            m = re.match(r"^\s*(?:#|//|--)\s*theme-hook:\s*(.*)$", line)
            if m:
                label, in_header = m.group(1).strip(), True
            continue
        m = re.match(r"^\s*(?:#|//|--)\s?(.*)$", line)
        if not m or not m.group(1).strip():
            break
        desc.append(m.group(1).strip())
    return label, " ".join(desc)


def disabled_ids():
    # The shell passes its live list (settings.json is saved 500 ms after a
    # change, so a switch flipped just before a theme change may not be there yet).
    live = os.environ.get("REVENANT_HOOKS_DISABLED")
    if live is not None:
        try:
            value = json.loads(live)
            if isinstance(value, list):
                return {str(v) for v in value}
        except ValueError:
            pass
    try:
        data = json.loads((CONFIG / "settings.json").read_text())
        value = data.get("theme", {}).get("hooksDisabled", [])
        return {str(v) for v in value} if isinstance(value, list) else set()
    except (OSError, ValueError, AttributeError):
        return set()


def scan(directory, builtin):
    hooks = {}
    try:
        entries = sorted(directory.iterdir())
    except OSError:
        return hooks
    for path in entries:
        if not path.is_file() or skipped_name(path.name):
            continue
        order, hook_id = parse_name(path)
        label, description = parse_header(path)
        hooks[hook_id] = {
            "id": hook_id,
            "label": label or hook_id,
            "description": description,
            "order": order,
            "builtin": builtin,
            "overrides": False,
            "executable": os.access(path, os.X_OK),
            "path": str(path),
        }
    return hooks


def all_hooks():
    hooks = scan(BUILTIN_DIR, True)
    for hook_id, hook in scan(USER_DIR, False).items():
        if hook_id in hooks:
            hook["overrides"] = True
            if not PREFIX.match(Path(hook["path"]).name):
                hook["order"] = hooks[hook_id]["order"]  # keep the built-in's slot
        hooks[hook_id] = hook
    off = disabled_ids()
    result = sorted(hooks.values(), key=lambda h: (h["order"], h["id"]))
    for hook in result:
        hook["enabled"] = hook["id"] not in off
    return result


def cmd_list():
    print(json.dumps({"hooks": all_hooks(), "userDir": str(USER_DIR)}))
    return 0


def cmd_run(argv):
    slug = ""
    if len(argv) >= 2 and argv[0] == "--slug":
        slug, argv = argv[1], argv[2:]
    if len(argv) != 11:
        print("usage: theme-hooks.py run [--slug S] NAME BG FG COMMENT SELECTION RED GREEN YELLOW BLUE MAUVE CYAN",
              file=sys.stderr)
        return 2
    name, colours = argv[0], [c.lstrip("#") for c in argv[1:]]
    for key, value in zip(ARG_KEYS, colours):
        if not HEX.match(value):
            print(f"theme-hooks: {key} {value!r} is not a hex colour; aborting", file=sys.stderr)
            return 1

    env = dict(os.environ)
    palette = dict(zip(ARG_KEYS, colours))
    for key in EXTRA_KEYS:  # apply-theme-externals.sh exports these; other callers fall back to fg
        value = env.get("THEME_" + key.upper(), "").lstrip("#")
        palette[key] = value if HEX.match(value) else palette["fg"]
    env.update({"THEME_" + k.upper(): v for k, v in palette.items()})
    env.update({"THEME_NAME": name, "THEME_SLUG": slug or env.get("THEME_SLUG", ""),
                "REVENANT_CONFIG": str(CONFIG)})

    for hook in all_hooks():
        if not hook["enabled"]:
            continue
        if not hook["executable"]:
            print(f"theme-hooks: {hook['id']} is not executable (chmod +x {hook['path']})", file=sys.stderr)
            continue
        try:
            code = subprocess.run([hook["path"], name, *colours], env=env,
                                  stdin=subprocess.DEVNULL, timeout=HOOK_TIMEOUT).returncode
        except subprocess.TimeoutExpired:
            print(f"theme-hooks: hook {hook['id']} timed out after {HOOK_TIMEOUT}s", file=sys.stderr)
            continue
        except OSError as error:
            print(f"theme-hooks: hook {hook['id']} could not start: {error}", file=sys.stderr)
            continue
        if code != 0:
            print(f"theme-hooks: hook {hook['id']} failed ({code})", file=sys.stderr)
    return 0


def main():
    if len(sys.argv) >= 2 and sys.argv[1] == "list":
        return cmd_list()
    if len(sys.argv) >= 2 and sys.argv[1] == "run":
        return cmd_run(sys.argv[2:])
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
