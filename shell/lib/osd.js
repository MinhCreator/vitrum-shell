.pragma library
// The on-screen display (volume, microphone, brightness, keyboard layout):
// where it shows, which island it hangs from, and what it says. It is a small
// drop out of the bar's centre island; where that bar cannot be seen (a game,
// a fullscreen window) an overlay window shows the same thing.

var KINDS = ["volume", "mic", "brightness", "layout"];
function known(kind) { return KINDS.indexOf(kind) >= 0; }

// Is this output's bar out of sight? Unmapped under a game (gameOutput), or
// under a fullscreen window: niri draws the top layer below one, except in
// the overview.
function barHidden(name, gameOutput, fullscreenOutput, overview) {
    if (!name) return false;
    if (gameOutput === name) return true;
    return !overview && fullscreenOutput === name;
}

// Where one screen shows it: "bar" (the drop), "window" (the overlay), or "".
// Never both, and only on the screen it was asked for (here).
function place(showing, here, barIsHidden) {
    if (!showing || !here) return "";
    return barIsHidden ? "window" : "bar";
}

// The island the drop hangs from: of the centre row's islands [{x, w}] the one
// over the row's middle (mid), else the nearest to it. -1: none.
function middle(frames, mid) {
    var best = -1, bestGap = Infinity, bestOff = Infinity;
    for (var i = 0; i < (frames || []).length; i++) {
        var f = frames[i];
        if (!f || !(f.w > 0)) continue;
        var gap = mid < f.x ? f.x - mid : mid > f.x + f.w ? mid - (f.x + f.w) : 0;
        var off = Math.abs(f.x + f.w / 2 - mid);
        if (gap < bestGap - 0.5 || (Math.abs(gap - bestGap) <= 0.5 && off < bestOff)) { best = i; bestGap = gap; bestOff = off; }
    }
    return best;
}

// A sheet w wide centred under its island, kept on a screen `width` wide.
function centred(ix, iw, w, width, gap) {
    // On whole pixels: an island of odd width put the sheet, and every line
    // and letter in it, half a pixel off.
    return Math.round(Math.max(gap, Math.min(width - w - gap, ix + iw / 2 - w / 2)));
}

// An open panel on the same bar: the drop stays away when the panel hangs
// from the same island or its sheet {x, w} would touch the drop's (both hang
// at the same height, so only x counts).
function blocked(panelUp, sameSource, panel, osd, gap) {
    if (!panelUp) return false;
    if (sameSource) return true;
    return panel.x < osd.x + osd.w + gap && osd.x < panel.x + panel.w + gap;
}

function icon(kind, value, muted) {
    if (kind === "volume") return muted ? "volume-mute" : value < 0.4 ? "volume-low" : "volume-high";
    if (kind === "mic") return muted ? "mic-off" : "mic";
    if (kind === "brightness") return "brightness";
    return "keyboard";
}

function text(value, muted) {
    return muted ? "muted" : Math.round(Math.max(0, value) * 100) + "%";
}

// Where the row of layouts sits in its view: centred when it fits; when it
// does not, moved so the current cell is in the middle, never past an end.
function rowOffset(cellX, cellW, rowW, viewW) {
    if (rowW <= viewW) return Math.round((viewW - rowW) / 2);
    var x = viewW / 2 - (cellX + cellW / 2);
    return Math.round(Math.max(viewW - rowW, Math.min(0, x)));
}
