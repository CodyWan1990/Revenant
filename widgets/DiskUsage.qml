import QtQuick
import QtQuick.Layouts
import "../services" as Services
import "../components" as Components
import "../components/bar" as BarUi

/// Disks: one widget for any number of drives (Services.Disks). Each drive
/// picked in its options is a segment on the bar; any of them opens a popup
/// with every mounted drive. An older widget's single `path` still works.
Item {
    id: root

    property var bar: null
    property var instance: ({})
    readonly property color accent: Services.Colors.byKey(instance.color, Services.Colors.diskUnderline)

    /// The chosen mount points; `path` was the old single-drive option.
    // Array.from, not Array.isArray: a list inside the saved instance can
    // reach QML as a list-like object rather than a JS array.
    readonly property var targets: instance.mounts?.length !== undefined ? Array.from(instance.mounts)
        : [instance.path || "/"]
    readonly property var shown: targets.map(target => Services.Disks.byTarget(target)).filter(Boolean)
    readonly property string labelStyle: instance.labelStyle ?? "icon"

    function colored(color, text) { return "<font color='" + color + "'>" + text + "</font>"; }
    function percentColor(percent) {
        return Services.Colors.threshold(percent,
            instance.warnPct ?? 60, instance.highPct ?? 80, instance.critPct ?? 90);
    }

    /// A drive's bar text: its switched-on pieces, unless Custom text is set.
    function textFor(mount) {
        const d = Services.Disks;
        const values = {
            pct: colored(percentColor(mount.percent), mount.percent + "%"),
            used: d.gb(mount.used), total: d.gb(mount.size), free: d.gb(mount.avail), name: mount.name
        };
        // An older widget's `format` template is its Custom text until Custom
        // text is edited (the editor shows it there); "" then means switches.
        const custom = (instance.custom ?? instance.format ?? "").trim();
        if (custom !== "") return Services.Fmt.fill(custom, values);
        return [
            [instance.showPercent ?? true, values.pct],
            [instance.showUsed ?? false, d.human(mount.used) + "/" + d.human(mount.size)],
            [instance.showFree ?? false, d.human(mount.avail) + " free"]
        ].filter(piece => piece[0]).map(piece => piece[1]).join(" ");
    }
    function prefix(mount) {
        if (labelStyle === "none") return "";
        if (labelStyle === "name") return colored(accent, mount.name) + " ";
        return Services.Icons.prefix("disk", instance.iconSet ?? "auto", accent)
            + (shown.length > 1 ? colored(accent, mount.name) + " " : "");
    }

    Layout.fillHeight: true
    implicitWidth: shown.length ? row.implicitWidth : 0
    visible: shown.length > 0

    BarUi.BarItem {
        style: root.instance.style ?? "underline"
        accentColor: root.accent

        RowLayout {
            id: row
            anchors.fill: parent
            spacing: 0

            Repeater {
                model: root.shown
                Item {
                    required property var modelData
                    Layout.fillHeight: true
                    Layout.preferredWidth: label.implicitWidth + 10

                    Components.StyledText {
                        id: label
                        anchors.centerIn: parent
                        textFormat: Text.RichText
                        font.pixelSize: root.bar?.smallFontSize ?? Services.Settings.fontSize
                        text: root.prefix(modelData) + root.textFor(modelData)
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popup.isOpen ? popup.close() : popup.open()
                    }
                }
            }
        }
    }

    Components.WidgetPopup {
        id: popup
        bar: root.bar
        parentWidget: root
        contentWidth: 380
        accentColor: root.accent

        Column {
            width: parent.width
            spacing: 14

            Components.PopupHeader { width: parent.width; text: "Disks"; separatorOpacity: 0.3 }

            Repeater {
                model: Services.Disks.mounts
                Column {
                    id: drive
                    required property var modelData
                    readonly property bool onBar: root.targets.includes(modelData.target)
                    width: parent.width
                    spacing: 5

                    RowLayout {
                        width: parent.width
                        Components.StyledText {
                            Layout.fillWidth: true
                            text: drive.modelData.name + "  " + drive.modelData.target
                            color: Services.Colors.foreground
                            font.pixelSize: Services.Ui.textBody
                            font.bold: drive.onBar
                            elide: Text.ElideRight
                        }
                        Components.StyledText {
                            textFormat: Text.RichText
                            text: root.colored(root.percentColor(drive.modelData.percent), drive.modelData.percent + "%")
                            font.pixelSize: Services.Ui.textBody
                            font.bold: true
                        }
                    }
                    Components.ProgressBar {
                        value: drive.modelData.percent
                        fillColor: root.percentColor(drive.modelData.percent)
                    }
                    Components.StyledText {
                        width: parent.width
                        text: Services.Disks.human(drive.modelData.used) + " used of "
                            + Services.Disks.human(drive.modelData.size) + "  ·  "
                            + Services.Disks.human(drive.modelData.avail) + " free  ·  "
                            + drive.modelData.fstype + " on " + drive.modelData.source
                        color: Services.Colors.surfaceVariantText
                        font.pixelSize: Services.Ui.textCaption
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
