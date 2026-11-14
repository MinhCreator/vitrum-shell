import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.theme
import qs.components

/*
 * The on-screen display where the bar cannot be seen: over a game or a
 * fullscreen window the bar's own drop (Bar.qml) would be under it (and under
 * the dock, when the bar is at the bottom and the dock shows), so this
 * overlay shows the same content (OsdContent) as a piece of glass of its own,
 * where the drop would hang. OsdState decides which of the two shows.
 *
 * Always mapped, with a 1 px region and mask while it shows nothing.
 */
PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    readonly property bool showing: OsdState.place(modelData.name) === "window"

    visible: true
    readonly property bool atTop: Settings.get("bar.position", "top") === "top"
    anchors { top: atTop; bottom: !atTop }
    // Over a dock that stands on a bottom bar: above the dock.
    margins { top: Tokens.islandHeight + 3 * Tokens.gap; bottom: Tokens.islandHeight + 3 * Tokens.gap + OsdState.dockOver(modelData.name) }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: osdContent.implicitWidth + 2 * Tokens.padding
    implicitHeight: Tokens.islandHeight + 4
    color: "transparent"
    WlrLayershell.namespace: "vitrum-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    mask: Region { item: dot }                  // never takes input
    BlurKick { id: blurKick; window: root }
    BackgroundEffect.blurRegion: Materials.wantsRegion("osd", blurKick.screen) && !blurKick.on ? effect : blurKick.none
    Region { id: effect; item: pill.opacity > 0.05 ? shape : dot; radius: pill.radius }
    // Off the screen's top-left pixel: the top-left hot corner sits there, under this layer.
    Item { id: dot; x: 2; y: 2; width: 1; height: 1 }
    Item { id: shape; x: pill.x; y: pill.y; width: pill.width; height: pill.height }

    Surface {
        id: pill
        group: "osd"
        width: parent.width
        height: Tokens.islandHeight
        radius: Tokens.radiusIsland
        y: root.showing ? 2 : root.atTop ? -height : root.height   // in from the bar's side
        opacity: root.showing ? 1 : 0
        Behavior on y { enabled: Motion.enabled; SpringAnim { token: Motion.snappy } }
        Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.fast } }

        OsdContent { id: osdContent; anchors.centerIn: parent; group: "osd" }
    }
}
