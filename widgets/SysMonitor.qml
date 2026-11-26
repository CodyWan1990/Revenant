import QtQuick
import QtQuick.Layouts
import "../services" as Services
import "../components" as Components
import "../components/bar" as BarUi

/// System monitor: CPU, memory and GPU (with CPU and GPU temperatures) in one
/// widget, each part switchable in its options (WidgetCatalog "sysMonitor").
/// Each enabled part is a segment on the bar; any of them opens one popup
/// with a history graph per part, headline tiles and the details.
/// GPU: AMD cards through amdgpu's sysfs files (Services.SystemStats).
Item {
    id: root

    property var bar: null
    property var instance: ({})
    readonly property var s: Services.SystemStats
    readonly property color accent: Services.Colors.byKey(instance.color, Services.Colors.cpuUnderline)

    readonly property bool showCpu: instance.showCpu ?? true
    readonly property bool showCpuTemp: (instance.showTemp ?? true) && s.cpuTemp > 0
    readonly property bool showMemory: instance.showMemory ?? true
    readonly property bool showGpu: (instance.showGpu ?? true) && s.gpuAvailable
    readonly property bool showGpuTemp: (instance.showGpuTemp ?? true) && s.gpuTemp > 0

    function colored(color, text) { return "<font color='" + color + "'>" + text + "</font>"; }

    /// The bar's segments: [{ icon, short, text }] for the enabled parts.
    /// Each part's text is its switched-on pieces in a fixed order, unless
    /// its Custom text template is set.
    function compose(custom, values, pieces) {
        if ((custom ?? "").trim() !== "") return Services.Fmt.fill(custom, values);
        return pieces.filter(piece => piece[0]).map(piece => piece[1]).join(" ");
    }
    readonly property var segments: {
        const i = instance;
        const out = [];
        if (showCpu) {
            const values = { pct: colored(s.cpuColor, s.cpuPercent.toFixed(0) + "%"),
                temp: showCpuTemp ? colored(s.cpuTempColor, s.cpuTemp + "\u00B0C") : "",
                ghz: s.cpuFreqGhz, cores: s.cpuCores };
            out.push({ icon: "cpu", short: "CPU", text: compose(i.cpuCustom, values, [
                [i.cpuUsage ?? true, values.pct], [showCpuTemp, values.temp],
                [i.cpuClock ?? false, s.cpuFreqGhz + "GHz"]]) });
        }
        if (showMemory) {
            const values = { pct: colored(s.memColor, s.memPercent + "%"),
                used: s.memUsedGb, total: s.memTotalGb, free: s.memFreeGb };
            out.push({ icon: "memory", short: "RAM", text: compose(i.memCustom, values, [
                [i.memUsage ?? true, values.pct],
                [i.memUsed ?? false, s.memUsedGb + "/" + s.memTotalGb + "GB"]]) });
        }
        if (showGpu) {
            const values = { pct: colored(s.gpuColor, s.gpuPercent + "%"),
                temp: showGpuTemp ? colored(s.gpuTempColor, s.gpuTemp + "\u00B0C") : "",
                vram: s.gpuVramUsedGb.toFixed(1), vramTotal: s.gpuVramTotalGb.toFixed(0) };
            out.push({ icon: "gpu", short: "GPU", text: compose(i.gpuCustom, values, [
                [i.gpuUsage ?? true, values.pct], [showGpuTemp, values.temp],
                [i.gpuVram ?? false, values.vram + "/" + values.vramTotal + "GB"]]) });
        }
        return out.filter(segment => segment.text !== "");
    }
    readonly property string labelStyle: instance.labelStyle ?? "icon"
    function prefix(segment) {
        if (labelStyle === "none") return "";
        if (labelStyle === "text") return colored(accent, segment.short) + " ";
        return Services.Icons.prefix(segment.icon, instance.iconSet ?? "emoji", accent);
    }

    Layout.fillHeight: true
    implicitWidth: segments.length ? row.implicitWidth : 0
    visible: segments.length > 0

    BarUi.BarItem {
        style: root.instance.style ?? "underline"
        accentColor: root.accent

        RowLayout {
            id: row
            anchors.fill: parent
            spacing: 0

            Repeater {
                model: root.segments
                Item {
                    required property var modelData
                    Layout.fillHeight: true
                    Layout.preferredWidth: label.implicitWidth + 10
                    Layout.topMargin: 1
                    Layout.bottomMargin: 1

                    Text {
                        id: label
                        anchors.centerIn: parent
                        font.family: root.bar.fontFamily
                        font.pixelSize: root.bar.smallFontSize
                        font.weight: Font.Bold
                        textFormat: Text.RichText
                        color: Services.Colors.foreground
                        text: root.prefix(modelData) + modelData.text
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
        contentWidth: 400
        accentColor: root.accent
        alignLeft: true
        xClamp: 0

        Components.StatPopup {
            headerText: "System monitor"
            graphHeight: 80
            // CPU and GPU temperatures ride along as lines on their usage
            // graph: °C reads fine on a 0–100 scale.
            graphs: {
                const celsius = value => Math.round(value) + "°C";
                const out = [];
                if (root.showCpu) out.push({ values: root.s.cpuHistory, color: Services.Colors.cpuUnderline,
                    name: "CPU", values2: root.showCpuTemp ? root.s.tempHistory : [],
                    color2: Services.Colors.orange, name2: root.showCpuTemp ? "CPU temperature" : "", format2: celsius });
                if (root.showMemory) out.push({ values: root.s.memHistory, color: Services.Colors.memoryUnderline,
                    name: "Memory" });
                if (root.showGpu) out.push({ values: root.s.gpuHistory, color: Services.Colors.color4,
                    name: "GPU", values2: root.showGpuTemp ? root.s.gpuTempHistory : [],
                    color2: Services.Colors.red, name2: root.showGpuTemp ? "GPU temperature" : "", format2: celsius });
                return out;
            }
            tiles: {
                const out = [];
                if (root.showCpu) out.push({ value: root.colored(root.s.cpuColor, root.s.cpuPercent.toFixed(0) + "%"), label: "CPU" });
                if (root.showMemory) out.push({ value: root.colored(root.s.memColor, root.s.memPercent + "%"), label: "memory" });
                if (root.showGpu) out.push({ value: root.colored(root.s.gpuColor, root.s.gpuPercent + "%"), label: "GPU" });
                return out;
            }
            entries: {
                let out = [];
                if (root.showCpu) out = out.concat([
                    ["CPU", root.s.cpuModel],
                    ["Cores / clock", root.s.cpuCores + " / " + root.s.cpuFreqGhz + " GHz"]]);
                if (root.showCpuTemp) out.push(["CPU temp", root.colored(root.s.cpuTempColor, root.s.cpuTemp + "°C"), true]);
                if (root.showMemory) out.push(["Memory", root.s.memUsedGb + " / " + root.s.memTotalGb + " GB ("
                    + root.s.memFreeGb + " GB free)"]);
                if (root.showGpu) out.push(["VRAM", root.s.gpuVramUsedGb.toFixed(1) + " / "
                    + root.s.gpuVramTotalGb.toFixed(0) + " GB (" + root.s.gpuVramPercent + "%)"]);
                if (root.showGpuTemp) out.push(["GPU temp", root.colored(root.s.gpuTempColor, root.s.gpuTemp + "°C"), true]);
                return out;
            }

            Components.TextButton {
                text: "Task Manager"
                onClicked: { popup.close(); Services.Actions.processes(); }
            }
        }
    }
}
