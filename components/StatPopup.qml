import QtQuick
import QtQuick.Layouts
import "../services" as Services

/// Shared system-monitor popup: header, then the history graph with its
/// legend (when graphValues is set; otherwise a progress bar), then the two
/// headline stats as compact tiles, then the label/value rows in `entries`.
Column {
    id: sp

    property string headerText: ""
    property string leftValue: ""     // rich text — caller controls color
    property string leftLabel: ""
    property string rightValue: ""     // rich text
    property string rightLabel: ""
    property bool rightVisible: true
    property real progress: 0          // 0–100 (ProgressBar.value), when there is no graph
    property color progressColor: Services.Colors.foreground

    /// History graph (components/MiniGraph.qml). graphMax 0 scales to the
    /// data (rates); graphFormat writes values, the scale and peaks.
    property var graphValues: undefined
    property color graphColor: progressColor
    property string graphName: ""
    property var graphValues2: []
    property color graphColor2: Services.Colors.color5
    property string graphName2: ""
    property real graphMax: 100
    property var graphFormat: value => Math.round(value) + "%"
    property int graphHeight: 110
    /// Several graphs, stacked: a list of { values, color, name, values2,
    /// color2, name2, max, format, format2 } (only `values` is required).
    /// Defaults to the single graph described by the graph* properties.
    property var graphs: graphValues === undefined ? [] : [{
        values: graphValues, color: graphColor, name: graphName, values2: graphValues2,
        color2: graphColor2, name2: graphName2, max: graphMax, format: graphFormat
    }]
    /// Headline tiles: a list of { value (rich text), label }. Defaults to the
    /// left/right pair.
    property var tiles: [
        { value: leftValue, label: leftLabel, shown: true },
        { value: rightValue, label: rightLabel, shown: rightVisible }
    ].filter(tile => tile.shown && tile.value !== "")

    /// Detail rows, forwarded to StatRows — see there for the format.
    property var entries: []
    // Anything that isn't a plain label/value row is appended below.
    default property alias extra: extraHolder.data

    width: parent.width
    spacing: 12

    PopupHeader {
        text: sp.headerText
        separatorOpacity: 0.3
    }

    Repeater {
        model: sp.graphs
        MiniGraph {
            required property var modelData
            width: sp.width
            graphHeight: sp.graphHeight
            values: modelData.values ?? []
            color: modelData.color ?? Services.Colors.accent
            name: modelData.name ?? ""
            values2: modelData.values2 ?? []
            color2: modelData.color2 ?? Services.Colors.color5
            name2: modelData.name2 ?? ""
            maxValue: modelData.max ?? 100
            format: modelData.format ?? (value => Math.round(value) + "%")
            format2: modelData.format2 ?? format
        }
    }

    ProgressBar {
        visible: sp.graphs.length === 0
        value: sp.progress
        fillColor: sp.progressColor
    }

    // The headline stats as two tiles in the shell's field style.
    RowLayout {
        width: parent.width
        spacing: 8
        Repeater {
            model: sp.tiles
            Rectangle {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                radius: Services.Ui.radiusSm
                color: Services.Ui.fieldColor
                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    StyledText {
                        textFormat: Text.RichText
                        color: Services.Colors.foreground   // rich-text <font color> overrides this
                        font.pixelSize: Services.Ui.textHeading
                        font.bold: true
                        text: modelData.value
                    }
                    StyledText {
                        text: modelData.label
                        color: Services.Colors.surfaceVariantText
                        font.pixelSize: Services.Ui.textCaption
                    }
                }
            }
        }
    }

    StatRows {
        entries: sp.entries
        fontSize: Services.Ui.textSmall
    }

    Column {
        id: extraHolder
        width: parent.width
    }
}
