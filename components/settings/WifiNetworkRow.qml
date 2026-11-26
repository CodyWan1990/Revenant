import QtQuick
import QtQuick.Layouts
import "../../services" as Services
import ".." as Components

/// One Wi-Fi network: signal, name (with a lock when secured), status, and
/// Connect/Disconnect + Forget. Shared by the bar's network dropdown and
/// Settings → Network → Wi-Fi; the actions go through Services.Wifi.
Rectangle {
    id: row

    required property var net
    property color accent: Services.Colors.accent
    /// Settings shows "Forget" in words; the dropdown, a compact ✕.
    property bool wide: false
    /// KeyNavCursor leaf (Settings): Enter connects / disconnects.
    property bool cursor: false
    function keyActivate() { toggle(); }

    function toggle() {
        if (net.stateChanging) return;
        if (net.connected) net.disconnect();
        else Services.Wifi.connectTo(net);
    }

    width: parent ? parent.width : 300
    height: 44
    radius: wide ? Services.Ui.radiusSm : 0
    color: net.connected ? Services.Colors.color0 : cursor ? Services.Ui.menuHoverColor : "transparent"
    border.color: net.connected ? accent : Services.Colors.color8
    border.width: 1

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 6
        spacing: 8

        Components.StyledText {
            text: Services.Wifi.signalGlyph(row.net.signalStrength)
            color: row.net.connected ? row.accent : Services.Colors.foreground
            font.pixelSize: Services.Ui.textSubtitleLarge
        }

        Column {
            Layout.fillWidth: true
            spacing: 1
            Components.StyledText {
                width: parent.width
                text: row.net.name + (Services.Wifi.isOpen(row.net) ? "" : "  " + Services.Icons.glyph("lock", "nerd"))
                color: Services.Colors.foreground
                font.pixelSize: Services.Ui.textBody
                elide: Text.ElideRight
            }
            Components.StyledText {
                text: Services.Wifi.status(row.net)
                color: row.net.connected ? row.accent : Services.Colors.color8
                font.pixelSize: Services.Ui.textCaption
            }
        }

        Components.TextButton {
            enabled: !row.net.stateChanging
            buttonHeight: 28
            text: row.net.connected ? "Disconnect" : "Connect"
            onClicked: row.toggle()
        }
        Components.TextButton {
            visible: row.net.known && !row.net.connected
            buttonHeight: 28
            horizontalPadding: row.wide ? 14 : 8
            text: row.wide ? "Forget" : "✕"
            hoverColor: Services.Colors.red
            onClicked: row.net.forget()
        }
    }
}
