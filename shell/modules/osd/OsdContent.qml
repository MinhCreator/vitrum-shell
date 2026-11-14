import QtQuick
import qs.services
import qs.theme
import qs.components
import "../../lib/osd.js" as OsdLib
import "../../lib/keyboard.js" as Kb

/*
 * What the on-screen display says (OsdState), the same in the bar's drop and
 * in the overlay pill. A value is its icon, a meter and the number; the
 * keyboard layout is its name in the row of all of them, the lit piece moving
 * to it. Another kind cross-fades here: the glass around it stays as it is.
 */
Item {
    id: root
    /// The material group it lies on: "bar" in the drop, "osd" in the pill.
    property string group: "bar"
    readonly property bool layout: OsdState.kind === "layout"

    implicitWidth: Tokens.islandHeight * 9 - 2 * Tokens.padding
    implicitHeight: Tokens.islandHeight
    width: implicitWidth
    height: implicitHeight

    Item {
        id: gauge
        anchors.fill: parent
        opacity: root.layout ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.fast } }

        Icon {
            id: glyph
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            name: OsdState.icon
            // Muted is off: colourless, like any glass that is not lit.
            color: OsdState.muted ? Colors.textDim : Colors.accent
        }
        Meter {
            anchors { left: glyph.right; leftMargin: Tokens.gap; right: amount.left; rightMargin: Tokens.gap; verticalCenter: parent.verticalCenter }
            group: root.group
            value: OsdState.value
            opacity: OsdState.muted ? 0.35 : 1
            Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.fast } }
        }
        Label {
            id: amount
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            // A fixed width: the meter does not move as the digits come and go.
            width: Math.round(Tokens.textSize * 3.5)
            horizontalAlignment: Text.AlignRight
            numeric: true
            text: OsdState.text
        }
    }

    Item {
        id: layouts
        anchors.fill: parent
        opacity: root.layout ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.fast } }

        Icon {
            id: keys
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            name: "keyboard"
            color: Colors.accent
        }
        Item {
            id: strip
            anchors { left: keys.right; leftMargin: Tokens.gap; right: parent.right; top: parent.top; bottom: parent.bottom }
            clip: true

            // Every layout, always: a row that showed only those that fit was
            // built again with other names on each switch, and jumped. When
            // the full names are too wide, all of them go short (EN RU UA);
            // when even that is, the row slides to keep the current one in view.
            readonly property bool compact: probe.implicitWidth > width
            readonly property int current: Math.max(0, Math.min(names.count - 1, Layouts.index))
            readonly property Item cell: names.count > 0 ? names.itemAt(current) : null
            Row {
                id: probe
                visible: false
                Repeater {
                    model: Layouts.names
                    Label { required property string modelData; text: modelData; rightPadding: strip.cellPad }
                }
            }
            readonly property real cellPad: Math.round(Tokens.padding * 1.5)

            // The light passes across the lit piece once as it arrives.
            Connections { target: Layouts; function onIndexChanged() { if (layouts.visible) lit.sweep(); } }
            Item {
                id: band
                width: row.width
                height: parent.height
                // In the middle of the whole drop, under the island, while that
                // keeps clear of the icon; else in the middle of what is left
                // beside it (and sliding, when even that is too narrow).
                readonly property real middle: Math.round((layouts.width - row.width) / 2 - strip.x)
                x: middle >= 0 && row.width <= strip.width ? middle
                   : OsdLib.rowOffset(strip.cell ? strip.cell.x : 0, strip.cell ? strip.cell.width : 0, row.width, strip.width)
                Behavior on x { enabled: Motion.enabled && layouts.visible; SpringAnim { token: Motion.snappy } }
                ShellTint {
                    id: lit
                    visible: strip.cell !== null
                    anchors.verticalCenter: parent.verticalCenter
                    x: strip.cell ? strip.cell.x : 0
                    width: strip.cell ? strip.cell.width : 0
                    height: Tokens.islandHeight - Tokens.gap
                    radius: Tokens.radiusButton
                    group: root.group
                    Behavior on x { enabled: Motion.enabled && layouts.visible; SpringAnim { token: Motion.snappy } }
                    Behavior on width { enabled: Motion.enabled && layouts.visible; SpringAnim { token: Motion.snappy } }
                }
                Row {
                    id: row
                    Repeater {
                        id: names
                        model: Layouts.names
                        delegate: Item {
                            id: entry
                            required property string modelData
                            required property int index
                            width: cellLabel.implicitWidth + strip.cellPad
                            height: strip.height
                            Label {
                                id: cellLabel
                                anchors.centerIn: parent
                                text: strip.compact ? (Layouts.shortNames[entry.index] || Kb.shortName(entry.modelData)) : entry.modelData
                                role: entry.index === strip.current ? "text" : "dim"
                            }
                        }
                    }
                }
            }
        }
    }
}
