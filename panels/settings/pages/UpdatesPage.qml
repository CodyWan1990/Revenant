import QtQuick
import "../../../services" as Services
import "../../../components" as Components
import "../../../components/settings" as SettingsUi

/// Updates: how often to check, and a manual check / upgrade.
SettingsUi.SettingsPage {
    id: root
    anchors.fill: parent
    horizontalPadding: 24
    contentSpacing: 16

    Components.Card {
        x: root.horizontalPadding; width: root.rowWidth
        title: Services.Updates.checking ? "Checking for updates…"
            : Services.Updates.totalCount === 0 ? "You're up to date" : "Updates are ready"
        description: Services.Updates.checking || Services.Updates.totalCount === 0 ? ""
            : [Services.Updates.count > 0 ? Services.Updates.count + " for the system" : "",
               Services.Updates.flatpakCount > 0 ? Services.Updates.flatpakCount + " for Flatpak apps" : "",
               Services.Updates.snapCount > 0 ? Services.Updates.snapCount + " for Snap apps" : ""]
              .filter(part => part).join(", ") + ". Installing opens a terminal window, which may ask for your password."

        Row {
            spacing: 10
            Components.TextButton {
                text: "Check now"
                enabled: !Services.Updates.checking
                onClicked: Services.Updates.refresh()
            }
            Components.TextButton {
                visible: Services.Updates.count > 0
                text: "Install system updates"
                onClicked: Services.Updates.upgradeSystem()
            }
            Components.TextButton {
                visible: Services.Updates.flatpakCount > 0
                text: "Update Flatpak apps"
                onClicked: Services.Updates.upgradeFlatpaks()
            }
            Components.TextButton {
                visible: Services.Updates.snapCount > 0
                text: "Update Snap apps"
                onClicked: Services.Updates.upgradeSnaps()
            }
        }
    }

    Components.Card {
        x: root.horizontalPadding; width: root.rowWidth
        title: "Checking"
        description: "Checking only looks — nothing is installed until you press a button above."

        SettingsUi.SliderRow {
            title: "Check every"
            from: 1; to: 24; suffix: " hours"
            valueText: value === 1 ? "1 hour" : ""
            value: Services.Settings.updatesIntervalHours
            onMoved: v => Services.Settings.updatesIntervalHours = Math.round(v)
        }
        Components.SettingsToggle {
            label: "Include Flatpak apps"
            description: "Apps installed from Flathub, often through a software store."
            checked: Services.Settings.updatesFlatpak
            onToggled: v => { Services.Settings.updatesFlatpak = v; Services.Updates.refresh(); }
        }
        Components.SettingsToggle {
            label: "Include Snap apps"
            description: "Apps installed from the Snap Store (common on Ubuntu)."
            checked: Services.Settings.updatesSnap
            onToggled: v => { Services.Settings.updatesSnap = v; Services.Updates.refresh(); }
        }
    }
}
