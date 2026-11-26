import QtQuick
import QtQuick.Layouts
import "../services" as Services
import "../components" as Components

/// Standalone Settings window: a category sidebar on the left and the page on
/// the right, in the shape of Dux Shell's settings modal (MIT). The sidebar is
/// data (services/SettingsTabs.qml); each page is a SettingsPage, so the
/// existing row cursor (KeyNavCursor) drives it.
///
/// Keyboard — two zones:
///   sidebar: Up/Down pick a page · Right/Enter/Tab go into it · type to search
///   page:    Up/Down rows · Left/Right adjust · Enter activates ·
///            Up past the first row, Ctrl+Left or Tab return to the sidebar
///   Esc closes from anywhere (clears the search first).
Components.OverlayPanel {
    id: win

    property string pageId: "bar_appearance"
    property bool showDefaultAppKeybinds: false
    readonly property var page: Services.SettingsTabs.pageById(pageId)
        ?? Services.SettingsTabs.pages[0]
    /// "sidebar" | "page"
    property string zone: "sidebar"

    /// The loaded page, when it implements the row-cursor contract.
    readonly property var loadedPage: pageLoader.item
    readonly property var pageItem: loadedPage && loadedPage.stepCursor !== undefined ? loadedPage : null
    closeOnFocusLoss: !((pageItem?.recordingShortcut ?? false)
        || (pageItem?.confirmingMonitorLayout ?? false))

    /// Sidebar rows after the search filter (categories kept only when one of
    /// their pages matches).
    readonly property var visibleRows: {
        const q = search.text.trim().toLowerCase();
        const rows = Services.SettingsTabs.rows;
        if (q === "") return rows;
        const hit = r => r.kind === "page" && (r.text.toLowerCase().includes(q)
            || (r.category ?? "").toLowerCase().includes(q));
        return rows.filter(r => hit(r)
            || (r.kind === "category" && rows.some(p => p.kind === "page" && p.category === r.text && hit(p))));
    }
    readonly property var visiblePages: visibleRows.filter(r => r.kind === "page")

    /// Open a page by id, or by an alias in SettingsTabs.aliases (a part of a
    /// page: "wallpapers" is the Wallpapers part of the theme page).
    property string pendingSection: ""
    function openPage(id) {
        const alias = Services.SettingsTabs.aliases[id];
        if (alias) {
            id = alias.page;
            pendingSection = alias.section;
        }
        const samePage = id === pageId;
        pageId = id;
        // Already loaded: the Loader won't fire onLoaded again.
        if (samePage && pendingSection && pageLoader.item && "section" in pageLoader.item) {
            pageLoader.item.section = pendingSection;
            pendingSection = "";
        }
        if (!isOpen) open();
    }

    function stepPage(delta) {
        const list = visiblePages;
        if (list.length === 0) return;
        const i = list.findIndex(p => p.id === win.page.id);
        const next = i < 0 ? 0 : Math.max(0, Math.min(list.length - 1, i + delta));
        pageId = list[next].id;
    }

    function enterPage() {
        if (!pageItem) return;
        zone = "page";
        pageItem.stepCursor(1);
    }

    function leavePage() {
        if (pageItem) pageItem.clearCursor();
        zone = "sidebar";
    }

    onOpened: { zone = "sidebar"; search.text = ""; }
    // The page stays loaded while the window is hidden; a page holding
    // something it must not keep showing (Connection details' "Show all")
    // gets told the window closed.
    onIsOpenChanged: if (!isOpen && typeof loadedPage?.windowClosed === "function") loadedPage.windowClosed()
    onFocusRequested: keys.forceActiveFocus()

    Components.OverlaySurface {
        id: surface
        anchors.centerIn: parent
        width: Math.min(1360, (Services.I3.focusedScreen?.width ?? 1920) - 32)
        // 90 % of the screen's height, but never over the bar.
        height: Math.min(Math.round((Services.I3.focusedScreen?.height ?? 1080) * 0.9),
            (Services.I3.focusedScreen?.height ?? 1080)
                - Services.Settings.barFor(Services.I3.focusedScreen?.name ?? "").height - 32)
        opacity: win.contentOpacity
        color: Services.Colors.background

        FocusScope {
            id: keys
            anchors.fill: parent
            focus: true

            Keys.onEscapePressed: {
                if (search.text !== "") search.text = "";
                else if (!win.pageItem?.closeDetail?.()) win.close();
            }
            Keys.onTabPressed: event => {
                event.accepted = true;
                if (win.zone === "sidebar") win.enterPage(); else win.leavePage();
            }
            Keys.onUpPressed: {
                if (win.zone === "sidebar") { win.stepPage(-1); return; }
                if (win.pageItem && !win.pageItem.stepCursor(-1)) win.leavePage();
            }
            Keys.onDownPressed: {
                if (win.zone === "sidebar") win.stepPage(1);
                else if (win.pageItem) win.pageItem.stepCursor(1);
            }
            Keys.onLeftPressed: event => {
                if (win.zone === "page" && !(event.modifiers & Qt.ControlModifier) && win.pageItem)
                    win.pageItem.adjust(-1);
                else
                    win.leavePage();
            }
            Keys.onRightPressed: {
                if (win.zone === "sidebar") win.enterPage();
                else if (win.pageItem) win.pageItem.adjust(1);
            }
            Keys.onReturnPressed: win.zone === "sidebar" ? win.enterPage() : win.pageItem?.activate()
            Keys.onEnterPressed: win.zone === "sidebar" ? win.enterPage() : win.pageItem?.activate()
            // Typing in the sidebar searches.
            // Only printable characters: Enter, Tab and Backspace also carry a
            // one-character text code and must reach their own handlers.
            Keys.onPressed: event => {
                if (win.zone !== "sidebar" || event.modifiers & Qt.ControlModifier) return;
                if (event.key === Qt.Key_Backspace && search.text !== "") {
                    search.text = search.text.slice(0, -1);
                    event.accepted = true;
                    return;
                }
                if (event.text.length !== 1 || event.text.charCodeAt(0) < 32) return;
                search.text += event.text;
                event.accepted = true;
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 2      // inside OverlaySurface's border
                spacing: 0

                // ─── Sidebar ───
                Rectangle {
                    Layout.preferredWidth: 250
                    Layout.fillHeight: true
                    color: Services.Ui.cardColor
                    radius: Services.Ui.radiusMd

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        Components.StyledText {
                            text: "Settings"
                            color: Services.Colors.foreground
                            font.pixelSize: Services.Ui.textHeading
                            font.bold: true
                            leftPadding: 6
                        }

                        // Search
                        Rectangle {
                            width: parent.width
                            height: 36
                            radius: Services.Ui.radiusMd
                            color: Services.Ui.fieldColor
                            border.color: search.activeFocus ? Services.Colors.accent : Services.Ui.subtleBorder
                            border.width: 1

                            Components.StyledText {
                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                text: ""
                                color: Services.Colors.color8
                                font.pixelSize: Services.Ui.textBody
                            }
                            TextInput {
                                id: search
                                anchors.fill: parent
                                anchors.leftMargin: 36
                                anchors.rightMargin: 12
                                verticalAlignment: TextInput.AlignVCenter
                                color: Services.Colors.foreground
                                font.family: Services.Settings.fontFamily
                                font.pixelSize: Services.Ui.textBody
                                clip: true
                                // The FocusScope types into it; clicks still focus it directly.
                                Keys.onEscapePressed: { text = ""; keys.forceActiveFocus(); }
                                Keys.onDownPressed: keys.forceActiveFocus()
                                Keys.onReturnPressed: { keys.forceActiveFocus(); win.enterPage(); }
                                onTextChanged: {
                                    const list = win.visiblePages;
                                    if (list.length > 0 && !list.some(p => p.id === win.pageId))
                                        win.pageId = list[0].id;
                                }
                            }
                            Components.StyledText {
                                anchors.left: search.left
                                anchors.verticalCenter: parent.verticalCenter
                                visible: search.text === ""
                                text: "Search settings"
                                color: Services.Colors.color8
                                font.pixelSize: Services.Ui.textBody
                            }
                        }

                        // Categories and pages
                        Flickable {
                            width: parent.width
                            height: parent.height - y
                            contentHeight: navColumn.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            Column {
                                id: navColumn
                                width: parent.width
                                spacing: 2

                                Repeater {
                                    model: win.visibleRows

                                    delegate: Item {
                                        id: navRow
                                        required property var modelData
                                        readonly property bool isPage: modelData.kind === "page"
                                        readonly property bool selected: isPage && modelData.id === win.page.id
                                        readonly property bool material: Services.Settings.iconSet === "material"

                                        width: navColumn.width
                                        height: modelData.kind === "separator" ? 13
                                            : modelData.kind === "category" ? 30 : 36

                                        Rectangle {
                                            visible: navRow.modelData.kind === "separator"
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: 8; width: parent.width - 16; height: 1
                                            color: Services.Colors.outlineVariant
                                        }

                                        Rectangle {
                                            visible: navRow.isPage
                                            anchors.fill: parent
                                            radius: Services.Ui.radiusMd
                                            color: navRow.selected
                                                ? (win.zone === "sidebar" ? Services.Ui.menuSelectionColor
                                                                          : Services.Ui.fieldColor)
                                                : navHover.containsMouse ? Services.Ui.menuHoverColor : "transparent"
                                        }

                                        Rectangle {
                                            visible: navRow.selected
                                            anchors.left: parent.left
                                            anchors.leftMargin: 3
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 2
                                            height: 16
                                            radius: Services.Ui.radiusSm > 0 ? 1 : 0
                                            color: Services.Colors.accent
                                        }

                                        Row {
                                            visible: navRow.modelData.kind !== "separator"
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: navRow.modelData.child ? 26 : 12
                                            spacing: 10

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 20
                                                horizontalAlignment: Text.AlignHCenter
                                                text: navRow.material ? Services.Icons.materialGlyph(navRow.modelData.material)
                                                                      : (navRow.modelData.nerd ?? "")
                                                font.family: navRow.material ? Services.Icons.materialFamily
                                                                             : Services.Settings.fontFamily
                                                font.pixelSize: navRow.material ? 18 : 15
                                                color: navRow.selected ? Services.Colors.primaryContainerText
                                                    : navRow.isPage ? Services.Colors.foreground : Services.Colors.surfaceVariantText
                                            }
                                            Components.StyledText {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: navRow.modelData.text ?? ""
                                                font.pixelSize: navRow.isPage ? 14 : 12
                                                font.bold: navRow.selected || !navRow.isPage
                                                color: navRow.selected ? Services.Colors.primaryContainerText
                                                    : navRow.isPage ? Services.Colors.foreground : Services.Colors.surfaceVariantText
                                            }
                                        }

                                        MouseArea {
                                            id: navHover
                                            anchors.fill: parent
                                            enabled: navRow.isPage
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                win.pageId = navRow.modelData.id;
                                                win.zone = "sidebar";
                                                keys.forceActiveFocus();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ─── Page ───
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    // Header: category ▸ page
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 72

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 1
                            anchors.leftMargin: 24
                            anchors.rightMargin: 24
                            height: 1
                            color: Services.Ui.subtleBorder
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 24
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Components.StyledText {
                                visible: (win.page?.category ?? "") !== ""
                                text: win.page?.category ?? ""
                                color: Services.Colors.surfaceVariantText
                                font.pixelSize: Services.Ui.textSmall
                            }
                            Components.StyledText {
                                text: win.page?.text ?? ""
                                color: Services.Colors.foreground
                                font.pixelSize: Services.Ui.px(22)
                                font.bold: true
                            }
                        }

                        Components.StyledText {
                            anchors.right: parent.right
                            anchors.rightMargin: 24
                            anchors.verticalCenter: parent.verticalCenter
                            text: win.zone === "sidebar" ? "→ / Enter to edit · type to search · Esc close"
                                                         : "↑↓ rows · ←→ adjust · Enter · Tab back"
                            color: Services.Colors.surfaceVariantText
                            font.pixelSize: Services.Ui.textCaption
                        }
                    }

                    Loader {
                        id: pageLoader
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        source: win.page ? win.page.source : ""
                        // A new page starts with no row cursor; the sidebar keeps focus.
                        onLoaded: {
                            win.zone = "sidebar";
                            if ("pageShown" in item) item.pageShown = Qt.binding(() => win.isOpen);
                            if (win.pendingSection && "section" in item) {
                                item.section = win.pendingSection;
                                win.pendingSection = "";
                            }
                            if (win.pageId === "keybinds" && win.showDefaultAppKeybinds) {
                                item.section = "Default Apps";
                                win.showDefaultAppKeybinds = false;
                            }
                        }
                    }

                    Connections {
                        target: win.pageId === "apps" ? pageLoader.item : null
                        ignoreUnknownSignals: true
                        function onKeybindsRequested() {
                            search.text = "";
                            win.showDefaultAppKeybinds = true;
                            win.openPage("keybinds");
                        }
                    }
                }
            }
        }
    }
}
