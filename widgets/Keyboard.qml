import QtQuick
import Quickshell
import "../services" as Services
import "../components/bar" as BarUi
import "../lib" as Lib

/// Keyboard: layout name + Caps / Num Lock, modelled on Dux Shell's
/// KeyboardLayoutName and CapsLockIndicator (MIT). X11 has no lock-key events,
/// so `xset q` is read every second; Caps Lock toggles show the OSD.
/// Click cycles through the instance's `layouts` (e.g. "us,ca") via setxkbmap.
BarUi.BarWidget {
    id: root

    property string layout: ""
    property bool caps: false
    property bool num: false
    property bool ready: false     // first read done (no OSD for the initial state)

    readonly property var layouts: String(instance.layouts ?? "").split(",").map(s => s.trim()).filter(s => s)

    icon: "keyboard"
    defaultAccent: Services.Colors.color13
    clickable: layouts.length > 1
    onClicked: {
        const i = layouts.indexOf(layout);
        const next = layouts[(i + 1) % layouts.length];
        Quickshell.execDetached(["setxkbmap", next]);
        root.layout = next;
        Services.Osd.showMessage("layout", Services.Icons.glyph("keyboard", "nerd"), "Layout: " + next.toUpperCase());
    }

    text: {
        const on = Services.Icons.hex(Services.Colors.yellow);
        let t = (instance.showLayout ?? true) ? root.layout.toUpperCase() : "";
        if (root.caps) t += (t ? " " : "") + "<font color='" + on + "'>"
            + Services.Icons.span(Services.Icons.glyph("caps", root.instance.iconSet ?? "auto"),
                root.instance.iconSet ?? "auto", Services.Colors.yellow) + "</font>";
        if (root.num && (instance.showNum ?? false)) t += (t ? " " : "") + "<font color='" + on + "'>NUM</font>";
        return t;
    }

    onCapsChanged: if (ready && (instance.capsOsd ?? true))
        Services.Osd.showMessage("caps", Services.Icons.glyph("caps", "nerd"),
            caps ? "Caps Lock on" : "Caps Lock off")

    Lib.PolledProcess {
        command: ["xset", "q"]
        interval: 1000
        onOutput: text => {
            root.caps = /Caps Lock:\s+on/.test(text);
            root.num = /Num Lock:\s+on/.test(text);
            root.ready = true;
        }
    }
    Lib.PolledProcess {
        command: ["setxkbmap", "-query"]
        interval: 5000
        onOutput: text => {
            const m = text.match(/^layout:\s+(\S+)/m);
            if (m) root.layout = m[1].split(",")[0];
        }
    }
}
