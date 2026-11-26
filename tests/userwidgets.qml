import QtQuick
import Quickshell
import Quickshell.Io
import "services" as Services

/// Regression test for the user's own widgets (<config>/widgets/<id>/):
/// services/WidgetCatalog.qml merges what scripts/system/user-widgets.py
/// lists, Settings.normalizeWidget() keeps a user widget's option keys even
/// before the folder has been read, a broken folder is reported, and saving a
/// widget's file gives it a new url() (live reload).
/// Run with scripts/dev/run-qs-tests.sh.
ShellRoot {
    id: root
    property int failures: 0
    function check(cond, what) {
        if (!cond) { console.warn("FAIL: " + what); failures++; }
        else console.warn("  ok: " + what);
    }
    readonly property var cat: Services.WidgetCatalog
    readonly property string dir: Services.Paths.configDir + "/widgets"
    property int step: 0
    property string firstUrl: ""

    function finish() {
        console.warn(failures === 0 ? "RESULT: all user-widget tests passed"
                                    : "RESULT: " + failures + " user-widget test(s) FAILED");
    }

    /// rescan: ask the catalog to look again once the script is done (a new
    /// folder); without it only the catalog's own file watchers can notice.
    property bool rescanAfter: true
    Process {
        id: sh
        onExited: if (root.rescanAfter) root.cat.rescanUser()
    }
    function write(script, rescan = true) {
        rescanAfter = rescan;
        sh.command = ["sh", "-c", script, "sh", root.dir];
        sh.running = true;
    }

    function start() {
        console.warn("— before the folder is read");
        const inst = Services.Settings.normalizeWidget({ type: "user:demo", greeting: "yo", id: "w1" });
        check(inst.greeting === "yo", "normalizeWidget keeps a user widget's own keys");
        check(inst.style !== undefined && inst.color === "auto", "and still fills the shared keys");
        check(cat.url("user:demo") === "", "unknown user type has no url yet");

        step = 1;
        write('mkdir -p "$1/demo" "$1/broken" && '
            + 'printf \'{"name":"Demo","icon":"help","about":"A test widget.","options":[{"key":"greeting","label":"G","type":"text","fallback":"hi"}]}\' > "$1/demo/widget.json" && '
            + 'printf "import QtQuick\\nItem {}\\n" > "$1/demo/Widget.qml" && '
            + 'printf "{" > "$1/broken/widget.json" && touch "$1/broken/Widget.qml"');
    }

    Connections {
        target: root.cat
        function onUserEntriesChanged() { Qt.callLater(root.advance); }
    }

    function advance() {
        if (step === 1 && cat.has("user:demo")) {
            console.warn("— after the scan");
            check(cat.types.includes("user:demo"), "listed among the types");
            check(cat.name("user:demo") === "Demo", "name from widget.json");
            check(cat.about("user:demo") === "A test widget.", "about from widget.json");
            check(cat.options("user:demo").length === 1 && cat.optionKeys.includes("greeting"), "options merged");
            firstUrl = cat.url("user:demo");
            check(firstUrl.startsWith("file://" + dir + "/demo/Widget.qml?v="), "url points at the user file");
            check(cat.userErrors.some(e => e.id === "broken"), "a broken folder is reported");
            check(cat.types.includes("clock"), "built-ins are still there");

            console.warn("— saving the widget");
            step = 2;
            // A different mtime for sure: mtime_ns, but some filesystems are coarse.
            // No rescan request: the catalog's FileView watcher must catch it.
            write('sleep 0.05; printf "import QtQuick\\nItem { width: 1 }\\n" > "$1/demo/Widget.qml"', false);
            watchdog.restart();
        } else if (step === 2 && cat.url("user:demo") !== firstUrl) {
            check(true, "its watcher notices an edit: new url (the Loader reloads it)");

            console.warn("— a folder made after the last scan");
            step = 3;
            // No rescan request: asking for its url (as the bar does) must be enough.
            write('mkdir -p "$1/late" && printf \'{"name":"Late"}\' > "$1/late/widget.json" && '
                + 'printf "import QtQuick\\nItem {}\\n" > "$1/late/Widget.qml"', false);
            lateProbe.start();
            watchdog.restart();
        } else if (step === 3 && cat.has("user:late")) {
            check(cat.url("user:late").indexOf("/late/Widget.qml?v=") > 0, "the bar asking for it makes the catalog find it");
            step = 4;
            finish();
        }
    }

    // Ask for the late widget's url until the files exist; the first ask
    // after they do must trigger the scan. Repeated asks inside 5 s must not.
    property int lateScans: 0
    Connections {
        target: root.cat.scanner
        function onSucceeded() { if (root.step === 3) root.lateScans++; }
    }
    Timer {
        id: lateProbe
        interval: 300
        repeat: true
        onTriggered: {
            if (root.step !== 3) { stop(); return; }
            root.cat.url("user:late");
        }
    }

    Timer {
        id: watchdog
        interval: 8000
        onTriggered: {
            if (root.step === 2) root.check(false, "an edit gives a new url");
            else if (root.step === 3) root.check(false, "a late folder is found when the bar asks (scans: " + root.lateScans + ")");
            else return;
            root.finish();
        }
    }

    Timer {
        interval: 50
        repeat: true
        running: true
        onTriggered: {
            if (!Services.Settings.ready || root.cat.scanner.running) return;
            stop();
            try { root.start(); }
            catch (error) { console.warn("RESULT: user-widget tests FAILED with " + error); }
        }
    }
}
