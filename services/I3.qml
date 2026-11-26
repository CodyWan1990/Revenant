pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib" as Lib

/// i3 IPC provider — the whole compositor seam. Same public interface as
/// nirishell's Niri.qml, so widgets only differ in the service name.
///
/// In: a long-lived `i3-msg -t subscribe -m` stream. i3 events are deltas with
/// no window counts or MRU, so each event (debounced) re-queries
/// get_workspaces + get_tree and rebuilds state wholesale; focus events also
/// update the title immediately so it never lags the debounce.
/// Out: three i3-msg commands.
QtObject {
    id: root

    /// All workspaces: [{ id, idx, name, output, isActive, isFocused, isUrgent, isOccupied, activeWindowId }]
    /// isActive = visible on its output (i3 "visible"); isOccupied is always true,
    /// because i3 only reports workspaces that exist (an empty one is destroyed on leave).
    property var workspaces: []
    /// Title of the currently focused window ("" when none).
    property string focusedWindowTitle: ""
    /// Emitted when i3 moves focus (to another window or workspace). Dropdowns
    /// close on it: on X11 there is no other way to see an outside click.
    signal focusMoved()

    /// All open windows, most-recently-used first: [{ id, title, appId, workspaceId }].
    /// id is the i3 con_id; workspaceId matches a workspaces[].id.
    property var windows: []

    /// RandR primary output name ("" until known). The tray and the full
    /// layout go there; other screens get Settings' secondary layout.
    property string primaryOutput: ""

    /// ShellScreen of the focused workspace's output (RandR output name == i3 output name).
    readonly property var focusedScreen: {
        let ws = workspaces.find(w => w.isFocused);
        if (!ws) return null;
        return Quickshell.screens.find(s => s.name === ws.output) ?? null;
    }

    function focusWorkspace(idx) {
        let ws = workspaces.find(w => w.idx === idx);
        let name = ws ? ws.name : String(idx);
        run("workspace \"" + internal.quote(name) + "\"");
    }
    function focusWindow(id) {
        run("[con_id=" + Number(id) + "] focus");
    }
    function quit() {
        run("exit");
    }
    /// Run one i3 command (e.g. `workspace "2"`). i3-msg joins argv with spaces,
    /// so a single argument keeps the quoting intact.
    function run(cmd) {
        Quickshell.execDetached(["i3-msg", cmd]);
    }

    readonly property QtObject internal: QtObject {
        id: internal
        // con_id -> { title, appId, workspaceId }
        property var windowsById: ({})
        property var focusedWindowId: null
        // con_ids, most recently focused first.
        property var focusOrder: []

        function quote(s) { return String(s).replace(/\\/g, "\\\\").replace(/"/g, "\\\""); }

        function noteFocus(id) {
            if (id === null || id === undefined) return;
            let order = focusOrder.filter(x => x !== id);
            order.unshift(id);
            focusOrder = order;
        }

        function publishWindows() {
            let seen = {};
            let out = [];
            for (let id of focusOrder) {
                let w = windowsById[id];
                if (w) { out.push({ id: id, title: w.title, appId: w.appId, workspaceId: w.workspaceId }); seen[id] = true; }
            }
            for (let id in windowsById) {
                if (seen[id]) continue;
                let w = windowsById[id];
                out.push({ id: Number(id), title: w.title, appId: w.appId, workspaceId: w.workspaceId });
            }
            root.windows = out;
        }

        function resolveFocusedTitle() {
            let w = focusedWindowId === null ? null : windowsById[focusedWindowId];
            root.focusedWindowTitle = (w && w.title) ? w.title : "";
        }

        /// get_workspaces reply → root.workspaces.
        function applyWorkspaces(list) {
            let out = [];
            for (let i = 0; i < list.length; i++) {
                let w = list[i];
                out.push({
                    id: w.id,
                    // Named-only workspaces report num -1; park them after the numbered ones.
                    idx: (w.num ?? -1) >= 0 ? w.num : 1000 + i,
                    name: w.name ?? "",
                    output: w.output ?? "",
                    isActive: w.visible === true,
                    isFocused: w.focused === true,
                    isUrgent: w.urgent === true,
                    isOccupied: true,
                    activeWindowId: null
                });
            }
            // Skip the reassign when nothing changed: title-only window events
            // re-query too, and rebuilding the Repeater each time flickers.
            if (JSON.stringify(out) !== JSON.stringify(root.workspaces))
                root.workspaces = out;
        }

        /// get_tree reply → windowsById / focus. A window is any con with an
        /// X window id; tiling and floating children are both walked.
        function applyTree(tree) {
            let map = {};
            let focused = null;
            function walk(node, wsId) {
                if (node.type === "workspace") wsId = node.id;
                if (node.window !== null && node.window !== undefined) {
                    map[node.id] = {
                        title: node.name ?? "",
                        appId: node.window_properties?.class ?? "",
                        workspaceId: wsId
                    };
                    if (node.focused === true) focused = node.id;
                }
                for (let c of (node.nodes ?? [])) walk(c, wsId);
                for (let c of (node.floating_nodes ?? [])) walk(c, wsId);
            }
            walk(tree, null);
            windowsById = map;
            focusedWindowId = focused;
            focusOrder = focusOrder.filter(id => map[id] !== undefined);
            noteFocus(focused);
            resolveFocusedTitle();
            publishWindows();
        }

        /// One subscribe event. Window focus/title events carry the container,
        /// so the title updates now; everything else waits for the re-query.
        function handleEvent(ev) {
            if (ev.success !== undefined) return;   // the subscribe ack
            if (ev.change === "focus") root.focusMoved();
            let c = ev.container;
            if (c && (ev.change === "focus" || ev.change === "title")) {
                if (ev.change === "focus") { focusedWindowId = c.id; noteFocus(c.id); }
                if (c.id === focusedWindowId) root.focusedWindowTitle = c.name ?? "";
            }
            refreshTimer.restart();
        }

        // Queued (latest wins): an event during a query re-runs it once it
        // finishes, instead of being dropped and leaving stale state.
        function refresh() {
            wsProc.run(["i3-msg", "-t", "get_workspaces"]);
            treeProc.run(["i3-msg", "-t", "get_tree"]);
            outputsProc.run(["i3-msg", "-t", "get_outputs"]);
        }

        /// get_outputs reply → primaryOutput.
        function applyOutputs(list) {
            let p = list.find(o => o.active && o.primary);
            root.primaryOutput = p ? p.name : "";
        }

        property Lib.QueuedProcess outputsProc: Lib.QueuedProcess {
            stdout: StdioCollector {
                onStreamFinished: {
                    try { internal.applyOutputs(JSON.parse(text)); }
                    catch (e) { console.warn("I3: bad get_outputs reply:", e); }
                }
            }
        }

        property Timer refreshTimer: Timer {
            interval: 40
            onTriggered: internal.refresh()
        }

        property Lib.QueuedProcess wsProc: Lib.QueuedProcess {
            stdout: StdioCollector {
                onStreamFinished: {
                    try { internal.applyWorkspaces(JSON.parse(text)); }
                    catch (e) { console.warn("I3: bad get_workspaces reply:", e); }
                }
            }
        }

        property Lib.QueuedProcess treeProc: Lib.QueuedProcess {
            stdout: StdioCollector {
                onStreamFinished: {
                    try { internal.applyTree(JSON.parse(text)); }
                    catch (e) { console.warn("I3: bad get_tree reply:", e); }
                }
            }
        }

        property Process stream: Process {
            command: ["i3-msg", "-t", "subscribe", "-m", "[\"workspace\",\"window\",\"output\"]"]
            running: true
            onRunningChanged: if (running) internal.refresh()   // initial state + after a restart
            stdout: SplitParser {
                onRead: line => {
                    let text = line.trim();
                    if (text.length === 0) return;
                    try {
                        internal.handleEvent(JSON.parse(text));
                    } catch (e) {
                        console.warn("I3: failed to parse event:", e, "—", text);
                    }
                }
            }
            // i3 restart (Mod+Shift+r) drops the socket; resubscribe.
            onExited: (code, status) => {  // qmllint disable signal-handler-parameters
                console.warn("I3: event stream exited (code " + code + "); restarting in 1s");
                restartTimer.start();
            }
        }

        property Timer restartTimer: Timer {
            interval: 1000
            onTriggered: internal.stream.running = true
        }
    }
}
