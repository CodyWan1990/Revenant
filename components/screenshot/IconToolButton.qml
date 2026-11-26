import QtQuick
import "../../services" as Services

/// Icon button for a toolbar (the screenshot selector's); with `label`, a
/// wider outlined button with text. Exposes
/// `hovered` and `tipText` so the toolbar can show the hovered button's tip.
Rectangle {
    id: btn

    property string glyph
    property string tipText
    property string label: ""   // shown after the icon: a wider, filled button
    property bool checked: false
    property color tint: Services.Colors.foreground
    readonly property bool hovered: btnArea.containsMouse
    signal clicked()

    width: label ? content.implicitWidth + 20 : 30
    height: 30
    color: checked ? Services.Colors.primaryContainer
        : hovered && enabled ? Services.Colors.surfaceContainerHigh
        : label ? Services.Colors.surfaceContainer : "transparent"
    border.color: label ? Services.Colors.blend(Services.Colors.background, tint, 0.6) : "transparent"
    opacity: enabled ? 1 : 0.4

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 7
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: btn.glyph
            color: btn.checked ? Services.Colors.primaryContainerText : btn.tint
            font.family: Services.Settings.fontFamily
            font.pixelSize: Services.Ui.textSubtitle
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: btn.label !== ""
            text: btn.label
            color: Services.Colors.foreground
            font.family: Services.Settings.fontFamily
            font.pixelSize: Services.Ui.textBody
            font.bold: true
        }
    }

    MouseArea {
        id: btnArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: if (btn.enabled) btn.clicked()
    }
}
