#!/usr/bin/env python3
"""Print "X Y" (root coordinates) for every mouse-button press on the display.

Used by components/WidgetPopup.qml to close a dropdown on an outside click.
X11 gives override-redirect popups no click-outside signal, and Quickshell's
PopupWindow.grabFocus only grabs on Wayland. XInput2 *raw* events are
delivered to every client that selects them on the root window, whichever
window is clicked and without stealing the click, so listening is harmless.

Needs python3-xlib. Exits when stdout closes (the popup stops the Process).
"""
import sys

from Xlib import display
from Xlib.ext import xinput
from Xlib.protocol import rq
from Xlib.ext.ge import GenericEventCode

# Raw event body after the generic-event header (XI2 protocol, XIRawEvent).
RawEventData = rq.Struct(
    rq.Card16("deviceid"),
    rq.Card32("time"),
    rq.Card32("detail"),       # button number
    rq.Card16("sourceid"),
    rq.Card16("valuators_len"),
    rq.Card32("flags"),
    rq.Pad(4),
)

WHEEL = {4, 5, 6, 7}           # scrolling (e.g. the volume widget) is not a click


def main():
    d = display.Display()
    info = d.query_extension("XInputExtension")
    if not info.present:
        sys.exit("click-watch: no XInputExtension")
    d.ge_add_event_data(info.major_opcode, xinput.RawButtonPress, RawEventData)
    root = d.screen().root
    root.xinput_select_events([(xinput.AllMasterDevices, xinput.RawButtonPressMask)])
    d.flush()

    while True:
        ev = d.next_event()
        if (ev.type != GenericEventCode or ev.extension != info.major_opcode
                or ev.evtype != xinput.RawButtonPress):
            continue
        if ev.data.detail in WHEEL:
            continue
        p = root.query_pointer()
        try:
            print(p.root_x, p.root_y, flush=True)
        except BrokenPipeError:
            return


if __name__ == "__main__":
    main()
