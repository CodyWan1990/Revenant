import QtQuick
import QtQuick.Layouts
import "../../../services" as Services
import "../../../components" as Components
import "../../../components/settings" as SettingsUi

/// Appearance ▸ Shell style: how the shell's own panels look, with a preview.
SettingsUi.SettingsPage {
    id: root
    anchors.fill: parent
    horizontalPadding: 24
    contentSpacing: 16

    Components.Card {
        x: root.horizontalPadding
        width: root.rowWidth
        title: "Panel style"
        description: "How this Settings window, the app launcher and the bar's menus look. "
            + "The bar itself has its own style under Bar → Appearance."

        SettingsUi.ChoiceRow {
            title: "Panel edges"
            choices: [
                { value: "outlined", label: "Outlined", hint: "Panels have a frame in your theme's accent colour." },
                { value: "tonal", label: "Shaded", hint: "Panels are a slightly lighter shade, with a faint frame." },
                { value: "flat", label: "Flat", hint: "No frames or shading — the plainest look." }
            ]
            value: Services.Settings.shellSurfaceStyle
            onSelected: value => Services.Settings.shellSurfaceStyle = value
        }

        SettingsUi.SliderRow {
            title: "Rounded corners"
            description: "How round the corners of panels and buttons are. App windows always stay square."
            from: 0; to: 24; suffix: " px"
            valueText: value === 0 ? "Square" : ""
            value: Services.Ui.radiusLg
            onMoved: value => Services.Settings.shellRadius = Math.round(value)
        }

        Components.SettingsToggle {
            label: "Animations"
            description: "Panels and menus fade in and out. Turn off if you'd rather they appear instantly."
            checked: Services.Settings.shellAnimations
            onToggled: value => Services.Settings.shellAnimations = value
        }
    }

    Components.Card {
        x: root.horizontalPadding
        width: root.rowWidth
        title: "Preview"
        description: "A sample section, drawn with the settings above."

        Rectangle {
            width: parent.width
            height: preview.implicitHeight + 32
            radius: Services.Ui.radiusLg
            color: Services.Ui.panelColor
            border.color: Services.Ui.accentFrame ? Services.Colors.accent : Services.Colors.outlineVariant
            border.width: Services.Ui.frameWidth

            RowLayout {
                id: preview
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 16
                anchors.rightMargin: 16

                Components.StyledText {
                    text: "Sample panel"
                    font.pixelSize: Services.Ui.textSubtitleLarge
                    font.bold: true
                    Layout.fillWidth: true
                }

                Components.TextButton {
                    text: "Button"
                    enabled: false
                    opacity: 1
                }
            }
        }
    }
}
