pragma Singleton

import QtQuick
import Quickshell.Io
import "." as Services
import "../lib" as Lib

/// CPU, memory, and network stats. CPU still goes through cpu-stats.sh (the
/// hwmon sensor walk needs a glob); memory and net are read straight from /proc.
QtObject {
    id: root
    readonly property real cpuPercent: internal.cpuPercent
    readonly property string cpuFreqGhz: internal.cpuFreqGhz
    readonly property int cpuTemp: internal.cpuTemp
    readonly property string cpuModel: internal.cpuModel
    readonly property int cpuCores: internal.cpuCores
    readonly property color cpuColor: Services.Colors.threshold(cpuPercent, 50, 65, 80)
    readonly property color cpuTempColor: Services.Colors.threshold(cpuTemp, 65, 75, 100)

    readonly property int memUsedGb: internal.memUsedGb
    readonly property int memTotalGb: internal.memTotalGb
    readonly property int memFreeGb: internal.memFreeGb
    readonly property int memPercent: internal.memPercent
    readonly property color memColor: Services.Colors.threshold(memPercent, 50, 65, 80)

    readonly property string netRx: internal.netRx
    readonly property string netTx: internal.netTx
    // ─── GPU (AMD, through amdgpu's sysfs files) ───
    /// The card with the most VRAM, i.e. the discrete one beside an iGPU.
    readonly property bool gpuAvailable: internal.gpuDir !== ""
    readonly property int gpuPercent: internal.gpuPercent
    readonly property real gpuVramUsedGb: internal.gpuVramUsedGb
    readonly property real gpuVramTotalGb: internal.gpuVramTotalGb
    readonly property int gpuVramPercent: gpuVramTotalGb > 0 ? Math.round(100 * gpuVramUsedGb / gpuVramTotalGb) : 0
    /// Junction (hotspot) temperature, or edge where there is no junction sensor.
    readonly property int gpuTemp: internal.gpuTemp
    readonly property color gpuColor: Services.Colors.threshold(gpuPercent, 50, 65, 80)
    readonly property color gpuTempColor: Services.Colors.threshold(gpuTemp, 70, 85, 100)
    readonly property real netRxBps: internal.netRxBps
    readonly property real netTxBps: internal.netTxBps

    // ─── History, for the popups' graphs (components/MiniGraph.qml) ───
    /// One sample every sampleMs, the newest last; historyLength samples.
    readonly property int sampleMs: 2000
    readonly property int historyLength: 90      // 3 minutes
    readonly property var cpuHistory: internal.cpuHistory
    readonly property var memHistory: internal.memHistory
    readonly property var rxHistory: internal.rxHistory
    readonly property var txHistory: internal.txHistory
    readonly property var tempHistory: internal.tempHistory
    readonly property var gpuHistory: internal.gpuHistory
    readonly property var gpuTempHistory: internal.gpuTempHistory
    function formatRate(bps) { return internal.humanRate(bps); }

    readonly property QtObject internal: QtObject {
        id: internal
        property real cpuPercent: 0
        property string cpuFreqGhz: "0.00"
        property int cpuTemp: 0
        property string cpuModel: ""
        property int cpuCores: 0
        property int memUsedGb: 0
        property int memTotalGb: 0
        property int memFreeGb: 0
        property int memPercent: 0

        property string netRx: "0B/s"
        property string netTx: "0B/s"
        property real netRxBps: 0
        property real netTxBps: 0
        property var cpuHistory: []
        property var memHistory: []
        property var rxHistory: []
        property var txHistory: []
        property var tempHistory: []
        property var gpuHistory: []
        property var gpuTempHistory: []
        property string gpuDir: ""
        property string gpuTempPath: ""
        property int gpuPercent: 0
        property real gpuVramUsedGb: 0
        property real gpuVramTotalGb: 0
        property int gpuTemp: 0
        // Previous /proc/stat totals, for the CPU busy share between samples.
        property real prevCpuTotal: -1
        property real prevCpuIdle: 0


        // Previous raw net counters; /proc gives totals since boot, so the
        // rate is the delta between consecutive polls.
        property real prevRx: -1
        property real prevTx: -1
        property real prevMs: 0

        function humanRate(bps) {
            if (bps < 1024) return Math.round(bps) + "B/s";
            if (bps < 1048576) return (bps / 1024).toFixed(1) + "KB/s";
            if (bps < 1073741824) return (bps / 1048576).toFixed(1) + "MB/s";
            return (bps / 1073741824).toFixed(1) + "GB/s";
        }

        // PolledProcess is an Item but needs no visual parent — its Timer/Process
        // run fine owned by a singleton; it also adds overlap-guard + kill-timeout.
        property Item cpuPoll: Lib.PolledProcess {
            command: ["bash", Services.Paths.script("system/cpu-stats.sh")]
            interval: 5000
            onOutput: text => {
                try {
                    let d = JSON.parse(text);
                    // Usage comes from /proc/stat over each whole sample (readCpu).
                    internal.cpuFreqGhz = d.freqGhz || "0.00";
                    internal.cpuTemp = d.temp || 0;
                    internal.cpuModel = d.model || "";
                    internal.cpuCores = d.cores || 0;
                } catch (e) {
                    console.warn("SystemStats: cpu parse error:", e, "raw:", text);
                }
            }
        }

        // Memory and network come straight out of /proc — FileView reads those
        // fine despite them reporting st_size 0, so there is no reason to fork
        // a shell every few seconds just to run awk over them.
        property FileView meminfo: FileView { path: "/proc/meminfo"; blockLoading: true }
        property FileView stat: FileView { path: "/proc/stat"; blockLoading: true }

        // card0/card1 and hwmonN can change between boots, so find the GPU
        // once: the amdgpu card with the most VRAM, and its junction sensor
        // (else its first temperature).
        property Process gpuFind: Process {
            running: true
            command: ["sh", "-c", "for d in /sys/class/drm/card[0-9]*/device; do "
                + "[ -r \"$d/mem_info_vram_total\" ] || continue; t=; "
                + "for h in \"$d\"/hwmon/hwmon*; do for l in \"$h\"/temp*_label; do "
                + "[ \"$(cat \"$l\" 2>/dev/null)\" = junction ] && t=${l%_label}_input; done; "
                + "[ -z \"$t\" ] && [ -r \"$h/temp1_input\" ] && t=$h/temp1_input; done; "
                + "echo \"$(cat \"$d/mem_info_vram_total\") $(readlink -f \"$d\") $t\"; done | sort -n | tail -1"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const f = this.text.trim().split(/\s+/);
                    if (f.length < 2) return;
                    internal.gpuVramTotalGb = Math.round(Number(f[0]) / 1073741824 * 10) / 10;
                    internal.gpuTempPath = f[2] ?? "";
                    internal.gpuDir = f[1];
                }
            }
        }
        property FileView gpuBusy: FileView { path: internal.gpuDir ? internal.gpuDir + "/gpu_busy_percent" : ""; blockLoading: true }
        property FileView gpuVram: FileView { path: internal.gpuDir ? internal.gpuDir + "/mem_info_vram_used" : ""; blockLoading: true }
        property FileView gpuTempFile: FileView { path: internal.gpuTempPath; blockLoading: true }
        function readGpu() {
            if (!gpuDir) return;
            gpuBusy.reload(); gpuVram.reload();
            gpuPercent = parseInt(gpuBusy.text()) || 0;
            gpuVramUsedGb = Math.round((parseInt(gpuVram.text()) || 0) / 1073741824 * 10) / 10;
            if (gpuTempPath) { gpuTempFile.reload(); gpuTemp = Math.round((parseInt(gpuTempFile.text()) || 0) / 1000); }
        }

        // Busy share of all CPU time since the last sample, as top computes it
        // (idle + iowait count as idle).
        function readCpu() {
            const f = stat.text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            if (f.length < 5) return;
            const total = f.slice(0, 8).reduce((a, b) => a + b, 0);
            const idle = f[3] + f[4];
            if (prevCpuTotal >= 0 && total > prevCpuTotal)
                cpuPercent = Math.round(1000 * (1 - (idle - prevCpuIdle) / (total - prevCpuTotal))) / 10;
            prevCpuTotal = total;
            prevCpuIdle = idle;
        }

        function push(list, value) {
            const next = list.concat(value);
            return next.length > root.historyLength ? next.slice(next.length - root.historyLength) : next;
        }
        property FileView netroute: FileView { path: "/proc/net/route"; blockLoading: true }
        property FileView netdev: FileView { path: "/proc/net/dev"; blockLoading: true }

        function readMem() {
            let total = 0, avail = 0;
            for (const line of meminfo.text().split("\n")) {
                let m = line.match(/^(MemTotal|MemAvailable):\s+(\d+)/);
                if (!m) continue;
                if (m[1] === "MemTotal") total = parseInt(m[2]);
                else avail = parseInt(m[2]);
            }
            if (total <= 0) return;
            const gb = kb => Math.round(kb / 1048576);
            memUsedGb = gb(total - avail);
            memFreeGb = gb(avail);
            memTotalGb = gb(total);
            memPercent = Math.round(100 * (total - avail) / total);
        }

        // Interface carrying the default route, i.e. what `ip route show
        // default` reports: the /proc/net/route row whose destination is 0.
        function defaultIface() {
            let lines = netroute.text().split("\n");
            for (let i = 1; i < lines.length; i++) {
                let f = lines[i].trim().split(/\s+/);
                if (f.length > 1 && f[1] === "00000000") return f[0];
            }
            return "";
        }

        function readNet() {
            let iface = defaultIface();
            if (!iface) return;
            // /proc/net/dev columns: iface: rx_bytes ... (8 fields) tx_bytes ...
            let row = netdev.text().split("\n").find(l => l.trim().startsWith(iface + ":"));
            if (!row) return;
            let f = row.split(":")[1].trim().split(/\s+/);
            let rx = parseInt(f[0]), tx = parseInt(f[8]), now = Date.now();
            // First sample or counter reset (iface change/reboot): re-baseline.
            if (prevRx >= 0 && rx >= prevRx && now > prevMs) {
                let dt = (now - prevMs) / 1000;
                netRxBps = (rx - prevRx) / dt;
                netTxBps = (tx - prevTx) / dt;
                netRx = humanRate(netRxBps);
                netTx = humanRate(netTxBps);
            }
            prevRx = rx;
            prevTx = tx;
            prevMs = now;
        }

        // One cheap sample (three /proc reads, no fork) for everything the
        // graphs show, so the history is already full when a popup opens.
        property Timer sampleTimer: Timer {
            interval: root.sampleMs; running: true; repeat: true; triggeredOnStart: true
            onTriggered: {
                internal.stat.reload();
                internal.meminfo.reload();
                internal.netroute.reload();
                internal.netdev.reload();
                const first = internal.prevCpuTotal < 0;
                internal.readCpu();
                internal.readMem();
                internal.readNet();
                internal.readGpu();
                if (first) return;   // no rates yet: nothing to plot
                internal.cpuHistory = internal.push(internal.cpuHistory, internal.cpuPercent);
                internal.memHistory = internal.push(internal.memHistory, internal.memPercent);
                internal.rxHistory = internal.push(internal.rxHistory, internal.netRxBps);
                internal.txHistory = internal.push(internal.txHistory, internal.netTxBps);
                internal.tempHistory = internal.push(internal.tempHistory, internal.cpuTemp);
                if (internal.gpuDir) {
                    internal.gpuHistory = internal.push(internal.gpuHistory, internal.gpuPercent);
                    internal.gpuTempHistory = internal.push(internal.gpuTempHistory, internal.gpuTemp);
                }
            }
        }

    }
}
