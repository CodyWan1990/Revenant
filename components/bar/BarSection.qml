import QtQuick
import QtQuick.Layouts
import "../../services" as Services
import "../../lib/BarStyle.js" as BarStyle

/// Repeated dynamic-widget loader used by each TopBar section. It also applies
/// the bar's widget style (Settings.barWidgetStyle) to every widget centrally:
///   polybar  — as before: `polybarSpacing` apart, each widget's own BarItem
///              decoration, separators drawn as their glyph
///   pills    — a rounded WidgetSurface behind each widget, `barWidgetGap` apart
///   segments — neighbouring pills join into one strip (BarStyle.resolveRoles)
///   flat     — no surface, pill padding
/// A widget's `surface` field overrides the bar style for that widget.
RowLayout {
    id: root

    property var model: []
    property var hostBar: null
    /// Gap between widgets in the polybar style (what `spacing` used to be).
    property int polybarSpacing: 4

    readonly property var profile: hostBar?.profile ?? Services.Settings.sharedBar
    readonly property string widgetStyle: profile.widgetStyle
    readonly property bool duxStyle: widgetStyle !== "polybar"

    spacing: 0      // each cell adds its own leading gap (see cell.leadingGap)

    // Per-entry surface + on-screen state, feeding the segment roles.
    readonly property var surfaced: (model ?? []).map(e =>
        !BarStyle.isBreaker(e.type)
        && BarStyle.effectiveSurface(widgetStyle, e.surface ?? "inherit") === "pill")
    property var shownList: []
    readonly property var roles: BarStyle.resolveRoles(surfaced, shownList, widgetStyle === "segments")

    function setShown(i, v) {
        if (shownList[i] === v) return;
        const copy = shownList.slice();
        copy[i] = v;
        shownList = copy;
    }

    Repeater {
        model: root.model

        delegate: Item {
            id: cell
            required property var modelData
            required property int index

            readonly property string kind: BarStyle.effectiveSurface(root.widgetStyle,
                modelData.surface ?? "inherit")
            readonly property bool breaker: BarStyle.isBreaker(modelData.type)
            readonly property bool hasSurface: kind === "pill" && !breaker
            readonly property int pad: !breaker && (kind === "pill" || kind === "plain")
                ? root.profile.pillPadding : 0
            readonly property string role: root.roles[index] ?? "solo"

            // "Present" = the widget takes space. The cell itself is never hidden:
            // an invisible parent makes its child report invisible too, and
            // widgets that size themselves from their own `visible` (Wi-Fi,
            // notifications) would then stay at width 0 for good. Widgets that
            // hide themselves (Battery on a desktop, Bluetooth without an
            // adapter) already set implicitWidth 0, so width is the signal.
            readonly property real contentWidth: (loader.item as Item)?.implicitWidth ?? 0
            readonly property bool present: contentWidth > 0
            onPresentChanged: root.setShown(index, present)
            Component.onCompleted: root.setShown(index, present)

            readonly property int leadingGap: {
                if (index === 0 || !present || (root.duxStyle && modelData.type === "separator"))
                    return 0;
                if (!root.duxStyle) return root.polybarSpacing;
                return (role === "middle" || role === "last") ? 2 : root.profile.widgetGap;
            }

            Layout.fillHeight: true
            Layout.leftMargin: leadingGap
            Layout.preferredWidth: present ? contentWidth + 2 * pad : 0

            WidgetSurface {
                anchors.fill: parent
                visible: cell.hasSurface && cell.present
                role: cell.role
                cornerRadius: root.profile.pillRadius
                fill: root.hostBar?.widgetSurfaceColor ?? Services.Colors.widgetSurface
            }

            Loader {
                id: loader
                anchors.fill: parent
                anchors.leftMargin: cell.pad
                anchors.rightMargin: cell.pad
                // Every type is a file in widgets/ (services/WidgetCatalog.qml).
                source: Services.WidgetCatalog.url(cell.modelData.type)
                onLoaded: {
                    if (item && "bar" in item) item.bar = root.hostBar;
                    if (item && "instance" in item) item.instance = cell.modelData;
                }
            }
        }
    }
}
