import QtQuick
import QtTest
import Quickshell
import "components"
import "Singletons"
ShellRoot {
    settings.watchFiles: false
    Window {
        id: win
        visible: true; width: 380; height: 160; color: Theme.background
        Row {
            anchors.centerIn: parent; spacing: 40
            ConfirmationIndicator { id: result; width: 80; height: 80 }
            ConfirmationIndicator { id: small; width: 24; height: 24; status: "error" }
        }
        TestCase {
            name: "ConfirmationIndicator"; when: win.visible
            function test_states() {
                Config.update({appearance:{reduceMotion:false}})
                result.status = "busy"; wait(80)
                verify(!result.terminal)
                const initialSweep = result.loadingSweep
                wait(120)
                verify(Math.abs(result.loadingSweep - initialSweep) > 1)
                result.visible = false
                const frozenPhase = result.loadingPhase
                wait(60)
                compare(result.loadingPhase, frozenPhase)
                result.visible = true
                result.status = "success"; wait(150)
                verify(result.drawProgress > 0 && result.drawProgress < 1)
                result.status = "error"; wait(450)
                compare(result.drawProgress, 1)
                compare(result.signalColor.toString(), "#ff4d61")
                result.status = "busy"; wait(30)
                compare(result.drawProgress, 0)
                result.status = "success"; wait(25)
                result.visible = false; wait(40)
                compare(result.drawProgress, 1)
                result.visible = true; wait(40)
                result.progress = 0.4; result.status = "progress"; wait(400)
                verify(result.determinate && !result.terminal && !result.animating)
                verify(Math.abs(result.shownProgress - 0.4) < 0.01)
                result.progress = 0.8; wait(60)
                verify(result.shownProgress > 0.4 && result.shownProgress < 0.8) // eases between steps
                wait(350)
                result.status = "cancelled"; wait(60)
                verify(result.terminal && result.ringProgress >= 0.79) // closes from the determinate arc
                wait(450)
                compare(result.drawProgress, 1)
                compare(result.signalColor, Theme.iconSecondary)
                Config.update({appearance:{reduceMotion:true}}); wait(20)
                compare(result.drawProgress, 1)
                result.status = "error"; wait(20)
                compare(result.drawProgress, 1)
                result.status = ""; wait(20)
                verify(!result.terminal)
                console.log("PASS: confirmation progress/cancelled, success/error, retry, interruption, hidden and reduced motion")
                Qt.quit()
            }
        }
    }
}
