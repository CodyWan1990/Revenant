import QtQuick
import Quickshell
import qs.services as Services
import qs.components.bar as BarUi
import qs.lib as Lib

// Example user widget. Copy this folder to ~/.config/revenant/widgets/<id>/
// and add it from Settings → Bar → Widgets. The bar sets `bar` and `instance`
// (the widget's entry in settings.json, with the option keys from widget.json).
BarUi.BarWidget {
    id: root

    // Every option: instance.<key> ?? <the same fallback as widget.json>.
    readonly property string greeting: instance.greeting ?? "Hi"
    readonly property string command: instance.command ?? "whoami"
    readonly property bool showOutput: instance.showOutput ?? true
    property string output: ""

    icon: "help"                          // an Icons.qml key
    // Used while the widget's Colour (every widget has one) is "auto".
    defaultAccent: Services.Colors.accent
    // text is rich text: escape anything that came from outside.
    text: Services.Icons.esc(root.greeting + (root.showOutput && root.output ? " " + root.output : ""))
    clickable: true
    onClicked: Quickshell.execDetached(["notify-send", "Hello", "From your own Revenant widget."])

    Lib.PolledProcess {
        command: ["sh", "-c", root.command]
        interval: (root.instance.intervalSec ?? 60) * 1000
        running: root.showOutput && root.command !== ""
        onOutput: text => root.output = text.split("\n")[0].trim()
    }
}
