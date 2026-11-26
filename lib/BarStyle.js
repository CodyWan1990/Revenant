.pragma library
// Bar widget-style rules, kept as pure functions so tests/barstyle.qml can
// check them without a bar. Modelled on Dux Shell's DBar BarMetrics /
// SegmentRoles (MIT).

/// What surface a widget gets, from the bar-wide style and the widget's own
/// override:
///   "polybar" — no surface; the widget's own BarItem decoration (underline/box)
///   "pill"    — a rounded surface behind it (pills, segments)
///   "plain"   — no surface, but pill padding (flat)
function effectiveSurface(widgetStyle, override) {
    if (override === "polybar" || override === "pill" || override === "plain")
        return override;
    if (widgetStyle === "pills" || widgetStyle === "segments") return "pill";
    if (widgetStyle === "flat") return "plain";
    return "polybar";
}

/// Separators and spacers break a run of joined segments.
function isBreaker(type) {
    return type === "separator" || type === "spacer";
}

/// Segment role per entry: "solo" | "first" | "middle" | "last".
///   surfaced[i]  — entry i draws a pill surface (non-pill widgets break runs)
///   shown[i]     — entry i is on screen; hidden ones (e.g. Battery on a
///                  desktop) neither join nor break a run
///   joined       — false = every surfaced entry is "solo" (pills style)
/// Adjacent shown + surfaced entries form a run; a run of 2+ gets
/// first … middle … last, so only its outer ends are rounded.
function resolveRoles(surfaced, shown, joined) {
    const n = surfaced ? surfaced.length : 0;
    const roles = new Array(n).fill("solo");
    let run = [];
    const close = () => {
        if (joined && run.length > 1) {
            roles[run[0]] = "first";
            roles[run[run.length - 1]] = "last";
            for (let k = 1; k < run.length - 1; k++) roles[run[k]] = "middle";
        }
        run = [];
    };
    for (let i = 0; i < n; i++) {
        if (!shown || !shown[i]) continue;          // invisible: skip, keep the run
        if (surfaced[i]) run.push(i);
        else close();                               // separator / plain widget: break
    }
    close();
    return roles;
}
