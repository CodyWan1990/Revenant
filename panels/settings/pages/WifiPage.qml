import QtQuick
import "../../../services" as Services
import "../../../components" as Components
import "../../../components/settings" as SettingsUi

/// Settings → Network → Wi-Fi: the radio, and nearby networks to connect,
/// disconnect or forget. Same logic and rows as the bar's network dropdown
/// (services/Wifi.qml, components/WifiNetworkRow.qml). Scans while shown.
SettingsUi.SettingsPage {
    id: root
    anchors.fill: parent
    horizontalPadding: 24
    contentSpacing: 16

    // Scan only while the window shows this page. holdScan counts holders,
    // so setHold() takes or releases exactly one.
    property bool holding: false
    function setHold(on) {
        if (on === holding) return;
        holding = on;
        Services.Wifi.holdScan(on);
    }
    onPageShownChanged: setHold(pageShown)
    Component.onCompleted: setHold(pageShown)
    Component.onDestruction: setHold(false)

    Components.Card {
        x: root.horizontalPadding
        width: root.rowWidth
        title: "Wi-Fi"
        description: !Services.Wifi.wifi ? "This computer has no Wi-Fi. Use a network cable to get online."
            : !Services.Wifi.hardwareEnabled ? "Turned off by a switch or key on the computer (often Fn + a key with an antenna on it)."
            : Services.Wifi.current ? "Connected to " + Services.Wifi.current.name + "."
            : Services.Wifi.on ? "Not connected. Pick a network below." : "Off. Turn it on to see networks nearby."

        Components.SettingsToggle {
            width: parent.width
            visible: !!Services.Wifi.wifi
            label: "Use Wi-Fi"
            checked: Services.Wifi.on
            onToggled: value => Services.Wifi.setOn(value)
        }
    }

    Components.Card {
        x: root.horizontalPadding
        width: root.rowWidth
        visible: !!Services.Wifi.wifi && Services.Wifi.on
        title: "Networks nearby"
        description: Services.Wifi.listed.length === 0 ? "Looking for networks…"
            : "Click a network to join it. A locked one asks for its password once; after that it connects by itself."

        Repeater {
            model: Services.Wifi.on ? Services.Wifi.listed : []
            SettingsUi.WifiNetworkRow {
                required property var modelData
                net: modelData
                wide: true
            }
        }
    }
}
