import QtQuick
import Quickshell
import "services" as Services

/// Regression test for the stored bar profiles in services/Settings.qml:
/// monitor profiles and presets get their sections normalized on load, and
/// switching the layout mode never drops the legacy `bar.secondary` layout.
/// Run with scripts/dev/run-qs-tests.sh.
ShellRoot {
    property int failures: 0
    function check(cond, what) {
        if (!cond) { console.warn("FAIL: " + what); failures++; }
        else console.warn("  ok: " + what);
    }
    readonly property var s: Services.Settings
    function types(section) { return (section ?? []).map(w => w.type).join(","); }
    function allNormalized(section) {
        return (section ?? []).every(w => typeof w === "object" && w.id && w.style && w.surface);
    }

    function run() {
        console.warn("— normalizeProfile");
        const p = s.normalizeProfile({ left: ["clock", "separator"], height: 30 });
        check(types(p.left) === "clock,separator" && allNormalized(p.left), "string entries become widget objects");
        check(p.height === 30 && p.center === undefined, "other keys pass through, absent sections stay absent");
        check(Object.keys(s.normalizeProfile(null)).length === 0, "a non-object profile becomes {}");

        console.warn("— retired widget types");
        const old = s.normalizeSection(["clock", { type: "wifi", style: "none" }, "separator", "updates", "notifications"]);
        check(types(old) === "clock,controlCenter,separator,notifications",
              "wifi + updates become one controlCenter, in wifi's place (" + types(old) + ")");
        check(old[1].style === "none", "the old widget's style carries over");
        check(types(s.normalizeSection(["bluetooth"])) === "controlCenter", "bluetooth alone becomes controlCenter");
        const sys = s.normalizeSection(["cpu", "memory"]);
        check(types(sys) === "sysMonitor,sysMonitor", "cpu and memory each become a sysMonitor (" + types(sys) + ")");
        check(sys[0].showCpu === true && sys[0].showMemory === false && sys[1].showMemory === true && sys[1].showCpu === false,
              "showing just what the old widget showed");

        console.warn("— loading");
        s.internal.loadFromText(JSON.stringify({ bar: {
            monitorProfiles: { "DP-9": { left: ["workspaces"], right: [{ type: "clock" }] } },
            presets: [{ name: "p", profile: { center: ["audio"] } }, { name: "empty" }]
        } }));
        const loaded = s.barMonitorProfiles["DP-9"];
        check(types(loaded?.left) === "workspaces" && allNormalized(loaded?.left), "monitor profile string entries normalized");
        check(allNormalized(loaded?.right) && loaded.right[0].iconSet === "auto", "monitor profile objects get defaults");
        check(types(s.barPresets[0]?.profile?.center) === "audio" && allNormalized(s.barPresets[0].profile.center),
              "preset sections normalized");
        check(s.barPresets[1]?.name === "empty" && typeof s.barPresets[1].profile === "object",
              "a preset without a profile survives");

        console.warn("— layout mode keeps the legacy secondary layout");
        s.barMonitorProfiles = ({});
        s.barLayoutMode = "shared";
        s.barSecondaryLeft = s.normalizeSection(["clock"]);
        const others = s.barOutputs.filter(o => o !== s.primaryBarOutput);
        s.setBarLayoutMode("separate");
        check(s.barSecondaryLeft.length === 0, "secondary layout retired");
        check(others.every(o => types(s.barMonitorProfiles[o]?.left) === "clock"),
              "shared → separate imports it for each non-primary monitor (" + others.length + " here)");

        console.warn(failures === 0 ? "RESULT: all bar-profile tests passed"
                                    : "RESULT: " + failures + " bar-profile test(s) FAILED");
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
            // An exception must still end the run with a RESULT line, or the
            // runner waits out its timeout and shows nothing useful.
            try { parent.run(); }
            catch (error) { console.warn("RESULT: bar-profile tests FAILED with " + error); }
        }
    }
}
