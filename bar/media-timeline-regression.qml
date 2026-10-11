import QtQuick
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    Window {
        visible: true
        width: 600; height: 80
        MediaTimeline { id: timeline; anchors.fill: parent; active: true; playing: true; progress: 0.4 }
    }
    Timer {
        interval: 220
        repeat: true
        running: true
        property int step: 0
        property real held: 0
        function check(value, message) { if (!value) throw new Error(message) }
        onTriggered: {
            try {
                if (step === 0) {
                    Config.update({appearance:{reduceMotion:false}})
                    check(timeline.fractionAt(-100) === 0 && timeline.fractionAt(1000) === 1, "seek bounds")
                    held = timeline.waveOffset
                } else if (step === 1) {
                    check(timeline.moving && timeline.waveOffset !== held, "playing phase")
                    timeline.playing = false
                    held = timeline.waveOffset
                } else if (step === 2) {
                    check(!timeline.moving && timeline.waveOffset === held && timeline.waveAmount < 0.01, "pause settles and stops")
                    timeline.playing = true
                    timeline.dragging = true
                    timeline.progress = 0.8
                } else if (step === 3) {
                    check(!timeline.moving && timeline.displayedProgress === 0.8, "drag follows without delay")
                    timeline.dragging = false
                    Config.update({appearance:{reduceMotion:true}})
                    held = timeline.waveOffset
                } else if (step === 4) {
                    check(!timeline.moving && timeline.waveOffset === held && timeline.waveAmount === 0, "reduced motion")
                    Config.update({appearance:{reduceMotion:false}})
                    timeline.visible = false
                    held = timeline.waveOffset
                } else if (step === 5) {
                    check(!timeline.moving && timeline.waveOffset === held, "hidden stops")
                    timeline.visible = true
                    timeline.active = false
                    timeline.progress = NaN
                } else {
                    check(!timeline.moving && timeline.boundedProgress === 0, "closed and invalid progress")
                    console.log("PASS: waveform phase, pause, immediate drag, reduced/hidden/closed and clamped seek")
                    Qt.quit()
                }
                step++
            } catch (error) { console.error("FAIL: media timeline", error); Qt.exit(1) }
        }
    }
    Timer { interval: 5000; running: true; onTriggered: Qt.exit(1) }
}
