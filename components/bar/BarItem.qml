import QtQuick
import "../../services" as Services
import "../../lib/BarStyle.js" as BarStyle

/// Styled bar-item wrapper with configurable decoration: style none|underline|box|pill.
/// That decoration is the polybar look. In the Dux widget styles
/// (Settings.barWidgetStyle pills/segments/flat) BarSection draws a surface
/// instead and this stays plain, unless the widget's own `surface` override
/// is "polybar".
Item {
    id: barItem
    anchors.fill: parent
    anchors.topMargin: 1
    anchors.bottomMargin: 1

    property string style: "underline"

    /// The widget instance this item decorates: the nearest ancestor with
    /// `instance` + `bar` (every bar widget root). Static once loaded.
    readonly property var hostWidget: findHost(parent)
    // `start: var`: ancestors are duck-typed (any widget root), not Items.
    function findHost(start: var): var {
        for (let p = start; p; p = p.parent)
            if (p.instance !== undefined && p.bar !== undefined) return p;
        return null;
    }
    /// The decoration actually drawn.
    readonly property string effectiveStyle:
        BarStyle.effectiveSurface(hostWidget?.bar?.profile?.widgetStyle ?? Services.Settings.barWidgetStyle,
            hostWidget?.instance?.surface ?? "inherit") === "polybar" ? style : "none"
    property color underlineColor: "transparent"
    property color accentColor: underlineColor

    default property alias contentData: contentArea.data

    Rectangle {
        anchors.fill: parent
        visible: barItem.effectiveStyle === "box" || barItem.effectiveStyle === "pill"
        radius: barItem.effectiveStyle === "pill" ? height / 2 : 4
        color: barItem.effectiveStyle === "pill"
            ? Qt.rgba(barItem.accentColor.r, barItem.accentColor.g, barItem.accentColor.b, 0.25)
            : "transparent"
        border.color: barItem.effectiveStyle === "box" ? barItem.accentColor : "transparent"
        border.width: barItem.effectiveStyle === "box" ? 1 : 0
    }

    Item {
        id: contentArea
        anchors.fill: parent
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 2
        color: barItem.accentColor
        visible: barItem.effectiveStyle === "underline"
    }
}
