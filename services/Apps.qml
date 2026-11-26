pragma Singleton

import QtQuick
import Quickshell
import "../lib" as Lib

/// The installed apps the shell offers: Quickshell's DesktopEntries (which
/// already leaves out NoDisplay entries) minus those whose TryExec program is
/// missing. Quickshell does not read TryExec, so scripts/system/missing-tryexec.py
/// does, re-run whenever the installed entries change.
///
/// Use `entries` wherever the shell lists apps (launcher, Keybinds, default
/// terminal), so an app that can't start is never offered anywhere.
QtObject {
    id: root

    readonly property var all: DesktopEntries.applications.values
    /// Desktop ids to hide, from the last scan.
    property var missing: []
    readonly property var entries: missing.length === 0
        ? all : all.filter(entry => !missing.includes(entry.id))

    /// Apps for a picker (Keybinds, Autostart): [{ name, id, title }], by
    /// title. `title` is the name, plus the id when two apps share a name.
    /// Only plain ids: Keybinds runs `gtk-launch <id>`, Autostart names a file by it.
    readonly property var pickable: {
        const apps = entries.filter(entry => !!entry.name && entry.command.length > 0
            && /^[A-Za-z0-9_.+-]+$/.test(entry.id));
        return apps.map(entry => ({
            name: entry.name,
            id: entry.id,
            title: apps.some(other => other.id !== entry.id && other.name === entry.name)
                ? entry.name + " (" + entry.id + ")" : entry.name
        })).sort((a, b) => a.title.localeCompare(b.title));
    }

    readonly property Lib.JsonScript scan: Lib.JsonScript {
        script: "system/missing-tryexec.py"
        fallbackError: "Could not check desktop entries' TryExec."
        onFailed: message => console.warn("Apps:", message)
        onSucceeded: result => root.missing = Array.isArray(result.missing) ? result.missing : []
    }

    // Installs and removals arrive as a burst of changes; scan once after.
    readonly property Timer rescan: Timer {
        interval: 500
        onTriggered: if (!root.scan.run("")) restart()
    }
    onAllChanged: rescan.restart()
    Component.onCompleted: rescan.restart()
}
