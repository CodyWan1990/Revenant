import QtQuick
import "../services" as Services

/// Settings card in Dux Shell's style (MIT): a rounded tonal surface with an
/// accent title and optional description; children flow into a padded Column.
/// With `collapsible`, clicking the title row shows or hides the children
/// (`expanded`, which the owner may bind to keep it across rebuilds;
/// `toggled` reports clicks).
/// Rounded corners are drawn inside the window by Qt, so they need no
/// compositor.
Rectangle {
    id: card
    width: parent ? parent.width : 0
    implicitHeight: body.implicitHeight + 32
    radius: Services.Ui.radiusLg
    color: Services.Ui.cardColor
    border.color: Services.Ui.subtleBorder
    border.width: Services.Ui.surfaceStyle === "flat" ? 0 : 1

    property string title: ""
    property string description: ""
    property bool collapsible: false
    property bool expanded: true
    signal toggled(bool expanded)
    default property alias content: inner.data

    Column {
        id: body
        x: 18
        y: 16
        width: card.width - 36
        spacing: 12

        Column {
            width: parent.width
            spacing: 4
            visible: card.title !== "" || card.description !== ""

            StyledText {
                visible: card.title !== ""
                width: parent.width
                text: (card.collapsible ? (card.expanded ? "\uf078  " : "\uf054  ") : "") + card.title
                color: Services.Colors.foreground
                font.pixelSize: Services.Ui.textSubtitle
                font.bold: true
                MouseArea {
                    anchors.fill: parent
                    enabled: card.collapsible
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        card.expanded = !card.expanded;
                        card.toggled(card.expanded);
                    }
                }
            }
            StyledText {
                visible: card.description !== ""
                width: parent.width
                text: card.description
                color: Services.Colors.surfaceVariantText
                font.pixelSize: Services.Ui.textSmall
                wrapMode: Text.WordWrap
            }
        }

        Column { id: inner; width: parent.width; spacing: 10; visible: !card.collapsible || card.expanded }
    }
}
