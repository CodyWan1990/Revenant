# Revenant

If `AGENTS.local.md` is next to this file (in `~/.config/revenant/`), read it
too. It holds the person's own notes on their setup: what they changed and
how they like it. Revenant never writes or replaces it, so put lasting notes
about this machine there.

Revenant is a desktop shell for **i3 on X11**, written in QML on
[Quickshell](https://quickshell.org) 0.3 (Qt 6). It provides the bar, app
launcher, notifications, Control Center, clipboard history, Alt+Tab, power
menu, screenshots, the Settings window and the theme switcher. When someone
asks for something like "a bar widget for my VPN", "recolour Discord when I
switch theme", "open the clipboard with Super+V" or "move the clock to the
right", you do it by editing the files below. Most requests need **no change
to the shell's code**.

## Two places

| | Where | What |
|---|---|---|
| **The person's config** | `~/.config/revenant/` (`$XDG_CONFIG_HOME/<shell name>`) | `settings.json`, their themes, theme hooks, **their own widgets**, this file's copy. Work here first. |
| **The shell** | `~/.config/quickshell/revenant/` (the folder holding `shell.qml`) | The shareable code. Edit it only to change Revenant itself, for everyone. It never writes into its own folder. |

The shell copies this file to `~/.config/revenant/AGENTS.md` at every start,
with a "written by the shell" first line. Edits to that copy are
overwritten: change the shell's `AGENTS.md` instead.

## What you can and can't do

You can:
- add bar widgets (your own QML, or a shell command in the Custom widget)
- rearrange and restyle the bar
- recolour any app on every theme switch (theme hooks) and add themes
- change any setting (`settings.json`)
- open any panel or Settings page from a key or a script (IPC)
- send notifications
- edit i3's keybinds and options through the shell's i3 writers

You can't:
- use transparency or rounded *windows*: there is no compositor, so every
  window is opaque and square (rounded shapes *inside* a window are fine)
- use Wayland-only APIs (layer shell, `grabFocus`)
- type into a dropdown: popups are override-redirect and take the mouse
  only; a panel that needs the keyboard is a `FloatingWindow`
- run a second shell: each one owns the bar, the tray and the notification
  server

## What it's written in

QML (declarative UI with JavaScript expressions) on Quickshell. The comment
at the top of each file in the shell's `services/` is the reference for what
it offers. Read the file rather than guessing:

| Service | For |
|---|---|
| `Colors` | the live theme: `background`, `foreground`, `accent`, `red` `orange` `yellow` `green`, `color0`…`color15`, `surfaceContainer*`, `outline*`; `byKey(key, fallback)` turns a palette key (`paletteKeys`) into a colour |
| `Ui` | text sizes (`textCaption`, `textSmall`, `textBody`, `textBodyLarge`, `textSubtitle`, `textTitle`, `textHeading`, or `Ui.px(n)`), radii, field colours |
| `Icons` | glyphs by key (`cpu`, `memory`, `net`, `music`, `help`, `lock`, …): `markup(key, set, colour)`, `prefix(…)`, `esc(text)` for untrusted text |
| `Settings` | every setting, saved to `settings.json` |
| `Actions` | open things: `launcher()`, `clipboard()`, `settings()`, `powermenu()`, `notepad()`, `processes()`, `themePicker()`, … |
| `Theme` | the themes and `apply(slug)` |
| `Paths` | every path the shell uses (`configDir`, `stateDir`, `script(name)`) |
| `I3` | workspaces, windows, outputs (the one window-manager seam) |
| `NotifManager`, `Audio`, `Media`, `SystemStats`, `Weather`, `Wifi`, … | what their names say |

## Changing things safely

- **settings.json applies live**: the shell watches it and reloads.
  - Write valid JSON, and preferably write a new file and rename it into place.
  - A key you delete goes back to its default.
  - Invalid JSON is logged (`Settings: failed to parse JSON`) and the shell keeps its current values. The next change made from Settings then writes the whole file back from memory, so fix a broken file before touching the UI.
  - The shell saves 500 ms after a change made in Settings.
- **Logs**: `qs -c revenant` in a terminal shows them live (`qs log` lags behind).
- **Restart**: `pkill -x qs; setsid -f qs -c revenant`. Run only one shell at a time.
- **Escape hatch**: if a setting leaves the shell unusable, move `settings.json` aside (`mv settings.json settings.json.bak`) and restart. The defaults come back, and the file holds what to restore.
- Don't edit generated files: `i3-colors.config`, this file's copy, and what the theme hooks write (kitty `current-theme.conf`, GTK/Qt palettes, …).

## Seeing it

- **Screenshots**: `maim` takes the whole screen. For one of the shell's keyboard panels, use `maim -i "$(xdotool search --name '^revenant$' | head -1)"`. The bar is a dock along a screen edge, so use `maim -g <geometry>`.
- **Synthetic input** (`xdotool key …`): first check that the active window is the shell's (`xdotool getactivewindow getwindowname` prints `revenant`). Check again before *every* action: focus moves, and keys sent to the wrong window land in the person's apps.

## The files

| File | What it decides | Applied |
|---|---|---|
| `settings.json` | everything in Settings: bar layout and widgets per monitor, style, fonts, launcher, notifications, … | live |
| `widgets/<id>/` | your own bar widgets: `widget.json` + `Widget.qml` | live (on save) |
| `hooks/theme.d/*` | your theme hooks: scripts run on every theme switch | next switch |
| `themes/<slug>.json` | themes made in the theme builder, or by you | live in the list |
| `session.env` | keyboard repeat, screen blanking, login volume (Settings → Keyboard / Screen & power) | at login, and from Settings |
| `i3-colors.config` | i3 window colours | written by the `i3` theme hook |
| `AGENTS.md` | this file | written by the shell |
| `AGENTS.local.md` | the person's notes for agents | never written by the shell |
| `CLAUDE.md` | makes Claude Code read this file and `AGENTS.local.md` (`@AGENTS.md`, `@AGENTS.local.md`) | created once by the shell if missing, then the person's |

State lives in `~/.local/state/revenant/`: the active theme (`current`),
wallpaper, notepad and monitor layout. `$XDG_RUNTIME_DIR/revenant-*` holds
screenshots in progress and the copied-image history, in RAM.

## Driving the shell: IPC

`qs -c revenant ipc show` lists every call. Each one is
`qs -c revenant ipc call shell <name> [args]`:

| Call | Opens / does |
|---|---|
| `launcher`, `clipboard`, `clipimages`, `emoji`, `windowswitcher`, `powermenu`, `wallpaper`, `themes`, `processes`, `keybinds`, `notepad`, `weather` | that panel (toggles) |
| `settings`, `settingsPage <id>` | the Settings window, at a page: `theme`, `theme_hooks`, `bar_widgets`, `bar_appearance`, `launcher`, `notifications`, `keybinds`, `monitors`, `autostart`, … (the ids in `services/SettingsTabs.qml`); `presets`, `colours`, `wallpapers` open that part of `theme` |
| `themePreset <id or name>` | apply a saved preset (colours, each monitor's wallpaper, and its bar layout if it has one); prints `ok` or `no such preset` |
| `screenshot` | the region/window/screen selector |
| `updatesRefresh` | re-check for updates |
| `reloadWidgets` | read `widgets/` again (rarely needed: see *Your own widgets*) |

From i3, bind a key to a call, after the shell's file is included:

```
bindsym $mod+v exec --no-startup-id qs -c revenant ipc call shell clipboard
```

The shell's `i3/revenant-keys.config` has a default set. Keybinds can also be
changed from Settings → Keybinds, which edits i3's `modules/keys/*.config`
safely (see *Changing the shell*).

## Bar widgets

Every widget on the bar is an entry in `settings.json` with an `id`, a
`type`, the shared keys (`style`, `color`, `iconSet`, `surface`) and its own
options. The person adds, moves and configures widgets in
**Settings → Bar → Widgets**, which you can open with
`qs -c revenant ipc call shell settingsPage bar_widgets`. Prefer that to
editing the bar arrays in `settings.json` by hand: with separate monitors,
the layout lives per output under `bar.monitorProfiles`.

### Your own widgets: `widgets/<id>/`

```
~/.config/revenant/widgets/<id>/      id: letters, digits, - and _
  widget.json   its name, icon, one-line description and options
  Widget.qml    the widget
```

It shows up in Settings → Bar → Widgets → Add, marked "yours", as type
`user:<id>`.
- **Saving either file updates it on the bar.** A *new* folder is found when the Settings page opens, when `settings.json` puts its `user:<id>` on the bar (the shell looks again by itself), or after `ipc call shell reloadWidgets`.
- A folder that can't be used shows its error on that page and in the log.

`widget.json`:

```json
{
  "name": "VPN",
  "icon": "lock",
  "about": "Whether the VPN is up; click to toggle it.",
  "options": [
    { "key": "connection", "label": "Connection name", "type": "text", "fallback": "work" },
    { "key": "intervalSec", "label": "Check every", "type": "int", "from": 2, "to": 600, "suffix": "s", "fallback": 10 }
  ]
}
```

- `icon` is an `Icons` key, or `""` for none.
- Option rows are the same as the built-ins' (see `services/WidgetCatalog.qml`):
  - `bool`, `text`, `csv` (a comma list, stored as an array)
  - `int` / `float` (`from`, `to`, `step`, `decimals`, `suffix`)
  - `preset` (`choices: [{value, label}]`, `allowCustom`, `hint`)
  - `choice` / `enum` (`choices`: strings)
  - `palette` (a colour key)
  - `note` (text only, no key)
  - `{ "section": "Title" }` (a heading)
- Each row may have a `description`.
- Don't reuse the shared keys (`id`, `type`, `style`, `color`, `iconSet`, `surface`): every widget already has them, and **Colour** is already on its options page.

`Widget.qml` imports the shell's own modules as `qs.<folder>`. These are the
same live objects the shell uses, so a theme switch recolours your widget:

```qml
import QtQuick
import Quickshell
import qs.services as Services
import qs.components.bar as BarUi
import qs.lib as Lib

BarUi.BarWidget {
    id: root
    // Each option: instance.<key> ?? the same fallback as in widget.json.
    readonly property string connection: instance.connection ?? "work"
    property bool up: false

    icon: "lock"
    defaultAccent: up ? Services.Colors.green : Services.Colors.red   // used while Colour is "auto"
    text: Services.Icons.esc(connection + (up ? " up" : " down"))     // rich text: escape outside text
    clickable: true
    onClicked: Quickshell.execDetached(["nmcli", "connection", up ? "down" : "up", connection])

    Lib.PolledProcess {
        command: ["sh", "-c", "nmcli -t -f NAME connection show --active"]
        interval: (root.instance.intervalSec ?? 10) * 1000
        onOutput: text => root.up = text.split("\n").includes(root.connection)
    }
}
```

**`BarUi.BarWidget`**, the base most widgets use:
- **What the bar sets:** `bar`, and `instance` (this widget's entry, with your option keys).
- **What you set:**
  - `icon`: an `Icons` key.
  - `defaultAccent`: used while the person's Colour is "auto".
  - `text`: rich text after the icon.
  - `clickable` and the `clicked()` signal.
- **What it gives you:** the bar's font, the widget style (underline, pill, …) and the click area.

Children you declare (popups, `MouseArea`s for scroll or right-click,
`Timer`s) sit alongside its label.

If the widget isn't a single label, make the root an `Item` with
`property var bar`, `property var instance: ({})`, `Layout.fillHeight: true`
and an `implicitWidth`, and draw it yourself, e.g. with `BarUi.BarText`
pieces. `widgets/Custom.qml` in the shell is a small example.

Running things:
- **A poll:** `Lib.PolledProcess` (`command`, `interval`, `output(text)`; it times out hung commands and never runs two at once).
- **On demand:** `Process` from `Quickshell.Io`. If it might be started again while still running, use `Lib.QueuedProcess`, because a plain `Process` drops that second request.
- **Fire and forget:** `Quickshell.execDetached([...])`.
- **A file:** `FileView { path: …; watchChanges: true }`, not `cat` in a loop.

Rules:
- Text sizes come from `Services.Ui.text*`, never a literal `pixelSize`; the bar label follows the bar's font size by itself.
- Colours come from `Services.Colors`, not hex, so themes apply.
- Never name a property `on…`: QML takes it for a signal handler.
- Poll gently. Every widget on every monitor runs its own copy.

**More files in the folder** (a `logic.js`, a `Popup.qml`) can be imported
relatively (`import "logic.js" as Logic`). Only `Widget.qml` and
`widget.json` reload on save, though: Qt caches every other file it has
loaded, so restart the shell after editing one. Keeping logic in a `.js`
file has an upside: you can test it on its own with a scratch `qs -p` shell.

A full, commented example ships with the shell, in
`examples/widgets/hello/`. Copy it to start:
`cp -r ~/.config/quickshell/revenant/examples/widgets/hello ~/.config/revenant/widgets/mywidget`.

### The Custom widget: no QML

For a shell command's output on the bar, add **Custom** in Settings → Bar →
Widgets.
- `command`: run with `sh -c`; its first line is shown.
- `intervalMs`: how often it runs.
- `label` and `icon`: the text and glyph shown with it.
- `onClick`: a command run on click.

### Built-in widgets (changing the shell)

A widget that should ship with Revenant goes in the shell instead:
- `widgets/<Name>.qml`, using the relative imports (`"../services"`).
- One entry in `services/WidgetCatalog.qml`'s `entries`: its type, name, icon, file and options.
- A sentence in its `blurbs`.

`scripts/dev/check-architecture.sh` fails if a catalog entry's file is missing
or a widget file has no entry. Built-in widget files are not live-reloaded:
restart the shell.

## Theme hooks: `hooks/theme.d/`

A theme switch runs hooks: small programs that each recolour one thing.
- **Built-in:** i3 borders, rofi, kitty, GTK, Qt and KDE, in the shell's `scripts/theming/hooks/`.
- **Yours:** any executable in `~/.config/revenant/hooks/theme.d/`.
- **On/off:** each hook has a switch in **Settings → Appearance → Theme hooks** (stored as `theme.hooksDisabled`). Switching one off leaves that app as it is now; it doesn't undo anything.

A hook is called as:

```
hook NAME BG FG COMMENT SELECTION RED GREEN YELLOW BLUE MAUVE CYAN    # hex, no '#'
```

Its environment also carries:
- `THEME_BG`, `THEME_FG`, … for all 14 palette keys, including `THEME_ORANGE`, `THEME_TEAL`, `THEME_MAROON` and `THEME_LAVENDER`
- `THEME_NAME` and `THEME_SLUG`
- `REVENANT_CONFIG`, the config folder

```sh
#!/bin/sh
# theme-hook: Alacritty
# Writes ~/.config/alacritty/colors.toml; import it from alacritty.toml.
out="$HOME/.config/alacritty/colors.toml"
[ -d "${out%/*}" ] || exit 0                      # not installed: nothing to do
new=$(printf '[colors.primary]\nbackground = "#%s"\nforeground = "#%s"\n' "$THEME_BG" "$THEME_FG")
[ -f "$out" ] && [ "$(cat "$out")" = "$new" ] && exit 0   # unchanged: don't touch it
printf '%s\n' "$new" > "$out"
```

How hooks are named and ordered:
- The `# theme-hook: Name` line and the comment lines under it are what the Settings page shows.
- The **id** is the file name without a leading number and the extension. A hook named like a built-in (`kitty`, `gtk`, …) **replaces** it.
- Hooks run in order of their number (`25-discord` runs between kitty, 30, and gtk, 40); one without a number runs at 90.

How a hook should behave:
- Only rewrite a file, and reload the app, when the content changes: switching themes with the arrow keys runs every hook on every step.
- Exit 0 when the app isn't installed.
- A failing hook is logged and the others still run; after 30 s a hook is stopped.

Try it:

```sh
python3 ~/.config/quickshell/revenant/scripts/theming/theme-hooks.py list   # what will run, in order
qs -c revenant ipc call shell settingsPage theme_hooks                       # then "Re-apply current theme"
```

### Themes

A theme is `themes/<slug>.json`, either in the config folder (yours; it wins
over a shipped one with the same slug) or in the shell's `themes/`:

```json
{ "meta": { "name": "My Theme", "slug": "my-theme", "dark": true },
  "palette": { "bg": "1e1e2e", "fg": "cdd6f4", "comment": "6c7086", "selection": "313244",
               "red": "f38ba8", "orange": "fab387", "yellow": "f9e2af", "green": "a6e3a1",
               "blue": "89b4fa", "mauve": "cba6f7", "cyan": "94e2d5", "teal": "94e2d5",
               "maroon": "eba0ac", "lavender": "b4befe" } }
```

Hex without `#`. A missing key falls back to `fg`. New files show up in
Settings → Themes & wallpapers → Colours; the theme builder there writes the same format.

## Integrations

- **Notifications:** the shell *is* the notification server (no dunst), so `notify-send "Title" "Body"` from anything shows a toast and lands in the history. Don't start another notification daemon.
- **Status from any program:** the Custom widget, or your own widget with `Lib.PolledProcess`, or `FileView` on a file the program writes.
- **Recolouring another app:** a theme hook.
- **Opening shell UI from elsewhere** (i3 binds, scripts, other apps): IPC.
- **Session settings:** key repeat, blanking and DPMS live in `session.env`, written by Settings and applied by the shell itself whenever it starts (`scripts/system/session.py start`; the login volume once per session). No login-file line is needed.
- **i3 config changes:** go through the shell's i3 writers. They share `scripts/i3/i3_config.py`: lock, check with `i3 -C`, write atomically, and put the old file back if the reload fails. Don't hand-edit what Settings → Keybinds / Windows & gaps manage (`modules/keys/*.config`, `modules/window-options.config`).

## Changing the shell itself

When the change is for everyone (a new built-in widget, a Settings page, a
panel), edit the shell. Its `README.md` has the full layout. The rules:

- **Paths:** every path comes from `services/Paths.qml`. No user names or machine paths in the code: the shell is meant to be shared.
- **Text sizes:** from `Services.Ui`, never a literal `pixelSize` (`check-architecture.sh` rejects one).
- **Settings pages:** one file per page in `panels/settings/pages/`.
  - Each page is a `SettingsUi.SettingsPage` (that gives it the keyboard cursor).
  - Register it in `services/SettingsTabs.qml`.
  - Scans and polls on a page follow its `pageShown`.
  - Scripts that answer with one JSON object run through `lib/JsonScript.qml`.
  - The sidebar shows a page's `material` icon when the person picked Material icons, and its `nerd` glyph otherwise. The bundled Material font only has the names in `lib/MaterialCodepoints.js`, so choose one of those (`check-architecture.sh` checks).
- **Processes:** a `Process` that can be asked to run again while running must be a `lib/QueuedProcess`.
- **Window types** (X11, no compositor):
  - Only the bar is a `PanelWindow`.
  - Dropdowns and toasts are `PopupWindow`s: mouse only, and they close via `scripts/system/click-watch.py`.
  - Keyboard panels are `FloatingWindow`s titled `revenant`, which the i3 rules match.
  - Don't animate a window's size: i3 gets a resize command per frame.
- **New settings:** add a property *and* its key path in `services/Settings.qml`'s schema. An array or object property also goes in `objectProps`.
- **QML naming:** don't name properties `on…`.
- **Before you're done:** `scripts/dev/check.sh` runs qmllint (warning-free), the architecture rules, `bash -n`, the Python compile check, the QML tests in `tests/` and the example widgets, in about 15 s. Add a `tests/<name>.qml` for new logic, following the existing ones.

## Check before you finish

| You changed | Run |
|---|---|
| your widget | `~/.config/quickshell/revenant/scripts/dev/check-widget.sh ~/.config/revenant/widgets/<id>`: checks `widget.json`, then loads `Widget.qml` once in a sandbox and fails on any error from its folder. Then add it to the bar and look at it. |
| a theme hook | `theme-hooks.py list` (is it there, in order, enabled?), then switch theme (or Re-apply) and check the app and the log |
| a theme | pick it in Settings → Themes & wallpapers → Colours |
| a preset (theme + wallpapers) | `theme.presets` in `settings.json`, or Settings → Themes & wallpapers → Presets; apply with `ipc call shell themePreset <name>` |
| `settings.json` | the log shows no parse error; the change is visible |
| the shell | `scripts/dev/check.sh`, then restart and try it |

`check-widget.sh` doesn't lay the widget out on a real bar or click it, and
a hook's success is the app changing colour. Always look at the result
(*Seeing it*).

## Keep in mind

- One widget or one hook per idea. Don't change another widget, hook or theme unless the request needs it.
- Prefer the config folder to the shell. A change in the shell is a change for everyone who uses it.
- Don't edit this file's copy in `~/.config/revenant/`; put notes for later in `AGENTS.local.md`.
- A new widget folder is found by itself when you add it (Settings, or `settings.json`). Edits to `Widget.qml` / `widget.json` reload by themselves; other files in the folder need a restart.
