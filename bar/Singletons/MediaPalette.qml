pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// One derived palette for the selected player, shared by all media compositions.
Singleton {
    id: root
    property string source: Players.isMusicSource ? Players.artUrl : ""
    property string handledSource: ""
    property string loadingSource: ""
    property var extracted: null
    property bool canceling: false
    property bool succeeded: false
    property int retryCount: 0
    property int requestTimeout: 12000
    readonly property color base: extracted || Theme.accent
    readonly property bool dark: Theme.cardBot.hslLightness < 0.5
    readonly property color target: extracted ? Qt.hsla(Math.max(0, base.hslHue),
        base.hslSaturation < 0.08 ? 0 : Math.max(0.38, Math.min(0.75, base.hslSaturation)),
        dark ? 0.70 : 0.36, 1) : Theme.accent
    property color accent: target
    Behavior on accent {
        ColorAnimation { id: fade; duration: Flags.reduceMotion || !Flags.mediaTransitions ? 0 : Motion.emphasizedLarge }
    }
    Connections {
        target: Flags
        function onReduceMotionChanged() { if (Flags.reduceMotion) fade.complete() }
        function onMediaTransitionsChanged() { if (!Flags.mediaTransitions) fade.complete() }
    }
    function sync() {
        if (!source) { extracted = null; handledSource = ""; return }
        if (debounce.running || retryDelay.running || extractor.running || source === handledSource) return
        loadingSource = source
        handledSource = source
        succeeded = false
        extractor.running = true
        watchdog.restart()
    }
    onSourceChanged: {
        retryDelay.stop()
        watchdog.stop()
        retryCount = 0
        handledSource = ""
        if (!source) extracted = null
        if (extractor.running && loadingSource !== source) {
            canceling = true
            extractor.running = false
        }
        debounce.restart()
    }
    Component.onCompleted: debounce.start()
    Timer { id: debounce; interval: 120; onTriggered: root.sync() }
    Timer { id: watchdog; objectName: "mediaPaletteWatchdog"; interval: root.requestTimeout; onTriggered: extractor.running = false }
    Timer { id: retryDelay; interval: 800; onTriggered: root.sync() }
    Process {
        id: extractor
        command: ["python3", decodeURIComponent(Qt.resolvedUrl("../services/artwork_palette.py").toString().replace(/^file:\/\//, "")), root.loadingSource]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text)
                    if (!root.canceling && result.source === root.source) {
                        root.succeeded = typeof result.color === "string" && /^#[0-9a-f]{6}$/i.test(result.color)
                        root.extracted = root.succeeded ? result.color : null
                    }
                } catch (error) { if (root.loadingSource === root.source) root.extracted = null }
            }
        }
        onExited: code => {
            watchdog.stop()
            const obsolete = root.canceling || root.loadingSource !== root.source
            root.canceling = false
            if (!obsolete && (!root.succeeded || code !== 0)) {
                root.extracted = null
                if (root.source && root.retryCount < 2) {
                    root.retryCount++
                    root.handledSource = ""
                    retryDelay.interval = 800 * root.retryCount
                    retryDelay.restart()
                }
            }
            Qt.callLater(root.sync)
        }
    }
}
