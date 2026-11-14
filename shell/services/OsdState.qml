pragma Singleton

import QtQuick
import Quickshell
import "../lib/osd.js" as OsdLib

/*
 * The on-screen display's state: what it shows (volume, microphone,
 * brightness, keyboard layout), on which screen, and for how long. Shown when
 * a value changes, gone 1.2 s after the last change.
 *
 * Two things draw it and neither listens for itself: the bar lets a small drop
 * out of its centre island (modules/bar/Bar.qml), and where that bar cannot be
 * seen (a game, a fullscreen window) the overlay window shows the same
 * (modules/osd/Osd.qml). place() says which one, per screen.
 */
Singleton {
    id: root

    /// volume | mic | brightness | layout ("" before the first one).
    property string kind: ""
    /// The last kind that has a value: the meter keeps it while a layout shows.
    property string gauge: "volume"
    property bool showing: false
    /// The output it shows on: the focused one when it was asked for.
    property string screen: ""

    function show(k) {
        if (!OsdLib.known(k)) return;
        if (k !== "layout") gauge = k;
        kind = k;
        screen = Niri.focusedOutput || (Quickshell.screens.length ? Quickshell.screens[0].name : "");
        showing = true;
        hide.restart();
    }
    Timer { id: hide; interval: 1200; onTriggered: root.showing = false }

    // Changes after startup only (the first values are not news).
    property bool armed: false
    Timer { interval: 1500; running: true; onTriggered: root.armed = true }
    Connections {
        target: Audio
        enabled: root.armed
        function onVolumeChanged() { root.show("volume"); }
        function onMutedChanged() { root.show("volume"); }
        function onMicMutedChanged() { root.show("mic"); }
    }
    Connections { target: Power; enabled: root.armed; function onBrightnessChanged() { root.show("brightness"); } }
    Connections { target: Layouts; enabled: root.armed && !Layouts.held; function onIndexChanged() { root.show("layout"); } }
    Connections { target: UiState; function onOsdRequested(k) { root.show(k); } }

    readonly property real value: gauge === "volume" ? Audio.volume : gauge === "mic" ? Audio.micVolume : Power.brightness
    readonly property bool muted: (gauge === "volume" && Audio.muted) || (gauge === "mic" && Audio.micMuted)
    readonly property string icon: OsdLib.icon(gauge, value, muted)
    readonly property string text: OsdLib.text(value, muted)

    /// The output a fullscreen window covers ("" without one).
    readonly property string fullscreenOutput: {
        const w = Niri.fullscreenWindow;
        const ws = w ? Niri.workspaces[w.workspaceId] : null;
        return ws ? ws.output || "" : "";
    }
    /// How far the dock stands over this output's bar (a bar at the bottom has
    /// the dock right above its centre island, where the drop would rise): the
    /// dock's height while it shows there, else 0.
    function dockOver(name) {
        const d = UiState.activeDock;
        if (Settings.get("bar.position", "top") === "top" || !d || !d.shown || !d.targetScreen || d.targetScreen.name !== name) return 0;
        return d.plateH;
    }
    /// This output's bar, or the drop out of it, cannot be seen (lib/osd.js).
    function barHidden(name) { return OsdLib.barHidden(name, GameMode.output, fullscreenOutput, Niri.overviewOpen) || dockOver(name) > 0; }
    /// Where this output shows it now: "bar", "window" or "".
    function place(name) { return OsdLib.place(showing, screen === name, barHidden(name)); }
}
