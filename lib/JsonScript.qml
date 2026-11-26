import QtQuick
import Quickshell.Io
import "../services" as Services

/// Runs a Python helper from scripts/ that prints one JSON object, and reports
/// it as `succeeded(result, operation)` or `failed(message, operation)`.
///
/// The helpers' contract: stdout is a single JSON object; a failure the user
/// should read is `{ "error": "…" }`. Anything else that goes wrong (no
/// output, bad JSON, a crash) becomes `fallbackError`, and stderr goes to the
/// log. One run at a time: run() while busy is refused and returns false.
///
/// A QtObject, not an Item, so declaring one inside a SettingsPage adds no row.
QtObject {
    id: root

    /// File name in scripts/, e.g. "i3-key-editor.py"…
    property string script: ""
    /// …or a full path, for a helper that lives elsewhere (x11's session.py).
    property string scriptPath: script ? Services.Paths.script(script) : ""
    /// Shown when the script gives no usable answer.
    property string fallbackError: "The helper script failed."

    /// Busy from the moment run() is called until the result is reported.
    /// Not just proc.running: Quickshell starts a process asynchronously, so
    /// that stays false for a moment after a start is requested, and a
    /// second run() in that gap would replace the first one's command.
    readonly property bool running: _requested || proc.running
    property bool _requested: false
    /// What the current (or last) run was asked to do; the first argument.
    readonly property string operation: _operation
    property string _operation: ""

    signal succeeded(var result, string operation)
    signal failed(string message, string operation)
    /// The last parsed answer (or null), so a page can read extra fields of a
    /// failure, e.g. { error, setup: true } from the i3 editors.
    property var lastResult: null

    /// run("list") → python3 -B scripts/<script> list
    /// run("save", [a, b]) appends a and b. Pass "" to send no operation.
    function run(operation, args = []) {
        if (running) return false;
        _requested = true;
        startWatch.restart();
        _operation = operation;
        const argv = ["python3", "-B", scriptPath];
        if (operation !== "") argv.push(operation);
        proc.command = argv.concat(args);
        proc.running = true;
        return true;
    }

    function _finish(code) {
        _requested = false;
        startWatch.stop();
        const text = stdout.text.trim();
        let result = null;
        try { result = JSON.parse(text); } catch (error) {}
        root.lastResult = result;
        // A script's own { error } wins over its exit code: monitor-layout.py
        // reports xrandr's message *and* exits 1, and that message is the
        // useful one. Only an answer that is not an object falls back.
        const isObject = result !== null && typeof result === "object" && !Array.isArray(result);
        if (isObject && typeof result.error === "string" && result.error !== "") {
            root.failed(result.error, root._operation);
            return;
        }
        if (isObject && code === 0) {
            root.succeeded(result, root._operation);
            return;
        }
        console.warn("JsonScript:", root.scriptPath.split("/").pop(), root._operation, "exited", code,
            isObject ? "after printing JSON:" : "with no JSON answer:",
            (root.stderr.text.trim() || text).slice(-500));
        root.failed(root.fallbackError, root._operation);
    }

    readonly property StdioCollector stdout: StdioCollector {}
    readonly property StdioCollector stderr: StdioCollector {}
    readonly property Process proc: Process {
        stdout: root.stdout
        stderr: root.stderr
        onStarted: root.startWatch.stop()
        onExited: code => root._finish(code)  // qmllint disable signal-handler-parameters
    }

    // A process that never starts (no python3, say) reports nothing; give up
    // after a while instead of staying busy forever.
    readonly property Timer startWatch: Timer {
        interval: 5000
        onTriggered: if (root._requested && !root.proc.running) {
            root._requested = false;
            console.warn("JsonScript:", root.scriptPath.split("/").pop(), root._operation, "never started");
            root.failed(root.fallbackError, root._operation);
        }
    }
}
