pragma Singleton

import QtQuick
import "." as Services
import "../lib/MaterialCodepoints.js" as Material

/// Central glyph map for the per-widget icon toggle (emoji ↔ Nerd Font).
QtObject {
    // key → { emoji, nerd }
    readonly property var map: ({
        "cpu":         { emoji: String.fromCodePoint(0x1F5A5, 0xFE0F), nerd: String.fromCodePoint(0xF0EE0) },
        "memory":      { emoji: String.fromCodePoint(0x1F9E0),         nerd: String.fromCodePoint(0xEFC5) },
        "disk":        { emoji: String.fromCodePoint(0x1F4BE),         nerd: String.fromCodePoint(0xF0A23) },
        "net":         { emoji: String.fromCodePoint(0x1F310),         nerd: String.fromCodePoint(0xF0200) },
        "power":       { emoji: String.fromCodePoint(0x23FB),          nerd: String.fromCodePoint(0xF0425) },
        "notif":       { emoji: String.fromCodePoint(0x1F514),         nerd: String.fromCodePoint(0xF009A) },
        "window":      { emoji: String.fromCodePoint(0x1FA9F),         nerd: String.fromCodePoint(0xF2D0) },
        "clipboard":   { emoji: String.fromCodePoint(0x1F4CB),         nerd: String.fromCodePoint(0xF014C) },
        "updates":     { emoji: String.fromCodePoint(0x1F4E6),         nerd: String.fromCodePoint(0xF06B0) },
        "uptime":      { emoji: String.fromCodePoint(0x23F1),          nerd: String.fromCodePoint(0xF0150) },
        "theme":       { emoji: String.fromCodePoint(0x1F3A8),         nerd: String.fromCodePoint(0xF03D8) },
        "clock":       { emoji: String.fromCodePoint(0x1F550),         nerd: String.fromCodePoint(0xF0954) },
        "calendar":    { emoji: String.fromCodePoint(0x1F4C6),         nerd: String.fromCodePoint(0xF00ED) },
        "music":       { emoji: String.fromCodePoint(0x266B),          nerd: String.fromCodePoint(0xF075A) },
        "mic":         { emoji: String.fromCodePoint(0x1F399, 0xFE0F), nerd: String.fromCodePoint(0xF036C) },
        "mic-muted":   { emoji: String.fromCodePoint(0x1F636),         nerd: String.fromCodePoint(0xF036D) },
        "bright-low":  { emoji: String.fromCodePoint(0x1F505),         nerd: String.fromCodePoint(0xF00DE) },
        "bright-high": { emoji: String.fromCodePoint(0x1F506),         nerd: String.fromCodePoint(0xF00E0) },
        "vol-muted":   { emoji: String.fromCodePoint(0x1F507),         nerd: String.fromCodePoint(0xF075F) },
        "vol-low":     { emoji: String.fromCodePoint(0x1F508),         nerd: String.fromCodePoint(0xF057F) },
        "vol-med":     { emoji: String.fromCodePoint(0x1F509),         nerd: String.fromCodePoint(0xF0580) },
        "vol-high":    { emoji: String.fromCodePoint(0x1F50A),         nerd: String.fromCodePoint(0xF057E) },
        "wifi-0":      { emoji: String.fromCodePoint(0x1F4F6),         nerd: String.fromCodePoint(0xF092F) },
        "wifi-1":      { emoji: String.fromCodePoint(0x1F4F6),         nerd: String.fromCodePoint(0xF091F) },
        "wifi-2":      { emoji: String.fromCodePoint(0x1F4F6),         nerd: String.fromCodePoint(0xF0922) },
        "wifi-3":      { emoji: String.fromCodePoint(0x1F4F6),         nerd: String.fromCodePoint(0xF0925) },
        "wifi-4":      { emoji: String.fromCodePoint(0x1F4F6),         nerd: String.fromCodePoint(0xF0928) },
        "wifi-off":    { emoji: String.fromCodePoint(0x1F4F5),         nerd: String.fromCodePoint(0xF092E) },
        "ethernet":    { emoji: String.fromCodePoint(0x1F50C),         nerd: String.fromCodePoint(0xF0200) },
        "bluetooth":   { emoji: String.fromCodePoint(0x1F537),         nerd: String.fromCodePoint(0xF00AF) },
        "bluetooth-on":  { emoji: String.fromCodePoint(0x1F537),       nerd: String.fromCodePoint(0xF00B1) },
        "bluetooth-off": { emoji: String.fromCodePoint(0x1F539),       nerd: String.fromCodePoint(0xF00B2) },
        "lock":        { emoji: String.fromCodePoint(0x1F512),         nerd: String.fromCodePoint(0xF033E) },
        "temp":        { emoji: String.fromCodePoint(0x1F321, 0xFE0F), nerd: String.fromCodePoint(0xF2C9) },
        "gpu":         { emoji: String.fromCodePoint(0x1F3AE),         nerd: String.fromCodePoint(0xF08AE) },
        "profile-performance": { emoji: String.fromCodePoint(0x1F680), nerd: String.fromCodePoint(0xF04C5) },
        "profile-balanced":    { emoji: String.fromCodePoint(0x2696, 0xFE0F), nerd: String.fromCodePoint(0xF05D1) },
        "profile-power-saver": { emoji: String.fromCodePoint(0x1F343), nerd: String.fromCodePoint(0xF032A) },
        "coffee":      { emoji: String.fromCodePoint(0x2615),          nerd: String.fromCodePoint(0xF0176) },
        "sleep":       { emoji: String.fromCodePoint(0x1F4A4),         nerd: String.fromCodePoint(0xF04B2) },
        "keyboard":    { emoji: String.fromCodePoint(0x2328, 0xFE0F), nerd: String.fromCodePoint(0xF030C) },
        "caps":        { emoji: String.fromCodePoint(0x1F520),         nerd: String.fromCodePoint(0xF0632) },
        "apps":        { emoji: String.fromCodePoint(0x1F50E),         nerd: String.fromCodePoint(0xF003B) },
        "picker":      { emoji: String.fromCodePoint(0x1F3A8),         nerd: String.fromCodePoint(0xF020A) },
        "note":        { emoji: String.fromCodePoint(0x1F4DD),         nerd: String.fromCodePoint(0xF249) },
        "help":        { emoji: String.fromCodePoint(0x2753),          nerd: String.fromCodePoint(0xF059) },
        "settings":    { emoji: String.fromCodePoint(0x2699, 0xFE0F), nerd: String.fromCodePoint(0xF013) },
        "wallpaper":   { emoji: String.fromCodePoint(0x1F5BC, 0xFE0F), nerd: String.fromCodePoint(0xF03E) },
        "camera":      { emoji: String.fromCodePoint(0x1F4F7),         nerd: String.fromCodePoint(0xF0100) }
    })

    readonly property FontLoader materialFont: FontLoader {
        source: "../assets/MaterialSymbolsRounded.ttf"
    }
    readonly property string materialFamily: materialFont.name || "Material Symbols Rounded"

    function materialGlyph(name) {
        const point = Material.codepoints[name];
        return point === undefined ? "" : String.fromCodePoint(point);
    }

    /// Material Symbols names for the same keys.
    readonly property var materialMap: ({
        "cpu": "memory", "memory": "memory_alt", "disk": "storage", "net": "lan",
        "power": "power_settings_new", "notif": "notifications", "window": "web_asset",
        "clipboard": "content_paste", "updates": "system_update", "uptime": "timer",
        "theme": "palette", "clock": "schedule", "calendar": "calendar_month",
        "music": "music_note", "mic": "mic", "mic-muted": "mic_off",
        "bright-low": "brightness_low", "bright-high": "brightness_high",
        "vol-muted": "volume_off", "vol-low": "volume_mute", "vol-med": "volume_down",
        "vol-high": "volume_up", "wifi-0": "signal_wifi_0_bar", "wifi-1": "network_wifi_1_bar",
        "wifi-2": "network_wifi_2_bar", "wifi-3": "network_wifi_3_bar", "wifi-4": "signal_wifi_4_bar",
        "wifi-off": "wifi_off", "lock": "lock", "temp": "thermostat", "gpu": "developer_board",
        "profile-performance": "speed", "profile-balanced": "balance", "profile-power-saver": "eco",
        "coffee": "local_cafe", "sleep": "bedtime", "keyboard": "keyboard", "caps": "keyboard_capslock", "apps": "apps", "picker": "colorize", "note": "sticky_note_2", "help": "help_outline", "camera": "videocam",
        "ethernet": "lan", "bluetooth": "bluetooth", "bluetooth-on": "bluetooth_connected",
        "bluetooth-off": "bluetooth_disabled", "settings": "settings", "wallpaper": "web_asset"
    })

    /// "auto" means the global default (Settings → Appearance → icons).
    function resolveSet(set) {
        set = (set === undefined || set === "auto") ? Services.Settings.iconSet : set;
        // Nerd glyphs are tofu without a Nerd Font; Material's font is bundled.
        return set === "nerd" && !Services.Settings.hasNerdFont ? "material" : set;
    }

    /// Glyph for a static key. set = "none" | "emoji" | "nerd" | "material" | "auto".
    function glyph(key, set) {
        set = resolveSet(set);
        if (set === "none") return "";
        if (set === "material") return materialMap[key] ?? "";
        let pair = map[key];
        if (!pair) return "";
        return set === "nerd" ? pair.nerd : pair.emoji;
    }

    /// QML color → "#rrggbb" for use inside RichText <font color>.
    function hex(c) {
        function h(x) { let s = Math.round(x * 255).toString(16); return s.length < 2 ? "0" + s : s; }
        return "#" + h(c.r) + h(c.g) + h(c.b);
    }

    /// Escape &, <, > for use as a RichText body.
    function esc(s) {
        return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    /// Wrap an already-resolved glyph in a RichText <font color> span when in
    /// nerd mode; host Text needs textFormat: Text.RichText. The three markup
    /// flavours below differ only in which getter produced the glyph, so they
    /// all route through here.
    function span(g, set, color) {
        set = resolveSet(set);
        if (set === "none" || g === "") return "";
        if (set === "material")
            return "<font face='" + materialFamily + "' color='" + hex(color) + "'>" + materialGlyph(g) + "</font>";
        return set === "nerd" ? "<font color='" + hex(color) + "'>" + g + "</font>" : g;
    }

    /// span() + a trailing space (or "" for "none"), so a hidden icon leaves no
    /// leading gap in the label.
    function pad(g, set, color) {
        let s = span(g, set, color);
        return s === "" ? "" : s + " ";
    }

    function markup(key, set, color) { return span(glyph(key, set), set, color); }
    function prefix(key, set, color) { return pad(glyph(key, set), set, color); }

    /// prefix() for weather condition glyphs.
    function weatherPrefix(id, set, color) { return pad(weather(id, set), set, color); }
    function markupWeather(id, set, color) { return span(weather(id, set), set, color); }

    /// Battery glyph by charge level + charging state (emoji or nf-md). set = "none"|"emoji"|"nerd".
    function battery(pct, charging, set) {
        set = resolveSet(set);
        if (set === "none") return "";
        if (set === "material") {
            if (charging) return "battery_charging_full";
            if (pct >= 95) return "battery_full";
            if (pct < 10) return "battery_alert";
            return "battery_" + Math.min(6, Math.max(0, Math.floor(pct / 15))) + "_bar";
        }
        if (set !== "nerd")
            return charging ? String.fromCodePoint(0x1F50C) : String.fromCodePoint(0x1F50B);
        // nf-md battery glyphs (charging, then discharging buckets rounded down to nearest 10).
        if (charging) return String.fromCodePoint(0xF0084);
        if (pct >= 95) return String.fromCodePoint(0xF0079); // full
        if (pct >= 85) return String.fromCodePoint(0xF0082); // 90
        if (pct >= 75) return String.fromCodePoint(0xF0081); // 80
        if (pct >= 65) return String.fromCodePoint(0xF0080); // 70
        if (pct >= 55) return String.fromCodePoint(0xF007F); // 60
        if (pct >= 45) return String.fromCodePoint(0xF007E); // 50
        if (pct >= 35) return String.fromCodePoint(0xF007D); // 40
        if (pct >= 25) return String.fromCodePoint(0xF007C); // 30
        if (pct >= 15) return String.fromCodePoint(0xF007B); // 20
        if (pct >= 5)  return String.fromCodePoint(0xF007A); // 10
        return String.fromCodePoint(0xF0083);                // alert
    }
    function batteryPrefix(pct, charging, set, color) {
        return pad(battery(pct, charging, set), set, color);
    }

    /// Weather glyph by OpenWeatherMap condition id (emoji or nf-weather).
    function weather(id, set) {
        set = resolveSet(set);
        if (set === "none") return "";
        if (set === "material") {
            if (id >= 200 && id < 300) return "thunderstorm";
            if (id >= 300 && id < 600) return "umbrella";
            if (id >= 600 && id < 700) return "ac_unit";
            if (id >= 701 && id < 800) return "foggy";
            if (id === 800)            return "wb_sunny";
            if (id >= 801 && id < 900) return "cloud";
            return "thermostat";
        }
        if (set !== "nerd") {
            if (id >= 200 && id < 300) return String.fromCodePoint(0x26C8, 0xFE0F);
            if (id >= 300 && id < 400) return String.fromCodePoint(0x1F326, 0xFE0F);
            if (id >= 500 && id < 600) return String.fromCodePoint(0x1F327, 0xFE0F);
            if (id >= 600 && id < 700) return String.fromCodePoint(0x2744, 0xFE0F);
            if (id >= 701 && id < 800) return String.fromCodePoint(0x1F32B, 0xFE0F);
            if (id === 800)            return String.fromCodePoint(0x2600, 0xFE0F);
            if (id >= 801 && id < 900) return String.fromCodePoint(0x2601, 0xFE0F);
            return String.fromCodePoint(0x1F321, 0xFE0F);
        }
        // nf-weather
        if (id >= 200 && id < 300) return String.fromCodePoint(0xE31D); // thunderstorm
        if (id >= 300 && id < 400) return String.fromCodePoint(0xE319); // sprinkle
        if (id >= 500 && id < 600) return String.fromCodePoint(0xE318); // rain
        if (id >= 600 && id < 700) return String.fromCodePoint(0xE31A); // snow
        if (id >= 701 && id < 800) return String.fromCodePoint(0xE313); // fog
        if (id === 800)            return String.fromCodePoint(0xE30D); // clear day
        if (id >= 801 && id < 900) return String.fromCodePoint(0xE312); // cloudy
        return String.fromCodePoint(0xE350); // thermometer
    }
}
