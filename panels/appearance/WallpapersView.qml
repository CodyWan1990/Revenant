import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import "../../services" as Services
import "../../components" as Components

/// Searchable wallpaper browser for the Settings page.
Column {
    id: root

    readonly property string fontFamily: Services.Settings.fontFamily
    /// The picked monitor's own folder, or the shared one.
    readonly property string wallpaperDir: Services.Wallpaper.dirFor(target)
    readonly property bool ownFolder: target !== "*" && !!Services.Settings.wallpaperDirs[target]
    property var allWallpapers: []
    FolderListModel {
        id: folderModel
        folder: Services.Settings.ready ? "file://" + root.wallpaperDir : ""
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp"]
        showDirs: false
        caseSensitive: false
        onFolderChanged: root.allWallpapers = []
        onStatusChanged: root.readFiles()
        onCountChanged: root.readFiles()
    }
    function readFiles() {
        if (folderModel.status !== FolderListModel.Ready) return;
        const out = [];
        for (let i = 0; i < folderModel.count; i++) out.push(folderModel.get(i, "fileName"));
        allWallpapers = out.sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase()));
    }
    property int wpSelectedIndex: 0
    /// The picture being applied, while it is.
    property string applying: ""
    readonly property string applyError: Services.Wallpaper.error
    /// Which monitor a click sets: "*" = all of them (and drops the
    /// per-monitor choices), otherwise an output name from Quickshell.screens.
    property string target: "*"
    readonly property var outputs: Services.Settings.barOutputs
    onOutputsChanged: if (target !== "*" && !outputs.includes(target)) target = "*"
    readonly property var current: Services.Wallpaper.current
    /// The image the picked target shows: its own, or the all-monitors one.
    readonly property string targetImage: target === "*" ? (current["*"] ?? "") : Services.Wallpaper.imageOn(target)

    function applyWallpaper(filename) {
        if (Services.Wallpaper.busy || !filename)
            return;
        applying = filename;
        Services.Wallpaper.set(wallpaperDir + "/" + filename, target);
    }
    Connections {
        target: Services.Wallpaper
        function onUpdated() { root.applying = ""; }
    }
    Component.onCompleted: Services.Wallpaper.refresh()

    readonly property var filtered: Services.Fuzzy.filter(root.allWallpapers,
        wpSearchInput.text, name => name)
    onFilteredChanged: root.wpSelectedIndex = 0


    // Which monitor a click sets; only worth showing with more than one.
    Components.SegmentedControl {
        id: targetRow
        width: parent.width
        height: visible ? 44 : 0
        visible: root.outputs.length > 1
        label: "Set it on"
        labelWidth: 70
        valueRole: "value"
        textRole: "text"
        model: [{ value: "*", text: "All monitors" }]
            .concat(root.outputs.map(name => ({ value: name, text: name + (root.current[name] ? " •" : "") })))
        currentValue: root.target
        onSelected: value => root.target = value
    }

    // The folder the grid lists: the shared one, or the picked monitor's own.
    Item {
        id: folderRow
        width: parent.width
        height: 44
        RowLayout {
            anchors.fill: parent
            anchors.bottomMargin: 8
            spacing: 8
            Components.StyledText {
                Layout.preferredWidth: 70
                text: "Folder"
                font.pixelSize: Services.Ui.textBodyLarge
            }
            Components.SettingField {
                id: folderField
                text: root.wallpaperDir
                placeholder: "~/Pictures/Wallpapers"
                // "~" is the home folder, as in a terminal.
                onEdited: value => Services.Settings.setWallpaperDir(root.target,
                    value.trim().replace(/^~(?=\/|$)/, Services.Paths.home).replace(/\/+$/, ""))
            }
            Components.TextButton {
                visible: root.ownFolder
                text: "Use the shared folder"
                onClicked: Services.Settings.setWallpaperDir(root.target, "")
            }
        }
    }

    Components.SearchHeader {
        icon: "\uf03e"
        placeholder: "Search wallpapers..."
        showPlaceholder: wpSearchInput.text.length === 0
        info: root.filtered.length + " wallpapers"
        border.color: Services.Colors.accent
        border.width: 1

        TextInput {
            id: wpSearchInput
            anchors.fill: parent
            verticalAlignment: TextInput.AlignVCenter
            color: Services.Colors.foreground
            font.family: root.fontFamily
            font.pixelSize: Services.Ui.textTitle
            clip: true

            Keys.onReturnPressed: {
                if (root.wpSelectedIndex >= 0 && root.wpSelectedIndex < root.filtered.length)
                    root.applyWallpaper(root.filtered[root.wpSelectedIndex]);
            }
            function navWp(dir) {
                let cols = Math.max(1, Math.floor(wallpaperGrid.width / wallpaperGrid.cellWidth));
                root.wpSelectedIndex = Services.Ui.gridStep(root.wpSelectedIndex,
                    root.filtered.length, cols, dir);
                wallpaperGrid.positionViewAtIndex(root.wpSelectedIndex, GridView.Contain);
            }
            Keys.onLeftPressed: navWp("left")
            Keys.onRightPressed: navWp("right")
            Keys.onUpPressed: navWp("up")
            Keys.onDownPressed: navWp("down")
        }
    }

    Rectangle { width: parent.width; height: 2; color: Services.Colors.accent }

    Rectangle {
        id: applyStatus
        width: parent.width
        height: visible ? 36 : 0
        color: Services.Colors.color0
        visible: root.applying !== "" || root.applyError !== ""
        clip: true

        Text {
            textFormat: Text.PlainText
            anchors.centerIn: parent
            text: root.applyError || "Applying " + root.applying + "…"
            color: Services.Colors.accent
            font.family: root.fontFamily
            font.pixelSize: Services.Ui.textBodyLarge
            font.italic: true
        }

        Behavior on height {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
    }

    // Distinguish an empty folder from a search with no matches.
    Components.StyledText {
        id: emptyState
        visible: root.filtered.length === 0
        x: 10
        width: parent.width - 20
        height: visible ? implicitHeight + 20 : 0
        topPadding: 14
        wrapMode: Text.WordWrap
        text: root.allWallpapers.length === 0
            ? "No pictures in " + root.wallpaperDir + " yet. Put .jpg or .png files there, or type another folder above."
            : "No wallpapers match that search."
        color: Services.Colors.color8
        font.pixelSize: Services.Ui.textBody
        font.italic: true
    }

    GridView {
        id: wallpaperGrid
        width: parent.width
        height: parent.height - 50 - targetRow.height - folderRow.height - emptyState.height
            - applyStatus.height
        cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 220)))
        cellHeight: 170
        clip: true
        model: root.filtered
        boundsBehavior: Flickable.StopAtBounds

        delegate: Item {
            required property string modelData
            required property int index
            width: wallpaperGrid.cellWidth
            height: wallpaperGrid.cellHeight

            Rectangle {
                id: thumbnail
                anchors.fill: parent
                anchors.margins: 6
                property bool active: wpThumbHover.containsMouse || index === root.wpSelectedIndex
                /// On the monitor the row above picks (or on all of them) now.
                readonly property bool inUse: root.targetImage.replace(/\/+/g, "/")
                    === (root.wallpaperDir + "/" + modelData).replace(/\/+/g, "/")
                color: active ? Services.Colors.accent : Services.Colors.color0
                border.color: (modelData === root.applying || inUse || active)
                    ? Services.Colors.accent : Services.Colors.color8
                border.width: (modelData === root.applying || inUse || active) ? 2 : 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 4

                    Image {
                        width: parent.width
                        height: parent.height - 24
                        source: "file://" + root.wallpaperDir + "/" + modelData
                        sourceSize.width: 300
                        sourceSize.height: 180
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true

                        Rectangle {
                            anchors.fill: parent
                            color: Services.Colors.color8
                            opacity: 0.3
                            visible: parent.status === Image.Loading
                        }
                    }

                    Text {
                        textFormat: Text.PlainText
                        width: parent.width
                        text: (thumbnail.inUse ? "✓ " : "") + modelData
                        color: thumbnail.active
                            ? Services.Colors.background
                            : Services.Colors.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Services.Ui.textSmall
                        elide: Text.ElideMiddle
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                MouseArea {
                    id: wpThumbHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.applyWallpaper(modelData)
                    onContainsMouseChanged: if (containsMouse) root.wpSelectedIndex = index
                }
            }
        }
    }
}
