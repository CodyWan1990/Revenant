import QtQuick
import "../../services" as Services
import ".." as Components

/// The Images section: thumbnails of copied images (services/ClipImages.qml), with ×.
GridView {
    id: imageGrid
    /// The clipboard panel (panels/ClipboardPanel.qml): selection, actions.
    required property var panel
    anchors.fill: parent
    anchors.margins: 6
    visible: panel.section === "images"
    model: panel.filteredImages
    clip: true
    // Spread the columns over the full width.
    cellWidth: width / Math.max(1, Math.floor(width / panel.imageCellW))
    cellHeight: panel.imageCellH
    boundsBehavior: Flickable.StopAtBounds
    currentIndex: panel.section === "images" ? panel.selectedIndex : -1

    delegate: Item {
        id: imageCell
        required property var modelData
        required property int index
        readonly property bool isSelected: index === panel.selectedIndex
        width: imageGrid.cellWidth
        height: imageGrid.cellHeight

        Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            radius: Services.Ui.radiusMd
            color: imageCell.isSelected ? Services.Ui.menuSelectionColor
                : imageArea.containsMouse ? Services.Ui.menuHoverColor : Services.Colors.color0
            border.color: imageCell.isSelected ? Services.Colors.accent : Services.Ui.subtleBorder
            border.width: imageCell.isSelected ? 2 : 1

            Image {
                id: thumb
                anchors.fill: parent
                anchors.margins: 8
                anchors.bottomMargin: 26
                source: "file://" + imageCell.modelData.path
                sourceSize.width: 400   // decode a thumbnail, not the full image
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
            }

            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 6
                horizontalAlignment: Text.AlignHCenter
                text: Services.Fmt.ago(imageCell.modelData.time)
                color: imageCell.isSelected ? Services.Ui.menuSelectionText : Services.Colors.surfaceVariantText
                font.family: panel.fontFamily
                font.pixelSize: Services.Ui.textCaption
                elide: Text.ElideRight
            }

            MouseArea {
                id: imageArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    panel.selectedIndex = imageCell.index;
                    panel.activate();
                }
            }

            Components.TextButton {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 4
                visible: imageArea.containsMouse || hovered
                width: 26
                buttonHeight: 24
                text: "×"
                fontSize: Services.Ui.textSubtitle
                idleColor: Services.Colors.background
                idleTextColor: Services.Colors.foreground
                hoverColor: Services.Colors.red
                borderWidth: 0
                Accessible.name: "Delete image"
                onClicked: panel.removeSelected(imageCell.index)
            }
        }
    }
}
