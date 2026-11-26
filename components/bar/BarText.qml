import QtQuick
import "../../services" as Services
import ".." as Components

/// Single-text bar widget body: a styled BarItem wrapping one centered RichText label.
Item {
    id: root

    property var bar: null
    property string style: "underline"
    property color accent: "transparent"
    property string text: ""
    property color textColor: Services.Colors.foreground
    property bool small: true
    property bool clickable: false
    /// Also take right clicks (emitted as rightClicked()).
    property bool acceptRight: false
    signal clicked()
    signal rightClicked()

    anchors.fill: parent
    implicitWidth: label.implicitWidth + 10

    BarItem {
        style: root.style
        accentColor: root.accent

        Components.StyledText {
            id: label
            anchors.centerIn: parent
            text: root.text
            textFormat: Text.RichText
            color: root.textColor
            font.pixelSize: root.bar
                ? (root.small ? root.bar.smallFontSize : root.bar.fontSize)
                : Services.Settings.fontSize
            font.bold: true
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.clickable
            acceptedButtons: root.acceptRight ? (Qt.LeftButton | Qt.RightButton) : Qt.LeftButton
            cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) root.rightClicked();
                else root.clicked();
            }
        }
    }
}
