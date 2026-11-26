pragma Singleton

import QtQuick
import Quickshell.Io
import "." as Services

/// Pending package updates from three sources — the system package manager
/// (apt, pacman or dnf), Flatpak and Snap — all through scripts/system/sys-updates.sh,
/// every updatesIntervalHours and on refresh().
///
/// Upgrades open in the chosen terminal. sys-updates.sh asks the shell to
/// check again over IPC when an upgrade finishes (shell.qml → refresh()), so
/// the counts are right even when the terminal forks and returns at once.
QtObject {
    id: root

    readonly property int count: system.packages.length
    readonly property var packages: system.packages
    readonly property int flatpakCount: flatpak.packages.length
    readonly property var flatpakPackages: flatpak.packages
    readonly property int snapCount: snap.packages.length
    readonly property var snapPackages: snap.packages

    readonly property int totalCount: count + flatpakCount + snapCount
    readonly property bool checking: system.checking || flatpak.checking || snap.checking
    /// Sources whose last check failed ("system: exit 1"), so a failed check
    /// shows as a failure instead of "up to date".
    readonly property var errors: [system, flatpak, snap].filter(s => s.error).map(s => s.label + ": " + s.error)


    /// Check every source again; a source already checking is left to finish.
    function refresh() {
        system.check();
        flatpak.check();
        snap.check();
    }

    function upgradeSystem() { system.upgrade(); }
    function upgradeFlatpaks() { flatpak.upgrade(); }
    function upgradeSnaps() { snap.upgrade(); }

    /// One package source: `sys-updates.sh <checkArg>` prints a JSON array of
    /// packages, `sys-updates.sh <upgradeArg>` runs the upgrade in a terminal.
    /// A disabled source reports no packages without running anything.
    component Source: QtObject {
        id: source
        required property string label
        required property string checkArg
        required property string upgradeArg
        property bool enabled: true

        property var packages: []
        /// Why the last check failed, or "". The previous list is kept.
        property string error: ""
        /// The check process's own state, so it can't get stuck "checking".
        readonly property bool checking: checkProc.running

        function check() {
            if (!enabled) { packages = []; error = ""; return; }
            if (!checkProc.running) checkProc.running = true;
        }
        function upgrade() {
            if (!upgradeProc.running) upgradeProc.running = true;
        }

        onEnabledChanged: check()

        readonly property Process checkProc: Process {
            command: ["bash", Services.Paths.script("system/sys-updates.sh"), source.checkArg]
            stdout: StdioCollector { id: checkOut }
            onExited: code => {  // qmllint disable signal-handler-parameters
                // Turned off while this check ran: check() already cleared
                // the list, so don't put the result back.
                if (!source.enabled) return;
                if (code !== 0) {
                    source.error = "check exited " + code;
                    console.warn("Updates:", source.label, source.error);
                    return;
                }
                try {
                    const list = JSON.parse(checkOut.text.trim() || "[]");
                    source.packages = Array.isArray(list) ? list : [];
                    source.error = "";
                } catch (parseError) {
                    source.error = "unreadable answer";
                    console.warn("Updates:", source.label, "parse error:", parseError);
                }
            }
        }

        readonly property Process upgradeProc: Process {
            command: Services.DefaultApps.terminalArgv(
                ["bash", Services.Paths.script("system/sys-updates.sh"), source.upgradeArg], "updatescratch")
            stderr: SplitParser {
                onRead: line => console.warn("Updates:", source.label, "terminal:", line)
            }
            // Also covered by the IPC refresh at the end of the upgrade; this
            // one catches a terminal that closed before the script got there.
            onExited: source.check()  // qmllint disable signal-handler-parameters
        }
    }

    readonly property Source system: Source {
        label: "system"
        checkArg: "check"
        upgradeArg: "upgrade"
    }
    readonly property Source flatpak: Source {
        label: "Flatpak"
        checkArg: "flatpak"
        upgradeArg: "flatpak-upgrade"
        enabled: Services.Settings.updatesFlatpak
    }
    readonly property Source snap: Source {
        label: "Snap"
        checkArg: "snap"
        upgradeArg: "snap-upgrade"
        enabled: Services.Settings.updatesSnap
    }

    readonly property Timer pollTimer: Timer {
        interval: Math.max(1, Services.Settings.updatesIntervalHours) * 3600000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
}
