import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../services" as Services
import ".." as Components

/// One row of Settings → Autostart: icon, name, a small detail line, and a
/// switch. With `editable`, clicking the name edits it in place (name,
/// command, delay); with `removable`, × removes it.
Rectangle {
    id: row

    property string name
    property string detail
    property string icon
    property bool service: false
    property bool checked: false
    property bool editable: false
    property bool removable: false
    property string command
    property int delay: 0
    property bool busy: false
    signal toggled(bool on)
    signal removed()
    signal edited(string name, string command, int delay)

    property bool editing: false

    width: parent ? parent.width : 400
    implicitHeight: body.implicitHeight + 12
    radius: Services.Ui.radiusSm
    color: editing ? Services.Ui.fieldColor : hover.hovered ? Services.Ui.menuHoverColor : "transparent"

    HoverHandler { id: hover }

    ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 6
        anchors.leftMargin: 10
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Item {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                Image {
                    id: appIcon
                    anchors.fill: parent
                    source: row.icon ? Quickshell.iconPath(row.icon, true) : ""
                    sourceSize.width: 48
                    sourceSize.height: 48
                    visible: status === Image.Ready
                    asynchronous: true
                }
                Text {
                    anchors.centerIn: parent
                    visible: !appIcon.visible
                    text: row.service ? "" : ""
                    color: Services.Colors.surfaceVariantText
                    font.family: Services.Settings.fontFamily
                    font.pixelSize: Services.Ui.textSubtitleLarge
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Components.StyledText {
                    Layout.fillWidth: true
                    text: row.name
                    font.pixelSize: Services.Ui.textBody
                    font.bold: true
                    elide: Text.ElideRight
                }
                Components.StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: row.detail
                    color: Services.Colors.surfaceVariantText
                    font.pixelSize: Services.Ui.textCaption
                    elide: Text.ElideRight
                }
                MouseArea {
                    parent: row
                    anchors.fill: parent
                    anchors.rightMargin: 110
                    anchors.bottomMargin: row.editing ? row.height - 40 : 0
                    enabled: row.editable && !row.busy
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    z: -1
                    onClicked: {
                        row.editing = !row.editing;
                        if (row.editing) {
                            nameField.text = row.name;
                            commandField.text = row.command;
                            delaySlider.value = row.delay;
                        }
                    }
                }
            }

            Components.TextButton {
                visible: row.removable
                text: "×"
                width: 28
                buttonHeight: 26
                fontSize: Services.Ui.textSubtitleLarge
                idleColor: "transparent"
                idleTextColor: Services.Colors.surfaceVariantText
                hoverColor: Services.Colors.red
                borderWidth: 0
                enabled: !row.busy
                Accessible.name: "Remove " + row.name
                onClicked: row.removed()
            }

            Components.SettingsToggle {
                Layout.preferredWidth: 56
                label: ""
                checked: row.checked
                enabled: !row.busy
                onToggled: value => row.toggled(value)
            }
        }

        // Edit in place.
        ColumnLayout {
            Layout.fillWidth: true
            visible: row.editing
            spacing: 6
            Components.LabeledSettingRow {
                Layout.fillWidth: true
                label: "Name"
                labelWidth: 80
                Components.SettingField { id: nameField; width: parent.width }
            }
            Components.LabeledSettingRow {
                Layout.fillWidth: true
                label: "Command"
                labelWidth: 80
                Components.SettingField { id: commandField; width: parent.width }
            }
            Components.StyledSlider {
                id: delaySlider
                Layout.fillWidth: true
                label: "Start after"; labelWidth: 80; from: 0; to: 60; stepSize: 1; suffix: " s"
            }
            Row {
                spacing: 8
                Components.TextButton {
                    text: "Save"
                    fontBold: true
                    enabled: !row.busy && nameField.text.trim() !== "" && commandField.text.trim() !== ""
                    onClicked: {
                        row.edited(nameField.text, commandField.text, Math.round(delaySlider.value));
                        row.editing = false;
                    }
                }
                Components.TextButton {
                    text: "Cancel"
                    onClicked: row.editing = false
                }
            }
        }
    }
}
