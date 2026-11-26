"""IPC, locking and validated config writes shared by the i3 settings editors."""
from contextlib import contextmanager
import fcntl
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

INCLUDE_LINE = re.compile(r"^([ \t]*include[ \t]+)(\S+)[ \t]*$", re.M)


class NotSetUp(ValueError):
    """The running config includes no such module yet (the page offers Set up)."""


def ipc(*args):
    result = subprocess.run(["i3-msg", "-r", *args], capture_output=True, text=True, timeout=5)
    if result.returncode:
        raise ValueError(result.stderr.strip() or result.stdout.strip() or "Could not contact i3.")
    return json.loads(result.stdout)


def main_config():
    """The config file the running i3 loaded; if i3 can't be asked, the first
    of the standard locations that exists."""
    try:
        return Path(ipc("-t", "get_config")["included_configs"][0]["path"]).resolve(strict=True)
    except (ValueError, OSError, KeyError, IndexError, subprocess.TimeoutExpired):
        pass
    xdg = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    for candidate in (xdg / "i3" / "config", Path.home() / ".i3" / "config"):
        if candidate.is_file():
            return candidate.resolve()
    raise ValueError("No i3 config found.")


def loaded_module(name):
    """(main config, module) for the included file called `name`, wherever the
    user keeps their i3 config (~/.config/i3, ~/.i3, -c …)."""
    included = ipc("-t", "get_config")["included_configs"]
    main = Path(included[0]["path"]).resolve(strict=True)
    found = {Path(entry["path"]).resolve() for entry in included[1:] if Path(entry["path"]).name == name}
    if not found:
        raise NotSetUp(f"Your i3 config doesn't include a {name} yet. Set up adds one.")
    if len(found) > 1:
        raise ValueError(f"Your i3 config includes more than one {name}; keep one.")
    return main, found.pop()


def expand_include(raw, base):
    """An include argument as a Path: ~ and $HOME expanded, relative paths
    taken from the including file's directory. May still contain a glob."""
    raw = re.sub(r"^~(?=/|$)", str(Path.home()), raw.strip("\"'"))
    raw = raw.replace("${HOME}", str(Path.home())).replace("$HOME", str(Path.home()))
    path = Path(raw)
    return path if path.is_absolute() else base / path


def find_include(source, base, target):
    """The one include line in `source` that points at `target`: a file, or a
    glob such as dir/keys/*.config (matched as a pattern, not expanded)."""
    def same(path):
        if any(char in target.name for char in "*?["):
            return path.name == target.name and path.parent.resolve() == target.parent.resolve()
        return path.exists() and path.resolve() == target.resolve()
    hits = [match for match in INCLUDE_LINE.finditer(source) if same(expand_include(match[2], base))]
    if len(hits) != 1:
        raise ValueError(f"Expected one include of {target.name}, found {len(hits)}.")
    return hits[0]


def substitute_include(source, base, target, replacement):
    """`source` with the include of `target` pointing at `replacement` instead
    (to validate a staged copy with i3 -C)."""
    match = find_include(source, base, target)
    return source[:match.start()] + match[1] + str(replacement) + source[match.end():]


def display_path(path):
    """~/… for paths under the home dir, as people write them in i3 configs."""
    try:
        return "~/" + str(Path(path).relative_to(Path.home()))
    except ValueError:
        return str(path)


def setup_module(name, files):
    """Create the module `name` and include it from the main config, validated
    with i3 -C and reloaded. `files(modules_dir)` returns {path relative to
    modules_dir: text} for the module and anything it needs; modules_dir is
    modules/ beside the main config. Existing files are kept; files created
    here are removed again if i3 rejects the result."""
    included = ipc("-t", "get_config")["included_configs"]
    main = Path(included[0]["path"]).resolve(strict=True)
    if any(Path(entry["path"]).name == name for entry in included[1:]):
        return main
    modules = main.parent / "modules"
    created = []
    try:
        for relative, text in files(modules).items():
            path = modules / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            if not path.exists():
                path.write_text(text)
                created.append(path)
        original = main.read_text()
        updated = original + ("" if original.endswith("\n") else "\n") \
            + f"\n# Added by Revenant's Settings\ninclude {display_path(modules / name)}\n"
        with config_lock(main, True):
            with tempfile.TemporaryDirectory(prefix="i3-setup-") as staging:
                staged = Path(staging) / "config"
                staged.write_text(updated)
                validate_config(staged, main.parent)
            replace_and_reload(main, original, updated)
    except Exception:
        for path in created:
            path.unlink(missing_ok=True)
            # …and the folders made for it, if now empty.
            for folder in path.parents:
                if folder == main.parent:
                    break
                try:
                    folder.rmdir()
                except OSError:
                    break
        raise
    return main


@contextmanager
def config_lock(main, editing):
    # Neither editor replaces the top-level file, so both lock the same inode.
    with main.open() as handle:
        fcntl.flock(handle, (fcntl.LOCK_EX if editing else fcntl.LOCK_SH) | fcntl.LOCK_NB)
        yield


def validate_config(staged_main, directory):
    check = subprocess.run(["i3", "-C", "-c", str(staged_main)], cwd=directory,
                           capture_output=True, text=True, timeout=10)
    if check.returncode:
        messages = (check.stderr + "\n" + check.stdout).strip().splitlines()
        detail = next((line for line in messages if "Duplicate keybinding" in line),
                      next(iter(messages), "Check the i3 configuration."))
        raise ValueError("i3 rejected the change. " + detail)


def write_atomically(path, contents):
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent,
                                     prefix=".keys-", delete=False) as handle:
        temporary = Path(handle.name)
        try:
            handle.write(contents)
            handle.flush()
            temporary.chmod(path.stat().st_mode & 0o777)
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)


def command(command_text):
    replies = ipc(command_text)
    if not replies or not all(reply.get("success") for reply in replies):
        raise ValueError("i3 declined the command.")


def replace_and_reload(path, original, updated):
    destination = path.resolve(strict=True)
    if destination.read_text() != original:
        raise ValueError("The config file changed during validation. Refresh and retry.")
    write_atomically(destination, updated)
    try:
        command("reload")
    except (ValueError, OSError, subprocess.TimeoutExpired):
        if destination.read_text() == updated:
            write_atomically(destination, original)
        raise ValueError("Could not reload i3. The original config was restored.") from None
