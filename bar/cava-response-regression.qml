import QtQuick
import Quickshell
import "components"
import "Singletons"
import "Singletons/Spectrum.js" as Spectrum
ShellRoot {
    settings.watchFiles: false
    readonly property bool liveAudio: Quickshell.env("ISLA_CAVA_LIVE") === "1"
    readonly property var displayedLevels: liveAudio ? Cava.values : levels
    property var levels: Array(24).fill(0)
    property real elapsed: 0
    Window {
        id: stage
        visible: true
        width: 640; height: 500
        color: Theme.background
        IslandMediaVisualizer {
            x: 30; y: 20; s: 2; coreH: 60
            hasMedia: true; isPlaying: true; hasFrame: true; values: displayedLevels
        }
        MediaView {
            x: 110; y: 10; width: 500; height: 480
            open: true; musicPresentation: true; cavaAvailable: true; cavaHasFrame: true
            cavaValues: displayedLevels
            Component.onCompleted: playback = Object.assign({}, playback, {hasPlayer: true, isPlaying: true, title: "Respuesta al audio", artist: "Graves · medios · agudos"})
        }
    }
    FrameAnimation {
        running: !liveAudio
        onTriggered: {
            elapsed += frameTime
            let target = []
            for (let i = 0; i < 24; i++)
                target.push(elapsed % 1 < 0.18 ? 0.8 * Math.exp(-i / 18) : 0.08)
            levels = Spectrum.advance(levels, target, frameTime)
        }
    }
    Component.onDestruction: Cava.setConsumer("cava-live-regression", false)
    Component.onCompleted: {
        if (liveAudio) Cava.setConsumer("cava-live-regression", true)
        function check(ok, message) { if (!ok) throw new Error(message) }
        check(Spectrum.parse("1 2 bad", 3) === null, "invalid frame")
        check(Spectrum.parse("65536 0 0", 3) === null, "range")
        check(Spectrum.parse("0 65535 0", 3)[1] === 0.5, "spatial grouping")
        check(Spectrum.parse("0 0 0", 3).every(v => v === 0), "silence")
        check(Spectrum.parse("20 20 20", 3)[0] > 0, "quiet audio precision")
        check(Spectrum.parse("6553 6553 6553", 3)[0] > 0.5, "perceptual range")
        let a = [0], b = [0]
        for (let i = 0; i < 30; i++) a = Spectrum.advance(a, [1], 1 / 30)
        for (let i = 0; i < 144; i++) b = Spectrum.advance(b, [1], 1 / 144)
        check(Math.abs(a[0] - b[0]) < 1e-10, "refresh independent")
        check(Spectrum.advance([1], [], 3)[0] < 0.0001, "stale decay")
        check(Math.abs(Spectrum.band([0, 1, 0, 1], 0, 2) - Math.sqrt(0.5)) < 1e-10, "band average")
        console.log("PASS: spectrum validation, grouping, refresh independence and stale decay")
    }
    Timer {
        interval: 1150; running: true
        onTriggered: stage.contentItem.grabToImage(result => result.saveToFile(Quickshell.env("ISLA_TEST_OUTPUT") + "/attack.png"))
    }
    Timer {
        interval: 1600; running: true
        onTriggered: stage.contentItem.grabToImage(result => result.saveToFile(Quickshell.env("ISLA_TEST_OUTPUT") + "/release.png"))
    }
    Timer {
        interval: 2100; running: true
        onTriggered: {
            if (liveAudio) {
                if (!Cava.hasFrame || !Cava.values.some(v => v > 0)) {
                    console.error("FAIL live audio frames/envelope")
                    Qt.exit(1)
                    return
                }
                console.log("PASS live selected-player capture and render envelope", JSON.stringify(Cava.values))
            }
            Qt.quit()
        }
    }
}
