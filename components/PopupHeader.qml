import QtQuick
import QtQuick.Layouts
import "../services" as Services

/// Popup title row with optional close button and bottom separator.
Column {
    id: root
    width: parent ? parent.width : 0
    // Match the host Column's spacing; 12 anywhere else.
    spacing: (parent as Column)?.spacing ?? 12

    property string text: ""
    property bool showClose: false
    property bool showSeparator: true
    property real separatorOpacity: 1.0

    signal closeClicked()

    RowLayout {
        width: parent.width

        StyledText {
            text: root.text
            color: Services.Colors.foreground
            font.pixelSize: Services.Ui.textTitle
            font.bold: true
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        TextButton {
            text: "\u2715"
            buttonHeight: 26
            horizontalPadding: 8
            idleColor: "transparent"
            idleTextColor: Services.Colors.surfaceVariantText
            borderWidth: 0
            visible: root.showClose
            onClicked: root.closeClicked()
        }
    }

    Divider {
        visible: root.showSeparator
        opacity: root.separatorOpacity
    }
}
