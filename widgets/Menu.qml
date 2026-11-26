import QtQuick
import "../services" as Services
import "../components" as Components
import "../components/bar" as BarUi

/// Launcher button (type "menu"): the apps icon, or the instance's own glyph.
Item {
    property var bar: null
    property var instance: ({})
    implicitWidth: menuTextInner.implicitWidth + 12
    implicitHeight: menuTextInner.implicitHeight

    BarUi.BarItem {
        style: instance.style ?? "underline"
        accentColor: Services.Colors.byKey(instance.color, Services.Colors.menuUnderline)

        // Launcher button (Dux style): an "apps" icon in the current icon
        // set, unless the instance sets its own glyph.
        Components.StyledText {
            id: menuTextInner
            anchors.centerIn: parent
            textFormat: Text.RichText
            text: instance.glyph
                ? Services.Icons.esc(instance.glyph)
                : Services.Icons.markup("apps", instance.iconSet ?? "auto",
                    Services.Colors.byKey(instance.color, Services.Colors.accent))
            color: Services.Colors.byKey(instance.color, Services.Colors.accent)
            font.pixelSize: Services.Settings.fontSize + 2
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Services.Actions.launcher()
        }
    }
}
