pragma Singleton

import QtQuick
import Quickshell.Io
import "." as Services
import "../lib" as Lib

/// Theme registry + switcher — shipped themes/ plus the user's Paths.userThemesDir (a user theme of the same slug wins); active slug persists to Paths.statePath (watched by Colors.qml).
QtObject {
    id: root

    readonly property string themesDir: Services.Paths.themesDir
    readonly property string userThemesDir: Services.Paths.userThemesDir
    readonly property string statePath: Services.Paths.statePath

    /// [{ name, slug, swatches, shipped, userFile }] from both theme folders, sorted by name.
    property var themes: []
    /// slug -> name and slug -> swatches, for dropdowns (StyledDropdown labels/swatches).
    /// A loop, not Object.fromEntries: Qt's JS engine doesn't have it.
    readonly property var names: { const m = {}; for (const t of themes) m[t.slug] = t.name; return m; }
    readonly property var swatchesBySlug: { const m = {}; for (const t of themes) m[t.slug] = t.swatches; return m; }
    readonly property var slugs: themes.map(t => t.slug)
    /// Currently applied theme slug.
    property string currentSlug: ""

    /// The JSON file for a slug: the user's copy if there is one, else shipped.
    function pathFor(slug) {
        return (internal.themeMap[slug]?.userFile ? root.userThemesDir : root.themesDir) + "/" + slug + ".json";
    }

    /// Re-scan the themes folder.
    function refresh() { internal.listProc.running = true; }

    /// Save a theme (name + palette) to the user's themes dir as <slug>.json,
    /// then apply it. A name that matches a shipped theme gets a suffix
    /// ("nord-2"): shipped themes are never overwritten, a user's own theme
    /// of the same name is (that's editing it).
    function saveTheme(name, palette) {
        name = (name || "").trim();
        let base = name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
        if (!base) base = "custom";
        let slug = base;
        for (let n = 2; internal.themeMap[slug]?.shipped; n++) slug = base + "-" + n;

        let p = {};
        for (let k in palette) p[k] = String(palette[k]).replace(/^#/, "");
        if (p.lavender === undefined)  p.lavender = p.mauve || "";
        if (p.maroon === undefined)    p.maroon = p.red || "";
        if (p.orange === undefined)    p.orange = p.yellow || "";
        if (p.teal === undefined)      p.teal = p.cyan || "";
        if (p.selection === undefined) p.selection = p.comment || "";

        let bg = p.bg || "000000";
        let lum = 0;
        try {
            lum = (parseInt(bg.slice(0, 2), 16) * 0.299
                 + parseInt(bg.slice(2, 4), 16) * 0.587
                 + parseInt(bg.slice(4, 6), 16) * 0.114) / 255;
        } catch (e) { lum = 0; }

        let obj = { meta: { name: name || slug, slug: slug, dark: lum < 0.5 }, palette: p };
        internal.pendingApplySlug = slug;
        internal.saveView.path = Qt.resolvedUrl("file://" + root.userThemesDir + "/" + slug + ".json");
        internal.saveView.setText(JSON.stringify(obj, null, 2));
    }

    /// Apply a saved preset (Settings.themePresets) by id or name: its colours,
    /// exactly its wallpapers, and its bar layout if it has one. False if
    /// there is no such preset.
    function applyPreset(idOrName) {
        const want = String(idOrName ?? "").toLowerCase();
        const preset = (Services.Settings.themePresets ?? []).find(p => p.id === idOrName)
            ?? (Services.Settings.themePresets ?? []).find(p => (p.name ?? "").toLowerCase() === want);
        if (!preset) return false;
        if (preset.theme && internal.themeMap[preset.theme]) apply(preset.theme, preset.wallpapers || null);
        else if (preset.wallpapers) Services.Wallpaper.setMap(typeof preset.wallpapers === "string"
            ? { "*": preset.wallpapers } : preset.wallpapers);
        if (preset.bar?.preset && !Services.Settings.applyBarPresetTo(preset.bar.preset, preset.bar.output))
            console.warn("Theme: preset", preset.name, "names a bar layout that no longer exists:", preset.bar.preset);
        return true;
    }

    /// The preset matching what's on screen now (colours and wallpapers), or null.
    readonly property var activePreset: {
        return (Services.Settings.themePresets ?? []).find(p =>
            p.theme === root.currentSlug && (!p.wallpapers || Services.Wallpaper.matches(p.wallpapers))) ?? null;
    }

    /// Apply a theme by slug: persist it, run the theme hooks
    /// (scripts/theming/theme-hooks.py) and, given `wallpapers` (a path or a
    /// set; a preset passes its own), set those. Colours alone leave the
    /// wallpaper as it is: a preset is how the two go together.
    function apply(slug, wallpapers) {
        root.currentSlug = slug;
        // Deliberately a shell call, not currentView.setText(): Quickshell's
        // FileView cannot create missing parent directories, and on a fresh
        // machine the state dir may not exist yet.
        internal.writeProc.run(["sh", "-c",
            "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1\"",
            "sh", root.statePath, slug]);
        if (wallpapers) Services.Wallpaper.setMap(typeof wallpapers === "string" ? { "*": wallpapers } : wallpapers);
        internal.applyExternals(slug);
    }

    /// Run the theme hooks again for the current theme (Settings → Theme hooks).
    function reapplyExternals() {
        if (root.currentSlug) internal.applyExternals(root.currentSlug);
    }

    readonly property QtObject internal: QtObject {
        id: internal

        // slug -> { slug, name, swatches, wallpaper }; populated by listProc below.
        property var themeMap: ({})
        property string pendingApplySlug: ""

        function rebuild() {
            let arr = Object.keys(themeMap).map(k => themeMap[k]);
            arr.sort((a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase()));
            root.themes = arr;
        }

        // Read every theme JSON in one POSIX sh pass, shipped ($1) then the
        // user's ($2), emitting each as "\n===THEME:<s|u>:<slug>===\n<json>" so
        // QML can split + parse it; a user theme of the same slug replaces the
        // shipped one. Quickshell has no reliable N-file reader for a
        // non-visual singleton (Instantiator+FileView didn't populate; Qt
        // blocks file:// XHR), so this small shell read is the robust path.
        property Process listProc: Process {
            running: true
            command: ["sh", "-c",
                "for f in \"$1\"/*.json \"$2\"/*.json; do [ -e \"$f\" ] || continue; " +
                "case \"$f\" in \"$1\"/*) k=s ;; *) k=u ;; esac; " +
                "printf '\\n===THEME:%s:%s===\\n' \"$k\" \"$(basename \"$f\" .json)\"; cat \"$f\"; done",
                "sh", root.themesDir, root.userThemesDir]
            stdout: StdioCollector {
                onStreamFinished: {
                    let map = {};
                    for (let c of this.text.split("\n===THEME:")) {
                        let end = c.indexOf("===\n");
                        if (end < 0) continue;
                        const tag = c.slice(0, end);   // "s:<slug>" shipped, "u:<slug>" user
                        internal.ingestInto(map, tag.slice(2), c.slice(end + 4), tag.charAt(0) === "s");
                    }
                    internal.themeMap = map;
                    internal.rebuild();
                    internal.migrate();
                }
            }
        }

        // Parse one theme file into `map` (name + ordered swatches + wallpaper path).
        function ingestInto(map, slug, txt, shipped) {
            let name = slug, swatches = [];
            try {
                let j = JSON.parse(txt || "{}");
                name = (j.meta && j.meta.name) || slug;
                let pal = j.palette || {};
                let order = ["bg", "red", "green", "yellow", "blue", "mauve", "cyan", "fg"];
                for (let k of order) {
                    let v = pal[k];
                    if (v) swatches.push(String(v).startsWith("#") ? String(v) : "#" + v);
                }
            } catch (e) {
                console.warn("Theme: failed to parse", slug, e);
            }
            // `shipped` stays true when a user theme overrides a shipped slug,
            // so the builder still won't write over the shipped file's name.
            map[slug] = { slug: slug, name: name, swatches: swatches,
                shipped: shipped || (map[slug]?.shipped ?? false), userFile: !shipped };
        }

        // Old theme -> wallpaper links become presets once both the themes
        // (for their names) and settings.json are read; see Settings.
        function migrate() {
            if (Services.Settings.ready && root.themes.length > 0)
                Services.Settings.migrateThemeWallpapers(root.names);
        }
        property Connections settingsReady: Connections {
            target: Services.Settings
            function onReadyChanged() { internal.migrate(); }
        }

        function applyExternals(slug) {
            // The theme hooks (i3, rofi, kitty, GTK, Qt, KDE, the user's); see theme-hooks.py.
            // Hand over the live on/off switches: settings.json is saved 500 ms after a change.
            externalsProc.run(["env", "REVENANT_HOOKS_DISABLED=" + JSON.stringify(Services.Settings.themeHooksDisabled),
                "bash", Services.Paths.script("theming/apply-theme-externals.sh"), slug]);
        }

        // Writes <user themes>/<slug>.json, re-scans the list, then applies it.
        property FileView saveView: FileView {
            atomicWrites: true
            onSaved: { internal.listProc.running = true; root.apply(internal.pendingApplySlug); }
            onSaveFailed: error => console.warn("Theme: save failed:", error)
        }

        // Queued: arrow-key previews apply a theme per step, and a plain
        // Process drops a run requested while the last is still going (i3
        // and kitty ended up on an older theme than the one shown).
        property Lib.QueuedProcess writeProc: Lib.QueuedProcess {
            onFinished: code => { if (code !== 0) console.warn("Theme: could not save the current theme"); }
        }
        property Lib.QueuedProcess externalsProc: Lib.QueuedProcess {
            onFinished: code => { if (code !== 0) console.warn("Theme: re-theming external apps failed"); }
        }

        // Track the persisted current slug so the UI can highlight it.
        property FileView currentView: FileView {
            path: Qt.resolvedUrl("file://" + root.statePath)
            watchChanges: true
            preload: true
            // No theme picked yet on a first run is normal; other errors aren't.
            printErrors: false
            onLoadFailed: error => {
                if (error !== FileViewError.FileNotFound)
                    console.warn("Theme: could not read", root.statePath + ":", FileViewError.toString(error));
            }
            onFileChanged: this.reload()
            onTextChanged: root.currentSlug = this.text().trim()
            Component.onCompleted: root.currentSlug = this.text().trim()
        }
    }
}
