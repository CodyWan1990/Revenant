import QtQuick
import "../services" as Services
import "../components/bar" as BarUi

/// Keybinds button: opens the cheat sheet (panels/KeybindsPanel.qml).
BarUi.BarWidget {
    icon: "help"
    defaultAccent: Services.Colors.color8
    clickable: true
    onClicked: Services.Actions.keybinds()
}
