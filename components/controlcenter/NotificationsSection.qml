import QtQuick
import "../../services" as Services
import ".." as Components

/// Notification history cards, newest first, shared by the notifications
/// widget's dropdown and the Control Center's Notifications section. Set
/// `active` false while hidden so the cards aren't built for nothing.
Column {
    id: root

    property bool active: true

    width: parent ? parent.width : 400
    spacing: 6

    Components.StyledText {
        text: "No notifications"
        color: Services.Colors.color8
        font.pixelSize: Services.Ui.textBody
        visible: Services.NotifManager.history.length === 0
    }

    Repeater {
        // history, not notifications: newest first, which only started
        // mattering once the list stopped self-emptying.
        model: root.active ? Services.NotifManager.history : []

        delegate: Rectangle {
            id: notifItem
            required property var modelData
            width: root.width
            height: notifContent.implicitHeight + 16
            radius: Services.Ui.radiusMd
            color: Services.Colors.surfaceContainerHigh
            border.color: Services.Colors.outlineVariant
            border.width: 1

            // Click the card (except ✕ / pills) to invoke the default action.
            MouseArea {
                anchors.fill: parent
                enabled: notifContent.defaultAction !== null
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: notifContent.invokeDefault()
            }

            Components.NotificationContent {
                id: notifContent
                anchors.fill: parent
                anchors.margins: 8
                notif: notifItem.modelData
                contentSpacing: 2
                summarySize: Services.Ui.textBodyLarge
                bodySize: Services.Ui.textBody
                bodyMaximumLines: 3
            }
        }
    }
}
