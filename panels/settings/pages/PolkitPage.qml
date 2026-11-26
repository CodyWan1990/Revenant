import QtQuick
import "../../../services" as Services
import "../../../components" as Components
import "../../../components/settings" as SettingsUi

/// Settings → Password prompts: who draws polkit's password prompts (pkexec,
/// mounting disks, system settings). The keyring (gnome-keyring/libsecret)
/// is separate and unaffected either way.
SettingsUi.SettingsPage {
    id: root
    anchors.fill: parent
    horizontalPadding: 24
    contentSpacing: 16

    readonly property bool shellMode: Services.Settings.polkitAgent === "shell"

    Components.Card {
        x: root.horizontalPadding
        width: root.rowWidth
        title: "Password prompts"
        description: "When something needs administrator rights — like mounting a drive or changing a system "
            + "setting — a box asks for your password. This picks which box you see. "
            + "It doesn't touch your saved passwords."

        SettingsUi.ChoiceRow {
            title: "Show"
            choices: [
                { value: "shell", label: "Revenant's prompt", hint: "Matches the rest of the shell and your theme." },
                // value kept for old settings
                { value: "gnome", label: "The system's prompt", hint: "The one that came with your system (polkit-gnome, lxpolkit, …)." }
            ]
            value: Services.Settings.polkitAgent
            onSelected: value => Services.Settings.polkitAgent = value
        }

        Components.StyledText {
            width: parent.width
            wrapMode: Text.WordWrap
            font.pixelSize: Services.Ui.textSmall
            color: root.shellMode && !Services.Polkit.registered && !Services.Polkit.testing
                ? Services.Colors.red : Services.Colors.surfaceVariantText
            visible: text !== ""
            text: !root.shellMode ? ""
                : Services.Polkit.registered
                    ? "Working. (For the moment while the shell restarts, commands typed in a terminal ask there instead.)"
                    : "Revenant couldn't take over the prompts — another prompt program may already be running. "
                      + "Try choosing the system's prompt and then this one again."
        }
    }
}
