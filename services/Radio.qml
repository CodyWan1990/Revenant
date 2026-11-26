pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import "." as Services

/// Radio power for the Bluetooth / Wi-Fi widgets and Settings ▸ Network &
/// Bluetooth, so both behave the same.
///
/// Bluetooth: a soft-blocked adapter (rfkill; GNOME used to manage this) can't
/// be powered until unblocked, so scripts/system/rfkill.py lifts the block first and
/// the adapter is enabled once BlueZ reports it unblocked.
/// Wi-Fi: NetworkManager sets/clears the rfkill block itself.
QtObject {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter  // qmllint disable unresolved-type
    readonly property bool bluetoothOn: adapter?.enabled ?? false
    readonly property bool bluetoothBlocked: adapter?.state === BluetoothAdapterState.Blocked
    readonly property bool wifiOn: Networking.wifiEnabled

    property bool powerOnAfterUnblock: false

    // ─── Bluetooth devices (shared by the bar widget and Settings → Bluetooth) ───
    readonly property var devices: adapter ? adapter.devices.values : []
    readonly property var connectedDevices: devices.filter(d => d.connected)
    readonly property bool discovering: adapter?.discovering ?? false

    /// Real names only: unnamed LE beacons report their address as the name.
    function named(d) {
        const n = d.name || d.deviceName || "";
        return n.length > 0 && n.replace(/[-:]/g, "").toUpperCase() !== d.address.replace(/:/g, "");
    }
    function deviceName(d) { return d.name || d.deviceName || d.address; }

    /// Connected, then paired, then (while scanning) newly found — each by name.
    readonly property var listedDevices: devices
        .filter(d => d.paired || d.connected || (discovering && named(d)))
        .slice()
        .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired)
            || (a.name || "").localeCompare(b.name || ""))

    function deviceBusy(d) {
        return d.pairing || d.state === BluetoothDeviceState.Connecting
            || d.state === BluetoothDeviceState.Disconnecting;
    }
    function deviceStatus(d) {
        return deviceBusy(d) ? (d.pairing ? "Pairing…" : "Working…")
            : d.connected ? "Connected" + (d.batteryAvailable ? " · " + Math.round(d.battery * 100) + "%" : "")
            : d.paired ? "Paired" : "Available";
    }

    /// Connect / disconnect, or pair a new device and connect once paired
    /// (and trust it, so it reconnects by itself next time).
    function toggleDevice(d) {
        if (d.connected) d.disconnect();
        else if (d.paired) d.connect();
        else {
            connectAfterPair = connectAfterPair.concat(d.address);
            d.pair();
        }
    }
    property var connectAfterPair: []
    readonly property Instantiator pairWatch: Instantiator {
        model: root.devices
        delegate: Connections {
            required property var modelData
            target: modelData
            function onPairedChanged() {
                if (!modelData.paired || !root.connectAfterPair.includes(modelData.address)) return;
                root.connectAfterPair = root.connectAfterPair.filter(a => a !== modelData.address);
                modelData.trusted = true;
                modelData.connect();
            }
        }
    }

    // Discovery drains power and floods the list: it runs only while a list
    // that asked for it is open, and stops when the last one closes.
    property int discoveryHolders: 0
    function setDiscovery(on) { if (adapter) adapter.discovering = on; }
    function holdDiscovery(hold) {
        discoveryHolders = Math.max(0, discoveryHolders + (hold ? 1 : -1));
        if (discoveryHolders === 0 && discovering) setDiscovery(false);
    }

    function setBluetooth(on) {
        if (!adapter) return;
        if (on && bluetoothBlocked) {
            powerOnAfterUnblock = true;
            Quickshell.execDetached(["python3", Services.Paths.script("system/rfkill.py"), "unblock", "bluetooth"]);
        } else {
            adapter.enabled = on;
        }
    }


    property Connections adapterWatch: Connections {
        target: root.adapter
        function onStateChanged() {
            if (root.powerOnAfterUnblock && !root.bluetoothBlocked) {
                root.powerOnAfterUnblock = false;
                root.adapter.enabled = true;
            }
        }
    }
}
