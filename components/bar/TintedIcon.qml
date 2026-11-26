import QtQuick
import QtQuick.Effects

/// An icon recoloured to one flat colour — for freedesktop "-symbolic" icons,
/// which themes ship in a fixed mid-grey that GTK recolours but Qt doesn't.
/// Needs qml6-module-qtquick-effects; SystemTray loads this through a Loader
/// and falls back to a plain Image when the module is missing.
Item {
    id: root
    property url source
    property int size: 20
    property color color: "white"

    Image {
        id: img
        anchors.fill: parent
        source: root.source
        sourceSize.width: root.size
        sourceSize.height: root.size
        visible: false
    }
    MultiEffect {
        anchors.fill: img
        source: img
        brightness: 1.0         // grey → white first, so colorization lands on the target hue
        colorization: 1.0
        colorizationColor: root.color
    }
}
