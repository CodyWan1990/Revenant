import QtQuick
import Quickshell.Io

/// Runs `command` on an interval, emitting `output(text)` with stdout; reactive command/interval, poll() triggers immediately.
/// A hung command is killed after `timeoutMs` (its partial output is dropped), and a still-running poll
/// won't pile up another run.
Item {
    id: root

    property var command: []
    property int interval: 5000
    property int timeoutMs: 10000
    property bool running: true
    signal output(string text)

    function poll() { root._start(); }

    // A command change while a run is in flight (e.g. the Loader assigning
    // `instance` just after the first poll started) re-runs once it finishes,
    // instead of waiting a whole interval with output from the old command.
    property bool _rerun: false
    // Set when the timeout killed the run: its partial output is dropped.
    property bool _killed: false

    function _start() {
        if (proc.running) return;                      // don't stack runs if the last one is still going
        if (!command || command.length === 0) return;
        _killed = false;
        proc.running = true;
        killTimer.restart();
    }

    Process {
        id: proc
        command: root.command
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                killTimer.stop();
                if (!root._killed) root.output(this.text);
                if (root._rerun) { root._rerun = false; Qt.callLater(root._start); }
            }
        }
    }

    // Kill a command that never returns, so it can't wedge the widget forever.
    Timer {
        id: killTimer
        interval: root.timeoutMs
        onTriggered: if (proc.running) {
            console.warn("PolledProcess: timeout, killing", root.command);
            root._killed = true;
            proc.running = false;
        }
    }

    Timer {
        interval: Math.max(250, root.interval)
        running: root.running
        repeat: true
        onTriggered: root._start()
    }

    onCommandChanged: {
        if (!root.running) return;
        if (proc.running) root._rerun = true;
        else root._start();
    }
    Component.onCompleted: if (root.running) root._start()
}
