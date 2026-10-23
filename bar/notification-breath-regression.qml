import QtQuick
import Quickshell
import "Singletons"
import "components"

// QT_QPA_PLATFORM=offscreen quickshell -p bar/notification-breath-regression.qml
// El brillo/radio de respiración entra y sale del hold sin saltos y el hold de
// lectura no se acorta con reduceMotion.
ShellRoot {
    PillMorphMotion {
        id: morph
        s: 1
        targetW: 300; targetH: 72; targetRadius: 18
        notifCollapseDuration: Motion.notifCollapse
        reduceMotion: Flags.reduceMotion
    }
    property real lastGlow: 0
    property real lastRadius: 0
    property real maxGlowStep: 0
    property real maxRadiusStep: 0
    property int phase: 0
    function check(ok, message) {
        if (!ok) { console.error("FAIL", message); Qt.exit(1) }
    }
    Timer {
        interval: 16; repeat: true; running: true
        onTriggered: {
            maxGlowStep = Math.max(maxGlowStep, Math.abs(morph.breathGlow - lastGlow))
            maxRadiusStep = Math.max(maxRadiusStep, Math.abs(morph.breathRadius - lastRadius))
            lastGlow = morph.breathGlow
            lastRadius = morph.breathRadius
        }
    }
    Timer { interval: 50; running: true; onTriggered: morph.notifHolding = true }
    Timer {
        interval: 1550; running: true
        onTriggered: {
            check(morph.holdLevel > 0.99 && morph.breathGlow > 0.12, "hold must reach full glow")
            morph.notifHolding = false
        }
    }
    Timer {
        interval: 2300; running: true
        onTriggered: {
            check(morph.holdLevel === 0 && morph.breathGlow === 0 && morph.breathRadius === 0,
                  "collapse-out must end without residual glow")
            check(maxGlowStep < 0.05, "glow must not jump (step " + maxGlowStep.toFixed(3) + ")")
            check(maxRadiusStep < 0.5, "breath radius must not jump (step " + maxRadiusStep.toFixed(3) + ")")
            check(Motion.notifHoldMin === 1000 && Motion.notifHoldMax === 2000, "reading hold is unscaled")
            Config.update({ appearance: { reduceMotion: true } })
            check(Motion.notifHoldMin === 1000 && Motion.notifHoldMax === 2000,
                  "reduced motion must not shorten the reading hold")
            morph.notifHolding = true
            check(morph.holdLevel === 1, "reduced motion resolves hold level directly")
            morph.notifHolding = false
            Config.update({ appearance: { reduceMotion: false } })
            console.log("PASS: breath enters/leaves hold continuously; reading hold unscaled")
            Qt.exit(0)
        }
    }
}
