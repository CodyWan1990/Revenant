pragma Singleton

import QtQuick

/// Settings window sidebar, as data (the shape of Dux Shell's
/// Common/SettingsTabs.qml, MIT): categories with child pages, plus
/// separators. A category without children is itself a page.
///
/// Page entries: { id, text, nerd, material, source } where `source` is
/// relative to panels/ and `nerd` / `material` are the two icon flavours
/// (panels/SettingsWindow.qml picks one from Settings.iconSet).
QtObject {
    readonly property var structure: [
        { id: "appearance", text: "Appearance", nerd: "", material: "palette", children: [
            { id: "theme", text: "Themes & wallpapers", nerd: "", material: "format_paint",
              source: "settings/pages/ThemePage.qml" },
            { id: "theme_hooks", text: "Theme hooks", nerd: "󰐱", material: "tune",
              source: "settings/pages/ThemeHooksPage.qml" },
            { id: "shell_style", text: "Shell style", nerd: "", material: "style",
              source: "settings/pages/ShellStylePage.qml" },
            { id: "fonts", text: "Fonts & icons", nerd: "", material: "text_fields",
              source: "settings/pages/FontsPage.qml" },
            { id: "desktop_appearance", text: "Icons & cursor", nerd: "", material: "widgets",
              source: "settings/pages/DesktopAppearancePage.qml" }
        ] },
        { separator: true },
        { id: "bar", text: "Bar", nerd: "", material: "view_agenda", children: [
            { id: "bar_appearance", text: "Appearance", nerd: "", material: "style",
              source: "settings/pages/BarAppearancePage.qml" },
            { id: "bar_widgets", text: "Widgets", nerd: "", material: "widgets",
              source: "settings/pages/BarWidgetsPage.qml" }
        ] },
        { separator: true },
        { id: "shell", text: "Shell", nerd: "", material: "apps", children: [
            { id: "launcher", text: "Launcher", nerd: "", material: "apps",
              source: "settings/pages/LauncherPage.qml" },
            { id: "notifications", text: "Notifications", nerd: "", material: "notifications",
              source: "settings/pages/NotificationsPage.qml" },
            { id: "osd", text: "Volume popup", nerd: "", material: "tune",
              source: "settings/pages/OsdPage.qml" },
            { id: "screenshots", text: "Screenshots", nerd: "", material: "videocam",
              source: "settings/pages/ScreenshotsPage.qml" },
            { id: "weather", text: "Weather", nerd: "", material: "wb_cloudy",
              source: "settings/pages/WeatherPage.qml" }
        ] },
        { separator: true },
        { id: "network", text: "Network", nerd: "", material: "wifi", children: [
            { id: "network_overview", text: "Overview", nerd: "", material: "tune",
              source: "settings/pages/NetworkOverviewPage.qml" },
            { id: "wifi", text: "Wi-Fi", nerd: "", material: "wifi",
              source: "settings/pages/WifiPage.qml" },
            { id: "network_details", text: "Connection details", nerd: "", material: "lan",
              source: "settings/pages/NetworkDetailsPage.qml" },
            { id: "connections", text: "Saved networks", nerd: "", material: "lock",
              source: "settings/pages/ConnectionsPage.qml" }
        ] },
        { separator: true },
        { id: "devices", text: "Devices", nerd: "", material: "keyboard", children: [
            { id: "bluetooth", text: "Bluetooth", nerd: "", material: "bluetooth",
              source: "settings/pages/BluetoothPage.qml" },
            { id: "monitors", text: "Monitors", nerd: "", material: "web_asset",
              source: "settings/pages/MonitorsPage.qml" },
            { id: "keyboard", text: "Keyboard", nerd: "", material: "keyboard_capslock",
              source: "settings/pages/KeyboardPage.qml" }
        ] },
        { separator: true },
        { id: "wm", text: "Window manager", nerd: "", material: "web_asset", children: [
            { id: "keybinds", text: "Keybinds", nerd: "", material: "keyboard",
              source: "settings/pages/KeybindEditorPage.qml" },
            { id: "i3_options", text: "Windows & gaps", nerd: "", material: "tune",
              source: "settings/pages/I3OptionsPage.qml" }
        ] },
        { separator: true },
        { id: "system", text: "System", nerd: "", material: "settings", children: [
            { id: "screen_power", text: "Screen & power", nerd: "", material: "bedtime",
              source: "settings/pages/ScreenPowerPage.qml" },
            { id: "services", text: "Systemd", nerd: "", material: "settings",
              source: "settings/pages/ServicesPage.qml" },
            { id: "autostart", text: "Autostart", nerd: "", material: "power_settings_new",
              source: "settings/pages/AutostartPage.qml" },
            { id: "apps", text: "Default apps", nerd: "", material: "terminal",
              source: "settings/pages/DefaultAppsPage.qml" },
            { id: "updates", text: "Updates", nerd: "", material: "system_update",
              source: "settings/pages/UpdatesPage.qml" },
            { id: "polkit", text: "Password prompts", nerd: "", material: "lock",
              source: "settings/pages/PolkitPage.qml" }
        ] },
        { separator: true },
        { id: "about", text: "About", nerd: "", material: "info", source: "settings/pages/AboutPage.qml" }
    ]

    /// Flattened for the sidebar list: { kind: "separator" | "category" | "page", … }.
    /// A page carries `category` (its parent's text) for the page header.
    readonly property var rows: {
        let out = [];
        for (const e of structure) {
            if (e.separator) { out.push({ kind: "separator" }); continue; }
            if (e.children && e.children.length > 0) {
                out.push({ kind: "category", id: e.id, text: e.text, nerd: e.nerd, material: e.material });
                for (const c of e.children)
                    out.push(Object.assign({ kind: "page", category: e.text, child: true }, c));
            } else {
                out.push(Object.assign({ kind: "page", category: "", child: false }, e));
            }
        }
        return out;
    }

    /// Just the pages, in sidebar order (keyboard Up/Down walks these).
    readonly property var pages: rows.filter(r => r.kind === "page")

    function pageById(id) { return pages.find(p => p.id === id) ?? null; }

    /// Old page ids that are now a part of another page: { page, section }.
    /// SettingsWindow.openPage() follows them and sets the page's `section`.
    readonly property var aliases: ({
        wallpapers: { page: "theme", section: "wallpapers" },
        presets: { page: "theme", section: "presets" },
        colours: { page: "theme", section: "colours" }
    })
}
