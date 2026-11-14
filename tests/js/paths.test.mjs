import { load, eq, readJson } from "./lib.mjs";
const p = load("paths.js");
const j = v => JSON.stringify(v);

// Path lists
eq(j(p.split("/a:/b::/a:/c/")), j(["/a", "/b", "/c"]), "empty and repeated entries, a trailing slash");
eq(j(p.split("rel:./x:/abs")), j(["/abs"]), "relative entries are dropped");
eq(j(p.split(null)), "[]", "unset");
eq(j(p.split("")), "[]", "empty");

// The root helper: where every distribution but NixOS has it, unless told
eq(p.rootHelper({}), "/usr/local/libexec/vitrum/vitrum-root", "default");
eq(p.rootHelper(undefined), "/usr/local/libexec/vitrum/vitrum-root", "no environment at all");
eq(p.rootHelper({ VITRUM_LIBEXEC: null }), "/usr/local/libexec/vitrum/vitrum-root", "unset (Quickshell.env gives null)");
eq(p.rootHelper({ VITRUM_LIBEXEC: "" }), "/usr/local/libexec/vitrum/vitrum-root", "empty");
eq(p.rootHelper({ VITRUM_LIBEXEC: "/nix/store/abc-vitrum/libexec/vitrum/" }), "/nix/store/abc-vitrum/libexec/vitrum/vitrum-root", "from the package");
eq(p.rootHelper({ VITRUM_LIBEXEC: "libexec" }), "/usr/local/libexec/vitrum/vitrum-root", "a relative one is not trusted");

// Shared data: XDG_DATA_DIRS in its order, /usr/share always last
eq(j(p.dataDirs({})), j(["/usr/local/share", "/usr/share"]), "unset: the XDG default");
eq(j(p.dataDirs({ XDG_DATA_DIRS: "/usr/share:/usr/local/share" })), j(["/usr/share", "/usr/local/share"]), "its own order, nothing twice");
eq(j(p.dataDirs({ XDG_DATA_DIRS: "/run/current-system/sw/share:/home/u/.nix-profile/share" })),
   j(["/run/current-system/sw/share", "/home/u/.nix-profile/share", "/usr/share"]), "NixOS: its dirs, then the old one");
eq(j(p.dataFiles({ XDG_DATA_DIRS: "/run/current-system/sw/share" }, "X11/xkb/rules/evdev.lst")),
   j(["/run/current-system/sw/share/X11/xkb/rules/evdev.lst", "/usr/share/X11/xkb/rules/evdev.lst"]), "a file in each");
eq(p.dataFiles({}, "dbus-1/services/x.service").pop(), "/usr/share/dbus-1/services/x.service", "the old path is the last resort");

// Zoneinfo and LADSPA
eq(j(p.zoneinfoDirs({})), j(["/etc/zoneinfo", "/usr/share/zoneinfo"]), "zoneinfo without TZDIR");
eq(j(p.zoneinfoDirs({ TZDIR: "/nix/store/x-tzdata/share/zoneinfo" })),
   j(["/nix/store/x-tzdata/share/zoneinfo", "/etc/zoneinfo", "/usr/share/zoneinfo"]), "TZDIR first");
eq(j(p.ladspaDirs({})), j(["/usr/lib64/ladspa", "/usr/lib/ladspa", "/usr/local/lib/ladspa"]), "LADSPA: the old dirs, in the old order");
eq(j(p.ladspaDirs({ LADSPA_PATH: "/run/current-system/sw/lib/ladspa:/usr/lib/ladspa" })),
   j(["/run/current-system/sw/lib/ladspa", "/usr/lib/ladspa", "/usr/lib64/ladspa", "/usr/local/lib/ladspa"]), "LADSPA_PATH first");

// A managed install
eq(p.managed({ VITRUM_MANAGED: "nix" }), "nix", "nix");
eq(p.managed({ VITRUM_MANAGED: " nix\n" }), "nix", "padded");
for (const v of [undefined, null, "", "0", "yes", "portage"]) eq(p.managed({ VITRUM_MANAGED: v }), "", `not managed: ${j(v)}`);
eq(p.managed(undefined), "", "no environment");

// The version: the package's word, then the installer's file
eq(p.version({ VITRUM_VERSION: "0.7.0" }, "0.6.4\n"), "0.7.0", "the environment wins");
eq(p.version({}, "0.6.4\n"), "0.6.4", "the file otherwise");
eq(p.version({ VITRUM_VERSION: " " }, ""), "", "neither");

// Sounds: the stock default is searched for, a folder of your own is taken as it is
const nix = { XDG_DATA_DIRS: "/run/current-system/sw/share" };
const stock = readJson("shell/data/settings.defaults.json").sounds.theme;
eq(j(p.soundDirs(nix, stock)), j(["/run/current-system/sw/share/sounds/freedesktop/stereo", "/usr/share/sounds/freedesktop/stereo"]), "the default setting");
eq(j(p.soundDirs(nix, "")), j(p.soundDirs(nix, stock)), "an emptied field is the default");
eq(j(p.soundDirs(nix, "/home/u/sounds/")), j(["/home/u/sounds"]), "your own folder");
eq(p.soundDirs({}, stock).pop(), "/usr/share/sounds/freedesktop/stereo", "elsewhere: where it always was");
