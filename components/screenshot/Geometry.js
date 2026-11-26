.pragma library

// Rectangle maths for the screenshot selector (panels/ScreenshotSelector.qml).
// Rects are { x, y, w, h } in X root pixels; rootW/rootH bound the screen.

/// "x,y,w,h;…" (from screenshot-capture.sh) -> rects, clamped, empty ones dropped.
function parseRects(text, rootW, rootH) {
    return String(text || "").split(";").map(r => r.split(",").map(Number))
        .filter(r => r.length === 4 && r.every(n => !isNaN(n)) && r[2] > 0 && r[3] > 0)
        .map(r => clampRect({ x: r[0], y: r[1], w: r[2], h: r[3] }, rootW, rootH))
        .filter(r => r.w > 0 && r.h > 0);
}

/// Whole pixels, inside the screen.
function clampRect(r, rootW, rootH) {
    const x = Math.max(0, Math.round(r.x)), y = Math.max(0, Math.round(r.y));
    const right = Math.min(rootW, Math.round(r.x + r.w));
    const bottom = Math.min(rootH, Math.round(r.y + r.h));
    return { x: x, y: y, w: Math.max(0, right - x), h: Math.max(0, bottom - y) };
}

/// The rect between two corners, in any order.
function fromCorners(x1, y1, x2, y2, rootW, rootH) {
    return clampRect({ x: Math.min(x1, x2), y: Math.min(y1, y2),
        w: Math.abs(x2 - x1), h: Math.abs(y2 - y1) }, rootW, rootH);
}

function contains(r, x, y) {
    return x >= r.x && x < r.x + r.w && y >= r.y && y < r.y + r.h;
}

/// The topmost window under the point, else its monitor, else null.
function hitTest(windows, monitors, x, y) {
    return windows.find(r => contains(r, x, y))
        ?? monitors.find(r => contains(r, x, y)) ?? null;
}

/// The monitor holding the rect's centre (where its toolbar goes).
function monitorFor(monitors, r, rootW, rootH) {
    const cx = r.x + r.w / 2, cy = r.y + r.h / 2;
    return monitors.find(m => contains(m, cx, cy)) ?? monitors[0]
        ?? { x: 0, y: 0, w: rootW, h: rootH };
}
