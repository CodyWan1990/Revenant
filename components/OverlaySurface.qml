import QtQuick
import "../services" as Services

/// Panel surface chrome. OverlayPanel sizes its X11 window to this item, so
/// give it a fixed width/height (not one derived from the window).
Rectangle {
    id: root

    default property alias content: contentItem.data
    property color accentColor: Services.Colors.accent
    readonly property bool isOverlaySurface: true

    radius: Services.Ui.radiusLg
    color: Services.Ui.panelColor
    border.color: Services.Ui.accentFrame ? accentColor : Services.Colors.outlineVariant
    border.width: Services.Ui.frameWidth
    clip: true

    // Consume clicks on the surface so they do not fall through to items behind it.
    MouseArea { anchors.fill: parent }

    Item {
        id: contentItem
        anchors.fill: parent
        anchors.margins: Math.floor(Services.Ui.radiusLg / 3)
    }
}
