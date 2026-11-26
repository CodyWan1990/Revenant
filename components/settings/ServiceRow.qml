import QtQuick
import QtQuick.Layouts
import "../../services" as Services
import ".." as Components

/// One systemd service in Settings → System → Systemd, written for people
/// who don't know systemd. Collapsed: a status dot, the service's name and a
/// plain status ("Running · Starts automatically"). Click to expand: what it
/// is, a "Start automatically" switch, Start / Stop / Restart, its log, and
/// Remove for services made on the page.
///
/// The page owns which row is open, which one is asking "are you sure?",
/// and the log text, so they survive the list refreshing every few seconds.
/// `service` is one entry of scripts/system/services.py's list.
Rectangle {
    id: row

    property var service: ({})
    /// "user" or "system": what "automatically" means (login or boot).
    property string scope: "user"
    property bool expanded: false
    /// The operation waiting for "are you sure?" ("stop" | "disable"), or "".
    property string confirming: ""
    /// This service's log while it's shown, else "".
    property string logText: ""
    property bool busy: false

    signal toggleExpanded()
    /// start | stop | restart | enable | disable | remove | log | hidelog |
    /// confirm (yes to `confirming`) | cancel
    signal action(string operation)

    readonly property bool failed: service.state === "failed"
    readonly property bool canAutostart: service.enabled === "enabled" || service.enabled === "disabled"
    readonly property bool autostarts: service.enabled === "enabled"
    readonly property string when: scope === "user" ? "when you log in" : "when the computer starts"

    function statusText() {
        if (failed) return "Failed";
        if (service.state === "activating" || service.state === "reloading") return "Starting…";
        if (service.running && service.sub === "exited") return "Done (it ran its job)";
        if (service.running) return "Running";
        return "Stopped";
    }
    function autostartText() {
        if (service.transient) return "Started by an app";
        if (service.enabled === "enabled") return "Starts automatically";
        if (service.enabled === "disabled") return "Doesn't start automatically";
        // static, indirect, generated, alias: started by something else.
        return "Started when needed";
    }

    width: parent ? parent.width : 400
    implicitHeight: body.implicitHeight + 12
    radius: Services.Ui.radiusSm
    color: expanded ? Services.Ui.fieldColor : hover.hovered ? Services.Ui.menuHoverColor : "transparent"
    HoverHandler { id: hover }

    ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 6
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 10

        // ─── Summary line (click to open) ───
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 9
                Layout.preferredHeight: 9
                radius: 4.5
                color: row.failed ? Services.Colors.red
                    : row.service.sub === "running" ? Services.Colors.green
                    : row.service.running ? Services.Colors.accent : Services.Colors.color8
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Components.StyledText {
                        Layout.fillWidth: true
                        text: row.service.name ?? ""
                        font.pixelSize: Services.Ui.textBody
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Components.StyledText {
                        visible: row.service.essential === true
                        text: "Needed by your session"
                        color: Services.Colors.yellow
                        font.pixelSize: Services.Ui.textCaption
                    }
                    Components.StyledText {
                        visible: row.service.created === true
                        text: "Made here"
                        color: Services.Colors.accent
                        font.pixelSize: Services.Ui.textCaption
                    }
                }
                Components.StyledText {
                    Layout.fillWidth: true
                    text: row.statusText() + "  ·  " + row.autostartText()
                    color: row.failed ? Services.Colors.red : Services.Colors.surfaceVariantText
                    font.pixelSize: Services.Ui.textCaption
                    elide: Text.ElideRight
                }
            }
            Components.StyledText {
                text: row.expanded ? "" : ""
                color: Services.Colors.surfaceVariantText
                font.family: Services.Settings.fontFamily
                font.pixelSize: Services.Ui.textSmall
            }
            MouseArea {
                parent: row
                x: 0
                y: 0
                width: row.width
                height: 44
                cursorShape: Qt.PointingHandCursor
                onClicked: row.toggleExpanded()
            }
        }

        // ─── Details ───
        ColumnLayout {
            Layout.fillWidth: true
            visible: row.expanded
            spacing: 10

            Components.StyledText {
                Layout.fillWidth: true
                text: row.service.about || "No description for this one. Its name is " + row.service.unit + "."
                wrapMode: Text.WordWrap
                font.pixelSize: Services.Ui.textSmall
            }
            Components.StyledText {
                Layout.fillWidth: true
                visible: row.service.essential === true
                text: "Your session relies on this. Stopping it can cut sound, network, login or other basics until you restart."
                color: Services.Colors.yellow
                wrapMode: Text.WordWrap
                font.pixelSize: Services.Ui.textCaption
            }
            Components.StyledText {
                Layout.fillWidth: true
                visible: row.failed
                text: "It stopped with an error. \"Show log\" shows its last messages, which usually say why."
                color: Services.Colors.red
                wrapMode: Text.WordWrap
                font.pixelSize: Services.Ui.textCaption
            }

            Components.SettingsToggle {
                Layout.fillWidth: true
                visible: row.canAutostart && !row.service.transient
                label: "Start automatically"
                description: "Starts " + row.when + "." + (row.scope === "system" ? " Changing this asks for your password." : "")
                checked: row.autostarts
                onToggled: on => row.action(on ? "enable" : "disable")
            }

            // "Are you sure?" for essential services.
            Rectangle {
                Layout.fillWidth: true
                visible: row.confirming !== ""
                implicitHeight: confirmBody.implicitHeight + 20
                radius: Services.Ui.radiusSm
                color: "transparent"
                border.color: Services.Colors.yellow
                border.width: 1
                Column {
                    id: confirmBody
                    x: 10
                    y: 10
                    width: parent.width - 20
                    spacing: 8
                    Components.StyledText {
                        width: parent.width
                        text: row.confirming === "stop"
                            ? "Stop " + row.service.name + "? Things that depend on it stop working until it's started again or you restart."
                            : "Stop " + row.service.name + " from starting " + row.when + "? Things that depend on it won't work next time."
                        wrapMode: Text.WordWrap
                        font.pixelSize: Services.Ui.textSmall
                    }
                    Row {
                        spacing: 8
                        Components.TextButton {
                            text: row.confirming === "stop" ? "Stop it" : "Turn it off"
                            buttonHeight: 28
                            hoverColor: Services.Colors.red
                            enabled: !row.busy
                            onClicked: row.action("confirm")
                        }
                        Components.TextButton {
                            text: "Keep it"
                            buttonHeight: 28
                            fontBold: true
                            onClicked: row.action("cancel")
                        }
                    }
                }
            }

            Flow {
                Layout.fillWidth: true
                spacing: 8
                Components.TextButton {
                    visible: !row.service.running
                    text: "Start"
                    buttonHeight: 28
                    fontBold: true
                    enabled: !row.busy
                    onClicked: row.action("start")
                }
                Components.TextButton {
                    visible: row.service.running === true
                    text: "Restart"
                    buttonHeight: 28
                    enabled: !row.busy
                    onClicked: row.action("restart")
                }
                Components.TextButton {
                    visible: row.service.running === true
                    text: "Stop"
                    buttonHeight: 28
                    enabled: !row.busy
                    onClicked: row.action("stop")
                }
                Components.TextButton {
                    text: row.logText ? "Hide log" : "Show log"
                    buttonHeight: 28
                    enabled: !row.busy
                    onClicked: row.action(row.logText ? "hidelog" : "log")
                }
                Components.TextButton {
                    visible: row.service.created === true
                    text: "Remove"
                    buttonHeight: 28
                    hoverColor: Services.Colors.red
                    enabled: !row.busy
                    onClicked: row.action("remove")
                }
            }

            Rectangle {
                Layout.fillWidth: true
                visible: row.logText !== ""
                implicitHeight: logView.implicitHeight + 16
                radius: Services.Ui.radiusSm
                color: Services.Colors.background
                Text {
                    id: logView
                    x: 8
                    y: 8
                    width: parent.width - 16
                    text: row.logText
                    color: Services.Colors.foreground
                    font.family: "monospace"
                    font.pixelSize: Services.Ui.textCaption
                    wrapMode: Text.WrapAnywhere
                    textFormat: Text.PlainText
                }
            }

            Components.StyledText {
                Layout.fillWidth: true
                text: "Technical name: " + row.service.unit + "  ·  state " + row.service.state + "/" + row.service.sub
                    + "  ·  " + row.service.enabled
                color: Services.Colors.surfaceVariantText
                font.pixelSize: Services.Ui.textCaption
                elide: Text.ElideRight
            }
        }
    }
}
