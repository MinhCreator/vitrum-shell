import QtQuick
import qs.services
import qs.theme
import qs.components

// Now playing (the bar's panel): the player card, and a switch when several play.
Item {
    id: root
    width: Tokens.islandHeight * 12
    // Where the card is heading, not where it is: the bar eases its sheet to
    // this on the curve the card's parts fold on (PlayerCard.settledHeight),
    // so lyrics that arrive move the sheet and what is in it as one.
    implicitHeight: card.settledHeight + (switches.visible ? switches.height + column.spacing : 0)

    Column {
        id: column
        width: root.width
        spacing: Tokens.gap

        PlayerCard { id: card; width: root.width; height: implicitHeight; expandable: true }

        // A Flow, not a Row: with many sources (a browser's tabs, a game, a
        // music app) a row ran past the panel's edge and the rest could not be reached.
        Flow {
            id: switches
            visible: Media.players.length > 1
            width: root.width
            spacing: Tokens.gap / 2
            Repeater {
                model: Media.players
                GlassButton {
                    required property var modelData
                    // Two of the same app (two tabs) are told apart by what they play.
                    // (Cut by the letter: a name longer than the panel ran out of it.)
                    label: Media.sourceLabel(modelData)
                    primary: modelData === Media.current
                    onClicked: Media.setPlayer(modelData)
                }
            }
        }
    }
    // Position updates while visible.
    Timer { interval: 1000; running: Media.playing && !GameMode.active; repeat: true; onTriggered: if (Media.current) Media.current.positionChanged() }
}
