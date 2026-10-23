import QtQuick
import Quickshell
import "Singletons"
import "components"

// QT_QPA_PLATFORM=offscreen quickshell -p bar/content-hold-regression.qml
// Redimensionar la surface abierta (resultados del launcher) no debe esconder
// su contenido; cambiar de surface, notificar o cerrar sí vuelven a exponerlo
// por crecimiento.
ShellRoot {
    PillMorphMotion {
        id: morph
        s: 1
        restW: 200; coreH: 38
        targetW: 200; targetH: 38; targetRadius: 19
        morphDuration: Motion.morph
        notifCollapseDuration: Motion.notifCollapse
        reduceMotion: Flags.reduceMotion
    }
    property real minDuringResize: 1
    function check(ok, message) {
        if (!ok) { console.error("FAIL", message); Qt.exit(1) }
    }
    Timer {
        id: sampler
        interval: 16; repeat: true
        onTriggered: minDuringResize = Math.min(minDuringResize, morph.contentProgress)
    }
    Timer {
        interval: 50; running: true
        onTriggered: {
            morph.surfaceName = "launcher"
            morph.surfaceOpen = true
            morph.targetW = 640; morph.targetH = 64
        }
    }
    Timer {
        interval: 800; running: true
        onTriggered: {
            check(morph.contentProgress === 1 && morph.contentHeld, "opened content must be revealed and held")
            sampler.start()
            morph.targetH = 420
        }
    }
    Timer {
        interval: 1500; running: true
        onTriggered: {
            sampler.stop()
            check(minDuringResize === 1, "same-surface resize must keep content (min " + minDuringResize.toFixed(3) + ")")
            // Fase 2 del cierre del launcher: destinos en reposo con la surface
            // abierta y reapertura inmediata.
            morph.targetW = 200; morph.targetH = 38
            check(!morph.contentHeld, "returning to rest must release the hold")
        }
    }
    Timer {
        interval: 2000; running: true
        onTriggered: {
            morph.targetW = 640; morph.targetH = 420
            check(morph.contentProgress < 0.5, "reopen from return must re-expose by growth")
        }
    }
    Timer {
        interval: 2700; running: true
        onTriggered: {
            check(morph.contentHeld, "reopened launcher must be held again once revealed")
            morph.surfaceName = "calendar"
            morph.targetW = 700; morph.targetH = 300
            check(!morph.contentHeld, "surface change must return to growth exposure")
        }
    }
    Timer {
        interval: 3500; running: true
        onTriggered: {
            check(morph.contentHeld, "new surface must be held once revealed")
            morph.notifAnimating = true
            check(!morph.contentHeld, "notification must release the hold")
            morph.notifAnimating = false
            morph.surfaceOpen = false
            morph.surfaceName = ""
            morph.targetW = 200; morph.targetH = 38
        }
    }
    Timer {
        interval: 4300; running: true
        onTriggered: {
            check(!morph.contentHeld && morph.contentProgress < 0.01, "closing must withdraw content")
            console.log("PASS: same-surface resize keeps content; swap, notification and close re-expose by growth")
            Qt.exit(0)
        }
    }
}
