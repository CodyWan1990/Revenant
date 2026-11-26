import QtQuick
import "../../../services" as Services
import "../../../components" as Components
import "../../../components/settings" as SettingsUi
import "../../../lib" as Lib

/// Settings → Autostart, kept as simple as other desktops' startup settings
/// (scripts/system/autostart.py):
///   Startup apps         login items that run under i3 (yours and the
///                        system's), each with a switch; + Add for an
///                        installed app or a command; click yours to edit
///   Background services  the user services worth choosing, each a switch
///                        (on = running now and at login)
/// Session plumbing (D-Bus, PipeWire, keyring, …), login items i3 doesn't
/// run, and i3's own exec lines are not listed.
SettingsUi.SettingsPage {
    id: root
    anchors.fill: parent
    horizontalPadding: 24
    contentSpacing: 16

    property var entries: []
    property string message: ""
    property bool dexInstalled: true
    /// Adding: "" (closed) | "app" | "custom"
    property string formMode: ""

    readonly property bool busy: worker.running || queued !== null
    function shown(e) { return e.runsHere && !e.essential && !e.plumbing; }
    readonly property var startupApps: entries.filter(e => e.source === "xdg" && shown(e))
        .sort((a, b) => a.name.localeCompare(b.name))
    readonly property var services: entries.filter(e => e.source === "systemd" && shown(e))
        .sort((a, b) => a.name.localeCompare(b.name))

    /// A click during the background refresh waits and runs right after it.
    property var queued: null
    function run(operation, args = []) {
        if (worker.run(operation, args)) message = "";
        else queued = { operation: operation, args: args };
    }
    function runQueued() {
        if (!queued) return;
        const next = queued;
        queued = null;
        run(next.operation, next.args);
    }

    Component.onCompleted: run("list")
    // Only while the Settings window shows this page (it stays loaded when hidden).
    Timer { interval: 5000; repeat: true; running: !root.busy && root.pageShown; onTriggered: worker.run("list") }

    Lib.JsonScript {
        id: worker
        script: "system/autostart.py"
        fallbackError: "Could not read or change the autostart entries."
        onFailed: message => { root.message = message; root.runQueued(); }
        onSucceeded: (result, operation) => {
            root.entries = result.entries;
            root.dexInstalled = result.dex ?? true;
            if (operation === "add-app" || operation === "add-custom") root.formMode = "";
            // A background refresh ("list") must not wipe the last message.
            if (operation !== "list") root.message = ({
                "add-app": "Added. It starts at your next login.", "add-custom": "Added. It starts at your next login.",
                edit: "Saved.", remove: "Removed."
            })[operation] ?? "";
            Qt.callLater(root.runQueued);
        }
    }

    // ─── Startup apps ───
    Components.Card {
        x: root.horizontalPadding
        width: root.rowWidth
        title: "Startup apps"
        description: "Started when you log in. Click one of yours to edit it."

        Components.StyledText {
            width: parent.width
            visible: !root.dexInstalled
            text: "dex isn't installed, so these don't start. Install dex and add "
                + "`exec --no-startup-id dex --autostart --environment i3` to your i3 config."
            color: Services.Colors.yellow
            font.pixelSize: Services.Ui.textSmall
            wrapMode: Text.WordWrap
        }

        Column {
            width: parent.width
            spacing: 2
            Repeater {
                model: root.startupApps
                SettingsUi.StartupRow {
                    required property var modelData
                    width: parent.width
                    name: modelData.name
                    detail: modelData.origin === "linked" ? "A link to a file kept elsewhere"
                        : modelData.delay ? "Starts after " + modelData.delay + " s" : (modelData.comment || "")
                    icon: modelData.icon
                    checked: modelData.enabled
                    // Yours to edit or remove; a changed system one can be reset (×).
                    editable: modelData.editable && modelData.origin !== "system"
                    removable: modelData.removable
                    command: modelData.command
                    delay: modelData.delay
                    busy: root.busy
                    onToggled: on => root.run(on ? "enable" : "disable", [modelData.id])
                    onRemoved: root.run("remove", [modelData.id])
                    onEdited: (name, command, delay) => root.run("edit", [modelData.id, name, command, String(delay)])
                }
            }
        }

        // ─── Add ───
        Components.TextButton {
            visible: root.formMode === ""
            text: "+ Add"
            enabled: !root.busy
            onClicked: { root.formMode = "app"; appPicker.currentValue = ""; appPicker.expand(); }
        }
        Column {
            width: parent.width
            spacing: 10
            visible: root.formMode !== ""

            SettingsUi.AppPicker {
                id: appPicker
                width: parent.width
                labelWidth: 90
                visible: root.formMode === "app"
                onPicked: app => root.run("add-app", [app.id])
            }
            Components.LabeledSettingRow {
                width: parent.width
                label: "Name"
                labelWidth: 90
                visible: root.formMode === "custom"
                Components.SettingField { id: nameField; width: parent.width }
            }
            Components.LabeledSettingRow {
                width: parent.width
                label: "Command"
                labelWidth: 90
                visible: root.formMode === "custom"
                Components.SettingField { id: commandField; width: parent.width; placeholder: "Runs with sh: pipes, && and quotes work" }
            }
            Row {
                spacing: 8
                Components.TextButton {
                    visible: root.formMode === "custom"
                    text: "Add"
                    fontBold: true
                    enabled: !root.busy && nameField.text.trim() !== "" && commandField.text.trim() !== ""
                    onClicked: root.run("add-custom", [nameField.text, commandField.text])
                }
                Components.TextButton {
                    visible: root.formMode === "app"
                    text: "Custom command…"
                    onClicked: { root.formMode = "custom"; nameField.text = ""; commandField.text = ""; }
                }
                Components.TextButton {
                    text: "Cancel"
                    onClicked: root.formMode = ""
                }
            }
        }

        Components.StyledText {
            width: parent.width
            visible: text !== ""
            text: root.message
            wrapMode: Text.WordWrap
            color: root.message.startsWith("Could") || root.message.includes("rejected") || root.message.includes("changed")
                ? Services.Colors.red : Services.Colors.surfaceVariantText
            font.pixelSize: Services.Ui.textSmall
        }
    }

    // ─── Background services ───
    Components.Card {
        x: root.horizontalPadding
        width: root.rowWidth
        visible: root.services.length > 0
        title: "Background services"
        description: "Your user services. On means running now and at every login."

        Column {
            width: parent.width
            spacing: 2
            Repeater {
                model: root.services
                SettingsUi.StartupRow {
                    required property var modelData
                    width: parent.width
                    name: modelData.name
                    detail: modelData.comment
                    service: true
                    checked: modelData.enabled
                    busy: root.busy
                    onToggled: on => root.run(on ? "enable" : "disable", [modelData.id])
                }
            }
        }
    }

    // ─── Login volume (scripts/system/session.py) ───
    Components.Card {
        x: root.horizontalPadding
        width: root.rowWidth
        title: "At login"
        description: "Applied once each time you log in, when the shell starts. Restarting the shell leaves your volume alone."

        Components.SettingsToggle {
            width: parent.width
            label: "Set the volume at login"
            checked: (Services.Session.values.LOGIN_VOLUME ?? -1) >= 0
            enabled: Services.Session.ready
            onToggled: value => Services.Session.set("LOGIN_VOLUME", value ? 30 : -1)
        }
        Components.StyledSlider {
            width: parent.width
            visible: (Services.Session.values.LOGIN_VOLUME ?? -1) >= 0
            label: "Volume"; from: 0; to: 100; stepSize: 5; suffix: "%"
            value: Services.Session.values.LOGIN_VOLUME ?? -1
            onMoved: value => Services.Session.set("LOGIN_VOLUME", Math.round(value))
        }
    }
}
