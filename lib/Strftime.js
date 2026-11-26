.pragma library

// strftime-style formatting (the codes `date +FORMAT` takes) for screenshot
// filenames: Settings → Screenshots previews with it, and the screenshot
// selector names files with it, so the two always agree.

const MONTHS = ["January", "February", "March", "April", "May", "June", "July",
    "August", "September", "October", "November", "December"];
const DAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

/// Codes shown in the settings help line.
const CODES = "%Y year  %m month  %d day  %H hour  %I hour (12h)  %p AM/PM  %M min  %S sec"
    + "  %B month name  %b short  %A weekday  %a short  %y 2-digit year  %j day of year  %s epoch";

function pad(n, width) {
    return String(n).padStart(width || 2, "0");
}

function format(pattern, date) {
    const d = date || new Date();
    const h12 = d.getHours() % 12 || 12;
    const start = new Date(d.getFullYear(), 0, 1);
    const dayOfYear = Math.floor((d - start) / 86400000) + 1;
    const codes = {
        Y: d.getFullYear(), y: pad(d.getFullYear() % 100), m: pad(d.getMonth() + 1),
        d: pad(d.getDate()), e: String(d.getDate()).padStart(2, " "),
        H: pad(d.getHours()), I: pad(h12), l: String(h12), M: pad(d.getMinutes()),
        S: pad(d.getSeconds()), p: d.getHours() < 12 ? "AM" : "PM",
        P: d.getHours() < 12 ? "am" : "pm",
        B: MONTHS[d.getMonth()], b: MONTHS[d.getMonth()].slice(0, 3),
        A: DAYS[d.getDay()], a: DAYS[d.getDay()].slice(0, 3),
        j: pad(dayOfYear, 3), s: Math.floor(d.getTime() / 1000),
        F: d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()),
        T: pad(d.getHours()) + ":" + pad(d.getMinutes()) + ":" + pad(d.getSeconds()),
        "%": "%"
    };
    return String(pattern).replace(/%(.)/g, (all, c) => c in codes ? String(codes[c]) : all);
}

/// A safe file name: no directories (a typed "/" would escape the folder), no
/// leading dots (hidden files, ".."), always ending in .png. Empty → "".
function fileName(raw) {
    let name = String(raw).trim().replace(/[/\\]/g, "-").replace(/^\.+/, "").replace(/\.png$/i, "").trim();
    return name ? name + ".png" : "";
}
