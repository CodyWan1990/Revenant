import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../services" as Services
import "../../../components" as Components
import "../../../lib/BarStyle.js" as BarStyle
import "../../../components/settings" as SettingsUi
import "../../../components/settings/BarLayout.js" as BarLayout

/// Bar widget placement and per-widget settings.
Flickable {
    id: root
    anchors.fill: parent
    contentHeight: col.implicitHeight + 16
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: draggingId === "" && editingId === ""

    readonly property var activeNav: editor.item ?? nav
    readonly property int cursorIndex: activeNav.cursorIndex
    function stepCursor(delta) { return activeNav.stepCursor(delta); }
    function activate() { activeNav.activate(); }
    function adjust(delta) { activeNav.adjust(delta); }
    function clearCursor() { activeNav.clearCursor(); }

    function closeDetail() {
        if (editingId === "")
            return false;
        editingId = "";
        nav.refresh();
        return true;
    }

    property SettingsUi.KeyNavCursor nav: SettingsUi.KeyNavCursor {
        scope: col
        flick: root
    }

    Component.onCompleted: { nav.refresh(); if (pageShown) Services.WidgetCatalog.rescanUser(); }
    /// Set by SettingsWindow: a new widget folder shows up when the page opens.
    property bool pageShown: true
    onPageShownChanged: if (pageShown) Services.WidgetCatalog.rescanUser()
    Connections {
        target: col
        function onImplicitHeightChanged() { Qt.callLater(root.nav.refresh); }
    }

    readonly property var sectionOrder: ["left", "center", "right"]
    property string activeSection: "left"

    function sectionLabel(section) {
        return ({ left: "Left", center: "Centre", right: "Right" })[section] ?? section;
    }

    function displayName(w) {
        const n = Services.WidgetCatalog.name(w.type);
        if (Services.WidgetCatalog.isUser(w.type)) return n + " · yours";
        return w.type === "custom" && w.label ? n + " · " + w.label : n;
    }
    readonly property var widgetsByName: {
        const names = {};
        for (const type of Services.WidgetCatalog.types)
            names[displayName({ type: type })] = type;
        return names;
    }
    readonly property var widgetNames: Object.keys(widgetsByName).sort((a, b) => a.localeCompare(b))
    /// Add-list name -> what the widget does (WidgetCatalog.about).
    readonly property var widgetBlurbs: {
        const blurbs = {};
        for (const name of widgetNames)
            blurbs[name] = Services.WidgetCatalog.about(widgetsByName[name]);
        return blurbs;
    }

    readonly property string layoutTarget: Services.Settings.barEditOutput
    readonly property var profile: Services.Settings.barFor(layoutTarget)
    onLayoutTargetChanged: if (editingId) closeDetail()

    // Layout operations: pure functions in components/settings/BarLayout.js,
    // applied to this bar's profile.
    function arrayFor(sec) { return profile[sec]; }
    function sections() { return { left: profile.left, center: profile.center, right: profile.right }; }
    function apply(patch) {
        if (Object.keys(patch).length) Services.Settings.setBarValues(layoutTarget, patch);
    }
    function removeAt(sec, i) { apply(BarLayout.removeAt(sections(), sec, i)); }
    function moveWidget(id, toSec, toIndex) { apply(BarLayout.move(sections(), sectionOrder, id, toSec, toIndex)); }
    function moveToSection(id, section) {
        const from = locate(id);
        if (from && from.sec !== section)
            moveWidget(id, section, arrayFor(section).length);
    }
    function add(sec, type) {
        const inst = Services.Settings.normalizeWidget({ type: type });
        apply(BarLayout.append(sections(), sec, inst));
        editingId = inst.id;   // open the editor on the new widget
    }
    function locate(id) { return BarLayout.locate(sections(), sectionOrder, id); }
    function updateWidget(id, patch) { apply(BarLayout.update(sections(), sectionOrder, id, patch)); }
    function updateSpacerOption(id, key, value, applyToAll) {
        apply(BarLayout.updateSpacer(sections(), sectionOrder, id, key, value, applyToAll));
    }

    property string draggingId: ""

    property string editingId: ""
    readonly property var editedWidget: editingId === "" ? null : locate(editingId)

    Column {
        id: col
        visible: !editor.active
        width: root.width
        topPadding: 16
        bottomPadding: 16
        spacing: 14

        Components.Card {
            x: 24
            width: col.width - 48
            title: "Monitors"
            visible: Services.Settings.barOutputs.length > 1 || Services.Settings.barLayoutMode === "separate"

            SettingsUi.BarMonitorPicker {
                width: parent.width
            }
        }

        Components.Card {
            id: secCard
            readonly property string section: root.activeSection
            x: 24
            width: col.width - 48
            title: "What's on the bar"
            description: "The bar has three parts: left, centre and right. Pick one to see what's in it. "
                + "Drag \u2630 or use the arrows to change the order; the part names on a row move it there."

            readonly property var items: root.arrayFor(section)

            Components.SegmentedControl {
                width: parent.width
                labelWidth: 0
                model: root.sectionOrder.map(section => ({
                    value: section, label: root.sectionLabel(section) + " (" + root.arrayFor(section).length + ")"
                }))
                valueRole: "value"
                textRole: "label"
                currentValue: root.activeSection
                onSelected: section => {
                    root.activeSection = section;
                    Qt.callLater(root.nav.refresh);
                }
            }

            Components.StyledText {
                visible: secCard.items.length === 0
                width: parent.width
                text: "Nothing here yet — add a widget below."
                color: Services.Colors.surfaceVariantText
                font.pixelSize: Services.Ui.textBody
                font.italic: true
            }

            Repeater {
                model: secCard.items

                delegate: SettingsUi.BarWidgetRow {
                    page: root
                    card: secCard
                    ghost: dragGhost
                }
            }

            SettingsUi.OptionRow {
                title: "Add a widget to the " + root.sectionLabel(secCard.section).toLowerCase()
                description: "Type to search. Its options open straight after, so you can set it up."
                Components.StyledDropdown {
                    width: parent.width
                    labelWidth: 0
                    model: root.widgetNames
                    descriptions: root.widgetBlurbs
                    filterable: true
                    placeholder: "Choose a widget\u2026"
                    currentValue: ""
                    onSelected: value => root.add(secCard.section, root.widgetsByName[value])
                }
            }
        }

        Components.Card {
            x: 24
            width: col.width - 48
            title: "Your own widgets"
            description: "Each folder in your widgets folder with a widget.json and a Widget.qml is a widget you can add above "
                + "(marked \u201cyours\u201d). Saving one of its files updates it on the bar."

            Components.StyledText {
                width: parent.width
                text: Services.WidgetCatalog.userEntries.length === 0 ? "None yet." :
                    Services.WidgetCatalog.userEntries.map(entry => entry.name).join(", ")
                color: Services.Colors.surfaceVariantText
                font.pixelSize: Services.Ui.textSmall
                wrapMode: Text.WordWrap
            }
            Repeater {
                model: Services.WidgetCatalog.userErrors
                Components.StyledText {
                    required property var modelData
                    width: parent.width
                    text: modelData.id + ": " + modelData.message
                    color: Services.Colors.red
                    font.pixelSize: Services.Ui.textSmall
                    wrapMode: Text.WordWrap
                }
            }
            Components.StyledText {
                width: parent.width
                text: Services.WidgetCatalog.userDir
                color: Services.Colors.accent
                font.pixelSize: Services.Ui.textSmall
                wrapMode: Text.WrapAnywhere
            }
            Row {
                spacing: 8
                Components.TextButton {
                    text: "Open widgets folder"
                    onClicked: Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && exec xdg-open \"$1\"",
                        "sh", Services.WidgetCatalog.userDir])
                }
                Components.TextButton {
                    text: "Look again"
                    onClicked: Services.WidgetCatalog.rescanUser()
                }
            }
        }

        Components.Card {
            id: presetsCard
            x: 24
            width: col.width - 48
            title: "Saved layouts"
            description: "Save the bar as it is now — its widgets and look — so you can come back to it after experimenting."

            readonly property var names: Services.Settings.barPresets.map(preset => preset.name)
            property string selectedName: ""
            readonly property string presetName: names.includes(selectedName) ? selectedName : names[0] ?? ""

            SettingsUi.OptionRow {
                visible: presetsCard.names.length > 0
                title: "Your layouts"
                Column {
                    width: parent.width
                    spacing: 8
                    Components.StyledDropdown {
                        width: parent.width
                        labelWidth: 0
                        model: presetsCard.names
                        currentValue: presetsCard.presetName
                        onSelected: name => presetsCard.selectedName = name
                    }
                    Row {
                        visible: presetsCard.presetName !== ""
                        spacing: 8

                        Components.TextButton {
                            text: "Use this layout"
                            onClicked: Services.Settings.applyBarPreset(presetsCard.presetName, root.layoutTarget)
                        }
                        Components.TextButton {
                            text: "Delete it"
                            onClicked: Services.Settings.deleteBarPreset(presetsCard.presetName)
                        }
                    }
                }
            }

            SettingsUi.OptionRow {
                title: "Save the bar as it is now"
                description: "Give it a name, like \"Work\" or \"Minimal\"."
                Components.SettingField {
                    id: presetNameField
                    width: parent.width
                }
            }
            Components.TextButton {
                readonly property string presetName: presetNameField.text.trim()
                readonly property bool duplicate: presetsCard.names.includes(presetName)
                text: duplicate ? "That name is taken" : "Save layout"
                enabled: presetName !== "" && !duplicate
                onClicked: {
                    if (Services.Settings.saveBarPreset(presetName, root.layoutTarget)) {
                        presetsCard.selectedName = presetName;
                        presetNameField.text = "";
                    }
                }
            }
        }

    }

    Loader {
        id: editor
        parent: root
        anchors.fill: parent
        z: 1
        active: root.editedWidget !== null

        sourceComponent: SettingsUi.SettingsPage {
            id: ed
            horizontalPadding: 24
            verticalPadding: 16
            contentSpacing: 14

            readonly property var loc: root.editedWidget
            property bool applyToAllSpacers: false
            readonly property string optionType: widget?.type === "spacer" ? "separator" : widget?.type ?? ""
            readonly property bool glyphHidden: widget?.hideGlyph === true || !(widget?.glyph ?? "").trim()
            readonly property var specs: {
                const all = Services.WidgetCatalog.options(optionType);
                // `showIf: "<key>"` rows only appear while that option is on
                // (e.g. the GPU text, only while GPU is shown).
                const options = all.filter(spec => !spec.hidden).filter(spec => !spec.showIf || keyValue(spec.showIf));
                if (optionType !== "separator" || !glyphHidden) return options;
                return options.filter(spec => spec.key === "width" || spec.key === "hideGlyph");
            }
            readonly property var widget: loc?.widget
            readonly property string surface: widget?.surface ?? "inherit"
            readonly property string decoration: widget?.style ?? defaultDecoration
            readonly property string colorKey: widget?.color ?? "auto"
            readonly property string iconSet: widget?.iconSet ?? "auto"
            readonly property string defaultDecoration: Services.Settings.defaultStyleFor(widget?.type)
            readonly property bool hasAppearanceOverrides: surface !== "inherit"
                || decoration !== defaultDecoration || colorKey !== "auto" || iconSet !== "auto"

            function optValue(spec) {
                if (optionType === "separator" && spec.key === "width")
                    return Services.Settings.separatorWidth(widget);
                if (optionType === "separator" && spec.key === "hideGlyph")
                    return glyphHidden;
                return keyValue(spec.key);
            }

            /// An option's value: the saved one, else an older key it replaced
            /// (the spec's `legacyKey`, e.g. Disks' old `format` for `custom`),
            /// else its fallback.
            function keyValue(key) {
                const all = Services.WidgetCatalog.options(optionType);
                const spec = all.find(other => other.key === key);
                return widget?.[key] ?? (spec?.legacyKey ? widget?.[spec.legacyKey] : undefined) ?? spec?.fallback;
            }

            function setOpt(spec, value) {
                if (optionType === "separator")
                    root.updateSpacerOption(root.editingId, spec.key, value, applyToAllSpacers);
                else
                    root.updateWidget(root.editingId, { [spec.key]: value });
            }

            RowLayout {
                x: ed.horizontalPadding
                width: ed.rowWidth
                spacing: 14

                Components.TextButton {
                    text: "‹ Back"
                    onClicked: root.closeDetail()
                }

                Column {
                    Layout.fillWidth: true

                    Components.StyledText {
                        width: parent.width
                        text: ed.loc ? root.displayName(ed.loc.widget) : ""
                        font.pixelSize: Services.Ui.textHeading
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Components.StyledText {
                        width: parent.width
                        visible: text !== ""
                        text: Services.WidgetCatalog.about(ed.widget?.type === "spacer" ? "separator" : ed.widget?.type ?? "")
                        color: Services.Colors.foreground
                        font.pixelSize: Services.Ui.textBody
                        wrapMode: Text.WordWrap
                    }
                    Components.StyledText {
                        width: parent.width
                        text: ed.loc ? (root.layoutTarget ? "Bar on " + root.layoutTarget : "The bar")
                            + "  ·  " + root.sectionLabel(ed.loc.sec) + " part"
                            + "  ·  position " + (ed.loc.index + 1) : ""
                        color: Services.Colors.surfaceVariantText
                        font.pixelSize: Services.Ui.textSmall
                    }
                }
            }

            Components.Card {
                id: optionsCard
                x: ed.horizontalPadding
                width: ed.rowWidth
                title: "Options"
                visible: ed.specs.length > 0

                Components.SettingsToggle {
                    visible: ed.optionType === "separator"
                    label: "Change every divider at once"
                    description: "Changes here apply to every spacer and divider on this bar."
                    checked: ed.applyToAllSpacers
                    onToggled: value => {
                        ed.applyToAllSpacers = value;
                        if (value && ed.glyphHidden)
                            root.updateSpacerOption(root.editingId, "hideGlyph", true, true);
                    }
                }

                Repeater {
                    model: ed.specs

                    delegate: SettingsUi.SettingsOptionEditor {
                        required property var modelData
                        width: optionsCard.width - 36
                        spec: modelData
                        value: ed.optValue(modelData)
                        choices: modelData.type === "palette" ? Services.Colors.paletteKeys
                            : modelData.choicesFrom === "mounts" ? Services.Disks.choices
                            : (modelData.choices ?? [])
                        onValueEdited: value => ed.setOpt(modelData, value)
                    }
                }
            }

            Components.Card {
                x: ed.horizontalPadding
                width: ed.rowWidth
                title: "Look"
                description: "Leave these alone to match the rest of the bar (Bar → Appearance)."

                // Dux widget style override for just this widget.
                SettingsUi.ChoiceRow {
                    title: "Background"
                    choices: [
                        { value: "inherit", label: "Like the bar", hint: "Follows the style chosen in Bar → Appearance." },
                        { value: "pill", label: "Bubble", hint: "On its own rounded bubble." },
                        { value: "plain", label: "None", hint: "Just text and icon, with room around it." },
                        { value: "polybar", label: "Classic", hint: "Plain text, with an optional underline or box below." }
                    ]
                    value: ed.surface
                    onSelected: value => root.updateWidget(root.editingId, { surface: value })
                }

                // Only drawn when the widget ends up polybar-style.
                SettingsUi.ChoiceRow {
                    title: "Decoration"
                    visible: BarStyle.effectiveSurface(root.profile.widgetStyle, ed.surface) === "polybar"
                    choices: [
                        { value: "none", label: "None", hint: "" },
                        { value: "underline", label: "Underline", hint: "A coloured line under the widget." },
                        { value: "box", label: "Box", hint: "A coloured outline around the widget." },
                        { value: "pill", label: "Bubble", hint: "A rounded coloured outline." }
                    ]
                    value: ed.decoration
                    onSelected: value => root.updateWidget(root.editingId, { style: value })
                }

                SettingsUi.OptionRow {
                    title: "Colour"
                    description: "A colour from your theme, so it changes with it. \"auto\" picks one that suits the widget."
                    Components.StyledDropdown {
                        width: parent.width
                        labelWidth: 0
                        model: Services.Colors.paletteKeys
                        currentValue: ed.colorKey
                        paletteSwatches: true
                        filterable: true
                        onSelected: value => root.updateWidget(root.editingId, { color: value })
                    }
                }

                SettingsUi.ChoiceRow {
                    title: "Icon"
                    choices: [
                        { value: "auto", label: "Default", hint: "Uses the icon style from Appearance → Fonts & icons." },
                        { value: "nerd", label: "Nerd Font", hint: "Simple line icon from your font." },
                        { value: "material", label: "Material", hint: "Rounded icon that comes with the shell." },
                        { value: "emoji", label: "Emoji", hint: "A colourful emoji." },
                        { value: "none", label: "None", hint: "No icon, just text." }
                    ]
                    value: ed.iconSet
                    onSelected: value => root.updateWidget(root.editingId, { iconSet: value })
                }

                Components.TextButton {
                    text: "Match the bar again"
                    visible: ed.hasAppearanceOverrides
                    onClicked: root.updateWidget(root.editingId, {
                        surface: "inherit", style: ed.defaultDecoration, color: "auto", iconSet: "auto"
                    })
                }
            }
        }
    }

    // Floating drag ghost (follows the cursor while a row is dragged).
    Item {
        id: dragGhost
        width: 110; height: 28
        z: 1000
        visible: Drag.active
        property string label: ""
        Drag.active: false
        Drag.keys: ["barwidget"]
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2

        Rectangle {
            anchors.fill: parent
            radius: 6
            color: Services.Colors.accent
            opacity: 0.92
            Components.StyledText {
                anchors.centerIn: parent
                text: dragGhost.label
                color: Services.Colors.background
                font.pixelSize: Services.Ui.textSmall
                font.bold: true
                elide: Text.ElideRight
                width: parent.width - 8
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
