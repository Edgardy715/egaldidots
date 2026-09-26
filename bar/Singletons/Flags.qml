pragma Singleton
import Quickshell

// Compatibility facade: settings have one owner, Config. New editors use
// Config.update/discard/save; consumers cannot break bindings by assigning here.
Singleton {
    readonly property real glassAlpha: Config.appearance.glassAlpha
    readonly property bool pillBlur: Config.appearance.pillBlur
    readonly property real topGap: Config.appearance.topGap
    readonly property real appGap: Config.appearance.appGap
    readonly property real uiScale: Config.appearance.uiScale
    readonly property real fontScale: Config.appearance.fontScale
    readonly property real spacingScale: Config.appearance.spacingScale
    readonly property real radiusScale: Config.appearance.radiusScale
    readonly property real motionScale: Config.appearance.motionScale
    readonly property string fontFamily: Config.appearance.fontFamily
    readonly property string fontMonoFamily: Config.appearance.fontMonoFamily
    readonly property string fontDisplayFamily: Config.appearance.fontDisplayFamily
    readonly property bool reduceMotion: Config.appearance.reduceMotion
    readonly property bool time12h: Config.appearance.time12h
    readonly property bool clockSeconds: Config.appearance.clockSeconds
    readonly property bool showGlyphs: Config.appearance.showGlyphs
    readonly property string fontMediaFamily: Config.appearance.fontMediaFamily
}
