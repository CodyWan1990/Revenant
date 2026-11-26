pragma Singleton

import QtQuick
import "../lib" as Lib

/// Mounted filesystems and their usage, for the Disks widget(s): one `df`
/// every 30 s shared by all of them. Pseudo and image filesystems (tmpfs,
/// snaps' squashfs, overlay, efivars) are left out; a hung network mount is
/// cut off by the timeout instead of wedging the widget.
QtObject {
    id: root

    /// [{ target, name, source, fstype, size, used, avail, percent }] in df's
    /// order; sizes in bytes. `name`: "root" for /, else the last path part.
    property var mounts: []
    readonly property bool ready: loaded
    property bool loaded: false

    function byTarget(target) { return mounts.find(mount => mount.target === target) ?? null; }

    function gb(bytes) {
        const value = bytes / 1073741824;
        return value >= 100 ? Math.round(value) : Math.round(value * 10) / 10;
    }
    /// "913G" / "1.8T" style, for compact labels.
    function human(bytes) {
        const tb = bytes / 1099511627776;
        return tb >= 1 ? (Math.round(tb * 10) / 10) + "T" : Math.round(bytes / 1073741824) + "G";
    }

    /// Choices for the widget's "Drives" checklist (SettingsOptionEditor "multi").
    readonly property var choices: mounts.map(mount => ({
        value: mount.target,
        label: mount.name + "  ·  " + mount.target,
        description: human(mount.size) + " " + mount.fstype + " on " + mount.source
    }))

    readonly property Lib.PolledProcess poll: Lib.PolledProcess {
        command: ["timeout", "5", "df", "-B1", "--output=source,fstype,size,used,avail,pcent,target",
            "-x", "tmpfs", "-x", "devtmpfs", "-x", "squashfs", "-x", "overlay", "-x", "efivarfs",
            "-x", "fuse.portal", "-x", "fuse.snapfuse"]
        interval: 30000
        onOutput: text => {
            const lines = text.trim().split("\n").slice(1);
            const out = [];
            for (const line of lines) {
                const f = line.trim().split(/\s+/);
                if (f.length < 7) continue;
                const target = f.slice(6).join(" ");
                out.push({
                    source: f[0], fstype: f[1], size: Number(f[2]), used: Number(f[3]),
                    avail: Number(f[4]), percent: parseInt(f[5]) || 0, target: target,
                    name: target === "/" ? "root" : target.split("/").filter(Boolean).pop()
                });
            }
            if (JSON.stringify(out) !== JSON.stringify(root.mounts)) root.mounts = out;
            root.loaded = true;
        }
    }
}
