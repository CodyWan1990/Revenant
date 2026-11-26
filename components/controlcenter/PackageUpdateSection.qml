import QtQuick
import QtQuick.Layouts
import "../../services" as Services
import ".." as Components

/// Package list and action shared by update providers.
Column {
    id: root

    property string icon: ""
    property string title: ""
    property int count: 0
    property var packages: []
    property var detailText: function(packageData) { return ""; }
    property int detailWidth: 220
    property string actionText: ""
    property color actionColor: Services.Colors.accent
    signal actionRequested()

    width: parent ? parent.width : 0
    spacing: 6

    RowLayout {
        width: parent.width
        Components.StyledText {
            text: root.icon + " " + root.title
            color: Services.Colors.foreground
            font.pixelSize: Services.Ui.textSubtitle
            font.bold: true
            Layout.fillWidth: true
        }
        Components.StyledText {
            text: root.count > 0 ? root.count + "" : "✅"
            color: root.count > 0 ? Services.Colors.foreground : Services.Colors.green
            font.pixelSize: Services.Ui.textBody
        }
    }

    ListView {
        width: parent.width
        height: Math.min(200, contentHeight)
        clip: true
        visible: root.count > 0
        model: root.packages

        delegate: Rectangle {
            required property var modelData
            required property int index
            width: ListView.view.width
            height: packageRow.implicitHeight + 6
            color: index % 2 === 0
                ? "transparent" : Services.Colors.withAlpha(Services.Colors.color8, 0.08)

            RowLayout {
                id: packageRow
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 4

                Components.StyledText {
                    text: modelData.name || ""
                    color: Services.Colors.foreground
                    font.pixelSize: Services.Ui.textBody
                    font.bold: true
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Components.StyledText {
                    text: root.detailText(modelData)
                    color: Services.Colors.color8
                    font.pixelSize: Services.Ui.textSmall
                    elide: Text.ElideRight
                    Layout.maximumWidth: root.detailWidth
                }
            }
        }
    }

    Components.TextButton {
        visible: root.count > 0
        text: root.actionText
        fontBold: true
        idleColor: root.actionColor
        hoverColor: Services.Colors.withAlpha(root.actionColor, 0.8)
        idleBorderColor: root.actionColor
        hoverBorderColor: root.actionColor
        idleTextColor: Services.Colors.background
        hoverTextColor: Services.Colors.background
        onClicked: root.actionRequested()
    }
}
