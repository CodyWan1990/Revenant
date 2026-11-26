import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../services" as Services
import "../components" as Components
import "../lib" as Lib

/// Task Manager (Ctrl+Shift+Escape; IPC `processes`): CPU, memory, GPU and
/// disk cards with live graphs (the same history as the bar popups), and a
/// process list to search, sort and end. Process list modelled on Dux Shell's
/// ProcessList (MIT).
///
/// Processes come from `top` every ~2 s while open (two frames 0.7 s apart:
/// live load, not ps's average since start). CPU is per core, as in top/htop.
/// Ending a process: "End task" sends SIGTERM (it may save and quit),
/// "Force kill" SIGKILL; each needs a second click (or the same key twice).
/// Only your own processes can be ended — nothing here runs as root — so
/// others' are dimmed, and a refusal is reported rather than lost.
///
/// Keyboard: type to filter · ↑↓ select · Tab next sort · Delete end ·
/// Shift+Delete kill · Esc close.
Components.OverlayPanel {
    id: panel

    // You may click elsewhere to look something up; Esc or ✕ closes it.
    closeOnFocusLoss: false

    readonly property string me: Quickshell.env("USER") ?? ""
    property var procs: []          // [{ pid, user, cpu, mem, rss, name }]
    property string sortBy: "cpu"   // "cpu" | "mem" | "pid" | "name" | "user"
    /// The selected process, by PID: it stays with that process when the
    /// list re-sorts on a refresh, and clears when the process exits.
    property int selectedPid: -1
    readonly property int selected: shown.findIndex(p => p.pid === selectedPid)
    /// Armed end/kill: { pid, name, sig } until confirmed or it times out.
    property var armed: null
    property string message: ""

    readonly property var sortKeys: ["cpu", "mem", "pid", "name", "user"]
    readonly property var shown: {
        const q = search.text.trim().toLowerCase();
        let list = q === "" ? procs
            : procs.filter(p => p.name.toLowerCase().includes(q) || String(p.pid).startsWith(q));
        const by = {
            cpu: (a, b) => b.cpu - a.cpu, mem: (a, b) => b.rss - a.rss, pid: (a, b) => a.pid - b.pid,
            name: (a, b) => a.name.localeCompare(b.name), user: (a, b) => a.user.localeCompare(b.user)
        }[sortBy];
        return list.slice().sort(by).slice(0, 300);
    }
    readonly property var current: selected >= 0 ? shown[selected] : null
    readonly property bool canEnd: !!current && current.user === me

    function fmtMem(kb) {
        return kb >= 1048576 ? (kb / 1048576).toFixed(1) + " GB"
            : kb >= 1024 ? Math.round(kb / 1024) + " MB" : kb + " KB";
    }
    function colored(color, text) { return "<font color='" + color + "'>" + text + "</font>"; }

    function move(d) {
        if (shown.length === 0) return;
        const at = Math.max(0, Math.min(shown.length - 1, (selected < 0 ? -1 : selected) + d));
        selectedPid = shown[at].pid;
        list.positionViewAtIndex(at, ListView.Contain);
    }

    // The rows are updated in place from `shown` rather than handing the
    // ListView a new array each refresh: a new model resets it to the top,
    // which threw you back up while scrolling.
    ListModel { id: rows }
    onShownChanged: {
        for (let i = 0; i < shown.length; i++) {
            const p = shown[i];
            const row = { pid: p.pid, user: p.user, cpu: p.cpu, rss: p.rss, name: p.name };
            if (i < rows.count) rows.set(i, row); else rows.append(row);
        }
        if (rows.count > shown.length) rows.remove(shown.length, rows.count - shown.length);
    }
    readonly property alias processView: list   // tests/taskmanager.qml

    /// First press arms, a second press of the same action on the same row
    /// sends the signal.
    function endSelected(sig) {
        const p = current;
        if (!p) return;
        if (p.user !== me) {
            message = p.name + " belongs to " + p.user + "; ending it needs administrator rights.";
            return;
        }
        if (armed && armed.pid === p.pid && armed.sig === sig) {
            killer.targets = Object.assign({}, killer.targets, { [p.pid]: p });
            killer.run(["kill", "-" + sig, String(p.pid)]);
            armed = null;
            return;
        }
        armed = { pid: p.pid, name: p.name, sig: sig };
        message = "";
        disarm.restart();
    }

    onOpened: { search.text = ""; selectedPid = -1; armed = null; message = ""; poll.running = true; }
    onFocusRequested: search.forceActiveFocus()
    onIsOpenChanged: if (!isOpen) poll.running = false

    Timer { id: disarm; interval: 3000; onTriggered: panel.armed = null }
    Timer { id: refresh; interval: 300; onTriggered: poll.running = true }

    // Every kill runs (two quick confirms don't drop one), and each result
    // names its own process: the pid → process map, not a shared `target`.
    Lib.QueuedProcess {
        id: killer
        keepAll: true
        property var targets: ({})
        stderr: StdioCollector { id: killError }
        onFinished: (code, argv) => {
            const pid = argv[2], target = targets[pid] ?? { name: "process", pid: pid };
            panel.message = code === 0 ? "Sent " + (argv[1] === "-KILL" ? "kill" : "end") + " to "
                    + target.name + " (" + target.pid + ")."
                : "Couldn't end " + target.name + ": " + (killError.text.trim().replace(/^.*kill: /, "") || "refused");
            const rest = Object.assign({}, targets);
            delete rest[pid];
            targets = rest;
            refresh.restart();
        }
    }

    Process {
        id: poll
        command: ["sh", "-c", "top -b -n 2 -d 0.7 -w 512 -e k | awk '/^ *PID/{n++; next} n==2'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of this.text.split("\n")) {
                    // PID USER PR NI VIRT RES SHR S %CPU %MEM TIME+ COMMAND (RES in KiB;
                    // a huge one may still carry an m/g/t suffix).
                    const f = line.trim().split(/\s+/);
                    if (f.length < 12 || !/^\d+$/.test(f[0])) continue;
                    const unit = { m: 1024, g: 1048576, t: 1073741824 }[f[5].slice(-1)] ?? 1;
                    out.push({ pid: +f[0], user: f[1], cpu: +f[8], mem: +f[9],
                               rss: Math.round(parseFloat(f[5]) * unit), name: f.slice(11).join(" ") });
                }
                panel.procs = out;
            }
        }
    }
    Timer { interval: 2000; repeat: true; running: panel.isOpen; onTriggered: poll.running = true }

    Components.OverlaySurface {
        anchors.centerIn: parent
        width: Math.min(1100, (Services.I3.focusedScreen?.width ?? 1920) - 64)
        height: Math.round((Services.I3.focusedScreen?.height ?? 1080) * 0.85)
        opacity: panel.contentOpacity

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            // ─── Header ───
            RowLayout {
                Layout.fillWidth: true
                Components.StyledText {
                    text: "Task Manager"
                    color: Services.Colors.foreground
                    font.pixelSize: Services.Ui.textHeading
                    font.bold: true
                    Layout.fillWidth: true
                }
                Components.StyledText {
                    text: panel.procs.length + " processes"
                    color: Services.Colors.surfaceVariantText
                    font.pixelSize: Services.Ui.textSmall
                }
                Components.TextButton {
                    text: "✕"
                    buttonHeight: 28
                    horizontalPadding: 10
                    onClicked: panel.close()
                }
            }

            // ─── Resources: CPU, memory, GPU, disks ───
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Repeater {
                    model: {
                        const s = Services.SystemStats;
                        const celsius = value => Math.round(value) + "°C";
                        const cards = [
                            { title: "CPU", value: panel.colored(s.cpuColor, s.cpuPercent.toFixed(0) + "%"),
                              detail: s.cpuCores + " cores · " + s.cpuFreqGhz + " GHz",
                              values: s.cpuHistory, color: Services.Colors.cpuUnderline,
                              values2: s.cpuTemp > 0 ? s.tempHistory : [], name2: s.cpuTemp > 0 ? "Temperature" : "",
                              color2: Services.Colors.orange, format2: celsius },
                            { title: "Memory", value: panel.colored(s.memColor, s.memPercent + "%"),
                              detail: s.memUsedGb + " of " + s.memTotalGb + " GB used",
                              values: s.memHistory, color: Services.Colors.memoryUnderline }
                        ];
                        if (s.gpuAvailable) cards.push({ title: "GPU", value: panel.colored(s.gpuColor, s.gpuPercent + "%"),
                            detail: "VRAM " + s.gpuVramUsedGb.toFixed(1) + " of " + s.gpuVramTotalGb.toFixed(0) + " GB",
                            values: s.gpuHistory, color: Services.Colors.color4,
                            values2: s.gpuTemp > 0 ? s.gpuTempHistory : [], name2: s.gpuTemp > 0 ? "Temperature" : "",
                            color2: Services.Colors.red, format2: celsius });
                        return cards;
                    }

                    Rectangle {
                        id: card
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: cardBody.implicitHeight + 24
                        Layout.alignment: Qt.AlignTop
                        radius: Services.Ui.radiusMd
                        color: Services.Ui.cardColor

                        ColumnLayout {
                            id: cardBody
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 6
                            RowLayout {
                                Layout.fillWidth: true
                                Components.StyledText {
                                    text: card.modelData.title
                                    color: Services.Colors.surfaceVariantText
                                    font.pixelSize: Services.Ui.textSmall
                                    font.bold: true
                                    Layout.fillWidth: true
                                }
                                Components.StyledText {
                                    textFormat: Text.RichText
                                    text: card.modelData.value
                                    font.pixelSize: Services.Ui.textHeading
                                    font.bold: true
                                }
                            }
                            Components.StyledText {
                                text: card.modelData.detail
                                color: Services.Colors.surfaceVariantText
                                font.pixelSize: Services.Ui.textCaption
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Components.MiniGraph {
                                Layout.fillWidth: true
                                graphHeight: 70
                                values: card.modelData.values
                                color: card.modelData.color
                                name: card.modelData.name2 ? "Usage" : ""
                                values2: card.modelData.values2 ?? []
                                color2: card.modelData.color2 ?? Services.Colors.color5
                                name2: card.modelData.name2 ?? ""
                                format2: card.modelData.format2 ?? format
                            }
                        }
                    }
                }

                // Disks: one bar per drive.
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: disksBody.implicitHeight + 24
                    Layout.alignment: Qt.AlignTop
                    radius: Services.Ui.radiusMd
                    color: Services.Ui.cardColor

                    ColumnLayout {
                        id: disksBody
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8
                        Components.StyledText {
                            text: "Disks"
                            color: Services.Colors.surfaceVariantText
                            font.pixelSize: Services.Ui.textSmall
                            font.bold: true
                        }
                        Repeater {
                            model: Services.Disks.mounts
                            ColumnLayout {
                                id: drive
                                required property var modelData
                                readonly property color tone: Services.Colors.threshold(modelData.percent, 60, 80, 90)
                                Layout.fillWidth: true
                                spacing: 3
                                RowLayout {
                                    Layout.fillWidth: true
                                    Components.StyledText {
                                        text: drive.modelData.name
                                        color: Services.Colors.foreground
                                        font.pixelSize: Services.Ui.textSmall
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                    Components.StyledText {
                                        text: Services.Disks.human(drive.modelData.used) + " / " + Services.Disks.human(drive.modelData.size)
                                        color: Services.Colors.surfaceVariantText
                                        font.pixelSize: Services.Ui.textCaption
                                    }
                                }
                                Components.ProgressBar {
                                    Layout.fillWidth: true
                                    value: drive.modelData.percent
                                    fillColor: drive.tone
                                }
                            }
                        }
                    }
                }
            }

            // ─── Search ───
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: Services.Ui.radiusMd
                color: Services.Ui.fieldColor

                TextInput {
                    id: search
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter
                    color: Services.Colors.foreground
                    font.family: Services.Settings.fontFamily
                    font.pixelSize: Services.Ui.textBodyLarge
                    clip: true
                    onTextChanged: panel.selectedPid = panel.shown[0]?.pid ?? -1

                    Keys.onEscapePressed: panel.close()
                    Keys.onUpPressed: panel.move(-1)
                    Keys.onDownPressed: panel.move(1)
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_PageDown) { panel.move(10); event.accepted = true; }
                        else if (event.key === Qt.Key_PageUp) { panel.move(-10); event.accepted = true; }
                        else if (event.key === Qt.Key_Delete) {
                            panel.endSelected(event.modifiers & Qt.ShiftModifier ? "KILL" : "TERM");
                            event.accepted = true;
                        }
                    }
                    Keys.onTabPressed: event => {
                        event.accepted = true;
                        panel.sortBy = panel.sortKeys[(panel.sortKeys.indexOf(panel.sortBy) + 1) % panel.sortKeys.length];
                    }
                }
                Components.StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    visible: search.text === ""
                    text: "Search processes by name or PID"
                    color: Services.Colors.color8
                    font.pixelSize: Services.Ui.textBodyLarge
                }
            }

            // ─── Column headings (click to sort) ───
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                Repeater {
                    model: [["Name", "name", -1], ["PID", "pid", 80], ["User", "user", 110], ["CPU", "cpu", 70], ["Memory", "mem", 90]]
                    Components.StyledText {
                        required property var modelData
                        text: modelData[0] + (panel.sortBy === modelData[1] ? (modelData[1] === "name" || modelData[1] === "user" || modelData[1] === "pid" ? " ▲" : " ▼") : "")
                        color: panel.sortBy === modelData[1] ? Services.Colors.accent : Services.Colors.surfaceVariantText
                        font.pixelSize: Services.Ui.textSmall
                        font.bold: true
                        Layout.fillWidth: modelData[2] < 0
                        Layout.preferredWidth: modelData[2] < 0 ? -1 : modelData[2]
                        horizontalAlignment: modelData[2] < 0 ? Text.AlignLeft : Text.AlignRight
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: panel.sortBy = parent.modelData[1]
                        }
                    }
                }
            }

            // ─── Processes ───
            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 1
                model: rows
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: processRow
                    required property int pid
                    required property string user
                    required property real cpu
                    required property real rss
                    required property string name
                    readonly property var modelData: ({ pid: pid, user: user, cpu: cpu, rss: rss, name: name })
                    readonly property bool sel: pid === panel.selectedPid
                    readonly property bool mine: user === panel.me
                    readonly property bool isArmed: panel.armed && panel.armed.pid === pid
                    width: list.width
                    height: 30
                    radius: Services.Ui.radiusSm
                    color: isArmed ? Services.Colors.blend(Services.Colors.background, Services.Colors.red, 0.35)
                        : sel ? Services.Ui.menuSelectionColor
                        : rowHover.containsMouse ? Services.Ui.menuHoverColor : "transparent"
                    opacity: mine || sel ? 1 : 0.6

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        Components.StyledText {
                            text: processRow.modelData.name
                            color: processRow.sel ? Services.Ui.menuSelectionText : Services.Colors.foreground
                            font.pixelSize: Services.Ui.textBody
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Components.StyledText {
                            text: processRow.modelData.pid
                            color: Services.Colors.surfaceVariantText
                            font.pixelSize: Services.Ui.textSmall
                            Layout.preferredWidth: 80
                            horizontalAlignment: Text.AlignRight
                        }
                        Components.StyledText {
                            text: processRow.modelData.user
                            color: Services.Colors.surfaceVariantText
                            font.pixelSize: Services.Ui.textSmall
                            Layout.preferredWidth: 110
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideLeft
                        }
                        Components.StyledText {
                            text: processRow.modelData.cpu.toFixed(1) + "%"
                            color: Services.Colors.threshold(processRow.modelData.cpu, 25, 50, 80)
                            font.pixelSize: Services.Ui.textSmall
                            font.bold: panel.sortBy === "cpu"
                            Layout.preferredWidth: 70
                            horizontalAlignment: Text.AlignRight
                        }
                        Components.StyledText {
                            text: panel.fmtMem(processRow.modelData.rss)
                            color: Services.Colors.foreground
                            font.pixelSize: Services.Ui.textSmall
                            font.bold: panel.sortBy === "mem"
                            Layout.preferredWidth: 90
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    MouseArea {
                        id: rowHover
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: { panel.selectedPid = processRow.pid; search.forceActiveFocus(); }
                    }
                }
            }

            // ─── Actions ───
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Components.StyledText {
                    Layout.fillWidth: true
                    text: panel.armed
                        ? "Click again (or press the key again) to " + (panel.armed.sig === "KILL" ? "force kill " : "end ")
                          + panel.armed.name + " (" + panel.armed.pid + ")"
                        : panel.message || "↑↓ select · Tab sort · Delete end · Shift+Delete kill · Esc close"
                    color: panel.armed || panel.message.startsWith("Couldn't") || panel.message.includes("administrator")
                        ? Services.Colors.red : Services.Colors.color8
                    font.pixelSize: Services.Ui.textSmall
                    font.bold: !!panel.armed
                    elide: Text.ElideRight
                }
                Components.TextButton {
                    text: panel.armed && panel.armed.sig === "TERM" ? "Really end?" : "End task"
                    enabled: panel.canEnd
                    onClicked: { panel.endSelected("TERM"); search.forceActiveFocus(); }
                }
                Components.TextButton {
                    text: panel.armed && panel.armed.sig === "KILL" ? "Really kill?" : "Force kill"
                    enabled: panel.canEnd
                    hoverColor: Services.Colors.red
                    onClicked: { panel.endSelected("KILL"); search.forceActiveFocus(); }
                }
            }
        }
    }
}
