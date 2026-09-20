pragma Singleton
import QtQuick
import Quickshell

/**
 * Isla · Flags. Tunables de sesión/aspecto. El vidrio translúcido vive en
 * glassAlpha: 0.34 → 66% del wallpaper se ve, blurred por el compositor
 * (puente waybar `alpha(@background,0.30)` · Ricelin pillOpacity:1.0).
 * Subir para más sólido, bajar para más "vidrio骨架". Con ignore_alpha 0.15
 * (windowRules.conf) el blur agarra todo el glass a partir de alpha > 0.15.
 */
Singleton {
    // glassAlpha: clamp 0.15–1.0 (min 0.15 porque con menos el blur del
    // compositor no alcanza; max 1.0 = totalmente sólido)
    property real glassAlpha: 0.34
    onGlassAlphaChanged: {
        if (glassAlpha < 0.15) glassAlpha = 0.15
        else if (glassAlpha > 1.0) glassAlpha = 1.0
    }

    property bool pillBlur: false      // blur del compositor; sin blur QML (== Ricelin Flags.pillBlur)

    // topGap/appGap: fracciones positivas, sin límite superior (el usuario sabe)
    property real topGap: 1.0
    onTopGapChanged: if (topGap < 0) topGap = 0

    property real appGap: 1.0
    onAppGapChanged: if (appGap < 0) appGap = 0

    property real uiScale: 1.0         // escala global (multimonitor base 1080p)
    onUiScaleChanged: if (uiScale < 0.25) uiScale = 0.25

    // reduceMotion: 0.28 = más agresivo que antes (0.4) para personas que
    // prefieren animaciones sutiles o con mareos
    property bool reduceMotion: false

    property bool time12h: true
    property bool clockSeconds: false
    property bool showGlyphs: true
}
