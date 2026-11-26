import QtQuick
import QtQuick.Layouts
import "../services" as Services
import "../components/bar" as BarUi

/// Control Center bar widget: one item for network, Bluetooth, notifications
/// and updates, each indicator switched on or off in its options. Left click
/// toggles this bar's Control Center (panels/ControlCenter.qml) on the section
/// in `openOn`; right click toggles Do Not Disturb.
Item {
    id: root

    property var bar: null
    property var instance: ({})
    readonly property color accent: Services.Colors.byKey(instance.color, Services.Colors.accent)
    readonly property string iconSet: instance.iconSet ?? "auto"
    readonly property color dim: Services.Colors.color8

    function icon(key, on) {
        return Services.Icons.markup(key, root.iconSet, on ? root.accent : root.dim);
    }

    readonly property string networkPart: {
        if (!(instance.showNetwork ?? true)) return "";
        const wifi = Services.Wifi, current = wifi.current;
        let key = current ? wifi.signalKey(current.signalStrength)
            : wifi.wired?.connected ? "ethernet" : !wifi.on ? "wifi-off" : "wifi-0";
        const on = !!current || !!wifi.wired?.connected;
        let out = icon(key, on);
        if ((instance.showNetworkName ?? false) && current)
            out += " " + Services.Fmt.escapeHtml(current.name);
        return out;
    }

    readonly property string bluetoothPart: {
        if (!(instance.showBluetooth ?? true) || !Services.Radio.adapter) return "";
        const on = Services.Radio.bluetoothOn, n = Services.Radio.connectedDevices.length;
        return icon(!on ? "bluetooth-off" : n ? "bluetooth-on" : "bluetooth", on);
    }

    readonly property string notificationsPart: {
        if (!(instance.showNotifications ?? true)) return "";
        const n = Services.NotifManager.history.length;
        const dnd = Services.NotifManager.dndEnabled;
        // Do Not Disturb: the bell greys out.
        return icon("notif", !dnd) + (n > 0 ? " " + n : "");
    }

    readonly property string updatesPart: {
        if (!(instance.showUpdates ?? true)) return "";
        const n = Services.Updates.totalCount;
        if (n === 0 && (instance.updatesOnlyWhenAvailable ?? true)) return "";
        return icon("updates", n > 0) + (n > 0 ? " " + n : "");
    }

    readonly property var parts: [networkPart, bluetoothPart, notificationsPart, updatesPart].filter(p => p)

    Layout.fillHeight: true
    implicitWidth: body.implicitWidth

    BarUi.BarText {
        id: body
        bar: root.bar
        style: root.instance.style ?? "underline"
        accent: root.accent
        clickable: true
        acceptRight: true
        onClicked: root.bar?.controlCenter?.toggleSection(root.instance.openOn ?? "last")
        onRightClicked: Services.NotifManager.dndEnabled = !Services.NotifManager.dndEnabled
        // Nothing switched on still leaves something to click.
        text: root.parts.length ? root.parts.join("&nbsp;&nbsp;&nbsp;") : root.icon("settings", true)
    }
}
