import QtQuick
import Quickshell
import "../../../components" as Components
import "../../../components/settings" as SettingsUi
import "../../../lib" as Lib
import "../../../services" as Services

/// Appearance ▸ Theme hooks: everything a theme switch recolours outside the
/// shell, one switch each. The list (order, labels, which of yours replace a
/// built-in) comes from scripts/theming/theme-hooks.py; the on/off state is
/// Settings.themeHooksDisabled, which that script also reads.
SettingsUi.SettingsPage {
    id: root
    anchors.fill: parent
    horizontalPadding: 24
    contentSpacing: 16

    property var hooks: []
    property string userDir: Services.Paths.configDir + "/hooks/theme.d"
    property string message: ""

    onPageShownChanged: if (pageShown) hookList.run("list")
    Component.onCompleted: if (pageShown) hookList.run("list")

    function setEnabled(id, on) {
        const off = Services.Settings.themeHooksDisabled.filter(x => x !== id);
        if (!on) off.push(id);
        Services.Settings.themeHooksDisabled = off;   // a new array: var compares by reference
    }

    function describe(hook) {
        const parts = [];
        if (hook.description) parts.push(hook.description);
        parts.push(hook.builtin ? "Built-in." : hook.overrides ? "Yours — replaces the built-in one." : "Yours.");
        if (!hook.executable) parts.push("Not executable, so it can't run: chmod +x " + hook.path);
        return parts.join(" ");
    }

    Lib.JsonScript {
        id: hookList
        script: "theming/theme-hooks.py"
        fallbackError: "Could not list the theme hooks."
        onFailed: message => root.message = message
        onSucceeded: result => {
            root.hooks = result.hooks;
            root.userDir = result.userDir;
            root.message = "";
        }
    }

    Components.Card {
        x: root.horizontalPadding; width: root.rowWidth
        title: "Where the theme goes"
        description: "When you switch theme, each of these recolours one thing outside the shell, top to bottom. "
            + "Switch one off to leave that app's colours alone — it keeps whatever it has now."

        Repeater {
            model: root.hooks

            delegate: Components.SettingsToggle {
                required property var modelData
                label: modelData.label
                description: root.describe(modelData)
                checked: !Services.Settings.themeHooksDisabled.includes(modelData.id)
                onToggled: v => root.setEnabled(modelData.id, v)
            }
        }

        Components.StyledText {
            width: parent.width
            visible: text !== ""
            text: hookList.running && root.hooks.length === 0 ? "Looking for hooks…" : root.message
            color: root.message ? Services.Colors.red : Services.Colors.surfaceVariantText
            font.pixelSize: Services.Ui.textSmall
            wrapMode: Text.WordWrap
        }

        Row {
            spacing: 8
            Components.TextButton {
                text: "Re-apply current theme"
                onClicked: Services.Theme.reapplyExternals()
            }
            Components.TextButton {
                text: "Refresh list"
                enabled: !hookList.running
                onClicked: hookList.run("list")
            }
        }
    }

    Components.Card {
        x: root.horizontalPadding; width: root.rowWidth
        title: "Add your own"
        description: "Put an executable script in your hooks folder and it runs on every theme switch. "
            + "It gets the theme name and colours as arguments (NAME BG FG COMMENT SELECTION RED GREEN YELLOW BLUE MAUVE CYAN, "
            + "hex without #) and as THEME_BG, THEME_FG, … variables, including THEME_ORANGE, THEME_TEAL, THEME_MAROON and "
            + "THEME_LAVENDER. A line \"# theme-hook: Name\" near the top names it here, and the comment lines under it "
            + "describe it. Give it a built-in's name (say kitty) to replace that one. A number at the front (25-foo) sets "
            + "the order."

        Components.StyledText {
            width: parent.width
            text: root.userDir
            color: Services.Colors.accent
            font.pixelSize: Services.Ui.textSmall
            wrapMode: Text.WrapAnywhere
        }

        Components.TextButton {
            text: "Open hooks folder"
            onClicked: Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && exec xdg-open \"$1\"", "sh", root.userDir])
        }
    }
}
