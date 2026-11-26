pragma Singleton

import QtQuick
import Quickshell.Io
import "." as Services

/// Default applications, detected rather than typed.
///
/// Everything here comes from installed desktop entries: `DesktopEntries`
/// gives a parsed `command` argv with the field codes (%U, %f, …) already
/// stripped, so nothing in the shell has to parse an `Exec=` line or build a
/// shell string — the two ways this normally goes wrong. Spawns are argv
/// arrays; no value from here is ever interpolated into `sh -c`.
QtObject {
    id: root

    /// Settings → Default apps rows: [{ title, rows: [{ label, action, types }] }].
    /// Shared with scripts/i3/i3-key-editor.py, which maps each row's `action`
    /// (an i3 shortcut label) to its first MIME type.
    readonly property var mimeGroups: {
        try { return JSON.parse(rolesFile.text()); }
        catch (error) { console.warn("DefaultApps: bad default-app-roles.json:", error); return []; }
    }
    readonly property FileView rolesFile: FileView {
        path: Qt.resolvedUrl("../assets/default-app-roles.json")
        blockLoading: true
    }

    /// Entries that call themselves terminals, minus the ones
    /// marked NoDisplay (alternatives entries, kiosk wrappers).
    readonly property var terminals: internal.byCategory("TerminalEmulator")

    /// Display names, for a dropdown model.
    readonly property var terminalNames: terminals.map(e => e.name)

    readonly property var terminalEntry: internal.find(terminals,
        Services.Settings.appTerminalId)

    /// The terminal the shell actually runs: the chosen one, else an installed
    /// terminal matching the legacy `appTerminal` name, else the first
    /// installed terminal — so a default naming an app that isn't installed
    /// (kitty) still opens something. null when no terminal entry exists.
    readonly property var effectiveTerminal: terminalEntry
        ?? terminals.find(e => String(e.command[0] ?? "").split("/").pop() === Services.Settings.appTerminal)
        ?? terminals[0] ?? null

    /// Name to show as the current choice. Falls back to the legacy free-text
    /// `appTerminal` so an existing settings.json keeps working.
    readonly property string terminalName: terminalEntry ? terminalEntry.name
        : (Services.Settings.appTerminal || "")

    /// argv[0] of the chosen terminal — what a keybind's `spawn` needs.
    readonly property string terminalCommand: terminalEntry
        ? (terminalEntry.command[0] ?? "")
        : (Services.Settings.appTerminal || "")

    /// Pick by display name (what the dropdown hands back). This governs the
    /// terminals the shell itself spawns; i3's own terminal keybind is left alone.
    function setTerminalByName(name) {
        const e = internal.byName(terminals, name);
        if (!e)
            return;
        Services.Settings.appTerminalId = e.id;
        Services.Settings.appTerminal = e.command[0] ?? "";
    }

    /// argv running `cmd` (an argv array) inside the chosen terminal.
    /// `appId`, when given, asks the terminal to tag the window so window
    /// rules can match it — only for terminals that support saying so.
    function terminalArgv(cmd, appId) {
        const entry = root.effectiveTerminal;
        // No terminal has a desktop entry: Debian's alternative, else xterm
        // (both take the default `-e`, which termSpec appends).
        const base = entry ? entry.command.slice() : ["sh", "-c",
            't=$(command -v x-terminal-emulator || command -v xterm) && exec "$t" "$@"', "sh"];
        const spec = internal.termSpec(base[0]);
        let argv = base;
        if (appId && spec.classFlag)
            argv = argv.concat([spec.classFlag + appId]);
        return argv.concat(spec.run, cmd);
    }

    readonly property QtObject internal: QtObject {
        id: internal

        // Terminals agree on `-e` far more often than not, so that is the
        // default and only the disagreements are listed. `classFlag` is a
        // prefix because these all take --flag=value.
        readonly property var termSpecs: ({
            "gnome-terminal": { run: ["--"], classFlag: "" },
            "ptyxis":         { run: ["--"], classFlag: "" },
            "tilix":          { run: ["-e"], classFlag: "" },
            "wezterm":        { run: ["start", "--"], classFlag: "--class=" },
            "kitty":          { run: [], classFlag: "--class=" },
            "alacritty":      { run: ["-e"], classFlag: "--class=" }
        })
        readonly property var termDefault: ({ run: ["-e"], classFlag: "" })

        function termSpec(command) {
            // Match on the basename: an entry may be /usr/bin/kitty.
            const base = String(command ?? "").split("/").pop();
            return termSpecs[base] ?? termDefault;
        }

        function byCategory(category) {
            const all = Services.Apps.entries;
            let out = [];
            for (const e of all) {
                if (e.noDisplay || !e.command || e.command.length === 0)
                    continue;
                if ((e.categories ?? []).indexOf(category) >= 0)
                    out.push(e);
            }
            out.sort((a, b) => a.name.localeCompare(b.name));
            return out;
        }

        function find(list, id) {
            if (!id)
                return null;
            for (const e of list)
                if (e.id === id)
                    return e;
            return null;
        }

        function byName(list, name) {
            for (const e of list)
                if (e.name === name)
                    return e;
            return null;
        }

    }
}
