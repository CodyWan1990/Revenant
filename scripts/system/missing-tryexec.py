#!/usr/bin/env python3
"""Desktop entries whose TryExec program is not installed, as JSON.

Quickshell's DesktopEntries does not read TryExec, so services/Apps.qml asks
this instead and hides those entries, as the spec says launchers should.

Prints {"missing": ["<desktop id>", ...]}, where the id matches Quickshell's
DesktopEntry.id: the path under applications/ with "/" as "-", minus
".desktop". Directories are searched in XDG order and the first file found
for an id wins, so a user's override in ~/.local/share/applications hides
(or un-hides) the system entry.
"""
import json

from desktop_entries import applications, installed, read_entry


def main():
    missing = []
    for entry_id, path in applications().items():
        program = read_entry(path).get("TryExec", "").strip()
        if program and not installed(program):
            missing.append(entry_id)
    return {"missing": sorted(missing)}


if __name__ == "__main__":
    print(json.dumps(main()))
