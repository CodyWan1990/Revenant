import QtQuick
import Quickshell
import Quickshell.Io
import "services" as Services

/// Regression test for services/Session.qml + scripts/system/session.py, with
/// the logging xset from tests/bin (nothing touches the real X server):
/// slider drags are batched into one save, DPMS times are only set while DPMS
/// is on, out-of-order times are refused, and keep-awake holds blanking off
/// across saves and re-applies the settings when released.
/// Run with scripts/dev/run-qs-tests.sh.
ShellRoot {
    property int failures: 0
    function check(cond, what) {
        if (!cond) { console.warn("FAIL: " + what); failures++; }
        else console.warn("  ok: " + what);
    }
    readonly property var s: Services.Session
    readonly property string home: Quickshell.env("HOME")

    // Read on demand (reload + waitForJob), never by watchChanges: an async
    // watcher reload in flight made text() return stale content (see network.qml).
    FileView { id: xsetLog; path: root.home + "/xset.log"; blockAllReads: true }
    // blockLoading: reload() then text() must see the file the save just made
    // (its directory may not have existed when this FileView started).
    FileView { id: envFile; path: Services.Paths.configDir + "/session.env"; blockLoading: true; blockAllReads: true }
    id: root
    function calls() { xsetLog.reload(); xsetLog.waitForJob(); return xsetLog.text().split("\n").filter(Boolean); }
    property int mark: 0
    function since() { const all = calls(); const out = all.slice(mark); mark = all.length; return out; }
    function idle() { return !s.script.running && !s.flush.running; }

    property int step: 0
    property int ticks: 0

    function finish(message) {
        console.warn(message ?? (failures === 0 ? "RESULT: all session tests passed"
                                                : "RESULT: " + failures + " session test(s) FAILED"));
        poll.stop();
    }

    function advance() {
        switch (step) {
        case 0:
            check(s.values.KEY_REPEAT_DELAY === 200 && s.values.DPMS === "off", "no file: the old .xprofile defaults");
            check(s.values.LOGIN_VOLUME === -1, "no file: the login volume is left alone");
            since();
            for (let d = 210; d <= 300; d += 10) s.set("KEY_REPEAT_DELAY", d);   // a slider drag
            s.set("KEY_REPEAT_RATE", 40);
            break;
        case 1: {
            const out = since();
            const rates = out.filter(line => line.startsWith("r rate"));
            check(rates.length === 1 && rates[0] === "r rate 300 40", "a drag is batched into one save (" + rates.join("; ") + ")");
            check(!out.some(line => /^dpms /.test(line)), "DPMS times are not set while DPMS is off");
            envFile.reload();
            envFile.waitForJob();
            check(envFile.text().includes("KEY_REPEAT_DELAY=300"), "the value is saved to session.env");
            s.set("DPMS", "on");
            break;
        }
        case 2: {
            const out = since();
            check(out.indexOf("+dpms") >= 0 && out.indexOf("dpms 600 600 600") > out.indexOf("+dpms"),
                  "turning DPMS on sets its times after enabling it");
            s.set("DPMS_STANDBY_MIN", 30);   // > suspend (10): X would refuse it
            break;
        }
        case 3:
            check(s.error.length > 0, "out-of-order DPMS times are refused with a message");
            check(s.values.DPMS_STANDBY_MIN === 10, "and the saved value is shown again");
            since();
            s.keepAwake = true;
            break;
        case 4: {
            check(since().includes("s off -dpms"), "keep-awake forces blanking and DPMS off");
            s.set("SCREEN_BLANK_MIN", 5);
            break;
        }
        case 5: {
            const out = since();
            check(out.includes("s 300") && out[out.length - 1] === "s off -dpms",
                  "a save while awake is followed by blanking off again");
            check(s.error === "", "a good save clears the earlier error");
            s.keepAwake = false;
            break;
        }
        case 6: {
            const out = since();
            check(out.includes("s 300") && out.includes("+dpms"), "releasing keep-awake re-applies the settings");
            finish();
            return;
        }
        }
        step++;
    }

    Timer {
        id: poll
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            if (++ticks > 300) { finish("RESULT: session tests FAILED — timed out at step " + step); return; }
            // execDetached xset calls land a moment after the run ends.
            if (!s.ready || !idle()) return;
            if (ticks % 3 !== 0) return;
            try { advance(); }
            catch (error) { finish("RESULT: session tests FAILED with " + error); }
        }
    }
}
