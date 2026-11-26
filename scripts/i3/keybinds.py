#!/usr/bin/env python3
"""Print i3 shortcuts as JSON for panels/KeybindsPanel.qml:

  [{"section", "keys", "action", "source", "note"}, ...]   (note = the
  comment line right above the bind, "" if none)

i3: `bindsym` lines from ~/.config/i3/config and every included file; the
section is the latest `## ───── Name ─────` header, the action a readable
form of the command (or the comment line right above the bind, if any).
"""
import glob
import json
import os
import re
import sys

HOME = os.path.expanduser("~")
I3_DIR = os.path.join(HOME, ".config/i3")
SECTION_HEADER = re.compile(r"^##\s*[─-]*\s*([^─=]+?)\s*[─-]*$")
ACTION_LABEL = "# Action: "

KEYNAMES = {"Mod4": "Super", "Mod1": "Alt", "Ctrl": "Ctrl", "Shift": "Shift",
            "Return": "Enter", "space": "Space", "minus": "-", "comma": ",",
            "period": ".", "Page_Up": "PgUp", "Page_Down": "PgDn", "Print": "Print",
            "BackSpace": "Backspace", "Escape": "Esc", "Delete": "Del"}


def pretty_keys(chord, variables):
    # Longest names first, so $mod doesn't eat the start of $mod2.
    for name in sorted(variables, key=len, reverse=True):
        chord = chord.replace("$" + name, variables[name])
    parts = re.split(r"\s*\+\s*", chord.strip())
    return " + ".join(KEYNAMES.get(p, KEYNAMES.get(p.capitalize(), p.upper() if len(p) == 1 else p))
                      for p in parts if p)


I3_COMMANDS = {"kill": "Close window", "restart": "Restart i3 (in place)", "reload": "Reload i3 config",
               "floating toggle": "Toggle floating", "fullscreen toggle": "Toggle fullscreen",
               "scratchpad show": "Show scratchpad", "move scratchpad": "Move to scratchpad"}


def describe(cmd, variables):
    is_exec = bool(re.match(r"^exec(_always)?\b", cmd.strip()))
    cmd = re.sub(r"^exec(_always)?\s+(--no-startup-id\s+)?", "", cmd.strip())
    if not is_exec and cmd in I3_COMMANDS:
        return I3_COMMANDS[cmd]
    qs = re.match(r"^\$qs\s+(\w+)", cmd)
    if qs:
        return "Shell: " + qs.group(1)
    for name, value in variables.items():
        cmd = cmd.replace("$" + name, value)
    cmd = re.sub(r"^i3-msg\s+", "", cmd)
    m = re.match(r'^workspace (?:number )?"?([^"]+)"?$', cmd)
    if m:
        return "Go to workspace " + m.group(1)
    m = re.match(r'^move container to workspace (?:number )?"?([^"]+)"?(?:[,;].*)?$', cmd)
    if m:
        return "Move window to workspace " + m.group(1)
    m = re.search(r"screenshot-capture\.sh\s+(\w+)", cmd)
    if m:
        return "Screenshot: " + m.group(1)
    m = re.search(r"i3resize\s+(\w+)", cmd)
    if m:
        return "Resize " + m.group(1)
    if is_exec and re.match(r"^[\w.-]+$", cmd):   # a bare program
        return "Run " + cmd
    return cmd if len(cmd) <= 70 else cmd[:67] + "…"


def i3_files():
    seen = set()

    def walk(path):
        resolved = os.path.realpath(path)
        if resolved in seen:
            return
        seen.add(resolved)
        try:
            with open(path, encoding="utf-8") as config:
                lines = config.readlines()
        except OSError:
            return
        yield path
        for line in lines:
            match = re.match(r"^\s*include\s+(.+)$", line)
            if match:
                pattern = os.path.expanduser(match[1].strip()).replace("$HOME", HOME)
                if not os.path.isabs(pattern):
                    pattern = os.path.join(os.path.dirname(path), pattern)
                for included in sorted(glob.glob(pattern)):
                    yield from walk(included)

    try:
        from i3_config import main_config   # the file i3 actually loaded
        main = str(main_config())
    except (ImportError, ValueError):
        main = os.path.join(I3_DIR, "config")
    return walk(main)



def i3_binds():
    out, variables = [], {"mod": "Mod4"}
    for path in i3_files():
        section, comment, prev_blank = "General", "", True
        try:
            lines = open(path, encoding="utf-8").read().splitlines()
        except OSError:
            continue
        for line in lines:
            s = line.strip()
            m = re.match(r"^set\s+\$(\w+)\s+(.+)$", s)
            if m:
                variables[m.group(1)] = m.group(2).strip()
                continue
            m = SECTION_HEADER.match(s)
            if m and "KEYBIND" not in m.group(1).upper():
                section, comment = m.group(1).strip(), ""
                continue
            if s.startswith("#"):
                if s.startswith("# Disabled shortcut: "):
                    comment = ""
                    continue
                text = s.lstrip("# ").strip()
                # A short "# Focus windows" opening a block names a group.
                if prev_blank and 0 < len(text.split()) <= 4 and not re.search(r"[(;:.,]", text):
                    section, comment = text, ""
                else:
                    comment = text
                prev_blank = False
                continue
            m = re.match(r"^bindsym\s+(?:--\S+\s+)*(\S+)\s+(.+)$", s)
            if m:
                label = comment.removeprefix("Action: ") if comment.startswith("Action: ") else ""
                out.append({"section": section, "keys": pretty_keys(m.group(1), variables),
                            "action": label or describe(m.group(2), variables), "source": "i3",
                            "note": "" if label else comment})
                comment = ""
                prev_blank = False
                continue
            if not s:
                comment = ""
                prev_blank = True
            else:
                prev_blank = False
    return out


def main():
    binds = i3_binds()
    json.dump(binds, sys.stdout, ensure_ascii=False)
    print()


if __name__ == "__main__":
    main()
