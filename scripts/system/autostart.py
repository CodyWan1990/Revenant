#!/usr/bin/env python3
"""Autostart manager backend (Settings → Autostart): everything that starts
with the session, from three sources.

  xdg      Login items: ~/.config/autostart over /etc/xdg/autostart, run by
           `dex --autostart --environment i3` (dex's rules are followed:
           user file overrides system, Hidden=, OnlyShowIn/NotShowIn, TryExec).
  i3       `exec` / `exec_always` lines in the main i3 config.
  systemd  User services (`systemctl --user`), enabled or disabled.

    autostart.py list
    autostart.py enable|disable <id>
    autostart.py run <id>                       start it now
    autostart.py edit <id> <name> <command> [delay-seconds]
    autostart.py force <id>                     xdg: run it under i3 anyway
    autostart.py remove <id>                    xdg: delete yours / reset a system one
    autostart.py start|stop|restart <id>        systemd
    autostart.py add-app <desktop-id> | add-custom <name> <command>

Every action prints {"entries": [...]} or {"error": "..."}. An entry:
  id, source, name, command, enabled, running (true/false/null = unknown),
  runsHere (false = dex skips it under i3) + reason, origin, editable,
  removable, forcible, delay, note (e.g. "Starts this shell"), essential.

Commands we write (custom, edited, delayed) are stored base64-encoded and run
as `sh -c "echo <b64> | base64 -d | sh"`, because dex's Exec parser mishandles
quotes and "%%"; the readable command is kept in X-I3shell-Command.
"""
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile

# i3_config (lock, i3 -C check, atomic write) lives with the i3 editors.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "i3"))
import i3_config as i3_config_module  # noqa: E402
from desktop_entries import applications, entry_group, installed, read_entry, set_key, write_atomically

ENVIRONMENT = "i3"
COMMAND_KEY = "X-I3shell-Command"
DELAY_KEY = "X-I3shell-Delay"
I3_DISABLED = "# Disabled autostart: "
I3_LABEL = "# Autostart: "
I3_EXEC = re.compile(r"^(\s*)((?:" + re.escape(I3_DISABLED) + r")?)(exec_always|exec)((?:\s+--no-startup-id)?)\s+(.+?)\s*$")
# User services whose loss breaks the session (sound, D-Bus, keyring, SSH).
ESSENTIAL = {"dbus-broker.service", "dbus.service", "pipewire.service", "pipewire-pulse.service",
             "wireplumber.service", "gnome-keyring-daemon.service", "gcr-ssh-agent.service",
             "xdg-desktop-portal.service", "xdg-permission-store.service"}
# Session plumbing nobody toggles by hand: kept off the main list (with the
# essential ones) so it shows what *you* start. Matched on the unit name.
PLUMBING = re.compile(r"(snap\.|xdg-|systemd-|dbus|at-spi|gvfs|evolution-|tracker|filter-chain|"
                      r"pipewire|wireplumber|gnome-|gcr-|ibus|obex|mpris-proxy|dirmngr|gpg-agent|"
                      r"p11-kit|speech-dispatcher|ssh-agent|user-session-migration|org\.freedesktop\.)")

# Login items that are session plumbing (matched on the desktop file name).
XDG_PLUMBING = re.compile(r"(at-spi|gnome-keyring|geoclue|localsearch|tracker|snap-userd|user-dirs|"
                          r"xdg-user-dirs|polkit|update-notifier|ubuntu-advantage|ibus|org\.gnome\.SettingsDaemon|"
                          r"gsettings|spice-vdagent|pulseaudio|print-applet)")


# ─── helpers ───

def run(*args, check=True, timeout=10):
    result = subprocess.run(list(args), capture_output=True, text=True, timeout=timeout)
    if check and result.returncode:
        message = (result.stderr or result.stdout).strip().splitlines()
        raise ValueError(message[-1] if message else f"{args[0]} failed.")
    return result.stdout


def escape(value):
    """Desktop-entry string escapes for a single-line value we write."""
    if any(char in value for char in "\n\r\0"):
        raise ValueError("Use a single-line command.")
    return value.replace("\\", "\\\\")


def unescape(value):
    return re.sub(r"\\(.)", lambda m: {"s": " ", "n": "\n", "t": "\t", "r": "\r"}.get(m[1], m[1]), value)


def exec_argv(value):
    """A desktop Exec value as argv: quoted args, escapes, field codes dropped."""
    value = unescape(value)
    argv, current, quoted, have = [], "", False, False
    i = 0
    while i < len(value):
        char = value[i]
        if quoted:
            if char == "\\" and i + 1 < len(value) and value[i + 1] in '"`$\\':
                current += value[i + 1]
                i += 1
            elif char == '"':
                quoted = False
            else:
                current += char
        elif char == '"':
            quoted, have = True, True
        elif char.isspace():
            if have or current:
                argv.append(current)
            current, have = "", False
        else:
            current += char
        i += 1
    if have or current:
        argv.append(current)
    out = []
    for arg in argv:
        if re.fullmatch(r"%[fFuUdDnNickvm]", arg):
            continue
        out.append(re.sub(r"%%", "%", re.sub(r"%[fFuUdDnNickvm]", "", arg)))
    return out


def wrapped(command, delay):
    """An Exec dex runs correctly whatever the command contains."""
    script = (f"sleep {int(delay)}; " if delay else "") + command
    return 'sh -c "echo ' + base64.b64encode(script.encode()).decode() + ' | base64 -d | sh"'


_processes = None
def processes():
    """[(comm, args)] of everything running, read once per action."""
    global _processes
    if _processes is None:
        comms = dict(line.split(None, 1) for line in run("ps", "-eo", "pid=,comm=", check=False).splitlines()
                     if len(line.split(None, 1)) == 2)
        args = dict(line.split(None, 1) for line in run("ps", "-eo", "pid=,args=", check=False).splitlines()
                    if len(line.split(None, 1)) == 2)
        _processes = [(comms[pid].strip(), args.get(pid, "").strip()) for pid in comms]
    return _processes


def is_running(command):
    """Best effort: is the command's program running? None if we can't tell."""
    try:
        argv = shlex.split(command)
    except ValueError:
        return None
    while argv and (argv[0] == "env" or "=" in argv[0]):
        argv = argv[1:]
    if not argv or os.path.basename(argv[0]) in ("sh", "bash", "dash"):
        return None
    program = os.path.basename(argv[0])
    for comm, args in processes():
        first = args.split(" ", 1)[0]
        if comm == program[:15] or os.path.basename(first) == program:
            return True
    return False


# ─── xdg login items ───

def user_dir():
    return Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "autostart"


def system_dirs():
    dirs = os.environ.get("XDG_CONFIG_DIRS") or "/etc/xdg"
    return [Path(d) / "autostart" for d in dirs.split(":") if d]


def system_file(name):
    for directory in system_dirs():
        path = directory / f"{name}.desktop"
        if path.is_file():
            return path
    return None


def as_list(value):
    return [item for item in (value or "").split(";") if item]


def why_not_here(keys):
    only, never = as_list(keys.get("OnlyShowIn")), as_list(keys.get("NotShowIn"))
    if only and ENVIRONMENT not in only:
        return "Only for " + ", ".join(only)
    if ENVIRONMENT in never:
        return "Not for i3"
    if keys.get("TryExec") and not installed(keys["TryExec"].strip()):
        return "Program not installed: " + keys["TryExec"].strip()
    # No TryExec: dex runs it anyway and it fails at every login (it shows in
    # ~/.xsession-errors). Our own commands are `sh -c …`, always present.
    argv = exec_argv(keys.get("Exec", ""))
    if argv and not installed(argv[0]):
        return "Program not installed: " + argv[0]
    return ""


def linked_message(path):
    """A symlinked entry is managed where it points (a dotfiles repo, a package):
    changing the link here would be lost, or would edit that file behind its back."""
    return f"This entry is a link to {path.resolve()}; change it there."


def xdg_entries():
    found = {}
    if user_dir().is_dir():
        for path in sorted(user_dir().glob("*.desktop")):
            origin = "linked" if path.is_symlink() else "override" if system_file(path.stem) else "user"
            found[path.stem] = (path, origin)
    for directory in system_dirs():
        if directory.is_dir():
            for path in sorted(directory.glob("*.desktop")):
                found.setdefault(path.stem, (path, "system"))
    out = []
    for name, (path, origin) in found.items():
        keys = read_entry(path)
        # dex reads only your file. A bare off switch (no Exec) still shows
        # the system entry's command and details under it.
        if origin == "override" and "Exec" not in keys:
            keys = {**read_entry(system_file(name)), **keys}
        if keys.get("Type", "Application") != "Application":
            continue
        reason = why_not_here(keys)
        custom = COMMAND_KEY in keys
        command = unescape(keys[COMMAND_KEY]) if custom else shlex.join(exec_argv(keys.get("Exec", "")))
        out.append({
            "id": "xdg:" + name, "source": "xdg", "name": keys.get("Name") or name,
            "comment": keys.get("Comment", ""), "icon": keys.get("Icon", ""), "command": command,
            "enabled": keys.get("Hidden", "").lower() != "true", "runsHere": not reason, "reason": reason,
            "running": is_running(command) if command else None,
            "origin": origin, "editable": origin != "linked",
            "removable": origin in ("user", "override"),
            "forcible": bool(reason) and not reason.startswith("Program not installed") and origin != "linked",
            "delay": int(keys.get(DELAY_KEY, "0") or 0), "note": "", "essential": False,
            # System login items that are session plumbing, not apps you chose.
            "plumbing": origin == "system" and bool(XDG_PLUMBING.match(name)),
            "file": str(path),
        })
    return out


def xdg_target(name):
    if not re.fullmatch(r"[A-Za-z0-9_.+@-]+", name):
        raise ValueError("That is not an autostart entry id.")
    return user_dir() / f"{name}.desktop"


def xdg_current_text(name):
    path = xdg_target(name)
    if path.exists():
        if path.is_symlink():
            raise ValueError(linked_message(path))
        text = path.read_text(encoding="utf-8")
        # Only an off switch over a system entry: start from the full entry.
        if system_file(name) and "Exec" not in read_entry(path):
            full = entry_group(system_file(name).read_text(encoding="utf-8"))
            return set_key(full, "Hidden", read_entry(path).get("Hidden"))
        return text
    system = system_file(name)
    if not system:
        raise ValueError("That autostart entry no longer exists.")
    return entry_group(system.read_text(encoding="utf-8"))


def minimal_override(name):
    keys = read_entry(system_file(name))
    return f"[Desktop Entry]\nType=Application\nName={escape(keys.get('Name', name))}\nHidden=true\n"


def xdg_set_enabled(name, enabled):
    path, system = xdg_target(name), system_file(name)
    if path.exists():
        if path.is_symlink():
            raise ValueError(linked_message(path))
        current = path.read_text(encoding="utf-8")
        if enabled and system and current == minimal_override(name):
            path.unlink()   # our own off switch: back to the system default
            return
        write_atomically(path, set_key(current, "Hidden", None if enabled else "true"))
    elif system:
        if not enabled:
            write_atomically(path, minimal_override(name))
    else:
        raise ValueError("That autostart entry no longer exists.")


def xdg_edit(name, label, command, delay="0"):
    label, command = label.strip(), command.strip()
    if not label or not command:
        raise ValueError("Enter a name and a command.")
    delay = int(delay or 0)
    if not 0 <= delay <= 600:
        raise ValueError("The delay must be 0–600 seconds.")
    text = xdg_current_text(name)
    text = set_key(text, "Name", escape(label))
    text = set_key(text, "Exec", wrapped(command, delay))
    text = set_key(text, COMMAND_KEY, escape(command))
    text = set_key(text, DELAY_KEY, str(delay) if delay else None)
    text = set_key(text, "TryExec", None)
    write_atomically(xdg_target(name), text)


def xdg_force(name):
    text = xdg_current_text(name)
    for key in ("OnlyShowIn", "NotShowIn"):
        text = set_key(text, key, None)
    write_atomically(xdg_target(name), text)


def xdg_remove(name):
    path = xdg_target(name)
    if not path.exists():
        raise ValueError("Only your own entries can be removed; turn system ones off instead.")
    if path.is_symlink():
        raise ValueError(linked_message(path))
    path.unlink()


def xdg_add_app(app_id):
    path = xdg_target(app_id)
    if path.exists() and read_entry(path).get("Hidden", "").lower() != "true":
        raise ValueError("That app already starts at login.")
    source = applications().get(app_id)
    if source is None:
        raise ValueError("That app is no longer installed.")
    text = entry_group(source.read_text(encoding="utf-8"))
    for key in ("Hidden", "OnlyShowIn", "NotShowIn", "NoDisplay", "X-GNOME-Autostart-enabled"):
        text = set_key(text, key, None)
    write_atomically(path, text)


def xdg_add_custom(label, command):
    slug = re.sub(r"[^a-z0-9]+", "-", label.lower()).strip("-") or "command"
    name, n = f"custom-{slug}", 2
    while xdg_target(name).exists():
        name, n = f"custom-{slug}-{n}", n + 1
    if not label.strip() or not command.strip():
        raise ValueError("Enter a name and a command.")
    write_atomically(xdg_target(name), "[Desktop Entry]\nType=Application\nName=x\nExec=true\n")
    try:
        xdg_edit(name, label, command, 0)
    except ValueError:
        xdg_target(name).unlink(missing_ok=True)
        raise
    return xdg_target(name)


# ─── i3 exec lines ───

def i3_config():
    # The file the running i3 loaded (~/.config/i3, ~/.i3, -c …).
    return i3_config_module.main_config()


def i3_id(index, line):
    return "i3:" + str(index) + ":" + hashlib.sha1(line.encode()).hexdigest()[:8]


def i3_entries():
    try:
        path = i3_config()
    except ValueError:
        return []
    lines = path.read_text(encoding="utf-8").splitlines()
    out = []
    for index, line in enumerate(lines):
        match = I3_EXEC.match(line)
        if not match:
            continue
        command = match[5]
        label = lines[index - 1][len(I3_LABEL):].strip() if index and lines[index - 1].startswith(I3_LABEL) else ""
        note = ("Starts this shell" if re.search(r"\bqs\s+-c\b", command)
                else "Starts your Login items" if "dex" in command and "--autostart" in command else "")
        try:
            argv = shlex.split(command)
        except ValueError:
            argv = command.split()
        auto = note.replace("Starts ", "").capitalize() if note else os.path.basename(argv[0]) if argv else command
        out.append({
            "id": i3_id(index, line), "source": "i3", "name": label or auto,
            "comment": match[3] + (" (also on restart)" if match[3] == "exec_always" else ""),
            "icon": "", "command": command, "enabled": not match[2], "runsHere": True, "reason": "",
            "running": is_running(command), "origin": "i3 config", "editable": True, "removable": False,
            "forcible": False, "delay": 0, "note": note, "essential": bool(note), "file": str(path),
        })
    return out


def i3_change(entry_id, change):
    """Apply change(lines, index) to the i3 config, after checking the line is
    still the one listed, once `i3 -C` accepts the result. No reload: exec
    lines only run at login (exec_always also on restart)."""
    _, index, digest = entry_id.split(":")
    index = int(index)
    path = i3_config()
    original = path.read_text(encoding="utf-8")
    lines = original.splitlines()
    if index >= len(lines) or i3_id(index, lines[index]) != entry_id:
        raise ValueError("The i3 config changed. Refresh and try again.")
    change(lines, index)
    updated = "\n".join(lines) + ("\n" if original.endswith("\n") else "")
    # The same lock and i3 -C check as the Keybinds and i3 Options editors,
    # so two Settings pages can't write the main config at once.
    with i3_config_module.config_lock(path, True):
        with tempfile.TemporaryDirectory(prefix="autostart-check-") as staging:
            staged = Path(staging) / "config"
            staged.write_text(updated, encoding="utf-8")
            i3_config_module.validate_config(staged, path.parent)
        if path.read_text(encoding="utf-8") != original:
            raise ValueError("The i3 config changed meanwhile. Refresh and try again.")
        i3_config_module.write_atomically(path, updated)


def i3_set_enabled(entry_id, enabled):
    def change(lines, index):
        match = I3_EXEC.match(lines[index])
        lines[index] = match[1] + ("" if enabled else I3_DISABLED) + match[3] + match[4] + " " + match[5]
    i3_change(entry_id, change)


def i3_edit(entry_id, label, command, _delay="0"):
    command, label = command.strip(), label.strip()
    if not command or "\n" in command:
        raise ValueError("Enter a single-line command.")

    def change(lines, index):
        match = I3_EXEC.match(lines[index])
        lines[index] = match[1] + match[2] + match[3] + match[4] + " " + command
        has_label = index > 0 and lines[index - 1].startswith(I3_LABEL)
        if label and has_label:
            lines[index - 1] = I3_LABEL + label
        elif label:
            lines.insert(index, I3_LABEL + label)
        elif has_label:
            del lines[index - 1]
    i3_change(entry_id, change)


# ─── systemd user services ───

def systemd_entries():
    try:
        files = run("systemctl", "--user", "list-unit-files", "--type=service", "--no-legend", "--no-pager")
    except (ValueError, OSError):
        return []
    units = []
    for line in files.splitlines():
        fields = line.split()
        if len(fields) >= 2 and fields[1] in ("enabled", "disabled") and "@" not in fields[0]:
            units.append(fields[0])
    if not units:
        return []
    props = run("systemctl", "--user", "show", "-p", "Id,Description,ActiveState,UnitFileState,FragmentPath",
                "--", *units, check=False)
    out = []
    for block in props.strip().split("\n\n"):
        keys = dict(line.split("=", 1) for line in block.splitlines() if "=" in line)
        unit = keys.get("Id", "")
        if not unit:
            continue
        fragment = keys.get("FragmentPath", "")
        out.append({
            "id": "systemd:" + unit, "source": "systemd", "name": keys.get("Description") or unit,
            "comment": unit, "icon": "", "command": unit, "enabled": keys.get("UnitFileState") == "enabled",
            "runsHere": True, "reason": "", "running": keys.get("ActiveState") == "active",
            "origin": "user" if fragment.startswith(str(Path.home())) else "system",
            "editable": False, "removable": False, "forcible": False, "delay": 0,
            "note": "Needed by your session" if unit in ESSENTIAL else "", "essential": unit in ESSENTIAL,
            "plumbing": unit in ESSENTIAL or bool(PLUMBING.match(unit)),
            "file": fragment,
        })
    return out


def systemd(action, unit, *flags):
    if not re.fullmatch(r"[A-Za-z0-9_.:\\-]+\.service", unit):
        raise ValueError("That is not a service name.")
    run("systemctl", "--user", action, *flags, unit, timeout=30)


# ─── dispatch ───

def entries():
    return xdg_entries() + i3_entries() + systemd_entries()


def find(entry_id):
    for entry in entries():
        if entry["id"] == entry_id:
            return entry
    raise ValueError("That autostart entry no longer exists.")


def listing():
    # dex runs the login items; without it they're listed but never start.
    return {"entries": entries(), "dex": shutil.which("dex") is not None}


def main(action="list", *args):
    global _processes
    if action == "list":
        return listing()
    if action == "add-app":
        xdg_add_app(*args)
    elif action == "add-custom":
        xdg_add_custom(*args)
    else:
        entry_id = args[0]
        source, _, key = entry_id.partition(":")
        if source not in ("xdg", "i3", "systemd"):
            raise ValueError("That is not an autostart entry id.")
        if action in ("enable", "disable"):
            on = action == "enable"
            if source == "xdg":
                xdg_set_enabled(key, on)
            elif source == "i3":
                i3_set_enabled(entry_id, on)
            else:
                # A service's switch means on or off, now and at login.
                systemd(action, key, "--now")
        elif action == "run":
            entry = find(entry_id)
            if source == "systemd":
                systemd("start", key)
            else:
                argv = ["dex", entry["file"]] if source == "xdg" else ["sh", "-c", entry["command"]]
                subprocess.Popen(argv, start_new_session=True,
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        elif action in ("start", "stop", "restart") and source == "systemd":
            systemd(action, key)
        elif action == "edit" and source == "xdg":
            xdg_edit(key, *args[1:4])
        elif action == "edit" and source == "i3":
            i3_edit(entry_id, *args[1:4])
        elif action == "force" and source == "xdg":
            xdg_force(key)
        elif action == "remove" and source == "xdg":
            xdg_remove(key)
        else:
            raise ValueError(f"Can't {action} that entry.")
    _processes = None
    return listing()


if __name__ == "__main__":
    try:
        result = main(*sys.argv[1:])
    except BlockingIOError:
        result = {"error": "Another i3 settings change is in progress. Try again in a moment."}
    except (OSError, ValueError, TypeError, IndexError, KeyError, subprocess.TimeoutExpired) as error:
        result = {"error": str(error)}
    print(json.dumps(result, ensure_ascii=False))
