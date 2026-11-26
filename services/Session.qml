pragma Singleton

import QtQuick
import Quickshell
import "." as Services
import "../lib" as Lib

/// X11 session settings — key repeat, screen blanking, DPMS, login volume —
/// through scripts/system/session.py (the shell runs `session.py start` when it
/// starts: see shell.qml). Values are per machine, in
/// Paths.configDir/session.env; set() saves and applies them at once.
QtObject {
    id: root

    /// KEY_REPEAT, KEY_REPEAT_DELAY, KEY_REPEAT_RATE, SCREEN_BLANK_MIN, DPMS,
    /// DPMS_{STANDBY,SUSPEND,OFF}_MIN, LOGIN_VOLUME (see session.py).
    property var values: ({})
    readonly property bool ready: Object.keys(values).length > 0
    property string error: ""

    /// The bar's keep-awake switch (widgets/IdleInhibitor.qml). X11 has no
    /// idle-inhibit protocol, so while it's on blanking and DPMS are forced
    /// off — re-forced after any save here — and turning it off re-applies
    /// the saved settings.
    property bool keepAwake: false
    /// Nothing to keep awake from: the saved settings never blank or sleep.
    readonly property bool neverBlanks: ready && values.SCREEN_BLANK_MIN === 0 && values.DPMS !== "on"
    onKeepAwakeChanged: {
        if (keepAwake) holdAwake();
        else { applyQueued = true; flush.restart(); }
    }
    function holdAwake() { Quickshell.execDetached(["xset", "s", "off", "-dpms"]); }
    property bool applyQueued: false

    /// Queue a change. Sliders call this on every step, so changes are
    /// batched and sent once the value stops moving.
    function set(key, value) {
        pending = Object.assign({}, pending, { [key]: value });
        values = Object.assign({}, values, { [key]: value });   // show it right away
        flush.restart();
    }
    function refresh() { flush.restart(); }

    property var pending: ({})

    readonly property Timer flush: Timer {
        interval: 250
        onTriggered: {
            const keys = Object.keys(root.pending);
            if (keys.length === 0) {
                const operation = root.applyQueued ? "apply" : "get";
                if (root.script.run(operation)) root.applyQueued = false;
                else restart();
                return;
            }
            if (!root.script.run("set", keys.map(key => key + "=" + root.pending[key]))) {
                restart();   // a run is in flight; try again after it
                return;
            }
            root.pending = {};
        }
    }

    readonly property Lib.JsonScript script: Lib.JsonScript {
        scriptPath: Services.Paths.script("system/session.py")
        fallbackError: "Could not read or apply the session settings."
        // After a failed set/apply, read back what really applies; a failed
        // get is final (re-running it would loop for as long as it keeps
        // failing, e.g. with session.py missing).
        onFailed: (message, operation) => {
            root.error = message;
            if (operation !== "get") root.script.run("get");
        }
        onSucceeded: (result, operation) => {
            // Don't overwrite a change still waiting to be sent.
            root.values = Object.assign({}, result.values, root.pending);
            // Only a save that went through clears an error; the "get" that
            // follows a failure must not hide it.
            if (operation === "set") root.error = "";
            if (root.keepAwake && operation === "set") root.holdAwake();
        }
    }

    Component.onCompleted: script.run("get")
}
