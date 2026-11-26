import QtQuick
import "../../services" as Services
import ".." as Components

/// A setting explained for someone meeting it for the first time: a title, a
/// sentence on what it is, then the control at full width, and under it what
/// the current choice does (`hint`). Stacking the control under the words,
/// rather than beside a label column, gives long choice names room.
///
/// The control is the child; give it an empty label. The keyboard cursor
/// (KeyNavCursor) descends through this wrapper to the control.
Column {
    id: row
    width: parent?.width ?? 0
    spacing: 6
    topPadding: 6
    bottomPadding: 6

    property string title: ""
    property string description: ""
    property string hint: ""
    default property alias content: slot.data

    Column {
        width: parent.width
        spacing: 2

        Components.StyledText {
            width: parent.width
            text: row.title
            color: Services.Colors.foreground
            font.pixelSize: Services.Ui.textBodyLarge
            font.bold: true
            wrapMode: Text.WordWrap
        }
        Components.StyledText {
            width: parent.width
            visible: text !== ""
            text: row.description
            color: Services.Colors.surfaceVariantText
            font.pixelSize: Services.Ui.textSmall
            wrapMode: Text.WordWrap
        }
    }

    Item {
        id: slot
        width: parent.width
        height: childrenRect.height
    }

    Components.StyledText {
        width: parent.width
        visible: text !== ""
        text: row.hint
        color: Services.Colors.accent
        font.pixelSize: Services.Ui.textSmall
        wrapMode: Text.WordWrap
    }
}
