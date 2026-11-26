import QtQuick
import QtQuick.Layouts
import "../../../services" as Services
import "../../../components" as Components
import "../../../components/settings" as SettingsUi
import "../../../lib" as Lib

/// Settings → Network → Connection details: each network device's state,
/// speed and addresses (scripts/system/network.py, from nmcli). Addresses, MAC and
/// DNS are private, so they stay hidden until "Show all" — which turns
/// itself off whenever Settings closes or you leave this page.
SettingsUi.SettingsPage {
    id: root
    anchors.fill: parent
    horizontalPadding: 24
    contentSpacing: 16

    property var devices: []
    property string connectivity: ""
    property string message: ""
    property bool showAll: false

    /// Called by SettingsWindow when it closes.
    function windowClosed() { showAll = false; }

    function shown(value) { return showAll ? value : "Hidden"; }
    function rows(device) {
        const out = [
            { label: "Status", value: device.state + (device.connection ? " · " + device.connection : "") },
            { label: "Speed", value: device.speed }
        ];
        const secret = [
            ["IP address", device.ip4.join(", ")], ["Router", device.gateway4], ["DNS servers", device.dns4.join(", ")],
            ["IPv6 address", device.ip6.join(", ")], ["IPv6 router", device.gateway6], ["IPv6 DNS", device.dns6.join(", ")],
            ["Hardware (MAC)", device.mac]
        ];
        for (const [label, value] of secret) out.push({ label: label, value: value, secret: true });
        return out.filter(row => row.value);
    }

    Component.onCompleted: worker.run("details")
    // Keep it current while open (cable plugged, DHCP lease, …).
    // Only while the window shows this page (it stays loaded when hidden).
    Timer { interval: 5000; repeat: true; running: root.pageShown; onTriggered: worker.run("details") }

    Lib.JsonScript {
        id: worker
        script: "system/network.py"
        fallbackError: "Could not read the network details."
        onFailed: message => root.message = message
        onSucceeded: result => {
            root.devices = result.devices;
            root.connectivity = result.connectivity;
            root.message = "";
        }
    }

    Components.Card {
        x: root.horizontalPadding
        width: root.rowWidth
        title: "Connection details"
        description: root.message || ({
            full: "You're online.",
            limited: "Connected to the network, but the internet can't be reached. Try restarting your router.",
            portal: "This network wants you to sign in first (as in a hotel or café). Open a web page to see its sign-in page.",
            none: "Offline.", unknown: "Couldn't check whether the internet is reachable."
        })[root.connectivity] || ""

        Components.SettingsToggle {
            width: parent.width
            label: "Show addresses"
            description: "Technical details someone helping you might ask for. Hidden again when you close Settings."
            checked: root.showAll
            onToggled: value => root.showAll = value
        }
    }

    Repeater {
        model: root.devices

        Components.Card {
            id: deviceCard
            required property var modelData
            x: root.horizontalPadding
            width: root.rowWidth
            title: ({ ethernet: "Cable (Ethernet)", wifi: "Wi-Fi" }[modelData.type] ?? modelData.type)
                + "  ·  " + modelData.device

            Repeater {
                model: root.rows(deviceCard.modelData)
                RowLayout {
                    required property var modelData
                    width: parent.width
                    spacing: 12
                    Components.StyledText {
                        Layout.preferredWidth: 140
                        text: modelData.label
                        color: Services.Colors.surfaceVariantText
                        font.pixelSize: Services.Ui.textBody
                    }
                    Components.StyledText {
                        Layout.fillWidth: true
                        text: modelData.secret ? root.shown(modelData.value) : modelData.value
                        color: modelData.secret && !root.showAll ? Services.Colors.color8 : Services.Colors.foreground
                        font.pixelSize: Services.Ui.textBody
                        wrapMode: Text.WrapAnywhere
                    }
                }
            }
        }
    }
}
