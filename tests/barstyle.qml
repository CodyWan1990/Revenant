import QtQuick
import Quickshell
import "lib/BarStyle.js" as BarStyle

/// Regression test for components/BarStyle.js: which surface a widget gets
/// for each bar style / override, and the segment roles (runs, separators,
/// hidden widgets). Run with scripts/dev/run-qs-tests.sh.
ShellRoot {
    property int failures: 0
    function check(cond, what) {
        if (!cond) { console.warn("FAIL: " + what); failures++; }
        else console.warn("  ok: " + what);
    }
    function roles(surfaced, shown, joined) {
        return BarStyle.resolveRoles(surfaced, shown, joined).join(",");
    }

    Component.onCompleted: {
        console.warn("— effectiveSurface");
        check(BarStyle.effectiveSurface("polybar", "inherit") === "polybar", "polybar bar keeps polybar widgets");
        check(BarStyle.effectiveSurface("pills", "inherit") === "pill", "pills bar → pill");
        check(BarStyle.effectiveSurface("segments", "inherit") === "pill", "segments bar → pill");
        check(BarStyle.effectiveSurface("flat", "inherit") === "plain", "flat bar → plain");
        check(BarStyle.effectiveSurface("pills", "polybar") === "polybar", "a widget can stay polybar in a Dux bar");
        check(BarStyle.effectiveSurface("polybar", "pill") === "pill", "a widget can be a pill in a polybar bar");
        check(BarStyle.effectiveSurface("segments", "plain") === "plain", "plain override");
        check(BarStyle.effectiveSurface("pills", undefined) === "pill", "missing override = inherit");

        console.warn("— resolveRoles");
        const T = true, F = false;
        check(roles([T, T, T], [T, T, T], true) === "first,middle,last", "a run of three joins");
        check(roles([T, T], [T, T], true) === "first,last", "a run of two joins");
        check(roles([T, T, T], [T, T, T], false) === "solo,solo,solo", "pills style never joins");
        check(roles([T, F, T], [T, T, T], true) === "solo,solo,solo", "a separator breaks the run");
        check(roles([T, T, F, T, T], [T, T, T, T, T], true) === "first,last,solo,first,last",
              "two runs either side of a separator");
        check(roles([T, T, T], [T, F, T], true) === "first,solo,last",
              "a hidden widget is skipped without breaking the run");
        check(roles([T], [T], true) === "solo", "a single widget is solo");
        check(roles([], [], true) === "", "an empty section");
        check(roles([T, T], undefined, true) === "solo,solo", "nothing shown yet → all solo");

        console.warn("— isBreaker");
        check(BarStyle.isBreaker("separator") && BarStyle.isBreaker("spacer"), "separator and spacer break runs");
        check(!BarStyle.isBreaker("clock"), "a widget does not");

        console.warn(failures === 0 ? "RESULT: all bar-style tests passed"
                                    : "RESULT: " + failures + " bar-style test(s) FAILED");
    }
}
