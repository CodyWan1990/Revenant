import QtQuick
import Quickshell
import "lib" as Lib

/// Regression test for components/QueuedProcess.qml: requests made while a
/// run is going are not dropped (a plain Process ignores them). Latest-wins
/// runs only the newest queued request; keepAll runs every one, in order.
/// Run with scripts/dev/run-qs-tests.sh.
ShellRoot {
    id: root
    property int failures: 0
    function check(cond, what) {
        if (!cond) { console.warn("FAIL: " + what); failures++; }
        else console.warn("  ok: " + what);
    }

    property var latestRuns: []
    property var allRuns: []

    // Each run sleeps a little, so the next requests arrive mid-run.
    function req(tag) { return ["sh", "-c", "sleep 0.15; echo " + tag]; }

    Lib.QueuedProcess {
        id: latest
        onFinished: (code, argv) => root.latestRuns = root.latestRuns.concat([argv[2].split(" ").pop()])
    }
    Lib.QueuedProcess {
        id: all
        keepAll: true
        onFinished: (code, argv) => root.allRuns = root.allRuns.concat([argv[2].split(" ").pop()])
    }

    Timer {
        running: true
        interval: 50
        onTriggered: {
            for (const t of ["a", "b", "c"]) { latest.run(root.req(t)); all.run(root.req(t)); }
            check(latest.busy && all.busy, "busy while a run is going or queued");
            done.start();
        }
    }

    Timer {
        id: done
        interval: 1500
        onTriggered: {
            check(root.latestRuns.join() === "a,c", "latest wins: a, then only the newest (c); got " + root.latestRuns.join());
            check(root.allRuns.join() === "a,b,c", "keepAll: every request, in order; got " + root.allRuns.join());
            check(!latest.busy && !all.busy, "idle afterwards");
            console.warn(root.failures === 0 ? "RESULT: all queued-process tests passed"
                                             : "RESULT: " + root.failures + " queued-process test(s) FAILED");
        }
    }
}
