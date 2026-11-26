import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import "../services" as Services
import "../components" as Components
import "../components/bar" as BarUi

/// Privacy indicator, ported from Dux Shell's PrivacyService (MIT): a mic icon
/// while an app records audio (a PipeWire Stream/Input/Audio node that isn't
/// muted) and a camera icon while a live video capture runs. Takes no space
/// otherwise. Click: which apps.
///
/// Screen sharing isn't detectable here: on X11 apps capture the screen from
/// the X server directly, not through PipeWire.
Item {
    id: root

    property var bar: null
    property var instance: ({})

    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream)

    /// Visualisers, peak meters and monitor taps capture audio too; they are
    /// not "using the microphone" (same rule as Dux).
    function systemTap(n) {
        const p = n.properties ?? {};
        const s = ((n.name || "") + " " + (p["media.name"] || "") + " " + (p["application.name"] || "")).toLowerCase();
        return /cava|monitor|system|peak detect/.test(s);
    }
    function appName(n) {
        const p = n.properties ?? {};
        return p["application.name"] || p["application.process.binary"] || n.name || "Unknown";
    }

    readonly property var micUsers: streams.filter(n => (n.properties?.["media.class"] === "Stream/Input/Audio")
        && !systemTap(n) && !(n.audio && n.audio.muted))
    readonly property var camUsers: streams.filter(n => n.properties?.["media.class"] === "Stream/Input/Video"
        && n.properties?.["media.role"] !== "Screen")

    readonly property bool active: micUsers.length > 0 || camUsers.length > 0

    // Bound so properties / mute state stay live.
    PwObjectTracker { objects: root.streams }

    Layout.fillHeight: true
    implicitWidth: active ? body.implicitWidth : 0

    BarUi.BarText {
        id: body
        bar: root.bar
        style: root.instance.style ?? "none"
        accent: Services.Colors.orange
        clickable: true
        onClicked: popup.isOpen ? popup.close() : popup.open()
        text: {
            const set = root.instance.iconSet ?? "auto";
            let t = "";
            if (root.micUsers.length > 0) t += Services.Icons.markup("mic", set, Services.Colors.orange);
            if (root.camUsers.length > 0) t += (t ? " " : "") + Services.Icons.markup("camera", set, Services.Colors.green);
            return t;
        }
    }

    Components.WidgetPopup {
        id: popup
        bar: root.bar
        parentWidget: root
        contentWidth: 280
        accentColor: Services.Colors.orange

        Column {
            width: parent.width
            spacing: 6
            Components.PopupHeader { width: parent.width; text: "In use"; separatorOpacity: 0.3 }
            Repeater {
                model: root.micUsers.map(n => ["Microphone", root.appName(n)])
                    .concat(root.camUsers.map(n => ["Camera", root.appName(n)]))
                RowLayout {
                    required property var modelData
                    width: parent.width
                    Components.StyledText {
                        text: parent.modelData[1]
                        color: Services.Colors.foreground
                        font.pixelSize: Services.Ui.textBody
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    Components.StyledText {
                        text: parent.modelData[0]
                        color: parent.modelData[0] === "Camera" ? Services.Colors.green : Services.Colors.orange
                        font.pixelSize: Services.Ui.textSmall
                    }
                }
            }
        }
    }
}
