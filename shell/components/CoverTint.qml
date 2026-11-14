import QtQuick
import Quickshell
import qs.services
import qs.theme

/*
 * The cover's most vivid colour, for the player's wave and spectrum (the
 * card and the full-screen player). The accent while there is no cover.
 *
 *     CoverTint { id: cover }
 *     color: cover.tint
 */
Item {
    id: root
    visible: false

    // Eased: the cover's colour arrives a moment after the cover, and the wave
    // and the spectrum would flip to it.
    property color tint: pick
    Behavior on tint { enabled: Motion.enabled; ColorAnim { duration: Motion.standard } }
    readonly property color pick: {
        let best = Colors.accent, score = -1;
        // No cover: the last one's colours are still in the quantizer.
        if (!Media.artUrl) return best;
        for (const c of quant.colors) {
            const s = c.hsvSaturation * (0.35 + c.hsvValue);
            if (c.hsvValue > 0.3 && s > score) { score = s; best = c; }
        }
        return best;
    }

    ColorQuantizer {
        id: quant
        source: Media.artUrl
        depth: 3
        rescaleSize: 48
    }
}
