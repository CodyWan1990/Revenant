#!/usr/bin/env python3
"""Read and apply i3's dedicated window-options module."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

from i3_config import (NotSetUp, command, config_lock, ipc, loaded_module, replace_and_reload,
                       setup_module, substitute_include, validate_config)

# The shell's own windows are titled with its config name (the directory
# this copy lives in), and are left out of the window list.
# The shell's directory: the nearest one up from here holding shell.qml.
ROOT = next(p for p in Path(__file__).resolve().parents if (p / "shell.qml").exists())
SHELL_NAME = ROOT.name

MODULE = "window-options.config"
DIRECTIVES = {
    "inner": "gaps inner",
    "outer": "gaps outer",
    "smartGaps": "smart_gaps",
    "tilingBorder": "default_border",
    "floatingBorder": "default_floating_border",
    "edgeBorders": "hide_edge_borders",
    "focusFollowsMouse": "focus_follows_mouse",
    "focusWrapping": "focus_wrapping",
    "focusOnActivation": "focus_on_window_activation",
    "mouseWarping": "mouse_warping",
    "workspaceLayout": "workspace_layout",
    "titleAlign": "title_align",
    "fullscreenPopups": "popup_during_fullscreen",
    "showMarks": "show_marks",
}
CHOICES = {
    "smartGaps": {"off", "on", "inverse_outer"},
    "edgeBorders": {"none", "vertical", "horizontal", "both", "smart", "smart_no_gaps"},
    "focusFollowsMouse": {"yes", "no"},
    "focusWrapping": {"yes", "no", "force", "workspace"},
    "focusOnActivation": {"smart", "urgent", "focus", "none"},
    "mouseWarping": {"output", "none"},
    "workspaceLayout": {"default", "stacking", "tabbed"},
    "titleAlign": {"left", "center", "right"},
    "fullscreenPopups": {"smart", "ignore", "leave_fullscreen", "all"},
    "showMarks": {"yes", "no"},
}
BORDERS = {"tilingBorder", "floatingBorder"}
DEFAULTS = {
    "inner": 0,
    "outer": 0,
    "smartGaps": "off",
    "tilingBorder": {"style": "normal", "width": 2},
    "floatingBorder": {"style": "normal", "width": 2},
    "edgeBorders": "none",
    "focusFollowsMouse": "yes",
    "focusWrapping": "yes",
    "focusOnActivation": "smart",
    "mouseWarping": "output",
    "workspaceLayout": "default",
    "titleAlign": "left",
    "fullscreenPopups": "smart",
    "showMarks": "yes",
}


def parse_value(key, value):
    if key in CHOICES:
        if value not in CHOICES[key]:
            raise ValueError(f"Invalid {DIRECTIVES[key]} setting.")
        return value
    if key in BORDERS:
        match = re.fullmatch(r"(pixel|normal|none)(?:\s+(\d+)(?:px)?)?", value)
        if not match or (match[1] == "none" and match[2]):
            raise ValueError(f"Invalid {DIRECTIVES[key]} setting.")
        return {"style": match[1], "width": int(match[2] or ("0" if match[1] == "none" else "2"))}
    return int(value.removesuffix("px"))


def format_value(key, value):
    if key in CHOICES:
        return parse_value(key, value)
    if key in BORDERS:
        if not isinstance(value, dict) or value.get("style") not in {"none", "pixel", "normal"}:
            raise ValueError("Choose a valid window border style.")
        if value["style"] == "none":
            return "none"
        return f'{value["style"]} {checked_int(value.get("width"), 0, 16)}'
    return str(checked_int(value, -64 if key == "outer" else 0, 64))


def checked_int(value, low, high):
    if type(value) is not int or not low <= value <= high:
        raise ValueError(f"Enter a whole number from {low} to {high}.")
    return value


def read_options(source):
    values = DEFAULTS.copy()
    positions = {}
    lines = source.splitlines(keepends=True)
    for index, line in enumerate(lines):
        words = line.split()
        if not words:
            continue
        for key, directive in DIRECTIVES.items():
            prefix = directive.split()
            if words[:len(prefix)] == prefix:
                if key in positions:
                    raise ValueError(f"{directive} is defined more than once in {MODULE}.")
                values[key] = parse_value(key, " ".join(words[len(prefix):]))
                positions[key] = index
                break
    return values, positions, lines


def revision(source):
    return hashlib.sha256(source.encode()).hexdigest()


def client_windows(node, floating=False):
    if node.get("type") == "dockarea":
        return
    floating = floating or node.get("type") == "floating_con"
    if node.get("window") is not None and node.get("name") != SHELL_NAME:
        yield node, "floatingBorder" if floating else "tilingBorder"
    for child in node.get("nodes", []):
        yield from client_windows(child, floating)
    for child in node.get("floating_nodes", []):
        yield from client_windows(child, True)


def apply_borders(values, border_types):
    commands = []
    for window, key in client_windows(ipc("-t", "get_tree")):
        if key not in border_types:
            continue
        border = values[key]
        if window.get("border") == border["style"] and (
                border["style"] == "none" or window.get("current_border_width") == border["width"]):
            continue
        commands.append(f'[con_id={int(window["id"])}] border {format_value(key, border)}')
    if commands:
        command("; ".join(commands))


def apply_options(main, module, original, changes):
    before, positions, lines = read_options(original)
    for key, value in changes.items():
        if key not in DIRECTIVES:
            raise ValueError("Unknown i3 window option.")
        new_value = format_value(key, value)
        if parse_value(key, new_value) != before[key]:
            setting = f"{DIRECTIVES[key]} {new_value}\n"
            if key in positions:
                lines[positions[key]] = setting
            else:
                if lines and not lines[-1].endswith("\n"):
                    lines[-1] += "\n"
                lines.append(setting)
    updated = "".join(lines)
    if updated == original:
        return ""

    main_source = main.read_text()
    with tempfile.TemporaryDirectory(prefix="i3-window-options-") as staging:
        staged_module = Path(staging) / MODULE
        staged_module.write_text(updated)
        staged_config = Path(staging) / "config"
        staged_config.write_text(substitute_include(main_source, main.parent, module, staged_module))
        validate_config(staged_config, main.parent)

    if main.read_text() != main_source:
        raise ValueError("The main i3 config changed during validation. Refresh and retry.")
    replace_and_reload(module, original, updated)
    after, _, _ = read_options(updated)
    warnings = []
    gap_commands = [f"gaps {key} all set {after[key]}"
                    for key in ("inner", "outer") if after[key] != before[key]]
    if gap_commands:
        try:
            command("; ".join(gap_commands))
        except (ValueError, OSError, subprocess.TimeoutExpired):
            warnings.append("Could not update gaps on open workspaces.")
    border_types = {key for key in BORDERS if after[key] != before[key]}
    if border_types:
        try:
            apply_borders(after, border_types)
        except (ValueError, OSError, subprocess.TimeoutExpired):
            warnings.append("Could not update all open window borders.")
    return "Defaults saved. " + " ".join(warnings) if warnings else ""


def main():
    action, *args = sys.argv[1:]
    if action == "setup":
        setup_module(MODULE, lambda modules: {
            MODULE: "# Window geometry and decorations, edited in Revenant's Settings → i3 Options.\n"})
        action = "read"
    main_path, module = loaded_module(MODULE)
    with config_lock(main_path, action in {"apply", "borders"}):
        source = module.read_text()
        warning = ""
        if action == "apply":
            expected, changes = args
            if revision(source) != expected:
                raise ValueError("Window options changed on disk. Refresh before applying.")
            warning = apply_options(main_path, module, source, json.loads(changes))
            source = module.read_text()
        values, _, _ = read_options(source)
        if action == "borders":
            if revision(source) != args[0]:
                raise ValueError("Window options changed on disk. Refresh before applying.")
            apply_borders(values, BORDERS)
        return {"values": values, "revision": revision(source), "warning": warning}


if __name__ == "__main__":
    try:
        result = main()
    except BlockingIOError:
        result = {"error": "Another i3 settings change is in progress. Try again in a moment."}
    except NotSetUp as error:
        result = {"error": str(error), "setup": True}
    except (OSError, ValueError, TypeError, KeyError, IndexError, subprocess.TimeoutExpired) as error:
        result = {"error": str(error)}
    print(json.dumps(result))
