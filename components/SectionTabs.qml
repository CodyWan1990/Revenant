import QtQuick
import QtQuick.Layouts
import "../services" as Services

/// A row of section headers: icon + title, with a count badge where there is
/// something to count. Used by the Control Center and the clipboard panel.
///
///   sections   [{ id, title, icon }]
///   current    the id shown as selected
///   counts     { id: number } — a badge for counts > 0
///   fill       true: tabs share the whole width (in proportion to their
///              content), and if the titles don't all fit only the current
///              one keeps its title. false: tabs take their natural width.
/// `selected(id)` fires on a click.
RowLayout {
    id: root

    property var sections: []
    property string current: ""
    property var counts: ({})
    property bool fill: false
    property int iconSize: Services.Ui.textBodyLarge
    property int titleSize: Services.Ui.textBody
    signal selected(string id)

    spacing: fill ? 4 : 6

    readonly property real fullWidth: {
        let sum = spacing * (sections.length - 1);
        for (const t of tabRepeater.itemsList) sum += t.fullContentWidth + 20;
        return sum;
    }
    readonly property bool compact: fill && fullWidth > width

    Repeater {
        id: tabRepeater
        model: root.sections
        readonly property var itemsList: {
            const out = [];
            for (let i = 0; i < count; i++) if (itemAt(i)) out.push(itemAt(i));
            return out;
        }

        Rectangle {
            id: tab
            required property var modelData
            readonly property bool isCurrent: root.current === modelData.id
            readonly property int count: root.counts[modelData.id] ?? 0
            readonly property bool showTitle: isCurrent || !root.compact
            readonly property real fullContentWidth: tabIcon.implicitWidth + 6
                + titleMetrics.advanceWidth + (count > 0 ? 6 + badge.width : 0)

            Layout.fillWidth: root.fill
            Layout.preferredWidth: tabContent.implicitWidth + (root.fill ? 20 : 24)
            Layout.minimumWidth: tabContent.implicitWidth + 12
            implicitHeight: 34
            radius: Services.Ui.radiusMd
            color: isCurrent ? Services.Colors.primaryContainer
                : tabArea.containsMouse ? Services.Colors.surfaceContainerHighest : "transparent"
            border.color: isCurrent ? Services.Colors.accent : Services.Colors.outlineVariant
            border.width: 1

            TextMetrics {
                id: titleMetrics
                font.family: Services.Settings.fontFamily
                font.pixelSize: root.titleSize
                font.bold: true
                text: tab.modelData.title
            }

            Row {
                id: tabContent
                anchors.centerIn: parent
                spacing: 6
                Text {
                    id: tabIcon
                    anchors.verticalCenter: parent.verticalCenter
                    text: tab.modelData.icon
                    color: tab.isCurrent ? Services.Colors.primaryContainerText : Services.Colors.accent
                    font.family: Services.Settings.fontFamily
                    font.pixelSize: root.iconSize
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: tab.showTitle
                    text: tab.modelData.title
                    color: tab.isCurrent ? Services.Colors.primaryContainerText : Services.Colors.foreground
                    font.family: Services.Settings.fontFamily
                    font.pixelSize: root.titleSize
                    font.bold: tab.isCurrent
                }
                Rectangle {
                    id: badge
                    anchors.verticalCenter: parent.verticalCenter
                    visible: tab.count > 0
                    width: Math.max(18, countText.implicitWidth + 8)
                    height: 18
                    radius: 9
                    color: tab.isCurrent ? Services.Colors.accent : Services.Colors.surfaceContainerHighest
                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: tab.count > 99 ? "99+" : tab.count
                        color: tab.isCurrent ? Services.Colors.background : Services.Colors.foreground
                        font.family: Services.Settings.fontFamily
                        font.pixelSize: Services.Ui.textMicro
                        font.bold: true
                    }
                }
            }

            MouseArea {
                id: tabArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selected(tab.modelData.id)
            }
        }
    }
}
