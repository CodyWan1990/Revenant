import QtQuick
import "../../../services" as Services
import "../../../components" as Components
import "../../../components/settings" as SettingsUi

/// Settings → Network → Overview: Wi-Fi and Bluetooth on/off in one place,
/// with what is connected. The same switches as the Wi-Fi and Bluetooth
/// pages (services/Wifi.qml, services/Radio.qml).
SettingsUi.SettingsPage {
    id: root
    anchors.fill: parent
    horizontalPadding: 24
    contentSpacing: 16

    readonly property var wired: Services.Wifi.wired
    readonly property var btConnected: Services.Radio.connectedDevices
    /// "2.5 Gb/s" rather than "2500 Mb/s".
    function speed(mbps) { return mbps >= 1000 ? (mbps / 1000) + " Gb/s" : mbps + " Mb/s"; }

    Components.Card {
        x: root.horizontalPadding
        width: root.rowWidth
        title: root.wired?.connected || Services.Wifi.current ? "You're connected" : "You're not connected"
        description: root.wired?.connected
            ? "Using a network cable" + (root.wired.linkSpeed > 0 ? " (" + root.speed(root.wired.linkSpeed) + ")." : ".")
            : Services.Wifi.current ? "Using the Wi-Fi network \"" + Services.Wifi.current.name + "\"."
            : Services.Wifi.wifi ? "Plug in a network cable, or turn Wi-Fi on and pick a network under Network → Wi-Fi."
            : "Plug in a network cable to get online."

        Components.SettingsToggle {
            width: parent.width
            visible: !!Services.Wifi.wifi
            label: "Wi-Fi"
            description: !Services.Wifi.hardwareEnabled ? "Turned off by a switch or key on the computer (often Fn + a key with an antenna on it)."
                : Services.Wifi.current ? "Connected to " + Services.Wifi.current.name + "."
                : Services.Wifi.on ? "On, but not connected. Pick a network under Network → Wi-Fi." : "Off."
            checked: Services.Wifi.on
            onToggled: value => Services.Wifi.setOn(value)
        }

        Components.SettingsToggle {
            width: parent.width
            visible: !!Services.Radio.adapter
            label: "Bluetooth"
            description: Services.Radio.bluetoothBlocked ? "Switched off at the system level. Turning it on here switches it back on."
                : !Services.Radio.bluetoothOn ? "Off. For wireless headphones, mice and keyboards."
                : root.btConnected.length === 0 ? "On, nothing connected. Add devices under Devices → Bluetooth."
                : "Connected: " + root.btConnected.map(d => Services.Radio.deviceName(d)).join(", ") + "."
            checked: Services.Radio.bluetoothOn
            onToggled: value => Services.Radio.setBluetooth(value)
        }

        Components.StyledText {
            width: parent.width
            visible: !Services.Wifi.wifi && !Services.Radio.adapter
            text: "No Wi-Fi card or Bluetooth adapter found."
            color: Services.Colors.surfaceVariantText
            font.pixelSize: Services.Ui.textSmall
        }
    }
}
