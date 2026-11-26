import QtQuick
import QtQuick.Layouts
import Quickshell
import "../services" as Services

/// Logout / Reboot / Shutdown button row shared by PowerMenu and ControlCenter.
/// Clicks perform the action directly unless `confirm` is set, which routes them
/// to `requested()` instead (PowerMenu's confirmation flow calls perform() later).
RowLayout {
    id: root

    property int buttonHeight: 40
    /// true = icon above label (PowerMenu); false = inline icon+label (ControlCenter).
    property bool showIcons: false
    /// Keyboard-selected button (-1 = hover-only highlight).
    property int selectedIndex: -1
    property bool confirm: false
    signal requested(string action, string label)
    signal hovered(int index)

    readonly property var actions: [
        { action: "logout",   label: "Logout",   icon: "", danger: false },
        { action: "reboot",   label: "Reboot",   icon: "", danger: false },
        { action: "shutdown", label: "Shutdown", icon: "", danger: true }
    ]

    // systemd's systemctl, else elogind's loginctl (OpenRC, runit, s6 systems).
    function power(verb) {
        Quickshell.execDetached(["sh", "-c",
            'if command -v systemctl >/dev/null; then exec systemctl "$1"; else exec loginctl "$1"; fi',
            "sh", verb]);
    }

    function perform(action) {
        if (action === "logout") Services.I3.quit();
        else if (action === "reboot") power("reboot");
        else if (action === "shutdown") power("poweroff");
    }

    spacing: 8

    Repeater {
        model: root.actions

        delegate: Rectangle {
            id: btn
            required property var modelData
            required property int index
            readonly property bool active: mouse.containsMouse || index === root.selectedIndex
            readonly property color accentCol: modelData.danger ? Services.Colors.red : Services.Colors.color1
            readonly property color fgCol: active
                ? (modelData.danger ? Services.Colors.foreground : Services.Colors.background)
                : (modelData.danger ? Services.Colors.red : Services.Colors.foreground)

            Layout.fillWidth: true
            Layout.preferredHeight: root.buttonHeight
            radius: Services.Ui.radiusSm
            color: active ? accentCol : Services.Colors.color0
            border.color: active ? accentCol : Services.Colors.color8
            border.width: 1

            Column {
                anchors.centerIn: parent
                spacing: 2

                StyledText {
                    visible: root.showIcons
                    text: btn.modelData.icon
                    font.pixelSize: Services.Ui.px(19)
                    color: btn.fgCol
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: root.showIcons ? btn.modelData.label
                                         : btn.modelData.icon + " " + btn.modelData.label
                    color: btn.fgCol
                    font.pixelSize: Services.Ui.textBodyLarge
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                onContainsMouseChanged: if (containsMouse) root.hovered(btn.index)
                onClicked: root.confirm
                    ? root.requested(btn.modelData.action, btn.modelData.label)
                    : root.perform(btn.modelData.action)
            }
        }
    }
}
