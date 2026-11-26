#!/usr/bin/env python3
"""systemd service manager backend (Settings → System → Systemd).

    services.py list
    services.py create user|system <name> <start: 1|0> [args]
    services.py start|stop|restart user|system <unit>
    services.py enable|disable user|system <unit>  start automatically or not
    services.py log user|system <unit>           its last log lines
    services.py which <name>                     the program a new service would run
    services.py remove user|system <unit>        only services created here

`list` prints {"user": [...], "system": [...]}: per scope, the running
services and the stopped ones worth seeing (enabled but not running, failed,
or created here), as { unit, name (description), running, state (active,
inactive, failed, …), sub (running, exited, dead, …), enabled (enabled,
disabled, static, …), created, transient (started on the fly by an app),
essential (your session needs it), about (a plain explanation, or "") }.
Every action prints the new list, except log ({"log": text}) and which
({"which": path or ""}); errors print {"error": "..."}.

`create` makes <name>.service running the program <name> (found on PATH)
with the optional arguments, restarted if it fails, wanted by the scope's
default target; "start" enables it with --now, else only enables it. A user
service goes to ~/.config/systemd/user; a system one to /etc/systemd/system
through one pkexec call (one password prompt, answered by the shell's
polkit agent when it is the agent). System start/stop/restart go through
systemctl, which asks polkit itself.

Units created here carry MARKER as their first line; only those can be
removed from the page.
"""
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile

MARKER = "# Created in Revenant's Settings → Systemd"
NAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.@-]*")
# Services a session can't do without: stopping one, or switching off its
# start-at-boot, asks first. Matched on the unit name.
ESSENTIAL = re.compile(r"(dbus|dbus-broker|pipewire|pipewire-pulse|wireplumber|systemd-.*|NetworkManager|"
                       r"lightdm|gdm|sddm|polkit|user@.*|user-runtime-dir@.*|getty@.*|accounts-daemon|"
                       r"gnome-keyring-daemon|xdg-desktop-portal.*|xdg-document-portal|xdg-permission-store|"
                       r"at-spi-dbus-bus|upower|rtkit-daemon|udisks2|apparmor|snapd|ufw|lvm2-.*|"
                       r"cryptsetup.*|keyboard-setup|console-setup|kmod-static-nodes|wpa_supplicant|"
                       r"plymouth.*|chrony|gvfs-daemon|gcr-ssh-agent)\.service")

# One plain line about common services, for people who don't know them.
ABOUT = {
    "NetworkManager": "Wi-Fi, Ethernet and VPN connections.",
    "wpa_supplicant": "Logs in to Wi-Fi networks for NetworkManager.",
    "systemd-resolved": "Turns website names into addresses (DNS).",
    "bluetooth": "Bluetooth devices: headphones, mice, controllers.",
    "pipewire": "Sound and screen sharing for apps.",
    "pipewire-pulse": "Lets apps made for PulseAudio play sound through PipeWire.",
    "wireplumber": "Decides which speaker, headset or mic apps use.",
    "filter-chain": "PipeWire audio effects, such as noise reduction.",
    "lightdm": "The login screen.",
    "gdm": "The login screen.",
    "polkit": "Asks for your password when an app needs admin rights.",
    "accounts-daemon": "Tells the login screen which users exist.",
    "dbus": "Lets programs talk to each other. Almost everything needs it.",
    "dbus-broker": "Lets programs talk to each other. Almost everything needs it.",
    "upower": "Battery and power information.",
    "power-profiles-daemon": "Power modes: power saver, balanced, performance.",
    "udisks2": "Mounts USB drives and other disks.",
    "gvfs-daemon": "Lets the file manager show trash, phones and network folders.",
    "gvfs-metadata": "Remembers file manager details such as emblems and positions.",
    "gnome-keyring-daemon": "Keeps your saved passwords and keys unlocked while you're logged in.",
    "gcr-ssh-agent": "Holds your SSH keys so you type their passphrase once.",
    "xdg-desktop-portal": "Lets sandboxed apps (snaps, flatpaks) open files and share the screen.",
    "xdg-desktop-portal-gtk": "The file picker and dialogs sandboxed apps use.",
    "xdg-document-portal": "Gives sandboxed apps access to files you choose.",
    "xdg-permission-store": "Remembers what you allowed sandboxed apps to do.",
    "at-spi-dbus-bus": "Accessibility: screen readers and similar tools.",
    "mpris-proxy": "Lets Bluetooth headphones' play/pause buttons control your music.",
    "obex": "Sends and receives files over Bluetooth.",
    "snapd": "Installs and updates snap apps.",
    "ufw": "The firewall.",
    "ssh": "Lets other computers log in to this one over SSH.",
    "avahi-daemon": "Finds printers, speakers and other devices on your network.",
    "chrony": "Keeps the clock right.",
    "cron": "Runs scheduled jobs.",
    "anacron": "Runs daily and weekly jobs, even if the computer was off.",
    "rsyslog": "Writes system logs to /var/log as text files.",
    "systemd-journald": "Collects system logs.",
    "systemd-logind": "Tracks who's logged in; handles power button and sleep.",
    "systemd-oomd": "Stops runaway programs before the computer runs out of memory.",
    "systemd-udevd": "Detects hardware as you plug it in.",
    "fwupd": "Firmware updates for your devices.",
    "unattended-upgrades": "Installs security updates automatically.",
    "rtkit-daemon": "Gives sound apps priority so audio doesn't stutter.",
    "apparmor": "Security: limits what apps are allowed to touch.",
    "syncthing": "Syncs folders between your devices.",
    "gamemoded": "Speeds up your computer while a game is running.",
    "docker": "Runs containers.",
    "tailscale": "Private network between your devices.",
}

USER_DIR = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "systemd" / "user"
SYSTEM_DIR = Path("/etc/systemd/system")


def systemctl(scope, *args, check=True, timeout=30):
    argv = ["systemctl"] + (["--user"] if scope == "user" else []) + list(args)
    result = subprocess.run(argv, capture_output=True, text=True, timeout=timeout)
    if check and result.returncode:
        raise ValueError((result.stderr or result.stdout).strip().splitlines()[-1:][0]
                         if (result.stderr or result.stdout).strip() else "systemctl failed.")
    return result.stdout


def created(fragment):
    try:
        with open(fragment, encoding="utf-8") as handle:
            return handle.readline().strip() == MARKER
    except OSError:
        return False


def unit_names(output):
    return [line.split()[0] for line in output.splitlines() if line.strip()]


def services(scope):
    """Running services, plus stopped ones worth seeing: enabled but not
    running, failed, or created here (in any state)."""
    listed = ["--type=service", "--no-legend", "--plain", "--no-pager"]
    units = unit_names(systemctl(scope, "list-units", "--state=active,failed", *listed, check=False))
    units += [u for u in unit_names(systemctl(scope, "list-unit-files", "--state=enabled", *listed, check=False))
              if not u.endswith("@.service")]          # templates have no instance to run
    folder = USER_DIR if scope == "user" else SYSTEM_DIR
    units += [path.name for path in folder.glob("*.service") if created(path)]
    units = list(dict.fromkeys(units))
    if not units:
        return []
    shown = systemctl(scope, "show", "-p", "Id,Description,LoadState,ActiveState,SubState,UnitFileState,FragmentPath",
                      "--", *units, check=False)
    out = {}
    for block in shown.strip().split("\n\n"):
        keys = dict(line.split("=", 1) for line in block.splitlines() if "=" in line)
        unit = keys.get("Id", "")
        if not unit or keys.get("LoadState") != "loaded" or unit in out:
            continue
        state = keys.get("ActiveState", "")
        out[unit] = {"unit": unit, "name": keys.get("Description") or unit,
                     "running": state in ("active", "reloading", "activating"),
                     "state": state, "sub": keys.get("SubState", ""),
                     "enabled": keys.get("UnitFileState", ""),
                     "created": created(keys.get("FragmentPath", "")),
                     "transient": "/transient/" in keys.get("FragmentPath", "") or unit.startswith("run-"),
                     "essential": bool(ESSENTIAL.fullmatch(unit)),
                     "about": ABOUT.get(unit.removesuffix(".service"), "")}
    return sorted(out.values(), key=lambda e: e["name"].lower())


def listing():
    return {"user": services("user"), "system": services("system")}


def checked_scope(scope):
    if scope not in ("user", "system"):
        raise ValueError("The scope is user or system.")
    return scope


def checked_unit(unit):
    if not re.fullmatch(NAME.pattern + r"\.service", unit):
        raise ValueError("That is not a service name.")
    return unit


def create(scope, name, start, args=""):
    checked_scope(scope)
    name = name.strip().removesuffix(".service")
    if not NAME.fullmatch(name):
        raise ValueError("Use letters, digits, - _ . for the name.")
    program = shutil.which(name)
    if program is None:
        raise ValueError(f"There's no program called {name} on your PATH.")
    try:
        extra = shlex.split(args)
    except ValueError as error:
        raise ValueError(f"The arguments don't parse: {error}.") from None
    unit = name + ".service"
    target = (USER_DIR if scope == "user" else SYSTEM_DIR) / unit
    if target.exists():
        raise ValueError(f"{unit} already exists.")
    text = "\n".join([
        MARKER,
        "[Unit]",
        f"Description={name}",
        "",
        "[Service]",
        "ExecStart=" + shlex.join([program] + extra),
        "Restart=on-failure",
        "",
        "[Install]",
        "WantedBy=" + ("default.target" if scope == "user" else "multi-user.target"),
        "",
    ])
    enable = ["enable", "--now", unit] if start == "1" else ["enable", unit]
    if scope == "user":
        USER_DIR.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")
        try:
            systemctl("user", "daemon-reload")
            systemctl("user", *enable)
        except ValueError:
            target.unlink(missing_ok=True)
            systemctl("user", "daemon-reload", check=False)
            raise
        return
    # System: write a temp file, then one pkexec does install + reload + enable.
    with tempfile.NamedTemporaryFile("w", suffix=".service", delete=False) as handle:
        handle.write(text)
        staged = handle.name
    try:
        result = subprocess.run(
            ["pkexec", "sh", "-c",
             'install -m 644 "$1" "$2" && systemctl daemon-reload && systemctl "$3" ${4:+"$4"} "$5"',
             "sh", staged, str(target), enable[0], enable[1] if len(enable) == 3 else "", unit],
            capture_output=True, text=True, timeout=300)
    finally:
        os.unlink(staged)
    if result.returncode:
        raise ValueError("Not created: " + (result.stderr.strip().splitlines()[-1:] or ["authentication was cancelled"])[0])


def remove(scope, unit):
    checked_scope(scope)
    checked_unit(unit)
    path = (USER_DIR if scope == "user" else SYSTEM_DIR) / unit
    if not created(path):
        raise ValueError("Only services created here can be removed here.")
    if scope == "user":
        systemctl("user", "disable", "--now", unit, check=False)
        path.unlink(missing_ok=True)
        systemctl("user", "daemon-reload")
        return
    result = subprocess.run(
        ["pkexec", "sh", "-c", 'systemctl disable --now "$1"; rm -f -- "$2" && systemctl daemon-reload',
         "sh", unit, str(path)], capture_output=True, text=True, timeout=300)
    if result.returncode:
        raise ValueError("Not removed: " + (result.stderr.strip().splitlines()[-1:] or ["authentication was cancelled"])[0])


def log(scope, unit):
    argv = ["journalctl", "--user-unit" if scope == "user" else "--unit", unit,
            "-n", "15", "--no-pager", "-o", "short", "--quiet"]
    result = subprocess.run(argv, capture_output=True, text=True, timeout=15)
    text = result.stdout.strip()
    if not text and scope == "system":
        return "Nothing to show. Reading system logs needs your account in the adm group."
    return text or "Nothing logged yet."


def main(action="list", *args):
    if action == "create":
        create(*args)
    elif action in ("start", "stop", "restart", "enable", "disable"):
        scope, unit = args
        systemctl(checked_scope(scope), action, checked_unit(unit))
    elif action == "log":
        scope, unit = args
        return {"log": log(checked_scope(scope), checked_unit(unit))}
    elif action == "which":
        name = args[0].strip().removesuffix(".service") if args else ""
        return {"which": (shutil.which(name) or "") if NAME.fullmatch(name) else ""}
    elif action == "remove":
        remove(*args)
    elif action != "list":
        raise ValueError("Unknown action.")
    return listing()


if __name__ == "__main__":
    try:
        result = main(*sys.argv[1:])
    except (OSError, ValueError, TypeError, subprocess.TimeoutExpired) as error:
        result = {"error": str(error)}
    print(json.dumps(result, ensure_ascii=False))
