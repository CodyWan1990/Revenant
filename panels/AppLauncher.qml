import QtQuick
import Quickshell
import "../services" as Services
import "../components" as Components
import "launcher" as LV

Components.OverlayPanel {
    id: launcher

    onOpened: {
        appsView.reset();
        appSelectedIndex = 0;
    }
    onFocusRequested: appsView.focusView()

    readonly property string fontFamily: Services.Settings.fontFamily
    readonly property bool compact: Services.Settings.launcherMode === "compact"
    readonly property bool listResults: compact || Services.Settings.launcherResultsLayout === "list"

    // ─── Apps state ─── (filtered list lives in AppsView)
    // Reactive view over services/Apps.qml (Quickshell's desktop-entry index,
    // minus entries whose TryExec program is missing). Mapped to the legacy {name,comment,keywords,icon}
    // shape so AppsView (search filter + delegate) stays untouched; `entry` is kept
    // for launching. Updates live as apps are installed/removed.
    readonly property var allApps: Services.Apps.entries
        .map(e => ({ name: e.name, comment: e.comment,
                     keywords: (e.keywords || []).join(" "),
                     icon: e.icon, entry: e }))
        .sort((a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase()))
    property int appSelectedIndex: 0
    readonly property int appGridColumns: listResults ? 1 : Math.max(1, Math.floor(appsView.resultsWidth / 120))
    readonly property int appCellWidth: Math.floor(appsView.resultsWidth / appGridColumns)
    readonly property int appCellHeight: listResults
        ? Math.max(28, Math.min(64, Services.Settings.launcherListRowHeight)) : 110

    function launchApp(app, forceLaunch = false) {
        if (!app?.entry)
            return;
        const id = app.entry.id;
        const existing = !forceLaunch && Services.Settings.launcherAction === "focus" && id
            ? Services.I3.windows.find(window => window.appId
                && DesktopEntries.heuristicLookup(window.appId)?.id === id) : null;
        if (Services.Settings.launcherHistoryEnabled && id) {
            const recent = Services.Settings.launcherRecentApps;
            Services.Settings.launcherRecentApps = [id, ...recent.filter(item => item !== id)].slice(0, 20);
        }
        close();
        if (existing) Services.I3.focusWindow(existing.id);
        else app.entry.execute();
    }

    Components.OverlaySurface {
        anchors.centerIn: parent
        width: Math.min(launcher.compact ? 560 : launcher.listResults ? 680 : 860,
            (Services.I3.focusedScreen?.width ?? 1280) - 32)
        height: Math.min(launcher.compact ? 420 : launcher.listResults ? 580 : 650,
            (Services.I3.focusedScreen?.height ?? 900) - Services.Settings.barFor(Services.I3.focusedScreen?.name ?? "").height - 32)
        opacity: launcher.contentOpacity

        LV.AppsView {
            id: appsView
            anchors.fill: parent
            anchors.bottomMargin: 8
            launcher: launcher
        }
    }
}
