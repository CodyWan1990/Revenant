//@ pragma UseQApplication
import QtQuick
import Quickshell
import "services" as Services

/// Regression test for the i3 IPC reducer in services/I3.qml: get_workspaces
/// mapping, get_tree window walk (tiling + floating), MRU order, and the
/// immediate focus/title updates from subscribe events.
///
/// Run with scripts/dev/run-qs-tests.sh, which stages this as the shell.qml of a
/// throwaway config. It feeds canned i3 JSON to `I3.internal.*`; the i3-msg
/// Processes the singleton starts fail to reach a socket here, which is harmless.
ShellRoot {
    property int failures: 0
    function check(cond, what) {
        if (!cond) { console.warn("FAIL: " + what); failures++; }
        else console.warn("  ok: " + what);
    }

    function ws(name) { return Services.I3.workspaces.find(w => w.name === name) ?? null; }
    function winIds() { return Services.I3.windows.map(w => w.id).join(","); }

    function leaf(id, title, cls, focused) {
        return { id: id, type: "con", name: title, window: 1000 + id, focused: focused === true,
                 window_properties: { class: cls }, nodes: [], floating_nodes: [] };
    }
    function tree(focusedId) {
        return { id: 1, type: "root", window: null, nodes: [
            { id: 2, type: "output", name: "DP-1", window: null, nodes: [
                { id: 10, type: "workspace", name: "1", window: null,
                  nodes: [ leaf(101, "kitty", "kitty", focusedId === 101),
                           leaf(102, "Brave", "Brave-browser", focusedId === 102) ],
                  floating_nodes: [
                      { id: 50, type: "floating_con", window: null, nodes: [
                          leaf(103, "pavucontrol", "pavucontrol", focusedId === 103) ] } ] }
            ] }
        ] };
    }

    Component.onCompleted: {
        let I = Services.I3;
        let H = I.internal;

        console.warn("— workspace mapping");
        H.applyWorkspaces([
            { id: 10, num: 1, name: "1", output: "DP-1", visible: true,  focused: true,  urgent: false },
            { id: 11, num: 2, name: "2", output: "DP-1", visible: false, focused: false, urgent: true },
            { id: 12, num: 3, name: "3", output: "HDMI-A-1", visible: true, focused: false, urgent: false },
            { id: 13, num: -1, name: "music", output: "DP-1", visible: false, focused: false, urgent: false }
        ]);
        check(I.workspaces.length === 4, "all workspaces published");
        check(ws("1").isFocused && ws("1").isActive, "focused + visible map to isFocused / isActive");
        check(ws("3").isActive && !ws("3").isFocused, "visible on another output is active, not focused");
        check(ws("2").isUrgent === true, "urgent maps to isUrgent");
        check(ws("2").isOccupied === true, "existing workspaces are always occupied");
        check(ws("2").idx === 2, "num becomes idx");
        check(ws("music").idx >= 1000, "a named-only workspace (num -1) sorts after the numbered ones");
        check(ws("3").output === "HDMI-A-1", "output is the RandR name the bar filters on");

        let before = I.workspaces;
        H.applyWorkspaces([
            { id: 10, num: 1, name: "1", output: "DP-1", visible: true,  focused: true,  urgent: false },
            { id: 11, num: 2, name: "2", output: "DP-1", visible: false, focused: false, urgent: true },
            { id: 12, num: 3, name: "3", output: "HDMI-A-1", visible: true, focused: false, urgent: false },
            { id: 13, num: -1, name: "music", output: "DP-1", visible: false, focused: false, urgent: false }
        ]);
        check(I.workspaces === before, "an identical reply does not reassign (no Repeater rebuild)");

        console.warn("— tree walk");
        H.applyTree(tree(101));
        check(I.windows.length === 3, "tiling and floating windows are both found");
        check(I.windows[0].id === 101, "the focused window is first");
        check(I.focusedWindowTitle === "kitty", "focused title resolved from the tree");
        check(I.windows.find(w => w.id === 103).appId === "pavucontrol", "WM_CLASS becomes appId");
        check(I.windows.find(w => w.id === 101).workspaceId === 10
              && I.windows.find(w => w.id === 103).workspaceId === 10,
              "tiling and floating windows carry their workspace id (running-apps scope)");

        console.warn("— MRU");
        H.handleEvent({ change: "focus", container: { id: 102, name: "Brave" } });
        check(I.focusedWindowTitle === "Brave", "a focus event updates the title immediately");
        H.applyTree(tree(102));
        check(winIds().startsWith("102,101"), "MRU: newest focus first, previous second");
        H.handleEvent({ change: "title", container: { id: 102, name: "Brave — docs" } });
        check(I.focusedWindowTitle === "Brave — docs", "a title event on the focused window updates the title");
        H.handleEvent({ change: "title", container: { id: 101, name: "vim" } });
        check(I.focusedWindowTitle === "Brave — docs", "a title event on another window leaves it alone");

        console.warn("— close");
        let closed = tree(102);
        closed.nodes[0].nodes[0].nodes = [ leaf(102, "Brave", "Brave-browser", true) ];
        H.applyTree(closed);
        check(winIds() === "102,103", "a closed window leaves the MRU stack");

        console.warn("— outputs");
        H.applyOutputs([{ name: "xroot-0", active: false, primary: false },
                        { name: "DP-1", active: true, primary: true },
                        { name: "DP-2", active: true, primary: false }]);
        check(I.primaryOutput === "DP-1", "the active primary output is found");
        H.applyOutputs([{ name: "DP-2", active: true, primary: false }]);
        check(I.primaryOutput === "", "no primary → empty (every bar then uses the main layout)");

        H.handleEvent({ success: true });
        check(true, "the subscribe ack is ignored without throwing");

        console.warn(failures === 0 ? "RESULT: all i3-reducer tests passed"
                                    : "RESULT: " + failures + " i3-reducer test(s) FAILED");
    }
}
