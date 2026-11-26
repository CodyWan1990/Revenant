import QtQuick
import Quickshell
import "../services" as Services
import "../components/bar" as BarUi

/// Main status bar — dynamically loads widgets from Settings arrays.
PanelWindow {  // qmllint disable uncreatable-type
    id: bar

    anchors.top: bar.profile.position === "top"
    anchors.bottom: bar.profile.position === "bottom"
    anchors.left: true
    anchors.right: true
    implicitHeight: bar.profile.height

    // i3 docks this window flush with the screen edge, and with no compositor
    // alpha renders as black — so no floating margins, radius or opacity here
    // (the settings still exist so nirishell's settings.json loads).
    color: Services.Colors.background

    // The monitor this bar was made for (shell.qml's Variants). Read the
    // profile from it, never from `screen`: while i3 moves the dock window, Qt
    // briefly places it on the wrong monitor, and with the two monitors' bars
    // on different edges that flipped the profile, which moved the window
    // back — a loop that flickered the bar between top and bottom.
    required property var modelData
    screen: modelData
    readonly property string outputName: modelData?.name ?? ""

    readonly property bool isPrimary: !Services.Settings.primaryBarOutput
        || outputName === Services.Settings.primaryBarOutput
    readonly property var profile: Services.Settings.barFor(outputName)
    readonly property color widgetSurfaceColor: Services.Colors.blend(
        Services.Colors.background, Services.Colors.foreground, profile.pillTint / 100)

    // ─── Font (driven by Settings) ───
    property string fontFamily: Services.Settings.fontFamily
    property var fontFamilies: [Services.Settings.fontFamily, "Noto Color Emoji"]
    property int fontSize: Services.Settings.fontSize
    property int smallFontSize: Math.max(1, bar.fontSize - 3)

    // ─── LEFT section ───
    BarUi.BarSection {
        id: leftSection
        anchors.left: parent.left
        anchors.leftMargin: bar.profile.padding
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        polybarSpacing: 4
        model: bar.profile.left
        hostBar: bar
    }

    // ─── CENTER section (pinned to absolute center) ───
    BarUi.BarSection {
        id: centerSection
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        polybarSpacing: 4
        model: bar.profile.center
        hostBar: bar
    }

    // ─── RIGHT section ───
    BarUi.BarSection {
        id: rightSection
        anchors.right: parent.right
        anchors.rightMargin: bar.profile.padding
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        polybarSpacing: 0
        model: bar.profile.right
        hostBar: bar
    }

    /// Widgets reach it as `bar.controlCenter` (Notifications).
    readonly property var controlCenter: controlCenterPanel

    ControlCenter {
        id: controlCenterPanel
        bar: bar
    }

    // Toasts drop under this bar, on the screen i3 has focused (or every bar
    // until the first i3 reply names one).
    NotificationToast {
        bar: bar
        isThisScreen: !Services.I3.focusedScreen || Services.I3.focusedScreen === bar.screen
    }

    // Volume / mic OSD, same screen rule as the toasts.
    OsdPopup {
        bar: bar
        isThisScreen: !Services.I3.focusedScreen || Services.I3.focusedScreen === bar.screen
    }
}
