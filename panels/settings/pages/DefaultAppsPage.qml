import QtQuick
import "../../../services" as Services
import "../../../components" as Components
import "../../../components/settings" as SettingsUi
import "../../../lib" as Lib

/// Desktop file associations and the terminal the shell uses.
SettingsUi.SettingsPage {
    id: root
    anchors.fill: parent
    horizontalPadding: 24
    contentSpacing: 16
    signal keybindsRequested()

    property var handlers: ({})
    property string updateMessage: ""
    property bool loaded: false
    /// Shared with the Keybinds page's "Open …" actions (DefaultApps.mimeGroups).
    readonly property var groups: Services.DefaultApps.mimeGroups

    readonly property var mimeTypes: groups.reduce((types, group) =>
        types.concat(group.rows.reduce((result, row) => result.concat(row.types), [])), [])

    function choicesFor(types) {
        const candidates = {};
        for (const type of types) {
            for (const app of handlers[type]?.apps ?? []) {
                if (!candidates[app.id])
                    candidates[app.id] = { id: app.id, name: app.name, types: [] };
                candidates[app.id].types.push(type);
            }
        }
        const choices = Object.values(candidates);
        return choices.map(app => ({
            id: app.id,
            label: choices.filter(other => other.name === app.name).length > 1
                ? app.name + " (" + app.id + ")" : app.name,
            types: app.types
        })).sort((a, b) => a.label.localeCompare(b.label));
    }

    function currentFor(types, choices) {
        const defaults = types.map(type => handlers[type]?.default ?? null);
        const first = defaults.find(app => app !== null);
        if (!first)
            return loaded ? (choices.length ? "Not chosen" : "None installed") : "Checking…";
        if (defaults.some(app => app && app.id !== first.id))
            return "Mixed defaults";
        return choices.find(app => app.id === first.id)?.label ?? first.name;
    }

    function updateAssociations(app: var) {
        const args = app ? ["--set", app.id, JSON.stringify(app.types)] : [];
        if (associationProc.run("", args.concat(mimeTypes)))
            updateMessage = "";
    }

    Component.onCompleted: updateAssociations()

    Lib.JsonScript {
        id: associationProc
        script: "system/default-apps.py"
        fallbackError: "Could not read or update desktop defaults."
        onFailed: message => root.updateMessage = message
        onSucceeded: result => {
            root.handlers = result.handlers;
            root.loaded = true;
            root.updateMessage = result.errors.join(" ");
        }
    }

    Components.Card {
        x: root.horizontalPadding
        width: root.rowWidth
        title: "Default apps"
        description: "Which app opens each kind of link or file — what starts when you click a web link, "
            + "or double-click a photo or a PDF. Picking an app here also makes it open every other "
            + "kind of file it knows how to."

        Row {
            spacing: 8
            Components.TextButton {
                text: "Keyboard shortcuts for these apps"
                onClicked: root.keybindsRequested()
            }
            Components.TextButton {
                text: associationProc.running ? "Checking…" : "Check again"
                enabled: !associationProc.running
                onClicked: root.updateAssociations()
            }
        }

        Components.StyledText {
            width: parent.width
            text: root.updateMessage
            visible: text !== ""
            wrapMode: Text.WordWrap
            color: Services.Colors.red
        }
    }

    Repeater {
        model: root.groups

        delegate: Components.Card {
            id: groupCard
            required property var modelData
            x: root.horizontalPadding
            width: root.rowWidth
            title: modelData.title

            Repeater {
                model: groupCard.modelData.rows

                delegate: Components.StyledDropdown {
                    id: appChoice
                    required property var modelData
                    readonly property var choices: root.choicesFor(modelData.types)
                    width: groupCard.width - 36
                    label: modelData.label
                    labelWidth: 140
                    model: choices.map(app => app.label)
                    currentValue: root.currentFor(modelData.types, choices)
                    enabled: root.loaded && choices.length > 0 && !associationProc.running
                    onSelected: name => root.updateAssociations(choices.find(app => app.label === name))
                }
            }
        }
    }

    Components.Card {
        x: root.horizontalPadding; width: root.rowWidth
        title: "Terminal"
        description: "The text-command window the shell opens for things like installing updates. "
            + "(The keyboard shortcut that opens a terminal is set under Window manager → Keybinds.)"

        // Detected from installed desktop entries rather than typed: the entry
        // carries its own parsed argv, so nothing here has to guess how to launch it.
        Components.StyledDropdown {
            width: parent.width
            label: "Use"
            model: Services.DefaultApps.terminalNames
            currentValue: Services.DefaultApps.terminalName
            onSelected: v => Services.DefaultApps.setTerminalByName(v)
        }
    }
}
