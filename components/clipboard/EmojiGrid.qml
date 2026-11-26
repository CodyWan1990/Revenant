import QtQuick
import "../../services" as Services

/// The Emoji section: the emoji table as a grid; hovering selects.
GridView {
    id: emojiGrid
    /// The clipboard panel (panels/ClipboardPanel.qml): selection, actions.
    required property var panel
    anchors.fill: parent
    anchors.margins: 8
    visible: panel.section === "emoji"
    model: panel.filteredEmoji
    clip: true
    cellWidth: width / Math.max(1, Math.floor(width / panel.emojiCell))
    cellHeight: panel.emojiCell
    boundsBehavior: Flickable.StopAtBounds
    currentIndex: panel.section === "emoji" ? panel.selectedIndex : -1

    delegate: Item {
        id: emojiCell
        required property var modelData
        required property int index
        width: emojiGrid.cellWidth
        height: emojiGrid.cellHeight

        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: Services.Ui.radiusSm
            color: emojiCell.index === panel.selectedIndex
                ? Services.Colors.accent
                : (cellHover.containsMouse ? Services.Colors.accentAlpha(0.25) : "transparent")

            Text {
                anchors.centerIn: parent
                text: emojiCell.modelData.char
                textFormat: Text.PlainText
                // Named outright, not via Settings.fontFamily: that is
                // required to be a Nerd Font, which has no colour emoji.
                // QML's font value type has no `families` fallback list
                // (C++-only), and this cell holds nothing but the emoji.
                font.family: "Noto Color Emoji"
                font.pixelSize: Services.Ui.px(24)
            }

            MouseArea {
                id: cellHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: panel.selectedIndex = emojiCell.index
                onClicked: {
                    panel.selectedIndex = emojiCell.index;
                    panel.activate();
                }
            }
        }
    }
}
