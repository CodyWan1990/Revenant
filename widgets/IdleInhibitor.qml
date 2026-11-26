import QtQuick
import "../services" as Services
import "../components" as Components
import "../components/bar" as BarUi

/// Idle inhibitor ("keep awake"), modelled on Dux Shell's IdleInhibitor (MIT).
/// The state lives in Services.Session (X11 has no idle-inhibit protocol, so
/// it forces blanking and DPMS off, then re-applies Settings → Screen & power
/// when turned off). Click: a dropdown with the switch and what it does.
BarUi.BarWidget {
    id: root

    readonly property bool awake: Services.Session.keepAwake

    icon: awake ? "coffee" : "sleep"
    defaultAccent: Services.Colors.yellow
    clickable: true
    onClicked: hint.isOpen ? hint.close() : hint.open()
    text: (instance.showLabel ?? false) ? (awake ? "Awake" : "Idle") : ""

    Components.WidgetPopup {
        id: hint
        bar: root.bar
        parentWidget: root
        contentWidth: 300
        accentColor: root.accent
        Column {
            width: parent.width
            spacing: 10

            Components.SettingsToggle {
                label: "Keep the screen awake"
                checked: root.awake
                onToggled: value => Services.Session.keepAwake = value
            }
            Components.StyledText {
                width: parent.width
                wrapMode: Text.WordWrap
                color: Services.Colors.foreground
                font.pixelSize: Services.Ui.textBody
                text: root.awake ? "Keeping the screen awake (blanking and DPMS off)."
                    : Services.Session.neverBlanks ? "The screen never blanks or sleeps on its own (Settings → Screen & power), so there is nothing to keep it awake from."
                    : "Stops the screen blanking or sleeping while on."
            }
        }
    }
}
