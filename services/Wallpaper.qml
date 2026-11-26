pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell.Io
import "." as Services
import "../lib" as Lib

/// The desktop wallpaper: what is on each monitor now, the pictures in the
/// wallpaper folder, and setting them. One place for Settings → Themes &
/// wallpapers, theme bindings, theme presets and the Quick theme widget.
///
/// scripts/theming/wallpaper.sh does the work (xwallpaper --daemon) and keeps
/// the choice in the state dir; `current` is read back from it (--state), so
/// it is right after a login --restore or a change made from a terminal too.
///
/// A wallpaper "set" is { "*": path, <output>: path }: "*" is every monitor
/// without its own picture.
QtObject {
    id: root

    /// What's set now: { "*": path, <output>: path }. Paths are absolute.
    property var current: ({})
    /// Picture file names in Settings.wallpaperDir, sorted.
    property var files: []
    /// True while a set is being applied.
    readonly property bool busy: internal.setProc.busy
    /// The last set failed (cleared by the next one).
    property string error: ""

    /// `current` was read again.
    signal updated()

    readonly property string dir: Services.Settings.wallpaperDir

    function pathOf(file) { return file.charAt(0) === "/" ? file : dir + "/" + file; }
    /// The picture folder for a monitor ("*" = the shared one).
    function dirFor(output) { return (output && output !== "*" && Services.Settings.wallpaperDirs[output]) || dir; }
    /// "a//b" and "a/b" are the same picture.
    function same(a, b) { return !!a && !!b && a.replace(/\/+/g, "/") === b.replace(/\/+/g, "/"); }
    /// The picture a monitor shows: its own, or the all-monitors one.
    function imageOn(output) { return current[output] ?? current["*"] ?? ""; }

    /// Put `path` on one monitor, or on all of them ("*", the default), which
    /// drops the per-monitor pictures.
    function set(path, output) {
        const out = output || "*";
        setMap(out === "*" ? { "*": path } : Object.assign({}, current, { [out]: path }));
    }

    /// Apply a whole set. Entries may be relative to the wallpaper folder.
    /// A set without "*" keeps the current all-monitors picture.
    function setMap(map) {
        if (!map) return;
        const specs = [];
        if (map["*"]) specs.push(pathOf(map["*"]));
        for (const out in map)
            if (out !== "*" && map[out]) specs.push(out + "=" + pathOf(map[out]));
        if (specs.length === 0) return;
        error = "";
        internal.setProc.run(["bash", Services.Paths.script("theming/wallpaper.sh"), "--set"].concat(specs));
    }

    /// The set in its stored form: a plain path when only "*" is set.
    function compact(map) {
        const keys = Object.keys(map ?? {});
        return keys.length === 1 && map["*"] ? map["*"] : map;
    }

    /// Does `map` (a set or a plain path) match what is on screen now?
    function matches(map) {
        const want = typeof map === "string" ? { "*": map } : (map ?? {});
        const keys = new Set(Object.keys(want).concat(Object.keys(current)));
        if (keys.size === 0) return false;
        const norm = p => (p ?? "").replace(/\/+/g, "/");
        for (const k of keys)
            if (norm(want[k] ? pathOf(want[k]) : "") !== norm(current[k])) return false;
        return true;
    }

    function refresh() {
        if (internal.stateProc.running) internal.again = true;
        else internal.stateProc.running = true;
    }

    Component.onCompleted: refresh()

    readonly property QtObject internal: QtObject {
        id: internal
        property bool again: false

        property Lib.QueuedProcess setProc: Lib.QueuedProcess {
            onFinished: code => {
                if (code !== 0) root.error = "Could not set the wallpaper";
                root.refresh();
            }
        }

        property Process stateProc: Process {
            command: ["bash", Services.Paths.script("theming/wallpaper.sh"), "--state"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const map = {};
                    for (const line of text.split("\n")) {
                        const tab = line.indexOf("\t");
                        if (tab > 0) map[line.slice(0, tab)] = line.slice(tab + 1).replace(/\/+/g, "/");
                    }
                    root.current = map;
                    root.updated();
                }
            }
            onExited: {  // qmllint disable signal-handler-parameters
                if (internal.again) { internal.again = false; running = true; }
            }
        }

        property FolderListModel folder: FolderListModel {
            // Not before settings.json is read: the default folder would be
            // listed first, and its names joined to the real folder.
            folder: Services.Settings.ready ? "file://" + root.dir : ""
            onFolderChanged: root.files = []
            nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp"]
            showDirs: false
            caseSensitive: false
            onStatusChanged: internal.readFiles()
            onCountChanged: internal.readFiles()
        }
        function readFiles() {
            if (folder.status !== FolderListModel.Ready || !Services.Settings.ready) return;
            const out = [];
            for (let i = 0; i < folder.count; i++) out.push(folder.get(i, "fileName"));
            root.files = out.sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase()));
        }
    }
}
