#!/usr/bin/env python3
"""X11 session settings: key repeat, screen blanking, DPMS, login volume.

Part of the shell (Settings → Keyboard, Screen & power, Autostart edit the
values through `set`). The shell runs `start` whenever it starts, the way a
desktop's settings daemon does, so nothing needs adding to a login file.
`login` is the same for a login script (~/.xprofile, ~/.xinitrc) that wants
the settings in place before the window manager draws anything.

    session.py get                 print the settings (and the live xset state)
    session.py set KEY=VALUE ...   validate, save, apply now
    session.py apply               apply the saved settings (xset)
    session.py start               apply; the login volume only the first time
                                   this session (restarting the shell keeps
                                   your volume)
    session.py login               apply, plus the login volume

Values live in ~/.config/<shell>/session.env (KEY=VALUE lines; per machine,
so keep them out of version control). A missing file or key falls back to
DEFAULTS. Output is JSON: {"values", "live"} or {"error"}.
"""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

# key: (default, minimum, maximum) for numbers; tuples of choices otherwise.
SPEC = {
    "KEY_REPEAT": ("on", ("on", "off")),
    "KEY_REPEAT_DELAY": (200, 100, 1000),   # ms before a held key repeats
    "KEY_REPEAT_RATE": (35, 5, 100),        # repeats per second
    "SCREEN_BLANK_MIN": (0, 0, 240),        # minutes idle before blanking; 0 = never
    "DPMS": ("off", ("on", "off")),         # monitor power saving
    "DPMS_STANDBY_MIN": (10, 1, 240),
    "DPMS_SUSPEND_MIN": (10, 1, 240),
    "DPMS_OFF_MIN": (10, 1, 240),
    "LOGIN_VOLUME": (-1, -1, 100),          # % at login; -1 = leave it alone (default)
}
DEFAULTS = {key: spec[0] for key, spec in SPEC.items()}
# The shell's directory: the nearest one up from here holding shell.qml.
ROOT = next(p for p in Path(__file__).resolve().parents if (p / "shell.qml").exists())


def config_file():
    # The shell's config dir: named after the directory this copy lives in
    # (scripts/.. = revenant), like services/Paths.qml's configDir.
    base = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    return base / ROOT.name / "session.env"


def validate(key, value):
    if key not in SPEC:
        raise ValueError(f"Unknown setting {key}.")
    spec = SPEC[key]
    if isinstance(spec[1], tuple):
        value = str(value).strip().lower()
        if value not in spec[1]:
            raise ValueError(f"{key} must be one of {', '.join(spec[1])}.")
        return value
    try:
        number = int(str(value).strip())
    except ValueError:
        raise ValueError(f"{key} must be a whole number.") from None
    if not spec[1] <= number <= spec[2]:
        raise ValueError(f"{key} must be between {spec[1]} and {spec[2]}.")
    return number


def load():
    values = dict(DEFAULTS)
    try:
        lines = config_file().read_text(encoding="utf-8").splitlines()
    except OSError:
        return values
    for line in lines:
        match = re.fullmatch(r"\s*([A-Z_]+)=(\S*)\s*", line)
        if match and match[1] in SPEC:
            try:
                values[match[1]] = validate(match[1], match[2])
            except ValueError:
                pass    # a bad hand edit falls back to the default
    try:
        check_order(values)
    except ValueError:
        for key in ("DPMS_STANDBY_MIN", "DPMS_SUSPEND_MIN", "DPMS_OFF_MIN"):
            values[key] = DEFAULTS[key]
    return values


def check_order(values):
    """X rejects DPMS times out of order ("illegal combination of values")."""
    if not values["DPMS_STANDBY_MIN"] <= values["DPMS_SUSPEND_MIN"] <= values["DPMS_OFF_MIN"]:
        raise ValueError("DPMS times must run standby ≤ suspend ≤ off.")


def save(values):
    path = config_file()
    path.parent.mkdir(parents=True, exist_ok=True)
    text = "# X11 session settings (session.py; edit in the shell's Settings).\n" + "".join(
        f"{key}={values[key]}\n" for key in SPEC)
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent,
                                     prefix=".session-", delete=False) as handle:
        temporary = Path(handle.name)
        try:
            handle.write(text)
            handle.flush()
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)


def xset(*args):
    subprocess.run(["xset", *map(str, args)], check=True, timeout=5,
                   stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)


def apply(values):
    if values["KEY_REPEAT"] == "on":
        xset("r", "on")
        xset("r", "rate", values["KEY_REPEAT_DELAY"], values["KEY_REPEAT_RATE"])
    else:
        xset("r", "off")
    if values["SCREEN_BLANK_MIN"] > 0:
        xset("s", values["SCREEN_BLANK_MIN"] * 60)
        xset("s", "blank")
    else:
        xset("s", "off")
        xset("s", "noblank")
    # Timeouts only while DPMS is on: `xset dpms <times>` also turns it on.
    if values["DPMS"] == "on":
        xset("+dpms")
        xset("dpms", *(values[k] * 60 for k in ("DPMS_STANDBY_MIN", "DPMS_SUSPEND_MIN", "DPMS_OFF_MIN")))
    else:
        xset("-dpms")


def login_volume(values):
    if values["LOGIN_VOLUME"] >= 0:
        # The sound server may still be starting this early; don't hold up login.
        subprocess.run(["pactl", "set-sink-volume", "@DEFAULT_SINK@", f"{values['LOGIN_VOLUME']}%"],
                       timeout=3, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def live():
    """What X is doing now, from `xset q` (best effort)."""
    try:
        text = subprocess.run(["xset", "q"], capture_output=True, text=True, timeout=5).stdout
    except (OSError, subprocess.TimeoutExpired):
        return {}
    out = {}
    if match := re.search(r"auto repeat delay:\s*(\d+)\s+repeat rate:\s*(\d+)", text):
        out["repeatDelay"], out["repeatRate"] = int(match[1]), int(match[2])
    if match := re.search(r"auto repeat:\s*(on|off)", text):
        out["repeat"] = match[1]
    if match := re.search(r"Screen Saver:.*?timeout:\s*(\d+)", text, re.S):
        out["blankSeconds"] = int(match[1])
    out["dpms"] = "on" if "DPMS is Enabled" in text else "off"
    return out


def volume_marker():
    """Set once the login volume was applied this session. XDG_RUNTIME_DIR is
    emptied at logout, so the next login sets it again."""
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    name = f"{ROOT.name}-login-volume-done"
    return Path(runtime) / name if runtime else Path(tempfile.gettempdir()) / f"{name}-{os.getuid()}"


def set_login_volume(values):
    try:
        login_volume(values)
    finally:
        try:
            volume_marker().touch()
        except OSError:
            pass


def main(action="get", *args):
    values = load()
    if action == "set":
        for pair in args:
            key, sep, value = pair.partition("=")
            if not sep:
                raise ValueError(f"Expected KEY=VALUE, got {pair!r}.")
            values[key] = validate(key, value)
        check_order(values)
        save(values)
        apply(values)
    elif action == "apply":
        apply(values)
    elif action == "login":
        try:
            apply(values)
        finally:
            set_login_volume(values)
    elif action == "start":
        try:
            apply(values)
        finally:
            if not volume_marker().exists():
                set_login_volume(values)
    elif action != "get":
        raise ValueError(f"Unknown action {action}.")
    return {"values": values, "live": live()}


if __name__ == "__main__":
    try:
        result = main(*sys.argv[1:])
    except (OSError, ValueError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        detail = getattr(error, "stderr", None)
        result = {"error": (detail.decode().strip() if isinstance(detail, bytes) and detail else str(error))}
    print(json.dumps(result))
