import QtQuick
import QtQuick.Layouts
import "../../services" as Services
import ".." as Components

/// A Control Center quick-toggle tile: icon, title and a status line. Clicking
/// the tile toggles it; with `showMore`, the › strip on the right opens the
/// related section instead (Wi-Fi → Network, Bluetooth → Bluetooth).
Rectangle {
    id: tile

    property string glyph: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool showMore: false
    property color accent: Services.Colors.accent
    signal toggled()
    signal moreClicked()

    implicitHeight: 58
    radius: Services.Ui.radiusMd
    color: active ? Services.Colors.primaryContainer
        : mainArea.containsMouse && enabled ? Services.Colors.surfaceContainerHighest
        : Services.Colors.surfaceContainerHigh
    border.color: active ? tile.accent : Services.Colors.outlineVariant
    border.width: 1
    opacity: enabled ? 1 : 0.5

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: tile.showMore ? 0 : 12
        spacing: 10

        Text {
            text: tile.glyph
            color: tile.active ? tile.accent : Services.Colors.surfaceVariantText
            font.family: Services.Settings.fontFamily
            font.pixelSize: Services.Ui.textHeading
            Layout.preferredWidth: 24
            horizontalAlignment: Text.AlignHCenter
        }

        Column {
            Layout.fillWidth: true
            spacing: 1
            Components.StyledText {
                width: parent.width
                text: tile.title
                color: tile.active ? Services.Colors.primaryContainerText : Services.Colors.foreground
                font.pixelSize: Services.Ui.textBodyLarge
                font.bold: true
                elide: Text.ElideRight
            }
            Components.StyledText {
                width: parent.width
                text: tile.subtitle
                color: tile.active ? Services.Colors.primaryContainerText : Services.Colors.surfaceVariantText
                font.pixelSize: Services.Ui.textCaption
                elide: Text.ElideRight
                opacity: 0.85
            }
        }

        // ─── › opens the section ───
        Rectangle {
            visible: tile.showMore
            Layout.fillHeight: true
            Layout.preferredWidth: 32
            color: moreArea.containsMouse ? Services.Colors.blend(tile.color, Services.Colors.foreground, 0.08)
                : "transparent"
            radius: tile.radius

            Rectangle {   // divider
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: parent.height - 20
                color: tile.active ? tile.accent : Services.Colors.outlineVariant
                opacity: 0.6
            }
            Text {
                anchors.centerIn: parent
                text: "›"
                color: tile.active ? Services.Colors.primaryContainerText : Services.Colors.foreground
                font.family: Services.Settings.fontFamily
                font.pixelSize: Services.Ui.textHeading
            }
            MouseArea {
                id: moreArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: tile.moreClicked()
            }
        }
    }

    MouseArea {
        id: mainArea
        anchors.fill: parent
        anchors.rightMargin: tile.showMore ? 32 : 0
        hoverEnabled: true
        enabled: tile.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.toggled()
    }
}
