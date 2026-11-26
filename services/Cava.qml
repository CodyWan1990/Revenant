pragma Singleton

import QtQuick
import Quickshell.Io
import "." as Services

/// One shared cava for every visualiser (the media widget's bar strip and
/// popup, the standalone visualiser widget). Runs only while something holds
/// a reference (components/CavaBars.qml acquires one while it is visible and
/// active), so it costs nothing otherwise.
///
/// `levels`: 32 values 0–1, ~30 fps. Consumers resample to their own count.
/// Input is `pulse`: Ubuntu's cava is built without the PipeWire backend, and
/// pipewire-pulse serves the same audio.
QtObject {
    id: root

    readonly property int bands: 32
    readonly property bool available: internal.haveCava
    readonly property bool running: internal.proc.running
    property var levels: []

    property int users: 0
    function acquire() { users++; }
    function release() { users = Math.max(0, users - 1); }

    /// `count` bars averaged from the 32 bands.
    function resample(count) {
        const src = levels, n = src.length;
        if (n === 0 || count <= 0) return [];
        const out = [];
        for (let i = 0; i < count; i++) {
            const a = Math.floor(i * n / count), b = Math.max(a + 1, Math.floor((i + 1) * n / count));
            let sum = 0;
            for (let j = a; j < b; j++) sum += src[j];
            out.push(sum / (b - a));
        }
        return out;
    }

    readonly property QtObject internal: QtObject {
        id: internal
        property bool haveCava: false

        // Installed? (checked once; restart the shell after installing cava)
        property Process check: Process {
            running: true
            command: ["sh", "-c", "command -v cava >/dev/null && echo y || echo n"]
            stdout: StdioCollector { onStreamFinished: root.internal.haveCava = this.text.trim() === "y" }
        }

        property Process proc: Process {
            running: root.available && root.users > 0
            // The config goes to a file, not `-p <(printf …)`: the process
            // substitution's subshell became cava's child once bash exec'd
            // into cava, and cava never reaps children, so it lingered as a
            // zombie for as long as cava ran.
            command: ["bash", "-c",
                'conf="$2/$1-cava.conf"; '
                + "printf '%s\\n' '[general]' 'bars = " + root.bands + "' 'framerate = 30'"
                + " '[input]' 'method = pulse' 'source = auto'"
                + " '[output]' 'method = raw' 'raw_target = /dev/stdout' 'data_format = ascii'"
                + " 'ascii_max_range = 100' 'bar_delimiter = 59' > \"$conf\" && exec cava -p \"$conf\"",
                "bash", Services.Paths.shellName, Services.Paths.runtimeDir]
            stdout: SplitParser {
                onRead: line => {
                    const v = line.split(";").filter(s => s !== "").map(x => Number(x) / 100);
                    if (v.length === root.bands) root.levels = v;
                }
            }
            onRunningChanged: if (!running) root.levels = []
        }
    }
}
