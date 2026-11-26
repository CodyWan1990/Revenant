import QtQuick
import QtQuick.Layouts
import "../../services" as Services
import ".." as Components
import "." as SettingsUi

/// Settings → Keybinds: the add / edit form (action, command or app, the
/// key combination with recording, no-repeat, save / remove).
Components.Card {
    /// The keybind editor page: what's being edited, and its actions.
    required property var page
    // The page reads and fills these fields.
    property alias actionName: actionName
    property alias installedPicker: installedPicker
    property alias actionCommand: actionCommand
    property alias shortcutInput: shortcutInput
    property alias chordField: chordField
    property alias editorCard: bindingEditor
    id: bindingEditor
    Layout.fillWidth: page.stackEditor
    Layout.preferredWidth: Math.min(460, page.rowWidth * 0.48)
    Layout.alignment: Qt.AlignTop
    title: page.adding
        ? (page.template && !page.template.disabled ? "Another shortcut for " + page.template.action : "New shortcut")
        : (page.selected?.action ?? "Change a shortcut")
    description: page.adding || page.selected ? ""
        : "Click a shortcut in the list to change it, or press New shortcut."

    /// The shortcut already using the keys entered here, if any.
    readonly property var clash: page.clashFor(chordField.text, page.adding ? -1 : page.selectedLine)
    readonly property bool showForm: page.adding ? page.actionChosen : !!page.selected

    SettingsUi.OptionRow {
        title: "Group"
        visible: page.adding
        Components.StyledDropdown {
            width: parent.width
            labelWidth: 0
            enabled: !page.busy
            model: page.configSections
            descriptions: page.sectionDescriptions
            currentValue: page.addSection
            onSelected: value => {
                page.addSection = value;
                page.chooseTemplate(page.noTemplate);
            }
        }
    }

    SettingsUi.OptionRow {
        title: "What it does"
        description: "Type to search. \"Custom command\" runs anything you like."
        visible: page.adding
        Components.StyledDropdown {
            width: parent.width
            labelWidth: 0
            enabled: !page.busy
            filterable: true
            placeholder: "Choose an action\u2026"
            model: page.actionOptions
            currentValue: page.templateLine === customTemplate ? "Custom command"
                : (page.template?.action ?? "")
            onSelected: title => page.chooseAction(title)
        }
    }

    // The keyboard route to a shortcut (the list rows are mouse-only).
    SettingsUi.OptionRow {
        title: "Shortcut to change"
        visible: !page.adding
        Components.StyledDropdown {
            width: parent.width
            labelWidth: 0
            model: page.labels
            filterable: true
            placeholder: "Choose one\u2026"
            enabled: !page.busy && page.visibleBindings.length > 0
            currentValue: page.selected?.action ?? ""
            onSelected: title => page.selectBinding(page.visibleBindings.find(item => item.action === title))
        }
    }

    SettingsUi.OptionRow {
        title: "Name"
        description: "How it shows in the list, like \"Open calculator\"."
        visible: page.customAction
        Components.SettingField { id: actionName; width: parent.width; enabled: !page.busy }
    }

    SettingsUi.OptionRow {
        title: "App"
        visible: page.appForm && page.installedApps.length > 0
        AppPicker {
            id: installedPicker
            width: parent.width
            label: ""
            labelWidth: 0
            enabled: !page.busy
            placeholder: "Choose an app\u2026"
            currentValue: page.pickedApp
            onPicked: app => page.pickApp(app.title)
        }
    }

    SettingsUi.OptionRow {
        title: page.appForm ? "Or type the app or command" : "Command"
        description: page.appForm ? "An installed app's name, or a program and its options."
            : "An i3 command, like \"exec firefox\" or \"workspace 3\"."
        visible: page.customAction || page.editableExec
        Components.SettingField {
            id: actionCommand
            width: parent.width
            enabled: !page.busy
            onLiveEdited: value => { if (value !== page.pickedApp) page.pickedApp = ""; }
        }
    }

    SettingsUi.OptionRow {
        title: "Keys"
        description: page.manualShortcut ? "In i3's words, like $mod+Shift+q ($mod is Super)."
            : "Click the box, then press the keys together."
        visible: bindingEditor.showForm
        Item {
            id: shortcutInput
            width: parent.width
            height: 36
            property bool cursor: false

            function keyActivate() {
                if (page.manualShortcut) chordField.keyActivate();
                else page.run("capture", [page.mod]);
            }

            Components.TextButton {
                width: parent.width
                anchors.verticalCenter: parent.verticalCenter
                visible: !page.manualShortcut
                enabled: !page.busy
                cursor: shortcutInput.cursor
                fontBold: chordField.text !== ""
                text: page.recordingShortcut ? "Listening… press the keys"
                    : (chordField.text ? page.prettyChord(chordField.text)
                        : "Click to set the keys")
                onClicked: shortcutInput.keyActivate()
            }

            Components.SettingField {
                id: chordField
                width: parent.width
                anchors.verticalCenter: parent.verticalCenter
                visible: page.manualShortcut
                enabled: !page.busy
                cursor: shortcutInput.cursor
            }
        }
    }

    Components.StyledText {
        width: parent.width
        visible: bindingEditor.showForm && bindingEditor.clash !== null
        text: "These keys already do \"" + (bindingEditor.clash?.action ?? "") + "\". "
            + "Pick other keys, or change that shortcut first — i3 would only keep one of them."
        color: Services.Colors.yellow
        font.pixelSize: Services.Ui.textSmall
        wrapMode: Text.WordWrap
    }

    Components.TextButton {
        text: page.manualShortcut ? "Press the keys instead" : "Type the keys instead"
        visible: bindingEditor.showForm
        enabled: !page.busy
        onClicked: {
            page.manualShortcut = !page.manualShortcut;
            if (page.manualShortcut) chordField.keyActivate();
        }
    }

    Components.SettingsToggle {
        label: "Only once while held"
        description: "Holding the keys does it once, instead of again and again."
        checked: page.noRepeat
        visible: bindingEditor.showForm
        enabled: !page.busy
        onToggled: value => page.noRepeat = value
    }

    Components.StyledText {
        width: parent.width
        visible: text !== "" && !page.editableExec && !page.customAction
        text: page.adding
            ? (page.availableActions.find(item => item.line === page.templateLine)?.command ?? "")
            : (page.selected?.command ?? "")
        wrapMode: Text.WrapAnywhere
        color: Services.Colors.surfaceVariantText
        font.pixelSize: Services.Ui.textSmall
        font.family: "monospace"
    }

    Components.Divider {
        visible: page.adding || !!page.selected
    }

    Flow {
        width: parent.width
        spacing: 8
        Components.TextButton {
            text: "Save"
            fontBold: true
            idleColor: Services.Ui.menuSelectionColor
            idleTextColor: Services.Ui.menuSelectionText
            visible: !page.adding && !!page.selected
            enabled: !!page.selected && !page.busy && chordField.text.trim() !== "" && bindingEditor.clash === null
                && (!page.editableExec || actionCommand.text.trim() !== "")
                && (chordField.text.trim() !== page.selected.chord || page.noRepeat !== page.selected.noRepeat
                    || (page.editableExec && actionCommand.text.trim() !== page.selected.appCommand))
            onClicked: page.run("save", [page.selected.section, page.revisions[page.selected.section],
                String(page.selectedLine), chordField.text,
                String(page.noRepeat), page.commandForInput()])
        }
        Components.TextButton {
            text: "Add shortcut"
            fontBold: true
            idleColor: Services.Ui.menuSelectionColor
            idleTextColor: Services.Ui.menuSelectionText
            visible: page.adding
            enabled: !page.busy && page.actionChosen && chordField.text.trim() !== "" && bindingEditor.clash === null
                && (!page.customAction || actionName.text.trim() !== "")
                && (!(page.customAction || page.editableExec) || actionCommand.text.trim() !== "")
            onClicked: page.run("add", [page.addSection, page.revisions[page.addSection], String(page.templateLine),
                chordField.text, actionName.text, page.commandForInput(), String(page.noRepeat)])
        }
        Components.TextButton {
            text: "Remove this shortcut"
            visible: !page.adding && !!page.selected
            enabled: !page.busy
            hoverColor: Services.Colors.red
            onClicked: page.run("remove", [page.selected.section, page.revisions[page.selected.section],
                String(page.selectedLine)])
        }
        Components.TextButton {
            text: "Cancel"
            visible: page.adding
            enabled: !page.busy
            onClicked: {
                page.adding = false;
                chordField.text = page.selected?.chord ?? "";
                actionCommand.text = page.selected?.appCommand ?? "";
                page.noRepeat = page.selected?.noRepeat ?? false;
                page.message = "";
            }
        }
    }

    Components.StyledText {
        width: parent.width
        text: page.message
        visible: text !== ""
        wrapMode: Text.WordWrap
        color: Services.Colors.surfaceVariantText
    }
}
