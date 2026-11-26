import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import "../services" as Services
import "../components" as Components
import "../components/controlcenter" as ControlCenterUi

/// Control Center: one per bar, pinned to the bar's right edge (WidgetPopup
/// with no widget). Opened by the Control Center widget and the notifications
/// widget, through openSection() / toggleSection().
///
///   quick toggles   Wi-Fi, Bluetooth, Do Not Disturb, Mute; the Wi-Fi and
///                   Bluetooth tiles' › open their section
///   volume, media
///   sections        Network · Bluetooth · Notifications · Updates, under
///                   headers; the Network / Bluetooth / Updates bodies are
///                   the same components the standalone widgets drop down
///
/// Mouse-only: X11 popups get no keyboard (see WidgetPopup).
Components.WidgetPopup {
    id: root

    parentWidget: null
    contentWidth: 420
    contentMargins: 0
    xClamp: 8
    accentColor: Services.Colors.accent
    // Cap at the screen minus the bar; the section body scrolls past that.
    contentHeight: Math.min((bar?.screen?.height ?? 1080) - (bar?.implicitHeight ?? 32) - 16,
        header.implicitHeight + sectionColumn.implicitHeight + 42)

    property string fontFamily: bar.fontFamily

    // ─── Sections ───
    readonly property var sections: [
        { id: "network", title: "Network", icon: "" },
        { id: "bluetooth", title: "Bluetooth", icon: "" },
        { id: "notifications", title: "Notifications", icon: "" },
        { id: "updates", title: "Updates", icon: "" }
    ]
    /// The section shown; kept between opens ("last" in the widget option).
    property string page: "notifications"

    /// Open on `name` ("last" or "" keeps the current section).
    function openSection(name) {
        if (name && name !== "last") page = name;
        if (!isOpen) open();
    }
    /// What a bar click does: close if it's open on that section, else show it.
    function toggleSection(name) {
        if (isOpen && (!name || name === "last" || name === page)) close();
        else openSection(name);
    }

    onPageChanged: body.contentY = 0

    // Scan / discover only while that section is on screen. The services count
    // holders, so each flag change is exactly one hold or release.
    readonly property bool scanningWifi: isOpen && page === "network"
    readonly property bool discoveringBt: isOpen && page === "bluetooth"
    onScanningWifiChanged: Services.Wifi.holdScan(scanningWifi)
    onDiscoveringBtChanged: Services.Radio.holdDiscovery(discoveringBt)
    // A bar can go away while this is open (monitor unplugged): release.
    Component.onDestruction: {
        if (scanningWifi) Services.Wifi.holdScan(false);
        if (discoveringBt) Services.Radio.holdDiscovery(false);
    }
    readonly property bool showingUpdates: isOpen && page === "updates"
    onShowingUpdatesChanged: if (showingUpdates && !Services.Updates.checking) Services.Updates.refresh()

    // ─── State ───
    readonly property bool dndEnabled: Services.NotifManager.dndEnabled
    readonly property int notificationCount: Services.NotifManager.history.length

    property var activePlayer: Services.Media.availablePlayer

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    property var sink: Pipewire.defaultAudioSink
    property real volume: sink?.audio?.volume ?? 0.5
    property bool muted: sink?.audio?.muted ?? false
    property int volumePercent: Math.round(volume * 100)

    readonly property var wifiCurrent: Services.Wifi.current
    readonly property var btConnected: Services.Radio.connectedDevices

    Item {
        width: root.contentWidth
        height: root.contentHeight

        Column {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 16
            spacing: 10

            RowLayout {
                width: parent.width
                spacing: 6

                Components.StyledText {
                    text: "Control Center"
                    font.pixelSize: Services.Ui.textTitle
                    font.bold: true
                    Layout.fillWidth: true
                }

                Components.TextButton {
                    text: "Settings"
                    onClicked: {
                        root.close();
                        Services.Actions.settings();
                    }
                }

                Components.TextButton {
                    text: "Power"
                    onClicked: {
                        root.close();
                        Services.Actions.powermenu();
                    }
                }
            }

            // ─── Quick toggles ───
            GridLayout {
                width: parent.width
                columns: 2
                columnSpacing: 8
                rowSpacing: 8

                ControlCenterUi.QuickToggle {
                    Layout.fillWidth: true
                    enabled: !!Services.Wifi.wifi
                    glyph: Services.Icons.glyph(!Services.Wifi.on ? "wifi-off"
                        : root.wifiCurrent ? Services.Wifi.signalKey(root.wifiCurrent.signalStrength) : "wifi-0", "nerd")
                    title: "Wi-Fi"
                    subtitle: !Services.Wifi.wifi ? (Services.Wifi.wired?.connected ? "No card · on Ethernet" : "No Wi-Fi card")
                        : !Services.Wifi.on ? "Off"
                        : root.wifiCurrent ? root.wifiCurrent.name : "Not connected"
                    active: Services.Wifi.on && !!Services.Wifi.wifi
                    accent: Services.Colors.color6
                    showMore: true
                    onToggled: Services.Wifi.setOn(!Services.Wifi.on)
                    onMoreClicked: root.page = "network"
                }

                ControlCenterUi.QuickToggle {
                    Layout.fillWidth: true
                    enabled: !!Services.Radio.adapter
                    glyph: Services.Icons.glyph(!Services.Radio.bluetoothOn ? "bluetooth-off"
                        : root.btConnected.length ? "bluetooth-on" : "bluetooth", "nerd")
                    title: "Bluetooth"
                    subtitle: !Services.Radio.adapter ? "No adapter"
                        : !Services.Radio.bluetoothOn ? "Off"
                        : root.btConnected.length === 1 ? (root.btConnected[0].name || root.btConnected[0].deviceName)
                        : root.btConnected.length > 1 ? root.btConnected.length + " devices" : "On"
                    active: Services.Radio.bluetoothOn
                    accent: Services.Colors.color4
                    showMore: true
                    onToggled: Services.Radio.setBluetooth(!Services.Radio.bluetoothOn)
                    onMoreClicked: root.page = "bluetooth"
                }

                ControlCenterUi.QuickToggle {
                    Layout.fillWidth: true
                    glyph: root.dndEnabled ? "" : ""
                    title: "Do Not Disturb"
                    subtitle: root.dndEnabled ? "Toasts silenced" : "Off"
                    active: root.dndEnabled
                    onToggled: Services.NotifManager.dndEnabled = !root.dndEnabled
                }

                ControlCenterUi.QuickToggle {
                    Layout.fillWidth: true
                    enabled: !!root.sink?.audio
                    glyph: Services.Icons.glyph(root.muted ? "vol-muted" : "vol-high", "nerd")
                    title: root.muted ? "Muted" : "Sound"
                    subtitle: !root.sink?.audio ? "No audio output"
                        : root.muted ? "Click to unmute" : root.volumePercent + "%"
                    active: root.muted
                    accent: Services.Colors.color1
                    onToggled: root.sink.audio.muted = !root.muted
                }
            }

            // ─── Volume ───
            Components.PopupSlider {
                width: parent.width
                enabled: !!root.sink?.audio
                value: root.volume
                muted: root.muted
                accentColor: Services.Colors.accent
                trackHeight: 12
                trackColor: Services.Colors.surfaceContainerHighest
                onMoved: value => { if (root.sink?.audio) root.sink.audio.volume = value; }
            }

            // ─── Media Player (MPRIS) ───
            Column {
                width: parent.width
                spacing: 6
                visible: root.activePlayer !== null

                Components.MediaTrackInfo {
                    width: parent.width
                    player: root.activePlayer
                }

                Components.MediaSeekBar {
                    width: parent.width
                    player: root.activePlayer
                    trackHeight: 4
                    trackColor: Services.Colors.color8
                    seekEnabled: false
                }

                Components.MediaTransportControls {
                    anchors.horizontalCenter: parent.horizontalCenter
                    player: root.activePlayer
                    spacing: 24
                    sideSize: 18
                    playSize: 22
                    accentColor: Services.Colors.accent
                    pointerCursor: false
                }
            }

            // ─── Section headers ───
            Components.SectionTabs {
                width: parent.width
                fill: true
                sections: root.sections
                current: root.page
                counts: ({ bluetooth: root.btConnected.length, notifications: root.notificationCount,
                           updates: Services.Updates.totalCount })
                onSelected: id => root.page = id
            }
        }

        // ─── The current section ───
        Flickable {
            id: body
            anchors.top: header.bottom
            anchors.topMargin: 10
            anchors.left: header.left
            anchors.right: header.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            contentHeight: sectionColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Column {
                id: sectionColumn
                width: body.width
                spacing: 10

                // ─── Section header line: title + its action ───
                RowLayout {
                    width: parent.width

                    Components.StyledText {
                        Layout.fillWidth: true
                        text: root.page === "network" ? (Services.Wifi.wired?.connected ? "Ethernet & Wi-Fi" : "Wi-Fi networks")
                            : root.page === "bluetooth" ? "Devices"
                            : root.page === "updates" ? (Services.Updates.checking || Services.Updates.totalCount === 0
                                ? "Updates" : Services.Updates.totalCount + (Services.Updates.totalCount === 1 ? " update available" : " updates available"))
                            : "Notifications"
                        font.pixelSize: Services.Ui.textSubtitle
                        font.bold: true
                    }

                    Components.TextButton {
                        visible: root.page === "bluetooth" && Services.Radio.bluetoothOn
                        text: Services.Radio.discovering ? "Stop" : "Scan"
                        buttonHeight: 26
                        onClicked: Services.Radio.setDiscovery(!Services.Radio.discovering)
                    }

                    Components.TextButton {
                        visible: root.page === "notifications" && root.notificationCount > 0
                        text: "Clear all"
                        buttonHeight: 26
                        onClicked: Services.NotifManager.dismissAll()
                    }
                }

                ControlCenterUi.NetworkSection {
                    visible: root.page === "network"
                    accent: Services.Colors.color6
                }

                ControlCenterUi.BluetoothSection {
                    visible: root.page === "bluetooth"
                    accent: Services.Colors.color4
                }

                ControlCenterUi.UpdatesSection {
                    visible: root.page === "updates"
                    onActionStarted: root.close()
                }

                ControlCenterUi.NotificationsSection {
                    visible: root.page === "notifications"
                    active: root.page === "notifications"
                }
            }
        }
    }
}
