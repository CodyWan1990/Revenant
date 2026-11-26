.pragma library

// Drawing the screenshot annotations on a Canvas 2D context. A shape is
// { type: pen | marker | arrow | rect, color, points: [{ x, y }] } in root
// pixels (the caller translates the context to the selection).

function paint(ctx, s) {
    const p = s.points;
    if (!p.length) return;
    ctx.save();
    ctx.strokeStyle = s.color;
    ctx.fillStyle = s.color;
    ctx.lineJoin = "round";
    ctx.lineCap = "round";
    ctx.lineWidth = s.type === "marker" ? 18 : 3;
    if (s.type === "marker") ctx.globalAlpha = 0.35;
    const a = p[0], b = p[p.length - 1];
    if (s.type === "rect") {
        ctx.strokeRect(Math.min(a.x, b.x), Math.min(a.y, b.y), Math.abs(b.x - a.x), Math.abs(b.y - a.y));
    } else if (s.type === "arrow") {
        const angle = Math.atan2(b.y - a.y, b.x - a.x), head = 16;
        const back = { x: b.x - head * 0.8 * Math.cos(angle), y: b.y - head * 0.8 * Math.sin(angle) };
        ctx.beginPath();
        ctx.moveTo(a.x, a.y);
        ctx.lineTo(back.x, back.y);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(b.x, b.y);
        ctx.lineTo(b.x - head * Math.cos(angle - 0.45), b.y - head * Math.sin(angle - 0.45));
        ctx.lineTo(b.x - head * Math.cos(angle + 0.45), b.y - head * Math.sin(angle + 0.45));
        ctx.closePath();
        ctx.fill();
    } else {   // pen, marker
        ctx.beginPath();
        ctx.moveTo(a.x, a.y);
        for (let i = 1; i < p.length; i++) ctx.lineTo(p[i].x, p[i].y);
        if (p.length === 1) ctx.lineTo(a.x + 0.1, a.y);
        ctx.stroke();
    }
    ctx.restore();
}
