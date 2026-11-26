import QtQuick
import "../../services" as Services
import ".." as Components
import "../settings" as SettingsUi

/// The Control Center's Bluetooth section: the device list, or why there is
/// none. The caller draws its own header (Scan, on/off) and holds discovery
/// (Services.Radio.holdDiscovery) while this is on screen.
///
/// Pairing limitation: Quickshell registers no BlueZ agent, so "Just Works"
/// devices (headphones, controllers, mice) pair fine; ones that need a PIN or
/// passkey (some keyboards) need an agent such as `bluetoothctl` running.
Column {
    id: root

    property color accent: Services.Colors.color4

    readonly property bool powered: Services.Radio.bluetoothOn
    readonly property var listed: Services.Radio.listedDevices

    width: parent ? parent.width : 340
    spacing: 10

    Components.StyledText {
        width: parent.width
        visible: !Services.Radio.adapter || !root.powered || root.listed.length === 0
        text: !Services.Radio.adapter ? "No Bluetooth adapter."
            : Services.Radio.bluetoothBlocked ? "Blocked by rfkill. Turning it on unblocks it."
            : !root.powered ? "Bluetooth is off."
            : Services.Radio.discovering ? "Searching…" : "No paired devices. Press Scan."
        color: Services.Colors.color8
        font.pixelSize: Services.Ui.textBody
        horizontalAlignment: Text.AlignHCenter
    }

    Repeater {
        model: root.powered ? root.listed : []

        delegate: SettingsUi.BluetoothDeviceRow {
            required property var modelData
            dev: modelData
            accent: root.accent
        }
    }
}
