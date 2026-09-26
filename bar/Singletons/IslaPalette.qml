pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var raw: ({})

    property color background: "#0e0c1b"
    property color foreground: "#c2c2c6"
    property color cursor: "#c2c2c6"
    property color accent: "#D3A3A0"
    property color accentSoft: "#E5BAB7"
    property color accentStrong: "#B66B67"
    property color accentAlt: "#E7C1BD"
    property color dim: "#5d5b6f"

    property var colors: ({})

    property string wallpaper: ""

    property bool ready: false
    Component.onCompleted: {
        root.ready = true
        rlProc.running = true
    }

    property string _lastText: ""

    function _apply(txt): void {
        if (!txt || txt.length < 10) return
        if (txt === root._lastText) return
        root._lastText = txt
        try {
            var j = JSON.parse(txt)
            root.raw = j
            root.background = j.special.background
            root.foreground = j.special.foreground
            root.cursor = j.special.cursor
            var c = j.colors
            root.colors = c
            root.accent = c.color4
            root.accentSoft = c.color5
            root.accentStrong = c.color1
            root.accentAlt = c.color6
            root.dim = c.color8
            root.wallpaper = j.wallpaper || ""
        } catch (e) { }
    }

    /** Invocado por el IpcHandler "island.reloadColors" tras un cambio de wallpaper. */
    function forceReload(): void {
        rlProc.running = true
    }

    Connections {
        target: Config
        function onWalColorsFileChanged() { root.forceReload() }
    }

    Process {
        id: rlProc
        command: ["cat", Config.walColorsFile]
        running: false
        stdout: StdioCollector {
            id: rlCollector
            onStreamFinished: {
                root._apply(rlCollector.text)
            }
        }
    }
}
