import QtQuick
import Quickshell
import "../services" as Services
import "../lib/Strftime.js" as Strftime
import "../components/screenshot" as ScreenshotUi
import "../components/screenshot/Geometry.js" as Geometry
import "../components/screenshot/Shapes.js" as Shapes

/// Screenshot selector: the frozen capture of every monitor in one global
/// fullscreen window (rule in i3/revenant.config), Flameshot
/// style. Click a window or a monitor, or drag an area; then adjust it, draw on
/// it and copy / save. Opened by scripts/screenshot/screenshot-capture.sh over IPC
/// (screenshotSelect); the PNG encode, clipboard and file happen afterwards in
/// scripts/screenshot/screenshot-deliver.sh, detached, so the shell never waits on them.
///
/// Every coordinate is in X root pixels, which are also capture-image pixels:
/// `stage` sits at the root origin. Only `crop` (the selected pixels plus the
/// drawing) is exported, by grabToImage at 1:1, so the frame, handles and
/// toolbar never end up in the picture. No compositor needed: the dimming is
/// drawn over the frozen image inside this window.
FloatingWindow {
    id: shot

    title: Services.Paths.shellName + "-shot"   // matched by i3/revenant.config
    color: "black"
    visible: false

    property string source: ""          // capture file (BMP in Paths.runtimeDir)
    property var windows: []            // visible windows, topmost first
    property var selection: null        // {x, y, w, h}; null while picking
    property var hover: null            // window / monitor under the pointer
    property var dragRect: null         // area being dragged out
    property point pointer: Qt.point(-1, -1)
    property string tool: "select"      // select | pen | arrow | rect | marker
    property int inkIndex: 0
    property var shapes: []             // finished drawings, root coordinates
    property var drawing: null          // the drawing in progress
    property bool busy: false
    property string naming: ""        // save | both | open while the name field is up
    property bool hadFocus: false

    readonly property string fontFamily: Services.Settings.fontFamily
    readonly property var inks: [Services.Colors.color1, Services.Colors.color3,
        Services.Colors.color2, Services.Colors.color4, Services.Colors.foreground]
    readonly property color accent: Services.Colors.accent

    readonly property var monitors: {
        const list = [];
        for (const s of Quickshell.screens)
            list.push({ x: s.x, y: s.y, w: s.width, h: s.height });
        return list;
    }
    // i3's global fullscreen covers the bounding box of the outputs; the
    // capture starts at the root origin.
    readonly property int originX: monitors.length ? Math.min(...monitors.map(m => m.x)) : 0
    readonly property int originY: monitors.length ? Math.min(...monitors.map(m => m.y)) : 0
    implicitWidth: monitors.length ? Math.max(...monitors.map(m => m.x + m.w)) - originX : 1920
    implicitHeight: monitors.length ? Math.max(...monitors.map(m => m.y + m.h)) - originY : 1080
    // Root extent, for clamping before the capture has decoded.
    readonly property int rootWidth: originX + implicitWidth
    readonly property int rootHeight: originY + implicitHeight

    // What the dimming, frame and size label follow.
    readonly property var shown: selection ?? dragRect ?? hover

    // ─── Opening and closing ───

    /// image: capture path; wins: "x,y,w,h;…" topmost first; preset: "x,y,w,h" or "".
    function openCapture(image, wins, preset) {
        if (visible || busy) return;
        if (Services.Ui.exclusivePanel) Services.Ui.exclusivePanel.close();
        if (Services.Ui.openPopup) Services.Ui.openPopup.close();
        windows = parseRects(wins);
        selection = parseRects(preset)[0] ?? null;
        hover = dragRect = drawing = null;
        shapes = [];
        tool = "select";
        naming = "";
        hadFocus = false;
        pointer = Qt.point(-1, -1);
        source = image;   // shown once decoded: see frame.onStatusChanged
    }

    function cancel() {
        if (!busy) closeSelector();
    }

    function closeSelector() {
        visible = false;
        naming = "";
        if (source) Quickshell.execDetached(["rm", "-f", "--", source]);
        source = "";
        busy = false;
    }

    readonly property string saveDir: {
        const dir = Services.Settings.screenshotDir.trim() || Quickshell.env("HOME") + "/Pictures/Screenshots";
        return dir.replace(/^~(?=\/|$)/, Quickshell.env("HOME"));
    }

    function defaultName() {
        return Strftime.fileName(Strftime.format(Services.Settings.screenshotNameFormat))
            || Strftime.fileName(Strftime.format("Screenshot_%Y-%m-%d_%H-%M-%S"));
    }

    /// action: copy | save | both | open (see screenshot-deliver.sh). `name`
    /// is the typed file name; without it, Save asks first when Settings →
    /// Screenshots says so, otherwise the date-time name is used.
    function finish(action, name) {
        if (busy || !source) return;
        if (!selection) {
            if (!hover) return;
            selection = hover;
        }
        if (name === undefined && action !== "copy" && Services.Settings.screenshotAskName) {
            naming = action;
            drawing = null;
            toolbar.startNaming(defaultName().replace(/\.png$/, ""));
            return;
        }
        const fileName = (name === undefined ? "" : Strftime.fileName(name)) || defaultName();
        busy = true;
        naming = "";
        drawing = null;
        const out = Services.Paths.runtimeDir
            + "/" + Services.Paths.shellName + "-export-" + Date.now() + ".bmp";
        // BMP: Qt writes it in a few ms; a PNG encode here would block the shell.
        crop.grabToImage(result => {
            if (result.saveToFile(out))
                Quickshell.execDetached(["bash", Services.Paths.script("screenshot/screenshot-deliver.sh"),
                    action, out, shot.saveDir, fileName]);
            else
                Quickshell.execDetached(["notify-send", "-u", "critical", "Screenshot", "Could not export the selection."]);
            shot.closeSelector();
        });
    }

    // ─── Geometry (components/screenshot/Geometry.js, bound to this screen) ───

    function parseRects(text) { return Geometry.parseRects(text, rootWidth, rootHeight); }
    function clampRect(r) { return Geometry.clampRect(r, rootWidth, rootHeight); }
    function fromCorners(x1, y1, x2, y2) { return Geometry.fromCorners(x1, y1, x2, y2, rootWidth, rootHeight); }
    function hitTest(x, y) { return Geometry.hitTest(windows, monitors, x, y); }
    function monitorFor(r) { return Geometry.monitorFor(monitors, r, rootWidth, rootHeight); }

    function backToPicking() {
        selection = null;
        hover = hitTest(pointer.x, pointer.y);
    }

    function undo() {
        if (shapes.length) shapes = shapes.slice(0, -1);
    }

    function nudge(dx, dy) {
        if (!selection) return;
        const s = selection;
        selection = {
            x: Math.max(0, Math.min(rootWidth - s.w, s.x + dx)),
            y: Math.max(0, Math.min(rootHeight - s.h, s.y + dy)), w: s.w, h: s.h
        };
    }

    function stopNaming() {
        naming = "";
        keys.forceActiveFocus();
    }

    function handleKey(e) {
        if (busy) { e.accepted = true; return; }
        if (naming) {   // the name field lost focus (a click): Esc still backs out
            if (e.key === Qt.Key_Escape) stopNaming();
            else toolbar.focusName();
            e.accepted = true;
            return;
        }
        const ctrl = e.modifiers & Qt.ControlModifier;
        const shift = e.modifiers & Qt.ShiftModifier;
        const step = shift ? 10 : 1;
        const tools = { [Qt.Key_V]: "select", [Qt.Key_P]: "pen", [Qt.Key_A]: "arrow",
            [Qt.Key_R]: "rect", [Qt.Key_M]: "marker" };
        if (e.key === Qt.Key_Escape) cancel();
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) finish(shift ? "both" : "copy");
        else if (ctrl && e.key === Qt.Key_C) finish("copy");
        else if (ctrl && e.key === Qt.Key_S) finish(shift ? "both" : "save");
        else if (ctrl && e.key === Qt.Key_O) finish("open");
        else if (ctrl && e.key === Qt.Key_Z) undo();
        else if (!ctrl && selection && tools[e.key] !== undefined) tool = tools[e.key];
        else if (!ctrl && e.key >= Qt.Key_1 && e.key < Qt.Key_1 + inks.length) inkIndex = e.key - Qt.Key_1;
        else if (e.key === Qt.Key_Left) nudge(-step, 0);
        else if (e.key === Qt.Key_Right) nudge(step, 0);
        else if (e.key === Qt.Key_Up) nudge(0, -step);
        else if (e.key === Qt.Key_Down) nudge(0, step);
        else return;
        e.accepted = true;
    }

    // ─── Drawing: components/screenshot/Shapes.js ───

    onShapesChanged: inkCanvas.requestPaint()
    onSelectionChanged: inkCanvas.requestPaint()

    // ─── Focus loss = something else took over (workspace key, new window) ───
    Item {
        Window.onActiveChanged: {
            if (Window.active) shot.hadFocus = true;
            else if (shot.visible && shot.hadFocus) shot.cancel();
        }
    }

    Item {
        id: keys
        focus: true
        Keys.onPressed: e => shot.handleKey(e)
    }

    Item {
        id: stage
        x: -shot.originX
        y: -shot.originY
        width: frame.width
        height: frame.height

        Image {
            id: frame
            source: shot.source ? "file://" + shot.source : ""
            asynchronous: true   // a 6000×1440 decode must not stall the bar
            smooth: false
            cache: true          // shared with crop's copy below
            onStatusChanged: {
                if (!shot.source) return;
                if (status === Image.Ready) {
                    shot.visible = true;
                    keys.forceActiveFocus();
                } else if (status === Image.Error) {
                    Quickshell.execDetached(["notify-send", "-u", "critical", "Screenshot", "Could not load the capture."]);
                    shot.closeSelector();
                }
            }
        }

        // ─── Dimming around the shown rectangle ───
        Item {
            id: dim
            anchors.fill: parent
            readonly property var r: shot.shown ?? { x: 0, y: 0, w: 0, h: 0 }
            readonly property real level: shot.selection ? 0.55 : 0.40
            Rectangle { x: 0; y: 0; width: dim.width; height: dim.r.y; color: "black"; opacity: dim.level }
            Rectangle { x: 0; y: dim.r.y + dim.r.h; width: dim.width; height: dim.height - y; color: "black"; opacity: dim.level }
            Rectangle { x: 0; y: dim.r.y; width: dim.r.x; height: dim.r.h; color: "black"; opacity: dim.level }
            Rectangle { x: dim.r.x + dim.r.w; y: dim.r.y; width: dim.width - x; height: dim.r.h; color: "black"; opacity: dim.level }
        }

        // ─── Picking: empty space starts a drag, a click takes the window / monitor ───
        MouseArea {
            id: picker
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.CrossCursor
            enabled: !shot.busy && !shot.naming
            property real pressX: 0
            property real pressY: 0
            property bool dragging: false
            property bool active: false   // this press is ours (not ignored)

            onPressed: m => {
                active = false;
                if (m.button === Qt.RightButton) {
                    if (shot.selection) shot.backToPicking(); else shot.cancel();
                    return;
                }
                // A drawing tool outside the selection: do nothing rather than
                // throw the selection away by accident.
                if (shot.selection && shot.tool !== "select") return;
                active = true;
                pressX = m.x;
                pressY = m.y;
                dragging = false;
            }
            onPositionChanged: m => {
                shot.pointer = Qt.point(m.x, m.y);
                if (!pressed || !active) {
                    if (!shot.selection) shot.hover = shot.hitTest(m.x, m.y);
                    return;
                }
                if (!dragging && Math.hypot(m.x - pressX, m.y - pressY) < 4) return;
                dragging = true;
                shot.selection = null;
                shot.hover = null;
                shot.dragRect = shot.fromCorners(pressX, pressY, m.x, m.y);
            }
            onReleased: m => {
                if (!active || m.button !== Qt.LeftButton) return;
                active = false;
                if (dragging) {
                    const r = shot.dragRect;
                    shot.dragRect = null;
                    dragging = false;
                    if (r && r.w >= 3 && r.h >= 3) shot.selection = r;
                    else shot.backToPicking();
                } else {
                    shot.selection = shot.hitTest(m.x, m.y);
                }
            }
        }

        // ─── Crosshair while picking ───
        Rectangle {
            visible: !shot.selection && shot.pointer.x >= 0
            x: 0; y: Math.round(shot.pointer.y); width: stage.width; height: 1
            color: shot.accent; opacity: 0.5
        }
        Rectangle {
            visible: !shot.selection && shot.pointer.x >= 0
            x: Math.round(shot.pointer.x); y: 0; width: 1; height: stage.height
            color: shot.accent; opacity: 0.5
        }

        // ─── The export: selected pixels + drawing ───
        Item {
            id: crop
            visible: shot.selection !== null
            x: shot.selection?.x ?? 0
            y: shot.selection?.y ?? 0
            width: shot.selection?.w ?? 1
            height: shot.selection?.h ?? 1
            clip: true

            Image {
                x: -crop.x
                y: -crop.y
                source: frame.source
                smooth: false
                cache: true
            }

            Canvas {
                id: inkCanvas
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.translate(-crop.x, -crop.y);
                    for (const s of shot.shapes) Shapes.paint(ctx, s);
                    if (shot.drawing) Shapes.paint(ctx, shot.drawing);
                }
            }
        }

        // ─── Move the selection, or draw inside it ───
        MouseArea {
            id: editor
            visible: shot.selection !== null
            enabled: !shot.busy && !shot.naming
            x: crop.x; y: crop.y; width: crop.width; height: crop.height
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: shot.tool === "select" ? Qt.SizeAllCursor : Qt.CrossCursor
            property var start: null

            onPressed: m => {
                if (m.button === Qt.RightButton) { shot.backToPicking(); return; }
                const p = mapToItem(stage, m.x, m.y);
                start = { x: p.x, y: p.y, sel: shot.selection };
                if (shot.tool !== "select")
                    shot.drawing = { type: shot.tool, color: String(shot.inks[shot.inkIndex]),
                        points: [{ x: p.x, y: p.y }] };
            }
            onPositionChanged: m => {
                if (!pressed || !start) return;
                const p = mapToItem(stage, m.x, m.y);
                shot.pointer = Qt.point(p.x, p.y);
                if (shot.tool === "select") {
                    const s = start.sel;
                    shot.selection = {
                        x: Math.round(Math.max(0, Math.min(stage.width - s.w, s.x + p.x - start.x))),
                        y: Math.round(Math.max(0, Math.min(stage.height - s.h, s.y + p.y - start.y))),
                        w: s.w, h: s.h
                    };
                } else if (shot.drawing) {
                    const pt = { x: p.x, y: p.y };
                    if (shot.tool === "pen" || shot.tool === "marker") shot.drawing.points.push(pt);
                    else shot.drawing.points = [shot.drawing.points[0], pt];
                    inkCanvas.requestPaint();
                }
            }
            onReleased: {
                const d = shot.drawing;
                shot.drawing = null;
                start = null;
                if (!d) return;
                const a = d.points[0], b = d.points[d.points.length - 1];
                const tiny = (d.type === "rect" || d.type === "arrow") && Math.hypot(b.x - a.x, b.y - a.y) < 4;
                if (tiny) inkCanvas.requestPaint();
                else shot.shapes = shot.shapes.concat([d]);
            }
            onDoubleClicked: if (shot.tool === "select") shot.finish("copy")
        }

        // ─── Frame and resize handles ───
        Rectangle {
            visible: shot.shown !== null
            x: (shot.shown?.x ?? 0) - 2
            y: (shot.shown?.y ?? 0) - 2
            width: (shot.shown?.w ?? 0) + 4
            height: (shot.shown?.h ?? 0) + 4
            color: "transparent"
            border.color: shot.accent
            border.width: 2
        }

        Repeater {
            model: [[-1, -1], [0, -1], [1, -1], [1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0]]

            Rectangle {
                id: handle
                required property var modelData
                readonly property int hx: modelData[0]
                readonly property int hy: modelData[1]
                visible: shot.selection !== null && shot.tool === "select" && !shot.naming
                width: 10; height: 10
                x: crop.x + (hx + 1) / 2 * crop.width - width / 2
                y: crop.y + (hy + 1) / 2 * crop.height - height / 2
                color: shot.accent
                border.color: Services.Colors.background
                border.width: 1

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    enabled: !shot.busy && !shot.naming
                    cursorShape: handle.hx === 0 ? Qt.SizeVerCursor
                        : handle.hy === 0 ? Qt.SizeHorCursor
                        : handle.hx === handle.hy ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
                    property var start: null
                    onPressed: start = shot.selection
                    onPositionChanged: m => {
                        if (!pressed || !start) return;
                        const p = mapToItem(stage, m.x, m.y), s = start;
                        const left = handle.hx < 0 ? p.x : s.x;
                        const right = handle.hx > 0 ? p.x : s.x + s.w;
                        const top = handle.hy < 0 ? p.y : s.y;
                        const bottom = handle.hy > 0 ? p.y : s.y + s.h;
                        const r = shot.fromCorners(left, top, right, bottom);
                        if (r.w >= 3 && r.h >= 3) shot.selection = r;
                    }
                    onReleased: start = null
                }
            }
        }

        // ─── Size label ───
        Rectangle {
            visible: shot.shown !== null
            readonly property var r: shot.shown ?? { x: 0, y: 0, w: 0, h: 0 }
            x: r.x
            y: r.y >= height + 6 ? r.y - height - 6 : r.y + 6
            width: sizeText.implicitWidth + 12
            height: sizeText.implicitHeight + 6
            color: Services.Colors.background
            Text {
                id: sizeText
                anchors.centerIn: parent
                text: parent.r.w + " × " + parent.r.h
                color: Services.Colors.foreground
                font.family: shot.fontFamily
                font.pixelSize: Services.Ui.textSmall
            }
        }

        // ─── Picking hint, top centre of each monitor ───
        Repeater {
            model: shot.selection ? [] : shot.monitors
            Rectangle {
                required property var modelData
                x: modelData.x + (modelData.w - width) / 2
                y: modelData.y + 16
                width: hintText.implicitWidth + 24
                height: hintText.implicitHeight + 12
                color: Services.Colors.background
                border.color: Services.Colors.outlineVariant
                Text {
                    id: hintText
                    anchors.centerIn: parent
                    text: "Click a window or screen  ·  Drag an area  ·  Enter copies the highlight  ·  Esc cancels"
                    color: Services.Colors.foreground
                    font.family: shot.fontFamily
                    font.pixelSize: Services.Ui.textBody
                }
            }
        }

        // ─── Toolbar (tools, colours, actions; the name field) ───
        ScreenshotUi.ScreenshotToolbar {
            id: toolbar
            selector: shot
        }
    }
}
