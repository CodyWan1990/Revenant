#!/usr/bin/env python3
"""List installed icon and cursor themes and apply the X11 desktop selection."""

import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

HOME = Path.home()
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or HOME / ".config")
DATA = Path(os.environ.get("XDG_DATA_HOME") or HOME / ".local/share")
XSETTINGS = CONFIG / "xsettingsd/xsettingsd.conf"
CURSOR_DEFAULT = HOME / ".icons/default/index.theme"
GTK_FILES = [CONFIG / f"gtk-{version}.0/settings.ini" for version in (3, 4)]
QT_FILES = [CONFIG / f"{tool}/{tool}.conf" for tool in ("qt5ct", "qt6ct")]
KEYS = {
    "icons": ("Net/IconThemeName", "gtk-icon-theme-name", "icon-theme"),
    "cursors": ("Gtk/CursorThemeName", "gtk-cursor-theme-name", "cursor-theme"),
}


def installed_themes():
    roots = [DATA / "icons", HOME / ".icons"]
    roots += [
        Path(directory) / "icons"
        for directory in (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":")
        if directory
    ]
    roots += [Path("/usr/share/pixmaps")]
    cursor_roots = roots + [Path("/usr/share/cursors/xorg-x11"), Path("/usr/X11R6/lib/X11/icons")]
    cursor_roots += [
        Path(os.path.expanduser(directory))
        for directory in os.environ.get("XCURSOR_PATH", "").split(":")
        if directory
    ]

    themes = {"icons": set(), "cursors": set()}
    for directory in dict.fromkeys(cursor_roots):
        if not directory.is_dir():
            continue
        for theme in directory.iterdir():
            name = theme.name
            # Theme IDs are shared by XSETTINGS, INI files and X resources.
            if name in ("default", "hicolor") or not re.fullmatch(r"[\w.+ -]+", name) or name != name.strip():
                continue
            if (theme / "cursors").is_dir():
                themes["cursors"].add(name)
            if directory in roots and (theme / "index.theme").is_file():
                if re.search(r"^Directories\s*=.+", read(theme / "index.theme"), re.MULTILINE):
                    themes["icons"].add(name)
    return {kind: sorted(names, key=str.casefold) for kind, names in themes.items()}


def read(path):
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return ""


def update(path, pattern, line, section=None):
    # Preserve comments, unrelated settings and existing symlinks.
    path = path.resolve()
    original = read(path)
    lines = original.splitlines()
    start, end = 0, len(lines)
    if section:
        if section not in [entry.strip() for entry in lines]:
            if lines and lines[-1]:
                lines.append("")
            lines.append(section)
        start = next(index + 1 for index, entry in enumerate(lines) if entry.strip() == section)
        end = next((i for i in range(start, len(lines)) if lines[i].lstrip().startswith("[")), len(lines))
    lines[start:end] = [entry for entry in lines[start:end] if not re.match(pattern, entry)]
    lines.insert(start, line)
    content = "\n".join(lines) + "\n"
    if content == original:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent, delete=False) as output:
        temporary = Path(output.name)
        try:
            output.write(content)
            output.close()
            if path.exists():
                temporary.chmod(path.stat().st_mode & 0o777)
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)


def run(*command, **kwargs):
    return subprocess.run(command, text=True, capture_output=True, timeout=5, **kwargs)


def toolkit_setting(gtk_key, gkey):
    for path in GTK_FILES:
        match = re.search(rf"^\s*{gtk_key}\s*=\s*(.+)", read(path), re.MULTILINE)
        if match:
            return match[1].strip()
    if shutil.which("gsettings"):
        result = run("gsettings", "get", "org.gnome.desktop.interface", gkey)
        if result.returncode == 0:
            return result.stdout.strip().strip("'")
    return ""


def current(kind):
    xkey, gtk_key, gkey = KEYS[kind]
    match = re.search(rf'^\s*{re.escape(xkey)}\s+"([^"]+)"', read(XSETTINGS), re.MULTILINE)
    return match[1] if match else toolkit_setting(gtk_key, gkey)


def apply(kind, name):
    xkey, gtk_key, _ = KEYS[kind]
    if not XSETTINGS.exists():
        settings = {
            "Net/ThemeName": ("gtk-theme-name", "gtk-theme"),
            "Gtk/FontName": ("gtk-font-name", "font-name"),
            **{key: (gtk, gnome) for key, gtk, gnome in KEYS.values()},
        }
        for key, (gtk, gnome) in settings.items():
            if key == xkey:
                continue
            value = toolkit_setting(gtk, gnome)
            if value and not any(char in value for char in '"\\\n\r'):
                update(XSETTINGS, rf"^{re.escape(key)}\s+", f'{key} "{value}"')
        size = toolkit_setting("gtk-cursor-theme-size", "cursor-size")
        if re.fullmatch(r"[0-9]+", size):
            update(XSETTINGS, r"^Gtk/CursorThemeSize\s+", f"Gtk/CursorThemeSize {size}")

    for path in GTK_FILES:
        update(path, rf"^\s*{gtk_key}\s*=", f"{gtk_key}={name}", "[Settings]")
    if kind == "icons":
        for path in QT_FILES:
            update(path, r"^\s*icon_theme\s*=", f"icon_theme={name}", "[Appearance]")
    elif kind == "cursors":
        update(CURSOR_DEFAULT, r"^\s*Inherits\s*=", f"Inherits={name}", "[Icon Theme]")

    update(XSETTINGS, rf"^\s*{re.escape(xkey)}\s+", f'{xkey} "{name}"')
    warnings = []
    if os.environ.get("DISPLAY"):
        if not shutil.which("xsettingsd"):
            warnings.append("Install xsettingsd to apply changes to running GTK apps.")
        elif run("pgrep", "-u", str(os.getuid()), "-x", "xsettingsd").returncode == 0:
            if run("pkill", "-HUP", "-u", str(os.getuid()), "-x", "xsettingsd").returncode:
                warnings.append("Could not reload xsettingsd.")
        else:
            with open(os.devnull, "wb") as discard:
                subprocess.Popen(["xsettingsd", "-c", str(XSETTINGS)], stdin=subprocess.DEVNULL,
                                 stdout=discard, stderr=discard, start_new_session=True)
        if kind == "cursors":
            if not shutil.which("xrdb") or run("xrdb", "-merge", input=f"Xcursor.theme: {name}\n").returncode:
                warnings.append("Could not update the cursor theme in the current X session.")
    return warnings


def main(args):
    themes = installed_themes()
    warnings = []
    if args != ["list"]:
        if len(args) != 3 or args[0] != "set" or args[2] not in themes.get(args[1], []):
            raise ValueError("Choose an installed icon or cursor theme.")
        XSETTINGS.parent.mkdir(parents=True, exist_ok=True)
        with (XSETTINGS.parent / ".revenant-appearance.lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            warnings = apply(args[1], args[2])
    return {"themes": themes, "current": {kind: current(kind) for kind in KEYS}, "warnings": warnings}


if __name__ == "__main__":
    try:
        print(json.dumps(main(sys.argv[1:])))
    except (OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(json.dumps({"error": str(error)}))
        sys.exit(1)
