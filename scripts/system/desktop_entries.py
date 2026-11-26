"""Desktop-entry files: where they live, their ids, and line-preserving edits.

Shared by missing-tryexec.py and autostart.py. Edits keep every other line
(comments, translations, actions) as it was, which configparser would not.
"""
import os
from pathlib import Path
import shutil
import tempfile

GROUP = "[Desktop Entry]"


def data_dirs():
    """XDG data dirs in precedence order (the user's first)."""
    home = os.environ.get("XDG_DATA_HOME") or str(Path.home() / ".local/share")
    system = os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"
    return [home] + [d for d in system.split(":") if d]


def desktop_id(root, path):
    """The spec's desktop file id, as Quickshell's DesktopEntry.id spells it:
    the path under applications/ with "/" as "-", minus ".desktop"."""
    return str(path.relative_to(root))[: -len(".desktop")].replace("/", "-")


def applications():
    """{id: path} for every application entry; the first dir wins per id."""
    found = {}
    for base in data_dirs():
        root = Path(base) / "applications"
        if root.is_dir():
            for path in sorted(root.rglob("*.desktop")):
                found.setdefault(desktop_id(root, path), path)
    return found


def read_entry(path):
    """The [Desktop Entry] group's keys (first occurrence wins), or {}."""
    try:
        text = Path(path).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return {}
    keys = {}
    in_group = False
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("["):
            in_group = stripped == GROUP
        elif in_group and "=" in stripped and not stripped.startswith("#"):
            key, value = stripped.split("=", 1)
            keys.setdefault(key.strip(), value.strip())
    return keys


def entry_group(text):
    """Just the [Desktop Entry] group of a file, header included."""
    out = []
    in_group = False
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("["):
            in_group = stripped == GROUP
        if in_group:
            out.append(line)
    return "\n".join(out).rstrip("\n") + "\n"


def set_key(text, key, value):
    """Set (or with value None, remove) a key in the [Desktop Entry] group."""
    lines = text.splitlines()
    out = []
    in_group = False
    done = False
    insert_at = None
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("["):
            if in_group and not done:
                insert_at = len(out)
            in_group = stripped == GROUP
            out.append(line)
            continue
        if in_group and "=" in stripped and stripped.split("=", 1)[0].strip() == key:
            if not done and value is not None:
                out.append(f"{key}={value}")
            done = True
            continue
        out.append(line)
    if not done and value is not None:
        if insert_at is None:
            insert_at = len(out) if in_group else None
        if insert_at is None:
            raise ValueError("No [Desktop Entry] group in the file.")
        out.insert(insert_at, f"{key}={value}")
    return "\n".join(out) + "\n"


def write_atomically(path, contents):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent,
                                     prefix=".entry-", delete=False) as handle:
        temporary = Path(handle.name)
        try:
            handle.write(contents)
            handle.flush()
            temporary.chmod(0o644)
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)


def installed(program):
    """TryExec semantics: an absolute path must be executable; a bare name
    must be on PATH."""
    return shutil.which(os.path.expanduser(program)) is not None
