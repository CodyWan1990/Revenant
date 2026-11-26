import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../services" as Services
import "../../components" as Components

/// App launcher view — extracted from AppLauncher. The filtered list lives here
/// with its search input; raw data (allApps), selection, grid sizing and the
/// launchApp action stay on the `launcher` coordinator (bare `launcher.*` refs
/// resolve to the property below).
Column {
    id: root

    required property var launcher
    readonly property int sidePadding: 16
    readonly property real contentWidth: Math.max(0, launcher.listResults
        ? Math.min(width - 2 * sidePadding, 800) : width - 2 * sidePadding)

    readonly property real resultsWidth: appGrid.width
    readonly property var filtered: {
        const query = appSearchInput.text.trim();
        const apps = launcher.allApps;
        if (query !== "")
            return Services.Fuzzy.filter(apps, query,
                app => app.name + " " + (app.comment || "") + " " + (app.keywords || ""));
        if (!Services.Settings.launcherHistoryEnabled || !Services.Settings.launcherRecentApps.length)
            return apps;
        const ids = Services.Settings.launcherRecentApps;
        const recent = ids.map(id => apps.find(app => app.entry.id === id)).filter(Boolean);
        return recent.concat(apps.filter(app => !ids.includes(app.entry.id)));
    }
    onFilteredChanged: launcher.appSelectedIndex = 0
    topPadding: 12
    spacing: 12

    function focusView() { appSearchInput.forceActiveFocus(); }
    function reset() { appSearchInput.text = ""; }

    Components.SearchHeader {
        id: searchHeader
        x: (root.width - width) / 2
        width: root.contentWidth
        icon: Services.Icons.markup("apps", "auto", Services.Colors.accent)
        iconFormat: Text.RichText
        placeholder: "Search apps"
        showPlaceholder: appSearchInput.text.length === 0

        TextInput {
            id: appSearchInput
            anchors.fill: parent
            verticalAlignment: TextInput.AlignVCenter
            color: Services.Colors.foreground
            font.family: launcher.fontFamily
            font.pixelSize: Services.Ui.textTitle
            clip: true

            Keys.onEscapePressed: launcher.close()
            function activate(event) {
                launcher.launchApp(root.filtered[launcher.appSelectedIndex],
                    (event.modifiers & Qt.ControlModifier) !== 0);
            }

            Keys.onReturnPressed: event => activate(event)
            Keys.onEnterPressed: event => activate(event)
            function navApps(dir) {
                launcher.appSelectedIndex = Services.Ui.gridStep(launcher.appSelectedIndex,
                    root.filtered.length, launcher.appGridColumns, dir);
                appGrid.positionViewAtIndex(launcher.appSelectedIndex, GridView.Contain);
            }
            Keys.onUpPressed: navApps("up")
            Keys.onDownPressed: navApps("down")
            Keys.onLeftPressed: event => {
                if (launcher.listResults) event.accepted = false;
                else navApps("left");
            }
            Keys.onRightPressed: event => {
                if (launcher.listResults) event.accepted = false;
                else navApps("right");
            }
        }
    }

    Components.StyledText {
        x: (root.width - width) / 2
        width: root.contentWidth
        height: 48
        visible: root.filtered.length === 0
        text: "No matching apps"
        color: Services.Colors.surfaceVariantText
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    GridView {
        id: appGrid
        x: (root.width - width) / 2
        width: root.contentWidth
        height: Math.max(0, root.height - searchHeader.height - root.topPadding - root.spacing)
        visible: root.filtered.length > 0
        model: root.filtered
        clip: true
        currentIndex: launcher.appSelectedIndex
        cellWidth: launcher.appCellWidth
        cellHeight: launcher.appCellHeight
        boundsBehavior: Flickable.StopAtBounds

        delegate: Item {
            required property var modelData
            required property int index

            width: appGrid.cellWidth
            height: appGrid.cellHeight

            Rectangle {
                id: result
                readonly property bool selected: index === launcher.appSelectedIndex
                anchors.fill: parent
                anchors.margins: launcher.listResults ? 1 : 4
                radius: Services.Ui.radiusMd
                color: selected ? Services.Ui.menuSelectionColor
                    : appHover.containsMouse ? Services.Ui.menuHoverColor : "transparent"
                border.width: selected ? 1 : 0
                border.color: Services.Ui.subtleBorder

                GridLayout {
                    anchors.centerIn: parent
                    width: parent.width - (launcher.listResults ? 20 : 16)
                    columns: launcher.listResults ? 2 : 1
                    columnSpacing: 10
                    rowSpacing: 6

                    Item {
                        // List rows: the icon follows the row height, leaving ~8px
                        // above and below it.
                        readonly property int size: launcher.listResults
                            ? Math.max(16, Math.min(32, launcher.appCellHeight - 16)) : 48
                        Layout.preferredWidth: size
                        Layout.preferredHeight: size
                        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

                        Image {
                            id: appIcon
                            anchors.fill: parent
                            source: {
                                const icon = modelData.icon || "";
                                if (icon === "") return "";
                                if (icon.startsWith("/")) return "file://" + icon;
                                return Quickshell.iconPath(icon, true);
                            }
                            sourceSize.width: parent.size
                            sourceSize.height: parent.size
                            fillMode: Image.PreserveAspectFit
                            visible: status === Image.Ready
                        }

                        Components.StyledText {
                            anchors.centerIn: parent
                            text: modelData.name ? modelData.name.charAt(0).toUpperCase() : "?"
                            font.pixelSize: launcher.listResults ? Math.round(parent.size * 0.6) : 28
                            font.bold: true
                            color: result.selected
                                ? Services.Colors.primaryContainerText : Services.Colors.surfaceVariantText
                            visible: appIcon.status !== Image.Ready
                        }
                    }

                    Components.StyledText {
                        Layout.fillWidth: true
                        text: modelData.name
                        color: result.selected
                            ? Services.Colors.primaryContainerText : Services.Colors.foreground
                        font.pixelSize: launcher.listResults ? 14 : 13
                        font.bold: result.selected
                        horizontalAlignment: launcher.listResults ? Text.AlignLeft : Text.AlignHCenter
                        elide: Text.ElideRight
                        maximumLineCount: launcher.listResults ? 1 : 2
                        wrapMode: launcher.listResults ? Text.NoWrap : Text.Wrap
                    }
                }

                MouseArea {
                    id: appHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: if (containsMouse) launcher.appSelectedIndex = index
                    onClicked: {
                        launcher.appSelectedIndex = index;
                        launcher.launchApp(modelData);
                    }
                }
            }
        }
    }
}
