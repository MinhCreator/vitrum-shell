import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.components
import qs.common

Page {
    title: "Media"
    subtitle: "The player in the bar, on the desktop and on the lock screen."
    Section {
        title: "Lyrics"
        SettingToggle { key: "media.lyrics"; label: "Synced lyrics"; hint: "From lrclib.net: in the player and on the lock screen." }
        SettingToggle { key: "media.lyricsInBar"; needs: "media.lyrics"; label: "The line being sung in the bar"; hint: "Instead of the track's title, while lyrics are found."; divider: false }
    }
    Section {
        title: "Player"
        SettingToggle { key: "media.visualizer"; label: "Spectrum in the player"; hint: "Needs cava." }
        SettingChoice {
            key: "media.playerScreen"; label: "Full-screen player on"
            hint: "Follows you: the screen you are on. Or keep it on one, and work on another; the pin in the player does the same."
            values: [""].concat(Quickshell.screens.map(s => s.name)); names: ({ "": "Follows you" })
            divider: false
        }
    }
}
