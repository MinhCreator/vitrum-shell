import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.theme
import qs.components
import "../../lib/lock.js" as LockLib

/*
 * The player, full screen (Mod+Alt+M, or the button on the bar's player):
 * the cover, blurred, is the whole backdrop; on it the cover, the track, the
 * wave and the controls, and beside them the lyrics as a tall column, the
 * line being sung large and the ones around it falling away. The spectrum
 * runs along the bottom edge. Tints come from the cover.
 *
 *   wide screens    the cover block on the left, the lyrics on the right
 *   narrow, tall    the cover block on top, the lyrics under it
 *   no lyrics       the cover block alone, in the middle
 *
 * Space plays and pauses, ← → seek 5 s, N and P are the next and the previous
 * track, ↑ ↓ scroll lyrics that are not timed, Escape closes. It closes itself
 * when there has been nothing to play for a while.
 *
 * The player's own look, as PlayerCard: not lit glass. No effect from niri
 * behind it (the namespace has no layer rule): the backdrop is opaque.
 */
PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    readonly property bool open: gate.ready && UiState.player && screen.name === (Niri.focusedOutput || Quickshell.screens[0].name)

    MapGate { id: gate; want: root.open }      // mapped only while open (components/MapGate.qml)
    visible: gate.mapped
    // Mapped again by opening: the window is a new one, the focus goes back in.
    onBackingWindowVisibleChanged: if (backingWindowVisible && open) keys.forceActiveFocus()
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "vitrum-player"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region { item: root.open ? catcher : dot }
    // Off the screen's top-left pixel: the top-left hot corner sits there, under this layer.
    Item { id: dot; x: 2; y: 2; width: 1; height: 1 }

    // ------------------------------------------------------------ state ---
    // The spectrum and the lyrics run only while someone shows them.
    property bool listening: false
    function listen(on) {
        if (on === listening) return;
        listening = on;
        if (on) { Cava.subscribe(); Lyrics.subscribe(); }
        else { Cava.unsubscribe(); Lyrics.unsubscribe(); }
    }
    Component.onCompleted: { showArt(); syncMode(); }
    Component.onDestruction: listen(false)
    onOpenChanged: {
        listen(open);
        if (!open) return;
        showArt(); syncMode();
        wave.pos = Media.current ? Media.current.position : 0;
        plainView.contentY = 0;
        keys.forceActiveFocus();
    }

    // Over a game, or with lite mode's plain fills: no blur passes, a plain backdrop.
    readonly property bool plain: Materials.plain("overlay", screen.name)

    // The cover's most vivid colour, for the wave and the spectrum.
    CoverTint { id: coverTint }
    readonly property color tint: coverTint.tint

    // The cover in two layers (ArtLayer): a new one goes into the layer that
    // is free and fades in over the other.
    property string artA: ""
    property string artB: ""
    property int artFront: 0
    function showArt() {
        const url = Media.artUrl;
        if ((artFront === 0 ? artA : artB) === url) return;
        if (artFront === 0) { artB = url; artFront = 1; }
        else { artA = url; artFront = 0; }
    }
    Connections {
        target: Media
        function onArtUrlChanged() { root.showArt(); }
        function onTrackKeyChanged() { wave.pos = Media.current ? Media.current.position : 0; }
    }

    // What the lyrics are: "synced", "plain" or "none". While the next
    // track's are asked for ("loading") the last answer stands, so the screen
    // is not rearranged twice.
    property string lyricsMode: "none"
    function syncMode() {
        const s = Lyrics.state;
        if (s === "loading") return;
        lyricsMode = s === "synced" ? "synced" : s === "plain" ? "plain" : "none";
    }
    Connections { target: Lyrics; function onStateChanged() { root.syncMode(); } }
    // 0: the cover block alone, in the middle; 1: beside (or above) the lyrics.
    // Set at once while it opens, eased once it is open.
    property real split: lyricsMode !== "none" ? 1 : 0
    Behavior on split { enabled: Motion.enabled && root.openT > 0.99; EaseAnim { duration: Math.round(Motion.emphasized * 1.5) } }

    // Nothing to play for a while (the player quit): nothing to show.
    Timer { interval: 4000; running: root.open && !Media.available; onTriggered: UiState.player = false }
    // The position only updates when asked.
    Timer {
        interval: 500; repeat: true
        running: root.open && Media.playing && !GameMode.active
        onTriggered: {
            if (!Media.current) return;
            Media.current.positionChanged();
            if (!seekArea.pressed) wave.pos = Media.current.position;
        }
    }
    function seekTo(seconds) {
        if (!(Media.length > 0)) return;
        const p = Math.max(0, Math.min(Media.length - 1, seconds));
        Media.seek(p);
        wave.pos = p;
        afterSeek.restart();
    }
    // Paused, nothing follows the position: the line being sung is found again.
    Timer { id: afterSeek; interval: 250; onTriggered: Lyrics._tick() }

    // The backdrop's slow drift and the wave's travel, by the frame: both stop
    // where they are when the music does, and go on from there.
    property real drift: 0
    property real wavePhase: 0
    FrameAnimation {
        running: root.open && Motion.enabled && (Media.playing || wave.amp > 0.01)
        onTriggered: {
            root.wavePhase = (root.wavePhase + frameTime * 3.9) % (Math.PI * 2);
            if (Media.playing && !root.plain) root.drift = (root.drift + frameTime * 0.07) % (Math.PI * 2);
        }
    }

    // The spectrum's last frame, kept: cava's bars are gone the moment it
    // stops, and the curve would drop flat before it has faded.
    property var bars: []
    Connections { target: Cava; function onBarsChanged() { if (Cava.bars.length) root.bars = Cava.bars; } }
    // Low notes in the middle, high ones out to both edges.
    readonly property var spectrumValues: bars.slice().reverse().concat(bars)
    /// The values as a smooth outline (Catmull-Rom through them), closed along the bottom.
    function spectrumPath(values, w, h) {
        const n = values.length, pts = [Qt.point(-2, h + 2)];
        if (n < 2) { pts.push(Qt.point(w + 2, h + 2)); return pts; }
        const at = i => values[Math.max(0, Math.min(n - 1, i))];
        const y = v => h - (0.03 + 0.97 * Math.max(0, Math.min(1, v))) * h;
        pts.push(Qt.point(-2, y(at(0))));
        for (let i = 0; i < n - 1; i++) {
            const p0 = at(i - 1), p1 = at(i), p2 = at(i + 1), p3 = at(i + 2);
            for (let s = 0; s < 4; s++) {
                const t = s / 4, t2 = t * t, t3 = t2 * t;
                const v = 0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (3 * p1 - p0 - 3 * p2 + p3) * t3);
                pts.push(Qt.point((i + t) / (n - 1) * w, y(v)));
            }
        }
        pts.push(Qt.point(w + 2, y(at(n - 1))));
        pts.push(Qt.point(w + 2, h + 2));
        return pts;
    }

    // ---------------------------------------------------------- entrance ---
    // 0 … 1, even: each part takes its own stretch of it, eased out (part()).
    // The backdrop first, then the cover block, then the lyrics; back the
    // other way, quicker.
    property real openT: open ? 1 : 0
    Behavior on openT { enabled: Motion.enabled; NumberAnimation { duration: root.open ? Motion.emphasized * 2 : Motion.standard } }
    function part(from, to) {
        const p = Math.max(0, Math.min(1, (openT - from) / (to - from)));
        return 1 - Math.pow(1 - p, 3);
    }
    readonly property real backIn: part(0, 0.6)
    readonly property real blockIn: part(0.15, 0.85)
    readonly property real lyricsIn: part(0.3, 1)

    // ------------------------------------------------------------ layout ---
    readonly property real u: Tokens.islandHeight
    readonly property real edge: Math.round(Math.max(Tokens.padding * 2, Math.min(width, height) * 0.05))
    readonly property bool wide: width > height * 1.2 && width >= u * 40
    readonly property real colGap: u * 2
    // Wide: two halves of a box in the middle, no wider than lyrics read well.
    readonly property real boxW: Math.min(width - 2 * edge, u * 64 + colGap)
    readonly property real boxX: (width - boxW) / 2
    readonly property real halfW: (boxW - colGap) / 2

    readonly property int titleSize: Math.round(Tokens.textTitle * 1.25)
    // Under a title this large the panel's sizes were footnotes.
    readonly property int artistSize: Math.round(titleSize * 0.7)
    // By the height, held back on a narrow screen: there a size taken from the
    // height alone broke every line in two.
    readonly property int lyricSize: Math.round(Math.max(Tokens.textTitle * 1.2, Math.min(height, width * 1.2) * 0.032 * Tokens.textScale))
    readonly property real controlSize: Math.round(u * 1.5)
    // What the block holds under the cover, at its tallest (a title of two
    // rows): the cover gives way to it on a low screen. Reckoned, not
    // measured: the block's width is the cover's, and its height the title's.
    readonly property real underCover: Tokens.gap * 7.75 + titleSize * 2.6 + artistSize * 1.5 + Tokens.textLarge * 1.5
                                       + wave.height + Tokens.textSize * 1.5 + controlSize * 1.2
                                       + (Media.players.length > 1 ? switchRows * u + (switchRows - 1) * Tokens.gap * 0.5 + Tokens.gap * 2 : 0)
    // The sources wrap to rows: about three to a row (reckoned, as the rest
    // is: the rows' real count hangs on the cover's width, which hangs on this).
    readonly property int switchRows: Math.min(4, Math.ceil(Media.players.length / 3))
    readonly property real coverSize: Math.round(Math.max(u * 6, wide
        ? Math.min(height * 0.38, u * 18, halfW, height - 2 * edge - underCover)
        : Math.min(height * 0.26, u * 14, width - 2 * edge)))
    readonly property int coverPx: Math.round(coverSize * ((screen && screen.devicePixelRatio) || 1))

    function lerp(a, b, t) { return a + (b - a) * t; }
    readonly property real blockX: wide ? lerp((width - block.width) / 2, boxX + (halfW - block.width) / 2, split) : (width - block.width) / 2
    readonly property real blockY: Math.max(edge, wide ? (height - block.height) / 2
                                                       : lerp((height - block.height) / 2, edge + u * 1.5, split))
    readonly property real lyricsX: wide ? boxX + halfW + colGap : edge
    readonly property real lyricsY: wide ? edge + u : edge + u * 1.5 + block.height + Tokens.gap * 3
    readonly property real lyricsW: wide ? halfW : width - 2 * edge
    readonly property real lyricsH: Math.max(0, wide ? height - 2 * (edge + u) : height - lyricsY - edge)

    // A blurred copy of the cover for the backdrop: two of them, one turned
    // round, drifting against each other.
    component Wash: ArtLayer {
        id: wash
        anchors.fill: parent
        has: washArt.status === Image.Ready
        settled: washArt.status !== Image.Loading
        Image {
            id: washArt
            anchors.fill: parent
            visible: false
            source: root.plain ? "" : wash.source
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 96
            asynchronous: true
        }
        MultiEffect {
            width: wash.width; height: wash.height
            x: Math.cos(root.drift) * wash.width * 0.08
            y: Math.sin(root.drift) * wash.height * 0.08
            scale: 1.5
            source: washArt
            blurEnabled: true; blur: 1.0; blurMax: 64
            saturation: 0.25
        }
        MultiEffect {
            width: wash.width; height: wash.height
            x: -Math.cos(root.drift * 2) * wash.width * 0.1
            y: Math.sin(root.drift) * wash.height * 0.1
            scale: 2
            rotation: 180
            opacity: 0.5
            source: washArt
            blurEnabled: true; blur: 1.0; blurMax: 64
            saturation: 0.25
        }
    }

    // The cover itself, and under it a blurred copy as its glow.
    component Sharp: ArtLayer {
        id: sharp
        anchors.fill: parent
        has: sharpArt.status === Image.Ready
        settled: sharpArt.status !== Image.Loading
        // With room around the picture for the blur to die away in: blurred
        // from the picture alone, the glow ended at the effect's own edge, a
        // box of colour under the cover and behind the title.
        Item {
            id: glowSource
            readonly property real room: Math.round(sharp.width * 0.35)
            x: -room; y: -room
            width: sharp.width + 2 * room; height: sharp.height + 2 * room
            visible: false
            layer.enabled: glowArt.status === Image.Ready
            Image {
                id: glowArt
                x: glowSource.room; y: glowSource.room
                width: sharp.width; height: sharp.height
                source: root.plain || Lite.shadowsOff ? "" : sharp.source
                sourceSize.width: 64
                asynchronous: true
            }
        }
        MultiEffect {
            x: glowSource.x; y: glowSource.y
            width: glowSource.width; height: glowSource.height
            visible: glowArt.status === Image.Ready
            source: glowSource
            autoPaddingEnabled: false
            transform: Translate { y: sharp.height * 0.07 }
            scale: 0.92
            opacity: Colors.dark ? 0.7 : 0.55
            blurEnabled: true; blur: 1.0; blurMax: 64
            saturation: 0.4
        }
        RoundImage { id: sharpArt; anchors.fill: parent; source: sharp.source; sourceWidth: root.coverPx; radius: Tokens.radiusPanel }
    }

    // A round button of the player's (as MediaControls' are).
    component RoundButton: Item {
        id: button
        property string icon: ""
        signal clicked()
        width: Math.round(root.u * 1.2); height: width
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Colors.alpha(Colors.text, buttonMouse.pressed ? 0.2 : buttonMouse.containsMouse ? 0.14 : 0.07)
            Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
        }
        Icon { anchors.centerIn: parent; name: button.icon; filled: true; size: Math.round(button.width * 0.45) }
        MouseArea { id: buttonMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: button.clicked() }
    }

    // ---------------------------------------------------------- backdrop ---
    MouseArea { id: catcher; anchors.fill: parent }

    Item {
        id: backdrop
        anchors.fill: parent
        opacity: root.backIn
        visible: opacity > 0
        // Under it all: the frame is never blank, and over a game it is all there is.
        Rectangle { anchors.fill: parent; color: Colors.surface }
        // Drawn small and stretched: a blur this soft has no detail to lose,
        // and the passes run over a sixteenth of the screen. (An eighth of
        // each side showed: the stretch drew its cells as a faint grid.)
        Item {
            id: small
            readonly property int by: 4
            visible: !root.plain
            width: Math.ceil(backdrop.width / by); height: Math.ceil(backdrop.height / by)
            transform: Scale { xScale: small.by; yScale: small.by }
            layer.enabled: visible
            layer.smooth: true
            Wash { id: washA; other: washB; source: root.artA; isFront: root.artFront === 0 }
            Wash { id: washB; other: washA; source: root.artB; isFront: root.artFront === 1 }
        }
        // So the text always reads, deeper at the edges where it sits.
        Rectangle {
            id: scrim
            anchors.fill: parent
            visible: !root.plain
            readonly property real a: Colors.dark ? 0.5 : 0.62
            gradient: Gradient {
                GradientStop { position: 0; color: Colors.alpha(Colors.surface, scrim.a + 0.1) }
                GradientStop { position: 0.45; color: Colors.alpha(Colors.surface, scrim.a) }
                GradientStop { position: 1; color: Colors.alpha(Colors.surface, scrim.a + 0.14) }
            }
        }

        // The spectrum, along the bottom edge: one soft outline, in the cover's
        // colour, sinking away when the music stops.
        Shape {
            id: spectrum
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: Math.round(root.height * 0.22)
            readonly property bool on: Settings.get("media.visualizer", true) && Cava.active && Cava.bars.length > 0
            opacity: on ? 1 : 0
            Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.emphasized * 2 } }
            visible: opacity > 0
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillGradient: LinearGradient {
                    x1: 0; y1: 0; x2: 0; y2: spectrum.height
                    GradientStop { position: 0; color: Colors.alpha(root.tint, 0.42) }
                    GradientStop { position: 1; color: Colors.alpha(root.tint, 0.08) }
                }
                PathPolyline { path: root.spectrumPath(root.spectrumValues, spectrum.width, spectrum.height) }
            }
        }
    }

    // ----------------------------------------------------------- content ---
    FocusScope {
        id: keys
        anchors.fill: parent
        focus: root.open
        Keys.onEscapePressed: UiState.player = false
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Space) Media.playPause();
            else if (event.key === Qt.Key_Left) root.seekTo(wave.pos - 5);
            else if (event.key === Qt.Key_Right) root.seekTo(wave.pos + 5);
            else if (event.key === Qt.Key_N) Media.next();
            else if (event.key === Qt.Key_P) Media.previous();
            else if (event.key === Qt.Key_Down && root.lyricsMode === "plain") plainView.flick(0, -1600);
            else if (event.key === Qt.Key_Up && root.lyricsMode === "plain") plainView.flick(0, 1600);
            else return;
            event.accepted = true;
        }

        Label {
            anchors.centerIn: parent
            visible: !Media.available
            opacity: root.backIn
            text: "Nothing playing"; role: "dim"; size: Tokens.textLarge
        }

        // ---------------------------------------------- the cover block ---
        Item {
            id: block
            x: root.blockX; y: root.blockY
            width: root.coverSize
            height: column.implicitHeight
            visible: Media.available && opacity > 0
            opacity: root.blockIn
            transform: Translate { y: (1 - root.blockIn) * root.u }

            Column {
                id: column
                width: block.width

                Item {
                    id: coverBox
                    width: root.coverSize; height: width
                    // Paused, it steps back a little.
                    scale: Media.playing ? 1 : 0.94
                    Behavior on scale { enabled: Motion.enabled; EaseAnim { duration: Motion.emphasized } }
                    // No cover: a plate with a note.
                    Rectangle {
                        anchors.fill: parent
                        z: -1
                        radius: Tokens.radiusPanel
                        color: Colors.alpha(Colors.text, 0.08)
                        opacity: 1 - Math.max(sharpA.opacity, sharpB.opacity)
                        visible: opacity > 0
                        Icon { anchors.centerIn: parent; name: "music"; filled: true; size: Math.round(coverBox.width * 0.3); color: Colors.textDim }
                    }
                    Sharp { id: sharpA; other: sharpB; source: root.artA; isFront: root.artFront === 0 }
                    Sharp { id: sharpB; other: sharpA; source: root.artB; isFront: root.artFront === 1 }
                }

                Item { width: 1; height: Tokens.gap * 3 }
                Label {
                    width: column.width
                    text: Media.title || Media.identity
                    size: root.titleSize
                    font.weight: Font.DemiBold
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                }
                Item { width: 1; height: Tokens.gap * 0.5 }
                Label { width: column.width; visible: text.length > 0; text: Media.artist; size: root.artistSize; color: Colors.alpha(Colors.text, 0.75); elide: Text.ElideRight }
                Item { width: 1; height: Tokens.gap * 0.25 }
                Label { width: column.width; visible: text.length > 0; text: Media.album; size: Tokens.textLarge; color: Colors.alpha(Colors.text, 0.5); elide: Text.ElideRight }

                // The wave: up to where it is, a sine that moves while it
                // plays. A click or a drag along it seeks (on letting go).
                Item { width: 1; height: Tokens.gap * 2 }
                Item {
                    id: wave
                    width: column.width
                    height: Math.round(root.u * 1.1)
                    property real pos: 0
                    property real dragFrac: 0
                    readonly property real frac: seekArea.pressed ? dragFrac
                                               : Media.length > 0 ? Math.max(0, Math.min(1, pos / Media.length)) : 0
                    readonly property real line: Math.max(3, Math.round(root.u * 0.12))
                    // Flat when paused, eased: not a wave frozen mid-air.
                    property real amp: Media.playing ? 1 : 0
                    Behavior on amp { enabled: Motion.enabled; EaseAnim { duration: Motion.emphasized } }
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: root.tint; strokeWidth: wave.line; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                            PathPolyline {
                                path: {
                                    const pts = [], w = wave.width * wave.frac, mid = wave.height / 2;
                                    const a = wave.amp * wave.height * 0.2, k = root.u * 0.3;
                                    for (let x = 0; x <= w; x += 3) pts.push(Qt.point(x, mid + a * Math.sin(x / k - root.wavePhase)));
                                    if (!pts.length) pts.push(Qt.point(0, mid));
                                    return pts;
                                }
                            }
                        }
                    }
                    Rectangle {
                        x: wave.width * wave.frac; anchors.verticalCenter: parent.verticalCenter
                        width: wave.width - x; height: wave.line; radius: height / 2
                        color: Colors.alpha(Colors.text, 0.22)
                    }
                    Rectangle {
                        x: wave.width * wave.frac - width / 2; anchors.verticalCenter: parent.verticalCenter
                        width: wave.line + 2; radius: width / 2; color: Colors.text
                        height: wave.height * (seekArea.pressed ? 1 : seekArea.containsMouse ? 0.9 : 0.7)
                        Behavior on height { enabled: Motion.enabled; EaseAnim { duration: Motion.fast } }
                    }
                    MouseArea {
                        id: seekArea
                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: true
                        cursorShape: Qt.PointingHandCursor
                        function at(x) { return Math.max(0, Math.min(1, x / width)); }
                        onPressed: m => wave.dragFrac = at(m.x)
                        onPositionChanged: m => { if (pressed) wave.dragFrac = at(m.x); }
                        onReleased: root.seekTo(wave.dragFrac * Media.length)
                    }
                }
                Item {
                    width: column.width; height: elapsed.implicitHeight
                    Label { id: elapsed; text: LockLib.formatDuration(seekArea.pressed ? wave.dragFrac * Media.length : wave.pos); role: "dim"; numeric: true }
                    Label { anchors.right: parent.right; text: LockLib.formatDuration(Media.length); role: "dim"; numeric: true }
                }

                Item { width: 1; height: Tokens.gap * 1.5 }
                MediaControls { anchors.horizontalCenter: parent.horizontalCenter; size: root.controlSize }

                // Several players: which one this is.
                Item { width: 1; height: Tokens.gap * 2; visible: switches.visible }
                // Wraps: many sources in one row ran past the block's edges.
                // As wide as its pieces when they fit, so one row stays centred.
                Flow {
                    id: switches
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: Media.players.length > 1
                    spacing: Tokens.gap * 0.5
                    readonly property real rowWidth: {
                        let w = 0;
                        for (let i = 0; i < choices.count; i++) { const it = choices.itemAt(i); if (it) w += it.width + spacing; }
                        return Math.max(0, w - spacing);
                    }
                    width: Math.min(parent.width, rowWidth)
                    Repeater {
                        id: choices
                        model: Media.players
                        Rectangle {
                            id: choice
                            required property var modelData
                            readonly property bool current: modelData === Media.current
                            // Never wider than the block: the name is cut instead.
                            width: Math.min(choiceLabel.implicitWidth + 2 * Tokens.padding, column.width); height: root.u
                            radius: Tokens.radiusButton
                            color: Colors.alpha(Colors.text, current ? 0.18 : choiceMouse.containsMouse ? 0.11 : 0.05)
                            Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
                            Label { id: choiceLabel; anchors.centerIn: parent; width: Math.min(implicitWidth, choice.width - 2 * Tokens.padding); elide: Text.ElideRight; text: Media.sourceLabel(choice.modelData); opacity: choice.current ? 1 : 0.7 }
                            MouseArea { id: choiceMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Media.setPlayer(choice.modelData) }
                        }
                    }
                }
            }
        }

        // -------------------------------------------------------- lyrics ---
        // Faded out at the top and the bottom rather than cut by an edge.
        Rectangle {
            id: fadeMask
            x: lyricsBox.x; y: lyricsBox.y
            width: lyricsBox.width; height: lyricsBox.height
            visible: false
            layer.enabled: true
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.16; color: "white" }
                GradientStop { position: 0.74; color: "white" }
                GradientStop { position: 1; color: "transparent" }
            }
        }
        Item {
            id: lyricsBox
            x: root.lyricsX; y: root.lyricsY
            width: root.lyricsW; height: root.lyricsH
            readonly property real show: root.lyricsIn * root.split
            visible: Media.available && show > 0 && height > root.u * 3
            opacity: show
            transform: Translate { y: (1 - lyricsBox.show) * root.u * 1.5 }
            clip: true
            // Not over a game: a mask is one more pass over its frames.
            layer.enabled: visible && !root.plain
            layer.effect: MultiEffect { maskEnabled: true; maskSource: fadeMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }

            // Timed: the line being sung two fifths of the way down, the rest
            // falling away from it. A click on a line goes to it.
            ListView {
                id: lines
                anchors.fill: parent
                visible: root.lyricsMode === "synced"
                // The next track's lines come in, not pop.
                opacity: Lyrics.state === "synced" ? 1 : 0
                Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.emphasized } }
                interactive: false
                model: Lyrics.lines
                currentIndex: Math.max(0, Lyrics.index)
                readonly property real restH: root.lyricSize * 1.9
                // Taken a tick later, never as it changes: a highlight range bound
                // straight to the current item reaches into a view that a new
                // track is resetting, and Qt crashes there (see PlayerCard).
                property real currentH: restH
                function syncCurrentH() { currentH = currentItem ? currentItem.height : restH; }
                onCurrentItemChanged: Qt.callLater(syncCurrentH)
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: height * 0.4 - currentH / 2
                preferredHighlightEnd: height * 0.4 + currentH / 2
                highlightMoveDuration: Motion.enabled ? Motion.emphasized * 2 : 0
                highlightMoveVelocity: -1
                // Lines beyond the edges stay built: they come into view already dimmed.
                cacheBuffer: Math.max(0, height)
                delegate: Item {
                    id: line
                    required property var modelData
                    required property int index
                    readonly property bool now: index === Lyrics.index
                    readonly property int away: now ? 0 : Math.max(1, Math.abs(index - Math.max(0, Lyrics.index)))
                    width: lines.width
                    height: lineText.implicitHeight
                    onHeightChanged: if (ListView.isCurrentItem) Qt.callLater(lines.syncCurrentH)
                    Label {
                        id: lineText
                        width: line.width
                        // Padding, not a height: a height cuts wrapped text (see PlayerCard).
                        topPadding: root.lyricSize * 0.45
                        bottomPadding: topPadding
                        horizontalAlignment: root.wide ? Text.AlignLeft : Text.AlignHCenter
                        text: line.modelData.text
                        wrapMode: Text.WordWrap
                        elide: Text.ElideNone
                        size: root.lyricSize
                        font.weight: Font.DemiBold
                        // One size laid out, the far lines drawn smaller: a
                        // size that eased would wrap the text anew on every frame.
                        transformOrigin: root.wide ? Item.Left : Item.Center
                        scale: line.away === 0 ? 1 : line.away === 1 ? 0.9 : 0.84
                        Behavior on scale { enabled: Motion.enabled; EaseAnim { duration: Motion.emphasized } }
                        opacity: lineMouse.containsMouse && line.away > 0 ? 0.75
                               : line.away === 0 ? 1 : line.away === 1 ? 0.5 : line.away === 2 ? 0.36 : line.away === 3 ? 0.26 : 0.18
                        Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.emphasized } }
                        // An instrumental line: a note, as an icon.
                        Icon {
                            visible: !line.modelData.text
                            x: root.wide ? 0 : (parent.width - width) / 2
                            anchors.verticalCenter: parent.verticalCenter
                            name: "music"; filled: true; size: root.lyricSize
                        }
                    }
                    MouseArea {
                        id: lineMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.seekTo(line.modelData.t)
                    }
                }
            }

            // Not timed: the same column, to scroll.
            Flickable {
                id: plainView
                anchors.fill: parent
                visible: root.lyricsMode === "plain"
                opacity: Lyrics.state === "plain" ? 1 : 0
                Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.emphasized } }
                contentWidth: width
                contentHeight: plainText.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                Label {
                    id: plainText
                    width: plainView.width
                    // Clear of the faded edges at both ends.
                    topPadding: plainView.height * 0.16
                    bottomPadding: plainView.height * 0.3
                    horizontalAlignment: root.wide ? Text.AlignLeft : Text.AlignHCenter
                    verticalAlignment: Text.AlignTop
                    text: Lyrics.plain
                    onTextChanged: plainView.contentY = 0
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                    size: Math.round(root.lyricSize * 0.7)
                    font.weight: Font.Medium
                    lineHeight: 1.35
                    color: Colors.alpha(Colors.text, 0.85)
                }
            }
        }

        // Whose music it is, and the way out: over the rest, in the corners.
        Row {
            x: root.edge; y: root.edge
            height: closeButton.height
            spacing: Tokens.gap * 0.75
            opacity: root.backIn * 0.6
            visible: Media.available
            Icon { name: "music"; filled: true; size: Tokens.iconSize; anchors.verticalCenter: parent.verticalCenter }
            Label { text: Media.identity; anchors.verticalCenter: parent.verticalCenter }
        }
        RoundButton {
            id: closeButton
            x: root.width - root.edge - width; y: root.edge
            opacity: root.backIn
            icon: "close"
            onClicked: UiState.player = false
        }
    }
}
