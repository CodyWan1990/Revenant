#!/usr/bin/env python3
"""Read and update the current user's desktop file associations through GIO."""
import argparse
import json

from gi.repository import Gio, GLib


def describe(app):
    return {"id": app.get_id(), "name": app.get_display_name()}


def associations(mime_type):
    default = Gio.AppInfo.get_default_for_type(mime_type, False)
    apps = [
        describe(app)
        for app in Gio.AppInfo.get_all_for_type(mime_type)
        if app.get_id() and (app.should_show() or (default and app.equal(default)))
    ]
    apps.sort(key=lambda app: (app["name"].casefold(), app["id"]))
    return {"default": describe(default) if default else None, "apps": apps}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--set", nargs=2, metavar=("DESKTOP_ID", "MIME_TYPES_JSON"))
    parser.add_argument("mime_types", nargs="+")
    args = parser.parse_args()

    errors = []
    if args.set:
        desktop_id, types_json = args.set
        requested = json.loads(types_json)
        if not isinstance(requested, list) or any(mime not in args.mime_types for mime in requested):
            parser.error("Requested types must be part of the queried types")
        for mime_type in requested:
            app = next(
                (candidate for candidate in Gio.AppInfo.get_all_for_type(mime_type)
                 if candidate.get_id() == desktop_id),
                None,
            )
            if app is None:
                errors.append(f"{desktop_id} is no longer registered for {mime_type}.")
                continue
            try:
                app.set_as_default_for_type(mime_type)
                default = Gio.AppInfo.get_default_for_type(mime_type, False)
                if not default or not default.equal(app):
                    errors.append(f"The active default for {mime_type} could not be changed.")
            except GLib.Error as error:
                errors.append(f"{mime_type}: {error.message}")

    print(json.dumps({
        "handlers": {mime_type: associations(mime_type) for mime_type in args.mime_types},
        "errors": errors,
    }))


if __name__ == "__main__":
    main()
