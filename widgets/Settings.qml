import QtQuick
import "../services" as Services
import "../components/bar" as BarUi

/// Opens the Settings window.
BarUi.BarText {
    property var instance: ({})
    style: instance.style ?? "underline"
    accent: Services.Colors.byKey(instance.color, Services.Colors.accent)
    clickable: true
    text: Services.Icons.markup("settings", instance.iconSet ?? "auto", accent) || "Settings"
    onClicked: Services.Actions.settings()
}
