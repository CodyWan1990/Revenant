import QtQuick
import QtQuick.Layouts
import "../services" as Services
import "../components/bar" as BarUi

/// Standalone audio visualiser (Dux Shell's AudioVisualization, MIT). The
/// media widget has the same bars built in (its `visualizer` option); this is
/// for a bar without a media widget. Takes no space without cava or when
/// nothing plays.
Item {
    id: root

    property var bar: null
    property var instance: ({})
    readonly property color accent: Services.Colors.byKey(instance.color, Services.Colors.mprisUnderline)
    readonly property bool playing: (instance.alwaysOn ?? false)
        || (Services.Media.playingPlayer?.isPlaying ?? false)
    readonly property bool shown: Services.Cava.available && playing

    Layout.fillHeight: true
    implicitWidth: shown ? bars.implicitWidth + 6 : 0

    BarUi.BarItem {
        style: root.instance.style ?? "none"
        accentColor: root.accent

        BarUi.CavaBars {
            id: bars
            anchors.centerIn: parent
            active: root.shown
            visible: root.shown
            bars: Math.max(4, Math.min(32, root.instance.bars ?? 12))
            barWidth: root.instance.barWidth ?? 3
            maxHeight: (root.bar ? root.bar.implicitHeight : 30) - 12
            color: root.accent
        }
    }
}
