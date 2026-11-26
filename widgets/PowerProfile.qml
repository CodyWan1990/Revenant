import QtQuick
import QtQuick.Layouts
import Quickshell
import "../services" as Services
import "../components" as Components
import "../components/bar" as BarUi
import "../lib" as Lib

/// Power profile (power-profiles-daemon via powerprofilesctl), modelled on
/// Dux Shell's power-profile picker (MIT). Click: choose Performance /
/// Balanced / Power saver.
BarUi.BarWidget {
    id: root

    property string profile: ""
    readonly property var profiles: [
        { id: "performance", name: "Performance", hint: "Highest clocks, most power" },
        { id: "balanced", name: "Balanced", hint: "The default" },
        { id: "power-saver", name: "Power saver", hint: "Lower clocks, quieter fans" }
    ]
    readonly property var current: profiles.find(p => p.id === profile) ?? null

    function set(id) {
        Quickshell.execDetached(["powerprofilesctl", "set", id]);
        root.profile = id;               // optimistic; the next poll confirms
    }

    icon: "profile-" + (profile || "balanced")
    defaultAccent: Services.Colors.color5
    clickable: true
    onClicked: popup.isOpen ? popup.close() : popup.open()
    text: (instance.showName ?? false) && current ? current.name : ""
    // Hidden without power-profiles-daemon (the poll then says "unavailable").
    visible: profile !== "unavailable"

    Lib.PolledProcess {
        id: poll
        command: ["sh", "-c", "command -v powerprofilesctl >/dev/null && powerprofilesctl get || echo unavailable"]
        interval: 15000
        onOutput: text => root.profile = text.trim()
    }

    Components.WidgetPopup {
        id: popup
        bar: root.bar
        parentWidget: root
        contentWidth: 280
        accentColor: root.accent

        Column {
            width: parent.width
            spacing: 6

            Components.PopupHeader { width: parent.width; text: "Power profile"; separatorOpacity: 0.3 }

            Repeater {
                model: root.profiles
                delegate: Rectangle {
                    id: option
                    required property var modelData
                    readonly property bool selected: modelData.id === root.profile
                    width: parent.width
                    height: 46
                    radius: 12
                    color: selected ? Services.Colors.primaryContainer
                        : hover.containsMouse ? Services.Colors.surfaceContainer : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12
                        Components.StyledText {
                            textFormat: Text.RichText
                            text: Services.Icons.markup("profile-" + option.modelData.id,
                                root.instance.iconSet ?? "auto",
                                option.selected ? Services.Colors.primaryContainerText : root.accent)
                            font.pixelSize: Services.Ui.px(18)
                        }
                        Column {
                            Layout.fillWidth: true
                            Components.StyledText {
                                text: option.modelData.name
                                color: option.selected ? Services.Colors.primaryContainerText : Services.Colors.foreground
                                font.pixelSize: Services.Ui.textBodyLarge
                                font.bold: option.selected
                            }
                            Components.StyledText {
                                text: option.modelData.hint
                                color: Services.Colors.surfaceVariantText
                                font.pixelSize: Services.Ui.textCaption
                            }
                        }
                    }
                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.set(option.modelData.id)
                    }
                }
            }
        }
    }
}
