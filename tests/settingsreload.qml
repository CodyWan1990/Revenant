import QtQuick
import Quickshell
import "services" as Services

/// Regression test for services/Settings.qml reloading settings.json: a key
/// deleted from the file goes back to its compiled default (it used to keep
/// the old value, and the next save wrote that back). A key the file never
/// had is left alone, and a default that follows another setting
/// (shellRadius ← barRadius) gets its binding back.
/// Run with scripts/dev/run-qs-tests.sh.
ShellRoot {
    property int failures: 0
    function check(cond, what) {
        if (!cond) { console.warn("FAIL: " + what); failures++; }
        else console.warn("  ok: " + what);
    }
    readonly property var s: Services.Settings
    function load(obj) { s.internal.loadFromText(JSON.stringify(obj)); }

    function run() {
        const home = Quickshell.env("HOME");

        console.warn("— a deleted key goes back to its default");
        load({ osd: { timeoutMs: 4000 }, screenshots: { askName: true, nameFormat: "x_%H",
            directory: "/tmp/shots" } });
        check(s.osdTimeoutMs === 4000 && s.screenshotAskName && s.screenshotNameFormat === "x_%H",
              "values load");
        load({ osd: { timeoutMs: 4000 } });
        check(s.screenshotAskName === false, "bool back to default");
        check(s.screenshotNameFormat === "Screenshot_%Y-%m-%d_%H-%M-%S", "string back to default");
        check(s.screenshotDir === home + "/Pictures/Screenshots", "env-derived default restored");
        check(s.osdTimeoutMs === 4000, "keys still present are untouched");

        console.warn("— only keys the file had are reset");
        s.osdMic = false;   // set in memory, never in the file
        load({ osd: { timeoutMs: 4000 } });
        check(s.osdMic === false, "a key absent from both loads keeps its value");

        console.warn("— arrays and maps restore as fresh copies");
        load({ launcher: { recentApps: ["a", "b"] } });
        check(s.launcherRecentApps.length === 2, "array loads");
        load({});
        check(Array.isArray(s.launcherRecentApps) && s.launcherRecentApps.length === 0, "array back to []");
        s.launcherRecentApps.push("leak");
        load({ launcher: { recentApps: ["c"] } });
        load({});
        check(s.launcherRecentApps.length === 0, "mutating the restored array doesn't touch the default");

        console.warn("— a bound default is bound again");
        load({ bar: { radius: 0 }, appearance: { radius: 3 } });
        check(s.shellRadius === 3, "stored shellRadius wins over the binding");
        load({ bar: { radius: 0 } });
        check(s.shellRadius === 12, "deleted: back to the default (barRadius 0 → 12)");
        load({ bar: { radius: 7 } });
        check(s.shellRadius === 7, "and follows barRadius again");

        console.warn("— after a save every key counts as in the file");
        s.internal.saveToFile();
        s.screenshotAskName = true;
        load({});
        check(s.screenshotAskName === false, "a key written by our own save resets when deleted");

        console.warn(failures === 0 ? "RESULT: all settings-reload tests passed"
                                    : "RESULT: " + failures + " settings-reload test(s) FAILED");
    }

    // Wait until Settings has read (or ruled out) settings.json, so its own
    // load can't overwrite what the test sets.
    Timer {
        interval: 50
        repeat: true
        running: true
        onTriggered: {
            if (!Services.Settings.ready) return;
            stop();
            try { parent.run(); }
            catch (error) { console.warn("RESULT: settings-reload tests FAILED with " + error); }
        }
    }
}
