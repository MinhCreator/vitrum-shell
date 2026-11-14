import { load, eq, ok } from "./lib.mjs";
const o = load("osd.js");
const d = load("drop.js");
const J = JSON.stringify;

// Kinds: anything else asked for over IPC is not shown.
ok(o.known("volume") && o.known("mic") && o.known("brightness") && o.known("layout"), "the four kinds");
ok(!o.known("") && !o.known("show") && !o.known(undefined), "nothing else");

// The bar is out of sight under a game or a fullscreen window, not in the overview.
eq(o.barHidden("DP-1", "", "", false), false, "a plain desktop: the bar shows");
eq(o.barHidden("DP-1", "DP-1", "", false), true, "a game on this output");
eq(o.barHidden("DP-1", "DP-2", "DP-2", false), false, "a game on the other output");
eq(o.barHidden("DP-1", "", "DP-1", false), true, "a fullscreen window here");
eq(o.barHidden("DP-1", "", "DP-1", true), false, "the overview shows the bar over it");
eq(o.barHidden("", "", "", false), false, "no name: not hidden");

// One place per screen, never both; nothing on a screen it was not asked for.
eq(o.place(true, true, false), "bar", "the bar's drop");
eq(o.place(true, true, true), "window", "the overlay when the bar is hidden");
eq(o.place(true, false, false), "", "another screen: nothing");
eq(o.place(true, false, true), "", "another screen with a game: nothing");
eq(o.place(false, true, false), "", "not showing");
eq(o.place(false, true, true), "", "not showing, hidden bar");

// The source island: the one over the row's middle, else the nearest.
eq(o.middle([], 100), -1, "no islands");
eq(o.middle([{ x: 0, w: 200 }], 100), 0, "the only one");
eq(o.middle([{ x: 0, w: 300 }, { x: 310, w: 60 }], 185), 0, "the wide one spans the middle");
eq(o.middle([{ x: 0, w: 60 }, { x: 70, w: 300 }], 185), 1, "and from the other side");
eq(o.middle([{ x: 0, w: 100 }, { x: 110, w: 100 }, { x: 220, w: 100 }], 160), 1, "the middle of three");
eq(o.middle([{ x: 0, w: 100 }, { x: 110, w: 100 }], 105), 0, "between two: the first");
eq(o.middle([{ x: 0, w: 0 }, { x: 0, w: 80 }], 40), 1, "one shrunk to nothing is skipped");
eq(o.middle([{ x: 0, w: 0 }], 0), -1, "only a shrunk one: none");

// Centred under the island, kept on the screen.
eq(o.centred(900, 120, 300, 1920, 10), 810, "centred");
eq(o.centred(20, 100, 300, 1920, 10), 10, "kept off the left edge");
eq(o.centred(1800, 100, 300, 1920, 10), 1610, "kept off the right edge");

// A panel on the same bar.
{
  const osd = { x: 810, w: 300 };
  eq(o.blocked(false, true, { x: 810, w: 300 }, osd, 10), false, "no panel: never blocked");
  eq(o.blocked(true, true, { x: 0, w: 10 }, osd, 10), true, "a panel from the same island");
  eq(o.blocked(true, false, { x: 1500, w: 400 }, osd, 10), false, "a panel far to the right: both show");
  eq(o.blocked(true, false, { x: 10, w: 400 }, osd, 10), false, "a panel far to the left: both show");
  eq(o.blocked(true, false, { x: 1000, w: 400 }, osd, 10), true, "overlapping");
  eq(o.blocked(true, false, { x: 1115, w: 400 }, osd, 10), true, "closer than a gap counts as touching");
  eq(o.blocked(true, false, { x: 1120, w: 400 }, osd, 10), false, "a gap apart");
}

// What it says.
eq(o.icon("volume", 0.8, false), "volume-high", "loud");
eq(o.icon("volume", 0.2, false), "volume-low", "quiet");
eq(o.icon("volume", 0.8, true), "volume-mute", "muted");
eq(o.icon("mic", 1, false), "mic", "microphone");
eq(o.icon("mic", 1, true), "mic-off", "microphone off");
eq(o.icon("brightness", 0.5, false), "brightness", "brightness");
eq(o.icon("layout", 0, false), "keyboard", "layout");
eq(o.text(0.456, false), "46%", "a rounded percentage");
eq(o.text(1.2, false), "120%", "over 100%");
eq(o.text(0.5, true), "muted", "muted");
{
  const { readJson } = await import("./lib.mjs");
  const icons = readJson("shell/data/icons.json");
  for (const k of ["volume", "mic", "brightness", "layout"])
    for (const m of [false, true])
      for (const v of [0.1, 0.9]) ok(icons[o.icon(k, v, m)], "an icon for " + k);
}

// The layouts as a row.
eq(o.rowOffset(0, 40, 120, 200), 40, "fits: centred");
eq(o.rowOffset(80, 40, 120, 200), 40, "fits: the same place for any cell");
eq(o.rowOffset(0, 40, 300, 200), 0, "too wide, first cell: from the start");
eq(o.rowOffset(130, 40, 300, 200), -50, "too wide: the current cell in the middle");
eq(o.rowOffset(260, 40, 300, 200), -100, "too wide, last cell: up to the end");

// The drop itself: one island tall under a centre island, narrower or wider
// than it, on a top and a bottom bar (lib/drop.js with the neck narrowed).
{
  const gap = 10, h = 34, w = 306;
  for (const island of [{ x: 900, y: gap, w: 120, h }, { x: 660, y: gap, w: 600, h }]) {
    const x = o.centred(island.x, island.w, w, 1920, gap);
    const g = d.dropGeometry(island, { x, w, h }, 1, gap, 10);
    eq(J(g.sheet), J({ x, y: gap + h + gap, w, h }), "open: the sheet under the bar");
    ok(g.neck.x >= g.sheet.x - 0.01 || g.neck.x >= island.x - 0.01, "the neck inside both");
    ok(g.neck.x + g.neck.w <= Math.min(island.x + island.w, g.sheet.x + g.sheet.w) + 0.01, "the neck no wider than either");
    for (const mirrored of [false, true]) {
      const p = d.dropPath(island, g.sheet, 10, 10, mirrored, 1080, g.neck);
      ok(p.startsWith("M") && p.endsWith("Z") && !/NaN/.test(p), "an outline");
    }
    eq(d.dropGeometry(island, { x, w, h }, 0, gap, 10).sheet.h, 0, "closed: nothing");
  }
}
