import QtQuick
import QtQuick.Layouts
import "../services" as Services

/// History graph for the system-monitor popups: a filled line over faint
/// gridlines, newest sample at the right edge, with a legend underneath.
/// Up to two series (e.g. download and upload) share one scale.
///
///   values / color / name     the main series (filled)
///   values2 / color2 / name2  an optional second series (a line)
///   maxValue                  fixed top of the scale (100 for percentages);
///                             0 scales to the largest value shown
///   format(v)                 how values, the scale and peaks are written
///   capacity                  samples across the full width, so a short
///                             history starts at the right and grows left
///
/// Fill alpha is fine: it is drawn inside the window, not by the compositor.
ColumnLayout {
    id: root

    property var values: []
    property color color: Services.Colors.accent
    property string name: ""
    property var values2: []
    property color color2: Services.Colors.color5
    property string name2: ""
    property real maxValue: 100
    property var format: value => Math.round(value) + "%"
    /// The second series' own unit (e.g. °C over a % scale); defaults to format.
    property var format2: format
    property int capacity: Services.SystemStats.historyLength
    property int graphHeight: 110

    /// The scale actually drawn: fixed, or the largest value (min 1).
    readonly property real scaleMax: maxValue > 0 ? maxValue
        : Math.max(1, ...root.values, ...root.values2)
    readonly property int minutes: Math.round(capacity * Services.SystemStats.sampleMs / 60000)

    width: parent ? parent.width : 300
    spacing: 6

    onValuesChanged: canvas.requestPaint()
    onValues2Changed: canvas.requestPaint()
    onScaleMaxChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: root.graphHeight
        radius: Services.Ui.radiusSm
        color: Services.Ui.fieldColor

        Canvas {
            id: canvas
            anchors.fill: parent
            anchors.margins: 1
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            function trace(ctx, list, step, x0, y) {
                ctx.beginPath();
                ctx.moveTo(x0, y(list[0]));
                for (let i = 1; i < list.length; i++) ctx.lineTo(x0 + i * step, y(list[i]));
            }
            function series(ctx, list, stroke, fill) {
                if (list.length < 2) return;
                const step = width / Math.max(1, root.capacity - 1);
                const x0 = width - (list.length - 1) * step;
                const y = v => height - 2 - Math.max(0, Math.min(1, v / root.scaleMax)) * (height - 4);
                if (fill) {
                    trace(ctx, list, step, x0, y);
                    ctx.lineTo(width, height);
                    ctx.lineTo(x0, height);
                    ctx.closePath();
                    ctx.fillStyle = Qt.rgba(stroke.r, stroke.g, stroke.b, 0.22);
                    ctx.fill();
                }
                trace(ctx, list, step, x0, y);
                ctx.strokeStyle = stroke;
                ctx.lineWidth = 1.6;
                ctx.lineJoin = "round";
                ctx.stroke();
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const fg = Services.Colors.foreground;
                ctx.strokeStyle = Qt.rgba(fg.r, fg.g, fg.b, 0.08);
                ctx.lineWidth = 1;
                for (const f of [0.25, 0.5, 0.75]) {
                    const gy = Math.round(height * f) + 0.5;
                    ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(width, gy); ctx.stroke();
                }
                series(ctx, root.values, root.color, true);
                series(ctx, root.values2, root.color2, false);
            }
        }

        // Scale: the top gridline's value, and the time span.
        StyledText {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 6
            text: root.format(root.scaleMax)
            color: Services.Colors.surfaceVariantText
            font.pixelSize: Services.Ui.textMicro
        }
        StyledText {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 6
            text: "−" + root.minutes + " min"
            color: Services.Colors.surfaceVariantText
            font.pixelSize: Services.Ui.textMicro
        }
        StyledText {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 6
            text: "now"
            color: Services.Colors.surfaceVariantText
            font.pixelSize: Services.Ui.textMicro
        }
    }

    // Legend: swatch, name, current value, peak.
    Repeater {
        model: [
            { name: root.name, color: root.color, list: root.values, fmt: root.format },
            { name: root.name2, color: root.color2, list: root.values2, fmt: root.format2 }
        ].filter(entry => entry.name !== "")

        RowLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: 8
            Rectangle {
                Layout.preferredWidth: 12
                Layout.preferredHeight: 3
                radius: 1
                color: modelData.color
            }
            StyledText {
                Layout.fillWidth: true
                text: modelData.name
                color: Services.Colors.foreground
                font.pixelSize: Services.Ui.textSmall
            }
            StyledText {
                text: modelData.list.length ? modelData.fmt(modelData.list[modelData.list.length - 1]) : "–"
                color: Services.Colors.foreground
                font.pixelSize: Services.Ui.textSmall
                font.bold: true
            }
            StyledText {
                text: "peak " + (modelData.list.length ? modelData.fmt(Math.max(...modelData.list)) : "–")
                color: Services.Colors.surfaceVariantText
                font.pixelSize: Services.Ui.textCaption
            }
        }
    }
}
