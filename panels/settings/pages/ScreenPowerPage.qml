import QtQuick
import "../../../services" as Services
import "../../../components" as Components
import "../../../components/settings" as SettingsUi

/// Settings → Screen & power: X screen blanking (xset s) and monitor power
/// saving (DPMS), via Services.Session — saved per machine and re-applied at
/// every X login. Fullscreen video and the bar's keep-awake toggle can still
/// hold the screen on.
SettingsUi.SettingsPage {
    id: root
    anchors.fill: parent
    horizontalPadding: 24
    contentSpacing: 16

    readonly property var v: Services.Session.values
    readonly property bool dpms: v.DPMS === "on"

    /// X refuses DPMS times out of order, so moving one past its neighbour
    /// pushes the neighbour along: standby ≤ suspend ≤ off.
    function setDpms(key, minutes) {
        const order = ["DPMS_STANDBY_MIN", "DPMS_SUSPEND_MIN", "DPMS_OFF_MIN"];
        const at = order.indexOf(key);
        Services.Session.set(key, minutes);
        for (let i = at + 1; i < order.length; i++)
            if ((v[order[i]] ?? 10) < minutes) Services.Session.set(order[i], minutes);
        for (let i = at - 1; i >= 0; i--)
            if ((v[order[i]] ?? 10) > minutes) Services.Session.set(order[i], minutes);
    }

    /// The simple "turn off after" slider: every stage at once, so the
    /// monitor goes straight to off. The stages card can split them again.
    function setAllDpms(minutes) {
        for (const key of ["DPMS_STANDBY_MIN", "DPMS_SUSPEND_MIN", "DPMS_OFF_MIN"])
            Services.Session.set(key, minutes);
    }

    Components.Card {
        x: root.horizontalPadding
        width: root.rowWidth
        title: "When you're away"
        description: "What the screen does when you haven't touched the mouse or keyboard for a while. "
            + "Full-screen videos, and the coffee-cup widget on the bar, keep it on."

        SettingsUi.SliderRow {
            title: "Blank the screen after"
            description: "The picture goes black, but the monitor stays on."
            from: 0; to: 120; suffix: " min"
            valueText: value === 0 ? "Never" : ""
            value: root.v.SCREEN_BLANK_MIN ?? 0
            onMoved: value => Services.Session.set("SCREEN_BLANK_MIN", Math.round(value))
        }

        Components.SettingsToggle {
            width: parent.width
            label: "Turn the monitors off to save power"
            description: "Moving the mouse or pressing a key turns them back on."
            checked: root.dpms
            enabled: Services.Session.ready
            onToggled: value => Services.Session.set("DPMS", value ? "on" : "off")
        }

        SettingsUi.SliderRow {
            visible: root.dpms
            title: "Turn them off after"
            from: 1; to: 120; suffix: " min"
            value: root.v.DPMS_OFF_MIN ?? 10
            onMoved: value => root.setAllDpms(Math.round(value))
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

    Components.Card {
        x: root.horizontalPadding
        width: root.rowWidth
        visible: root.dpms
        title: "Power-saving stages"
        description: "Some monitors power down in steps, each using less power and taking a little longer to wake. "
            + "Each step comes no sooner than the one before it."
        collapsible: true
        expanded: false

        Repeater {
            model: [
                { key: "DPMS_STANDBY_MIN", title: "Standby after", description: "The lightest sleep; wakes almost instantly." },
                { key: "DPMS_SUSPEND_MIN", title: "Deeper sleep after", description: "" },
                { key: "DPMS_OFF_MIN", title: "Fully off after", description: "" }
            ]
            SettingsUi.SliderRow {
                required property var modelData
                title: modelData.title
                description: modelData.description
                from: 1; to: 120; suffix: " min"
                value: root.v[modelData.key] ?? 10
                onMoved: value => root.setDpms(modelData.key, Math.round(value))
            }
        }
    }
}
