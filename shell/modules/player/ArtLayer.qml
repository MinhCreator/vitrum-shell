import QtQuick
import qs.theme
import qs.components

/*
 * One of two layers that show a picture which changes (the full-screen
 * player's cover, and its blurred backdrop). The new picture fades in over the
 * old one, which leaves only once it is covered: never a pop, a dip to what is
 * behind, or a blank frame. With no new picture the old one eases out.
 *
 *     ArtLayer { id: a; other: b; source: root.artA; isFront: root.artFront === 0; has: …; settled: … }
 *     ArtLayer { id: b; other: a; source: root.artB; isFront: root.artFront === 1; has: …; settled: … }
 *
 * Whoever draws the picture inside says when it has loaded (`has`), and when
 * there is nothing more to wait for (`settled`: loaded, failed, or no source).
 */
Item {
    id: ply
    property string source: ""
    /// The layer the picture is coming into; the other one holds the last.
    property bool isFront: false
    /// The other layer of the pair.
    property var other: null
    property bool has: false
    property bool settled: true
    property int fade: Motion.emphasized * 2
    /// In whole: the layer under it may go.
    readonly property bool arrived: isFront && has && opacity > 0.999

    z: isFront ? 1 : 0
    opacity: isFront ? (has ? 1 : 0)
           : has && other !== null && (!other.settled || (other.has && !other.arrived)) ? 1 : 0
    Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: ply.fade } }
    visible: opacity > 0
}
