import QtQuick
import Quickshell
import Quickshell.Io
import "../services" as Services
import "../components/bar" as BarUi

/// Clipboard history count (clipmenu 7), like polybar's clipboard module.
/// Left click: open the clipboard picker. Right click: ask, then clear the
/// history (a second right click within 3 s confirms — there is no dialog).
BarUi.BarWidget {
    id: root

    icon: "clipboard"
    defaultAccent: Services.Colors.color6
    clickable: true
    onClicked: Services.Actions.clipboard()
    text: root.armed ? "clear?" : (root.running ? String(root.count) : "off")

    property int count: 0
    property bool running: true
    property bool armed: false

    // clipdel's dry run prints one line per stored clip; it's a tiny C binary
    // reading the mmap'd store, so polling it is cheap.
    Process {
        id: countProc
        command: ["sh", "-c", "pgrep -x clipmenud >/dev/null || { echo off; exit; }; clipdel '.' | wc -l"]
        stdout: StdioCollector {
            onStreamFinished: {
                let t = this.text.trim();
                root.running = t !== "off";
                root.count = parseInt(t) || 0;
            }
        }
    }
    Timer {
        interval: (root.instance.intervalSec ?? 2) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: countProc.running = true
    }

    Timer { id: disarm; interval: 3000; onTriggered: root.armed = false }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (!root.armed) { root.armed = true; disarm.restart(); return; }
            root.armed = false;
            Quickshell.execDetached(["clipdel", "-d", ".*"]);
            root.count = 0;
        }
    }
}
