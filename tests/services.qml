import QtQuick
import Quickshell
import "panels/settings/pages" as Pages

/// Regression test for Settings → System → Systemd (panels/settings/pages/
/// ServicesPage.qml + scripts/system/services.py). Only reads the service
/// list: every check either asks "are you sure?" (then cancels) or filters.
/// Nothing is started, stopped, enabled or created.
/// Run with scripts/dev/run-qs-tests.sh.
ShellRoot {
    id: root
    property int failures: 0
    property int ticks: 0
    function check(cond, what) {
        if (!cond) { console.warn("FAIL: " + what); failures++; }
        else console.warn("  ok: " + what);
    }

    FloatingWindow {
        implicitWidth: 900; implicitHeight: 700
        Pages.ServicesPage { id: page }
    }

    function finish(message) {
        console.warn(message ?? (failures === 0 ? "RESULT: all services tests passed"
                                                : "RESULT: " + failures + " services test(s) FAILED"));
        poll.stop();
    }

    function run() {
        const all = page.userServices.concat(page.systemServices);
        check(all.every(s => typeof s.unit === "string" && typeof s.essential === "boolean"
                             && typeof s.transient === "boolean" && "about" in s),
              "every service has unit, essential, transient and about");

        // Services the session needs ask first, and cancelling leaves no trace.
        const core = all.find(s => s.essential && s.running);
        if (core) {
            const scope = page.userServices.includes(core) ? "user" : "system";
            page.handle(scope, core, "stop");
            check(page.confirm?.op === "stop" && !page.busy, "stopping a core service asks first and runs nothing");
            page.handle(scope, core, "cancel");
            check(page.confirm === null, "\"Keep it\" clears the question");
            page.handle(scope, core, "disable");
            check(page.confirm?.op === "disable" && !page.busy, "switching off a core service's auto-start asks first");
            page.handle(scope, core, "cancel");
        } else {
            console.warn("  skip: no running core service visible here");
        }

        // Core services are tucked away by default, but never when searched for.
        check(page.isTucked({ essential: true, state: "active" }), "a healthy core service is tucked away");
        check(!page.isTucked({ essential: true, state: "failed" }), "a failed core service is always shown");
        page.query = "dbus";
        check(!page.isTucked({ essential: true, state: "active" }), "a search shows core services too");
        page.query = "";

        // Temporary services that apps start are hidden unless asked for.
        const temp = { unit: "run-x.service", name: "x", state: "active", running: true, transient: true, about: "" };
        check(page.shown([temp], "user").length === 0, "temporary services are hidden");
        page.showTemporary = true;
        check(page.shown([temp], "user").length === 1, "\"Show temporary\" shows them");
        page.showTemporary = false;

        // Plain words: the about line is searchable, and failed sorts first.
        page.query = "wi-fi";
        check(page.shown([{ unit: "NetworkManager.service", name: "Network Manager", about: "Wi-Fi, Ethernet and VPN connections.",
                            state: "active", running: true, transient: false }], "system").length === 1,
              "searching \"wi-fi\" finds NetworkManager by its description");
        page.query = "";
        const order = page.shown([
            { unit: "b.service", name: "B", state: "inactive", running: false, transient: false, about: "" },
            { unit: "a.service", name: "A", state: "active", running: true, transient: false, about: "" },
            { unit: "c.service", name: "C", state: "failed", running: false, transient: false, about: "" }
        ], "system").map(s => s.name).join("");
        check(order === "CAB", "failed first, then running, then stopped (got " + order + ")");

        check(page.friendlyError("Interactive authentication required.").startsWith("Nothing changed"),
              "a cancelled password prompt reads as \"nothing changed\"");
        finish();
    }

    Timer {
        id: poll
        interval: 50
        repeat: true
        running: true
        onTriggered: {
            if (++root.ticks > 400) { root.finish("RESULT: services tests FAILED — the list never loaded"); return; }
            if (page.userServices.length + page.systemServices.length === 0) return;
            try { root.run(); }
            catch (error) { root.finish("RESULT: services tests FAILED with " + error); }
        }
    }
}
