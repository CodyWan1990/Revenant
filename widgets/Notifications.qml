import QtQuick
import QtQuick.Layouts
import "../services" as Services
import "../components" as Components
import "../components/bar" as BarUi
import "../components/controlcenter" as ControlCenterUi

/// Notification count. Click: a notifications-only dropdown (history, Clear
/// all, Do Not Disturb); the Control Center widget is the all-in-one.
/// Right click toggles Do Not Disturb.
Item {
    id: root

    property var bar: null
    property var instance: ({})
    readonly property color accent: Services.Colors.byKey(instance.color, Services.Colors.notifUnderline)
    readonly property int count: Services.NotifManager.history.length
    readonly property bool dnd: Services.NotifManager.dndEnabled

    Layout.fillHeight: true
    visible: !(instance.hideWhenZero ?? false) || count > 0
    implicitWidth: visible ? body.implicitWidth : 0

    BarUi.BarText {
        id: body
        bar: root.bar
        style: root.instance.style ?? "underline"
        accent: root.accent
        clickable: true
        acceptRight: true
        onClicked: popup.isOpen ? popup.close() : popup.open()
        onRightClicked: Services.NotifManager.dndEnabled = !root.dnd
        // Do Not Disturb: the bell greys out.
        text: String(Services.Icons.prefix("notif", root.instance.iconSet ?? "emoji",
                root.dnd ? Services.Colors.color8 : root.accent)
            + (root.count > 0 ? root.count : "")).replace(/\s+$/, "")
    }

    Components.WidgetPopup {
        id: popup
        bar: root.bar
        parentWidget: root
        contentWidth: 420
        accentColor: root.accent
        // Cap at the screen minus the bar; the list scrolls past that.
        contentHeight: Math.min((bar?.screen?.height ?? 1080) - (bar?.implicitHeight ?? 32) - 48,
            header.implicitHeight + list.implicitHeight + 42)

        Item {
            width: parent.width
            height: popup.contentHeight - 32

            RowLayout {
                id: header
                width: parent.width
                spacing: 6

                Components.StyledText {
                    text: "Notifications"
                    font.pixelSize: Services.Ui.textSubtitle
                    font.bold: true
                    Layout.fillWidth: true
                    Layout.minimumWidth: implicitWidth
                }
                // Highlighted while on.
                Components.TextButton {
                    text: (root.dnd ? "\uf1f6" : "\uf0f3") + "  Do Not Disturb"
                    buttonHeight: 26
                    idleColor: root.dnd ? Services.Colors.primaryContainer : Services.Colors.surfaceContainerHigh
                    idleBorderColor: root.dnd ? Services.Colors.accent : Services.Colors.outlineVariant
                    onClicked: Services.NotifManager.dndEnabled = !root.dnd
                }
                Components.TextButton {
                    visible: root.count > 0
                    text: "Clear all"
                    buttonHeight: 26
                    onClicked: Services.NotifManager.dismissAll()
                }
            }

            Flickable {
                anchors.top: header.bottom
                anchors.topMargin: 10
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                contentHeight: list.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                ControlCenterUi.NotificationsSection {
                    id: list
                    width: parent.width
                    active: popup.isOpen
                }
            }
        }
    }
}
