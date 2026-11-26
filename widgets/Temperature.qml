import QtQuick
import QtQuick.Layouts
import "../services" as Services
import "../components" as Components
import "../components/bar" as BarUi

/// Temperature bar widget (CPU, GPU or any hwmon sensor), modelled on Dux
/// Shell's CPU/GPU temperature widgets (MIT). Click: every sensor, grouped by
/// device. Data: services/Temps.qml.
BarUi.BarWidget {
    id: root

    readonly property string source: (instance.sensorId ?? "") !== "" ? instance.sensorId : (instance.source ?? "cpu")
    readonly property var sensor: Services.Temps.resolve(root.source)
    readonly property int celsius: sensor ? sensor.c : 0
    readonly property color tempColor: Services.Colors.threshold(celsius,
        instance.warn ?? 65, instance.high ?? 75, instance.crit ?? 90)

    icon: root.source === "gpu" ? "gpu" : "temp"
    defaultAccent: Services.Colors.cpuUnderline
    clickable: true
    onClicked: popup.isOpen ? popup.close() : popup.open()

    text: {
        if (!root.sensor) return "<font color='" + Services.Icons.hex(Services.Colors.color8) + "'>--°C</font>";
        const label = (instance.showLabel ?? false)
            ? Services.Temps.chipName(root.sensor) + " " : "";
        return label + "<font color='" + Services.Icons.hex(root.tempColor) + "'>" + root.celsius + "°C</font>";
    }

    Components.WidgetPopup {
        id: popup
        bar: root.bar
        parentWidget: root
        contentWidth: 320
        accentColor: root.accent

        Column {
            width: parent.width
            spacing: 6

            Components.PopupHeader {
                width: parent.width
                text: "Temperatures"
                separatorOpacity: 0.3
            }

            Repeater {
                // Group headers + rows, in sensor order.
                model: {
                    let out = [], last = "";
                    for (const s of Services.Temps.sensors) {
                        const g = Services.Temps.chipName(s);
                        if (g !== last) { out.push({ header: g }); last = g; }
                        out.push({ sensor: s });
                    }
                    return out;
                }

                delegate: Item {
                    id: entry
                    required property var modelData
                    width: parent.width
                    height: modelData.header ? 26 : 22

                    Components.StyledText {
                        visible: !!entry.modelData.header
                        anchors.bottom: parent.bottom
                        text: entry.modelData.header ?? ""
                        color: Services.Colors.accent
                        font.pixelSize: Services.Ui.textSmall
                        font.bold: true
                    }

                    RowLayout {
                        visible: !entry.modelData.header
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        Components.StyledText {
                            text: entry.modelData.sensor?.label ?? ""
                            color: Services.Colors.foreground
                            font.pixelSize: Services.Ui.textBody
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Components.StyledText {
                            readonly property int c: entry.modelData.sensor?.c ?? 0
                            text: c + "°C"
                            color: Services.Colors.threshold(c, root.instance.warn ?? 65,
                                root.instance.high ?? 75, root.instance.crit ?? 90)
                            font.pixelSize: Services.Ui.textBody
                            font.bold: entry.modelData.sensor?.id === root.sensor?.id
                        }
                    }
                }
            }
        }
    }
}
