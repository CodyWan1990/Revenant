import QtQuick
import "../services" as Services
import "../components/bar" as BarUi

/// Opens Settings → Wallpapers.
BarUi.BarWidget {
    icon: "wallpaper"
    defaultAccent: Services.Colors.accent
    clickable: true
    onClicked: Services.Actions.wallpaper()
}
