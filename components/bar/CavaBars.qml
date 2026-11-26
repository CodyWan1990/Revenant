import QtQuick
import "../../services" as Services

/// A row of visualiser bars fed by the shared cava (services/Cava.qml).
/// Holds a cava reference only while `active` and visible, so cava runs
/// exactly while some bars are on screen and moving.
Row {
    id: root

    property bool active: true
    property int bars: 12
    property int barWidth: 3
    property real maxHeight: 20
    property color color: Services.Colors.mprisUnderline

    spacing: 2

    readonly property bool holding: active && visible && Services.Cava.available
    property bool held: false
    onHoldingChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: if (held) Services.Cava.release()
    function sync() {
        if (holding && !held) { Services.Cava.acquire(); held = true; }
        else if (!holding && held) { Services.Cava.release(); held = false; }
    }

    readonly property var values: Services.Cava.resample(bars)

    Repeater {
        model: root.bars
        Rectangle {
            required property int index
            readonly property real level: root.values[index] ?? 0
            width: root.barWidth
            height: Math.max(2, level * root.maxHeight)
            anchors.verticalCenter: parent.verticalCenter
            radius: width / 2
            color: root.color
            opacity: 0.5 + level * 0.5
            Behavior on height { NumberAnimation { duration: 60 } }
        }
    }
}
