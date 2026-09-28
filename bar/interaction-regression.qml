import QtQuick
import Quickshell
import QtTest
import "components"
import "Singletons"

ShellRoot {
    Window {
        id: window
        visible: true; width: 520; height: 220
        color: Theme.background
        Item {
            id: target
            x: 30; y: 30; width: 80; height: 60
            Rectangle { anchors.fill: parent; scale: hit.motion.visualScale; color: Theme.accent; radius: 14 }
            MotionArea { id: hit; anchors.fill: parent; accessibleName: "Test action"; onClicked: checks.clicks++ }
        }
        CtrlBtn { id: media; x: 140; y: 40; iconName: "play_arrow"; primary: true; onClicked: checks.clicks++ }
        Toggle { id: toggle; x: 220; y: 45; onToggled: on => checked = on }
        Slider { id: slider; x: 30; y: 150; width: 200; knob: true; onSliderChanged: v => value = v }
        MaterialIcon { id: changing; x: 300; y: 45; iconName: "wifi_off"; font.pixelSize: 26 }
        Timer { interval: 50; running: checks.finished; onTriggered: Qt.quit() }
        TestCase {
            id: checks
            name: "Interaction"
            when: window.visible
            property int clicks: 0
            property bool finished: false
            function check(ok, message) {
                if (!ok) { console.error("FAIL: interaction", message); throw new Error(message) }
            }
            function equal(a, b) { check(a === b, String(a) + " != " + String(b)) }
            function test_controls() {
                wait(100)
                mouseMove(target, 40, 30)
                tryCompare(hit, "containsMouse", true)
                mousePress(target, 40, 30)
                wait(100)
                check(hit.motion.visualScale < 0.99)
                equal(target.width, 80)
                equal(hit.width, 80)
                mouseRelease(target, 40, 30)
                equal(clicks, 1)
                wait(220)
                check(Math.abs(hit.motion.visualScale - 1) < 0.003)
                mousePress(target, 40, 30)
                mouseMove(target, 120, 30)
                mouseRelease(target, 120, 30)
                equal(clicks, 1)
                hit.enabled = false
                mouseClick(target, 40, 30)
                equal(clicks, 1)
                hit.enabled = true
                hit.forceActiveFocus()
                keyClick(Qt.Key_Space)
                equal(clicks, 2)
                media.forceActiveFocus()
                keyPress(Qt.Key_Space)
                wait(90)
                check(media.keyboardDown, "media keyboard pressure")
                keyRelease(Qt.Key_Space)
                equal(clicks, 3)
                mouseClick(slider, 8, slider.height / 2)
                equal(slider.value, 0)
                mouseClick(slider, 192, slider.height / 2)
                equal(slider.value, 1)
                mouseClick(toggle, 20, 12)
                equal(toggle.checked, true)
                changing.iconName = "wifi"
                wait(50)
                check(changing.swapProgress > 0 && changing.swapProgress < 1)
                changing.iconName = "bluetooth"
                wait(300)
                equal(changing.displayedIcon, "bluetooth")
                equal(changing.outgoingIcon, "")
                Config.update({appearance: {reduceMotion: true}})
                changing.iconName = "wifi_off"
                equal(changing.swapProgress, 1)
                mousePress(target, 40, 30)
                equal(hit.motion.visualScale, 1)
                mouseRelease(target, 40, 30)
                console.log("PASS: pointer, cancellation, keyboard, toggle, fixed hitbox, icon interruption and reduced motion")
                finished = true
            }
        }
    }
}
