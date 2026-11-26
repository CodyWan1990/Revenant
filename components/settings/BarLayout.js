.pragma library

// Bar layout operations for Settings → Bar → Widgets, as pure functions:
// each takes the sections ({ left, center, right } widget arrays) and
// returns a patch ({ section: newArray }) for Settings.setBarValues, or {}
// when nothing changes. Tested in tests/barreorder.qml.

/// { sec, index, widget } for a widget id, or null.
function locate(sections, order, id) {
    for (const sec of order) {
        const arr = sections[sec] ?? [];
        for (let i = 0; i < arr.length; i++)
            if (arr[i].id === id) return { sec: sec, index: i, widget: arr[i] };
    }
    return null;
}

function removeAt(sections, sec, i) {
    const a = sections[sec].slice();
    a.splice(i, 1);
    return { [sec]: a };
}

function append(sections, sec, widget) {
    return { [sec]: sections[sec].concat([widget]) };
}

/// Move `id` to `toIndex` in `toSec`; toIndex counts the slots before the
/// move, so dropping on the row below lands just before it.
function move(sections, order, id, toSec, toIndex) {
    const loc = locate(sections, order, id);
    if (!loc) return {};
    // A click on the drag handle is a full press/drop on the row's own
    // DropArea: a no-op, which must not cost a rebuild and a disk write.
    if (loc.sec === toSec && (toIndex === loc.index || toIndex === loc.index + 1))
        return {};
    if (loc.sec === toSec) {
        const a = sections[toSec].slice();
        a.splice(loc.index, 1);
        let idx = toIndex;
        if (idx > loc.index) idx--;   // account for the removed slot
        a.splice(Math.max(0, Math.min(idx, a.length)), 0, loc.widget);
        return { [toSec]: a };
    }
    const from = sections[loc.sec].slice();
    from.splice(loc.index, 1);
    const to = sections[toSec].slice();
    to.splice(Math.max(0, Math.min(toIndex, to.length)), 0, loc.widget);
    return { [loc.sec]: from, [toSec]: to };
}

/// Merge `patch` into the widget `id`.
function update(sections, order, id, patch) {
    const loc = locate(sections, order, id);
    if (!loc) return {};
    const a = sections[loc.sec].slice();
    a[loc.index] = Object.assign({}, a[loc.index], patch);
    return { [loc.sec]: a };
}

/// A separator/spacer option on one widget, or on all of them. Turning the
/// glyph back on with no glyph set restores "|".
function updateSpacer(sections, order, id, key, value, applyToAll) {
    function patchFor(widget) {
        const patch = { [key]: value };
        if (key === "hideGlyph" && !value && !(widget.glyph ?? "").trim())
            patch.glyph = "|";
        return patch;
    }
    if (!applyToAll) {
        const widget = locate(sections, order, id)?.widget;
        return widget ? update(sections, order, id, patchFor(widget)) : {};
    }
    const out = {};
    for (const sec of order) {
        const current = sections[sec] ?? [];
        const next = current.map(widget => {
            if (widget.type !== "separator" && widget.type !== "spacer") return widget;
            const patch = patchFor(widget);
            return Object.keys(patch).some(name => widget[name] !== patch[name])
                ? Object.assign({}, widget, patch) : widget;
        });
        if (next.some((widget, index) => widget !== current[index])) out[sec] = next;
    }
    return out;
}
