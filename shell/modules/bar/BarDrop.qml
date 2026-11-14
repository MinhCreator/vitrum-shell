import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.services
import qs.theme
import qs.components
import "../../lib/drop.js" as Drop

/*
 * One drop of the bar's glass: a sheet hanging from an island on a short neck
 * (lib/drop.js). The bar has two, an open panel and the on-screen display, and
 * gives each its island, its target and its progress; this holds the pieces —
 * the tint along the outline, the neck, the sheet with what it shows — and
 * their regions, for the bar's glass and its input.
 *
 * It fills the bar's window: a Region reads its item's own x and y.
 */
Item {
    id: root
    default property alias content: sheet.data
    readonly property alias sheet: sheet

    /// 0 island … 1 open, and whether any of it is drawn.
    property real t: 0
    property bool shown: false
    property bool shaped: false
    property bool atTop: true
    property string screenName: ""
    /// The island (x, width) and the open sheet (x, width, height), bar frame.
    property real islandX: 0
    property real islandW: 1
    property real targetX: 0
    property real targetW: 0
    property real targetH: 0
    /// What niri rounds every piece with in shaped mode, and its fillets.
    property real pieceRadius: Tokens.islandRadius
    property real fillet: Tokens.islandRadius
    /// The sheet's corners where it is its own surface.
    property real radius: Tokens.radiusPanel
    /// Under a sheet narrower than the island the neck narrows onto it.
    property bool narrow: false
    /// No island to hang from: the sheet alone, under the bar.
    property bool detached: false

    /// One piece with its island (shaped glass): the outline carries the tint.
    readonly property bool merges: shaped && shown && !detached
    readonly property var islandFrame: ({ x: islandX, y: Tokens.gap, w: islandW, h: Tokens.islandHeight })
    readonly property var geo: Drop.dropGeometry(islandFrame, { x: targetX, w: targetW, h: targetH }, t, Tokens.gap, narrow ? pieceRadius : 0)
    readonly property var neckRect: Drop.mirrorRect(geo.neck, !atTop, height)
    readonly property var sheetRect: Drop.mirrorRect(geo.sheet, !atTop, height)
    readonly property real sheetRadius: Math.min(shaped ? pieceRadius : radius, sheet.width / 2, sheet.height / 2)

    /// For the bar's effect region (none while nothing is drawn), and its mask.
    readonly property alias sheetRegion: sheetRegion
    readonly property var regions: !shown ? [] : merges ? [neckRegion, sheetRegion] : [sheetRegion]
    Region { id: neckRegion; item: neck }
    Region { id: sheetRegion; item: sheet; radius: root.shaped ? 0 : root.sheetRadius }

    // The tint along the drop's outline (shaped glass), under everything else.
    Shape {
        anchors.fill: parent
        z: -1
        visible: root.merges
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: Materials.fill("bar", 0, root.screenName)
            // A narrowed neck is a rectangle lapping over island and sheet.
            fillRule: ShapePath.WindingFill
            PathSvg {
                path: root.merges ? Drop.dropPath(root.islandFrame, root.geo.sheet, root.pieceRadius, root.fillet, !root.atTop, root.height,
                                                  root.narrow ? root.geo.neck : null) : ""
            }
        }
    }

    Item { id: neck; x: root.neckRect.x; y: root.neckRect.y; width: root.neckRect.w; height: root.neckRect.h }

    Item {
        id: sheet
        x: root.sheetRect.x; y: root.sheetRect.y
        width: root.sheetRect.w; height: root.sheetRect.h
        visible: root.shown
        clip: true

        // Not merged with an island, the sheet is its own rounded surface.
        Surface {
            anchors.fill: parent
            visible: !root.merges
            group: "bar"
            radius: root.sheetRadius
        }
    }
}
