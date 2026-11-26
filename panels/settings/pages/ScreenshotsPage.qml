import QtQuick
import Quickshell
import "../../../services" as Services
import "../../../components" as Components
import "../../../lib/Strftime.js" as Strftime
import "../../../components/settings" as SettingsUi

/// Screenshots: where Save puts them and what they are called
/// (panels/ScreenshotSelector.qml, scripts/screenshot/screenshot-deliver.sh).
SettingsUi.SettingsPage {
    id: root
    anchors.fill: parent
    horizontalPadding: 24
    contentSpacing: 16

    // Ticks so the example name shows the time as it would be now.
    property date now: new Date()
    Timer { interval: 1000; running: root.visible; repeat: true; onTriggered: root.now = new Date() }

    readonly property var presets: [
        "Screenshot_%Y-%m-%d_%H-%M-%S",
        "%Y-%m-%d_%H-%M-%S",
        "Screenshot from %Y-%m-%d %H-%M-%S",
        "%B-%d-%Y-%I-%M-%S-%p",
        "%Y%m%d_%H%M%S",
        "%a %d %b %Y, %I-%M-%S %p"
    ]
    // The dropdown lists examples rather than codes; a fixed date keeps them
    // from changing while the list is open.
    readonly property date sample: new Date(2026, 10, 23, 14, 5, 9)
    readonly property var presetLabels: presets.map(p => Strftime.format(p, sample))
    readonly property int presetIndex: presets.indexOf(Services.Settings.screenshotNameFormat)
    readonly property string example:
        Strftime.fileName(Strftime.format(Services.Settings.screenshotNameFormat, now))

    Components.Card {
        x: root.horizontalPadding; width: root.rowWidth
        title: "Taking a screenshot"
        description: "Press Print Screen and drag over what you want. Shift+Print Screen takes one window, "
            + "Super+Print Screen the whole screen. You can then copy it, save it, or draw on it first. "
            + "(These are the usual keys; Window manager → Keybinds can change them.)"
    }

    Components.Card {
        x: root.horizontalPadding; width: root.rowWidth
        title: "Saving"

        SettingsUi.OptionRow {
            title: "Folder"
            description: "Where saved screenshots go. ~ means your home folder; the folder is made if it isn't there yet."
            Components.SettingField {
                width: parent.width
                text: Services.Settings.screenshotDir
                placeholder: Quickshell.env("HOME") + "/Pictures/Screenshots"
                onEdited: value => Services.Settings.screenshotDir =
                    value.trim() || Quickshell.env("HOME") + "/Pictures/Screenshots"
            }
        }
        Row {
            spacing: 8
            Components.TextButton {
                text: "Open the folder"
                onClicked: Quickshell.execDetached(["bash", "-c",
                    'd=${1/#\\~/$HOME}; mkdir -p -- "$d" && xdg-open "$d"', "bash",
                    Services.Settings.screenshotDir])
            }
            Components.TextButton {
                text: "Back to Pictures/Screenshots"
                visible: Services.Settings.screenshotDir !== Quickshell.env("HOME") + "/Pictures/Screenshots"
                onClicked: Services.Settings.screenshotDir = Quickshell.env("HOME") + "/Pictures/Screenshots"
            }
        }

        Components.SettingsToggle {
            label: "Ask for a name each time"
            description: "A name box appears next to your selection, filled in with the date and time. "
                + "Enter saves, Esc goes back. Copying without saving never asks."
            checked: Services.Settings.screenshotAskName
            onToggled: v => Services.Settings.screenshotAskName = v
        }
    }

    Components.Card {
        x: root.horizontalPadding; width: root.rowWidth
        title: "File names"
        description: "Screenshots are named after the date and time they were taken."

        SettingsUi.OptionRow {
            title: "Name style"
            hint: "Next screenshot: " + (root.example || "(the default name)")
            Components.StyledDropdown {
                width: parent.width
                labelWidth: 0
                model: root.presetLabels.concat(["Custom"])
                currentValue: root.presetIndex >= 0 ? root.presetLabels[root.presetIndex] : "Custom"
                onSelected: value => {
                    const i = root.presetLabels.indexOf(value);
                    if (i >= 0) Services.Settings.screenshotNameFormat = root.presets[i];
                    else customCard.expanded = true;
                }
            }
        }
    }

    Components.Card {
        id: customCard
        x: root.horizontalPadding; width: root.rowWidth
        title: "Custom name pattern"
        description: "For your own style: letters after % are replaced with parts of the date."
        collapsible: true
        expanded: root.presetIndex < 0

        Components.SettingField {
            width: parent.width
            text: Services.Settings.screenshotNameFormat
            placeholder: root.presets[0]
            onEdited: value => Services.Settings.screenshotNameFormat = value.trim() || root.presets[0]
        }
        Components.StyledText {
            width: parent.width
            text: Strftime.CODES
            color: Services.Colors.surfaceVariantText
            font.pixelSize: Services.Ui.textSmall
            wrapMode: Text.WordWrap
        }
    }
}
