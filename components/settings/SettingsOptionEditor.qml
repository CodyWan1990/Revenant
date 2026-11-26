import QtQuick
import "../../services" as Services
import ".." as Components

/// Spec-driven settings editor for per-widget options (WidgetCatalog options).
/// Laid out like the rest of Settings: the option's label (and its
/// `description`, when the spec has one) above a full-width control. A short
/// list of short choices is a row of buttons; longer lists are a dropdown.
Item {
    id: root

    property var spec: ({})
    property var value: undefined
    property var choices: spec.choices ?? []
    /// Unused since the labels moved above the controls; kept so older hosts
    /// that set it still load.
    property int labelWidth: 110
    signal valueEdited(var value)

    // ─── keyboard: forward the host's row cursor to whichever editor the
    // Loader built. A section header or a note is not a stop, so it reports
    // none; a `preset` row showing its custom field, and the workspace layout
    // list, are several, and those come from the loaded item itself.
    property int cursorIndex: -1
    readonly property bool navigable: !spec.section && spec.type !== "note"
    /// The loaded editor, duck-typed: each one implements only the parts of
    /// the cursor contract it needs (selectableCount/cursorIndex/activateAt/
    /// adjustAt, or the single-stop cursor/keyActivate/keyAdjust).
    readonly property var loadedEditor: editor.item
    readonly property int selectableCount: {
        if (!navigable || !loadedEditor)
            return 0;
        return loadedEditor.selectableCount !== undefined
            ? loadedEditor.selectableCount : 1;
    }

    onCursorIndexChanged: paintCursor()
    function paintCursor() {
        const item = root.loadedEditor;
        if (!item)
            return;
        if (item.selectableCount !== undefined)
            item.cursorIndex = cursorIndex;
        else if (item.cursor !== undefined)
            item.cursor = cursorIndex === 0;
    }

    function activateAt(i) {
        const item = root.loadedEditor;
        if (!item)
            return;
        if (item.activateAt !== undefined)
            item.activateAt(i);
        else if (item.keyActivate !== undefined)
            item.keyActivate();
    }

    function adjustAt(i, delta) {
        const item = root.loadedEditor;
        if (!item)
            return;
        if (item.adjustAt !== undefined)
            item.adjustAt(i, delta);
        else if (item.keyAdjust !== undefined)
            item.keyAdjust(delta);
    }

    readonly property Item editorItem: editor.item as Item
    implicitHeight: editorItem
        ? (editorItem.implicitHeight > 0 ? editorItem.implicitHeight : editorItem.height)
        : 0
    height: implicitHeight

    function choiceLabel(choice) {
        return typeof choice === "object" ? choice.label : choice;
    }
    function choiceValue(choice) {
        return typeof choice === "object" ? choice.value : choice;
    }
    function labelForValue(current) {
        for (const choice of choices)
            if (choiceValue(choice) === current)
                return choiceLabel(choice);
        return current ?? "";
    }
    /// Up to four choices whose labels fit side by side read better as
    /// buttons than as a dropdown you have to open.
    readonly property bool useSegments: {
        if (choices.length < 2 || choices.length > 4 || spec.type === "palette" || spec.filterable)
            return false;
        const labels = choices.map(choice => String(choiceLabel(choice)));
        return labels.every(label => label.length <= 18) && labels.join("").length <= 48;
    }

    function valueForLabel(label) {
        for (const choice of choices)
            if (choiceLabel(choice) === label)
                return choiceValue(choice);
        return label;
    }

    Loader {
        id: editor
        width: parent.width
        height: root.height
        // A rebuilt editor starts with no cursor; re-apply whatever the host
        // had set, or the highlight vanishes when a row changes shape.
        onLoaded: root.paintCursor()
        sourceComponent: {
            if (root.spec.section) return sectionEditor;
            switch (root.spec.type) {
            case "bool": return boolEditor;
            case "int":
            case "float": return sliderEditor;
            case "enum":
            case "choice":
            case "palette": return root.useSegments ? segmentEditor : dropdownEditor;
            case "preset": return root.useSegments && root.spec.allowCustom === false ? segmentEditor : presetEditor;
            case "multi": return multiEditor;
            case "note": return noteEditor;
            default: return textEditor;
            }
        }
    }

    /// The option's name, plus its description when the spec has one. Takes
    /// the accent while the keyboard cursor is on the row, like other labels.
    component Heading: Column {
        property bool cursor: false
        width: parent?.width ?? 0
        spacing: 2

        Components.StyledText {
            width: parent.width
            text: root.spec.label ?? ""
            color: parent.cursor ? Services.Colors.accent : Services.Colors.foreground
            font.pixelSize: Services.Ui.textBodyLarge
            font.bold: true
            wrapMode: Text.WordWrap
        }
        Components.StyledText {
            width: parent.width
            visible: text !== ""
            text: root.spec.description ?? ""
            color: Services.Colors.surfaceVariantText
            font.pixelSize: Services.Ui.textSmall
            wrapMode: Text.WordWrap
        }
    }

    /// A heading over one control, forwarding the single-stop cursor
    /// contract (cursor / keyActivate / keyAdjust) to that control.
    component Stacked: Column {
        id: stacked
        property bool cursor: false
        // `var`: a control is duck-typed (cursor, keyActivate, keyAdjust).
        property var control: null
        width: parent?.width ?? 0
        spacing: 6
        topPadding: 4
        bottomPadding: 4
        onCursorChanged: if (control) control.cursor = cursor
        function keyActivate() { control?.keyActivate(); }
        function keyAdjust(delta) { if (control?.keyAdjust) control.keyAdjust(delta); }

        Heading { cursor: stacked.cursor }
    }

    Component {
        id: sectionEditor
        Item {
            width: parent.width
            implicitHeight: 40

            SectionHeader {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                text: root.spec.section
            }
        }
    }

    // A checklist: `choices` are { value, label, description? }; the value is
    // the array of checked values, kept in the choices' order. One keyboard
    // stop per choice.
    Component {
        id: multiEditor
        Column {
            id: multi
            width: parent.width
            spacing: 2
            topPadding: 4
            bottomPadding: 4
            property int cursorIndex: -1
            readonly property int selectableCount: root.choices.length
            // Array.from: a saved list can arrive list-like rather than a JS array.
            readonly property var checkedValues: root.value?.length !== undefined ? Array.from(root.value) : []

            function setChecked(value, on) {
                const wanted = new Set(checkedValues);
                if (on) wanted.add(value); else wanted.delete(value);
                root.valueEdited(root.choices.map(choice => choice.value).filter(v => wanted.has(v)));
            }
            function activateAt(i) {
                const choice = root.choices[i];
                if (choice) setChecked(choice.value, !checkedValues.includes(choice.value));
            }
            function adjustAt(i, delta) {
                const choice = root.choices[i];
                if (choice) setChecked(choice.value, delta > 0);
            }

            Heading { cursor: multi.cursorIndex >= 0 }
            Components.StyledText {
                width: parent.width
                visible: root.choices.length === 0
                text: root.spec.emptyText ?? "Nothing to choose from."
                color: Services.Colors.surfaceVariantText
                font.pixelSize: Services.Ui.textSmall
            }
            Repeater {
                model: root.choices
                Components.SettingsToggle {
                    required property var modelData
                    required property int index
                    width: multi.width
                    label: modelData.label
                    description: modelData.description ?? ""
                    checked: multi.checkedValues.includes(modelData.value)
                    cursor: index === multi.cursorIndex
                    onToggled: value => multi.setChecked(modelData.value, value)
                }
            }
        }
    }

    Component {
        id: boolEditor
        // The same switch as the rest of Settings (was an On | Off segment).
        Components.SettingsToggle {
            width: parent.width
            label: root.spec.label
            description: root.spec.description ?? ""
            checked: !!root.value
            onToggled: value => root.valueEdited(value)
        }
    }

    Component {
        id: sliderEditor
        Stacked {
            control: slider
            Components.StyledSlider {
                id: slider
                readonly property real unit: root.spec.scale ?? 1
                width: parent.width
                labelWidth: 0
                suffix: root.spec.suffix ?? ""
                from: root.spec.from
                to: root.spec.to
                stepSize: root.spec.step ?? 1
                decimals: root.spec.decimals ?? 0
                value: root.value / unit
                onMoved: movedValue => root.valueEdited(root.spec.type === "int"
                    ? Math.round(movedValue) * unit
                    : Math.round(movedValue / stepSize) * stepSize * unit)
            }
        }
    }

    Component {
        id: segmentEditor
        Stacked {
            control: segments
            Components.SegmentedControl {
                id: segments
                width: parent.width
                model: root.choices.map(choice => ({ value: root.choiceValue(choice), label: root.choiceLabel(choice) }))
                valueRole: "value"; textRole: "label"
                currentValue: root.value ?? ""
                onSelected: value => root.valueEdited(value)
            }
        }
    }

    Component {
        id: dropdownEditor
        Stacked {
            control: dropdown
            Components.StyledDropdown {
                id: dropdown
                width: parent.width
                labelWidth: 0
                filterable: root.spec.filterable === true
                paletteSwatches: root.spec.type === "palette"
                model: root.choices.map(choice => root.choiceLabel(choice))
                currentValue: root.labelForValue(root.value)
                onSelected: label => root.valueEdited(root.valueForLabel(label))
            }
        }
    }

    Component {
        id: presetEditor
        Column {
            id: preset
            readonly property bool allowCustom: root.spec.allowCustom !== false
            readonly property bool hasMatch: root.choices.some(
                choice => root.choiceValue(choice) === root.value)
            property bool customOpen: allowCustom && !hasMatch
            width: parent.width
            spacing: 6
            topPadding: 4
            bottomPadding: 4

            // Two stops once the custom field is showing: the preset dropdown,
            // then the free-text value it revealed.
            property int cursorIndex: -1
            readonly property int selectableCount: customOpen ? 2 : 1
            onCursorIndexChanged: {
                dropdown.cursor = cursorIndex === 0;
                customField.cursor = cursorIndex === 1;
            }
            function activateAt(i) {
                if (i === 0) dropdown.keyActivate();
                else customField.keyActivate();
            }
            function adjustAt(i, delta) {
                if (i === 0) dropdown.keyAdjust(delta);
            }

            Heading { cursor: preset.cursorIndex >= 0 }

            Components.StyledDropdown {
                id: dropdown
                width: parent.width
                labelWidth: 0
                model: root.choices.map(choice => root.choiceLabel(choice))
                    .concat(preset.allowCustom ? ["Custom…"] : [])
                currentValue: preset.customOpen ? "Custom…" : root.labelForValue(root.value)
                onSelected: label => {
                    if (label === "Custom…") {
                        preset.customOpen = true;
                        return;
                    }
                    preset.customOpen = false;
                    root.valueEdited(root.valueForLabel(label));
                }
            }

            Components.SettingField {
                id: customField
                width: parent.width
                visible: preset.customOpen
                Component.onCompleted: text = root.value ?? ""
                onEdited: value => root.valueEdited(value)
            }

            Components.StyledText {
                width: parent.width
                visible: preset.customOpen && !!root.spec.hint
                text: "You can use: " + (root.spec.hint ?? "")
                color: Services.Colors.surfaceVariantText
                font.pixelSize: Services.Ui.textSmall
                wrapMode: Text.WordWrap
            }
        }
    }

    Component {
        id: textEditor
        Stacked {
            control: field
            Components.SettingField {
                id: field
                width: parent.width
                Component.onCompleted: text = root.spec.type === "csv"
                    ? (root.value || []).join(", ") : (root.value ?? "")
                onEdited: value => root.valueEdited(root.spec.type === "csv"
                    ? value.split(",").map(part => part.trim()).filter(part => part.length > 0)
                    : value)
            }
        }
    }

    Component {
        id: noteEditor
        Components.StyledText {
            width: parent.width
            topPadding: 2
            bottomPadding: 2
            text: root.spec.text ?? ""
            color: Services.Colors.surfaceVariantText
            font.pixelSize: Services.Ui.textSmall
            wrapMode: Text.WordWrap
        }
    }
}
