import QtQuick
import "../services" as Services
import "../components" as Components

/// Wi-Fi password prompt (cf. Dux Shell's WifiPasswordModal, MIT).
/// A keyboard panel, not part of the Wi-Fi dropdown: dropdowns are X11
/// override-redirect PopupWindows and never receive keys. Opened through
/// Services.Actions.wifiPassword(network, error) by services/Wifi.qml.
Components.OverlayPanel {
    id: panel

    property var network: null
    property string error: ""

    function ask(net, err) {
        network = net;
        error = err ?? "";
        open();
    }

    function submit() {
        if (!network || field.text.length === 0) return;
        network.connectWithPsk(field.text);
        close();
    }

    onOpened: field.clear()
    onFocusRequested: field.takeFocus()
    // Never keep a typed secret around after the prompt goes away.
    onIsOpenChanged: if (!isOpen) field.text = ""

    Components.OverlaySurface {
        anchors.centerIn: parent
        width: 400
        height: 196
        opacity: panel.contentOpacity

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            Components.StyledText {
                text: String.fromCodePoint(0xF0928) + "  Connect to “" + (panel.network?.name ?? "") + "”"
                color: Services.Colors.foreground
                font.pixelSize: Services.Ui.textSubtitleLarge
                font.bold: true
                width: parent.width
                elide: Text.ElideRight
            }

            Components.PasswordField {
                id: field
                width: parent.width
                onAccepted: panel.submit()
                onCancelled: panel.close()
            }

            Components.StyledText {
                width: parent.width
                height: 16
                text: panel.error
                color: Services.Colors.red
                font.pixelSize: Services.Ui.textSmall
            }

            Components.StyledText {
                text: "Enter connect · Esc cancel · Ctrl+H " + (field.reveal ? "hide" : "show")
                color: Services.Colors.color8
                font.pixelSize: Services.Ui.textSmall
            }
        }
    }
}
