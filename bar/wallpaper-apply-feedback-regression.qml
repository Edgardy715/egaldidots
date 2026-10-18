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
        width: 440; height: 380
        Rectangle {
            id: stage
            width: 440; height: 380
            color: Theme.background
            WallpaperApplyFeedback { id: feedback; anchors.centerIn: parent }
        }
        TestCase {
            id: checks
            name: "WallpaperApplyFeedback"
            when: window.visible
            property bool finished: false
            function check(value, message) { if (!value) { console.error("FAIL: wallpaper confirmation", message); Qt.exit(1); throw new Error(message) } }
            function capture(name) {
                const dir = Quickshell.env("ISLA_TEST_OUTPUT")
                if (!dir) return
                let saved = false
                stage.grabToImage(result => { saved = result.saveToFile(dir + "/" + name + ".png") })
                tryVerify(() => saved, 3000)
            }
            function test_confirmation() {
                Config.update({appearance:{reduceMotion:false}})
                feedback.phase = "preparing"; wait(300)
                check(feedback.visible && feedback.busy, "loading is visible")
                capture("apply-preparing")
                feedback.phase = "transition"; wait(100)
                feedback.phase = "done"; wait(180)
                check(feedback.success && feedback.checkProgress > 0 && feedback.checkProgress < 1, "check draws progressively: " + feedback.checkProgress)
                capture("apply-check-drawing")
                wait(400)
                check(feedback.checkProgress === 1 && feedback.success, "green confirmation completed")
                capture("apply-success")
                feedback.phase = ""; wait(300)
                check(!feedback.visible, "confirmation releases presentation")
                feedback.phase = "preparing"; wait(60)
                feedback.phase = "error"; feedback.errorText = "El fondo cambió, pero no se actualizaron los colores."
                wait(300); check(feedback.failed && !feedback.success, "error never confirms success")
                capture("apply-error")
                Config.update({appearance:{reduceMotion:true}})
                feedback.phase = "done"; wait(30)
                check(feedback.checkProgress === 1, "reduced motion resolves check immediately")
                feedback.allowed = false; wait(30)
                check(!feedback.visible, "auth/fullscreen can suppress feedback")
                console.log("PASS: wallpaper loading, progressive green check, failure, reduced motion and hidden state")
                finished = true
            }
        }
        Timer { interval: 100; running: checks.finished; onTriggered: Qt.quit() }
    }
}
