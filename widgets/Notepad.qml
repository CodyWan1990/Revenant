import QtQuick
import "../services" as Services
import "../components/bar" as BarUi

/// Notepad button (Dux Shell's Notepad, MIT): opens panels/NotepadPanel.qml.
BarUi.BarWidget {
    icon: "note"
    defaultAccent: Services.Colors.yellow
    clickable: true
    onClicked: Services.Actions.notepad()
}
