import QtQuick
import Quickshell
import Quickshell.Io
import "../services" as Services
import "../components/bar" as BarUi

/// Colour picker, modelled on Dux Shell's ColorPicker (MIT). Click the widget,
/// then click any pixel: its #rrggbb goes to the clipboard and the OSD shows
/// it; right click / Esc cancels (scripts/system/color-pick.py grabs the pointer).
/// The last colour shows as a swatch next to the icon.
BarUi.BarWidget {
    id: root

    property string last: ""

    icon: "picker"
    defaultAccent: Services.Colors.color14
    clickable: true
    onClicked: if (!pick.running) pick.running = true
    text: root.last && (instance.showLast ?? true)
        ? "<font color='" + root.last + "'>●</font>" : ""

    Process {
        id: pick
        command: ["python3", Services.Paths.script("system/color-pick.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                const hex = this.text.trim();
                if (!/^#[0-9a-f]{6}$/i.test(hex)) return;   // cancelled
                root.last = hex;
                // printf, not echo: no trailing newline in the clipboard.
                Quickshell.execDetached(["sh", "-c",
                    'printf %s "$1" | xclip -selection clipboard >/dev/null 2>&1', "sh", hex]);
                Services.Osd.showMessage("picker",
                    Services.Icons.glyph("picker", "nerd"), hex.toUpperCase() + " copied");
            }
        }
    }
}
