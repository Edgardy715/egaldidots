import QtQuick
import QtTest
import Quickshell
import "components"

ShellRoot {
    settings.watchFiles: false
    Window {
        id: scene
        visible: true
        width: 640
        height: 200
        PillHeaderView {
            id: header
            anchors.fill: parent
            now: new Date(2026, 9, 5, 12, 45)
        }
        SignalSpy { id: calendar; target: header; signalName: "requestCalendar" }
        PillMorphMotion {
            id: motion
            targetW: 100
            targetH: 38
            targetRadius: 19
            restW: 100
            coreH: 38
            morphDuration: 250
            notifCollapseDuration: 80
        }
        Timer { interval: 50; running: checks.finished; onTriggered: Qt.quit() }
        TestCase {
            id: checks
            name: "PillComposition"
            when: scene.visible
            property bool finished: false
            function test_header_and_motion() {
                try {
                    wait(80)
                    verify(header.restContentWidth > 0)
                    mouseClick(header, header.width / 2, header.height / 2)
                    compare(calendar.count, 1)
                    const restWidth = header.restContentWidth
                    header.flashWorkspace(10)
                    wait(300)
                    verify(header.workspaceAnimating)
                    verify(header.restContentWidth > restWidth)
                    verify(header.restContentWidth <= restWidth + 44)
                    header.surface = "launcher"
                    header.launcherHeaderVisible = true
                    header.hasMedia = true
                    header.title = "Injected title"
                    header.artist = "Injected artist"
                    header.launcherHeaderH = 78
                    wait(100)

                    motion.surfaceOpen = true
                    motion.targetW = 400
                    motion.targetH = 200
                    motion.targetRadius = 24
                    wait(60)
                    verify(motion.width > 100 && motion.width < 400)
                    const midWidth = motion.width
                    motion.targetW = 100
                    motion.targetH = 38
                    compare(motion.width, midWidth)
                    wait(35)
                    motion.targetW = 320
                    motion.targetH = 180
                    wait(500)
                    verify(Math.abs(motion.width - 320) < 0.01)
                    verify(Math.abs(motion.height - 180) < 0.01)
                    verify(motion.closeness > 0.99 && motion.contentProgress > 0.99)
                    compare(motion.lastSurfaceW, 320)
                    compare(motion.lastSurfaceH, 180)

                    motion.surfaceOpen = false
                    motion.workspaceAnimating = true
                    motion.targetW = 144
                    compare(motion.width, 144)
                    motion.notifAnimating = true
                    motion.notifHolding = true
                    compare(motion.duration, 80)
                    wait(100)
                    verify(motion.breath > 0)
                    motion.reduceMotion = true
                    motion.targetW = 100
                    motion.targetH = 38
                    motion.targetRadius = 19
                    compare(motion.width, 100)
                    compare(motion.height, 38)
                    compare(motion.radius, 19)
                    const breath = motion.breath
                    wait(80)
                    compare(motion.breath, breath)
                    motion.notifHolding = false
                    compare(motion.breathRadius, 0)
                    compare(motion.breathGlow, 0)
                    console.log("PASS: injected header/calendar input, workspace width, interrupted morph, exposure, reduced motion and notification breath")
                    finished = true
                } catch (error) {
                    console.error("FAIL: pill composition", error)
                    Qt.callLater(() => Qt.exit(1))
                }
            }
        }
    }
    Timer { interval: 5000; running: true; onTriggered: { console.error("FAIL: pill composition timeout"); Qt.exit(1) } }
}
