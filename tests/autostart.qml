import QtQuick
import Quickshell
import "services" as Services
import "panels/settings/pages" as Pages

/// Regression test for Settings → Autostart (panels/settings/pages/
/// AutostartPage.qml + scripts/system/autostart.py) against the staged $HOME:
/// custom commands (quoting, delay), off/on, a system entry's override round
/// trip, "Run in i3" + reset, adding an app, removing, and the page's filter
/// and search. The system autostart dir and systemd are only read; no
/// service is started or stopped. Run with scripts/dev/run-qs-tests.sh.
ShellRoot {
    id: root
    property int failures: 0
    function check(cond, what) {
        if (!cond) { console.warn("FAIL: " + what); failures++; }
        else console.warn("  ok: " + what);
    }
    function find(id) { return page.entries.find(entry => entry.id === id); }

    readonly property string tricky: "echo \"double\" 'single' $HOME 50% && true"
    property int step: 0
    property int ticks: 0
    property string systemId: ""
    property string forceId: ""
    property string appId: ""

    FloatingWindow {
        implicitWidth: 900; implicitHeight: 700
        Pages.AutostartPage { id: page }
    }

    function finish(message) {
        console.warn(message ?? (failures === 0 ? "RESULT: all autostart tests passed"
                                                : "RESULT: " + failures + " autostart test(s) FAILED"));
        poll.stop();
    }

    function advance() {
        switch (step) {
        case 0:
            check(page.message === "", "lists without an error");
            check(!page.entries.some(e => e.source === "xdg" && e.origin === "user"), "a fresh home has no login items of its own");
            page.run("add-custom", ["Say hi", tricky]);
            break;
        case 1: {
            const e = find("xdg:custom-say-hi");
            check(e?.origin === "user" && e?.enabled === true, "a custom command is added, enabled");
            check(e?.command === tricky, "its command survives quoting exactly");
            page.run("disable", ["xdg:custom-say-hi"]);
            break;
        }
        case 2:
            check(find("xdg:custom-say-hi")?.enabled === false, "it can be turned off");
            page.run("edit", ["xdg:custom-say-hi", "Say hello", "true", "5"]);
            break;
        case 3: {
            const e = find("xdg:custom-say-hi");
            check(e?.name === "Say hello" && e?.command === "true" && e?.delay === 5, "edit sets name, command and delay");
            check(e?.enabled === false, "editing keeps it off");
            systemId = page.entries.find(x => x.source === "xdg" && x.origin === "system" && x.runsHere && x.enabled)?.id ?? "";
            if (systemId) page.run("disable", [systemId]); else { step += 2; return advance(); }
            break;
        }
        case 4:
            check(find(systemId)?.origin === "override" && find(systemId)?.enabled === false, "turning a system item off makes an override");
            page.run("enable", [systemId]);
            break;
        case 5:
            if (systemId) check(find(systemId)?.origin === "system" && find(systemId)?.enabled, "turning it back on removes the override");
            forceId = page.entries.find(x => x.source === "xdg" && x.forcible && !x.runsHere)?.id ?? "";
            if (forceId) page.run("force", [forceId]); else { step += 2; return advance(); }
            break;
        case 6:
            check(find(forceId)?.runsHere === true && find(forceId)?.origin === "override", "Run in i3 makes it run here");
            page.run("remove", [forceId]);
            break;
        case 7: {
            if (forceId) check(find(forceId)?.runsHere === false && find(forceId)?.origin === "system", "Reset brings the system entry back");
            appId = Services.Apps.pickable[0]?.id ?? "";
            if (appId) page.run("add-app", [appId]); else { step++; return advance(); }
            break;
        }
        case 8:
            if (appId) check(find("xdg:" + appId)?.origin === "user", "an installed app is added");
            check(page.startupApps.every(e => e.source === "xdg" && e.runsHere && !e.essential && !e.plumbing),
                  "Startup apps: login items that run in i3, no session plumbing");
            check(page.services.every(e => e.source === "systemd" && !e.essential && !e.plumbing),
                  "Background services: user services, no session plumbing");
            check(page.startupApps.some(e => e.id === "xdg:custom-say-hi"), "your own item is listed, even when off");
            page.run("remove", ["xdg:custom-say-hi"]);
            break;
        case 9:
            check(!find("xdg:custom-say-hi"), "a custom command can be removed (message: '" + page.message + "')");
            page.run("remove", ["xdg:../escape"]);
            break;
        case 10:
            check(page.message.length > 0, "a bad id is refused with a message (message: '" + page.message + "')");
            finish();
            return;
        }
        step++;
    }

    Timer {
        id: poll
        interval: 50
        repeat: true
        running: true
        onTriggered: {
            if (++root.ticks > 600) { root.finish("RESULT: autostart tests FAILED — timed out at step " + root.step); return; }
            if (page.busy || page.entries.length === 0) return;
            if (root.step === 0 && Services.Apps.all.length === 0 && root.ticks < 100) return;
            try { root.advance(); }
            catch (error) { root.finish("RESULT: autostart tests FAILED with " + error); }
        }
    }
}
