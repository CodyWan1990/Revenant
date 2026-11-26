import QtQuick
import QtQuick.Layouts
import "../../../services" as Services
import "../../../components" as Components
import "../../appearance" as Appearance
import "../../../components/settings" as SettingsUi

/// Appearance ▸ Themes & wallpapers, one page top to bottom:
///   Presets     saved looks: a colour theme plus the wallpaper on each
///               monitor (Settings.themePresets, Theme.applyPreset)
///   Colours     a dropdown of every theme, with its swatches; applies live
///   Wallpapers  the picker, per monitor, each with its own folder if wanted
/// `section` scrolls to a part; SettingsWindow sets it for the aliases.
SettingsUi.SettingsPage {
    id: root
    anchors.fill: parent
    horizontalPadding: 24
    contentSpacing: 16
    Component.onCompleted: { Services.Theme.refresh(); Services.Wallpaper.refresh(); }
    onPageShownChanged: if (pageShown) Services.Wallpaper.refresh()

    /// Set by SettingsWindow ("wallpapers", …): scroll that part into view.
    property string section: ""
    onSectionChanged: Qt.callLater(scrollToSection)
    function scrollToSection() {
        const item = ({ presets: presetsCard, colours: coloursCard, wallpapers: wallpapersCard })[section];
        if (item) contentY = Math.max(0, Math.min(item.y - 8, contentHeight - height));
        section = "";
    }
    readonly property var current: Services.Theme.themes.find(theme => theme.slug === Services.Theme.currentSlug)
    function themeOf(slug) { return Services.Theme.themes.find(theme => theme.slug === slug); }
    /// The preset whose Delete was clicked once (a second click deletes).
    property string confirmDelete: ""

    // ─── Presets ───────────────────────────────────────────────────────────
    Components.Card {
        id: presetsCard
        x: root.horizontalPadding; width: root.rowWidth
        title: "Save this look"
        description: "Keeps the colour theme and the wallpaper on each monitor together, so one click brings back the whole desktop. "
            + "The Quick theme bar widget lists them too."

        Components.StyledText {
            width: parent.width
            text: "Now: " + (root.current?.name ?? "no theme") + " · "
                + (Object.keys(Services.Wallpaper.current).length > 1 ? "a wallpaper per monitor"
                    : (Services.Wallpaper.current["*"] ?? "no wallpaper").split("/").pop())
            color: Services.Colors.surfaceVariantText
            font.pixelSize: Services.Ui.textBody
            elide: Text.ElideRight
        }

        RowLayout {
            width: parent.width
            spacing: 8
            Components.SettingField {
                id: presetName
                placeholder: "Name, e.g. Night drive"
                onLiveEdited: value => saveButton.enabled = value.trim() !== ""
                onEdited: value => { if (value.trim() !== "") saveButton.clicked(); }
            }
            Components.TextButton {
                id: saveButton
                text: "Save as preset"
                enabled: false
                onClicked: {
                    const name = presetName.text.trim();
                    if (!name) return;
                    // Same name: update that preset rather than add a twin.
                    const same = (Services.Settings.themePresets ?? []).find(p => p.name.toLowerCase() === name.toLowerCase());
                    Services.Settings.saveThemePreset({ id: same?.id ?? "", name: name, theme: Services.Theme.currentSlug,
                        wallpapers: Services.Wallpaper.compact(Services.Wallpaper.current) });
                    presetName.text = "";
                    enabled = false;
                }
            }
        }
    }

    Components.Card {
        x: root.horizontalPadding; width: root.rowWidth
        title: "Your presets"
        description: (Services.Settings.themePresets ?? []).length === 0
            ? "None yet: pick colours and wallpapers, then save them above."
            : "Click one to apply it. Update keeps its name and takes what's on screen now."

        Repeater {
            model: Services.Settings.themePresets ?? []

            delegate: Item {
                id: presetRow
                required property var modelData
                required property int index
                readonly property bool active: Services.Theme.activePreset?.id === modelData.id
                readonly property var theme: root.themeOf(modelData.theme)
                readonly property string image: {
                    const w = modelData.wallpapers;
                    return Services.Wallpaper.pathOf(typeof w === "string" ? w : (w?.["*"] ?? Object.values(w ?? {})[0] ?? ""));
                }
                readonly property int perMonitor: typeof modelData.wallpapers === "object" && modelData.wallpapers
                    ? Object.keys(modelData.wallpapers).filter(k => k !== "*").length : 0
                width: parent.width
                height: 64 + barRow.height + 6

                Rectangle {
                    id: applyArea
                    /// KeyNavCursor leaf: Enter applies.
                    property bool cursor: false
                    function keyActivate() { Services.Theme.applyPreset(presetRow.modelData.id); }
                    anchors.left: parent.left
                    anchors.right: buttons.left
                    anchors.rightMargin: 8
                    height: 64
                    radius: Services.Ui.radiusMd
                    color: presetRow.active ? Services.Colors.primaryContainer
                        : (cursor || applyHover.containsMouse) ? Services.Colors.surfaceContainerHigh : "transparent"
                    border.color: cursor ? Services.Colors.accent : "transparent"
                    border.width: cursor ? 2 : 0

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 92
                            Layout.fillHeight: true
                            color: Services.Colors.color0
                            border.color: Services.Colors.outlineVariant
                            border.width: 1
                            Image {
                                anchors.fill: parent
                                anchors.margins: 1
                                source: presetRow.image ? "file://" + presetRow.image : ""
                                sourceSize.width: 184
                                sourceSize.height: 104
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 4
                            Components.StyledText {
                                width: parent.width
                                text: (presetRow.active ? "✓ " : "") + presetRow.modelData.name
                                color: presetRow.active ? Services.Colors.primaryContainerText : Services.Colors.foreground
                                font.pixelSize: Services.Ui.textBodyLarge
                                font.bold: presetRow.active
                                elide: Text.ElideRight
                            }
                            Components.StyledText {
                                width: parent.width
                                text: (presetRow.theme?.name ?? (presetRow.modelData.theme ? presetRow.modelData.theme + " (missing)" : "keeps the colours"))
                                    + (presetRow.perMonitor > 0 ? " · " + presetRow.perMonitor + " monitor" + (presetRow.perMonitor > 1 ? "s" : "") + " with their own wallpaper" : "")
                                color: presetRow.active ? Services.Colors.primaryContainerText : Services.Colors.surfaceVariantText
                                font.pixelSize: Services.Ui.textSmall
                                elide: Text.ElideRight
                            }
                        }

                        Row {
                            spacing: 4
                            Repeater {
                                model: presetRow.theme?.swatches ?? []
                                Rectangle {
                                    required property string modelData
                                    width: 14; height: 14; radius: 7
                                    color: modelData
                                    border.color: Services.Colors.outlineVariant
                                    border.width: 1
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: applyHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: applyArea.keyActivate()
                    }
                }

                Row {
                    id: buttons
                    anchors.right: parent.right
                    anchors.verticalCenter: applyArea.verticalCenter
                    spacing: 4
                    Components.TextButton {
                        text: "Update"
                        horizontalPadding: 10
                        // Keeps its bar layout: that's chosen below, not read from the screen.
                        onClicked: Services.Settings.saveThemePreset({ id: presetRow.modelData.id, name: presetRow.modelData.name,
                            theme: Services.Theme.currentSlug, wallpapers: Services.Wallpaper.compact(Services.Wallpaper.current),
                            bar: presetRow.modelData.bar })
                    }
                    Components.TextButton {
                        text: "↑"
                        horizontalPadding: 10
                        enabled: presetRow.index > 0
                        onClicked: Services.Settings.moveThemePreset(presetRow.modelData.id, -1)
                    }
                    Components.TextButton {
                        text: "↓"
                        horizontalPadding: 10
                        enabled: presetRow.index < (Services.Settings.themePresets ?? []).length - 1
                        onClicked: Services.Settings.moveThemePreset(presetRow.modelData.id, 1)
                    }
                    Components.TextButton {
                        text: root.confirmDelete === presetRow.modelData.id ? "Really delete?" : "Delete"
                        horizontalPadding: 10
                        onClicked: {
                            if (root.confirmDelete === presetRow.modelData.id) {
                                root.confirmDelete = "";
                                Services.Settings.removeThemePreset(presetRow.modelData.id);
                            } else root.confirmDelete = presetRow.modelData.id;
                        }
                    }
                }

                // The bar layout this preset brings along: one of the saved bar
                // presets (Settings → Bar → Widgets), on every bar or one monitor's.
                RowLayout {
                    id: barRow
                    readonly property string barPreset: presetRow.modelData.bar?.preset ?? ""
                    readonly property string barOutput: presetRow.modelData.bar?.output ?? "*"
                    readonly property bool perMonitor: Services.Settings.barLayoutMode === "separate"
                    readonly property bool missing: barPreset !== ""
                        && !Services.Settings.allBarPresets.some(b => b.name === barPreset)
                    anchors.top: applyArea.bottom
                    anchors.topMargin: 4
                    anchors.left: parent.left
                    anchors.leftMargin: 108
                    anchors.right: parent.right
                    spacing: 8

                    Components.StyledText {
                        text: "Bar layout"
                        color: Services.Colors.surfaceVariantText
                        font.pixelSize: Services.Ui.textBody
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: 14
                    }
                    Components.StyledDropdown {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        labelWidth: 0
                        placeholder: "Keep the bar as it is"
                        model: [""].concat(Services.Settings.allBarPresets.map(b => b.name))
                            .concat(barRow.missing ? [barRow.barPreset] : [])
                        labels: barRow.missing ? { "": "Keep the bar as it is", [barRow.barPreset]: barRow.barPreset + " (deleted)" }
                                               : { "": "Keep the bar as it is" }
                        currentValue: barRow.barPreset
                        onSelected: value => Services.Settings.setThemePresetBar(presetRow.modelData.id, value,
                            barRow.perMonitor ? (presetRow.modelData.bar?.output ?? Services.Settings.primaryBarOutput) : "*")
                    }
                    Components.StyledText {
                        visible: barRow.perMonitor && barRow.barPreset !== ""
                        text: "on"
                        color: Services.Colors.surfaceVariantText
                        font.pixelSize: Services.Ui.textBody
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: 14
                    }
                    Components.StyledDropdown {
                        visible: barRow.perMonitor && barRow.barPreset !== ""
                        Layout.preferredWidth: 220
                        Layout.alignment: Qt.AlignTop
                        labelWidth: 0
                        model: ["*"].concat(Services.Settings.barOutputs)
                        labels: { "*": "Every monitor" }
                        currentValue: barRow.barOutput
                        onSelected: value => Services.Settings.setThemePresetBar(presetRow.modelData.id, barRow.barPreset, value)
                    }
                }
            }
        }
    }

    // ─── Colours ───────────────────────────────────────────────────────────
    Components.Card {
        id: coloursCard
        x: root.horizontalPadding; width: root.rowWidth
        title: "Colour theme"
        description: "Colours the bar, these panels, window borders, the terminal and most apps. It changes straight away, "
            + "and you can always switch back."

        Components.StyledDropdown {
            width: parent.width
            labelWidth: 0
            filterable: true
            maxListHeight: 320
            placeholder: "Pick a theme"
            model: Services.Theme.slugs
            labels: Services.Theme.names
            swatches: Services.Theme.swatchesBySlug
            currentValue: Services.Theme.currentSlug
            onSelected: value => Services.Theme.apply(value)
        }

        Components.TextButton {
            text: "Make your own in the theme builder"
            onClicked: Services.Actions.themePicker()
        }
    }

    // ─── Wallpapers ────────────────────────────────────────────────────────
    Components.Card {
        id: wallpapersCard
        x: root.horizontalPadding; width: root.rowWidth
        title: "Wallpapers"
        description: "Click a picture to use it as your desktop background. With more than one monitor, pick one first to give it "
            + "its own picture, or its own folder to pick from."

        Appearance.WallpapersView {
            width: parent.width
            height: Math.max(420, root.height - 140)
        }
    }
}
