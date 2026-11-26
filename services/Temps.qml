pragma Singleton

import QtQuick
import "." as Services
import "../lib" as Lib

/// Hardware temperatures from hwmon (scripts/system/temps.sh), for the temperature
/// widget (modelled on Dux Shell's CPU/GPU temperature widgets, MIT).
/// Polls only once something references this singleton.
QtObject {
    id: root

    /// [{ id, chip, dev, label, c }] — every sensor; `id` is stable across boots.
    property var sensors: []

    /// The CPU package sensor (Ryzen Tctl, Intel Package, …).
    readonly property var cpu: sensors.find(s => s.chip === "k10temp" && s.label === "Tctl")
        ?? sensors.find(s => /^(k10temp|zenpower|coretemp)$/.test(s.chip)) ?? null

    /// The discrete GPU's edge sensor: of several amdgpu chips (dGPU + iGPU),
    /// the one that also reports a junction temperature is the real card.
    readonly property var gpu: {
        const amd = sensors.filter(s => s.chip === "amdgpu");
        const dgpuDev = amd.find(s => s.label === "junction")?.dev;
        return amd.find(s => s.dev === dgpuDev && s.label === "edge")
            ?? amd[0] ?? sensors.find(s => /nouveau|nvidia/.test(s.chip)) ?? null;
    }

    /// "cpu" | "gpu" | a sensor id.
    function resolve(source) {
        if (!source || source === "cpu") return cpu;
        if (source === "gpu") return gpu;
        return sensors.find(s => s.id === source) ?? null;
    }

    /// Friendly group name for a sensor's chip in the dropdown.
    function chipName(s) {
        if (s.chip === "k10temp" || s.chip === "zenpower" || s.chip === "coretemp") return "CPU";
        if (s.chip === "amdgpu") return gpu && s.dev === gpu.dev ? "GPU" : "iGPU";
        if (s.chip === "nvme") return "NVMe " + s.dev;
        if (s.chip === "gigabyte_wmi") return "Motherboard";
        if (s.chip === "acpitz") return "ACPI";
        return s.chip;
    }

    property Lib.PolledProcess poll: Lib.PolledProcess {
        command: ["bash", Services.Paths.script("system/temps.sh")]
        interval: 3000
        onOutput: text => {
            try { root.sensors = JSON.parse(text); }
            catch (e) { console.warn("Temps: bad sensor JSON", e); }
        }
    }
}
