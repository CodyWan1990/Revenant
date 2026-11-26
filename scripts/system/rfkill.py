#!/usr/bin/env python3
"""Soft-block or unblock a radio type: rfkill.py block|unblock bluetooth|wlan

A dependency-free stand-in for `rfkill block/unblock <type>`. Writes one
rfkill_event (linux/rfkill.h) to /dev/rfkill, which logind's uaccess ACL makes
writable by the logged-in user, so no root is needed. systemd-rfkill saves the
new state and restores it at boot, exactly as with the rfkill tool.
"""
import struct
import sys

TYPES = {"wlan": 1, "bluetooth": 2}
RFKILL_OP_CHANGE_ALL = 3


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in ("block", "unblock") or sys.argv[2] not in TYPES:
        sys.exit("usage: rfkill.py block|unblock bluetooth|wlan")
    soft = 1 if sys.argv[1] == "block" else 0
    # struct rfkill_event { __u32 idx; __u8 type, op, soft, hard; }  (v1, 8 bytes)
    event = struct.pack("IBBBB", 0, TYPES[sys.argv[2]], RFKILL_OP_CHANGE_ALL, soft, 0)
    with open("/dev/rfkill", "wb", buffering=0) as dev:
        dev.write(event)


if __name__ == "__main__":
    main()
