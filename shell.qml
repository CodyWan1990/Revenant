//@ pragma UseQApplication
// Tray (SNI) icons are looked up by name in an icon theme; without one they
// render as the magenta "missing" checkerboard. Set it with QS_ICON_THEME in
// the session environment (e.g. ~/.profile or ~/.xprofile: export QS_ICON_THEME=Papirus-Dark).
import QtQuick
import Quickshell
import Quickshell.Io
import "panels" as Panels
import "services" as Services

/// Entry point — spawns a TopBar on every connected screen,
/// plus single-instance overlay panels (launcher, etc.).
ShellRoot {
    PersistentProperties {
        id: startup
        property bool monitorsRestored: false
    }

    Process {
        id: monitorRestore
        command: ["python3", Services.Paths.script("i3/monitor-layout.py"),
            "restore", Services.Paths.monitorLayoutPath]
        running: !startup.monitorsRestored
        stdout: StdioCollector { id: monitorRestoreOutput }
        onExited: code => {  // qmllint disable signal-handler-parameters
            startup.monitorsRestored = true;
            if (code !== 0) console.warn("Monitor layout:", monitorRestoreOutput.text.trim());
            else {
                const result = JSON.parse(monitorRestoreOutput.text);
                if (result.outputs) console.info("Monitor layout restored");
                else if (result.skipped) console.info("Monitor layout:", result.skipped);
            }
        }
    }

    // Session settings and the wallpaper, applied by the shell itself (as a
    // desktop's settings daemon would), so no login file is needed. Both are
    // safe to repeat: a restart re-applies key repeat / blanking / DPMS and
    // repaints the wallpaper, and the login volume is set once per session.
    Process {
        command: ["python3", "-B", Services.Paths.script("system/session.py"), "start"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    if (result.error) console.warn("Session settings:", result.error);
                } catch (e) { console.warn("Session settings: unreadable reply"); }
            }
        }
    }
    Process {
        command: ["bash", Services.Paths.script("theming/wallpaper.sh"), "--restore"]
        running: true
        onExited: code => { if (code !== 0) console.warn("Wallpaper: could not restore it"); }  // qmllint disable signal-handler-parameters
    }

    // The agents' guide, copied where agents look (<config>/AGENTS.md).
    Process {
        command: ["bash", Services.Paths.script("system/agents-doc.sh"),
            Services.Paths.base + "/AGENTS.md", Services.Paths.configDir]
        running: true
        onExited: code => { if (code !== 0) console.warn("AGENTS.md: could not copy it to", Services.Paths.configDir); }  // qmllint disable signal-handler-parameters
    }

    Variants {
        model: Quickshell.screens

        Panels.TopBar {}
    }

    Panels.AppLauncher {
        id: appLauncher
    }

    Panels.ThemePicker {
        id: themePicker
    }

    Panels.ClipboardPanel {
        id: clipboardPicker
    }

    Panels.PowerMenu {
        id: powerMenu
    }

    Panels.ScreenshotSelector {
        id: screenshotSelector
    }

    Panels.WindowSwitcher {
        id: windowSwitcher
    }

    Panels.TaskManager {
        id: taskManager
    }

    Panels.KeybindsPanel {
        id: keybindsPanel
    }

    Panels.NotepadPanel {
        id: notepadPanel
    }

    Panels.SettingsWindow {
        id: settingsWindow
    }

    Panels.WifiPasswordPanel {
        id: wifiPasswordPanel
    }

    // polkit's admin prompts, when the shell is the agent (services/Polkit.qml).
    Panels.PolkitPanel {
        flow: Services.Polkit.flow
    }

    // ─── Action bus ───
    Connections {
        target: Services.Actions
        function onLauncher() { appLauncher.toggle(); }
        // One panel, three sections: each bind opens (or toggles) its own section.
        function onClipboard() { clipboardPicker.openSection("text"); }
        function onClipimages() { clipboardPicker.openSection("images"); }
        function onPowermenu() { powerMenu.toggle(); }
        function onWallpaper() { settingsWindow.openPage("wallpapers"); }
        function onThemeSettings() { settingsWindow.openPage("theme"); }
        function onThemePicker() { themePicker.toggle(); }
        function onSettings() { settingsWindow.toggle(); }
        // Capture first, then the selector opens over IPC (screenshotSelect).
        function onScreenshot() {
            Quickshell.execDetached(["bash", Services.Paths.script("screenshot/screenshot-capture.sh"), "region"]);
        }
        function onWindowswitcher() { windowSwitcher.toggle(); }
        function onEmoji() { clipboardPicker.openSection("emoji"); }
        function onProcesses() { taskManager.toggle(); }
        function onKeybinds() { keybindsPanel.toggle(); }
        function onNotepad() { notepadPanel.toggle(); }
        function onWifiPassword(network, error) { wifiPasswordPanel.ask(network, error); }
    }

    // ─── IPC entry points ─── bound in i3/.config/i3/modules/keys.config
    // (exec qs -c revenant ipc call shell <name>; i3/revenant-keys.config).
    IpcHandler {
        target: "shell"

        function launcher(): void { Services.Actions.launcher(); }
        function clipboard(): void { Services.Actions.clipboard(); }
        function clipimages(): void { Services.Actions.clipimages(); }
        function powermenu(): void { Services.Actions.powermenu(); }
        function wallpaper(): void { Services.Actions.wallpaper(); }
        function themes(): void { Services.Actions.themeSettings(); }
        function settings(): void { Services.Actions.settings(); }
        /// Opens Settings at one page, by its id in services/SettingsTabs.qml
        /// (e.g. "services", "wallpapers", "keybinds").
        function settingsPage(id: string): void { settingsWindow.openPage(id); }
        /// Apply a saved theme preset by id or name (Settings → Themes & wallpapers).
        function themePreset(name: string): string { return Services.Theme.applyPreset(name) ? "ok" : "no such preset"; }
        function screenshot(): void { Services.Actions.screenshot(); }
        /// Called by scripts/screenshot/screenshot-capture.sh with the frozen capture,
        /// the visible windows ("x,y,w,h;…") and an optional preselection.
        function screenshotSelect(image: string, windows: string, preset: string): void {
            screenshotSelector.openCapture(image, windows, preset);
        }
        function windowswitcher(): void { Services.Actions.windowswitcher(); }
        function weather(): void { Services.Actions.weather(); }
        function emoji(): void { Services.Actions.emoji(); }
        function processes(): void { Services.Actions.processes(); }
        function keybinds(): void { Services.Actions.keybinds(); }
        function notepad(): void { Services.Actions.notepad(); }
        /// Called by scripts/system/sys-updates.sh when an upgrade finishes.
        function updatesRefresh(): void { Services.Updates.refresh(); }
        /// Re-read ~/.config/<shell>/widgets (a new widget folder).
        function reloadWidgets(): void { Services.WidgetCatalog.rescanUser(); }
    }
}
