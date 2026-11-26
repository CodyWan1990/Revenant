import QtQuick
import QtQuick.Layouts
import "../../services" as Services
import ".." as Components
import "../settings" as SettingsUi

/// The Control Center's Network section:
/// wired status, the traffic graph and the Wi-Fi network list. The caller
/// draws its own header (with the on/off switch) and holds the Wi-Fi scan
/// (Services.Wifi.holdScan) while this is on screen.
Column {
    id: root

    property color accent: Services.Colors.color6
    property bool showTraffic: true
    property int maxNetworks: 12

    readonly property var wifi: Services.Wifi.wifi
    readonly property var wired: Services.Wifi.wired
    readonly property bool wifiOn: Services.Wifi.on
    readonly property var listed: Services.Wifi.listed

    width: parent ? parent.width : 340
    spacing: 10

    // Wired status, when there is a wired card.
    Components.StyledText {
        visible: !!root.wired
        width: parent.width
        text: Services.Icons.glyph("ethernet", "nerd") + "  Ethernet: " + (root.wired?.connected
            ? "connected" + (root.wired.linkSpeed > 0 ? " · " + root.wired.linkSpeed + " Mb/s" : "")
            : "disconnected")
        color: root.wired?.connected ? root.accent : Services.Colors.color8
        font.pixelSize: Services.Ui.textSmall
    }

    // ─── Traffic on the default route (services/SystemStats.qml) ───
    // SystemStats samples all the time, so the graph is already three
    // minutes deep when the dropdown opens.
    Column {
        width: parent.width
        spacing: 8
        visible: root.showTraffic

        Components.Divider { }

        RowLayout {
            width: parent.width
            Components.StyledText {
                text: "Traffic"
                color: Services.Colors.foreground
                font.pixelSize: Services.Ui.textBody
                font.bold: true
                Layout.fillWidth: true
            }
            Components.StyledText {
                text: "↓ " + Services.SystemStats.netRx
                color: root.accent
                font.pixelSize: Services.Ui.textBody
            }
            Components.StyledText {
                text: "↑ " + Services.SystemStats.netTx
                color: Services.Colors.color5
                font.pixelSize: Services.Ui.textBody
                Layout.leftMargin: 10
            }
        }

        Components.MiniGraph {
            width: parent.width
            graphHeight: 110
            values: Services.SystemStats.rxHistory
            color: root.accent
            name: "Download"
            values2: Services.SystemStats.txHistory
            color2: Services.Colors.color5
            name2: "Upload"
            maxValue: 0   // scale to the traffic shown
            format: value => Services.SystemStats.formatRate(value)
        }
    }

    Components.Divider { }

    Components.StyledText {
        width: parent.width
        visible: !root.wifi || !root.wifiOn || root.listed.length === 0
        text: !root.wifi ? "No Wi-Fi card."
            : !Services.Wifi.hardwareEnabled ? "Wi-Fi is blocked by a hardware switch."
            : !root.wifiOn ? "Wi-Fi is off."
            : "Searching…"
        color: Services.Colors.color8
        font.pixelSize: Services.Ui.textBody
        horizontalAlignment: Text.AlignHCenter
    }

    Repeater {
        model: root.wifiOn ? root.listed.slice(0, root.maxNetworks) : []

        delegate: SettingsUi.WifiNetworkRow {
            required property var modelData
            net: modelData
            accent: root.accent
        }
    }
}
