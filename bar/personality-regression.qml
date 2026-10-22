import QtQuick
import QtTest
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    Window {
        id: window
        visible: true
        width: 1000; height: 720
        color: Theme.background
        Pill {
            id: pill
            anchors.horizontalCenter: parent.horizontalCenter
            y: 42
            screenName: "personality-fixture"
            notificationsEnabled: false
        }
        IslandCompanion { id: eyes; x: 32; y: 32; visible: false }
        Timer { id: exitTimer; interval: 120; onTriggered: Qt.quit() }
        TestCase {
            name: "IslandPersonality"
            when: Config.loaded && window.visible
            function shot(name) {
                const dir = Quickshell.env("ISLA_TEST_OUTPUT")
                if (!dir || !dir.length) return
                window.contentItem.grabToImage(result => result.saveToFile(dir + "/" + name + ".png"))
                wait(60)
            }
            function check(ok, message) { if (!ok) throw new Error(message || "condition failed") }
            function eventually(callback, timeout, message) {
                let elapsed = 0
                while (!callback() && elapsed < timeout) { wait(25); elapsed += 25 }
                check(callback(), message || "eventual condition failed")
            }
            function test_receptionAndActivity() {
                try {
                DesktopStatus.monitorServices = false
                Config.update({appearance: {reduceMotion: false, personality: true}})
                wait(900)
                eventually(() => pill.restHeaderOpacity > 0.99 && Math.abs(pill.width - pill.restW) < 1, 4000, "rest settles before capture")
                shot("rest")
                const restWidth = pill.restCenterWidth
                const activityHit = findChild(pill, "islandActivityHit")
                const companion = findChild(pill, "activityCompanion")
                check(activityHit && companion, "companion control exists")
                mouseMove(activityHit, activityHit.width / 2, activityHit.height / 2)
                wait(550)
                check(companion.engaged, "hover engages the expression")
                check(Math.abs(pill.restCenterWidth - restWidth) < 1, "hover keeps header geometry")
                shot("companion-hover")
                activityHit.forceActiveFocus()
                check(companion.engaged && activityHit.activeFocus, "keyboard has equivalent feedback")
                shot("companion-focus")
                pill.hovered = true
                pill.pointerX = pill.width
                pill.pointerY = pill.height
                wait(200)
                shot("look-right")
                pill.lastBatteryStatus = "discharging"
                DesktopStatus.batteryOSD(67, "charging")
                check(pill.activityNotice === qsTr("Cargando · %1%").arg(67), "battery event reaches charging notice")
                check(pill.receiving, "charging starts finite reception")
                wait(160)
                shot("charge-early")
                wait(180)
                shot("charge-wave")
                eventually(() => pill.restCenterWidth > restWidth, 1200)
                eventually(() => !pill.receiving, 4000, "pulse stops without idle clock")
                shot("charge-settled")
                pill.surface = "focus"
                eventually(() => pill.surfaceItem !== null, 3000)
                wait(700)
                shot("focus")
                for (let frame = 0; frame < 10; frame++) {
                    if (frame === 0) pill.surfaceItem.feedbackRequested("received")
                    wait(80)
                    shot("pulse-" + String(frame).padStart(2, "0"))
                }
                pill.surfaceItem.feedbackRequested("received")
                check(pill.receiving, "surface result reaches shared material")
                wait(230)
                shot("focus-reception")
                pill.respond("received")
                wait(90)
                check(pill.receiving, "repeat retargets pulse")
                Config.update({appearance: {reduceMotion: true}})
                check(!pill.receiving, "reduced motion cancels running pulse")
                pill.respond("received")
                check(!pill.receiving, "reduced result remains still")
                eyes.visible = true
                eyes.reduced = true
                eyes.lookX = 1
                check(eyes.gazeX === 0, "reduced gaze")
                check(eyes.lid === 1, "reduced blink")
                pill.surface = ""
                wait(100)
                Config.update({appearance: {personality: false}})
                pill.activityNotice = ""
                wait(150)
                check(pill.restCenterWidth < restWidth, "companion can be disabled")
                Config.update({appearance: {personality: true, reduceMotion: false}})
                pill.respond("received")
                check(pill.receiving)
                pill.visible = false
                check(!pill.receiving, "hidden material stops pulse")
                console.log("PASS: reception, charging, shared surface feedback, eyes, reduced motion, visibility and opt-out")
                exitTimer.start()
                } catch (error) { console.error("FAIL: personality " + error); Qt.exit(1) }
            }
        }
    }
}
