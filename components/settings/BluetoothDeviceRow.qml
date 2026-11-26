import QtQuick
import QtQuick.Layouts
import "../../services" as Services
import ".." as Components

/// One Bluetooth device: name, status (with battery), and Connect /
/// Disconnect / Pair + Forget. Shared by the bar's Bluetooth dropdown and
/// Settings → Bluetooth; the actions go through Services.Radio.
Rectangle {
    id: row

    required property var dev
    property color accent: Services.Colors.accent
    /// Settings shows "Forget" in words; the dropdown, a compact ✕.
    property bool wide: false
    readonly property bool busy: Services.Radio.deviceBusy(dev)
    /// KeyNavCursor leaf (Settings): Enter connects / disconnects / pairs.
    property bool cursor: false
    function keyActivate() { if (!busy) Services.Radio.toggleDevice(dev); }

    width: parent ? parent.width : 300
    height: 44
    radius: wide ? Services.Ui.radiusSm : 0
    color: dev.connected ? Services.Colors.color0 : cursor ? Services.Ui.menuHoverColor : "transparent"
    border.color: dev.connected ? accent : Services.Colors.color8
    border.width: 1

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 6
        spacing: 8

        Column {
            Layout.fillWidth: true
            spacing: 1
            Components.StyledText {
                width: parent.width
                text: Services.Radio.deviceName(row.dev)
                color: Services.Colors.foreground
                font.pixelSize: Services.Ui.textBody
                elide: Text.ElideRight
            }
            Components.StyledText {
                text: Services.Radio.deviceStatus(row.dev)
                color: row.dev.connected ? row.accent : Services.Colors.color8
                font.pixelSize: Services.Ui.textCaption
            }
        }

        Components.TextButton {
            enabled: !row.busy
            buttonHeight: 28
            text: row.dev.connected ? "Disconnect" : row.dev.paired ? "Connect" : "Pair"
            onClicked: Services.Radio.toggleDevice(row.dev)
        }
        Components.TextButton {
            visible: row.dev.paired && !row.dev.connected
            buttonHeight: 28
            horizontalPadding: row.wide ? 14 : 8
            text: row.wide ? "Forget" : "✕"
            hoverColor: Services.Colors.red
            onClicked: row.dev.forget()
        }
    }
}
