import QtQuick
import QtQuick.Layouts
import "../../../services" as Services
import "../../../components" as Components
import "../../../components/settings" as SettingsUi
import "../../../lib" as Lib

/// Settings → Network → Saved networks: every saved NetworkManager profile,
/// including Wi-Fi out of range and VPNs (scripts/system/network.py, nmcli).
/// Connect / disconnect, auto-connect on or off, delete. Delete takes two
/// clicks, and netplan's generated profiles say what deleting them breaks.
/// Changing a system-wide profile may ask for your password (polkit).
SettingsUi.SettingsPage {
    id: root
    anchors.fill: parent
    horizontalPadding: 24
    contentSpacing: 16

    property var connections: []
    property string message: ""
    /// uuid awaiting the second "Delete" click.
    property string confirmDelete: ""
    readonly property bool busy: worker.running || queued !== null

    /// A click that lands during the background refresh would be refused
    /// (one nmcli run at a time), so it waits here and runs right after.
    property var queued: null
    function run(operation, args = []) {
        if (worker.run(operation, args)) { message = ""; confirmDelete = ""; }
        else queued = { operation: operation, args: args };
    }
    function runQueued() {
        if (!queued) return;
        const next = queued;
        queued = null;
        run(next.operation, next.args);
    }
    function isNetplan(c) { return c.name.startsWith("netplan-"); }

    Component.onCompleted: run("connections")
    Timer { interval: 5000; repeat: true; running: !root.busy; onTriggered: worker.run("connections") }

    Lib.JsonScript {
        id: worker
        script: "system/network.py"
        fallbackError: "Could not read or change the saved connections."
        onFailed: message => { root.message = message; root.runQueued(); }
        onSucceeded: (result, operation) => {
            root.connections = result.connections;
            Qt.callLater(root.runQueued);
            if (operation !== "connections") root.message = ({
                up: "Connected.", down: "Disconnected.", autoconnect: "Saved.", delete: "Deleted."
            })[operation] ?? "";
        }
    }

    Components.Card {
        x: root.horizontalPadding
        width: root.rowWidth
        title: "Saved networks"
        description: root.busy ? "Working…" : root.message
            || "Networks and VPNs this computer remembers. Switch one on to have it connect by itself whenever it's in reach."

        Repeater {
            model: root.connections

            Column {
                id: entry
                required property var modelData
                readonly property var conn: modelData
                width: parent.width
                spacing: 4

                RowLayout {
                    width: parent.width
                    spacing: 8

                    Components.SettingsToggle {
                        Layout.fillWidth: true
                        label: entry.conn.name + (entry.conn.active ? "  ·  connected now" : "")
                        description: entry.conn.type + (entry.conn.device ? " on " + entry.conn.device : "")
                        checked: entry.conn.autoconnect
                        enabled: !root.busy
                        onToggled: value => root.run("autoconnect", [entry.conn.uuid, value ? "yes" : "no"])
                    }
                    Components.TextButton {
                        text: entry.conn.active ? "Disconnect" : "Connect"
                        enabled: !root.busy
                        onClicked: root.run(entry.conn.active ? "down" : "up", [entry.conn.uuid])
                    }
                    Components.TextButton {
                        text: root.confirmDelete === entry.conn.uuid ? "Really delete?" : "Delete"
                        enabled: !root.busy
                        hoverColor: Services.Colors.red
                        idleBorderColor: root.confirmDelete === entry.conn.uuid ? Services.Colors.red : Services.Ui.subtleBorder
                        onClicked: root.confirmDelete === entry.conn.uuid
                            ? root.run("delete", [entry.conn.uuid])
                            : root.confirmDelete = entry.conn.uuid
                    }
                }

                Components.StyledText {
                    width: parent.width
                    visible: root.confirmDelete === entry.conn.uuid || (root.isNetplan(entry.conn) && entry.conn.active)
                    text: root.isNetplan(entry.conn)
                        ? "Made by netplan (Ubuntu's network setup). Deleting it removes this network's configuration; it may not come back until you set it up again."
                        : "Click again to forget it. You'd need its password to join again."
                    color: root.confirmDelete === entry.conn.uuid ? Services.Colors.red : Services.Colors.surfaceVariantText
                    font.pixelSize: Services.Ui.textSmall
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
