import QtQuick
import QtQuick.Layouts
import "../../../services" as Services
import "../../../components" as Components
import "../../../components/settings" as SettingsUi
import "../../../lib" as Lib

SettingsUi.SettingsPage {
    id: root
    anchors.fill: parent
    horizontalPadding: 24
    contentSpacing: 20
    readonly property bool stackEditor: rowWidth < 690

    property var bindings: []
    property var templates: []
    property var configSections: []
    property var revisions: ({})
    property string mod: "Mod4"
    // Names shared with scripts/i3/i3-key-editor.py: its section headings, and
    // the template line it reads as "Custom command". A template's `kind`
    // ("binding" | "action" | "role") says what it is; see the script's header.
    readonly property string allSections: "All shortcuts"
    readonly property string defaultAppsSection: "Default Apps"
    readonly property string customAppsSection: "Custom Apps"
    readonly property int customTemplate: -1
    /// templateLine when no action is chosen yet (editor-only).
    readonly property int noTemplate: -2

    property int selectedLine: -1
    property string section: allSections
    property string message: ""
    /// Search text: matches an action's name, its keys or its section.
    property string query: ""
    property bool adding: false
    property string addSection: ""
    property int templateLine: noTemplate
    property bool noRepeat: false
    property bool manualShortcut: false
    property string pickedApp: ""
    readonly property bool customAction: adding && templateLine === customTemplate
    readonly property bool actionChosen: templateLine !== noTemplate
    readonly property var availableActions: templates.filter(item => item.section === addSection)
    readonly property var template: availableActions.find(item => item.line === templateLine)
    readonly property bool editableExec: (adding ? template?.appCommand : selected?.appCommand) != null
    readonly property bool appForm: editableExec || (customAction && addSection === root.customAppsSection)
    readonly property var installedApps: Services.Apps.pickable
    readonly property var actionOptions: actionTitles(availableActions).concat(addSection === root.defaultAppsSection ? [] : ["Custom command"])
    readonly property bool busy: worker.running
    readonly property bool recordingShortcut: busy && worker.operation === "capture"
    readonly property var selected: bindings.find(binding => binding.line === selectedLine)
    readonly property var sectionDescriptions: ({
        [allSections]: "Every section",
        [defaultAppsSection]: "Your browser, file manager, … (from Default apps)",
        [customAppsSection]: "Apps you've given a shortcut",
        "Shell panels": "Launcher and menus",
        "Windows": "Focus, move, and resize",
        "Scratchpad": "Hide and recall windows",
        "Workspaces": "Switch and move",
        "Monitors": "Switch and move across displays",
        "Audio": "Volume and mute",
        "Screenshots": "Capture the screen",
        "Session": "Reload, restart, and log out"
    })
    readonly property var sections: [root.allSections].concat(configSections)
    readonly property var visibleBindings: section === root.allSections
        ? bindings : bindings.filter(binding => binding.section === section)
    readonly property var labels: actionTitles(visibleBindings)

    function matchesQuery(item) {
        const words = query.trim().toLowerCase().split(/\s+/).filter(word => word && word !== "+");
        const text = (item.action + " " + item.keys + " " + item.section).toLowerCase();
        return words.every(word => text.includes(word));
    }

    readonly property var rows: {
        const result = [];
        for (const name of configSections) {
            if (section !== root.allSections && section !== name)
                continue;
            const entries = templates.filter(item => item.section === name && root.matchesQuery(item));
            if (!entries.length)
                continue;
            result.push({ heading: name });
            for (const binding of entries)
                result.push({ binding: binding });
        }
        return result;
    }

    property var defaultHandlers: ({})
    property bool defaultHandlersReady: false

    function defaultApp(binding) {
        if (binding?.defaultRole === "terminal") {
            const terminal = Services.DefaultApps.terminalEntry;
            return terminal ? { name: terminal.name, id: terminal.id } : null;
        }
        return defaultHandlers[binding?.defaultRole]?.default ?? null;
    }

    Lib.JsonScript {
        id: defaultAppsQuery
        script: "system/default-apps.py"
        fallbackError: "Could not read the desktop default apps."
        onFailed: message => console.warn("Keybinds:", message)
        onSucceeded: result => {
            root.defaultHandlers = result.handlers;
            root.defaultHandlersReady = true;
            if (root.adding && root.template?.kind === "role" && form.actionCommand.text === "")
                root.fillDefaultCommand();
        }
    }

    function refreshDefaultApps() {
        const roles = templates.map(binding => binding.defaultRole)
            .filter((role, index, roles) => !!role && role !== "terminal" && roles.indexOf(role) === index);
        if (roles.length) defaultAppsQuery.run("", roles);
    }

    function fillDefaultCommand() {
        const app = defaultApp(template);
        if (app && /^[A-Za-z0-9_.+-]+$/.test(app.id))
            form.actionCommand.text = "gtk-launch " + app.id;
    }

    /// A chord compared the way i3 reads it: case and modifier order don't
    /// matter ("$mod+Shift+q" is "Shift+$mod+Q").
    function chordKey(chord) {
        const parts = String(chord ?? "").toLowerCase().split("+").map(part => part.trim()).filter(part => part);
        const key = parts.pop() ?? "";
        return parts.sort().concat([key]).join("+");
    }
    /// "$mod+Shift+q" as people read it: "Super + Shift + Q".
    function prettyChord(chord) {
        const names = { "$mod": "Super", "mod4": "Super", "mod1": "Alt", "return": "Enter", "ctrl": "Ctrl",
                        "control": "Ctrl", "shift": "Shift", "space": "Space", "escape": "Esc" };
        return String(chord ?? "").split("+").filter(part => part).map(part => names[part.toLowerCase()]
            ?? (part.length === 1 ? part.toUpperCase() : part)).join(" + ");
    }

    /// The other shortcut already using `chord`, if any.
    function clashFor(chord, exceptLine) {
        const wanted = chordKey(chord);
        if (!wanted) return null;
        return bindings.find(binding => !binding.disabled && binding.line !== exceptLine
            && chordKey(binding.chord) === wanted) ?? null;
    }

    function actionTitles(items) {
        return items.map(item => item.action)
            .filter((title, index, titles) => titles.indexOf(title) === index);
    }

    function chooseAction(title) {
        if (title === "Custom command") {
            chooseTemplate(root.customTemplate);
            return;
        }
        const choice = availableActions.find(item => item.action === title && item.disabled)
            ?? availableActions.find(item => item.action === title);
        chooseTemplate(choice?.line ?? -2);
    }

    function revealEditor() {
        if (stackEditor)
            Qt.callLater(() => {
                const position = form.mapToItem(contentItem, 0, 0);
                contentY = Math.min(position.y - verticalPadding, Math.max(0, contentHeight - height));
            });
    }

    function selectBinding(binding) {
        if (!binding || busy)
            return;
        if (binding.disabled) {
            beginAdd(binding);
            return;
        }
        adding = false;
        manualShortcut = false;
        selectedLine = binding.line;
        form.chordField.text = binding.chord;
        form.actionCommand.text = binding.appCommand ?? "";
        noRepeat = binding.noRepeat;
        message = "";
        revealEditor();
    }

    function beginAdd(binding: var) {
        addSection = binding?.section
            ?? (section === root.allSections ? (selected?.section ?? configSections[0]) : section);
        adding = true;
        chooseTemplate(binding?.line ?? -2);
        form.actionName.text = "";
        message = "";
        revealEditor();
    }

    function beginAddApp() {
        beginAdd();
        section = root.customAppsSection;
        addSection = root.customAppsSection;
        chooseTemplate(root.customTemplate);
        form.installedPicker.expand();
    }

    function commandForInput() {
        const command = form.actionCommand.text.trim();
        if (!appForm) return command;
        const input = command.toLowerCase();
        const matches = installedApps.filter(app => app.title.toLowerCase() === input || app.name.toLowerCase() === input);
        return matches.length === 1 ? "gtk-launch " + matches[0].id : command;
    }

    function pickApp(title) {
        const app = installedApps.find(item => item.title === title);
        if (!app) return;
        pickedApp = title;
        form.actionCommand.text = title;
        if (customAction) form.actionName.text = "Open " + app.name;
    }

    function chooseTemplate(line) {
        templateLine = line;
        manualShortcut = false;
        pickedApp = "";
        form.actionCommand.text = template?.appCommand ?? "";
        if (template?.kind === "role") fillDefaultCommand();
        noRepeat = template?.noRepeat ?? false;
        form.chordField.text = template?.disabled ? template.chord : "";
    }

    function run(operation, args = []) {
        if (worker.run(operation, args))
            message = operation === "capture" ? "Press the keys now, all together. Esc cancels." : "";
    }

    function findSameBinding(items, previous) {
        if (!previous) return undefined;
        return items.find(item => item.section === previous.section && item.action === previous.action
            && item.command === previous.command && item.chord === previous.chord
            && item.disabled === previous.disabled && item.noRepeat === previous.noRepeat);
    }

    Component.onCompleted: run("list")

    Lib.JsonScript {
        id: worker
        script: "i3/i3-key-editor.py"
        fallbackError: "Could not complete the keybind operation."
        onFailed: message => root.message = message
        onSucceeded: (result, operation) => {
            if (operation === "capture") {
                if (result.chord) form.chordField.text = result.chord;
                root.message = result.chord ? "Got it." : "Stopped listening.";
            } else {
                const previous = root.selected;
                const previousTemplate = root.template;
                let keepDraft = false;
                root.bindings = result.bindings;
                root.templates = result.templates;
                root.configSections = result.sections;
                root.refreshDefaultApps();
                root.revisions = result.revisions;
                root.mod = result.mod;
                if (root.sections.indexOf(root.section) < 0) root.section = root.allSections;
                if (operation === "list") {
                    const matching = root.findSameBinding(root.bindings, previous);
                    root.selectedLine = matching?.line ?? -1;
                    keepDraft = !!matching;
                    if (root.adding && !root.configSections.includes(root.addSection)) {
                        root.adding = false;
                        keepDraft = false;
                        root.message = "The shortcut section is no longer available.";
                    } else if (root.adding && previousTemplate) {
                        const matchingTemplate = root.findSameBinding(root.templates, previousTemplate);
                        if (matchingTemplate) {
                            root.templateLine = matchingTemplate.line;
                        } else {
                            root.chooseTemplate(root.noTemplate);
                            root.message = "That action is no longer available.";
                        }
                    } else if (previous && !matching && !root.adding) {
                        root.message = "That shortcut is no longer in the file.";
                    }
                }
                if (operation === "remove" || operation === "add") {
                    if (operation === "add") root.section = root.addSection;
                    root.adding = false;
                    root.selectedLine = -1;
                    root.message = operation === "add" ? "Shortcut added — try it."
                        : "Shortcut removed.";
                }
                if (!root.adding && !keepDraft) {
                    form.chordField.text = root.selected?.chord ?? "";
                    form.actionCommand.text = root.selected?.appCommand ?? "";
                    root.noRepeat = root.selected?.noRepeat ?? false;
                }
                if (operation === "save") root.message = "Saved — try it.";
            }
        }
    }

    // Shown when the running i3 config has no keys module yet.
    Components.Card {
        x: root.horizontalPadding
        width: root.rowWidth
        visible: worker.lastResult?.setup === true
        title: "One-time setup needed"
        description: (worker.lastResult?.error ?? "") + " Setting up adds a small file next to your "
            + "i3 config (in modules/) and one line to include it. i3 checks the result before anything is saved."
        Components.TextButton {
            text: "Set up"
            enabled: !worker.running
            onClicked: root.run("setup")
        }
    }

    Components.Card {
        id: filterCard
        x: root.horizontalPadding
        width: root.rowWidth
        title: "Keyboard shortcuts"
        description: "Press keys together to do things quickly, like Super + Enter to open a terminal. "
            + "Super is the Windows key on most keyboards. Click a shortcut to change it."

        Components.StyledText {
            width: parent.width
            text: root.bindings.length > 0 ? root.bindings.length + " shortcuts set up"
                : root.busy ? "Reading your shortcuts…" : "No shortcuts found."
            color: Services.Colors.surfaceVariantText
            font.pixelSize: Services.Ui.textSmall
        }

        Components.SettingField {
            width: parent.width
            placeholder: "Search — like \"browser\", \"volume\" or \"Super B\""
            enabled: root.bindings.length > 0
            onLiveEdited: value => {
                root.query = value;
                list.shortcutList.positionViewAtBeginning();
            }
        }

        Components.StyledDropdown {
            width: parent.width
            label: "Show"
            labelWidth: 60
            model: root.sections
            descriptions: root.sectionDescriptions
            currentValue: root.section
            enabled: !root.busy && root.bindings.length > 0
            onSelected: value => {
                root.section = value;
                list.shortcutList.positionViewAtBeginning();
                if (root.adding && value !== root.allSections && value !== root.addSection) {
                    root.addSection = value;
                    root.chooseTemplate(root.noTemplate);
                }
                if (!root.visibleBindings.includes(root.selected)) {
                    root.selectedLine = -1;
                    form.chordField.text = "";
                }
                root.message = "";
            }
        }

        Flow {
            width: parent.width
            spacing: 8

            Components.TextButton {
                text: "New shortcut"
                enabled: !root.busy && root.configSections.length > 0
                onClicked: root.beginAdd()
            }

            Components.TextButton {
                text: "Shortcut to open an app"
                enabled: !root.busy && root.configSections.includes(root.customAppsSection) && root.installedApps.length > 0
                onClicked: root.beginAddApp()
            }

            Components.TextButton {
                text: "Reload"
                enabled: !root.busy
                onClicked: root.run("list")
            }
        }
    }

    GridLayout {
        x: root.horizontalPadding
        width: root.rowWidth
        height: implicitHeight
        columns: root.stackEditor ? 1 : 2
        columnSpacing: 18
        rowSpacing: 18

        SettingsUi.KeybindList {
            id: list
            page: root
        }

        SettingsUi.KeybindForm {
            id: form
            page: root
        }
    }
}
