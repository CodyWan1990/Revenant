import QtQuick
import "../../../services" as Services
import "../../../components" as Components
import "../../../components/settings" as SettingsUi

/// Notifications: do-not-disturb and how toasts / history behave.
SettingsUi.SettingsPage {
    id: root
    anchors.fill: parent
    horizontalPadding: 24
    contentSpacing: 16

    Components.Card {
        x: root.horizontalPadding; width: root.rowWidth
        title: "Notifications"
        description: "Messages from apps — a new email, a finished download — pop up in the corner of the screen. "
            + "The bell on the bar keeps the ones you missed."

        Components.SettingsToggle {
            label: "Do not disturb"
            description: "No popups. Notifications are still kept, so you can read them later from the bell."
            checked: Services.NotifManager.dndEnabled
            onToggled: v => Services.NotifManager.dndEnabled = v
        }
    }

    Components.Card {
        x: root.horizontalPadding; width: root.rowWidth
        title: "Popups"

        SettingsUi.SliderRow {
            title: "How many at once"
            description: "Extra ones wait their turn."
            from: 1; to: 10
            value: Services.Settings.maxVisible
            onMoved: v => Services.Settings.maxVisible = Math.round(v)
        }
        SettingsUi.SliderRow {
            title: "How long each one stays"
            description: "Urgent ones stay until you close them, whatever this says."
            from: 0; to: 30; suffix: " s"
            valueText: value === 0 ? "Until closed" : ""
            value: Services.Settings.autoDismissSeconds
            onMoved: v => Services.Settings.autoDismissSeconds = Math.round(v)
        }
    }

    Components.Card {
        x: root.horizontalPadding; width: root.rowWidth
        title: "History"

        SettingsUi.SliderRow {
            title: "Notifications to keep"
            description: "Older ones are removed once there are more than this."
            from: 10; to: 200; stepSize: 10
            value: Services.Settings.historyLimit
            onMoved: v => Services.Settings.historyLimit = Math.round(v)
        }
    }
}
