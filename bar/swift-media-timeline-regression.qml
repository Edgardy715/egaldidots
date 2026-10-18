import QtQuick
import QtTest
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    Window {
        id: scene
        visible: true
        width: 520; height: 112
        color: Theme.cardBot
        QtObject {
            id: sessionOrder
            property bool dragging: false
            property real dragFraction: 0.8
            property real position: 0
            readonly property real progress: dragging ? dragFraction : position / 120
        }
        SwiftMediaTimeline {
            id: orderTimeline
            x: 36; y: 80; width: 448; height: 24
            opacity: 0
            active: true
            length: 120
            dragging: sessionOrder.dragging
            progress: sessionOrder.progress
        }
        SwiftMediaTimeline {
            id: timeline
            x: 36; y: 36; width: 448; height: 32
            active: true
            length: 120
            position: 48
            progress: 0.4
            displayTime: "0:48"
            onSeekRequested: value => {
                position = value
                progress = value / length
            }
            onDragStarted: fraction => { dragging = true; progress = fraction }
            onDragMoved: fraction => progress = fraction
            onDragCommitted: fraction => {
                dragging = false
                position = fraction * length
                progress = fraction
            }
            onDragCanceled: dragging = false
        }
        SignalSpy { id: seeks; target: timeline; signalName: "seekRequested" }
        SignalSpy { id: starts; target: timeline; signalName: "dragStarted" }
        SignalSpy { id: moves; target: timeline; signalName: "dragMoved" }
        SignalSpy { id: commits; target: timeline; signalName: "dragCommitted" }
        SignalSpy { id: cancels; target: timeline; signalName: "dragCanceled" }
        TestCase {
            id: checks
            name: "SwiftMediaTimeline"
            when: scene.visible
            property bool finished: false
            function check(value, message) {
                if (!value) { console.error("FAIL: " + message); Qt.exit(1); throw new Error(message) }
            }
            function shot(name) {
                const directory = Quickshell.env("ISLA_TEST_OUTPUT")
                if (!directory) return
                let saved = false
                timeline.grabToImage(image => {
                    saved = image.saveToFile(directory + "/" + name + ".png")
                }, Qt.size(timeline.width * 2, timeline.height * 2))
                tryVerify(() => saved, 1500)
            }
            function test_squiggle_and_seek() {
                try {
                Config.update({appearance: {reduceMotion: false, mediaTransitions: true}})
                const input = findChild(timeline, "mediaSeek")
                const clock = findChild(timeline, "swiftTimelineClock")
                const thumb = findChild(timeline, "swiftTimelineThumb")
                const tail = findChild(timeline, "swiftTimelineTail")
                check(input && clock && thumb && tail, "controls available")
                compare(timeline.restThickness, 4)
                compare(timeline.expandedThickness, 6)
                compare(timeline.wavelength, 34)
                compare(timeline.position, 48)
                check(timeline.fractionAt(-50) === 0 && timeline.fractionAt(999) === 1,
                    "fraction clamps to track")
                shot("01-rest")

                timeline.playing = true
                tryVerify(() => clock.running)
                timeline.length = 0
                check(!clock.running, "unsupported duration stops phase clock")
                timeline.length = 120
                tryVerify(() => clock.running)
                wait(480)
                check(timeline.waveAmount > 0.95, "playing develops the wave")
                const phase = timeline.phaseOffset
                const phaseStart = Date.now()
                wait(100)
                const phaseAdvance = (timeline.phaseOffset - phase + timeline.wavelength) % timeline.wavelength
                const expectedAdvance = timeline.wavelength * (Date.now() - phaseStart) / 1600
                check(Math.abs(phaseAdvance - expectedAdvance) < 1.5,
                    "wave phase follows elapsed time")
                compare(timeline.position, 48, "timeline does not invent playback time")
                shot("02-playing")

                timeline.playing = false
                const pausedPhase = timeline.phaseOffset
                check(!clock.running, "pause stops phase clock")
                wait(450)
                compare(timeline.phaseOffset, pausedPhase)
                check(timeline.waveAmount < 0.01, "pause flattens wave")
                shot("03-paused")

                mouseMove(input, timeline.trackInset + timeline.trackWidth * 0.6, 16)
                tryVerify(() => thumb.opacity > 0.9)
                tryCompare(timeline, "thickness", 6)
                shot("04-hover")
                mousePress(input, timeline.trackInset + timeline.trackWidth * 0.6, 16)
                check(timeline.dragging && starts.count === 1, "press begins scrub")
                mouseMove(input, timeline.trackInset + timeline.trackWidth * 0.8, 16)
                wait(30)
                check(moves.count > 0 && Math.abs(timeline.displayedProgress - 0.8) < 0.01,
                    "scrub tracks pointer precisely")
                mouseRelease(input, timeline.trackInset + timeline.trackWidth * 0.8, 16)
                check(commits.count === 1 && !timeline.dragging, "release commits once")
                check(Math.abs(timeline.position - 96) < 0.5, "release position")
                input.forceActiveFocus()
                keyClick(Qt.Key_Right)
                check(seeks.count === 1 && Math.abs(timeline.position - 101) < 0.5,
                    "keyboard seeks five seconds")
                keyClick(Qt.Key_Home)
                compare(timeline.position, 0)
                compare(timeline.displayedProgress, 0, "Home paints zero immediately")
                keyClick(Qt.Key_End)
                compare(timeline.position, 120)
                compare(timeline.displayedProgress, 1, "End paints full progress immediately")

                timeline.playing = true
                tryVerify(() => clock.running)
                timeline.visible = false
                check(!clock.running, "hidden timeline stops clock")
                const hiddenPhase = timeline.phaseOffset
                wait(100)
                compare(timeline.phaseOffset, hiddenPhase)
                timeline.visible = true
                tryVerify(() => clock.running)
                Config.update({appearance: {reduceMotion: true}})
                tryVerify(() => !clock.running)
                check(timeline.waveAmount < 0.01, "reduced motion flattens wave")
                shot("05-reduced")

                Config.update({appearance: {reduceMotion: false, mediaTransitions: false}})
                tryVerify(() => !clock.running)
                Config.update({appearance: {reduceMotion: false, mediaTransitions: true}})
                timeline.playing = false
                timeline.progress = 0.8
                compare(timeline.displayedProgress, 0.8)
                timeline.progress = 0
                compare(timeline.displayedProgress, 0, "new track starts at zero immediately")
                timeline.progress = 0.5 / timeline.length
                compare(timeline.displayedProgress, timeline.progress, "half-second seek is exact")
                timeline.progress = 0.06 / timeline.length
                compare(timeline.displayedProgress, timeline.progress, "normal 60 ms advance is exact")
                timeline.progress = 0.18 / timeline.length
                compare(timeline.displayedProgress, timeline.progress, "rate-two advance is exact")
                timeline.progress = 0.6
                compare(timeline.displayedProgress, 0.6, "large seek is exact")
                timeline.length = 240
                timeline.progress = 0
                compare(timeline.displayedProgress, 0, "length and track change remain exact")
                timeline.length = 120

                sessionOrder.dragging = true
                compare(orderTimeline.displayedProgress, 0.8)
                sessionOrder.dragging = false
                sessionOrder.position = 72
                compare(orderTimeline.displayedProgress, 0.6,
                    "drag release uses the committed position immediately")

                // When the pointer loses its track, the old release must not seek.
                mousePress(input, timeline.trackInset + timeline.trackWidth * 0.3, 16)
                check(timeline.pointerDown && timeline.dragging, "second scrub begins")
                const beforeCancel = cancels.count
                const beforeCommit = commits.count
                timeline.length = 90
                check(cancels.count === beforeCancel + 1 && !timeline.pointerDown && !timeline.dragging,
                    "length change cancels the active scrub")
                mouseRelease(input, timeline.trackInset + timeline.trackWidth * 0.9, 16)
                compare(commits.count, beforeCommit, "stale release does not commit")
                timeline.length = 120

                mousePress(input, timeline.trackInset + timeline.trackWidth * 0.4, 16)
                check(timeline.pointerDown && timeline.dragging, "third scrub begins")
                timeline.length = 0
                check(!timeline.pointerDown && !timeline.dragging && !timeline.enabled,
                    "lost seek support cancels scrub")
                mouseRelease(input, timeline.trackInset + timeline.trackWidth * 0.9, 16)
                compare(commits.count, beforeCommit, "unsupported track cannot commit")
                timeline.length = 120

                mousePress(input, timeline.trackInset + timeline.trackWidth * 0.4, 16)
                check(timeline.pointerDown && timeline.dragging, "fourth scrub begins")
                timeline.dragging = false
                check(!timeline.pointerDown, "external session cancellation clears pointer")
                mouseRelease(input, timeline.trackInset + timeline.trackWidth * 0.9, 16)
                compare(commits.count, beforeCommit, "external cancellation cannot commit")

                const endTail = findChild(orderTimeline, "swiftTimelineTail")
                const endPlayed = findChild(orderTimeline, "swiftTimelinePlayed")
                sessionOrder.position = 0
                check(!orderTimeline.handleShown && Math.abs(endTail.x - orderTimeline.trackInset) < 0.01,
                    "zero progress has no leading hole")
                sessionOrder.position = 120
                check(Math.abs(endPlayed.width - orderTimeline.trackWidth) < 0.01,
                    "full progress reaches the end")
                Config.discard()
                console.log("PASS: Swift timeline exact progress, elapsed wave phase, scrub cancellation and endpoints")
                finished = true
                } catch (error) {
                    console.error("FAIL: " + error + " " + error.stack)
                    Qt.exit(1)
                    throw error
                }
            }
        }
        Timer { interval: 80; running: checks.finished; onTriggered: Qt.quit() }
        Timer { interval: 12000; running: true; onTriggered: { console.error("FAIL: Swift timeline timeout"); Qt.exit(1) } }
    }
}
