import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import qs.services
import qs.theme
import "../lib/lock.js" as LockLib

/*
 * The player, as a card: the cover, blurred, fills it under the glass; the
 * sharp cover sits on it with the track and the controls; the progress is a
 * wave while it plays; synced lyrics scroll under it (Lyrics), the spectrum
 * (Cava) runs along the bottom. Tints come from the cover.
 *
 * Used by the bar's media panel and the lock screen (its own height) and the
 * desktop's player widget (fill: the height it is given; lyrics only when
 * there is room). The times, the lyrics and the spectrum fold in and out
 * (Fold) rather than appear: lyrics land a moment after the card is shown.
 */
Item {
    id: root
    /// Take the height given (a widget) instead of the content's own (a panel).
    property bool fill: false
    property bool showLyrics: true
    /// The spectrum along the bottom (a widget's own option), as far as media.visualizer allows.
    property bool showVisualizer: true
    /// No plate of its own: inside a desktop widget the widget's glass is the card.
    property bool bare: false
    /// The material group the plain plate follows (the lock passes "lock").
    property string group: "panels"
    /// A button to the full-screen player (the bar's panel).
    property bool expandable: false
    readonly property real pad: bare ? 0 : fill ? Tokens.padding * 0.75 : Tokens.padding
    // Eased with the parts that fold: the lock's card follows it as it is.
    implicitHeight: body.implicitHeight + 2 * pad
    /// The height it is heading to. The bar eases its sheet to a new height
    /// itself, on the same curve as a Fold: given this, the two move as one
    /// (given the eased height, the sheet would trail the card and cut it).
    /// Summed from where the parts are heading, never from the heights on
    /// their way: those change every frame of a fold (and the column's own
    /// height a step behind them), the sheet's easing started over on each
    /// change, stood still, and jumped once the fold was done.
    readonly property real settledHeight: 2 * pad + track.height + waveBox.height
        + timesRow.rest + lyricsBox.rest + spectrumBox.rest

    // A tick after it is built: a widget is given its height then, and the
    // parts that depend on it take their places at once, not folding in.
    property bool live: false
    Component.onCompleted: { Cava.subscribe(); Lyrics.subscribe(); Qt.callLater(() => root.live = true); }
    Component.onDestruction: { Cava.unsubscribe(); Lyrics.unsubscribe(); }

    // The cover's most vivid colour, for the wave and the spectrum.
    CoverTint { id: coverTint }
    readonly property color tint: coverTint.tint

    // A part of the card that comes and goes: its height and the gap above it
    // ease together, and it stays shown until it has folded away. The content
    // sits at y: gap, at its full height; the fold cuts it while it moves.
    component Fold: Item {
        property bool shown: true
        /// Its height when shown, without the gap above it.
        property real full: 0
        property real gap: 0
        property real k: shown ? 1 : 0
        Behavior on k { enabled: Motion.enabled && root.live; EaseAnim { duration: Motion.standard } }
        /// Where its height is heading.
        readonly property real rest: shown ? full + gap : 0
        height: (full + gap) * k
        visible: k > 0
        opacity: k
        clip: k < 1
    }

    // ------------------------------------------------------- the card ---
    // The cover, blurred and tinted, under the content. Its edge is feathered
    // into the glass around it: a hard-edged box of blurred cover sat on the
    // refracted wallpaper like a sticker, its rounded corners most of all.
    readonly property real feather: Tokens.padding * 1.2
    readonly property bool hasArt: Media.artUrl.length > 0 && backArt.status === Image.Ready
    // Over a game (Materials.plain) the plain plate instead: two blur passes
    // and a mask over the game's frames.
    readonly property bool blurredArt: hasArt && !Materials.plain(root.group, Screen.name)
    // In a desktop widget the card sits inside the frame's padding: the
    // blurred cover reaches out to the frame's edge and takes its corners,
    // instead of a feathered box floating inside it.
    readonly property real bleed: bare ? Tokens.padding : 0
    /// How far up the cover reaches: a widget sets it to cover its header too.
    property real bleedTop: bleed
    readonly property real backRadius: bare ? Tokens.radiusPanel * 1.25 : Tokens.radiusInner * 1.5
    Item {
        id: back
        anchors.fill: parent
        anchors.margins: -root.bleed
        anchors.topMargin: -root.bleedTop
        visible: false
        Image { id: backArt; anchors.fill: parent; source: Media.artUrl; fillMode: Image.PreserveAspectCrop; sourceSize.width: 256; asynchronous: true }
    }
    // Soft mask: a rounded box inset by the feather, blurred out to the card's edge.
    // Its layer stays on: the wash's MultiEffect holds on to the texture it
    // was given, and a layer turned off and on again (a cover loading for a
    // moment) leaves it masking with a dead one, the blurred cover gone.
    Item {
        id: softMask
        anchors.fill: parent
        anchors.margins: -root.bleed
        anchors.topMargin: -root.bleedTop
        visible: false
        layer.enabled: true
        Rectangle { id: maskCore; anchors.fill: parent; anchors.margins: root.bare ? 0 : root.feather * 0.6; radius: root.backRadius; visible: false }
        MultiEffect { anchors.fill: maskCore; source: maskCore; blurEnabled: true; blur: 1.0; blurMax: root.bare ? 2 : Math.round(root.feather) }
    }
    // Bare (a desktop widget) too: only the plain plate is the widget's glass.
    Item {
        anchors.fill: parent
        anchors.margins: -root.bleed
        anchors.topMargin: -root.bleedTop
        visible: opacity > 0
        // The blurred cover comes in once it has loaded, not as a pop.
        opacity: root.blurredArt ? 1 : 0
        Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.standard } }
        layer.enabled: visible
        layer.effect: MultiEffect { maskEnabled: true; maskSource: softMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
        MultiEffect {
            anchors.fill: parent
            source: back
            blurEnabled: true; blur: 1.0; blurMax: 48
            saturation: 0.15
        }
        Rectangle { anchors.fill: parent; color: Colors.alpha(Colors.surface, Colors.dark ? 0.45 : 0.55) }
    }
    // No cover, or a game running: the plain plate.
    Rectangle {
        anchors.fill: parent
        visible: !root.bare && opacity > 0
        opacity: root.blurredArt ? 0 : 1
        Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.standard } }
        radius: Tokens.radiusInner * 1.5
        color: Materials.fill(root.group, 1, Screen.name)
    }

    Label { anchors.centerIn: parent; visible: !Media.available && !root.bare; text: "Nothing playing"; role: "dim" }

    Column {
        id: body
        visible: Media.available
        x: root.pad; y: root.pad
        width: root.width - 2 * root.pad
        // No spacing: each part under the track carries the gap above it, so
        // one that folds away takes its gap along, eased, not as a step.
        readonly property real gap: root.fill ? Tokens.gap * 0.6 : Tokens.gap

        // The cover, and the track with its controls.
        Row {
            id: track
            spacing: Tokens.gap * 1.5
            readonly property real cover: root.fill ? Math.min(Tokens.islandHeight * 4.4, Math.max(Tokens.islandHeight * 1.8, root.height * 0.4)) : Tokens.islandHeight * 3.4
            Rectangle {
                width: parent.cover; height: width; radius: Tokens.radiusInner
                color: Colors.surfaceHigh
                RoundImage {
                    id: art
                    anchors.fill: parent; source: Media.artUrl; sourceWidth: 256; radius: parent.radius
                    opacity: Media.artUrl.length > 0 && status === Image.Ready ? 1 : 0
                    Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.standard } }
                }
                Icon { anchors.centerIn: parent; name: "music"; size: Tokens.iconSize * 2; opacity: 1 - art.opacity; color: Colors.textDim }
            }
            Column {
                width: body.width - parent.cover - Tokens.gap * 1.5
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                // Short of the expand button, which sits in the card's corner.
                Label { width: parent.width - (expand.visible ? expand.width + Tokens.gap * 0.5 : 0); text: Media.title || Media.identity; size: root.fill ? Tokens.textSize : Tokens.textLarge; font.weight: Font.DemiBold; elide: Text.ElideRight }
                Label { width: parent.width; text: Media.artist; role: "dim"; elide: Text.ElideRight; visible: text.length > 0 }
                Label { width: parent.width; text: Media.album || Media.identity; role: "dim"; size: Tokens.textSmall; elide: Text.ElideRight; visible: !root.fill && text.length > 0 }
                Item { width: 1; height: Tokens.gap * (root.fill ? 0.4 : 1) }
                MediaControls { size: root.fill ? Tokens.islandHeight * 0.95 : Tokens.islandHeight * 1.05 }
            }
        }

        // The wave: up to where it is, a sine that moves while it plays.
        Item {
            id: waveBox
            width: body.width
            height: body.gap + wave.height
            Item {
                id: wave
                y: body.gap
                width: body.width
                height: Tokens.islandHeight * 0.55
                readonly property real frac: Media.length > 0 ? Math.max(0, Math.min(1, pos / Media.length)) : 0
                property real pos: Media.position
                property real phase: 0
                NumberAnimation on phase { from: 0; to: Math.PI * 2; duration: 1600; loops: Animation.Infinite; running: Media.playing && Motion.enabled && wave.visible }
                Timer { interval: 500; repeat: true; running: Media.playing && !GameMode.active; onTriggered: wave.pos = Media.current ? Media.current.position : 0 }
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: root.tint; strokeWidth: 3; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                        PathPolyline {
                            path: {
                                const pts = [], w = wave.width * wave.frac, mid = wave.height / 2, amp = Media.playing ? wave.height * 0.22 : 0;
                                for (let x = 0; x <= w; x += 3) pts.push(Qt.point(x, mid + amp * Math.sin(x / 7 + wave.phase)));
                                if (!pts.length) pts.push(Qt.point(0, mid));
                                return pts;
                            }
                        }
                    }
                }
                Rectangle {
                    x: wave.width * wave.frac; anchors.verticalCenter: parent.verticalCenter
                    width: wave.width - x; height: 3; radius: 1.5
                    color: Colors.alpha(Colors.text, 0.25)
                }
                Rectangle {
                    x: wave.width * wave.frac - width / 2; anchors.verticalCenter: parent.verticalCenter
                    width: 4; height: wave.height * 0.8; radius: 2; color: Colors.text
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: m => { if (Media.length > 0) { Media.seek(m.x / width * Media.length); wave.pos = m.x / width * Media.length; } }
                }
            }
        }
        Fold {
            id: timesRow
            width: body.width
            gap: body.gap
            full: times.implicitHeight
            // In a widget too, when it is tall enough to spare the line.
            // A long line of lyrics comes first: without room for two rows it would be cut.
            shown: !root.fill || (root.height > Tokens.islandHeight * 4.5
                                  && (!lyrics.wanted || lyrics.spareAll - full - body.gap >= lyrics.twoH))
            Label { id: times; y: timesRow.gap; text: LockLib.formatDuration(wave.pos); role: "dim"; size: Tokens.textSmall; numeric: true }
            Label { y: timesRow.gap; anchors.right: parent.right; text: LockLib.formatDuration(Media.length); role: "dim"; size: Tokens.textSmall; numeric: true }
        }

        // Synced lyrics: the line being sung in the middle (one line in a small
        // widget). A long line wraps to up to three rows rather than being cut;
        // the view keeps room for that, and the line being sung stays centred.
        // They arrive after the card is shown, and go with the track: the block
        // unfolds from its middle line and folds back, the card following.
        Fold {
            id: lyricsBox
            width: body.width
            gap: body.gap
            shown: lyrics.wanted && lyrics.room
            full: lyrics.lines === 3 ? lyrics.threeH : root.fill ? Math.max(0, Math.min(lyrics.tallH, lyrics.spare)) : lyrics.tallH

            ListView {
                id: lyrics
                readonly property real lineH: Tokens.textLarge * 1.9
                readonly property real rowH: Tokens.textLarge * 1.3
                // The tallest line: three rows of the large size.
                readonly property real tallH: lineH + 2 * rowH
                readonly property real threeH: lineH * 2 + tallH
                // Two rows: what a long line needs to be read whole.
                readonly property real twoH: lineH + rowH
                // In a widget, what the card has left for them: all else, the
                // spectrum's least included, comes first. Sized by the card alone,
                // they pushed the spectrum out past its bottom edge. From what
                // is wanted, not from heights on their way there.
                readonly property real spareAll: root.height - 2 * root.pad - track.height - wave.height - 2 * body.gap
                    - (spectrumBox.shown ? spectrumBox.least + body.gap : 0)
                readonly property real spare: spareAll - (timesRow.shown ? timesRow.full + body.gap : 0)
                readonly property int lines: root.fill && spare < threeH ? 1 : 3
                readonly property int maxRows: root.fill && spare < tallH ? 2 : 3
                // The next track's lyrics are a moment away ("loading"): the block
                // is held for it, empty, and folds only on the answer that there
                // are none (or when that takes too long).
                property bool was: false
                property bool late: false
                readonly property bool held: Lyrics.state === "loading" && was && !late
                readonly property bool wanted: root.showLyrics && Settings.get("media.lyrics", true) && (Lyrics.state === "synced" || held)
                readonly property bool room: !root.fill || spare >= twoH
                Component.onCompleted: was = Lyrics.state === "synced"
                Connections {
                    target: Lyrics
                    function onStateChanged() {
                        lyrics.late = false;
                        if (Lyrics.state === "loading") holdTimer.restart();
                        else { holdTimer.stop(); lyrics.was = Lyrics.state === "synced"; }
                    }
                }
                Timer { id: holdTimer; interval: 2500; onTriggered: lyrics.late = true }
                // Taken a tick later, never as it changes. A new track resets the model,
                // the view announces its current item in the middle of that, and a
                // highlight range bound straight to it reached back into the half-reset
                // view: Qt crashed in viewportMoved on every track change.
                property real currentH: lineH
                function syncCurrentH() { currentH = currentItem ? currentItem.height : lineH; }
                onCurrentItemChanged: Qt.callLater(syncCurrentH)
                // Its full height all along, centred in what the fold shows:
                // the highlight range holds still while the fold moves.
                y: lyricsBox.gap * lyricsBox.k + (lyricsBox.k - 1) * height / 2
                width: body.width
                height: lyricsBox.full
                // The new track's lines come into the held block, not pop.
                opacity: Lyrics.state === "synced" ? 1 : 0
                Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.standard } }
                clip: true
                interactive: false
                model: Lyrics.lines
                currentIndex: Math.max(0, Lyrics.index)
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: (height - currentH) / 2
                preferredHighlightEnd: (height + currentH) / 2
                highlightMoveDuration: Motion.enabled ? Motion.emphasized : 0
                delegate: Label {
                    required property var modelData
                    required property int index
                    readonly property bool now: index === Lyrics.index
                    onHeightChanged: if (ListView.isCurrentItem) Qt.callLater(lyrics.syncCurrentH)
                    // Only the line being sung and its neighbours: the room kept for
                    // a three-row line would otherwise show slivers of the lines
                    // beyond them, cut by the view's edge.
                    readonly property bool near: Math.abs(index - Math.max(0, Lyrics.index)) <= (lyrics.lines === 3 ? 1 : 0)
                    opacity: near ? 1 : 0
                    Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.standard } }
                    width: lyrics.width
                    // Padding, not a height: with a height set, Qt cuts wrapped text to
                    // it, a height taken from the text never grew past one row, and a
                    // long line ended in "…" instead of going on to the next row.
                    topPadding: (lyrics.lineH - lyrics.rowH) / 2
                    bottomPadding: topPadding
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData.text
                    wrapMode: Text.WordWrap
                    maximumLineCount: lyrics.maxRows
                    elide: Text.ElideRight
                    size: now ? Tokens.textLarge : Tokens.textSize
                    font.weight: now ? Font.DemiBold : Font.Normal
                    color: now ? Colors.text : Colors.alpha(Colors.text, 0.45)
                    Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.standard } }
                    // An instrumental line: a note, as an icon.
                    Icon { anchors.centerIn: parent; visible: !modelData.text; name: "music"; filled: true; color: parent.color; size: parent.font.pixelSize * 1.1 }
                }
            }
        }

        // The spectrum: a fixed set of bars, each reading its value (a new
        // model every frame would rebuild them all thirty times a second).
        Fold {
            id: spectrumBox
            width: body.width
            gap: body.gap
            readonly property real least: Tokens.islandHeight * 0.5
            shown: root.showVisualizer && Settings.get("media.visualizer", true)
            // In a widget: what is left under the parts above, as they move.
            full: root.fill ? Math.max(least, root.height - 2 * root.pad - y - gap) : Tokens.islandHeight * 0.9
            Row {
                id: spectrum
                y: spectrumBox.gap
                width: body.width
                height: spectrumBox.full
                // Paused or silent: the bars sink away rather than lie there as a dashed line.
                opacity: Cava.active && Cava.bars.length > 0 ? 1 : 0
                Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.standard } }
                spacing: 2
                Repeater {
                    model: Cava.barCount
                    Rectangle {
                        required property int index
                        readonly property real v: Cava.bars[index] || 0
                        width: (body.width - (Cava.barCount - 1) * 2) / Cava.barCount
                        height: Math.max(2, spectrum.height * v)
                        anchors.bottom: parent.bottom
                        radius: Math.min(width / 2, 3)
                        color: Colors.alpha(root.tint, 0.55 + 0.45 * v)
                    }
                }
            }
        }
    }

    // To the full-screen player: round, as the player's own buttons are.
    Item {
        id: expand
        visible: root.expandable && Media.available
        width: Math.round(Tokens.islandHeight * 0.9); height: width
        x: root.width - root.pad - width; y: root.pad
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Colors.alpha(Colors.text, expandMouse.pressed ? 0.18 : expandMouse.containsMouse ? 0.12 : 0.06)
            Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
        }
        Icon { anchors.centerIn: parent; name: "resize"; filled: true; size: Math.round(parent.width * 0.5) }
        MouseArea {
            id: expandMouse
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            // The panel closes: the player takes the whole screen.
            onClicked: { UiState.closePanel(); UiState.closeOverlays(); UiState.player = true; }
        }
    }
}
