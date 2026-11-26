import QtQuick
import "../../../services" as Services
import "../../../components" as Components
import "../../../components/settings" as SettingsUi

/// Appearance ▸ Fonts & icons.
SettingsUi.SettingsPage {
    id: root
    anchors.fill: parent
    horizontalPadding: 24
    contentSpacing: 16

    Components.Card {
        x: root.horizontalPadding; width: root.rowWidth
        title: "Text"
        description: "The font and text sizes used by the bar and the shell's panels. Apps keep their own fonts."

        SettingsUi.OptionRow {
            title: "Font"
            description: "Type to search. \"Nerd Font\" fonts come first: they include the little icons the bar uses."
            Components.StyledDropdown {
                width: parent.width
                labelWidth: 0
                model: Services.Settings.fontFamilies
                filterable: true
                currentValue: Services.Settings.fontChoice
                onSelected: value => Services.Settings.fontChoice = value
            }
        }
        Components.StyledText {
            width: parent.width
            visible: Services.Settings.fontChoice !== Services.Settings.fontFamily
            text: "\"" + Services.Settings.fontChoice + "\" isn't installed, so \""
                + Services.Settings.fontFamily + "\" is used instead. "
                + (Services.Settings.hasNerdFont ? "" : "Install a Nerd Font so the bar's icons show up.")
            color: Services.Colors.yellow
            font.pixelSize: Services.Ui.textSmall
            wrapMode: Text.WordWrap
        }

        SettingsUi.SliderRow {
            title: "Bar text size"
            from: 10; to: 28; suffix: " px"
            value: Services.Settings.fontSize
            onMoved: v => Services.Settings.fontSize = Math.round(v)
        }
        SettingsUi.SliderRow {
            title: "Panel text size"
            description: "Text in this window, the launcher and menus. 100% is the normal size."
            from: 80; to: 150; stepSize: 5; suffix: "%"
            value: Services.Settings.panelTextScale
            onMoved: v => Services.Settings.panelTextScale = Math.round(v)
        }
    }

    Components.Card {
        x: root.horizontalPadding; width: root.rowWidth
        title: "Icons"

        SettingsUi.ChoiceRow {
            title: "Icon style for the bar"
            description: "Each bar widget can still choose its own under Bar → Widgets."
            choices: [
                { value: "nerd", label: "Nerd Font", hint: "Simple line icons from your font. Needs a Nerd Font installed." },
                { value: "material", label: "Material", hint: "Rounded icons that come with the shell — they always work." },
                { value: "emoji", label: "Emoji", hint: "Colourful emoji, like on a phone." }
            ]
            value: Services.Settings.iconSet
            onSelected: value => Services.Settings.iconSet = value
        }
    }
}
