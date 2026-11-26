import QtQuick
import "../../../services" as Services
import "../../../components" as Components
import "../../../components/settings" as SettingsUi

/// Volume popup (on-screen display): the volume / mic popup (services/Osd.qml).
SettingsUi.SettingsPage {
    id: root
    anchors.fill: parent
    horizontalPadding: 24
    contentSpacing: 16

    Components.Card {
        x: root.horizontalPadding; width: root.rowWidth
        title: "Volume popup"
        description: "A small bar near the bottom of the screen that shows the volume while you change it "
            + "— from the keyboard's volume keys, a shortcut or an app."

        Components.SettingsToggle {
            label: "Show the volume popup"
            checked: Services.Settings.osdEnabled
            onToggled: v => Services.Settings.osdEnabled = v
        }
        Components.SettingsToggle {
            visible: Services.Settings.osdEnabled
            label: "Also when the microphone is muted or unmuted"
            checked: Services.Settings.osdMic
            onToggled: v => Services.Settings.osdMic = v
        }
        SettingsUi.SliderRow {
            visible: Services.Settings.osdEnabled
            title: "How long it stays"
            from: 0.5; to: 5; stepSize: 0.5; suffix: " s"
            valueText: value.toFixed(1) + " s"
            value: Services.Settings.osdTimeoutMs / 1000
            onMoved: v => Services.Settings.osdTimeoutMs = Math.round(v * 1000)
        }
    }
}
