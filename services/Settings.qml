pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "." as Services

/// Settings singleton — persists user preferences to JSON.
/// All properties are writable and trigger a debounced save.
QtObject {
    id: root

    property string barPosition: "top"
    property int barHeight: 35
    // Deliberately minimal. The widgets that need configuring or a network
    // before they say anything useful — updates, weather, media, cpu, memory —
    // are off by default; they are one click away in Settings → Bar.
    property var barLeft: ["separator", "menu", "separator", "workspaces", "separator", "windowTitle"]
    property var barCenter: ["clock"]
    property var barRight: ["audio", "separator", "themeSwitcher", "separator", "systemTray", "separator", "notifications", "separator", "power"]
    // Legacy secondary layout, used when importing existing monitor layouts.
    property var barSecondaryLeft: []
    property var barSecondaryCenter: []
    property var barSecondaryRight: []
    readonly property bool hasSecondaryLayout: barSecondaryLeft.length + barSecondaryCenter.length
        + barSecondaryRight.length > 0
    property string barLayoutMode: defaultBindings.barLayoutMode()
    property var barMonitorProfiles: ({})
    property var barPresets: []
    property string preferredBarOutput: ""
    readonly property var barOutputs: Quickshell.screens.map(screen => screen.name).filter(name => name)
    readonly property string primaryBarOutput: Services.I3.primaryOutput || barOutputs[0] || ""
    readonly property string selectedBarOutput: barOutputs.includes(preferredBarOutput)
        ? preferredBarOutput : barOutputs.includes(primaryBarOutput) ? primaryBarOutput : barOutputs[0] ?? ""
    readonly property string barEditOutput: barLayoutMode === "separate" ? selectedBarOutput : ""

    readonly property var barOptionProps: ({
        left: "barLeft", center: "barCenter", right: "barRight",
        position: "barPosition", height: "barHeight", padding: "barPadding",
        hideVacant: "barHideVacantTags", widgetStyle: "barWidgetStyle",
        pillPadding: "barPillPadding", widgetGap: "barWidgetGap",
        pillRadius: "barPillRadius", pillTint: "barPillTint"
    })
    readonly property var sharedBar: {
        const profile = {};
        for (const key in barOptionProps)
            profile[key] = root[barOptionProps[key]];
        return profile;
    }

    function barFor(output) {
        if (!output || barLayoutMode !== "separate") return sharedBar;
        const defaults = hasSecondaryLayout && primaryBarOutput && output !== primaryBarOutput
            ? { left: barSecondaryLeft, center: barSecondaryCenter, right: barSecondaryRight } : {};
        return Object.assign({}, sharedBar, defaults, barMonitorProfiles?.[output]);
    }

    function setBarValues(output, values) {
        if (output) {
            const profile = Object.assign({}, barFor(output), values);
            barMonitorProfiles = Object.assign({}, barMonitorProfiles, { [output]: profile });
        } else {
            for (const key in values)
                root[barOptionProps[key]] = values[key];
        }
    }

    function setBarLayoutMode(mode) {
        if (mode === barLayoutMode) return;
        // Import the legacy secondary layout as a profile for each known
        // non-primary monitor before retiring it, whichever way the mode
        // switches: it is cleared below, so skipping the import would lose
        // it. A monitor that already has a profile keeps it; new monitors
        // start from the shared bar.
        if (hasSecondaryLayout) {
            const legacy = { left: barSecondaryLeft, center: barSecondaryCenter, right: barSecondaryRight };
            const profiles = Object.assign({}, barMonitorProfiles);
            for (const output of barOutputs) {
                if (output !== primaryBarOutput && !profiles[output])
                    profiles[output] = Object.assign({}, sharedBar, legacy);
            }
            barMonitorProfiles = profiles;
        }
        barLayoutMode = mode;
        if (hasSecondaryLayout) {
            barSecondaryLeft = [];
            barSecondaryCenter = [];
            barSecondaryRight = [];
        }
    }

    function saveBarPreset(name, output) {
        name = name.trim();
        if (!name || barPresets.some(preset => preset.name === name)) return false;
        barPresets = barPresets.concat({ name: name, profile: barFor(output) });
        return true;
    }

    function applyBarPreset(name, output) {
        const preset = barPresets.find(entry => entry.name === name);
        if (preset) setBarValues(output, preset.profile);
    }

    /// Apply a bar preset to `output`, or with "*" to every bar: the shared
    /// one, and in "each monitor its own" mode each monitor's. False if there
    /// is no preset of that name.
    function applyBarPresetTo(name, output) {
        const preset = barPresets.find(entry => entry.name === name);
        if (!preset) return false;
        if (output && output !== "*") {
            setBarValues(barLayoutMode === "separate" ? output : "", preset.profile);
        } else {
            setBarValues("", preset.profile);
            if (barLayoutMode === "separate")
                for (const out of barOutputs) setBarValues(out, preset.profile);
        }
        return true;
    }

    function deleteBarPreset(name) {
        barPresets = barPresets.filter(preset => preset.name !== name);
    }

    // Legacy radius kept for settings files written before shell appearance.
    property int barRadius: 0
    property int shellRadius: defaultBindings.shellRadius()
    property string shellSurfaceStyle: "outlined"
    property bool shellAnimations: true
    property string launcherMode: "full"
    property string launcherResultsLayout: "grid"
    /// Height of one result row in list layout (and compact search), px.
    property int launcherListRowHeight: 40
    property string launcherAction: "launch"
    property bool launcherHistoryEnabled: false
    property var launcherRecentApps: []
    /// Space between the screen edges and the left/right sections (polybar's padding-left/right).
    property int barPadding: 12
    property bool barHideVacantTags: false

    // ─── Widget style (Dux Shell's bar look, with polybar kept) ───
    /// "polybar": plain text + | separators + each widget's own underline/box
    /// (the original look). "pills" | "segments" | "flat": Dux styles, drawn
    /// by components/WidgetSurface.qml around every widget.
    property string barWidgetStyle: "polybar"
    property int barPillRadius: 10
    /// Horizontal padding inside a pill / segment.
    property int barPillPadding: 10
    /// Gap between pills (and between segment runs) in the Dux styles.
    property int barWidgetGap: 6
    /// How strongly the pill surface is tinted toward the foreground (0–40 %).
    property int barPillTint: 12

    /// Default icon set for widgets whose own iconSet is "auto":
    /// "nerd" (Nerd Font glyphs) | "material" (Material Symbols / Icons) | "emoji".
    property string iconSet: "nerd"

    // ─── On-screen display (services/Osd.qml) ───
    property bool osdEnabled: true
    /// Also show the OSD when the microphone is muted / unmuted.
    property bool osdMic: true
    property int osdTimeoutMs: 1500

    // ─── Updates (services/Updates.qml) ───
    property int updatesIntervalHours: 12
    property bool updatesFlatpak: true
    property bool updatesSnap: true

    /// Who draws polkit's admin password prompts: "shell" (panels/PolkitPanel.qml,
    /// via services/Polkit.qml) or "gnome" (the system's own agent: polkit-gnome,
    /// lxpolkit, … — scripts/system/polkit-agent.sh; the value predates the others).
    property string polkitAgent: "shell"

    /// The font picked in Settings → Fonts (stored as general.fontFamily).
    /// Should be a Nerd Font — see fontFamilies below. Cascadia because it is
    /// the one Fedora actually packages.
    property string fontChoice: "Cascadia Code NF"
    /// The font everything uses: the choice if it's installed, else the first
    /// installed Nerd Font (bar icons are Nerd Font glyphs), else the system
    /// font — so a missing font never turns the bar into tofu.
    readonly property bool hasNerdFont: fontFamilies.some(f => /nerd font|\bNF[MP]?\b/i.test(f))
    readonly property string fontFamily: {
        const all = Qt.fontFamilies();
        if (all.includes(fontChoice)) return fontChoice;
        return fontFamilies.find(f => /nerd font|\bNF[MP]?\b/i.test(f)) ?? "sans-serif";   // fontconfig maps it to the system default
    }
    property int fontSize: 17
    /// Panel, popup and Settings text, in % of the original sizes (Ui.text*).
    property int panelTextScale: 100

    /// Legacy free-text terminal command. Still read as the fallback when no
    /// desktop entry has been chosen, so an existing settings.json keeps
    /// working; DefaultApps keeps it in step when you pick one.
    property string appTerminal: "kitty"
    /// Desktop-entry id of the chosen terminal (e.g. "kitty.desktop").
    /// An id rather than a command: it carries the entry's own argv, which is
    /// already parsed and field-code-free.
    property string appTerminalId: ""

    property int maxVisible: 5
    property int autoDismissSeconds: 10
    /// How many notifications the Control Center keeps. They are no longer
    /// closed when their toast times out, so something has to bound the list.
    property int historyLimit: 50

    property string weatherCity: ""
    property string weatherCountry: ""
    property string weatherUnits: "metric"

    /// Where the Wallpapers tab lists images from.
    property string wallpaperDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    /// output -> its own picture folder (Settings → Themes & wallpapers, with a
    /// monitor picked); a monitor without one uses wallpaperDir.
    property var wallpaperDirs: ({})
    /// Old: slug -> wallpaper, brought back with that theme ("Remember the
    /// wallpaper for this theme"). Presets replaced it; read once so
    /// migrateThemeWallpapers() can turn each into a preset, then dropped.
    property var themeWallpapers: ({})
    /// Saved looks: [{ id, name, theme: <slug>, wallpapers: <path or set>,
    /// bar?: { preset: <bar preset name>, output: "*" | <output> } }], where a
    /// set is { "*": path, <output>: path } (services/Wallpaper.qml) and `bar`
    /// is applied with applyBarPresetTo().
    /// Settings → Themes & wallpapers → Presets; Theme.applyPreset().
    property var themePresets: []
    /// Theme hook ids that don't run on a theme switch (scripts/theming/theme-hooks.py
    /// reads this key straight from settings.json). Settings -> Theme hooks.
    property var themeHooksDisabled: []

    /// Screenshots (panels/ScreenshotSelector.qml): where Save puts them, the
    /// strftime-style name (components/Strftime.js; no .png), and whether
    /// Save asks for a name, prefilled with that one.
    property string screenshotDir: Quickshell.env("HOME") + "/Pictures/Screenshots"
    property string screenshotNameFormat: "Screenshot_%Y-%m-%d_%H-%M-%S"
    property bool screenshotAskName: false


    /// True once settings.json has been read, or ruled absent. Anything that
    /// branches on a stored value must wait for this — before it, every
    /// property above is still the compiled default.
    readonly property bool ready: internal.loaded

    // Property name -> dotted path in settings.json. One table drives loading,
    // saving, and the change-handler wiring below, so a new setting is a
    // declaration above plus one row here — not four edits in four places.
    readonly property var schema: ({
        barLayoutMode: "bar.layoutMode",
        barMonitorProfiles: "bar.monitorProfiles",
        barPresets: "bar.presets",
        barPosition: "bar.position",
        barHeight: "bar.height",
        barLeft: "bar.left",
        barCenter: "bar.center",
        barRight: "bar.right",
        barSecondaryLeft: "bar.secondary.left",
        barSecondaryCenter: "bar.secondary.center",
        barSecondaryRight: "bar.secondary.right",
        barRadius: "bar.radius",
        shellRadius: "appearance.radius",
        shellSurfaceStyle: "appearance.surfaceStyle",
        shellAnimations: "appearance.animations",
        launcherMode: "launcher.mode",
        launcherResultsLayout: "launcher.resultsLayout",
        launcherListRowHeight: "launcher.listRowHeight",
        launcherAction: "launcher.action",
        launcherHistoryEnabled: "launcher.historyEnabled",
        launcherRecentApps: "launcher.recentApps",
        barPadding: "bar.padding",
        barHideVacantTags: "bar.hideVacantTags",
        barWidgetStyle: "bar.widgetStyle",
        barPillRadius: "bar.pillRadius",
        barPillPadding: "bar.pillPadding",
        barWidgetGap: "bar.widgetGap",
        barPillTint: "bar.pillTint",
        iconSet: "general.iconSet",
        osdEnabled: "osd.enabled",
        osdMic: "osd.mic",
        osdTimeoutMs: "osd.timeoutMs",
        updatesIntervalHours: "updates.intervalHours",
        updatesFlatpak: "updates.flatpak",
        updatesSnap: "updates.snap",
        polkitAgent: "polkit.agent",
        fontChoice: "general.fontFamily",
        fontSize: "general.fontSize",
        panelTextScale: "general.panelTextScale",
        appTerminal: "defaultApps.terminal",
        appTerminalId: "defaultApps.terminalId",
        maxVisible: "notifications.maxVisible",
        autoDismissSeconds: "notifications.autoDismissSeconds",
        historyLimit: "notifications.historyLimit",
        weatherCity: "weather.city",
        weatherCountry: "weather.country",
        weatherUnits: "weather.units",
        wallpaperDir: "general.wallpaperDir",
        wallpaperDirs: "general.wallpaperDirs",
        themeWallpapers: "theme.wallpapers",
        themePresets: "theme.presets",
        themeHooksDisabled: "theme.hooksDisabled",
        screenshotDir: "screenshots.directory",
        screenshotNameFormat: "screenshots.nameFormat",
        screenshotAskName: "screenshots.askName"
    })

    // These hold widget-instance arrays, not scalars, so they go through
    // normalizeSection() on the way in.
    /// Read for migration only (bar.secondary became per-monitor profiles,
    /// bar.radius became appearance.radius).
    readonly property var legacyProps: ["barSecondaryLeft", "barSecondaryCenter", "barSecondaryRight", "barRadius", "themeWallpapers"]

    readonly property var sectionProps: ["barLeft", "barCenter", "barRight",
        "barSecondaryLeft", "barSecondaryCenter", "barSecondaryRight"]

    // Plain object maps. Like sectionProps they are `var`, so `!==` compares by
    // reference and would reassign on every load; they need a value compare.
    readonly property var objectProps: ["themeWallpapers", "themePresets", "wallpaperDirs", "themeHooksDisabled", "launcherRecentApps", "barMonitorProfiles", "barPresets"]

    /// Settings whose default follows other settings. The declarations above
    /// bind to these, and a key deleted from settings.json gets the binding
    /// back rather than a frozen value (see restoreDefault()).
    readonly property var defaultBindings: ({
        barLayoutMode: () => root.hasSecondaryLayout ? "separate" : "shared",
        shellRadius: () => root.barRadius > 0 ? root.barRadius : 12
    })

    /// Put a setting back to its compiled default: what a key removed from
    /// settings.json means. Snapshots are JSON copies taken before the first
    /// load, so later edits to an array or map can't leak into them.
    function restoreDefault(prop) {
        if (defaultBindings[prop]) {
            root[prop] = Qt.binding(defaultBindings[prop]);
            return;
        }
        const raw = internal.defaults[prop];
        if (raw === undefined || raw === JSON.stringify(root[prop])) return;
        root[prop] = JSON.parse(raw);
    }

    /// Turn the old per-theme wallpapers (theme.wallpapers) into presets named
    /// after their theme, skipping any that a preset already holds, then drop
    /// them. `names` is slug -> theme name (Theme.names). Theme.qml runs this
    /// once the themes and settings.json are both read.
    function migrateThemeWallpapers(names) {
        const old = themeWallpapers ?? {};
        const slugs = Object.keys(old);
        if (slugs.length === 0) return 0;
        const abs = p => String(p).charAt(0) === "/" ? String(p) : wallpaperDir.replace(/\/+$/, "") + "/" + p;
        const norm = map => {
            const out = {};
            for (const k of Object.keys(map).sort()) out[k] = abs(map[k]).replace(/\/+/g, "/");
            return JSON.stringify(out);
        };
        let added = 0;
        for (const slug of slugs) {
            const value = old[slug];
            if (!value) continue;
            const map = typeof value === "string" ? { "*": value } : value;
            const resolved = {};
            for (const k in map) if (map[k]) resolved[k] = abs(map[k]);
            const key = norm(resolved);
            const held = (themePresets ?? []).some(p => p.theme === slug && p.wallpapers
                && norm(typeof p.wallpapers === "string" ? { "*": p.wallpapers } : p.wallpapers) === key);
            if (held) continue;
            const keys = Object.keys(resolved);
            saveThemePreset({ name: names[slug] ?? slug, theme: slug,
                wallpapers: keys.length === 1 && resolved["*"] ? resolved["*"] : resolved });
            added++;
        }
        themeWallpapers = {};
        console.log("Settings: turned", added, "theme wallpaper(s) into presets");
        return added;
    }

    /// Give a monitor its own picture folder; "" (or the shared folder) drops it.
    function setWallpaperDir(output, dir) {
        if (!output || output === "*") { wallpaperDir = dir; return; }
        const next = Object.assign({}, wallpaperDirs);
        if (dir && dir !== wallpaperDir) next[output] = dir; else delete next[output];
        wallpaperDirs = next;
    }

    /// Save a preset (a new one, or replace the one with that id). Returns its id.
    function saveThemePreset(preset) {
        const list = (themePresets ?? []).slice();
        let id = preset.id;
        if (!id) {
            const base = (preset.name || "preset").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "") || "preset";
            id = base;
            for (let n = 2; list.some(p => p.id === id); n++) id = base + "-" + n;
        }
        const entry = { id: id, name: preset.name || id, theme: preset.theme || "", wallpapers: preset.wallpapers ?? "" };
        if (preset.bar?.preset) entry.bar = { preset: preset.bar.preset, output: preset.bar.output || "*" };
        const at = list.findIndex(p => p.id === id);
        if (at >= 0) list[at] = entry; else list.push(entry);
        themePresets = list;
        return id;
    }
    /// Set (or with no bar preset name, clear) the bar layout a theme preset applies.
    function setThemePresetBar(id, barPreset, output) {
        const list = (themePresets ?? []).slice();
        const i = list.findIndex(p => p.id === id);
        if (i < 0) return;
        const entry = Object.assign({}, list[i]);
        if (barPreset) entry.bar = { preset: barPreset, output: output || "*" };
        else delete entry.bar;
        list[i] = entry;
        themePresets = list;
    }
    function removeThemePreset(id) { themePresets = (themePresets ?? []).filter(p => p.id !== id); }
    /// Move a preset `delta` places up (-1) or down (+1).
    function moveThemePreset(id, delta) {
        const list = (themePresets ?? []).slice();
        const i = list.findIndex(p => p.id === id), j = i + delta;
        if (i < 0 || j < 0 || j >= list.length) return;
        [list[i], list[j]] = [list[j], list[i]];
        themePresets = list;
    }

    // Bar sections are arrays of widget instance objects: { id, type, style, color, ... };
    // normalizeSection() upgrades legacy string entries transparently on load.
    function genWidgetId() { return "w" + Math.random().toString(36).slice(2, 8); }

    function defaultStyleFor(type) {
        return (type === "separator" || type === "spacer"
                || type === "windowTitle" || type === "workspaces") ? "none" : "underline";
    }

    function separatorWidth(instance) {
        return instance.width ?? (instance.type === "spacer" ? 50 : 12);
    }

    // Per-widget-type options live in services/WidgetCatalog.qml, with the
    // rest of each type's registration.

    // Font pickers list Nerd Fonts first: every bar icon is a Nerd Font
    // codepoint, so anything else renders the widgets as tofu.
    readonly property var fontFamilies: {
        const all = Qt.fontFamilies();
        const nerd = /nerd font|\bNF[MP]?\b/i;
        return all.filter(f => nerd.test(f)).concat(all.filter(f => !nerd.test(f)));
    }

    function normalizeWidget(el) {
        if (el && typeof el === "object") {
            let out = {
                id: el.id || genWidgetId(),
                type: el.type,
                style: el.style || defaultStyleFor(el.type),
                color: el.color || "auto",
                iconSet: el.iconSet || "auto",
                // Per-widget override of the bar's widget style:
                // "inherit" | "pill" | "plain" | "polybar".
                surface: el.surface || "inherit"
            };
            Services.WidgetCatalog.optionKeys.forEach(function (k) {
                if (el[k] !== undefined) out[k] = el[k];
            });
            // A user widget's options are keys only its widget.json knows,
            // and settings.json may load before that folder has been read:
            // keep all of them rather than drop them.
            if (Services.WidgetCatalog.isUser(el.type))
                for (const k in el)
                    if (out[k] === undefined && el[k] !== undefined) out[k] = el[k];
            return out;
        }
        // String form (used by the built-in section defaults above)
        let s = String(el);
        return { id: genWidgetId(), type: s, style: defaultStyleFor(s), color: "auto", iconSet: "auto", surface: "inherit" };
    }

    /// Widget types that were folded into another one: an old layout's entry
    /// becomes the new type rather than an empty slot.
    /// `merge`: several of them in one section become a single widget.
    readonly property var retiredTypes: ({
        wifi: { into: "controlCenter", merge: true },
        bluetooth: { into: "controlCenter", merge: true },
        updates: { into: "controlCenter", merge: true },
        cpu: { into: "sysMonitor", options: { showCpu: true, showMemory: false, showGpu: false } },
        memory: { into: "sysMonitor", options: { showCpu: false, showMemory: true, showGpu: false } }
    })

    function normalizeSection(arr) {
        if (!Array.isArray(arr)) return [];
        const out = [];
        for (const el of arr) {
            const type = el && typeof el === "object" ? el.type : String(el);
            const retired = retiredTypes[type];
            if (retired) {
                // Wi-Fi and Updates side by side become one Control Center.
                if (retired.merge && out.some(w => w.type === retired.into)) continue;
                const old = typeof el === "object" ? el : {};
                const migrated = normalizeWidget(Object.assign({}, old, retired.options ?? {}, { type: retired.into }));
                migrated.style = old.style ?? migrated.style;
                out.push(migrated);
                continue;
            }
            out.push(normalizeWidget(el));
        }
        return out;
    }

    /// A stored bar profile (a monitor's, or a preset's) with its sections
    /// normalized like barLeft & co., so hand-edited or old string entries
    /// work there too. Other keys pass through.
    function normalizeProfile(profile) {
        if (!profile || typeof profile !== "object") return {};
        const out = Object.assign({}, profile);
        for (const section of ["left", "center", "right"])
            if (out[section] !== undefined) out[section] = normalizeSection(out[section]);
        return out;
    }

    // Normalize string-form section arrays at startup so the model always sees instance objects.
    Component.onCompleted: {
        for (const p of sectionProps)
            root[p] = normalizeSection(root[p]);
        const defaults = {};
        for (const p in schema)
            defaults[p] = JSON.stringify(root[p]);
        internal.defaults = defaults;
        // Every setting saves the same way, so wire the change signals in a
        // loop rather than writing eighteen identical handlers.
        for (const p in schema)
            root[p + "Changed"].connect(internal.scheduleSave);
    }

    readonly property QtObject internal: QtObject {
        id: internal
        property string settingsPath: Services.Paths.settingsPath
        property bool loaded: false
        property bool saving: false
        /// prop -> JSON of its compiled default (Component.onCompleted).
        property var defaults: ({})
        /// Props whose key settings.json held at the last load or save. Only
        /// these go back to their default when the key disappears: the first
        /// load must not touch settings the file never had, nor break their
        /// bindings.
        property var inFile: ({})

        property FileView fileView: FileView {
            path: Qt.resolvedUrl("file://" + internal.settingsPath)
            watchChanges: true
            preload: true
            atomicWrites: true
            // No settings.json on a first run is normal (defaults apply);
            // any other read error is still reported.
            printErrors: false
            onLoadFailed: error => {
                if (error !== FileViewError.FileNotFound)
                    console.warn("Settings: could not read", internal.settingsPath + ":", FileViewError.toString(error));
            }
            onTextChanged: {
                // setText() fires this on our own save. Re-loading it would hand
                // loadFromText a fresh copy of what we just wrote — see the
                // identity note there for why that is not harmless.
                if (internal.saving) {
                    internal.loaded = true;
                    return;
                }
                internal.loadFromText(this.text());
                internal.loaded = true;
            }
            onFileChanged: {
                // Ignore file changes triggered by our own save
                if (internal.saving) return;
                this.reload();
                internal.loadFromText(this.text());
            }
            // Clear the saving guard once our own write lands (was the saveProc callback).
            onSaved: internal.savingClearTimer.start()
            onSaveFailed: function (error) {
                console.warn("Settings: save failed:", error);
                internal.saving = false;
            }
        }

        property Timer saveTimer: Timer {
            interval: 500
            onTriggered: internal.saveToFile()
        }

        function scheduleSave() {
            if (!loaded || loading) return;
            saveTimer.restart();
        }

        property bool loading: false

        // Walk a dotted path into obj; undefined if any segment is missing.
        function dig(obj, path) {
            return path.split(".").reduce((o, k) =>
                (o === undefined || o === null) ? undefined : o[k], obj);
        }

        function loadFromText(raw) {
            if (!raw || raw.length === 0) {
                console.log("Settings: no file found, using defaults");
                return;
            }

            try {
                loading = true;
                let j = JSON.parse(raw);
                const present = {};
                for (const prop in root.schema) {
                    let v = dig(j, root.schema[prop]);
                    if (v === undefined) {
                        // A key deleted by hand means "back to the default".
                        // Keeping the old value would also write it straight
                        // back on the next save.
                        if (inFile[prop]) root.restoreDefault(prop);
                        continue;
                    }
                    present[prop] = true;
                    if (root.sectionProps.indexOf(prop) >= 0) {
                        // normalizeSection mints new objects every call, and `var`
                        // properties compare by reference — so assigning an equal
                        // array still emits barLeftChanged. That resets TopBar's
                        // Repeaters, which destroys and rebuilds every widget on
                        // every monitor. Only assign when the content really differs.
                        let next = normalizeSection(v);
                        if (JSON.stringify(next) !== JSON.stringify(root[prop]))
                            root[prop] = next;
                    } else if (root.objectProps.indexOf(prop) >= 0) {
                        // Same reference-vs-value problem as sectionProps. Bar
                        // profiles hold sections too, so normalize those.
                        if (prop === "barMonitorProfiles" && v && typeof v === "object") {
                            const profiles = {};
                            for (const output in v) profiles[output] = normalizeProfile(v[output]);
                            v = profiles;
                        } else if (prop === "barPresets" && Array.isArray(v)) {
                            v = v.map(preset => Object.assign({}, preset,
                                { profile: normalizeProfile(preset?.profile) }));
                        }
                        if (JSON.stringify(v) !== JSON.stringify(root[prop]))
                            root[prop] = v;
                    } else if (root[prop] !== v) {
                        root[prop] = v;
                    }
                }
                inFile = present;
                loading = false;
                console.log("Settings: loaded from", settingsPath);
            } catch (e) {
                loading = false;
                console.warn("Settings: failed to parse JSON:", e);
            }
        }

        function toJson() {
            let out = {};
            for (const prop in root.schema) {
                // Migration-only keys are written only while they hold
                // something, so new files don't carry them forever.
                if (root.legacyProps.includes(prop) && JSON.stringify(root[prop]) === defaults[prop]) continue;
                let parts = root.schema[prop].split(".");
                let leaf = parts.pop();
                let node = parts.reduce((o, k) => (o[k] = o[k] || {}), out);
                node[leaf] = root[prop];
            }
            return JSON.stringify(out, null, 2);
        }

        property Timer savingClearTimer: Timer {
            // Delay clearing the saving flag so FileView's onFileChanged can check it first.
            interval: 200
            onTriggered: internal.saving = false
        }

        function saveToFile() {
            saving = true;
            const all = {};
            for (const prop in root.schema) all[prop] = true;
            inFile = all;   // toJson() writes every key
            fileView.setText(toJson());  // native atomic write; onSaved clears `saving`
        }
    }

    // Bootstrap timer — only saves defaults if file didn't load after 1 second
    property Timer bootstrapTimer: Timer {
        interval: 1000
        running: true
        onTriggered: {
            if (!internal.loaded) {
                internal.loaded = true;
                internal.scheduleSave();
                console.log("Settings: bootstrapping defaults (no file found)");
            }
        }
    }
}
