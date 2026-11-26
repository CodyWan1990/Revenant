import QtQuick
import "../../services" as Services
import ".." as Components

/// The Text section: clipmenu's history, one row per clip, with ×.
ListView {
    id: textList
    /// The clipboard panel (panels/ClipboardPanel.qml): selection, actions.
    required property var panel
    anchors.fill: parent
    anchors.margins: 6
    visible: panel.section === "text"
    model: panel.filteredText
    clip: true
    spacing: 4
    boundsBehavior: Flickable.StopAtBounds
    currentIndex: panel.section === "text" ? panel.selectedIndex : -1

    delegate: Components.InteractiveListRow {
        id: entryRow
        required property var modelData
        required property int index

        width: ListView.view.width
        height: 42
        radius: Services.Ui.radiusMd
        selected: index === panel.selectedIndex
        selectedColor: Services.Ui.menuSelectionColor
        hoverColor: Services.Ui.menuHoverColor
        clickRightMargin: 42
        onClicked: {
            panel.selectedIndex = index;
            panel.activate();
        }

        Components.StyledText {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: textDelete.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: entryRow.modelData.display
            color: entryRow.selected ? Services.Ui.menuSelectionText : Services.Colors.foreground
            font.pixelSize: Services.Ui.textBodyLarge
            elide: Text.ElideRight
        }

        Components.TextButton {
            id: textDelete
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            buttonHeight: 28
            text: "×"
            fontSize: Services.Ui.textSubtitleLarge
            idleColor: "transparent"
            idleTextColor: Services.Colors.surfaceVariantText
            hoverColor: Services.Colors.red
            borderWidth: 0
            Accessible.name: "Delete clipboard entry"
            onClicked: panel.removeSelected(entryRow.index)
        }
    }
}
