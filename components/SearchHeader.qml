import QtQuick
import QtQuick.Layouts
import "../services" as Services

/// Shared chrome for the searchable panels' 48px header bar: leading icon,
/// an input slot, ghost placeholder, and trailing info text / extra actions.
/// The caller supplies its own TextInput (with its per-panel key handling) as
/// the default child — it fills the slot. Being a Rectangle, callers can set
/// border/radius directly.
Rectangle {
    id: root

    property string icon: ""
    property int iconFormat: Text.PlainText
    property string placeholder: "Search..."
    property string info: ""
    property bool showPlaceholder: true
    default property alias inputSlot: inputHolder.data
    property alias trailing: trailingRow.data

    width: parent.width
    height: 48
    color: Services.Ui.fieldColor
    radius: Services.Ui.radiusMd
    border.color: inputHolder.children.some(item => item.activeFocus)
        ? Services.Colors.accent : Services.Ui.subtleBorder
    border.width: 1

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 8

        Text {
            textFormat: root.iconFormat
            text: root.icon
            visible: text !== ""
            font.pixelSize: Services.Ui.px(19)
            color: Services.Colors.accent
            Layout.alignment: Qt.AlignVCenter
        }

        Item {
            id: inputHolder
            Layout.fillWidth: true
            Layout.fillHeight: true

            StyledText {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.placeholder
                color: Services.Colors.surfaceVariantText
                font.pixelSize: Services.Ui.textTitle
                visible: root.showPlaceholder
            }
        }

        StyledText {
            text: root.info
            visible: text !== ""
            color: Services.Colors.surfaceVariantText
            font.pixelSize: Services.Ui.textBody
            Layout.alignment: Qt.AlignVCenter
        }

        Row {
            id: trailingRow
            spacing: 8
            Layout.alignment: Qt.AlignVCenter
        }
    }

}
