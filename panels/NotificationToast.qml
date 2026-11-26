import QtQuick
import Quickshell
import "../services" as Services
import "../components" as Components

/// Toast-style notification popups — anchored to the bar's right edge, auto-dismiss.
/// One per bar (TopBar owns it); only the focused screen's shows. An X11
/// PopupWindow: override-redirect, so i3 never manages or focuses it — it takes
/// clicks but no keys, which is all a toast needs.
PopupWindow {
    id: toast

    required property var bar
    property bool isThisScreen: true

    anchor.window: bar
    anchor.rect.x: (bar?.width ?? 0) - implicitWidth - 10
    anchor.rect.y: bar?.profile.position === "bottom"
        ? -implicitHeight - 8 : (bar?.implicitHeight ?? 0) + 8
    implicitWidth: 400
    implicitHeight: Math.max(1, toastColumn.implicitHeight)
    // The window is opaque (no compositor), so it is exactly the cards' column
    // and the gaps between cards show the window colour — make that the border.
    color: Services.Colors.notifUnderline

    // popups, not notifications: those now outlive their toast, and keying the
    // window off them would leave this surface mapped until the user cleared.
    visible: isThisScreen
        && !Services.NotifManager.dndEnabled
        && Services.NotifManager.popups.length > 0

    Column {
        id: toastColumn
        width: parent.width
        anchors.top: parent.top
        spacing: 2

        Repeater {
            // Already capped at maxVisible and filtered to the unexpired, so
            // membership is the visibility test. An index gate here would mean
            // "the oldest few" now that notifications outlive their toast.
            model: Services.NotifManager.popups

            delegate: Rectangle {
                id: card
                required property var modelData

                width: toastColumn.width
                height: cardContent.implicitHeight + 24
                color: Services.Colors.background
                border.color: Services.Colors.notifUnderline
                border.width: 2

                // Slide-down + fade on arrival. (Repeater has no removal
                // transitions, so exit is instant — ponytail.)
                opacity: 0
                transform: Translate { id: slideIn; y: -12 }
                // Once per notification, not once per delegate: the model is
                // rebuilt whenever another arrives or expires, so an
                // unconditional start() would replay this on every toast.
                Component.onCompleted: {
                    if (Services.NotifManager.claimEntry(modelData?.id))
                        enterAnim.start();
                    else
                        opacity = 1;
                }
                ParallelAnimation {
                    id: enterAnim
                    NumberAnimation {
                        target: card; property: "opacity"
                        from: 0; to: 1
                        duration: Services.Ui.durOpen; easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: slideIn; property: "y"
                        from: -12; to: 0
                        duration: Services.Ui.durOpen; easing.type: Easing.OutCubic
                    }
                }

                // Click anywhere on the card (except the ✕ / action pills, which sit on top and
                // handle their own clicks) to invoke the default action, if the app supplied one.
                MouseArea {
                    anchors.fill: parent
                    enabled: cardContent.defaultAction !== null
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: cardContent.invokeDefault()
                }

                Components.NotificationContent {
                    id: cardContent
                    anchors.fill: parent
                    anchors.margins: 12
                    notif: card.modelData
                }
            }
        }
    }
}
