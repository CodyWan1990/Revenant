import QtQuick
import Quickshell
import Quickshell.Io
import "panels" as Panels

/// Regression test for panels/TaskManager.qml: the process list finds a
/// process, ending it takes two presses, it really ends (the test's own
/// throwaway `sleep` — nothing else is ever signalled), and another user's
/// process is refused with a message. Run with scripts/dev/run-qs-tests.sh.
ShellRoot {
    id: root
    property int failures: 0
    function check(cond, what) {
        if (!cond) { console.warn("FAIL: " + what); failures++; }
        else console.warn("  ok: " + what);
    }

    Panels.TaskManager { id: tm }
    // The victim: our own process, nothing else.
    Process { id: victim; command: ["sleep", "313"]; running: true }
    property bool victimGone: false
    Process {
        id: alive
        command: ["kill", "-0", String(victim.processId)]
        onExited: code => root.victimGone = code !== 0  // qmllint disable signal-handler-parameters
    }

    function indexOfPid(pid) { return tm.shown.findIndex(p => p.pid === pid); }

    property real scrolledTo: 0
    property var procsBefore: null
    property int step: 0
    property int ticks: 0
    function advance() {
        switch (step) {
        case 0:
            if (!victim.processId) return;
            tm.open();
            break;
        case 1: {
            const i = indexOfPid(victim.processId);
            if (i < 0) return;   // wait for top's first sample
            check(tm.shown[i].name === "sleep", "the process list shows our sleep");
            const rootProc = tm.shown.findIndex(p => p.user === "root");
            if (rootProc >= 0) {
                tm.selectedPid = tm.shown[rootProc].pid;
                tm.endSelected("TERM");
                check(tm.message.includes("administrator") && tm.armed === null, "another user's process is refused with a message");
            }
            tm.selectedPid = victim.processId;
            // Scroll down, then let a refresh land (below) and check it held.
            tm.processView.contentY = Math.max(0, Math.min(200, tm.processView.contentHeight - tm.processView.height));
            root.scrolledTo = tm.processView.contentY;
            root.procsBefore = tm.procs;
            tm.endSelected("TERM");
            check(tm.armed?.pid === victim.processId, "the first press only arms");
            alive.running = true;
            break;
        }
        case 2:
            if (alive.running || tm.procs === root.procsBefore) return;   // wait for a refresh
            check(root.scrolledTo > 0 && Math.abs(tm.processView.contentY - root.scrolledTo) < 1,
                  "a refresh keeps the scroll position (" + root.scrolledTo + " → " + tm.processView.contentY + ")");
            check(tm.current?.pid === victim.processId, "the selection stays on the same process after a refresh");
            check(!victimGone, "and the process is still running");
            tm.endSelected("TERM");
            check(tm.armed === null, "the second press sends it");
            break;
        case 3:
            if (tm.message === "") return;
            check(tm.message.startsWith("Sent end to sleep"), "the result is reported (" + tm.message + ")");
            alive.running = true;
            break;
        case 4:
            if (alive.running) return;
            check(victimGone, "the process has ended");
            console.warn(failures === 0 ? "RESULT: all task-manager tests passed"
                                        : "RESULT: " + failures + " task-manager test(s) FAILED");
            poll.stop();
            return;
        }
        step++;
    }

    Timer {
        id: poll
        interval: 200
        repeat: true
        running: true
        onTriggered: {
            if (++root.ticks > 150) { console.warn("RESULT: task-manager tests FAILED — timed out at step " + root.step); stop(); return; }
            try { root.advance(); }
            catch (error) { console.warn("RESULT: task-manager tests FAILED with " + error); stop(); }
        }
    }
}
