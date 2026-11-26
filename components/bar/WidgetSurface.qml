import QtQuick
import "../../services" as Services

/// Rounded surface behind one bar widget in the Dux styles (pills /
/// segments). A segment's joined side is squared off by an extra rect, so a
/// run reads as one strip rounded only at its ends. Drawn inside the bar
/// window by Qt: no compositor needed.
Item {
    id: surface

    /// "solo" | "first" | "middle" | "last" (components/BarStyle.js)
    property string role: "solo"
    property int vInset: 4
    property int cornerRadius: Services.Settings.barPillRadius
    property color fill: Services.Colors.widgetSurface

    Rectangle {
        id: body
        anchors.fill: parent
        anchors.topMargin: surface.vInset
        anchors.bottomMargin: surface.vInset
        radius: Math.min(surface.cornerRadius, height / 2)
        color: surface.fill
    }

    // Square off the right side (joined to the next widget).
    Rectangle {
        visible: surface.role === "first" || surface.role === "middle"
        anchors.right: body.right
        anchors.top: body.top
        anchors.bottom: body.bottom
        width: body.radius
        color: surface.fill
    }
    // Square off the left side (joined to the previous widget).
    Rectangle {
        visible: surface.role === "middle" || surface.role === "last"
        anchors.left: body.left
        anchors.top: body.top
        anchors.bottom: body.bottom
        width: body.radius
        color: surface.fill
    }
}
