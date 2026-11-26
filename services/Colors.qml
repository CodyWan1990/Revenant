pragma Singleton

import QtQuick
import Quickshell.Io
import "." as Services

/// Color provider — reads the active theme's JSON (Theme.pathFor) and adapts its 14-key Panda palette into 16 indexed colors; recolors reactively on theme/slug change.
QtObject {
    readonly property color background: internal.palette.background
    readonly property color foreground: internal.palette.foreground
    readonly property color cursor: internal.palette.cursor

    readonly property color color0: internal.palette.color0
    readonly property color color1: internal.palette.color1
    readonly property color color2: internal.palette.color2
    readonly property color color3: internal.palette.color3
    readonly property color color4: internal.palette.color4
    readonly property color color5: internal.palette.color5
    readonly property color color6: internal.palette.color6
    readonly property color color7: internal.palette.color7
    readonly property color color8: internal.palette.color8
    readonly property color color9: internal.palette.color9
    readonly property color color10: internal.palette.color10
    readonly property color color11: internal.palette.color11
    readonly property color color12: internal.palette.color12
    readonly property color color13: internal.palette.color13
    readonly property color color14: internal.palette.color14
    readonly property color color15: internal.palette.color15

    readonly property color accent: color4
    readonly property color widgetSurface: blend(background, foreground, Services.Settings.barPillTint / 100)

    // ─── Tonal layers (Dux Shell / Material "surface containers") ───
    // Opaque blends of the theme's own colours, so they follow every theme
    // JSON and need no compositor: low → highest step toward the foreground.
    function blend(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }
    readonly property color surfaceContainerLow: blend(background, foreground, 0.04)
    readonly property color surfaceContainer: blend(background, foreground, 0.07)
    readonly property color surfaceContainerHigh: blend(background, foreground, 0.11)
    readonly property color surfaceContainerHighest: blend(background, foreground, 0.15)
    readonly property color primaryContainer: blend(background, accent, 0.30)
    readonly property color primaryContainerText: blend(foreground, accent, 0.15)
    readonly property color outlineVariant: blend(background, foreground, 0.20)
    /// Readable secondary text (descriptions, category labels) on any surface.
    readonly property color surfaceVariantText: blend(foreground, background, 0.35)
    /// Control outlines that must stay visible (an "off" switch).
    readonly property color outline: blend(background, foreground, 0.45)

    // Semantic aliases (matching waybar style.css mapping)
    readonly property color workspaceActive: color1
    readonly property color clockUnderline: color2
    readonly property color updatesUnderline: color3
    readonly property color weatherUnderline: color4
    readonly property color mprisUnderline: color5
    readonly property color cpuUnderline: color6
    readonly property color memoryUnderline: color9
    readonly property color pulseaudioUnderline: color10
    readonly property color notifUnderline: color11
    readonly property color trayUnderline: color12
    readonly property color powermenuUnderline: color13
    readonly property color diskUnderline: color14
    readonly property color networkUnderline: color3
    readonly property color uptimeUnderline: color7
    readonly property color brightnessUnderline: color15
    readonly property color menuUnderline: color8
    readonly property color batteryUnderline: color2

    // Status colors — mapped to the theme palette so they recolor with the theme
    // (color2/color3/color1 = the palette's green/yellow/red).
    readonly property color green: color2
    readonly property color yellow: color3
    // The theme's own orange (polybar's separator/workspace colour); a
    // red–yellow blend only for a palette that has none.
    readonly property color orange: internal.raw.orange
        ? internal.hex(internal.raw.orange, "#ff9e64")
        : Qt.rgba((color1.r + color3.r) / 2, (color1.g + color3.g) / 2, (color1.b + color3.b) / 2, 1)
    readonly property color red: color1

    // Resolve a palette key to a color; "auto"/unknown returns fallback (widget's semantic default).
    function byKey(key, fallback) {
        switch (key) {
        case "background": return background;
        case "foreground": return foreground;
        case "cursor": return cursor;
        case "color0": return color0;   case "color1": return color1;
        case "color2": return color2;   case "color3": return color3;
        case "color4": return color4;   case "color5": return color5;
        case "color6": return color6;   case "color7": return color7;
        case "color8": return color8;   case "color9": return color9;
        case "color10": return color10; case "color11": return color11;
        case "color12": return color12; case "color13": return color13;
        case "color14": return color14; case "color15": return color15;
        // Named status colours (polybar-style layouts read better with these).
        case "red": return red;         case "orange": return orange;
        case "yellow": return yellow;   case "green": return green;
        case "blue": return color4;     case "mauve": return color5;
        case "cyan": return color6;     case "muted": return color8;
        default: return fallback;
        }
    }

    function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
    function accentAlpha(a) { return Qt.rgba(accent.r, accent.g, accent.b, a); }

    /// Status color for a value at ascending thresholds:
    /// value < t1 → green, < t2 → yellow, < t3 → orange, else red.
    function threshold(value, t1, t2, t3) {
        if (value < t1) return green;
        if (value < t2) return yellow;
        if (value < t3) return orange;
        return red;
    }

    /// Re-send the current palette to the compositor (used on IPC reconnect).

    readonly property var paletteKeys: [
        "auto", "foreground", "background",
        "color1", "color2", "color3", "color4", "color5", "color6", "color7",
        "color8", "color9", "color10", "color11", "color12", "color13", "color14", "color15",
        "red", "orange", "yellow", "green", "blue", "mauve", "cyan", "muted"
    ]

    readonly property QtObject internal: QtObject {
        id: internal

        // Single source of truth for the active slug is Theme.currentSlug
        // (which watches the state file); fall back to Dracula pre-load.
        readonly property string slug: Services.Theme.currentSlug || "dracula"

        // Fallback = Dracula, so the shell is usable before any theme is applied.
        property var palette: ({
            background: "#282a36", foreground: "#f8f8f2", cursor: "#f8f8f2",
            color0: "#282a36", color1: "#ff5555", color2: "#50fa7b", color3: "#f1fa8c",
            color4: "#bd93f9", color5: "#bd93f9", color6: "#8be9fd", color7: "#f8f8f2",
            color8: "#6272a4", color9: "#ff5555", color10: "#50fa7b", color11: "#f1fa8c",
            color12: "#bd93f9", color13: "#bd93f9", color14: "#8be9fd", color15: "#f8f8f2"
        })

        function hex(v, fallback) {
            if (!v || typeof v !== "string") return fallback;
            return v.startsWith("#") ? v : "#" + v;
        }

        // Panda's 14-key palette → 16 indexed colors (terminal-style mapping).
        function adapt(p) {
            let bg = hex(p.bg, "#282a36");
            let fg = hex(p.fg, "#f8f8f2");
            return {
                background: bg, foreground: fg, cursor: fg,
                color0: bg,
                color1: hex(p.red, fg),
                color2: hex(p.green, fg),
                color3: hex(p.yellow, fg),
                color4: hex(p.blue, fg),
                color5: hex(p.mauve, fg),
                color6: hex(p.cyan, fg),
                color7: fg,
                color8: hex(p.comment, fg),
                color9: hex(p.red, fg),
                color10: hex(p.green, fg),
                color11: hex(p.yellow, fg),
                color12: hex(p.blue, fg),
                color13: hex(p.mauve, fg),
                color14: hex(p.cyan, fg),
                color15: fg
            };
        }

        // The theme's own palette, unadapted (for keys the 16 colours drop, like orange).
        property var raw: ({})

        function parseTheme() {
            try {
                let text = themeView.text();
                if (!text || text.length === 0) return;
                let json = JSON.parse(text);
                if (json.palette) {
                    raw = json.palette;
                    palette = adapt(json.palette);
                }
            } catch (e) {
                console.warn("Colors: failed to parse theme JSON:", e);
            }
        }

        // Watches the active theme JSON itself (live edits recolor instantly).
        property FileView themeView: FileView {
            // The user's copy of the slug if there is one, else the shipped file.
            path: Qt.resolvedUrl("file://" + Services.Theme.pathFor(internal.slug))
            watchChanges: true
            preload: true
            onFileChanged: this.reload()
            onTextChanged: internal.parseTheme()
            Component.onCompleted: internal.parseTheme()
        }
    }
}
