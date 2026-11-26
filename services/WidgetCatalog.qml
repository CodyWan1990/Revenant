pragma Singleton

import QtQuick
import Quickshell.Io
import QtQml.Models
import "../lib" as Lib
import "." as Services

/// Every bar widget type, in the order Settings → Bar → Widgets lists them.
/// One entry is the whole registration: TopBar loads `file` from widgets/,
/// BarWidgetsPage shows `name` + `icon` (an Icons.qml key) and renders `options`, and
/// Settings.normalizeWidget() keeps exactly the option keys declared here.
/// Adding a widget type = a file in widgets/ + one entry below.
///
/// The user's own widgets (<config>/widgets/<id>/widget.json + Widget.qml,
/// listed by scripts/system/user-widgets.py) join as `userEntries`, type
/// "user:<id>", with the same entry shape plus `about`, `path` and `mtime`.
///
/// A widget reads each option as `instance.<key> ?? <fallback>`, with the
/// same fallback as its row here. `hidden` types still load (old settings
/// files use them) but aren't offered; `optionsFrom` borrows another type's
/// options.
///
/// Option row types:
///   bool | text | note (static text, no key) | csv (comma list stored as array)
///   int / float  from, to, step, decimals, suffix; `scale` stores value*scale
///   preset       choices [{ value, label }]; allowCustom (default true) adds a
///                "Custom…" entry revealing a raw field; `hint` documents the
///                placeholders a template row accepts
///   choice/enum  choices: plain strings
///   palette      a Colors.paletteKeys dropdown; "auto" uses the widget fallback
QtObject {
    id: root

    // ─── Rows shared by the CPU, memory, system-monitor and disk widgets ───
    function cpuFormat(label) {
        return { key: "format", label: label, type: "preset", fallback: "{ghz}GHz ({pct}){temp}",
                 hint: "{ghz} {pct} {temp} {cores} — {pct} and {temp} carry their own unit",
                 choices: [{ value: "{ghz}GHz ({pct}){temp}", label: "2.40GHz (12%) 45°C" },
                           { value: "{pct}{temp}", label: "12% 45°C" },
                           { value: "{pct}", label: "12%" },
                           { value: "{ghz}GHz", label: "2.40GHz" }] };
    }
    function memFormat(label) {
        return { key: "format", label: label, type: "preset", fallback: "{used}/{total}GB ({pct})",
                 hint: "{used} {total} {free} {pct} — {pct} carries its own % sign",
                 choices: [{ value: "{used}/{total}GB ({pct})", label: "12/32GB (38%)" },
                           { value: "{pct}", label: "38%" },
                           { value: "{used}GB", label: "12GB" },
                           { value: "{free}GB free", label: "20GB free" }] };
    }
    /// Yellow / orange / red percentage thresholds.
    function thresholds(warn, high, crit) {
        return [
            { key: "warnPct", label: "Yellow above", type: "int", from: 0, to: 100, suffix: "%", fallback: warn,
              description: "The reading changes colour as it fills up." },
            { key: "highPct", label: "Orange above", type: "int", from: 0, to: 100, suffix: "%", fallback: high },
            { key: "critPct", label: "Red above", type: "int", from: 0, to: 100, suffix: "%", fallback: crit }
        ];
    }

    readonly property var entries: [
        { type: "workspaces", name: "Workspaces", icon: "window", file: "Workspaces.qml", options: [
            { section: "Text" },
            { key: "format", label: "Label", type: "preset", fallback: "{indicator} {name}",
              hint: "{index} {name} {indicator}",
              choices: [{ value: "{indicator} {name}", label: "Marker and name" },
                        { value: "{name}", label: "Name only" },
                        { value: "{index}", label: "Number only" },
                        { value: "{indicator}", label: "Marker only" }], description: "What each workspace button shows." },
            { key: "indicator", label: "Marker", type: "text", fallback: "", description: "A small symbol you can put in the label, like a dot." },
            { key: "bold", label: "Bold labels", type: "bool", fallback: true },
            { section: "Size" },
            { key: "tagScale", label: "Button size", type: "float",
              from: 0.8, to: 2.5, step: 0.1, decimals: 1, suffix: "×", fallback: 1.3, description: "1.0× matches the bar text." },
            { key: "itemSpacing", label: "Button spacing", type: "int",
              from: 0, to: 20, suffix: "px", fallback: 4 },
            { key: "tagPadding", label: "Room in button", type: "int",
              from: 0, to: 24, suffix: "px", fallback: 4, description: "Space between a button's edge and its label." },
            { key: "underlineHeight", label: "Focus underline", type: "int",
              from: 0, to: 8, suffix: "px", fallback: 2, description: "A line under the workspace you're on. 0 turns it off." },
            { section: "Symbols" },
            { key: "focusedGlyph", label: "Current symbol", type: "text", fallback: "", description: "Shown for the workspace you're on." },
            { key: "visibleGlyph", label: "Visible symbol", type: "text", fallback: "", description: "Shown for a workspace that is on screen on another monitor." },
            { key: "otherGlyph", label: "Other symbol", type: "text", fallback: "", description: "Shown for every other workspace." },
            { key: "urgentGlyph", label: "Attention symbol", type: "text", fallback: "", description: "Shown when an app on that workspace wants your attention." },
            { section: "Colours" },
            { key: "activeColor", label: "Current colour", type: "palette", fallback: "auto", description: "The workspace you're on." },
            { key: "urgentColor", label: "Attention colour", type: "palette", fallback: "auto", description: "A workspace where an app wants your attention." },
            { key: "occupiedColor", label: "Has-windows colour", type: "palette", fallback: "auto", description: "Workspaces that have windows open." },
            { key: "vacantColor", label: "Empty colour", type: "palette", fallback: "auto", description: "Workspaces with nothing open." },
            { key: "hoverColor", label: "Hover colour", type: "palette", fallback: "auto" },
            { section: "Behaviour" },
            { key: "vacantMode", label: "Empty workspaces", type: "preset",
              fallback: "inherit", allowCustom: false,
              choices: [{ value: "inherit", label: "Follow Bar → Appearance" },
                        { value: "show", label: "Always show" },
                        { value: "hide", label: "Always hide" }], description: "Whether workspaces with nothing open still get a button." },
            { key: "scrollEnabled", label: "Scroll to switch", type: "bool", fallback: false, description: "Scroll over the buttons to move between workspaces." },
            { key: "reverseScroll", label: "Reverse scrolling", type: "bool", fallback: false }
        ] },

        { type: "windowTitle", name: "Window title", icon: "window", file: "WindowTitle.qml", options: [
            { key: "maxWidth", label: "Widest it gets", type: "int", from: 80, to: 900, suffix: "px", fallback: 360, description: "Longer titles are cut short with \"…\"." },
            { key: "prefix", label: "Text before the title", type: "text", fallback: "| ", description: "Text shown just before the title." }
        
        ] },

        { type: "clock", name: "Clock", icon: "clock", file: "Clock.qml", options: [
            { key: "weekdayFormat", label: "Day of the week", type: "preset", fallback: "dddd",
              hint: "dddd = Monday, ddd = Mon",
              choices: [{ value: "dddd", label: "Monday" }, { value: "ddd", label: "Mon" },
                        { value: "", label: "Hidden" }] },
            { key: "dateFormat", label: "Date", type: "preset", fallback: "MMMM d, yyyy",
              hint: "d = 5, dd = 05, MMM = Jan, MMMM = January, M = 1, yyyy = 2026",
              choices: [{ value: "MMMM d, yyyy", label: "January 5, 2026" },
                        { value: "MMM d", label: "Jan 5" },
                        { value: "yyyy-MM-dd", label: "2026-01-05" },
                        { value: "d/M/yyyy", label: "5/1/2026" },
                        { value: "", label: "Hidden" }] },
            { key: "timeIcon", label: "Clock icon", type: "bool", fallback: true, description: "A small clock symbol before the time." },
            { key: "timeFormat", label: "Time", type: "preset", fallback: "hh:mm AP",
              hint: "h = 3, hh = 03, HH = 15 (24-hour), mm = minutes, ss = seconds, AP = AM/PM",
              choices: [{ value: "hh:mm AP", label: "03:04 PM" },
                        { value: "h:mm AP", label: "3:04 PM" },
                        { value: "HH:mm", label: "15:04" },
                        { value: "HH:mm:ss", label: "15:04:05" },
                        { value: "", label: "Hidden" }] }
        
        ] },

        { type: "weather", name: "Weather", icon: "theme", file: "Weather.qml", options: [
            { key: "showCity", label: "Show the town's name", type: "bool", fallback: false },
            { key: "showUnit", label: "Show °C or °F", type: "bool", fallback: true }
        
        ] },

        { type: "media", name: "Media player", icon: "music", file: "Media.qml", options: [
            { section: "Text" },
            { key: "format", label: "What to show", type: "preset", fallback: "{artist} - {title}",
              hint: "{artist} {title} {album} {player}",
              choices: [{ value: "{artist} - {title}", label: "Artist - Title" },
                        { value: "{title}", label: "Title only" },
                        { value: "{title} — {artist}", label: "Title — Artist" },
                        { value: "{player}: {title}", label: "Player: Title" }], description: "What the bar says about the song or video." },
            { key: "maxChars", label: "Longest text", type: "int", from: 8, to: 120, fallback: 35, description: "Longer names are cut short with \"…\"." },
            { key: "maxWidth", label: "Widest it gets", type: "int", from: 80, to: 600, suffix: "px", fallback: 250 },
            { section: "Extras" },
            { key: "showControls", label: "Previous / play / next buttons", type: "bool", fallback: true },
            { key: "visualizer", label: "Dancing bars", type: "choice", choices: [{ value: "both", label: "Bar and popup" }, { value: "bar", label: "On the bar" }, { value: "popup", label: "In the popup" }, { value: "off", label: "Off" }],
              fallback: "both", description: "Bars that move with the sound. The popup opens when you click the song." },
            { key: "vizBars", label: "Number of bars on the bar", type: "int", from: 4, to: 16, fallback: 8 }
        
        ] },

        { type: "sysMonitor", name: "System monitor", icon: "cpu", file: "SysMonitor.qml", options: [
            { key: "labelStyle", label: "Mark each reading with", type: "preset", fallback: "icon", allowCustom: false,
              choices: [{ value: "icon", label: "Icon" }, { value: "text", label: "Text (CPU, RAM, GPU)" },
                        { value: "none", label: "None" }] },
            { section: "Processor (CPU)" },
            { key: "showCpu", label: "Show the processor", type: "bool", fallback: true },
            { key: "cpuUsage", label: "How busy (%)", type: "bool", fallback: true, showIf: "showCpu" },
            { key: "showTemp", label: "Temperature", type: "bool", fallback: true, showIf: "showCpu" },
            { key: "cpuClock", label: "Speed (GHz)", type: "bool", fallback: false, showIf: "showCpu" },
            { key: "cpuCustom", label: "Your own text", type: "text", fallback: "", showIf: "showCpu", description: "Optional; replaces the switches above. You can use: {pct} {temp} {ghz} {cores}" },
            { section: "Memory (RAM)" },
            { key: "showMemory", label: "Show memory", type: "bool", fallback: true },
            { key: "memUsage", label: "How full (%)", type: "bool", fallback: true, showIf: "showMemory" },
            { key: "memUsed", label: "Used / total (GB)", type: "bool", fallback: false, showIf: "showMemory" },
            { key: "memCustom", label: "Your own text", type: "text", fallback: "", showIf: "showMemory", description: "Optional; replaces the switches above. You can use: {pct} {used} {total} {free}" },
            { section: "Graphics card (GPU)" },
            { key: "showGpu", label: "Show the graphics card", type: "bool", fallback: true,
              description: "AMD graphics cards only." },
            { key: "gpuUsage", label: "How busy (%)", type: "bool", fallback: true, showIf: "showGpu" },
            { key: "showGpuTemp", label: "Temperature", type: "bool", fallback: true, showIf: "showGpu" },
            { key: "gpuVram", label: "Graphics memory used / total", type: "bool", fallback: false, showIf: "showGpu" },
            { key: "gpuCustom", label: "Your own text", type: "text", fallback: "", showIf: "showGpu", description: "Optional; replaces the switches above. You can use: {pct} {temp} {vram} {vramTotal}" }
        ] },

        { type: "audio", name: "Audio", icon: "vol-high", file: "Audio.qml", options: [
            { key: "showPercent", label: "Show the volume number", type: "bool", fallback: true },
            { key: "muteLabel", label: "Muted text", type: "text", fallback: "MUTE", description: "Shown instead of the volume while sound is muted." },
            { key: "scrollStep", label: "Change per scroll", type: "int", from: 1, to: 25, suffix: "%", fallback: 5, description: "How much one scroll over the widget changes the volume." },
            { key: "maxVolume", label: "Loudest allowed", type: "int", from: 100, to: 150, suffix: "%", fallback: 100, description: "Above 100% makes quiet things louder, but can sound distorted." }
        
        ] },

        { type: "systemTray", name: "System tray", icon: "window", file: "SystemTray.qml", options: [
            { key: "iconSize", label: "Icon size", type: "int", from: 10, to: 40, suffix: "px", fallback: 20 },
            { key: "itemSpacing", label: "Space between icons", type: "int", from: 0, to: 20, suffix: "px", fallback: 4 },
            { key: "hideWhenEmpty", label: "Hide when there are no icons", type: "bool", fallback: true },
            { key: "showPassive", label: "Show inactive tray icons", type: "bool", fallback: false, description: "Some apps keep an icon here even while they are idle." }
        
        ] },

        { type: "diskUsage", name: "Disks", icon: "disk", file: "DiskUsage.qml", options: [
            { key: "mounts", label: "Drives to show", type: "multi", choicesFrom: "mounts", fallback: ["/"],
              emptyText: "No drives found yet." },
            { key: "labelStyle", label: "Mark each drive with", type: "preset", fallback: "icon", allowCustom: false,
              choices: [{ value: "icon", label: "Icon (plus the name when several)" },
                        { value: "name", label: "Drive name" }, { value: "none", label: "None" }] },
            { section: "What to show" },
            { type: "note", text: "Your own text is set below, so these switches are ignored. Clear it to use them again.",
              showIf: "custom" },
            { key: "showPercent", label: "How full (%)", type: "bool", fallback: true },
            { key: "showUsed", label: "Used / total (GB)", type: "bool", fallback: false },
            { key: "showFree", label: "Free space (GB)", type: "bool", fallback: false },
            { key: "custom", label: "Your own text", type: "text", fallback: "", legacyKey: "format", description: "Optional; replaces the switches above. You can use: {pct} {used} {total} {free} {name} (sizes in GB)" },
            { section: "Warning colours" },
            ...root.thresholds(60, 80, 90),
            // Older single-drive widgets: kept so their settings survive a save.
            { key: "path", type: "text", fallback: "", hidden: true },
            { key: "format", type: "text", fallback: "", hidden: true }
        ] },

        { type: "network", name: "Network speed", icon: "net", file: "Network.qml", options: [
            { key: "format", label: "What to show", type: "preset", fallback: "↓{rx} ↑{tx}",
              hint: "{rx} {tx}",
              choices: [{ value: "↓{rx} ↑{tx}", label: "↓1.2M ↑300K" },
                        { value: "{rx} / {tx}", label: "1.2M / 300K" },
                        { value: "↓{rx}", label: "Download only" },
                        { value: "↑{tx}", label: "Upload only" }], description: "How fast data is coming in (↓) and going out (↑)." }
        
        ] },

        { type: "uptime", name: "Uptime", icon: "uptime", file: "Uptime.qml", options: [
            { key: "format", label: "What to show", type: "preset", fallback: "auto", allowCustom: false,
              choices: [{ value: "auto", label: "3d 4h 20m (skip zero units)" },
                        { value: "dhm", label: "0d 4h 20m (always)" },
                        { value: "hm", label: "76h 20m" },
                        { value: "d", label: "3d" }] },
            { key: "intervalSec", label: "Update every", type: "int", from: 10, to: 3600, suffix: "s", fallback: 60 }
        
        ] },

        { type: "clipboard", name: "Clipboard", icon: "clipboard", file: "Clipboard.qml", options: [
            { key: "intervalSec", label: "Check every", type: "int", from: 1, to: 60, suffix: "s", fallback: 2, description: "How often it checks for new copied items." }
        
        ] },

        { type: "visualizer", name: "Audio visualiser", icon: "music", file: "Visualizer.qml", options: [
            { key: "bars", label: "Number of bars", type: "int", from: 4, to: 32, fallback: 12 },
            { key: "barWidth", label: "Bar thickness", type: "int", from: 2, to: 8, suffix: "px", fallback: 3 },
            { key: "alwaysOn", label: "Keep running when nothing plays", type: "bool", fallback: false, description: "Uses a little more power." }
        
        ] },

        { type: "privacy", name: "Privacy indicator", icon: "mic", file: "Privacy.qml", options: [] },

        { type: "keybindsButton", name: "Keybinds", icon: "help", file: "KeybindsButton.qml", options: [] },

        { type: "notepad", name: "Notepad", icon: "note", file: "Notepad.qml", options: [] },

        { type: "colorPicker", name: "Colour picker", icon: "picker", file: "ColorPicker.qml", options: [
            { key: "showLast", label: "Show the last colour picked", type: "bool", fallback: true, description: "A small swatch next to the icon." }
        
        ] },

        { type: "keyboard", name: "Keyboard & Caps Lock", icon: "keyboard", file: "Keyboard.qml", options: [
            { key: "showLayout", label: "Show the layout (like US)", type: "bool", fallback: true },
            { key: "layouts", label: "Layouts to switch between", type: "text", fallback: "", description: "Keyboard layouts to switch between when you click it, separated by commas (for example: us, de)." },
            { key: "capsOsd", label: "Popup for Caps Lock", type: "bool", fallback: true, description: "Show a popup when Caps Lock turns on or off." },
            { key: "showNum", label: "Show Num Lock too", type: "bool", fallback: false }
        
        ] },

        { type: "runningApps", name: "Running apps", icon: "window", file: "RunningApps.qml", options: [
            { key: "scope", label: "Which apps", type: "choice", choices: [{ value: "workspace", label: "This workspace" }, { value: "output", label: "This monitor" }, { value: "all", label: "Everywhere" }], fallback: "workspace", description: "Which open windows get an icon." },
            { key: "iconSize", label: "Icon size", type: "int", from: 12, to: 28, suffix: "px", fallback: 18 }
        
        ] },

        { type: "temperature", name: "Temperature", icon: "temp", file: "Temperature.qml", options: [
            { key: "source", label: "Sensor", type: "choice", choices: [{ value: "cpu", label: "Processor" }, { value: "gpu", label: "Graphics card" }], fallback: "cpu", description: "Which part's temperature to show." },
            { key: "sensorId", label: "Other sensor (advanced)", type: "text", fallback: "", description: "Optional, for anything else, like a drive: a sensor id such as nvme@nvme1:Composite. It replaces the choice above." },
            { key: "showLabel", label: "Show the sensor's name", type: "bool", fallback: false },
            { key: "warn", label: "Yellow from", type: "int", from: 30, to: 110, suffix: "°C", fallback: 65, description: "The reading changes colour as it gets hotter." },
            { key: "high", label: "Orange from", type: "int", from: 30, to: 110, suffix: "°C", fallback: 75 },
            { key: "crit", label: "Red from", type: "int", from: 30, to: 110, suffix: "°C", fallback: 90 }
        
        ] },

        { type: "powerProfile", name: "Power profile", icon: "profile-balanced", file: "PowerProfile.qml", options: [
            { key: "showName", label: "Show the profile's name", type: "bool", fallback: false, description: "Like \"Balanced\" next to the icon. Needs power-profiles-daemon." }
        
        ] },

        { type: "idleInhibitor", name: "Keep awake", icon: "coffee", file: "IdleInhibitor.qml", options: [
            { key: "showLabel", label: "Show \"Awake\" / \"Idle\" text", type: "bool", fallback: false }
        
        ] },

        { type: "brightness", name: "Brightness", icon: "bright-high", file: "Brightness.qml", options: [
            { key: "command", label: "Program", type: "text", fallback: "brightnessctl", description: "The program used to change brightness. Leave this unless the slider does nothing." },
            { key: "minPercent", label: "Lowest brightness", type: "int", from: 0, to: 50, suffix: "%", fallback: 1, description: "The lowest the slider goes, so the screen never goes fully dark." },
            { key: "intervalSec", label: "Check every", type: "int", from: 1, to: 120, suffix: "s", fallback: 5, description: "How often it re-reads the brightness, in case something else changed it." }
        
        ] },

        { type: "battery", name: "Battery", icon: "power", file: "Battery.qml", options: [
            { key: "showTime", label: "Show time left", type: "bool", fallback: false },
            { key: "critPct", label: "Red at or below", type: "int", from: 0, to: 100, suffix: "%", fallback: 15, description: "The reading changes colour as the battery runs down." },
            { key: "lowPct", label: "Orange at or below", type: "int", from: 0, to: 100, suffix: "%", fallback: 30 },
            { key: "warnPct", label: "Yellow at or below", type: "int", from: 0, to: 100, suffix: "%", fallback: 50 }
        
        ] },

        { type: "headset", name: "Headset", icon: "audio", file: "Headset.qml", options: [] },

        { type: "themeSwitcher", name: "Quick theme", icon: "theme", file: "ThemeSwitcher.qml", options: [
            { key: "showPresets", label: "Presets", type: "bool", fallback: true,
              description: "Your saved looks (colours + wallpapers) at the top." },
            { key: "showColours", label: "Colour themes", type: "bool", fallback: true,
              description: "A dropdown of every colour theme." },
            { key: "showWallpapers", label: "Wallpapers", type: "bool", fallback: true,
              description: "The pictures in your wallpaper folder; a click sets one on every monitor." },
            { key: "wallpaperColumns", label: "Wallpapers per row", type: "int",
              from: 1, to: 4, fallback: 2, description: "Fewer per row makes each picture bigger." },
            { key: "popupWidth", label: "Dropdown width", type: "int",
              from: 300, to: 900, suffix: "px", fallback: 460, description: "How wide the dropdown is." },
            { key: "maxPopupHeight", label: "Dropdown height", type: "int",
              from: 120, to: 1200, suffix: "px", fallback: 720, description: "How tall the dropdown gets before it scrolls." }
        ] },

        { type: "controlCenter", name: "Control Center", icon: "settings", file: "ControlCenter.qml", options: [
            { type: "note", text: "Click it for quick switches and details; right-click turns Do Not Disturb on or off." },
            { key: "showNetwork", label: "Network icon", type: "bool", fallback: true },
            { key: "showNetworkName", label: "Wi-Fi network's name", type: "bool", fallback: false },
            { key: "showBluetooth", label: "Bluetooth icon", type: "bool", fallback: true },
            { key: "showNotifications", label: "Number of notifications", type: "bool", fallback: true },
            { key: "showUpdates", label: "Number of updates", type: "bool", fallback: true },
            { key: "updatesOnlyWhenAvailable", label: "Only when there are updates", type: "bool", fallback: true },
            { key: "openOn", label: "Opens to", type: "choice",
              choices: [{ value: "last", label: "Where I left it" }, { value: "network", label: "Network" },
                        { value: "bluetooth", label: "Bluetooth" }, { value: "notifications", label: "Notifications" },
                        { value: "updates", label: "Updates" }], fallback: "last", description: "Which page the Control Center shows when you open it." }
        ] },

        { type: "notifications", name: "Notifications", icon: "notif", file: "Notifications.qml", options: [
            { key: "hideWhenZero", label: "Hide when there are none", type: "bool", fallback: false }
        
        ] },

        { type: "menu", name: "Launcher button", icon: "apps", file: "Menu.qml", options: [
            { key: "glyph", label: "Symbol", type: "text", fallback: "☰", description: "The character shown on the button." }
        
        ] },

        { type: "settings", name: "Settings", icon: "settings", file: "Settings.qml", options: [] },

        { type: "wallpaper", name: "Wallpapers", icon: "wallpaper", file: "Wallpaper.qml", options: [] },

        { type: "power", name: "Power", icon: "power", file: "Power.qml", options: [] },

        { type: "separator", name: "Spacer / Separator", icon: "", file: "Separator.qml", options: [
            { key: "width", label: "Width", type: "int", from: 2, to: 400, suffix: "px", fallback: 12, description: "How much space it takes on the bar." },
            { key: "hideGlyph", label: "No symbol", type: "bool", fallback: false, description: "Just empty space, with no symbol in it." },
            { key: "glyph", label: "Symbol", type: "text", fallback: "", description: "Shown in the middle of the space, like | or •." },
            { key: "glyphSize", label: "Symbol size", type: "int", from: 0, to: 32, suffix: "px", fallback: 0 },
            { type: "note", text: "A symbol size of 0 follows the bar text size." }
        
        ] },

        { type: "custom", name: "Custom", icon: "window", file: "Custom.qml", options: [
            { type: "note", text: "Commands run as you, through sh -c." },
            { key: "label", label: "Text before the output", type: "text", fallback: "", description: "Text shown on the bar before the command's output." },
            { key: "icon", label: "Icon", type: "text", fallback: "", description: "A symbol or emoji shown first (optional)." },
            { key: "command", label: "Command", type: "text", fallback: "", description: "A terminal command. The first line it prints is shown on the bar." },
            { key: "onClick", label: "When clicked, run", type: "text", fallback: "", description: "A command to run when you click the widget (optional)." },
            { key: "intervalMs", label: "Run again every", type: "int",
              from: 1, to: 60, suffix: "s", scale: 1000, fallback: 5000, description: "How often the command runs again." }
        
        ] },

        { type: "spacer", name: "Spacer / Separator", icon: "", file: "Separator.qml", hidden: true, optionsFrom: "separator" }
    ]

    /// The user's widgets, from scripts/system/user-widgets.py (rescanUser()).
    property var userEntries: []
    /// [{ id, message }] for folders in the widgets dir that couldn't be used.
    property var userErrors: []
    /// Where they live (<config>/widgets).
    property string userDir: Services.Paths.configDir + "/widgets"
    readonly property var allEntries: entries.concat(userEntries)

    readonly property var byType: {
        const map = {};
        for (const entry of allEntries) map[entry.type] = entry;
        return map;
    }
    /// The types offered in the editor, in display order.
    readonly property var types: allEntries.filter(entry => !entry.hidden).map(entry => entry.type)

    /// One plain sentence per type: what it shows or does. Settings → Bar →
    /// Widgets shows it in the Add list and on the widget's options page.
    readonly property var blurbs: ({
        workspaces: "Buttons for your workspaces (virtual desktops); click one to switch to it.",
        windowTitle: "The name of the window you're using.",
        clock: "The time and date. Click it for a calendar.",
        weather: "The current temperature and sky. Set your city under Shell → Weather.",
        media: "What's playing in your music or video app, with play/pause.",
        sysMonitor: "How busy your processor, memory and graphics card are.",
        audio: "Your volume. Scroll over it to change it, click to mute, right-click for a slider.",
        systemTray: "Small icons that apps like Discord or Steam add while they run.",
        diskUsage: "How full your drives are.",
        network: "How fast data is going up and down right now.",
        uptime: "How long the computer has been on.",
        clipboard: "Things you've copied; click one to copy it again.",
        visualizer: "Bars that dance to whatever is playing.",
        privacy: "Lights up while an app is using your microphone or camera.",
        keybindsButton: "Shows your keyboard shortcuts.",
        notepad: "A quick scratch pad for notes.",
        colorPicker: "Pick any colour on the screen and copy its code.",
        keyboard: "Your keyboard layout, and whether Caps Lock is on.",
        runningApps: "An icon for each open app, like a taskbar.",
        temperature: "How hot your processor is.",
        powerProfile: "Switch between power saving, balanced and performance.",
        idleInhibitor: "A coffee cup: while it's on, the screen won't sleep.",
        brightness: "Your screen brightness. Click it for a slider.",
        battery: "How much battery is left (laptops).",
        headset: "Battery of a connected gaming headset (needs the headsetcontrol program).",
        themeSwitcher: "Presets, colour themes and wallpapers in one dropdown.",
        controlCenter: "Wi-Fi, Bluetooth, notifications and updates in one button.",
        notifications: "Your notifications, and Do Not Disturb.",
        menu: "Opens the app launcher.",
        settings: "Opens this Settings window.",
        wallpaper: "Opens the wallpaper picker.",
        power: "Lock, log out, restart or shut down.",
        separator: "Space or a divider between widgets.",
        custom: "Shows the output of your own command (for people comfortable with the terminal)."
    })
    function about(type) { return blurbs[type] ?? byType[type]?.about ?? ""; }
    function isUser(type) { return String(type).startsWith("user:"); }

    function has(type) { return byType[type] !== undefined; }
    function name(type) { return byType[type]?.name ?? type; }
    function icon(type) { return byType[type]?.icon ?? ""; }
    function options(type) {
        const entry = byType[type];
        return (entry?.optionsFrom ? byType[entry.optionsFrom]?.options : entry?.options) ?? [];
    }
    /// Loader source for a type, or "" for an unknown one.
    function url(type) {
        const entry = byType[type];
        if (!entry && isUser(type)) noteMissing(type);
        // ?v=<mtime>: a new URL after an edit, so the Loader builds the new
        // version instead of the engine's cached one (live reload).
        if (entry?.path) return "file://" + entry.path + "?v=" + entry.mtime;
        return entry?.file ? Qt.resolvedUrl("../widgets/" + entry.file) : "";
    }

    /// Re-read the user's widgets folder. Runs at start, when Settings → Bar →
    /// Widgets opens, from IPC `reloadWidgets`, when a listed widget's files
    /// change, and when the bar needs a user widget it hasn't seen.
    /// The bar met a user widget the catalog doesn't know (its folder was made
    /// after the last scan): look again. At most once per type every few
    /// seconds, so a widget whose folder is gone can't make it scan in a loop;
    /// a later settings change still retries, for a folder made meanwhile.
    function noteMissing(type) {
        const now = Date.now();
        if (now - (missingAt[type] ?? -1e9) < 5000) return;
        missingAt[type] = now;   // plain bookkeeping: mutating emits nothing, on purpose
        if (!scanner.running) Qt.callLater(rescanUser);   // a scan in flight settles it anyway
    }
    property var missingAt: ({})

    function rescanUser() {
        if (!scanner.run("list")) rescanAgain = true;
    }
    property bool rescanAgain: false

    readonly property Lib.JsonScript scanner: Lib.JsonScript {
        script: "system/user-widgets.py"
        fallbackError: "Could not read your widgets folder."
        onSucceeded: result => {
            // Same list: keep the old arrays, so nothing downstream re-evaluates.
            if (JSON.stringify(result.widgets) !== JSON.stringify(root.userEntries)) root.userEntries = result.widgets;
            if (JSON.stringify(result.errors) !== JSON.stringify(root.userErrors)) root.userErrors = result.errors;
            root.userDir = result.dir;
            for (const error of result.errors) console.warn("WidgetCatalog: widgets/" + error.id + ":", error.message);
            root.finishScan();
        }
        onFailed: message => { console.warn("WidgetCatalog:", message); root.finishScan(); }
    }
    function finishScan() {
        if (!rescanAgain) return;
        rescanAgain = false;
        Qt.callLater(rescanUser);
    }

    /// One watcher per file of each listed widget: saving one rescans, which
    /// bumps its mtime and so its url().
    readonly property Instantiator watchers: Instantiator {
        // (No Array.flatMap in Qt's JS engine.)
        model: root.userEntries.reduce((files, entry) =>
            files.concat([entry.path, entry.path.replace(/Widget\.qml$/, "widget.json")]), [])
        delegate: FileView {
            required property string modelData
            path: modelData
            watchChanges: true
            onFileChanged: root.rescanUser()
        }
    }

    Component.onCompleted: rescanUser()

    /// Every option key any type declares. normalizeWidget() carries these
    /// through a save/load round-trip and drops anything else. Derived rather
    /// than hand-listed: a hand-listed one silently ate new keys.
    readonly property var optionKeys: {
        const seen = {};
        for (const entry of allEntries)
            for (const option of entry.options ?? [])
                if (option.key !== undefined) seen[option.key] = true;
        return Object.keys(seen);
    }
}
