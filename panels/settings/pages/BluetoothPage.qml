import QtQuick
import "../../../services" as Services
import "../../../components" as Components
import "../../../components/settings" as SettingsUi

/// Settings → Bluetooth: adapter power, and paired / nearby devices to
/// connect, pair or forget. Same logic and rows as the bar's Bluetooth
/// dropdown (services/Radio.qml, components/BluetoothDeviceRow.qml).
/// Discovery runs only while this page is open and you asked for it.
SettingsUi.SettingsPage {
    id: root
    anchors.fill: parent
    horizontalPadding: 24
    contentSpacing: 16

    // Discover only while the window shows this page. holdDiscovery counts
    // holders, so setHold() takes or releases exactly one.
    property bool holding: false
    function setHold(on) {
        if (on === holding) return;
        holding = on;
        Services.Radio.holdDiscovery(on);
    }
    onPageShownChanged: setHold(pageShown)
    Component.onCompleted: setHold(pageShown)
    Component.onDestruction: setHold(false)

    Components.Card {
        x: root.horizontalPadding
        width: root.rowWidth
        title: "Bluetooth"
        description: !Services.Radio.adapter ? "This computer has no Bluetooth."
            : "For wireless headphones, speakers, mice, keyboards and game controllers."

        Components.SettingsToggle {
            width: parent.width
            visible: !!Services.Radio.adapter
            label: "Use Bluetooth"
            description: Services.Radio.bluetoothBlocked ? "Switched off at the system level. Turning it on here switches it back on." : ""
            checked: Services.Radio.bluetoothOn
            onToggled: value => Services.Radio.setBluetooth(value)
        }
    }

    Components.Card {
        x: root.horizontalPadding
        width: root.rowWidth
        visible: Services.Radio.bluetoothOn
        title: "Devices"
        description: Services.Radio.discovering
            ? "Looking for devices… New ones appear below; click one to pair it."
            : Services.Radio.listedDevices.length === 0 ? "No devices yet. Add one with the button below."
            : "Click a device to connect or disconnect it."

        Components.TextButton {
            text: Services.Radio.discovering ? "Stop looking" : "Add a device"
            onClicked: Services.Radio.setDiscovery(!Services.Radio.discovering)
        }
        Components.StyledText {
            width: parent.width
            visible: Services.Radio.discovering
            text: "Put the device in pairing mode first — usually by holding its power or Bluetooth button "
                + "until a light flashes. (A device that asks you to type a PIN can't be paired here yet; "
                + "use bluetoothctl in a terminal for those.)"
            color: Services.Colors.surfaceVariantText
            font.pixelSize: Services.Ui.textSmall
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: Services.Radio.listedDevices
            SettingsUi.BluetoothDeviceRow {
                required property var modelData
                dev: modelData
                wide: true
            }
        }
    }
}
