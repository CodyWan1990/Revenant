pragma Singleton

import QtQuick
import "." as Services

/// Shared UI tokens so panels and popups match — text sizes, radii, animation durations.
/// Radii scale from the user's Radius setting (12 → the classic 12/8/4 look).
QtObject {
    // ─── Text sizes for panels, popups and Settings (not the bar's text, which
    // follows Settings.fontSize). Each is scaled by Settings → Fonts → Panel
    // text size; at 100 % they are the shell's original pixel sizes.
    readonly property real textScale: Math.max(0.5, Services.Settings.panelTextScale / 100)
    /// A one-off size (big numbers, display text), scaled like the names below.
    function px(size) { return Math.round(size * textScale); }
    readonly property int textMicro: px(10)          // badges, tiny counts
    readonly property int textCaption: px(11)        // hints, key help, secondary lines
    readonly property int textSmall: px(12)          // descriptions, metadata
    readonly property int textBody: px(13)           // most text
    readonly property int textBodyLarge: px(14)      // list rows, emphasised body
    readonly property int textSubtitle: px(15)       // section headers, card titles
    readonly property int textSubtitleLarge: px(16)
    readonly property int textTitle: px(17)          // panel and popup titles
    readonly property int textHeading: px(20)        // page headings

    readonly property int radiusLg: Math.max(0, Math.min(24, Services.Settings.shellRadius))
    readonly property int radiusMd: Math.round(radiusLg * 2 / 3)
    readonly property int radiusSm: Math.round(radiusLg / 3)

    readonly property string surfaceStyle: Services.Settings.shellSurfaceStyle
    readonly property color panelColor: surfaceStyle === "tonal"
        ? Services.Colors.surfaceContainerLow : Services.Colors.background
    readonly property bool accentFrame: surfaceStyle !== "tonal" && surfaceStyle !== "flat"
    readonly property int frameWidth: surfaceStyle === "flat" ? 0 : accentFrame ? 2 : 1
    readonly property color cardColor: surfaceStyle === "flat" ? panelColor : Services.Colors.surfaceContainer

    readonly property color fieldColor: Services.Colors.surfaceContainerHigh
    readonly property color menuHoverColor: Services.Colors.surfaceContainerHighest
    readonly property color menuSelectionColor: Services.Colors.primaryContainer
    readonly property color menuSelectionText: Services.Colors.primaryContainerText
    readonly property color subtleBorder: Services.Colors.blend(panelColor, Services.Colors.foreground, 0.13)

    readonly property int durOpen: Services.Settings.shellAnimations ? 180 : 0
    readonly property int durClose: Services.Settings.shellAnimations ? 120 : 0

    /// The OverlayPanel currently holding exclusive keyboard focus, or null.
    /// Kept here rather than in the panels because it is one seat-wide fact:
    /// only one window has X keyboard focus, so a second panel opening has to
    /// take the first one down. OverlayPanel maintains it.
    property var exclusivePanel: null
    /// The WidgetPopup currently open, or null. Opening one (by click or by
    /// key, e.g. weather) closes the last.
    property var openPopup: null

    /// Clamp arrow-key navigation over a grid of `count` items in `cols`
    /// columns. dir: "left"|"right"|"up"|"down". Clamps rather than wraps, so
    /// holding a direction settles at an edge instead of jumping across.
    /// Shared by the launcher's three grids and the welcome screen.
    function gridStep(idx, count, cols, dir) {
        if (dir === "left")  return Math.max(0, idx - 1);
        if (dir === "right") return Math.min(count - 1, idx + 1);
        if (dir === "up")    return idx >= cols ? idx - cols : idx;
        return idx + cols < count ? idx + cols : idx;   // "down"
    }
}
