pragma Singleton

import QtQuick
import Quickshell.Networking
import "." as Services

/// Wi-Fi and Ethernet state and actions, shared by the bar's network widget
/// (the Control Center's components/NetworkSection.qml) and Settings → Network → Wi-Fi, so both behave
/// the same (Quickshell.Networking → NetworkManager over D-Bus).
///
/// Passwords are typed in panels/WifiPasswordPanel.qml (a keyboard panel).
/// A failed attempt on a secured network asks again, from here only, so two
/// open lists can't raise two prompts.
QtObject {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired) ?? null
    readonly property bool on: Networking.wifiEnabled
    readonly property bool hardwareEnabled: Networking.wifiHardwareEnabled
    readonly property var networks: wifi ? wifi.networks.values : []
    readonly property var current: networks.find(n => n.connected) ?? null

    /// Connected, then saved, then strongest first.
    readonly property var listed: networks.slice().sort((a, b) =>
        (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength))

    function setOn(value) { Networking.wifiEnabled = value; }

    function isOpen(net) {
        return net.security === WifiSecurityType.Open || net.security === WifiSecurityType.Owe;
    }

    /// Icons.qml key for a signal strength (0–1).
    function signalKey(strength) {
        return "wifi-" + Math.min(4, Math.floor((strength ?? 0) * 5));
    }
    function signalGlyph(strength) { return Services.Icons.glyph(signalKey(strength), "nerd"); }

    function status(net) {
        return net.stateChanging
                ? (net.state === ConnectionState.Disconnecting ? "Disconnecting…" : "Connecting…")
            : net.connected ? "Connected"
            : net.known ? "Saved" : Math.round(net.signalStrength * 100) + "%";
    }

    /// Saved and open networks connect directly; a new secured one asks for
    /// its password first.
    function connectTo(net) {
        if (net.known || isOpen(net)) net.connect();
        else Services.Actions.wifiPassword(net, "");
    }

    // ─── Scanning: on while any list is showing ───
    /// Each open list calls holdScan(true) on open and holdScan(false) on close.
    property int scanHolders: 0
    function holdScan(hold) { scanHolders = Math.max(0, scanHolders + (hold ? 1 : -1)); }
    readonly property Binding scanBinding: Binding {
        target: root.wifi
        when: !!root.wifi
        property: "scannerEnabled"
        value: root.scanHolders > 0 && root.on
    }

    // ─── A failed attempt on a secured network: ask (again) ───
    readonly property Instantiator failureWatch: Instantiator {
        model: root.networks
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectionFailed(reason) {
                if (root.isOpen(modelData)) return;
                Services.Actions.wifiPassword(modelData,
                    reason === ConnectionFailReason.NoSecrets ? "" : "Couldn't connect. Wrong password?");
            }
        }
    }
}
