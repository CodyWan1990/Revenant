//@ pragma UseQApplication
import QtQuick
import Quickshell
import "services" as Services
import "panels/settings/pages" as Pages

/// Regression test for BarWidgetsPage's widget reorder math.
///
/// Run with scripts/dev/run-qs-tests.sh, which stages this as the shell.qml of a
/// throwaway config next to copies of components/, services/ and panels/ —
/// same reason as navcursor.qml: Quickshell will not import a module from
/// outside its config folder.
///
/// It drives moveWidget() directly rather than synthesizing drags. The drag
/// plumbing is Qt's; what breaks silently is the index arithmetic and the
/// no-op guard, and the guard's whole point is an identity check a rendered
/// test could not see: reassigning the section array — even to equal content —
/// destroys and rebuilds every row delegate, including the MouseArea that is
/// mid-drop. That is what locked the tab up.
ShellRoot {
    id: root

    property int failures: 0
    function check(cond, what) {
        if (!cond) { console.warn("FAIL: " + what); failures++; }
        else console.warn("  ok: " + what);
    }

    function types(arr) { return arr.map(w => w.type).join(","); }

    Pages.BarWidgetsPage { id: tab; width: 600; height: 400 }

    Component.onCompleted: {
        let S = Services.Settings;
        // Fixed, known sections. Assigned via normalizeSection so every entry
        // carries the id moveWidget() locates by.
        function reset() {
            S.barLeft = S.normalizeSection(["clock", "menu", "workspaces"]);
            S.barCenter = S.normalizeSection(["audio"]);
            S.barRight = S.normalizeSection(["power", "notifications"]);
        }

        console.warn("— reorder within a section");
        reset();
        let before = S.barLeft;
        tab.moveWidget(S.barLeft[0].id, "left", 2);
        check(types(S.barLeft) === "menu,clock,workspaces",
            "moving down lands before the target row, not after (got "
            + types(S.barLeft) + ")");

        reset();
        tab.moveWidget(S.barLeft[2].id, "left", 0);
        check(types(S.barLeft) === "workspaces,clock,menu",
            "moving up needs no index adjustment (got " + types(S.barLeft) + ")");

        reset();
        tab.moveWidget(S.barLeft[0].id, "left", 3);
        check(types(S.barLeft) === "menu,workspaces,clock",
            "moving to the end target lands last (got " + types(S.barLeft) + ")");

        console.warn("— the no-op guard (a click on the drag handle)");
        reset();
        before = S.barLeft;
        tab.moveWidget(S.barLeft[1].id, "left", 1);
        check(S.barLeft === before,
            "dropping a row on itself does not reassign the array");
        before = S.barLeft;
        tab.moveWidget(S.barLeft[1].id, "left", 2);
        check(S.barLeft === before,
            "...nor does dropping it on the row below, which is the same slot");
        before = S.barLeft;
        tab.moveWidget(S.barLeft[2].id, "left", 3);
        check(S.barLeft === before,
            "...nor does dropping the last row on the end target");

        // The guard must not swallow a real move that happens to look adjacent.
        reset();
        tab.moveWidget(S.barLeft[0].id, "left", 2);
        check(types(S.barLeft) !== "clock,menu,workspaces",
            "the guard does not swallow a genuine one-slot move");

        console.warn("— across sections");
        reset();
        let movedId = S.barLeft[1].id;
        tab.moveWidget(movedId, "right", 1);
        check(types(S.barLeft) === "clock,workspaces",
            "source section loses it (got " + types(S.barLeft) + ")");
        check(types(S.barRight) === "power,menu,notifications",
            "target section gains it at the drop index (got " + types(S.barRight) + ")");

        reset();
        tab.moveWidget(S.barLeft[0].id, "center", 1);
        check(types(S.barCenter) === "audio,clock",
            "cross-section drop at the end target appends (got "
            + types(S.barCenter) + ")");

        reset();
        before = S.barCenter;
        tab.moveWidget(S.barCenter[0].id, "center", 0);
        check(S.barCenter === before,
            "a single-item section dropped on itself is still a no-op");

        console.warn("— bad input");
        reset();
        before = S.barLeft;
        tab.moveWidget("no-such-id", "left", 0);
        check(S.barLeft === before, "an unknown id changes nothing");

        console.warn(failures === 0
            ? "\nRESULT: all bar-reorder tests passed"
            : "\nRESULT: " + failures + " test(s) FAILED");
        Qt.quit();
    }
}
