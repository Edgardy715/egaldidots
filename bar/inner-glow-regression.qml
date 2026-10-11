import QtQuick
import Quickshell
import "components"
import "Singletons"
ShellRoot {
    settings.watchFiles: false
    Window {
        visible: true
        width: 240; height: 80
        InnerGlow { id: glow; anchors.fill: parent }
    }
    property int step: 0
    property real phase: 0
    function check(value, message) {
        if (!value) { console.error("FAIL: " + message); Qt.exit(1) }
    }
    Timer {
        interval: 250; running: true; repeat: true
        onTriggered: {
            if (step === 0) { Config.update({appearance: {reduceMotion: false}}); phase = glow.driftPhase }
            else if (step === 1) {
                check(glow.driftPhase > phase, "visible glow moves")
                check(Math.abs(glow.driftX) <= 0.06 && Math.abs(glow.driftY) <= 0.04, "drift remains subtle")
                glow.visible = false; phase = glow.driftPhase
            } else if (step === 2) {
                check(glow.driftPhase === phase, "hidden glow stops")
                glow.visible = true
                Config.update({appearance: {reduceMotion: true}})
                phase = glow.driftPhase
            } else if (step === 3) {
                check(glow.driftPhase === phase && glow.driftX === 0 && glow.driftY === 0, "reduced motion is static")
                Config.update({appearance: {reduceMotion: false}})
            } else {
                check(glow.driftPhase > phase, "resume preserves phase")
                console.log("PASS: subtle glow drift, hidden pause, reduced motion and resume")
                Qt.quit()
            }
            step++
        }
    }
}
