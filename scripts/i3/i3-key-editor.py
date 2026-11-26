#!/usr/bin/env python3
"""Record and manage keyboard shortcuts in i3's shortcut modules."""
import ctypes
import hashlib
import json
import os
from pathlib import Path
import re
import select
import subprocess
import sys
import tempfile
import time

from i3_config import (NotSetUp, config_lock, display_path, loaded_module, replace_and_reload,
                       setup_module, substitute_include, validate_config)
from keybinds import ACTION_LABEL, SECTION_HEADER, describe, pretty_keys

BIND = re.compile(r"^(\s*bindsym\s+(?:--\S+\s+)*)(\S+)([ \t]+)(.+)$")
CHORD = re.compile(r"(?:(?:\$mod|Ctrl|Shift|Mod[1-5])\+)*[A-Za-z0-9_]+")
# A binding's "line" is module_index * LINE_STRIDE + its line in that module,
# so one number names it across all modules. Templates for actions that are
# not in the file yet use negative lines instead; their "kind" says which:
#   "binding"  a line in the file (line >= 0), enabled or disabled
#   "action"   an i3 command from UNBOUND_ACTIONS (line UNBOUND_BASE - n)
#   "role"     a default-app role with no binding yet (line ROLE_BASE - n)
# CUSTOM_TEMPLATE (-1) is what the editor sends for "Custom command".
LINE_STRIDE = 1_000_000
CUSTOM_TEMPLATE = -1
UNBOUND_BASE = -10
ROLE_BASE = -100
DISABLED = "# Disabled shortcut: "
APP_EXEC = re.compile(r"^(exec\s+(?:--no-startup-id\s+)?)(.+)$")
DEFAULT_APPS = "Default Apps"
CUSTOM_APPS = "Custom Apps"
APP_SECTIONS = {DEFAULT_APPS, CUSTOM_APPS}
# Action label -> the MIME type whose default app it opens. The MIME roles
# are shared with Settings → Default apps (assets/default-app-roles.json, first
# type of each row); the terminal comes from the shell's own terminal setting.
# The shell's directory: the nearest one up from here holding shell.qml.
ROOT = next(p for p in Path(__file__).resolve().parents if (p / "shell.qml").exists())
ROLES_FILE = ROOT / "assets" / "default-app-roles.json"
DEFAULT_APP_ROLES = (("Open terminal", "terminal"),) + tuple(
    (row["action"], row["types"][0])
    for group in json.loads(ROLES_FILE.read_text(encoding="utf-8")) for row in group["rows"])
UNBOUND_ACTIONS = (
    ("Windows", "Toggle fullscreen", "fullscreen toggle"),
    ("Windows", "Split horizontally", "split h"),
    ("Windows", "Split vertically", "split v"),
    ("Windows", "Tabbed layout", "layout tabbed"),
    ("Windows", "Stacking layout", "layout stacking"),
    ("Windows", "Toggle split layout", "layout toggle split"),
    ("Windows", "Focus parent container", "focus parent"),
    ("Windows", "Focus child container", "focus child"),
    ("Windows", "Toggle tiling / floating focus", "focus mode_toggle"),
    ("Windows", "Toggle sticky floating window", "sticky toggle"),
    ("Workspaces", "Next workspace", "workspace next"),
    ("Workspaces", "Previous workspace", "workspace prev"),
    ("Workspaces", "Next workspace on this monitor", "workspace next_on_output"),
    ("Workspaces", "Previous workspace on this monitor", "workspace prev_on_output"),
    ("Session", "Log out of i3", "exit"),
)


def read_modules(keys):
    modules = {}
    for path in sorted((keys.parent / "keys").glob("*.config")):
        source = path.read_text()
        headers = [match[1].strip() for line in source.splitlines()
                   if (match := SECTION_HEADER.match(line))]
        if len(headers) != 1 or headers[0] in modules:
            raise ValueError(f"{path.name} must contain one unique shortcut section.")
        modules[headers[0]] = (path, source)
    if not modules:
        raise ValueError("No shortcut modules were found.")
    return modules


def revision_for(path, source):
    return hashlib.sha256((path.name + "\0" + source).encode()).hexdigest()


def parse_bindings(preamble, source, offset=0):
    variables = {"mod": "Mod4"}
    for match in re.finditer(r"^\s*set\s+\$(\w+)\s+(.+)$", preamble + "\n" + source, re.M):
        variables[match[1]] = match[2].strip()
    bindings = []
    templates = []
    sections = []
    section = "General"
    label = ""
    for index, line in enumerate(source.splitlines()):
        header = SECTION_HEADER.match(line)
        if header:
            section = header[1].strip()
            if section not in sections:
                sections.append(section)
            label = ""
            continue
        if line.startswith(ACTION_LABEL):
            label = line[len(ACTION_LABEL):].strip()
            continue
        disabled = line.startswith(DISABLED)
        match = BIND.fullmatch(line.removeprefix(DISABLED))
        if (match and not match[4].endswith("\\") and not match[2].startswith("button")
                and not (disabled and section == CUSTOM_APPS)):
            app = APP_EXEC.fullmatch(match[4]) if section in APP_SECTIONS else None
            binding = {
                "line": offset + index,
                "kind": "binding",
                "chord": match[2],
                "keys": pretty_keys(match[2], {"mod": variables["mod"]}),
                "action": label or describe(match[4], variables),
                "command": match[4],
                "section": section,
                "disabled": disabled,
                "noRepeat": "--release" in match[1].split(),
                "appCommand": (app[2] if app else match[4]) if section in APP_SECTIONS else None,
            }
            templates.append(binding)
            if not disabled:
                bindings.append(binding)
            if section not in sections:
                sections.append(section)
        label = ""
    known = {(item["section"], item["command"].strip()) for item in templates}
    for index, (area, action, command) in enumerate(UNBOUND_ACTIONS):
        if area in sections and (area, command) not in known:
            templates.append({"line": UNBOUND_BASE - index, "kind": "action", "chord": "", "keys": "",
                              "section": area, "action": action, "command": command,
                              "disabled": True, "noRepeat": False, "appCommand": None})
    if DEFAULT_APPS in sections:
        roles = dict(DEFAULT_APP_ROLES)
        existing = {item["action"] for item in templates}
        for item in templates:
            if item["section"] == DEFAULT_APPS:
                item["defaultRole"] = roles.get(item["action"])
        for index, (action, role) in enumerate(DEFAULT_APP_ROLES):
            if action not in existing:
                templates.append({"line": ROLE_BASE - index, "kind": "role", "chord": "", "keys": "",
                                  "section": DEFAULT_APPS, "action": action, "command": "",
                                  "disabled": True, "noRepeat": False, "appCommand": "",
                                  "defaultRole": role})
    return {
        "bindings": bindings,
        "templates": templates,
        "sections": sections,
        "mod": variables["mod"],
    }


def read_bindings(main, keys, modules):
    preamble = main.read_text() + "\n" + keys.read_text()
    result = {"bindings": [], "templates": [], "sections": list(modules), "revisions": {}}
    for index, (section, (path, source)) in enumerate(modules.items()):
        state = parse_bindings(preamble, source, index * LINE_STRIDE)
        if state["sections"] != [section]:
            raise ValueError(f"Put all bindings in {path.name} after its section heading.")
        result["bindings"].extend(state["bindings"])
        result["templates"].extend(state["templates"])
        result["revisions"][section] = revision_for(path, source)
        result["mod"] = state["mod"]
    return result


def edit_binding(main, keys, modules, operation, section, revision, *args):
    if section not in modules:
        raise ValueError("Choose an existing shortcut section.")
    path, original = modules[section]
    if revision_for(path, original) != revision:
        raise ValueError("This shortcut section changed. Refresh the list before applying.")
    state = parse_bindings(main.read_text() + "\n" + keys.read_text(), original)
    lines = original.splitlines(keepends=True)
    if operation == "remove":
        line = int(args[0]) % LINE_STRIDE
        binding = next((item for item in state["bindings"] if item["line"] == line), None)
        if binding is None:
            raise ValueError("That binding is no longer editable.")
        if binding["section"] == CUSTOM_APPS:
            start = line - 1 if line > 0 and lines[line - 1].startswith(ACTION_LABEL) else line
            del lines[start:line + 1]
        else:
            lines[line] = DISABLED + lines[line]
    elif operation == "save":
        line, chord = int(args[0]) % LINE_STRIDE, args[1].strip()
        binding = next((item for item in state["bindings"] if item["line"] == line), None)
        if binding is None:
            raise ValueError("That binding is no longer editable.")
        lines[line] = write_binding(lines[line], chord, args[2] == "true",
                                    args[3].strip() if binding["appCommand"] is not None else None)
    else:
        template, chord, name, command, no_repeat = args
        template = int(template)
        add_binding(lines, state, section, template % LINE_STRIDE if template >= 0 else template,
                    chord.strip(), name.strip(), command.strip(), no_repeat == "true")
    apply_config(main, keys, modules, path, original, "".join(lines))


def write_binding(line, chord, no_repeat, app_command=None):
    if not CHORD.fullmatch(chord):
        raise ValueError("Enter an i3 shortcut such as $mod+Shift+F8.")
    match = BIND.fullmatch(line.rstrip("\n"))
    prefix = re.sub(r"(?<=\s)--release[ \t]+", "", match[1])
    command = match[4]
    if app_command is not None:
        if not valid_line(app_command):
            raise ValueError("Enter a single-line app command.")
        command = app_exec(app_command, APP_EXEC.fullmatch(command))
    return prefix + ("--release " if no_repeat else "") + chord + match[3] + command + (
        "\n" if line.endswith("\n") else "")


def valid_line(value):
    return bool(value) and not any(char in value for char in "\n\r\0") and not value.endswith("\\")


def app_exec(command, previous=None):
    if APP_EXEC.fullmatch(command):
        return command
    return (previous[1] if previous else "exec --no-startup-id ") + command


def add_binding(lines, state, section, template, chord, name, command, no_repeat):
    if section not in state["sections"]:
        raise ValueError("Choose an existing shortcut section.")
    if template != CUSTOM_TEMPLATE:
        binding = next((item for item in state["templates"]
                        if item["line"] == template and item["section"] == section), None)
        if binding is None:
            raise ValueError("That action is no longer available in this section.")
        if template < 0 and binding["appCommand"] is None:
            command = binding["command"]
        elif template >= 0:
            original = lines[template].removeprefix(DISABLED)
            new_line = write_binding(original, chord, no_repeat,
                                     command if binding["appCommand"] is not None else None)
        if binding["disabled"] and template >= 0:
            lines[template] = new_line
            return
        name = binding["action"]
    if template >= 0:
        index = template + 1
    else:
        if not valid_line(name) or not valid_line(command):
            raise ValueError("Enter an action name and a single-line i3 command.")
        if section == DEFAULT_APPS and template == CUSTOM_TEMPLATE:
            raise ValueError("Choose an existing default app action.")
        if section in APP_SECTIONS:
            command = app_exec(command)
        new_line = write_binding(f"bindsym placeholder {command}\n", chord, no_repeat)
        headers = [(idx, match[1].strip()) for idx, line in enumerate(lines)
                   if (match := SECTION_HEADER.match(line.rstrip("\n")))]
        start = next((idx for idx, heading in headers if heading == section), -1)
        index = next((idx for idx, _ in headers if idx > start), len(lines))
    if index and not lines[index - 1].endswith("\n"):
        lines[index - 1] += "\n"
    lines[index:index] = [ACTION_LABEL + name + "\n", new_line.rstrip("\n") + "\n"]


def apply_config(main, keys, modules, target, original, updated):
    if updated == original:
        return

    main_source = main.read_text()
    dispatcher_source = keys.read_text()
    with tempfile.TemporaryDirectory(prefix="i3-key-editor-") as staging:
        staged_keys = Path(staging) / "keys.config"
        staged_main = Path(staging) / "config"
        staged_modules = Path(staging) / "sections"
        staged_modules.mkdir()
        for path, source in modules.values():
            staged_modules.joinpath(path.name).write_text(updated if path == target else source)
        # Point both includes at the staged copies, however they're spelled.
        staged_keys.write_text(substitute_include(
            dispatcher_source, keys.parent, keys.parent / "keys" / "*.config", staged_modules / "*.config"))
        staged_main.write_text(substitute_include(main_source, main.parent, keys, staged_keys))
        validate_config(staged_main, main.parent)

    if (read_modules(keys) != modules or main.read_text() != main_source
            or keys.read_text() != dispatcher_source):
        raise ValueError("Shortcut files changed during validation. Refresh and retry.")
    replace_and_reload(target, original, updated)


def capture(mod):
    from Xlib import X, XK, display

    connection = display.Display()
    x11 = ctypes.CDLL("libX11.so.6")
    x11.XKeysymToString.argtypes = [ctypes.c_ulong]
    x11.XKeysymToString.restype = ctypes.c_char_p
    masks = [(X.ControlMask, "Ctrl"), (X.ShiftMask, "Shift")] + [
        (1 << (index + 3), "$mod" if f"Mod{index + 1}" == mod else f"Mod{index + 1}")
        for index in range(5)
    ]
    ignored = set()
    modifier_keys = set()
    for index, keycodes in enumerate(connection.get_modifier_mapping()):
        modifier_keys.update(keycode for keycode in keycodes if keycode)
        if any(connection.keycode_to_keysym(keycode, 0) == XK.XK_Num_Lock for keycode in keycodes if keycode):
            ignored.add(1 << index)

    try:
        # Keep the grab on the focused Settings window. A grab on the root
        # sends a focus-out event to the panel and can close the editor.
        focused = connection.get_input_focus().focus
        if not hasattr(focused, "grab_keyboard"):
            raise ValueError("Focus the Settings window before recording a shortcut.")
        status = focused.grab_keyboard(False, X.GrabModeAsync, X.GrabModeAsync, X.CurrentTime)
        if status != X.GrabSuccess:
            raise ValueError("Could not grab the keyboard. Close any open menu and try again.")
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if not connection.pending_events():
                select.select([connection.fileno()], [], [], max(0, deadline - time.monotonic()))
                continue
            event = connection.next_event()
            if event.type != X.KeyPress or event.detail in modifier_keys:
                continue
            symbol = x11.XKeysymToString(connection.keycode_to_keysym(event.detail, 0))
            if not symbol:
                continue
            key = symbol.decode("ascii")
            modifiers = [label for mask, label in masks if mask not in ignored and event.state & mask]
            if key == "Escape" and not modifiers:
                return {"cancelled": True}
            chord = "+".join([*modifiers, key])
            if not CHORD.fullmatch(chord):
                raise ValueError("That key does not have a supported i3 name.")
            return {"chord": chord}
        return {"cancelled": True}
    finally:
        connection.ungrab_keyboard(X.CurrentTime)
        connection.close()


def main():
    action, *args = sys.argv[1:]
    if action == "capture":
        return capture(args[0])
    if action == "setup":
        # keys.config includes one file per shortcut section from keys/.
        setup_module("keys.config", lambda modules: {
            "keys.config": "# Shortcut sections, one file each, edited in Revenant's Settings → Keybinds.\n"
                           f"include {display_path(modules / 'keys')}/*.config\n",
            "keys/10-general.config": "## ───── General ─────\n",
        })
        action = "list"
    main_config, keys = loaded_module("keys.config")
    editing = action in {"save", "add", "remove"}
    # All edits must validate and reload against a single consistent snapshot.
    with config_lock(main_config, editing):
        modules = read_modules(keys)
        if editing:
            edit_binding(main_config, keys, modules, action, *args)
            modules = read_modules(keys)
        return read_bindings(main_config, keys, modules)


if __name__ == "__main__":
    try:
        result = main()
    except BlockingIOError:
        result = {"error": "Another shortcut change is in progress. Try again in a moment."}
    except NotSetUp as error:
        result = {"error": str(error), "setup": True}
    except (OSError, ValueError, KeyError, IndexError, ImportError, subprocess.TimeoutExpired) as error:
        result = {"error": str(error)}
    print(json.dumps(result, ensure_ascii=False))
