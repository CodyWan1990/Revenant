import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../services" as Services
import "../components" as Components
import "../components/bar" as BarUi

Item {
    id: root

    property var bar: null
    property var instance: ({})
    property var device: null
    property string lightingMessage: ""
    /// headsetcontrol is optional: without it the widget stays hidden and
    /// nothing polls (it used to fail to start every minute).
    property bool available: false

    readonly property color accent: Services.Colors.byKey(instance.color, Services.Colors.pulseaudioUnderline)
    readonly property int battery: device?.battery?.level ?? -1
    readonly property var capabilities: device?.capabilities ?? []
    readonly property bool canToggle: capabilities.includes("CAP_LIGHTS")
    readonly property bool canColor: capabilities.includes("CAP_LIGHT_COLOR")
    readonly property string deviceId: device
        ? device.id_vendor.replace(/^0x/, "") + ":" + device.id_product.replace(/^0x/, "") : ""

    Layout.fillHeight: true
    visible: device !== null
    implicitWidth: visible ? badge.implicitWidth : 0

    function setLighting(option, value) {
        if (!deviceId || lighting.running)
            return;
        lightingMessage = "Applying…";
        lighting.command = ["headsetcontrol", "-d", deviceId, option, value, "-o", "json"];
        lighting.running = true;
    }

    Process {
        id: poll
        command: ["headsetcontrol", "-b", "--caps", "-o", "json"]
        stdout: StdioCollector { id: batteryOutput }
        onExited: {  // qmllint disable signal-handler-parameters
            try {
                const devices = JSON.parse(batteryOutput.text).devices ?? [];
                root.device = devices.find(d => d.capabilities?.includes("CAP_BATTERY_STATUS")) ?? null;
            } catch (error) {
                root.device = null;
            }
            if (!root.device)
                popup.close();
        }
    }

    Process {
        id: lighting
        stdout: StdioCollector { id: lightingOutput }
        stderr: StdioCollector { id: lightingError }
        onExited: code => {  // qmllint disable signal-handler-parameters
            try {
                const result = JSON.parse(lightingOutput.text).devices?.[0];
                if (code === 0 && result?.status === "success") {
                    root.lightingMessage = "Lighting updated";
                    return;
                }
                root.lightingMessage = Object.values(result?.errors ?? {}).join(" ")
                    || lightingError.text.trim() || "Could not update headset lighting.";
            } catch (error) {
                root.lightingMessage = lightingError.text.trim() || "Could not update headset lighting.";
            }
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v headsetcontrol >/dev/null"]
        onExited: code => root.available = code === 0  // qmllint disable signal-handler-parameters
    }

    Timer {
        interval: 60000
        running: root.available
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!lighting.running) poll.running = true
    }

    BarUi.BarText {
        id: badge
        bar: root.bar
        style: root.instance.style ?? "underline"
        accent: root.accent
        clickable: true
        text: "🎧 " + (root.battery >= 0 ? root.battery + "%" : "—")
        onClicked: popup.isOpen ? popup.close() : popup.open()
    }

    Components.WidgetPopup {
        id: popup
        bar: root.bar
        parentWidget: root
        contentWidth: 320
        accentColor: root.accent
        onOpening: if (!lighting.running) poll.running = true

        Column {
            width: parent.width
            spacing: 10

            Components.PopupHeader {
                text: root.device?.product || "Headset"
                showClose: true
                onCloseClicked: popup.close()
            }

            Components.StyledText {
                width: parent.width
                wrapMode: Text.WordWrap
                text: root.battery >= 0 ? "Battery " + root.battery + "%"
                    : root.device?.battery?.status === "BATTERY_CHARGING" ? "Charging"
                    : root.device?.errors?.battery || "Battery unavailable"
            }

            Row {
                spacing: 8
                visible: root.canToggle

                Components.TextButton {
                    text: "LEDs on"
                    enabled: !lighting.running
                    onClicked: root.setLighting("-l", "1")
                }

                Components.TextButton {
                    text: "LEDs off"
                    enabled: !lighting.running
                    onClicked: root.setLighting("-l", "0")
                }
            }

            Flow {
                width: parent.width
                spacing: 6
                visible: root.canColor

                Repeater {
                    model: root.canColor ? [
                        { name: "Red", hex: "ff0000" },
                        { name: "Green", hex: "00ff00" },
                        { name: "Blue", hex: "0000ff" },
                        { name: "Purple", hex: "b000ff" },
                        { name: "White", hex: "ffffff" }
                    ] : []

                    Components.TextButton {
                        required property var modelData
                        text: modelData.name
                        enabled: !lighting.running
                        onClicked: root.setLighting("--light-color", modelData.hex)
                    }
                }
            }

            Components.StyledText {
                width: parent.width
                wrapMode: Text.WordWrap
                visible: text.length > 0
                text: root.lightingMessage
            }
        }
    }
}
