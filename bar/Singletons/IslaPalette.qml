pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "Palette.js" as Palette

Singleton {
    id: root
    property var raw: ({})
    property var colors: Palette.fallback
    readonly property bool ready: true
    property bool loaded: false
    property string error: ""
    property string wallpaper: ""
    property string mode: "dark"
    readonly property color background: colors.surface
    readonly property color foreground: colors.on_surface
    readonly property color cursor: colors.on_surface
    readonly property color accent: colors.primary
    readonly property color accentSoft: colors.secondary
    readonly property color accentStrong: colors.primary
    readonly property color accentAlt: colors.tertiary
    readonly property color dim: colors.outline
    property string _lastText: ""

    function _apply(text): bool {
        if (text === _lastText && loaded) return true
        try {
            const next = Palette.parse(text)
            raw = next
            colors = next.colors
            wallpaper = next.wallpaper
            mode = next.mode
            _lastText = text
            loaded = true
            error = ""
            return true
        } catch (exception) {
            error = String(exception)
            console.warn("[Isla Matugen] " + error + "; keeping the last valid palette")
            return false
        }
    }
    function forceReload(): void { paletteFile.reload() }
    FileView {
        id: paletteFile
        path: Config.paletteFile
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root._apply(text())
        onLoadFailed: root.error = "Matugen palette unavailable; using the last valid palette"
    }
}
