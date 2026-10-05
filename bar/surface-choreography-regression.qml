import QtQuick
import QtTest
import Quickshell
import "Singletons"
import "components"

ShellRoot {
    settings.watchFiles: false
    Window {
        id: scene
        visible: true; width: 1100; height: 760
        color: "#161820"
        title: "Isla · Coreografía de superficies"
        Rectangle { anchors.fill: parent; color: scene.color }
        Pill { id: pill; x: (scene.width - width) / 2; y: 24; s: 1; screenName: "motion-preview" }
        Item {
            x: 20; y: 650; width: 180; height: 40
            StaggerItem {
                id: row; anchors.fill: parent; entered: false; staggerIndex: 20
                Rectangle { anchors.fill: parent; color: "steelblue"; radius: 12 }
            }
        }
        TestCase {
            id: checks
            name: "SurfaceChoreography"
            when: scene.visible
            function host() {
                let item = pill.surfaceItem
                while (item && item.displayedSurface === undefined) item = item.parent
                return item
            }
            function capture(name) {
                const directory = Quickshell.env("ISLA_MOTION_CAPTURE_DIR")
                if (directory) scene.contentItem.grabToImage(result => result.saveToFile(directory + "/" + name + ".png"))
            }
            function test_choreography() {
                Config.update({appearance: {reduceMotion: false, motionScale: 1}})
                wait(80)
                pill.surface = "calendar"
                wait(180); capture("01-opening")
                wait(140); capture("01b-revealing")
                tryVerify(() => pill.surfaceItem !== null && host().loadReveal === 1, 1800)
                wait(400); capture("02-calendar")
                const oldHost = host()
                pill.surface = "mixer"
                wait(80)
                capture("02b-withdrawing")
                pill.surface = "utils"
                wait(85)
                compare(oldHost.displayedSurface, "utils", "latest destination commits without restarting withdrawal")
                tryVerify(() => pill.surfaceItem !== null && oldHost.loadReveal === 1, 1500)
                wait(350); capture("03-utils")
                if (Quickshell.env("ISLA_MOTION_CAPTURE_DIR")) wait(1600)
                pill.surface = "calendar"
                wait(40)
                pill.surface = "utils"
                wait(220)
                compare(oldHost.displayedSurface, "utils", "return to current panel cancels pending swap")
                row.entered = true
                wait(240)
                verify(row.progress > 0 && row.progress < 1)
                const before = row.progress
                row.entered = false
                verify(Math.abs(row.progress - before) < 0.01, "exit retains position")
                wait(30)
                row.entered = true
                Config.update({appearance: {reduceMotion: true}})
                compare(row.progress, 1, "reduced motion completes an in-flight stagger")
                pill.surface = "mixer"
                compare(oldHost.displayedSurface, "mixer", "reduced swap has no timer")
                tryVerify(() => pill.surfaceItem !== null, 1500)
                compare(oldHost.loadReveal, 1)
                pill.surface = ""
                tryVerify(() => pill.surfaceItem === null, 500)
                console.log("PASS: asynchronous reveal, latest swap, cancellation, stagger retarget and live reduced motion")
            }
            function cleanupTestCase() { Qt.callLater(Qt.quit) }
        }
    }
}
