import QtQuick
import Quickshell
import Quickshell.Io
import "services" as Services

/// Regression test for services/Apps.qml: entries whose TryExec program is
/// missing are hidden, a working TryExec is kept, and an entry installed
/// while the shell runs is checked too. Writes fake entries into the staged
/// $HOME/.local/share/applications. Run with scripts/dev/run-qs-tests.sh.
ShellRoot {
    property int failures: 0
    function check(cond, what) {
        if (!cond) { console.warn("FAIL: " + what); failures++; }
        else console.warn("  ok: " + what);
    }
    function ids(list) { return list.map(entry => entry.id); }
    function entry(name, tryExec) {
        return "[Desktop Entry]\nType=Application\nName=" + name + "\nExec=sh\nTryExec=" + tryExec + "\n";
    }

    readonly property string dir: Quickshell.env("HOME") + "/.local/share/applications"
    property int step: 0
    property int ticks: 0

    function write(files) {
        let cmd = "mkdir -p \"$1\"";
        const args = [dir];
        for (const name in files) {
            args.push(name, files[name]);
            // args[i] is $(i + 1): $1 is the dir, then name/content pairs.
            cmd += "; printf '%s' \"$" + args.length + "\" > \"$1/$" + (args.length - 1) + ".desktop\"";
        }
        Quickshell.execDetached(["sh", "-c", cmd, "sh"].concat(args));
    }

    function finish(message) {
        console.warn(message ?? (failures === 0 ? "RESULT: all apps tests passed"
                                                : "RESULT: " + failures + " apps test(s) FAILED"));
        poll.stop();
    }

    Component.onCompleted: write({
        "qs-test-here": entry("Here", "sh"),
        "qs-test-gone": entry("Gone", "/nonexistent/qs-test-gone")
    })

    // Waits for the entry index and the TryExec scan to settle, then checks.
    Timer {
        id: poll
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            if (++ticks > 150) {
                finish("RESULT: apps tests FAILED — timed out at step " + step + " (indexed: "
                    + ids(Services.Apps.all).filter(id => id.startsWith("qs-test")).join(",") + "; missing: "
                    + Services.Apps.missing.join(",") + ")");
                return;
            }
            const all = ids(Services.Apps.all);
            const shown = ids(Services.Apps.entries);
            if (step === 0) {
                if (!all.includes("qs-test-gone") || !Services.Apps.missing.includes("qs-test-gone")) return;
                check(all.includes("qs-test-here") && all.includes("qs-test-gone"), "Quickshell indexes both entries");
                check(shown.includes("qs-test-here"), "an entry whose TryExec is installed is offered");
                check(!shown.includes("qs-test-gone"), "an entry whose TryExec is missing is hidden");
                step = 1;
                write({ "qs-test-later": entry("Later", "no-such-program-qs-test") });
            } else if (step === 1) {
                if (!all.includes("qs-test-later") || !Services.Apps.missing.includes("qs-test-later")) return;
                check(!shown.includes("qs-test-later"), "an entry installed while running is checked too");
                check(shown.includes("qs-test-here"), "the earlier entry stays offered");
                finish();
            }
        }
    }
}
