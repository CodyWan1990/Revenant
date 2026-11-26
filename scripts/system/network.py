#!/usr/bin/env python3
"""NetworkManager details and saved connections for Settings → Network,
through nmcli (what Quickshell.Networking doesn't expose: addresses, DNS,
every saved profile, VPNs).

    network.py details                  devices with addresses + connectivity
    network.py connections              saved profiles (no loopback)
    network.py up|down <uuid>           activate / deactivate a profile
    network.py autoconnect <uuid> yes|no
    network.py delete <uuid>

Prints JSON ({"devices", "connectivity"} / {"connections"} / {"error"}).
Changing a system-wide profile may ask for your password through the
session's polkit agent.
"""
import json
import re
import subprocess
import sys

UUID = re.compile(r"[0-9a-fA-F-]{36}")
LISTS = {"IP4.ADDRESS": "ip4", "IP4.DNS": "dns4", "IP6.ADDRESS": "ip6", "IP6.DNS": "dns6"}
KINDS = {
    "802-3-ethernet": "Ethernet", "802-11-wireless": "Wi-Fi", "vpn": "VPN",
    "wireguard": "VPN", "bluetooth": "Bluetooth", "gsm": "Mobile", "cdma": "Mobile",
    "bridge": "Bridge", "bond": "Bond", "vlan": "VLAN", "tun": "Tunnel",
}


def nmcli(*args, timeout=10):
    result = subprocess.run(["nmcli", *args], capture_output=True, text=True, timeout=timeout)
    if result.returncode:
        message = (result.stderr or result.stdout).strip().splitlines()
        raise ValueError(re.sub(r"^Error:\s*", "", message[-1] if message else "nmcli failed."))
    return result.stdout


def split_terse(line):
    """nmcli -t joins fields with ':' and escapes ':' and '\\' inside them."""
    fields, current, escaped = [], "", False
    for char in line:
        if escaped:
            current += char
            escaped = False
        elif char == "\\":
            escaped = True
        elif char == ":":
            fields.append(current)
            current = ""
        else:
            current += char
    fields.append(current)
    return fields


def details():
    fields = ("GENERAL.DEVICE,GENERAL.TYPE,GENERAL.STATE,GENERAL.CONNECTION,GENERAL.HWADDR,"
              "CAPABILITIES.SPEED,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS,IP6.GATEWAY,IP6.DNS")
    devices, device = [], None
    # `device show` is one "KEY:value" per line (values unescaped), blank
    # line between devices. Split at the first ':' — keys never contain one.
    for line in nmcli("-t", "-f", fields, "device", "show").splitlines() + [""]:
        if not line.strip():
            if device and device["type"] != "loopback":
                devices.append(device)
            device = None
            continue
        key, _, value = line.partition(":")
        if device is None:
            device = {"device": "", "type": "", "state": "", "connection": "", "mac": "", "speed": "",
                      "ip4": [], "gateway4": "", "dns4": [], "ip6": [], "gateway6": "", "dns6": []}
        base = key.split("[")[0]
        target = {
            "GENERAL.DEVICE": "device", "GENERAL.TYPE": "type", "GENERAL.CONNECTION": "connection",
            "GENERAL.HWADDR": "mac", "IP4.GATEWAY": "gateway4", "IP6.GATEWAY": "gateway6",
        }.get(base)
        if target:
            device[target] = value
        elif base == "GENERAL.STATE":
            device["state"] = re.sub(r"^\d+\s*\((.*)\)$", r"\1", value)
        elif base == "CAPABILITIES.SPEED":
            device["speed"] = "" if value in ("", "unknown") else value
        elif base in LISTS and value:
            device[LISTS[base]].append(value)
    connectivity = nmcli("-t", "networking", "connectivity").strip() or "unknown"
    return {"devices": devices, "connectivity": connectivity}


def connections():
    out = []
    for line in nmcli("-t", "-f", "NAME,UUID,TYPE,DEVICE,AUTOCONNECT,ACTIVE",
                      "connection", "show").splitlines():
        name, uuid, kind, device, autoconnect, active = (split_terse(line) + [""] * 6)[:6]
        if kind == "loopback":
            continue
        out.append({"name": name, "uuid": uuid, "type": KINDS.get(kind, kind), "device": device,
                    "autoconnect": autoconnect == "yes", "active": active == "yes"})
    out.sort(key=lambda c: (not c["active"], c["type"] != "VPN", c["name"].lower()))
    return {"connections": out}


def checked(uuid):
    if not UUID.fullmatch(uuid or ""):
        raise ValueError("That is not a connection id.")
    return uuid


def main(action="details", *args):
    if action == "details":
        return details()
    if action == "connections":
        return connections()
    if action in ("up", "down"):
        nmcli("--wait", "30", "connection", action, "uuid", checked(args[0]), timeout=40)
    elif action == "autoconnect":
        if args[1] not in ("yes", "no"):
            raise ValueError("autoconnect takes yes or no.")
        nmcli("connection", "modify", "uuid", checked(args[0]), "connection.autoconnect", args[1])
    elif action == "delete":
        nmcli("connection", "delete", "uuid", checked(args[0]))
    else:
        raise ValueError(f"Unknown action {action}.")
    return connections()


if __name__ == "__main__":
    try:
        result = main(*sys.argv[1:])
    except (OSError, ValueError, IndexError, subprocess.TimeoutExpired) as error:
        result = {"error": str(error)}
    print(json.dumps(result))
