import QtQuick
import QtQuick.Layouts
import "../services" as Services

/// Radio-button style list entry — used in audio device lists and layout picker.
Rectangle {
    id: root
    width: parent ? parent.width : 0
    height: 30
    radius: Services.Ui.radiusMd

    property bool selected: false
    property color accentColor: Services.Colors.color1
    property string label: ""
    property int fontSize: Services.Ui.textSmall

    signal clicked()

    color: selected
        ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.15)
        : (itemMa.containsMouse ? Services.Ui.menuHoverColor : "transparent")

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8; anchors.rightMargin: 8
        spacing: 6

        Text {
            textFormat: Text.PlainText
            text: root.selected ? "\u25C9" : "\u25CB"
            color: root.selected ? root.accentColor : Services.Colors.color8
            font.pixelSize: Services.Ui.textBody
        }
        StyledText {
            text: root.label
            color: Services.Colors.foreground
            font.pixelSize: root.fontSize
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: itemMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
