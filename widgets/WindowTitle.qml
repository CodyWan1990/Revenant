import QtQuick
import QtQuick.Layouts
import "../services" as Services
import "../components" as Components
import "../components/bar" as BarUi

/// Focused window's title, elided to `maxWidth`.
Item {
    id: wtRoot
    property var bar: null
    property var instance: ({})
    // Split icon (RichText, colored) + title (PlainText, elides) so the title
    // truncates with "…" — Qt ignores elide on RichText.
    readonly property int maxTitleWidth: instance.maxWidth ?? 360
    visible: Services.I3.focusedWindowTitle !== ""
    implicitWidth: wtRow.implicitWidth + 4
    implicitHeight: wtRow.implicitHeight

    BarUi.BarItem {
        style: instance.style ?? "none"
        accentColor: Services.Colors.byKey(instance.color, Services.Colors.foreground)

        RowLayout {
            id: wtRow
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 4
            spacing: 4

            Components.StyledText {
                id: windowIconText
                textFormat: Text.RichText
                text: (wtRoot.instance.prefix ?? "| ") + Services.Icons.markup("window", wtRoot.instance.iconSet ?? "emoji", Services.Colors.byKey(wtRoot.instance.color, Services.Colors.foreground))
                color: Services.Colors.foreground
                font.pixelSize: Services.Settings.fontSize
            }

            Components.StyledText {
                id: windowTitleText
                textFormat: Text.PlainText
                text: Services.I3.focusedWindowTitle
                color: Services.Colors.foreground
                font.pixelSize: Services.Settings.fontSize
                elide: Text.ElideRight
                Layout.maximumWidth: wtRoot.maxTitleWidth
            }
        }
    }
}
