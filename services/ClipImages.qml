pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "." as Services

/// Image clipboard history, beside clipmenu's text history (clipmenu 7 keeps
/// text only). scripts/clipboard/clip-image-watch.py waits for the CLIPBOARD owner to
/// change and saves offered images in `dir`; this re-lists `dir` when it says
/// "changed". Files are "<epoch ms>-<hash>.<ext>", so name order is age order.
///
/// `dir` is in Paths.runtimeDir, like clipmenu's store: per user, 0700, in RAM
/// and gone at logout. Not started under scripts/dev/run-qs-tests.sh (I3SHELL_TEST),
/// where it would record the real session's clipboard.
QtObject {
    id: root

    readonly property bool testing: !!Quickshell.env("I3SHELL_TEST")
    readonly property string dir: Services.Paths.runtimeDir
        + "/" + Services.Paths.shellName + "-clip-images"
    readonly property int limit: 40

    /// [{ path, time (ms since epoch), mime }], newest first.
    property var entries: []

    readonly property var mimes: ({ png: "image/png", jpg: "image/jpeg", webp: "image/webp",
        gif: "image/gif", bmp: "image/bmp" })

    function refresh() {
        if (internal.lister.running) internal.listAgain = true;
        else internal.lister.running = true;
    }

    /// Put an entry back on the clipboard. The watcher sees its own hash at
    /// the front and leaves the history alone, or moves an older one forward.
    function copy(entry) {
        // xclip forks to serve the selection; detached, so nothing waits on it.
        Quickshell.execDetached(["xclip", "-selection", "clipboard", "-t", entry.mime, "-i", entry.path]);
    }

    function remove(entry) {
        entries = entries.filter(e => e.path !== entry.path);
        Quickshell.execDetached(["rm", "-f", "--", entry.path]);
    }

    function clear() {
        entries = [];
        Quickshell.execDetached(["sh", "-c", 'rm -f -- "$1"/*', "sh", dir]);
    }

    readonly property QtObject internal: QtObject {
        id: internal
        property bool listAgain: false

        property Process watcher: Process {
            running: !root.testing
            command: ["python3", Services.Paths.script("clipboard/clip-image-watch.py"), root.dir, String(root.limit)]
            stdout: SplitParser {
                onRead: line => { if (line === "ready" || line === "changed") root.refresh(); }
            }
            stderr: SplitParser { onRead: line => console.warn("clip-image-watch:", line) }
            // A crash or a lost X connection: try again, not in a tight loop.
            // Exit 3 means python-xlib is missing: retrying can't help.
            onExited: code => {  // qmllint disable signal-handler-parameters
                if (code === 3) console.warn("ClipImages: image history is off until python-xlib is installed");
                else if (!root.testing) internal.restart.start();
            }
        }

        property Timer restart: Timer {
            interval: 5000
            onTriggered: internal.watcher.running = true
        }

        property Process lister: Process {
            command: ["sh", "-c", 'ls -1 -- "$1" 2>/dev/null', "sh", root.dir]
            stdout: StdioCollector {
                onStreamFinished: {
                    const out = [];
                    for (const name of this.text.split("\n")) {
                        const m = /^(\d+)-[0-9a-f]+\.(\w+)$/.exec(name);
                        if (m) out.push({ path: root.dir + "/" + name, time: Number(m[1]),
                            mime: root.mimes[m[2]] ?? "image/png" });
                    }
                    out.sort((a, b) => b.time - a.time);
                    root.entries = out;
                }
            }
            onExited: if (internal.listAgain) { internal.listAgain = false; running = true; }  // qmllint disable signal-handler-parameters
        }
    }
}
