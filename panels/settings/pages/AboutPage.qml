import QtQuick
import "../../../services" as Services
import "../../../components" as Components
import "../../../components/settings" as SettingsUi

/// About: what this shell is and where its pieces come from.
SettingsUi.SettingsPage {
    id: root
    anchors.fill: parent
    horizontalPadding: 24
    contentSpacing: 16

    Components.Card {
        x: root.horizontalPadding; width: root.rowWidth
        title: Services.Paths.shellName
        description: "The bar, menus, notifications and this Settings window on your i3 desktop. "
            + "Built with Quickshell, for i3 on X11."

        Components.StatRows {
            width: parent.width
            entries: [
                ["Installed in", Services.Paths.base],
                ["Your settings", Services.Paths.configDir],
                ["Theme", Services.Theme.currentSlug || "—"],
                ["Bar style", Services.Settings.barWidgetStyle],
                ["Icon set", Services.Settings.iconSet]
            ]
        }
    }

    Components.Card {
        x: root.horizontalPadding; width: root.rowWidth
        title: "Credits"

        Components.StyledText {
            width: parent.width
            wrapMode: Text.WordWrap
            color: Services.Colors.foreground
            font.pixelSize: Services.Ui.textBody
            text: "Built on Quickshell by outfoxxed. Forked from nirishell.\n"
                + "Settings window, bar widget styles, OSD, Bluetooth and Wi-Fi panels modelled on "
                + "Dux Shell (formerly DankMaterialShell), MIT licensed, © Avenge Media LLC."
        }
    }
}
