#!/usr/bin/env python3
"""Pick one on-screen pixel and print its colour as #rrggbb.

Used by widgets/ColorPicker.qml (Dux Shell's colour picker, on X11).
Grabs the pointer with a crosshair cursor until one click:
  left click   print the pixel's colour, exit 0
  right click  cancel, exit 1
  Escape       cancel, exit 1 (keyboard grabbed too)
Needs python3-xlib. No compositor, so the pixel read is exactly what is shown.
"""
import sys

from Xlib import X, display

XC_CROSSHAIR = 34


def main():
    d = display.Display()
    root = d.screen().root

    font = d.open_font("cursor")
    cursor = font.create_glyph_cursor(font, XC_CROSSHAIR, XC_CROSSHAIR + 1,
                                      (65535, 65535, 65535), (0, 0, 0))
    mask = X.ButtonPressMask
    if root.grab_pointer(False, mask, X.GrabModeAsync, X.GrabModeAsync,
                         X.NONE, cursor, X.CurrentTime) != X.GrabSuccess:
        sys.exit("color-pick: could not grab the pointer")
    root.grab_keyboard(False, X.GrabModeAsync, X.GrabModeAsync, X.CurrentTime)
    esc = d.keysym_to_keycode(0xFF1B)

    try:
        while True:
            ev = d.next_event()
            if ev.type == X.KeyPress and ev.detail == esc:
                return 1
            if ev.type != X.ButtonPress:
                continue
            if ev.detail != 1:
                return 1
            img = root.get_image(ev.root_x, ev.root_y, 1, 1, X.ZPixmap, 0xFFFFFFFF)
            b, g, r = img.data[0], img.data[1], img.data[2]   # BGRx on 24/32-bit visuals
            print("#%02x%02x%02x" % (r, g, b), flush=True)
            return 0
    finally:
        d.ungrab_pointer(X.CurrentTime)
        d.ungrab_keyboard(X.CurrentTime)
        d.flush()


if __name__ == "__main__":
    sys.exit(main())
