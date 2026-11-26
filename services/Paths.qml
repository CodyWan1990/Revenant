pragma Singleton

import QtQuick
import Quickshell

/// Central location for the shell's on-disk paths.
///
/// Everything is derived from the config's own directory, so a copy of this
/// shell (revenant, a test copy, …) runs side by side with its own settings
/// and theme state, and files can move between copies unchanged.
QtObject {
    readonly property string home: Quickshell.env("HOME")
    readonly property string base: String(Quickshell.shellDir).replace(/\/+$/, "")
    /// The config name `qs -c <name>` runs this as, e.g. "revenant". Panel
    /// window titles and runtime files are named after it.
    readonly property string shellName: base.split("/").pop()
    readonly property string scriptsDir: base + "/scripts"
    /// Themes that ship with the shell (read-only as far as the shell goes).
    readonly property string themesDir: base + "/themes"

    /// The user's own files, never inside the code dir: settings.json,
    /// session.env, themes made in the builder, theme hooks.
    readonly property string configDir:
        (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/" + shellName
    readonly property string settingsPath: configDir + "/settings.json"
    readonly property string userThemesDir: configDir + "/themes"
    /// Per-machine state (theme, notepad, monitor layout), created at start.
    readonly property string stateDir:
        (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/" + shellName
    /// The active theme's slug (services/Theme.qml, watched by Colors.qml).
    readonly property string statePath: stateDir + "/current"
    readonly property string notepadPath: stateDir + "/notepad.md"
    readonly property string monitorLayoutPath: stateDir + "/monitors.json"

    /// Per-user scratch space (captures, clipboard images): the session's
    /// runtime dir, or a private one in /tmp when the session has none.
    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR")
        || "/tmp/" + shellName + "-" + (Quickshell.env("USER") || "user")

    // FileView can't create directories, so make sure these exist (the /tmp
    // fallback private to this user: mode 0700, set only when created).
    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", stateDir, userThemesDir]);
        if (!Quickshell.env("XDG_RUNTIME_DIR")) Quickshell.execDetached(["mkdir", "-p", "-m", "700", runtimeDir]);
    }

    function script(name) { return scriptsDir + "/" + name }
}
