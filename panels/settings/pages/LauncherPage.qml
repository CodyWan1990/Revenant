import QtQuick
import "../../../services" as Services
import "../../../components" as Components
import "../../../components/settings" as SettingsUi

/// Shell ▸ Launcher: how the app launcher looks and what Enter does.
SettingsUi.SettingsPage {
    id: root
    anchors.fill: parent
    horizontalPadding: 24
    contentSpacing: 16

    Components.Card {
        x: root.horizontalPadding
        width: root.rowWidth
        title: "App launcher"
        description: "Where you find and open apps: click the launcher button on the bar, or press Super+D "
            + "(the Windows key and D), then start typing an app's name."

        SettingsUi.ChoiceRow {
            title: "Size"
            choices: [
                { value: "full", label: "Large", hint: "A big panel that shows your apps before you type anything." },
                { value: "compact", label: "Search bar", hint: "A small search box; results appear as you type." }
            ]
            value: Services.Settings.launcherMode
            onSelected: value => Services.Settings.launcherMode = value
        }

        SettingsUi.ChoiceRow {
            visible: Services.Settings.launcherMode === "full"
            title: "Show apps as"
            choices: [
                { value: "grid", label: "Grid of icons", hint: "Big icons side by side, like a phone." },
                { value: "list", label: "List", hint: "One app per line, with its name beside the icon." }
            ]
            value: Services.Settings.launcherResultsLayout
            onSelected: value => Services.Settings.launcherResultsLayout = value
        }

        SettingsUi.SliderRow {
            // Compact search always lists; expanded only in list layout.
            visible: Services.Settings.launcherMode === "compact"
                || Services.Settings.launcherResultsLayout === "list"
            title: "Line height"
            description: "Taller lines are easier to click; shorter ones fit more apps."
            from: 28; to: 64; stepSize: 2; suffix: " px"
            value: Services.Settings.launcherListRowHeight
            onMoved: v => Services.Settings.launcherListRowHeight = Math.round(v)
        }
    }

    Components.Card {
        x: root.horizontalPadding
        width: root.rowWidth
        title: "Opening an app that's already open"

        SettingsUi.ChoiceRow {
            title: "When you pick an app"
            choices: [
                { value: "launch", label: "Open a new window", hint: "Always starts a fresh window, even if the app is already open." },
                { value: "focus", label: "Go to its window", hint: "If the app is already open, switch to it instead. Ctrl+Enter still opens a new one." }
            ]
            value: Services.Settings.launcherAction
            onSelected: value => Services.Settings.launcherAction = value
        }
    }

    Components.Card {
        x: root.horizontalPadding
        width: root.rowWidth
        title: "Recent apps"

        Components.SettingsToggle {
            label: "Remember apps you open"
            description: "Show them first when the launcher opens, before you type anything."
            checked: Services.Settings.launcherHistoryEnabled
            onToggled: value => Services.Settings.launcherHistoryEnabled = value
        }

        Components.TextButton {
            text: "Forget recent apps"
            enabled: Services.Settings.launcherRecentApps.length > 0
            onClicked: Services.Settings.launcherRecentApps = []
        }
    }
}
