import QtQuick
import Quickshell.Io

/// A Process you can call while it is still running. A plain Process ignores
/// `running = true` mid-run, so the second request is silently dropped (a
/// theme applied twice quickly left i3 on the first one). run(argv) starts it
/// now, or queues the request for when the current run exits:
///   keepAll false   only the latest queued request runs (a slider, a theme
///                   preview: intermediate values don't matter)
///   keepAll true    every request runs, in order (deleting several entries)
///
/// `finished(code, argv)` fires after each run; read `stdout`/`stderr` from
/// the collectors you attach, as with a Process.
Process {
    id: root

    property bool keepAll: false
    /// True while a run is going or waiting.
    readonly property bool busy: running || queue.length > 0
    property var queue: []
    property var current: []
    signal finished(int code, var argv)

    function run(argv) {
        // Every request goes through the queue, so one arriving between a
        // run's exit and the next start can't overtake a newer one.
        queue = keepAll ? queue.concat([argv]) : [argv];
        pump();
    }

    function pump() {
        if (running || queue.length === 0) return;
        current = queue[0];
        queue = queue.slice(1);
        command = current;
        running = true;
    }

    onExited: code => {  // qmllint disable signal-handler-parameters
        finished(code, current);
        // Next event-loop turn: `running` may still read true inside exited.
        Qt.callLater(root.pump);
    }
}
