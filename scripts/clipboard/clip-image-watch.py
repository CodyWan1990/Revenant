#!/usr/bin/env python3
"""Keep a history of images copied to the CLIPBOARD (clipmenu 7 keeps text only).

Usage: clip-image-watch.py DIR [MAX]

Waits for XFixes "selection owner changed" events, so it costs nothing while
the clipboard is idle. When the new owner offers an image, the image is saved
as DIR/<epoch ms>-<hash>.<ext>, newest name = newest copy; copying the same
image again renames it to the front instead of storing a second file. Keeps
the newest MAX (default 40) and prints "changed" after each change, so
services/ClipImages.qml can re-list DIR.

DIR should be in $XDG_RUNTIME_DIR, like clipmenu's own store: per user, mode
0700, in RAM and gone at logout.
"""
import ctypes
import fcntl
import hashlib
import os
import signal
import subprocess
import sys
import time

try:
    from Xlib import display
    from Xlib.ext import xfixes
except ImportError:
    # Exit 3 = can't ever work here: ClipImages.qml stops restarting it.
    print("clip-image-watch: python-xlib is not installed (python3-xlib / python-xlib)",
          file=sys.stderr)
    sys.exit(3)

# Preferred first: PNG is lossless and what screenshot tools and browsers offer.
MIME_EXT = [("image/png", "png"), ("image/jpeg", "jpg"), ("image/webp", "webp"),
            ("image/gif", "gif"), ("image/bmp", "bmp")]
MAX_BYTES = 25 * 1024 * 1024


def xclip_out(target, timeout):
    return subprocess.run(["xclip", "-selection", "clipboard", "-o", "-t", target],
                          capture_output=True, timeout=timeout, check=True).stdout


def entries(store):
    return sorted((f for f in os.listdir(store) if not f.startswith(".")), reverse=True)


def save_clipboard_image(store, keep):
    try:
        targets = xclip_out("TARGETS", 2).decode(errors="replace").split()
    except (subprocess.SubprocessError, OSError):
        return False
    choice = next(((mime, ext) for mime, ext in MIME_EXT if mime in targets), None)
    if not choice:
        return False
    mime, ext = choice
    try:
        data = xclip_out(mime, 5)
    except (subprocess.SubprocessError, OSError):
        return False
    if not data or len(data) > MAX_BYTES:
        return False

    digest = hashlib.sha1(data).hexdigest()[:12]
    name = "%d-%s.%s" % (time.time() * 1000, digest, ext)
    existing = [f for f in entries(store) if f.split("-", 1)[-1].startswith(digest)]
    if existing:
        if existing[0] == entries(store)[0]:
            return False   # already the newest: re-copying it from the picker
        os.replace(os.path.join(store, existing[0]), os.path.join(store, name))
        for extra in existing[1:]:
            os.remove(os.path.join(store, extra))
    else:
        tmp = os.path.join(store, ".tmp-" + name)
        with open(tmp, "wb") as f:
            f.write(data)
        os.replace(tmp, os.path.join(store, name))
    for old in entries(store)[keep:]:
        os.remove(os.path.join(store, old))
    return True


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    store = sys.argv[1]
    keep = int(sys.argv[2]) if len(sys.argv) > 2 else 40
    os.makedirs(store, mode=0o700, exist_ok=True)

    # Die with the shell: a restarted shell starts a new watcher, and an
    # orphaned old one would keep racing it for the same files.
    libc = ctypes.CDLL(None, use_errno=True)
    libc.prctl(1, signal.SIGTERM)   # PR_SET_PDEATHSIG
    if os.getppid() == 1:
        sys.exit(0)   # the parent was already gone before prctl
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    # One watcher per store; a second waits until the first has exited.
    lock = open(os.path.join(store, ".lock"), "w")
    fcntl.flock(lock, fcntl.LOCK_EX)

    d = display.Display()
    if not d.has_extension("XFIXES"):
        sys.exit("clip-image-watch: the X server has no XFIXES")
    d.xfixes_query_version()
    clipboard = d.intern_atom("CLIPBOARD")
    d.xfixes_select_selection_input(d.screen().root, clipboard,
                                    xfixes.XFixesSetSelectionOwnerNotifyMask)
    d.flush()

    # Compare codes, not classes: python-xlib imports its extension modules a
    # second time internally, so isinstance() against ours is always False.
    owner_changed = d.extension_event.SetSelectionOwnerNotify   # (type, sub_code)
    print("ready", flush=True)
    while True:
        event = d.next_event()
        if (event.type, getattr(event, "sub_code", None)) != owner_changed:
            continue
        time.sleep(0.05)   # let the new owner finish setting up its targets
        if save_clipboard_image(store, keep):
            print("changed", flush=True)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
