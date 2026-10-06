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
        width: 400; height: 120
        color: "#242424"
        TopSystemStatus {
            id: rail
            x: scene.width - width - 25; y: 35
            screenName: "status-test"
            windows: []
        }
        Timer { interval: 50; running: checks.finished; onTriggered: Qt.quit() }
        TestCase {
            id: checks
            name: "TopSystemStatus"
            when: scene.visible
            property bool finished: false
            function check(ok, message) {
                if (!ok) { console.error("FAIL:", message); throw new Error(message) }
            }
            function expectEqual(actual, expected) { check(actual === expected, actual + " != " + expected) }
            function windows(classes) { return classes.map(c => ({lastIpcObject: {class: c}})) }
            function shot(name) {
                const dir = Quickshell.env("ISLA_STATUS_SHOTS")
                if (dir) grabImage(scene.contentItem).save(dir + "/" + name + ".png")
            }
            function test_apps() {
                Config.update({appearance: {reduceMotion: false}})
                wait(600)
                const base = rail.width
                const list = findChild(rail, "statusApps")
                expectEqual(list.count, 0)
                shot("empty")
                rail.windows = windows(["kitty"])
                wait(75)
                check(rail.width > base && rail.width < rail.contentWidth, "glass expands through intermediate widths")
                shot("enter")
                wait(500)
                check(rail.nameShown, "new single app shows its name")
                const expanded = rail.width
                shot("single-intro")
                wait(1900)
                check(!rail.nameShown && rail.width < expanded - 10, "intro contracts automatically")
                shot("single-compact")
                const hover = findChild(rail, "statusAppHover")
                mouseMove(hover, 13, 14)
                wait(500)
                check(rail.nameShown && rail.width > expanded - 1, "hover reveals name and expands")
                shot("single-hover")
                mouseMove(scene.contentItem, 5, 5)
                wait(500)
                check(!rail.nameShown && rail.width < expanded - 10, "leaving hover contracts")
                rail.windows = windows(["kitty", "firefox", "kitty"])
                wait(500)
                expectEqual(list.count, 2)
                check(!rail.nameShown, "multiple apps never show names")
                mouseMove(list, 13, 14)
                wait(50)
                check(!rail.nameShown, "multiple app hover stays icons only")
                mouseMove(scene.contentItem, 5, 5)
                expectEqual(rail.apps.join(","), "firefox,kitty")
                check(Math.abs(rail.width - rail.contentWidth) < 0.5)
                const icon = list.itemAtIndex(0).children[0]
                check(icon.visible && icon.status === Image.Ready, "resolved app icon must remain visible: " + icon.visible + "/" + icon.status + " x=" + list.contentX)
                shot("two")
                rail.windows = windows(["firefox"])
                wait(60)
                check(rail.width > rail.contentWidth, "glass contracts while icon leaves")
                check(!rail.nameShown, "remaining existing app does not restart intro")
                shot("remove")
                rail.windows = windows(["firefox", "kitty", "org.gnome.Nautilus"])
                wait(500)
                expectEqual(list.count, 3)
                shot("three")
                rail.windows = []
                wait(500)
                expectEqual(list.count, 0)
                check(Math.abs(rail.width - base) < 0.5, "empty width " + rail.width + " base " + base)
                shot("closed")
                Config.update({appearance: {reduceMotion: true}})
                rail.windows = windows(["kitty", "firefox"])
                wait(40)
                check(Math.abs(rail.width - rail.contentWidth) < 0.5)
                rail.availableWidth = 142
                wait(40)
                check(rail.width <= 142 && list.width > 0)
                rail.visible = false
                rail.windows = []
                wait(40)
                check(Math.abs(rail.width - base) < 0.5, "empty width " + rail.width + " base " + base)
                console.log("PASS: status app identity, entry/exit, interruption, compact width, single intro/hover, multiple icons, reduced motion and hide")
                finished = true
            }
        }
    }
}
