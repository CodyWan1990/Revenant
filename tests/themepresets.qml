import QtQuick
import Quickshell
import Quickshell.Io
import "services" as Services

/// Regression test for theme presets and per-monitor wallpapers
/// (services/Wallpaper.qml, Settings.themePresets, Theme.applyPreset) with the
/// tests/bin xwallpaper/pkill stand-ins: the real wallpaper is never touched,
/// and no theme hook runs (the sandbox has no theme files).
/// Run with scripts/dev/run-qs-tests.sh.
ShellRoot {
    id: root
    property int failures: 0
    function check(cond, what) {
        if (!cond) { console.warn("FAIL: " + what); failures++; }
        else console.warn("  ok: " + what);
    }
    readonly property var wp: Services.Wallpaper
    readonly property string pics: Services.Paths.home + "/pics"
    property int step: 0

    FileView { id: log; path: Services.Paths.home + "/xwallpaper.log"; blockLoading: true; blockAllReads: true }
    function logged() { log.reload(); log.waitForJob(); return log.text(); }

    Process {
        id: setup
        // The active theme comes from the state file, as after a real switch.
        command: ["sh", "-c", 'mkdir -p "$1" "$(dirname "$2")" && touch "$1/a.png" "$1/b.png" "$1/c.png" && printf nord > "$2"',
            "sh", root.pics, Services.Paths.statePath]
        onExited: {
            // Its watcher doesn't see a file created after it started (a real
            // session has one from the start), so read it again.
            Services.Theme.internal.currentView.reload();
            themeRead.start();
        }
    }
    Timer {
        id: themeRead
        interval: 50; repeat: true
        onTriggered: {
            if (Services.Theme.currentSlug !== "nord") return;
            stop();
            root.step = 1;
            root.wp.setMap({ "*": root.pics + "/a.png", "DP-9": "b.png" });   // b.png: not in the wallpaper folder
        }
    }

    Connections {
        target: root.wp
        function onUpdated() { Qt.callLater(root.advance); }
    }

    function advance() {
        switch (step) {
        case 1: {
            // "b.png" resolves against the wallpaper folder, which isn't pics:
            // the script refuses the whole set and nothing changes.
            check(Object.keys(wp.current).length === 0, "a missing picture sets nothing");
            check(wp.error !== "", "and is reported");
            step = 2;
            wp.setMap({ "*": pics + "/a.png", "DP-9": pics + "/b.png" });
            return;
        }
        case 2: {
            check(wp.current["*"] === pics + "/a.png" && wp.current["DP-9"] === pics + "/b.png", "a per-monitor set is stored");
            const last = logged().trim().split("\n").filter(l => !l.startsWith("pkill")).pop() ?? "";
            check(last.indexOf("--output all --zoom " + pics + "/a.png") === 9
                  && last.indexOf("--output DP-9 --zoom " + pics + "/b.png") > 0,
                  "xwallpaper gets the all-monitors picture first (" + last + ")");
            check(logged().includes("pkill"), "the previous daemon is stopped (through the stand-in)");
            check(wp.imageOn("DP-9") === pics + "/b.png" && wp.imageOn("HDMI-1") === pics + "/a.png", "imageOn falls back to *");

            check(Services.Theme.currentSlug === "nord", "the active theme is read");
            const id = Services.Settings.saveThemePreset({ name: "Night drive", theme: "nord", wallpapers: wp.compact(wp.current) });
            check(id === "night-drive", "a preset gets a slug id");
            check(Services.Theme.activePreset?.id === "night-drive", "it is the active preset");
            check(Services.Settings.saveThemePreset({ name: "Night drive" }) === "night-drive-2", "a second one of that name gets its own id");
            Services.Settings.removeThemePreset("night-drive-2");
            check(Services.Settings.themePresets.length === 1, "remove drops it");

            step = 3;
            wp.set(pics + "/c.png", "*");
            return;
        }
        case 3:
            check(Object.keys(wp.current).length === 1 && wp.current["*"] === pics + "/c.png", "all monitors drops the per-monitor pictures");
            check(Services.Theme.activePreset === null, "the preset is no longer active");
            step = 4;
            check(Services.Theme.applyPreset("NIGHT DRIVE"), "applyPreset finds it by name");
            check(!Services.Theme.applyPreset("nope"), "and refuses an unknown one");
            return;
        case 4:
            check(wp.current["DP-9"] === pics + "/b.png" && wp.current["*"] === pics + "/a.png", "applying it brings the whole set back");
            check(Services.Theme.activePreset?.id === "night-drive", "and it is active again");
            step = 5;
            wp.set(pics + "/c.png", "DP-9");
            return;
        case 5:
            check(wp.current["DP-9"] === pics + "/c.png" && wp.current["*"] === pics + "/a.png", "one monitor changes, the rest stay");

            // Per-monitor picture folders.
            const shared = Services.Settings.wallpaperDir;
            Services.Settings.setWallpaperDir("DP-9", pics);
            check(wp.dirFor("DP-9") === pics && wp.dirFor("HDMI-1") === shared && wp.dirFor("*") === shared,
                  "a monitor can have its own folder; the others use the shared one");
            Services.Settings.setWallpaperDir("DP-9", shared);
            check(Services.Settings.wallpaperDirs["DP-9"] === undefined, "picking the shared folder again drops its own");
            Services.Settings.setWallpaperDir("DP-9", pics);
            Services.Settings.setWallpaperDir("DP-9", "");
            check(wp.dirFor("DP-9") === shared, "and so does an empty one");

            // A preset can bring a bar layout (a saved bar preset) along.
            const S = Services.Settings;
            S.barHeight = 33;
            check(S.saveBarPreset("Tall", ""), "a bar preset is saved");
            S.setThemePresetBar("night-drive", "Tall", "*");
            check(S.themePresets[0].bar?.preset === "Tall" && S.themePresets[0].bar.output === "*", "the theme preset names it");
            S.saveThemePreset({ id: "night-drive", name: "Night drive", theme: "nord", wallpapers: S.themePresets[0].wallpapers,
                                bar: S.themePresets[0].bar });
            check(S.themePresets[0].bar?.preset === "Tall", "Update keeps it");
            S.barHeight = 21;
            Services.Theme.applyPreset("night-drive");
            check(S.barHeight === 33, "applying the preset puts that bar back");
            check(!S.applyBarPresetTo("Nope", "*"), "an unknown bar preset is refused");
            // The stock bar is always there as a preset, and stays the stock bar.
            check(S.allBarPresets[0]?.name === S.defaultBarPresetName && S.allBarPresets[0].builtin,
                  "the stock bar is listed first as a built-in preset");
            check(!S.saveBarPreset(S.defaultBarPresetName, ""), "its name can't be saved over");
            S.deleteBarPreset(S.defaultBarPresetName);
            check(S.allBarPresets.some(b => b.name === S.defaultBarPresetName), "and it can't be deleted");
            S.barHeight = 21;
            S.barWidgetStyle = "polybar";
            check(S.applyBarPresetTo(S.defaultBarPresetName, "*"), "it applies like any preset");
            check(S.barHeight === S.defaultBarProfile.height && S.barWidgetStyle === S.defaultBarProfile.widgetStyle
                  && S.barRight.map(w => w.type).join() === S.defaultBarProfile.right.map(w => w.type).join(),
                  "and brings back the stock height, style and widgets");
            check(!S.barPresets.some(b => b.name === S.defaultBarPresetName), "without being saved to settings.json");
            S.setThemePresetBar("night-drive", "", "*");
            check(S.themePresets[0].bar === undefined, "and it can be cleared");

            // Old per-theme wallpapers become presets, once.
            Services.Settings.themeWallpapers = { nord: { "*": pics + "/a.png", "DP-9": pics + "/b.png" },
                dracula: "c.png", gone: "" };
            const before = Services.Settings.themePresets.length;
            check(Services.Settings.migrateThemeWallpapers({ dracula: "Dracula" }) === 1,
                  "one old link becomes a preset; the one a preset already holds is skipped");
            const made = Services.Settings.themePresets[before];
            check(made?.name === "Dracula" && made.theme === "dracula"
                  && made.wallpapers === Services.Settings.wallpaperDir + "/c.png",
                  "named after its theme, with the folder-relative path made absolute");
            check(Object.keys(Services.Settings.themeWallpapers).length === 0, "and the old links are dropped");
            check(Services.Settings.migrateThemeWallpapers({}) === 0, "a second run does nothing");
            console.warn(failures === 0 ? "RESULT: all theme-preset tests passed"
                                        : "RESULT: " + failures + " theme-preset test(s) FAILED");
            step = 6;
        }
    }

    Timer {
        interval: 50; repeat: true; running: true
        onTriggered: {
            if (!Services.Settings.ready) return;
            stop();
            setup.running = true;
        }
    }
    Timer {
        interval: 15000; running: true
        onTriggered: if (root.step < 6) console.warn("RESULT: theme-preset tests FAILED — timed out at step " + root.step)
    }
}
