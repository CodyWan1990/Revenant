import QtQuick
import "../services" as Services

/// On/off row in Dux Shell's style (MIT): label + optional description on the
/// left, a Material switch on the right. Keyboard: a KeyNavCursor leaf (Enter
/// toggles, Left/Right set off/on).
Item {
    id: root

    property string label: ""
    property string description: ""
    property bool checked: false
    /// KeyNavCursor highlight.
    property bool cursor: false

    signal toggled(bool checked)

    width: parent ? parent.width : 0
    implicitHeight: Math.max(36, text.implicitHeight + 8)

    function keyActivate() { toggled(!checked); }
    function keyAdjust(delta) { if ((delta > 0) !== checked) toggled(delta > 0); }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: Services.Ui.radiusMd
        color: Services.Colors.surfaceContainerHigh
        visible: root.cursor || area.containsMouse
    }

    Column {
        id: text
        anchors.left: parent.left
        anchors.right: track.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        StyledText {
            width: parent.width
            text: root.label
            color: Services.Colors.foreground
            font.pixelSize: Services.Ui.textBodyLarge
            elide: Text.ElideRight
        }
        StyledText {
            width: parent.width
            visible: root.description !== ""
            text: root.description
            color: Services.Colors.surfaceVariantText
            font.pixelSize: Services.Ui.textSmall
            wrapMode: Text.WordWrap
        }
    }

    // Material switch: a pill track and a round thumb that slides and grows.
    Rectangle {
        id: track
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 46
        height: 26
        radius: height / 2
        color: root.checked ? Services.Colors.accent : Services.Colors.surfaceContainerHighest
        border.width: root.checked ? 0 : 2
        border.color: Services.Colors.outline
        Behavior on color { ColorAnimation { duration: Services.Ui.durOpen } }

        Rectangle {
            property int size: root.checked ? 18 : 12
            width: size
            height: size
            radius: size / 2
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - 4 : 7
            color: root.checked ? Services.Colors.background : Services.Colors.outline
            Behavior on x { NumberAnimation { duration: Services.Ui.durOpen; easing.type: Easing.OutCubic } }
            Behavior on size { NumberAnimation { duration: Services.Ui.durOpen } }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
