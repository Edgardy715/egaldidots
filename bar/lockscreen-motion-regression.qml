import QtQuick
import Quickshell
import "lockscreen"
import "Singletons"

ShellRoot {
    id: test
    property real previous: 0
    property bool sawRejection: false
    property int exitFinishedCount: 0
    property int submitted: 0
    property real maxDrop: 0
    property int step: 0
    property int waits: 0
    function check(ok, message) {
        if (!ok) { console.error("FAIL: " + message); Qt.exit(1) }
    }
    function capture(name) {
        const directory = Quickshell.env("ISLA_LOCK_CAPTURE_DIR")
        if (directory) surface.grabToImage(result => result.saveToFile(directory + "/" + name + ".png"))
    }
    function find(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children) {
            const found = find(child, name)
            if (found) return found
        }
        return null
    }
    Window {
        visible: true; width: 1200; height: 900
        title: "Isla · Prueba de movimiento del bloqueo"
        LockSurface {
            id: surface
            anchors.fill: parent
            username: "Vista previa"
            avatarSource: ""
            wallpaper: Quickshell.env("ISLA_LOCK_WALLPAPER")
            secured: true
            preview: true
            onUnlockRequested: secret => { test.submitted++; test.check(secret === "x", "submit forwards the typed secret once") }
            onBlobScaleChanged: test.maxDrop = Math.max(test.maxDrop, blobScale)
            onFieldOffsetChanged: if (Math.abs(fieldOffset) > 0.5) test.sawRejection = true
            onExitFinished: test.exitFinishedCount++
        }
    }
    FrameAnimation {
        running: surface.presentation > 0 && surface.presentation < 1
        onTriggered: {
            test.check(surface.travel >= surface.expansion, "travel leads growth")
            if (surface.contentOpacity > 0 && !surface.retiring)
                test.check(surface.expansion > 0.84, "input waits for sufficient geometry")
            const body = test.find(surface, "lockBody")
            if (surface.capWidth > 200) test.check(body.width <= surface.capWidth + 1 && body.height <= surface.capH + 1 && Math.abs(body.x + body.width / 2 - surface.width / 2) < 1, "auth surface stays one centered capsule ")
        }
    }
    Timer {
        interval: 100; repeat: true; running: true
        onTriggered: {
            // La gota tarda Motion.fast + Motion.standard en formarse: espera (acotado) antes de comprobar.
            if (test.step === 13 && test.maxDrop <= 0.9 && test.waits++ < 30) return
            if (test.step === 16 && (!test.sawRejection || Math.abs(surface.fieldOffset) > 0.01) && test.waits++ < 60) return
            if (test.step === 27 && test.exitFinishedCount === 0 && test.waits++ < 150) return
            switch (test.step++) {
            case 0:
                test.check(surface.presentation === 0 && !surface.authActive, "secured lock starts at rest")
                test.capture("01-pill")
                surface.activateInput("")
                break
            case 1:
                test.check(surface.presentation > 0 && surface.presentation < 1, "pill expands through intermediate geometry")
                test.capture("02-expanding")
                test.previous = surface.presentation
                surface.entered = false
                test.check(Math.abs(surface.presentation - test.previous) < 0.01, "interruption preserves position")
                break
            case 2:
                test.previous = surface.presentation
                surface.entered = true
                test.check(Math.abs(surface.presentation - test.previous) < 0.01, "reopen preserves position")
                break
            case 9:
                test.check(surface.presentation > 0.99, "opening settles")
                test.check(Math.abs(test.find(surface, "lockBody").width - surface.capWidth) < 2 && Math.abs(test.find(surface, "lockBody").height - surface.capH) < 2, "capsule settles at its own size")
                test.capture("03-ready")
                break
            case 10:
                surface.activateInput("x")
                break
            case 11:
                test.check(test.find(surface, "lockPasswordDots").model.count === 1, "typing creates one visual dot")
                surface.attemptUnlock()
                test.check(test.submitted === 1 && surface.gathering, "submit gathers the beads into one drop")
                test.check(test.find(surface, "lockPasswordDotViewport").visible, "the drop stays visible after the secret is cleared")
                surface.busy = true
                break
            case 13:
                test.check(test.maxDrop > 0.9, "the drop forms while PAM works")
                surface.busy = false
                surface.errorText = "Contraseña incorrecta. Inténtalo de nuevo."
                break
            case 14: test.capture("04-rejected"); break
            case 15: test.check(surface.blobDrain > 0.2, "rejection drains the drop downward"); break
            case 16:
                test.check(test.sawRejection && Math.abs(surface.fieldOffset) < 0.01, "rejection recoils and settles")
                surface.errorText = ""
                surface.authenticated = true
                break
            case 19:
                test.check(!surface.gathering && surface.blobScale === 0 && surface.blobDrain === 0, "the drained drop resets")
                test.check(surface.successProgress > 0.5 && !surface.departing, "success shown before departure")
                test.check(test.exitFinishedCount === 0, "unlock is not released before the return to the desktop")
                test.capture("05-success")
                break
            case 22:
                test.check(surface.retiring && (!surface.departing || surface.contentOpacity <= 0.001), "content withdraws before collapse")
                test.capture("06-return")
                break
            case 27:
                test.check(surface.departing && surface.cardT < 0.01, "success returns to pill")
                test.check(test.exitFinishedCount === 1, "return to the desktop releases the lock exactly once")
                test.capture("07-pill-return")
                break
            case 29:
                test.check(Config.update({appearance: {reduceMotion: true}}).ok, "temporary config ready")
                surface.authenticated = false
                surface.retiring = false
                surface.entered = false
                surface.entered = true
                surface.errorText = "Otro error"
                break
            case 31:
                test.check(surface.presentation === 1 && surface.fieldOffset === 0, "reduced motion resolves geometry without recoil")
                console.log("PASS: lockscreen morph interruption, rejection, success ordering, return and reduced motion")
                Qt.quit()
            }
        }
    }
}
