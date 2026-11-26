import QtQuick
import "../services" as Services
import "../components" as Components
import "../components/bar" as BarUi

/// Opens the power menu.
Item {
    property var bar: null
    property var instance: ({})
    implicitWidth: powerTextInner.implicitWidth + 12
    implicitHeight: powerTextInner.implicitHeight

    BarUi.BarItem {
        style: instance.style ?? "underline"
        accentColor: Services.Colors.byKey(instance.color, Services.Colors.powermenuUnderline)

        Components.StyledText {
            id: powerTextInner
            anchors.centerIn: parent
            textFormat: Text.RichText
            text: Services.Icons.markup("power", instance.iconSet ?? "emoji", Services.Colors.byKey(instance.color, Services.Colors.powermenuUnderline))
            // Honors the per-widget Color setting; red is only the default.
            color: Services.Colors.byKey(instance.color, Services.Colors.red)
            font.pixelSize: Services.Settings.fontSize
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Services.Actions.powermenu()
        }
    }
}
