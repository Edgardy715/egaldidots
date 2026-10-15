import QtQuick
import QtTest
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    QtObject {
        id: player
        property bool isPlaying: false
        property bool canControl: true
        property bool canSeek: true
        property bool positionSupported: true
        property bool lengthSupported: true
        property real length: 120
        property real position: 0
    }
    MediaSession { id: session; player: player; active: false }
    Window {
        id: scene
        visible: true
        width: 600; height: 80
        color: "#17191c"
        Item {
            id: stage
            width: 600; height: 80
            anchors.centerIn: parent
            Rectangle { anchors.fill: parent; color: "#17191c" }
            MediaTimeline {
                id: timeline
                anchors.fill: parent
                active: true; playing: false; progress: 0.4; length: 120
                onSeekRequested: value => session.seekTo(value)
                onDragStarted: fraction => session.beginDrag(fraction)
                onDragMoved: fraction => session.dragFraction = fraction
                onDragCommitted: fraction => session.commitDrag(fraction)
                onDragCanceled: session.cancelDrag()
            }
        }
        TestCase {
            id: checks
            name: "PixelMediaTimeline"
            when: scene.visible
            property bool finished: false
            function check(condition, message) {
                if (!condition) { console.error("FAIL: PixelMediaTimeline", message); Qt.exit(1); throw new Error(message) }
            }
            function same(actual, expected, message) { check(actual === expected, (message || "comparison") + ": " + actual + " != " + expected) }
            function shot(name) {
                const directory = Quickshell.env("ISLA_TEST_OUTPUT")
                if (!directory) return
                let saved = false
                stage.grabToImage(image => {
                    saved = image.saveToFile(directory + "/" + name + ".png")
                }, Qt.size(stage.width * 3, stage.height * 3))
                tryVerify(() => saved, 1000)
            }
            function phaseDistance(start, end) {
                return (end - start + timeline.wavelength) % timeline.wavelength
            }
            function test_pixel_motion() {
                Config.update({appearance:{reduceMotion:false}})
                wait(80)
                same(timeline.wavelength, 20)
                same(timeline.amplitude, 1.5)
                same(timeline.strokeWidth, 2)
                same(timeline.waveAmount, 0)
                check(timeline.fractionAt(-100) === 0 && timeline.fractionAt(1000) === 1)
                shot("00-flat")
                timeline.playing = true
                wait(30)
                same(timeline.waveAmount, 0, "Android's 60ms entrance delay")
                wait(170)
                check(timeline.waveAmount > 0.5 && timeline.waveAmount < 1)
                shot("01-enter")
                wait(750)
                same(timeline.waveAmount, 1)
                const start = timeline.waveOffset
                const startedAt = Date.now()
                wait(250)
                const distance = phaseDistance(start, timeline.waveOffset)
                check(Math.abs(distance - (Date.now() - startedAt) / 1000 * 8) < 0.5,
                    "Android's 8dp/s phase velocity")
                shot("02-playing")
                timeline.playing = false
                const pausedPhase = timeline.waveOffset
                const pauseStart = Date.now()
                for (let i = 0; i < 10; i++) {
                    wait(55)
                    same(timeline.waveOffset, pausedPhase)
                    console.log("PIXEL_FRAME pause", Date.now() - pauseStart, timeline.waveAmount)
                    if (i === 2) shot("pause-mid")
                }
                wait(150)
                same(timeline.waveAmount, 0)
                shot("pause-flat")
                timeline.playing = true
                wait(180)
                const beforeReverse = timeline.waveAmount
                timeline.playing = false
                same(timeline.waveAmount, beforeReverse, "pause retargets from current height")
                wait(90)
                const beforeResume = timeline.waveAmount
                timeline.playing = true
                same(timeline.waveAmount, beforeResume, "resume preserves current height")
                wait(30)
                same(timeline.waveAmount, beforeResume)
                wait(900)
                timeline.dragging = true
                timeline.progress = 0.8
                same(timeline.displayedProgress, 0.8, "scrub is immediate")
                const dragPhase = timeline.waveOffset
                wait(750)
                same(timeline.waveOffset, dragPhase)
                same(timeline.waveAmount, 0)
                shot("03-drag")
                timeline.dragging = false
                wait(900)
                timeline.progress = 0
                check(timeline.displayedProgress > 0.7, "track reset starts from old progress")
                wait(300)
                check(timeline.displayedProgress > 0 && timeline.displayedProgress < 0.3)
                shot("04-reset")
                wait(500)
                same(timeline.displayedProgress, 0)
                check(timeline.moving, "playing at zero still animates like Android")
                Config.update({appearance:{reduceMotion:true}})
                same(timeline.waveAmount, 0)
                const reducedPhase = timeline.waveOffset
                wait(100)
                same(timeline.waveOffset, reducedPhase)
                timeline.progress = 0.95
                same(timeline.displayedProgress, 0.95)
                shot("05-reduced")
                Config.update({appearance:{reduceMotion:false}})
                wait(150)
                timeline.visible = false
                const hiddenPhase = timeline.waveOffset
                wait(150)
                same(timeline.waveAmount, 0)
                same(timeline.waveOffset, hiddenPhase)
                timeline.visible = true
                wait(100)
                timeline.active = false
                timeline.progress = NaN
                same(timeline.boundedProgress, 0)
                same(timeline.displayedProgress, 0)
                same(timeline.waveAmount, 0)
                check(!timeline.moving)
                timeline.active = true
                timeline.playing = false
                timeline.progress = Qt.binding(() => session.progress)
                timeline.dragging = Qt.binding(() => session.dragging)
                wait(80)
                session.beginDrag(0.8)
                same(timeline.displayedProgress, 0.8)
                session.commitDrag(0.8)
                wait(300)
                same(timeline.displayedProgress, 0.8, "real commit from zero does not trigger track reset")
                player.position = 0
                wait(900)
                session.beginDrag(0.8)
                session.cancelDrag()
                wait(30)
                same(timeline.displayedProgress, 0, "cancel restores the real position immediately")
                const input = findChild(timeline, "mediaSeek")
                check(input !== null, "seek input exists")
                mousePress(input, timeline.trackInset + timeline.trackWidth * 0.6, 40)
                check(session.dragging, "pointer press begins scrub")
                mouseMove(input, timeline.trackInset + timeline.trackWidth * 0.8, 40)
                mouseRelease(input, timeline.trackInset + timeline.trackWidth * 0.8, 40)
                wait(100)
                check(!session.dragging && Math.abs(timeline.displayedProgress - 0.8) < 0.002, "pointer release commits without reverse reset")
                timeline.position = Qt.binding(() => session.displayPosition)
                input.forceActiveFocus()
                keyClick(Qt.Key_Right)
                check(player.position > 100 && player.position < 102, "keyboard seeks forward five seconds")
                keyClick(Qt.Key_Home)
                same(player.position, 0)
                keyClick(Qt.Key_End)
                same(player.position, 120)
                console.log("PASS: Android16 dimensions, phase velocity, delayed amplitude, pause/resume interruption, scrub, track reset, reduced/hidden/closed")
                finished = true
            }
        }
        Timer { interval: 100; running: checks.finished; onTriggered: Qt.quit() }
    }
    Timer { interval: 18000; running: true; onTriggered: { console.error("FAIL: pixel timeline timeout"); Qt.exit(1) } }
}
