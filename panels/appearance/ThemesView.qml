import QtQuick
import QtQuick.Layouts
import "../../services" as Services
import "../../components" as Components

/// Theme switcher view — extracted from ThemePicker. Selection state
/// (themeSelectedIndex) and openCreateTheme live on the `picker` coordinator;
/// the fuzzy-filtered grid model lives here with its search input.
FocusScope {
    id: root

    required property var picker

    function focusView() { themeSearch.forceActiveFocus(); }
    function reset() { themeSearch.text = ""; }

    // Fuzzy-filtered themes; the "+ New theme" tile only shows when not searching.
    readonly property var filteredThemes: Services.Fuzzy.filter(Services.Theme.themes,
        themeSearch.text, t => t.name)
    readonly property var gridModel: themeSearch.text === ""
        ? filteredThemes.concat([{ add: true }])
        : filteredThemes

    function activateSelected() {
        let m = gridModel;
        let idx = picker.themeSelectedIndex;
        if (idx < 0 || idx >= m.length) return;
        if (m[idx].add === true) picker.openCreateTheme();
        else Services.Theme.apply(m[idx].slug);   // stay open to preview
    }

    function navThemes(dir) {
        let cols = Math.max(1, Math.floor((themeGrid.width - 32) / 200));
        picker.themeSelectedIndex = Services.Ui.gridStep(picker.themeSelectedIndex,
            gridModel.length, cols, dir);
        themeGrid.positionViewAtIndex(picker.themeSelectedIndex, GridView.Contain);
    }

    Column {
        anchors.fill: parent

        Components.SearchHeader {
            icon: ""
            placeholder: "Search themes..."
            showPlaceholder: themeSearch.text.length === 0
            info: root.filteredThemes.length + " themes"
            border.color: Services.Colors.accent
            border.width: 1

            TextInput {
                id: themeSearch
                anchors.fill: parent
                verticalAlignment: TextInput.AlignVCenter
                color: Services.Colors.foreground
                font.family: picker.fontFamily
                font.pixelSize: Services.Ui.textTitle
                clip: true

                onTextChanged: picker.themeSelectedIndex = 0
                Keys.onEscapePressed: picker.creatingTheme
                    ? (picker.creatingTheme = false) : picker.close()
                Keys.onReturnPressed: root.activateSelected()
                Keys.onLeftPressed: root.navThemes("left")
                Keys.onRightPressed: root.navThemes("right")
                Keys.onUpPressed: root.navThemes("up")
                Keys.onDownPressed: root.navThemes("down")
            }
        }

        Rectangle { width: parent.width; height: 2; color: Services.Colors.accent }

        GridView {
            id: themeGrid
            width: parent.width
            height: parent.height - 50
            leftMargin: 16
            rightMargin: 16
            topMargin: 12
            cellWidth: Math.floor((width - 32) / Math.max(1, Math.floor((width - 32) / 200)))
            cellHeight: 92
            clip: true
            currentIndex: picker.themeSelectedIndex
            model: root.gridModel
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: themeCell
                required property var modelData
                required property int index
                readonly property bool isAdd: modelData.add === true
                width: themeGrid.cellWidth
                height: themeGrid.cellHeight

                Rectangle {
                    id: themeCard
                    anchors.fill: parent
                    anchors.margins: 6
                    radius: Services.Ui.radiusMd
                    property bool current: !themeCell.isAdd && Services.Theme.currentSlug === themeCell.modelData.slug
                    property bool active: themeHover.containsMouse || current || themeCell.index === picker.themeSelectedIndex
                    color: (active && !themeCell.isAdd)
                        ? Services.Colors.accent
                        : Services.Colors.color0
                    border.color: themeCell.isAdd
                        ? (active ? Services.Colors.accent : Services.Colors.color8)
                        : (current ? Services.Colors.foreground : Services.Colors.color8)
                    border.width: current ? 2 : 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        visible: themeCell.isAdd
                        Text {
                            text: "＋"
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: themeCard.active ? Services.Colors.accent : Services.Colors.color8
                            font.family: picker.fontFamily
                            font.pixelSize: Services.Ui.px(26)
                        }
                        Text {
                            text: "New theme"
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: themeCard.active ? Services.Colors.accent : Services.Colors.color8
                            font.family: picker.fontFamily
                            font.pixelSize: Services.Ui.textBody
                        }
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10
                        visible: !themeCell.isAdd

                        RowLayout {
                            width: parent.width
                            spacing: 8

                            Text {
                                textFormat: Text.PlainText
                                text: themeCell.isAdd ? "" : themeCell.modelData.name
                                color: themeCard.active
                                    ? Services.Colors.background
                                    : Services.Colors.foreground
                                font.family: picker.fontFamily
                                font.pixelSize: Services.Ui.textSubtitle
                                font.bold: themeCard.current
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "✓"
                                visible: themeCard.current
                                color: Services.Colors.background
                                font.pixelSize: Services.Ui.textSubtitleLarge
                                font.bold: true
                            }
                        }

                        Row {
                            spacing: 4
                            Repeater {
                                model: themeCell.isAdd ? [] : (themeCell.modelData.swatches || [])
                                delegate: Rectangle {
                                    required property string modelData
                                    width: 16; height: 16; radius: 3
                                    color: modelData
                                    border.width: 1
                                    border.color: Qt.rgba(0, 0, 0, 0.25)
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: themeHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: if (containsMouse) picker.themeSelectedIndex = themeCell.index
                        onClicked: {
                            picker.themeSelectedIndex = themeCell.index;
                            if (themeCell.isAdd) picker.openCreateTheme();
                            else Services.Theme.apply(themeCell.modelData.slug);   // stay open to preview
                        }
                    }
                }
            }
        }
    }
}
