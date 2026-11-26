pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit
import "." as Services

/// The shell as the session's polkit agent (Settings → Password prompts).
///
/// Only one agent can register per session, so with polkitAgent "shell" this
/// stops the system's own agent first (scripts/system/polkit-agent.sh: polkit-gnome,
/// lxpolkit, …), then creates the PolkitAgent; with "gnome" it drops its
/// agent and starts the system's again.
/// panels/PolkitPanel.qml draws `flow`. While the shell restarts nothing is
/// registered, and pkexec asks in its terminal instead.
///
/// Registration goes over the system bus for the real login session, so it is
/// never started under scripts/dev/run-qs-tests.sh (I3SHELL_TEST is set there).
QtObject {
    id: root

    readonly property bool testing: !!Quickshell.env("I3SHELL_TEST")
    readonly property string mode: Services.Settings.polkitAgent
    readonly property bool wanted: !testing && Services.Settings.ready && mode === "shell"

    /// The current authentication request, or null.
    readonly property var agent: loader.item   // a PolkitAgent, or null
    readonly property var flow: agent?.flow ?? null
    readonly property bool registered: agent?.isRegistered ?? false

    property bool handedOver: false
    // Starts/stops the system's own agent (polkit-gnome, lxpolkit, …).
    readonly property string helper: Services.Paths.script("system/polkit-agent.sh")

    onFlowChanged: if (flow) console.info("Polkit: request", flow.actionId, "for",
        (flow.identities ?? []).map(identity => JSON.stringify(identity)).join(", "))
    onRegisteredChanged: console.info("Polkit: shell agent", registered ? "registered" : "not registered")
    onWantedChanged: sync()
    Component.onCompleted: sync()

    function sync() {
        if (!Services.Settings.ready || testing) return;
        if (wanted && !handedOver) {
            stopGnome.running = true;          // then activate (see onExited)
        } else if (!wanted && mode === "gnome") {
            handedOver = false;                // unloads our agent first…
            // …then the system's agent registers (if one is installed).
            Quickshell.execDetached(["sh", "-c", '[ -x "$1" ] && exec "$1" start', "sh", helper]);
        }
    }

    // Through sh, so it always exits: a missing helper (nothing to stop) must
    // not leave the shell with no agent at all — a Process that can't start
    // never emits exited.
    readonly property Process stopGnome: Process {
        command: ["sh", "-c", '[ -x "$1" ] || exit 0; exec "$1" stop', "sh", root.helper]
        onExited: code => {  // qmllint disable signal-handler-parameters
            if (code !== 0)
                console.warn("Polkit: could not stop the other agent (exit " + code + "); registering may fail");
            root.handedOver = root.wanted;
        }
    }

    readonly property LazyLoader loader: LazyLoader {
        active: root.wanted && root.handedOver
        PolkitAgent {}
    }
}
