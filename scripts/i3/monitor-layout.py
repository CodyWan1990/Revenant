#!/usr/bin/env python3
"""Read and apply the current X11 display layout through RandR."""
import fcntl
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time


def xrandr(*args):
    return subprocess.run(["xrandr", *args], check=True, capture_output=True,
                          text=True, timeout=10).stdout


def read_outputs(report):
    outputs = []
    output = None
    for line in report.splitlines():
        header = re.match(r'^(\S+) (connected|disconnected)\b(.*)', line)
        if header:
            name, status, details = header.groups()
            output = None
            if status != "connected":
                continue
            geometry = re.search(r'\d+x\d+\+(-?\d+)\+(-?\d+)', details)
            rotation = re.search(r'\b(left|right|inverted)\b', details.split("(")[0])
            output = dict(name=name, enabled=bool(geometry), primary=" primary " in details,
                          x=int(geometry[1]) if geometry else 0, y=int(geometry[2]) if geometry else 0,
                          rotation=rotation[1] if rotation else "normal", mode="", rate="", modes={})
            outputs.append(output)
        elif output:
            mode = re.match(r'^\s+(\d+x\d+)\s+((?:\d+\.\d+\s*[*+]*\s*)+)$', line)
            if not mode:
                continue
            name, rates = mode.groups()
            options = output["modes"].setdefault(name, [])
            for rate, flags in re.findall(r"(\d+\.\d+)\s*([*+]*)", rates):
                if rate not in options:
                    options.append(rate)
                if "*" in flags:
                    output.update(mode=name, rate=rate)
            if not output["mode"] or (not output["enabled"] and "+" in rates):
                output.update(mode=name, rate=options[0])
    return outputs


def layout_args(current, draft):
    by_name = {output["name"]: output for output in current}
    if sorted(item["name"] for item in draft) != sorted(by_name):
        raise ValueError("Connected displays changed. Refresh the monitor list.")
    active = [item for item in draft if item["enabled"]]
    if not active:
        raise ValueError("Keep at least one monitor enabled.")
    origin_x = min(item["x"] for item in active)
    origin_y = min(item["y"] for item in active)
    primary = next((item for item in active if item["primary"]), active[0])
    args = []
    for item in draft:
        name = item["name"]
        args.extend(["--output", name])
        if not item["enabled"]:
            args.append("--off")
            continue
        rates = by_name[name]["modes"].get(item["mode"], [])
        if item["rate"] not in rates or item["rotation"] not in ("normal", "left", "right", "inverted"):
            raise ValueError(f"The selected mode or rotation is unavailable on {name}.")
        x, y = round(item["x"] - origin_x), round(item["y"] - origin_y)
        args.extend(["--mode", item["mode"], "--rate", item["rate"],
                     "--pos", f"{x}x{y}", "--rotate", item["rotation"]])
        if item is primary:
            args.append("--primary")
    return args


def apply_layout(current, draft):
    args = layout_args(current, draft)
    xrandr("--dryrun", *args)
    try:
        xrandr(*args)
    except subprocess.SubprocessError:
        xrandr(*layout_args(current, current))
        raise
    return read_outputs(xrandr("--query"))


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as stream:
        pending = Path(stream.name)
        try:
            json.dump(data, stream, indent=2)
            stream.flush()
            os.replace(pending, path)
        finally:
            pending.unlink(missing_ok=True)


def main(operation="read", path="", request=""):
    profile = Path(path)
    if operation == "restore" and not profile.is_file():
        return {}
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR") or profile.parent)
    display = re.sub(r"[^A-Za-z0-9_.-]", "_", os.environ.get("DISPLAY", "local"))
    transaction = runtime / f"{profile.parent.name}-monitors-{display}.json"
    runtime.mkdir(parents=True, exist_ok=True)
    with transaction.with_suffix(".lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        return update_layout(operation, profile, request, transaction)


def update_layout(operation, path, request, transaction):
    pending = json.loads(transaction.read_text()) if transaction.exists() else None
    if operation == "watchdog" and (not pending or pending["deadline"] != int(request)):
        return {}
    current = read_outputs(xrandr("--query"))
    if pending:
        expired = time.time() * 1000 >= pending["deadline"]
        if operation == "keep" and not expired and pending["deadline"] == int(request):
            transaction.unlink()
            return {"outputs": current, "status": "kept"}
        if expired or (operation == "revert" and pending["deadline"] == int(request)):
            previous = {output["name"]: output for output in pending["previous"]}
            rollback = [previous.get(output["name"], output) for output in current]
            try:
                current = apply_layout(current, rollback)
            finally:
                transaction.unlink()
            return {"outputs": current, "status": "reverted"}
        if operation in ("read", "restore"):
            return {"outputs": current, "deadline": pending["deadline"]}
        raise ValueError("Confirm or revert the pending monitor layout first.")
    if operation in ("keep", "revert"):
        return {"outputs": current, "status": "expired"}
    if operation == "save":
        layout_args(current, current)
        write_json(path, current)
    elif operation == "restore":
        profile = json.loads(Path(path).read_text())
        if {output["name"] for output in current} != {output["name"] for output in profile}:
            return {"skipped": "Connected monitors differ from the saved layout."}
        keys = ("enabled", "primary", "x", "y", "rotation", "mode", "rate")
        def layout(outputs):
            return {output["name"]: tuple(output[key] for key in keys) for output in outputs}
        if layout(current) != layout(profile):
            current = apply_layout(current, profile)
    elif operation == "apply":
        changes = json.loads(request)
        if current != changes["saved"]:
            raise ValueError("The live monitor layout changed. Refresh before applying.")
        draft = changes["draft"]
        layout_args(current, draft)
        deadline = int(time.time() * 1000) + 15_000
        write_json(transaction, {"deadline": deadline, "previous": current})
        try:
            subprocess.Popen([sys.executable, __file__, "watchdog", str(path), str(deadline)],
                             stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL, start_new_session=True)
        except OSError:
            transaction.unlink(missing_ok=True)
            raise
        current = apply_layout(current, draft)
        return {"outputs": current, "deadline": deadline}
    return {"outputs": current}


if __name__ == "__main__":
    try:
        if len(sys.argv) > 3 and sys.argv[1] == "watchdog":
            time.sleep(max(0, int(sys.argv[3]) / 1000 - time.time()))
        print(json.dumps(main(*sys.argv[1:])))
    except (ValueError, OSError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print(json.dumps({"error": (getattr(error, "stderr", None) or str(error)).strip()}))
        sys.exit(1)
