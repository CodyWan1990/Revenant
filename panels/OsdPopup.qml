import QtQuick
import QtQuick.Layouts
import Quickshell
import "../services" as Services
import "../components" as Components

/// Volume / mic OSD (services/Osd.qml), bottom-centre of the focused screen.
/// One per bar, like NotificationToast. An X11 PopupWindow: override-redirect,
/// so i3 never manages it and it can sit anywhere on the bar's screen; the
/// position is relative to the bar window.
PopupWindow {
    id: osd

    required property var bar
    property bool isThisScreen: true

    readonly property bool shown: isThisScreen && Services.Osd.active
    readonly property color accent: Services.Osd.muted
        ? Services.Colors.color8 : Services.Colors.pulseaudioUnderline

    implicitWidth: 320
    implicitHeight: 64
    anchor.window: bar
    anchor.rect.x: Math.round(((bar?.screen?.width ?? 0) - implicitWidth) / 2)
    anchor.rect.y: (bar?.profile.position === "bottom"
        ? bar.implicitHeight : (bar?.screen?.height ?? 0)) - implicitHeight - 120
    color: Services.Colors.background

    // Stay mapped through the fade-out; unmap once it has finished.
    visible: false
    onShownChanged: {
        if (shown) { fadeOut.stop(); visible = true; fadeIn.restart(); }
        else if (visible) fadeOut.restart();
    }

    NumberAnimation {
        id: fadeIn
        target: body; property: "opacity"; to: 1
        duration: Services.Ui.durOpen; easing.type: Easing.OutCubic
    }
    NumberAnimation {
        id: fadeOut
        target: body; property: "opacity"; to: 0
        duration: Services.Ui.durClose; easing.type: Easing.InCubic
        onFinished: if (!osd.shown) osd.visible = false
    }

    Rectangle {
        id: body
        anchors.fill: parent
        color: Services.Colors.background
        border.color: osd.accent
        border.width: 2
        opacity: 0

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            spacing: 14

            Components.StyledText {
                text: Services.Osd.icon
                color: osd.accent
                font.pixelSize: Services.Ui.px(26)
            }

            Components.StyledText {
                visible: Services.Osd.message !== ""
                Layout.fillWidth: true
                text: Services.Osd.message
                color: Services.Colors.foreground
                font.pixelSize: Services.Ui.textSubtitleLarge
                font.bold: true
            }

            Components.ProgressBar {
                visible: Services.Osd.message === ""
                Layout.fillWidth: true
                width: 0                          // RowLayout sizes it
                height: 8
                value: Services.Osd.muted ? 0 : Math.min(100, Services.Osd.value)
                fillColor: osd.accent
                trackColor: Services.Colors.color8
            }

            Components.StyledText {
                visible: Services.Osd.message === ""
                text: Services.Osd.muted ? "Muted" : Services.Osd.value + "%"
                color: Services.Colors.foreground
                font.pixelSize: Services.Ui.textSubtitleLarge
                font.bold: true
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 64
            }
        }
    }
}
