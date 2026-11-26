import QtQuick
import QtQuick.Layouts
import "../services" as Services
import "../components" as Components
import "../components/bar" as BarUi

/// Quick theme: a dropdown with your presets (colours + wallpapers, from
/// Settings → Themes & wallpapers), the colour themes and the wallpapers.
/// A click applies it live; a wallpaper goes on every monitor. Each part can
/// be hidden in the widget's options.
BarUi.BarWidget {
    id: root

    icon: "theme"
    defaultAccent: Services.Colors.color5
    clickable: true
    onClicked: themePopup.isOpen ? themePopup.close() : themePopup.open()

    readonly property bool showPresets: root.instance.showPresets ?? true
    readonly property bool showColours: root.instance.showColours ?? true
    readonly property bool showWallpapers: root.instance.showWallpapers ?? true
    readonly property var presets: Services.Settings.themePresets ?? []

    Component.onCompleted: Services.Theme.refresh()

    Components.WidgetPopup {
        id: themePopup
        bar: root.bar
        parentWidget: root
        contentWidth: root.instance.popupWidth ?? 460
        contentHeight: Math.min(root.instance.maxPopupHeight ?? 720, body.implicitHeight + contentMargins * 2)
        contentMargins: 6
        accentColor: Services.Colors.color5

        onOpening: { Services.Theme.refresh(); Services.Wallpaper.refresh(); }

        Flickable {
            anchors.fill: parent
            clip: true
            contentHeight: body.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: body
                width: parent.width
                spacing: 2

                // ─── Presets ───
                Components.StyledText {
                    visible: root.showPresets
                    text: "PRESETS"
                    width: parent.width
                    leftPadding: 8
                    topPadding: 6
                    bottomPadding: 2
                    color: themePopup.widgetAccent
                    font.pixelSize: Services.Ui.textSmall
                    font.bold: true
                }
                Components.StyledText {
                    visible: root.showPresets && root.presets.length === 0
                    width: parent.width
                    leftPadding: 10
                    bottomPadding: 4
                    wrapMode: Text.WordWrap
                    text: "None yet — save one in Settings → Themes & wallpapers."
                    color: Services.Colors.color8
                    font.pixelSize: Services.Ui.textSmall
                    font.italic: true
                }
                Repeater {
                    model: root.showPresets ? root.presets : []
                    delegate: Components.InteractiveListRow {
                        id: presetRow
                        required property var modelData
                        readonly property bool current: Services.Theme.activePreset?.id === modelData.id
                        readonly property var theme: Services.Theme.themes.find(t => t.slug === modelData.theme)
                        width: body.width
                        height: 32
                        selected: current
                        accentColor: themePopup.widgetAccent
                        hoverColor: themePopup.widgetAccent
                        selectedColor: Services.Colors.withAlpha(themePopup.widgetAccent, 0.2)
                        onClicked: { Services.Theme.applyPreset(modelData.id); themePopup.close(); }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8
                            Components.StyledText {
                                Layout.fillWidth: true
                                text: (presetRow.current ? "✓ " : "") + presetRow.modelData.name
                                elide: Text.ElideRight
                                color: presetRow.hovered ? Services.Colors.background
                                    : (presetRow.current ? themePopup.widgetAccent : Services.Colors.foreground)
                                font.pixelSize: Services.Ui.textBodyLarge
                                font.bold: presetRow.current
                            }
                            Components.SwatchRow { colors: presetRow.theme?.swatches ?? [] }
                        }
                    }
                }

                // ─── Colours ───
                Components.StyledText {
                    visible: root.showColours
                    text: "COLOURS"
                    width: parent.width
                    leftPadding: 8
                    topPadding: 6
                    bottomPadding: 2
                    color: themePopup.widgetAccent
                    font.pixelSize: Services.Ui.textSmall
                    font.bold: true
                }
                Components.StyledDropdown {
                    visible: root.showColours
                    x: 4
                    width: body.width - 8
                    labelWidth: 0
                    maxListHeight: 280
                    placeholder: "Pick a theme"
                    model: Services.Theme.slugs
                    labels: Services.Theme.names
                    swatches: Services.Theme.swatchesBySlug
                    currentValue: Services.Theme.currentSlug
                    onSelected: value => Services.Theme.apply(value)
                }

                // ─── Wallpapers ───
                Components.StyledText {
                    visible: root.showWallpapers
                    text: "WALLPAPERS"
                    width: parent.width
                    leftPadding: 8
                    topPadding: 6
                    bottomPadding: 2
                    color: themePopup.widgetAccent
                    font.pixelSize: Services.Ui.textSmall
                    font.bold: true
                }
                Components.StyledText {
                    visible: root.showWallpapers && Services.Wallpaper.files.length === 0
                    width: parent.width
                    leftPadding: 10
                    wrapMode: Text.WordWrap
                    text: "No pictures in " + Services.Wallpaper.dir
                    color: Services.Colors.color8
                    font.pixelSize: Services.Ui.textSmall
                    font.italic: true
                }
                Grid {
                    id: thumbs
                    visible: root.showWallpapers
                    width: parent.width
                    columns: root.instance.wallpaperColumns ?? 2
                    spacing: 4
                    readonly property real cell: (width - spacing * (columns - 1)) / columns

                    Repeater {
                        model: root.showWallpapers ? Services.Wallpaper.files : []
                        delegate: Rectangle {
                            id: thumb
                            required property string modelData
                            readonly property string path: Services.Wallpaper.pathOf(modelData)
                            readonly property bool current: Services.Wallpaper.same(Services.Wallpaper.current["*"], path)
                            width: thumbs.cell
                            height: Math.round(thumbs.cell * 0.5625)
                            color: Services.Colors.color0
                            border.color: (current || thumbHover.containsMouse) ? themePopup.widgetAccent : Services.Colors.color8
                            border.width: (current || thumbHover.containsMouse) ? 2 : 1

                            Image {
                                anchors.fill: parent
                                anchors.margins: parent.border.width
                                source: "file://" + thumb.path
                                sourceSize.width: 440
                                sourceSize.height: 248
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                            MouseArea {
                                id: thumbHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                // Every monitor; per-monitor pictures are set in Settings.
                                onClicked: Services.Wallpaper.set(thumb.path, "*")
                            }
                        }
                    }
                }

                Components.TextButton {
                    x: 4
                    width: body.width - 8
                    text: "Themes & wallpapers settings…"
                    onClicked: { themePopup.close(); Services.Actions.themeSettings(); }
                }
            }
        }
    }
}
