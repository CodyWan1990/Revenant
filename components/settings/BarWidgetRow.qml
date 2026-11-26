import QtQuick
import QtQuick.Layouts
import "../../services" as Services
import ".." as Components

/// One widget row on Settings → Bar → Widgets: drag handle, name, move /
/// edit / remove buttons, and the drop zones that reorder it
/// (panels/settings/pages/BarWidgetsPage.qml).
Column {
    id: rowWrap
    required property var modelData
    required property int index
    /// The Bar widgets page (its layout operations and drag state), the
    /// section card this row is in, and the page's drag ghost.
    required property var page
    required property var card
    required property Item ghost
    width: parent.width
    spacing: 0

    Rectangle {
        id: rowItem
        readonly property var modelData: rowWrap.modelData
        readonly property int index: rowWrap.index
        width: parent.width
        height: 48
        radius: Services.Ui.radiusMd
        opacity: page.draggingId === rowWrap.modelData.id ? 0.4 : 1.0
        color: rowHover.hovered ? Services.Colors.accentAlpha(0.12) : "transparent"

        HoverHandler { id: rowHover }

        // Each half of the row selects its nearest insertion edge.
        DropArea {
            id: rowDrop
            anchors.fill: parent
            keys: ["barwidget"]
            readonly property bool insertAfter: drag.y >= height / 2
            /* Deferred: reordering reassigns the section array,
             * which rebuilds every row delegate — including the
             * MouseArea whose onReleased is running us right now.
             * Let it finish before pulling the rug. */
            onDropped: drop => {
                const widgetId = page.draggingId;
                const section = card.section;
                const index = rowItem.index + (drop.y >= height / 2 ? 1 : 0);
                Qt.callLater(() => page.moveWidget(widgetId, section, index));
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                y: rowDrop.insertAfter ? parent.height - height : 0
                height: 2
                color: Services.Colors.accent
                visible: parent.containsDrag
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            Text {
                text: "☰"
                color: Services.Colors.color8
                font.pixelSize: Services.Ui.textSubtitleLarge
                Layout.alignment: Qt.AlignVCenter

                MouseArea {
                    id: rowDrag
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: page.draggingId === rowItem.modelData.id
                        ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    drag.target: dragGhost
                    onPressed: mouse => {
                        ghost.label = rowItem.modelData.type;
                        let gp = mapToItem(page.contentItem, mouse.x, mouse.y);
                        ghost.x = gp.x - ghost.width / 2;
                        ghost.y = gp.y - ghost.height / 2;
                        page.draggingId = rowItem.modelData.id;
                        ghost.Drag.active = true;
                    }
                    onReleased: {
                        ghost.Drag.drop();
                        ghost.Drag.active = false;
                        page.draggingId = "";
                    }
                    /* No released delivery when the panel closes
                     * mid-drag, and draggingId gates interactive
                     * and the ghost — strand it and the tab is
                     * dead until the Loader recreates it. */
                    onCanceled: {
                        ghost.Drag.cancel();
                        ghost.Drag.active = false;
                        page.draggingId = "";
                    }
                }
            }

            // Widget icon (follows the icon set) + friendly name.
            Components.StyledText {
                Layout.preferredWidth: 22
                Layout.alignment: Qt.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                textFormat: Text.RichText
                text: Services.Icons.markup(Services.WidgetCatalog.icon(rowItem.modelData.type),
                    rowItem.modelData.iconSet ?? "auto", Services.Colors.accent)
                font.pixelSize: Services.Ui.textSubtitleLarge
            }
            Components.StyledText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: {
                    const widget = rowItem.modelData;
                    const name = page.displayName(widget);
                    if (widget.type !== "separator" && widget.type !== "spacer") return name;
                    const glyph = widget.hideGlyph ? "" : (widget.glyph ?? "").trim();
                    return name + " · " + (glyph || "empty space");
                }
                color: Services.Colors.foreground
                font.pixelSize: Services.Ui.textBodyLarge
                elide: Text.ElideRight
            }

            Components.TextButton {
                text: "↑"
                horizontalPadding: 7
                buttonHeight: 26
                enabled: rowItem.index > 0
                Accessible.name: "Move " + page.displayName(rowItem.modelData) + " up"
                onClicked: page.moveWidget(rowItem.modelData.id, card.section, rowItem.index - 1)
            }

            Components.TextButton {
                text: "↓"
                horizontalPadding: 7
                buttonHeight: 26
                enabled: rowItem.index + 1 < card.items.length
                Accessible.name: "Move " + page.displayName(rowItem.modelData) + " down"
                onClicked: page.moveWidget(rowItem.modelData.id, card.section, rowItem.index + 2)
            }

            Repeater {
                model: page.sectionOrder
                Components.TextButton {
                    required property string modelData
                    readonly property string sectionName: page.sectionLabel(modelData)
                    text: rowItem.width >= 700 ? "\u2192 " + sectionName
                        : rowItem.width >= 580 ? sectionName : sectionName.charAt(0)
                    horizontalPadding: 7
                    buttonHeight: 26
                    visible: card.section !== modelData
                    Accessible.name: "Move " + page.displayName(rowItem.modelData) + " to " + sectionName
                    onClicked: page.moveToSection(rowItem.modelData.id, modelData)
                }
            }

            Components.TextButton {
                text: "Options"
                horizontalPadding: 9
                buttonHeight: 26
                Accessible.name: "Options for " + page.displayName(rowItem.modelData)
                onClicked: page.editingId = rowItem.modelData.id
            }

            Components.ChipButton {
                symbol: "✕"
                size: 16
                activeColor: Services.Colors.red
                Layout.alignment: Qt.AlignVCenter
                onClicked: page.removeAt(card.section, rowItem.index)
            }
        }

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 1
            color: Services.Colors.color8
            opacity: 0.2
            visible: rowItem.index < card.items.length - 1
        }
    }
}
