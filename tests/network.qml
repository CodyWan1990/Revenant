import QtQuick
import Quickshell
import Quickshell.Io
import "panels/settings/pages" as Pages

/// Regression test for Settings → Network's Connection details and Saved &
/// VPN pages with the canned nmcli from tests/bin (the real network is never
/// read or changed): private values stay hidden until "Show all", which the
/// window closing turns off; terse fields with escaped colons parse; delete
/// takes two clicks. Run with scripts/dev/run-qs-tests.sh.
ShellRoot {
    id: root
    property int failures: 0
    function check(cond, what) {
        if (!cond) { console.warn("FAIL: " + what); failures++; }
        else console.warn("  ok: " + what);
    }

    FloatingWindow {
        implicitWidth: 900; implicitHeight: 900
        Pages.NetworkDetailsPage { id: details; width: 440; height: 900 }
        Pages.ConnectionsPage { id: conns; x: 450; width: 440; height: 900 }
    }
    // Read on demand only. A watchChanges reload is asynchronous: when one was
    // still running as logged() asked, text() returned the file from before
    // the last nmcli call (the "second click deletes" flake under load).
    FileView { id: log; path: Quickshell.env("HOME") + "/nmcli.log"; blockLoading: true; blockAllReads: true }
    function logged() { log.reload(); log.waitForJob(); return log.text(); }

    function texts(item) {
        let out = [];
        if (item.text !== undefined && item.visible !== false) out.push(String(item.text));
        for (const child of item.children ?? []) out = out.concat(texts(child));
        return out;
    }

    property int step: 0
    function advance() {
        switch (step) {
        case 0: {
            if (details.devices.length === 0 || conns.connections.length === 0) return false;
            check(details.devices.length === 1 && details.devices[0].device === "eth0", "loopback is left out of the devices");
            check(details.connectivity === "full", "the internet check is read");
            const shown = texts(details).join("\n");
            check(!shown.includes("192.0.2.10") && !shown.includes("AA:BB:CC"), "addresses and MAC are hidden by default");
            check(shown.includes("1000 Mb/s"), "non-private details still show");
            details.showAll = true;
            break;
        }
        case 1: {
            const shown = texts(details).join("\n");
            check(shown.includes("192.0.2.10/24") && shown.includes("AA:BB:CC:DD:EE:FF"), "Show all reveals them");
            details.windowClosed();
            check(!details.showAll, "closing Settings turns Show all off");
            const names = conns.connections.map(c => c.name);
            check(names.includes("Cafe: guest"), "an escaped colon in a name parses");
            check(!names.includes("lo"), "loopback is not a saved connection");
            check(conns.connections.find(c => c.name === "Work VPN")?.type === "VPN", "VPN profiles are labelled");
            conns.run("autoconnect", ["22222222-2222-2222-2222-222222222222", "no"]);
            break;
        }
        case 2:
            if (conns.busy) return false;
            check(logged().includes("connection modify uuid 22222222-2222-2222-2222-222222222222 connection.autoconnect no"),
                  "the auto-connect switch modifies that profile");
            conns.confirmDelete = "33333333-3333-3333-3333-333333333333";   // first click
            check(!logged().includes("delete"), "one click does not delete");
            conns.run("delete", ["33333333-3333-3333-3333-333333333333"]);   // second click
            break;
        case 3:
            if (conns.busy) return false;
            check(logged().includes("connection delete uuid 33333333-3333-3333-3333-333333333333"), "the second click deletes (log: " + logged().replace(/\n/g, " / ") + " msg: " + conns.message + ")");
            check(conns.confirmDelete === "", "and the confirmation resets");
            console.warn(failures === 0 ? "RESULT: all network tests passed"
                                        : "RESULT: " + failures + " network test(s) FAILED");
            poll.stop();
            return true;
        }
        step++;
        return true;
    }

    Timer {
        id: poll
        interval: 150
        repeat: true
        running: true
        property int ticks: 0
        onTriggered: {
            if (++ticks > 150) { console.warn("RESULT: network tests FAILED — timed out at step " + root.step); stop(); return; }
            try { root.advance(); }
            catch (error) { console.warn("RESULT: network tests FAILED with " + error); stop(); }
        }
    }
}
