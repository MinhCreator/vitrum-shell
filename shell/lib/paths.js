.pragma library
// Where vitrum looks for what the system ships: its root helper, shared data
// (xkb's catalogue, sounds, D-Bus services), zoneinfo, LADSPA plugins. Most
// distributions keep these under /usr; NixOS keeps nothing there and says
// where through the environment. Pure, so it is tested
// (tests/js/paths.test.mjs): the environment's values in, the places to try
// out, in order. The paths every other distribution uses stay last, so
// nothing changes where they exist.

var LIBEXEC = "/usr/local/libexec/vitrum";
var DATA_DIRS = ["/usr/local/share", "/usr/share"];
var ZONEINFO = ["/etc/zoneinfo", "/usr/share/zoneinfo"];
var LADSPA = ["/usr/lib64/ladspa", "/usr/lib/ladspa", "/usr/local/lib/ladspa"];

function _str(v) { return v === undefined || v === null ? "" : String(v); }

// "a:b::a" → ["a", "b"]: absolute entries only (a relative one would depend on
// where the shell was started), each once, without a trailing slash.
function split(list) {
    var out = [], parts = _str(list).split(":");
    for (var i = 0; i < parts.length; i++) {
        var p = parts[i].replace(/\/+$/, "");
        if (parts[i].charAt(0) !== "/") continue;
        if (p === "") p = "/";
        if (out.indexOf(p) < 0) out.push(p);
    }
    return out;
}

function _with(first, rest) {
    var out = first.slice();
    for (var i = 0; i < rest.length; i++) if (out.indexOf(rest[i]) < 0) out.push(rest[i]);
    return out;
}

// The directory holding vitrum-root and vitrum-portal.
function libexec(env) {
    var d = split(_str(env && env.VITRUM_LIBEXEC));
    return d.length ? d[0] : LIBEXEC;
}
function rootHelper(env) { return libexec(env) + "/vitrum-root"; }

// XDG_DATA_DIRS (its default when unset), then /usr/share.
function dataDirs(env) {
    var d = split(_str(env && env.XDG_DATA_DIRS));
    return _with(d.length ? d : DATA_DIRS, ["/usr/share"]);
}
// dataFiles(env, "X11/xkb/rules/evdev.lst") → that file in each data dir.
function dataFiles(env, rel) {
    var d = dataDirs(env), out = [];
    for (var i = 0; i < d.length; i++) out.push(d[i] + "/" + rel);
    return out;
}

function zoneinfoDirs(env) { return _with(split(_str(env && env.TZDIR)), ZONEINFO); }
function ladspaDirs(env) { return _with(split(_str(env && env.LADSPA_PATH)), LADSPA); }

// "nix" when the install belongs to Nix (read-only, no checkout to pull, the
// flake input is what gets updated); "" for the installer's own.
function managed(env) { return _str(env && env.VITRUM_MANAGED).trim() === "nix" ? "nix" : ""; }

// The vitrum version: what the package says, else what the installer wrote
// (the text of ~/.local/share/vitrum/version).
function version(env, fileText) {
    return _str(env && env.VITRUM_VERSION).trim() || _str(fileText).trim();
}

// The sound theme folders to try: the one set in Settings, or — for none, or
// the old default, which does not exist everywhere — the freedesktop theme in
// each data dir.
function soundDirs(env, setting) {
    var s = _str(setting).trim().replace(/\/+$/, "");
    var stock = dataFiles(env, "sounds/freedesktop/stereo");
    return s && s !== "/usr/share/sounds/freedesktop/stereo" ? [s] : stock;
}
