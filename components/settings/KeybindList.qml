import QtQuick
import QtQuick.Layouts
import "../../services" as Services
import ".." as Components

/// Settings → Keybinds: the list of shortcuts in the current section, each
/// row selecting it for editing, its keys drawn as key caps, with "+ Key" to
/// add another key combination for the same action.
Rectangle {
    /// The keybind editor page: bindings, selection and actions.
    required property var page
    property alias shortcutList: shortcutList
    Layout.fillWidth: true
    Layout.alignment: Qt.AlignTop
    Layout.preferredHeight: page.stackEditor ? 280 : Math.max(380, page.height - filterCard.height - 52)
    color: Services.Ui.cardColor
    radius: Services.Ui.radiusLg
    border.color: Services.Colors.outlineVariant
    border.width: 1

    Components.StyledText {
        anchors.centerIn: parent
        width: parent.width - 32
        visible: shortcutList.count === 0 && !page.busy
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: page.query.trim() !== "" ? "No shortcuts match \"" + page.query.trim() + "\"." : "Nothing here yet."
        color: Services.Colors.surfaceVariantText
    }

    ListView {
        id: shortcutList
        anchors.fill: parent
        anchors.margins: 8
        model: page.rows
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        spacing: 2

        delegate: Components.InteractiveListRow {
            id: shortcutRow
            required property var modelData
            readonly property var binding: modelData.binding
            width: ListView.view.width
            height: binding ? 42 : 34
            radius: Services.Ui.radiusSm
            clickRightMargin: addAlternate.visible ? addAlternate.width + 14 : 0
            enabled: !!binding && !page.busy
            selected: page.adding ? binding?.line === page.templateLine : binding?.line === page.selectedLine
            selectedColor: Services.Colors.primaryContainer
            hoverColor: Services.Colors.surfaceContainerHigh
            onClicked: page.selectBinding(binding)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 10
                spacing: 8

                Components.StyledText {
                    Layout.fillWidth: true
                    text: shortcutRow.binding?.action ?? shortcutRow.modelData.heading
                    elide: Text.ElideRight
                    font.bold: !shortcutRow.binding || shortcutRow.selected
                    color: !shortcutRow.binding ? Services.Colors.accent
                        : shortcutRow.selected ? Services.Colors.primaryContainerText : Services.Colors.foreground
                }

                // Unset: say why, in words.
                Components.StyledText {
                    visible: !!shortcutRow.binding && shortcutRow.binding.disabled
                    text: shortcutRow.binding?.defaultRole && page.defaultHandlersReady
                            && !page.defaultApp(shortcutRow.binding) && !shortcutRow.binding?.appCommand
                        ? "No app installed" : "No shortcut"
                    font.pixelSize: Services.Ui.textSmall
                    color: shortcutRow.selected ? Services.Colors.primaryContainerText
                        : Services.Colors.surfaceVariantText
                }

                // Set: one key cap per key ("Super", "Shift", "Q").
                Row {
                    visible: !!shortcutRow.binding && !shortcutRow.binding.disabled
                    spacing: 4
                    Repeater {
                        model: shortcutRow.binding && !shortcutRow.binding.disabled
                            ? (shortcutRow.binding.keys ?? "").split(" + ") : []
                        Rectangle {
                            required property string modelData
                            width: Math.max(22, cap.implicitWidth + 12)
                            height: 22
                            radius: 4
                            color: Services.Ui.fieldColor
                            border.color: Services.Colors.outlineVariant
                            border.width: 1
                            Components.StyledText {
                                id: cap
                                anchors.centerIn: parent
                                text: parent.modelData
                                font.pixelSize: Services.Ui.textSmall
                                color: Services.Colors.foreground
                            }
                        }
                    }
                }

                Components.TextButton {
                    id: addAlternate
                    visible: !!shortcutRow.binding && !shortcutRow.binding.disabled
                    text: "+ Key"
                    buttonHeight: 26
                    horizontalPadding: 8
                    Accessible.name: "Add another shortcut for " + (shortcutRow.binding?.action ?? "")
                    onClicked: page.beginAdd(shortcutRow.binding)
                }
            }
        }
    }
}
