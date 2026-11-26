import QtQuick
import QtQuick.Layouts
import Quickshell
import "../services" as Services
import "../components" as Components
import "../components/bar" as BarUi

/// Running apps: an icon per open window (from i3's tree), click to focus.
/// Modelled on Dux Shell's RunningApps (MIT). Scope: the workspace this bar's
/// monitor shows (default), every window on this monitor, or all windows.
Item {
    id: root

    property var bar: null
    property var instance: ({})
    readonly property color accent: Services.Colors.byKey(instance.color, Services.Colors.accent)
    readonly property string scope: instance.scope ?? "workspace"
    readonly property int iconSize: instance.iconSize ?? 18

    readonly property string output: bar && bar.screen ? bar.screen.name : ""
    readonly property var visibleWs: Services.I3.workspaces.find(w => w.output === root.output && w.isActive) ?? null
    readonly property var outputWsIds: Services.I3.workspaces.filter(w => w.output === root.output).map(w => w.id)
    readonly property var focusedId: Services.I3.windows.length > 0 ? Services.I3.windows[0].id : -1

    /// In stable order (by con_id) so icons don't shuffle as focus moves.
    readonly property var apps: Services.I3.windows
        .filter(w => root.scope === "all"
            || (root.scope === "output" && root.outputWsIds.indexOf(w.workspaceId) >= 0)
            || (root.scope === "workspace" && root.visibleWs && w.workspaceId === root.visibleWs.id))
        .slice().sort((a, b) => a.id - b.id)

    function iconFor(appId) {
        const e = appId ? DesktopEntries.heuristicLookup(appId) : null;
        return e && e.icon ? Quickshell.iconPath(e.icon, true) : "";
    }

    Layout.fillHeight: true
    implicitWidth: apps.length > 0 ? row.implicitWidth + 4 : 0

    BarUi.BarItem {
        style: root.instance.style ?? "none"
        accentColor: root.accent

        Row {
            id: row
            anchors.centerIn: parent
            spacing: root.instance.spacing ?? 6

            Repeater {
                model: root.apps

                delegate: Item {
                    id: app
                    required property var modelData
                    readonly property bool focused: modelData.id === root.focusedId
                    readonly property string iconSrc: root.iconFor(modelData.appId)
                    width: root.iconSize + 8
                    height: root.bar ? root.bar.implicitHeight - 4 : 28

                    Image {
                        anchors.centerIn: parent
                        width: root.iconSize
                        height: root.iconSize
                        sourceSize: Qt.size(root.iconSize * 2, root.iconSize * 2)
                        source: app.iconSrc
                        visible: app.iconSrc !== ""
                        smooth: true
                        opacity: app.focused || hover.containsMouse ? 1 : 0.65
                    }
                    // No icon theme entry: the app's initial.
                    Components.StyledText {
                        anchors.centerIn: parent
                        visible: app.iconSrc === ""
                        text: (app.modelData.appId || app.modelData.title || "?").charAt(0).toUpperCase()
                        color: app.focused ? root.accent : Services.Colors.foreground
                        font.pixelSize: root.iconSize - 4
                        font.bold: true
                    }
                    // Focus marker under the focused window's icon.
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: app.focused ? root.iconSize : 4
                        height: 3
                        radius: 1.5
                        color: app.focused ? root.accent : Services.Colors.color8
                        Behavior on width { NumberAnimation { duration: Services.Ui.durOpen } }
                    }

                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Services.I3.focusWindow(app.modelData.id)
                    }
                }
            }
        }
    }
}
