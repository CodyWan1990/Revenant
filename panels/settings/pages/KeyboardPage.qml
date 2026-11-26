import QtQuick
import "../../../services" as Services
import "../../../components" as Components
import "../../../components/settings" as SettingsUi

/// Settings → Keyboard: X key repeat (xset r), via Services.Session — saved
/// per machine and re-applied at every X login, in i3 and awesome alike.
SettingsUi.SettingsPage {
    id: root
    anchors.fill: parent
    horizontalPadding: 24
    contentSpacing: 16

    readonly property var v: Services.Session.values
    readonly property bool repeating: v.KEY_REPEAT !== "off"

    Components.Card {
        x: root.horizontalPadding
        width: root.rowWidth
        title: "Key repeat"
        description: "What happens when you hold a key down — useful for arrow keys and Backspace. "
            + "Changes apply straight away."

        Components.SettingsToggle {
            width: parent.width
            label: "Repeat held keys"
            checked: root.repeating
            enabled: Services.Session.ready
            onToggled: value => Services.Session.set("KEY_REPEAT", value ? "on" : "off")
        }
        SettingsUi.SliderRow {
            visible: root.repeating
            title: "Wait before repeating"
            description: "How long you hold a key before it starts repeating. Longer means fewer accidental repeats."
            from: 100; to: 1000; stepSize: 10; suffix: " ms"
            valueText: (value / 1000).toFixed(2) + " s"
            value: root.v.KEY_REPEAT_DELAY ?? 200
            onMoved: value => Services.Session.set("KEY_REPEAT_DELAY", Math.round(value))
        }
        SettingsUi.SliderRow {
            visible: root.repeating
            title: "Repeat speed"
            description: "How many times a second the key repeats once it starts."
            from: 5; to: 100; suffix: " per second"
            value: root.v.KEY_REPEAT_RATE ?? 35
            onMoved: value => Services.Session.set("KEY_REPEAT_RATE", Math.round(value))
        }
        SettingsUi.OptionRow {
            visible: root.repeating
            title: "Try it here"
            Components.SettingField { width: parent.width; placeholder: "Click here, then hold down a key…" }
        }
        Components.StyledText {
            width: parent.width
            visible: Services.Session.error !== ""
            text: Services.Session.error
            wrapMode: Text.WordWrap
            color: Services.Colors.red
            font.pixelSize: Services.Ui.textSmall
        }
    }
}
