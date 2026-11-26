import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import "../services" as Services
import "../components/bar" as BarUi

/// System tray — renders StatusNotifierItem icons; left-click activates, right-click opens the menu.
Item {
    id: root

    property var bar: null
    property var instance: ({})
    Layout.fillHeight: true
    implicitWidth: trayRow.implicitWidth
    // Counted from the model, not from the row's visible children: once this
    // widget hides, its children all read as invisible and it could never
    // come back. Reading each item's status here also re-runs the binding when
    // an item turns Active/NeedsAttention.
    readonly property int shownCount: {
        let n = 0, items = SystemTray.items.values ?? [];
        for (let i = 0; i < items.length; i++)
            if (root.showPassive || items[i].status !== Status.Passive) n++;
        return n;
    }
    visible: !(instance.hideWhenEmpty ?? true) || shownCount > 0
    /// SNI "Passive" = the app says nothing needs attention (GNOME/KDE hide these,
    /// e.g. Ubuntu's update-notifier). They reappear when they turn Active/NeedsAttention.
    readonly property bool showPassive: instance.showPassive ?? false

    readonly property int iconSize: instance.iconSize ?? 20

    BarUi.BarItem {
        style: root.instance.style ?? "underline"
        accentColor: Services.Colors.byKey(root.instance.color, Services.Colors.trayUnderline)

    RowLayout {
        id: trayRow
        anchors.fill: parent
        spacing: root.instance.itemSpacing ?? 4

        Repeater {
            model: SystemTray.items

            delegate: Item {
                required property var modelData
                readonly property bool isTrayIcon: true
                visible: root.showPassive || modelData.status !== Status.Passive
                Layout.fillHeight: true
                Layout.preferredWidth: root.iconSize + 8
                Layout.topMargin: 1
                Layout.bottomMargin: 1

                // Symbolic icons are tinted to the bar's text colour (polybar-ish
                // contrast); full-colour app icons are drawn as they are.
                readonly property bool symbolic: String(modelData.icon).indexOf("-symbolic") >= 0

                Loader {
                    id: tinted
                    anchors.centerIn: parent
                    width: root.iconSize
                    height: root.iconSize
                    active: parent.symbolic
                    source: "../components/bar/TintedIcon.qml"
                    onLoaded: {
                        item.source = Qt.binding(() => modelData.icon);
                        item.size = root.iconSize;
                        item.color = Qt.binding(() => Services.Colors.foreground);
                    }
                }

                Image {
                    id: trayIcon
                    anchors.centerIn: parent
                    width: root.iconSize
                    height: root.iconSize
                    // Plain icon unless the tinted copy loaded (module present).
                    visible: tinted.status !== Loader.Ready
                    source: modelData.icon
                    sourceSize.width: root.iconSize
                    sourceSize.height: root.iconSize
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onClicked: event => {
                        if (event.button === Qt.RightButton) {
                            if (modelData.hasMenu) {
                                let pos = mapToItem(null, event.x, event.y);
                                modelData.display(root.bar, pos.x, pos.y);
                            }
                        } else if (event.button === Qt.MiddleButton) {
                            modelData.secondaryActivate();
                        } else {
                            if (!modelData.onlyMenu) {
                                modelData.activate();
                            } else if (modelData.hasMenu) {
                                let pos = mapToItem(null, event.x, event.y);
                                modelData.display(root.bar, pos.x, pos.y);
                            }
                        }
                    }
                    onWheel: wheel => {
                        modelData.scroll(wheel.angleDelta.y, false);
                    }
                }
            }
        }
    }

    }
}
