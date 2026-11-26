import QtQuick
import "../services" as Services

/// Previous/play/next controls shared by MPRIS surfaces.
Row {
    id: root

    property var player: null
    property color accentColor: Services.Colors.color1
    property int sideSize: 28
    property int playSize: 34
    property bool pointerCursor: true
    property bool buttonSurfaces: false

    spacing: 28

    Repeater {
        model: [
            { icon: "previous", available: root.player?.canGoPrevious ?? false, invoke: () => root.player?.previous() },
            { icon: root.player?.isPlaying ? "pause" : "play", available: root.player?.canTogglePlaying ?? false,
              invoke: () => root.player?.togglePlaying() },
            { icon: "next", available: root.player?.canGoNext ?? false, invoke: () => root.player?.next() }
        ]

        delegate: Rectangle {
            id: button

            required property var modelData
            required property int index
            readonly property bool primary: index === 1
            readonly property bool available: modelData.available

            anchors.verticalCenter: parent.verticalCenter
            width: root.buttonSurfaces ? 42 : glyph.width + 2
            height: root.buttonSurfaces ? 42 : glyph.height + 4
            radius: root.buttonSurfaces ? Services.Ui.radiusMd : 0
            color: !root.buttonSurfaces || !available ? "transparent"
                : primary ? root.accentColor
                : mouse.containsMouse ? Services.Colors.surfaceContainerHighest : "transparent"
            opacity: available ? 1 : 0.45

            Canvas {
                id: glyph
                anchors.centerIn: parent
                width: button.primary ? root.playSize : root.sideSize
                height: width
                readonly property string icon: button.modelData.icon
                readonly property color ink: button.primary && button.available
                    ? (root.buttonSurfaces ? Services.Colors.background : root.accentColor)
                    : Services.Colors.foreground

                onIconChanged: requestPaint()
                onInkChanged: requestPaint()
                onWidthChanged: requestPaint()

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.clearRect(0, 0, width, height);
                    ctx.scale(width / 24, height / 24);
                    ctx.fillStyle = ink;

                    if (icon === "pause") {
                        ctx.fillRect(6, 5, 4, 14);
                        ctx.fillRect(14, 5, 4, 14);
                        return;
                    }
                    if (icon === "previous") {
                        ctx.translate(24, 0);
                        ctx.scale(-1, 1);
                    }
                    const skip = icon !== "play";
                    ctx.beginPath();
                    ctx.moveTo(skip ? 4 : 7, 5);
                    ctx.lineTo(skip ? 4 : 7, 19);
                    ctx.lineTo(skip ? 15 : 19, 12);
                    ctx.closePath();
                    ctx.fill();
                    if (skip)
                        ctx.fillRect(17, 5, 3, 14);
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                enabled: button.available
                hoverEnabled: root.buttonSurfaces
                cursorShape: root.pointerCursor ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: button.modelData.invoke()
            }
        }
    }
}
