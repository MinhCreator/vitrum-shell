pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/paths.js" as Lib

/*
 * Where the system keeps what vitrum uses but does not ship: the root helper,
 * xkb's catalogue, sounds, D-Bus services, zoneinfo, LADSPA plugins. Under
 * /usr almost everywhere; NixOS has nothing there and names the places in the
 * environment (VITRUM_LIBEXEC, XDG_DATA_DIRS, TZDIR, LADSPA_PATH), which its
 * package sets. The order is lib/paths.js's; the /usr paths stay last.
 */
Singleton {
    id: root
    readonly property var env: ({
        VITRUM_LIBEXEC: Quickshell.env("VITRUM_LIBEXEC"), VITRUM_MANAGED: Quickshell.env("VITRUM_MANAGED"),
        VITRUM_VERSION: Quickshell.env("VITRUM_VERSION"), XDG_DATA_DIRS: Quickshell.env("XDG_DATA_DIRS"),
        TZDIR: Quickshell.env("TZDIR"), LADSPA_PATH: Quickshell.env("LADSPA_PATH")
    })

    /// vitrum-root, run through pkexec.
    readonly property string rootHelper: Lib.rootHelper(env)
    /// "nix": the install is Nix's (nothing to pull, the flake input is updated); else "".
    readonly property string managed: Lib.managed(env)
    /// The version the package names; "" with the installer, which writes a file.
    readonly property string version: Lib.version(env, "")
    readonly property var zoneinfoDirs: Lib.zoneinfoDirs(env)
    readonly property var ladspaDirs: Lib.ladspaDirs(env)
    /// rel in each data dir, the first to try first.
    function data(rel) { return Lib.dataFiles(env, rel); }
    function soundDirs(setting) { return Lib.soundDirs(env, setting); }

    /// xkb's catalogue of layouts (evdev.lst); "" until looked for and found.
    /// A FileView takes one path, so the first that exists is asked for, once,
    /// by whoever reads it (findXkbRules); nowhere: the old path, as before.
    property string xkbRules: ""
    function findXkbRules() { if (!xkbRules && !xkb.running) xkb.running = true; }
    Process {
        id: xkb
        readonly property var files: root.data("X11/xkb/rules/evdev.lst")
        command: ["sh", "-c", 'for f; do [ -r "$f" ] && { printf "%s\\n" "$f"; exit 0; }; done; exit 0', "sh"].concat(files)
        stdout: StdioCollector { onStreamFinished: root.xkbRules = text.trim() || xkb.files[xkb.files.length - 1] }
    }
}
