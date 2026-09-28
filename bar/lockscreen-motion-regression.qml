import QtQuick
import Quickshell
import "lockscreen"
import "Singletons"

ShellRoot {
    id: test
    property real previous: 0
    property bool sawRejection: false
    property int step: 0
    function check(ok, message) {
        if (!ok) { console.error("FAIL: " + message); Qt.exit(1) }
    }
    function capture(name) {
        const directory = Quickshell.env("ISLA_LOCK_CAPTURE_DIR")
        if (directory) surface.grabToImage(result => result.saveToFile(directory + "/" + name + ".png"))
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
            onUnlockRequested: test.check(false, "fixture must not submit")
            onFieldOffsetChanged: if (Math.abs(fieldOffset) > 0.5) test.sawRejection = true
        }
    }
    FrameAnimation {
        running: surface.presentation > 0 && surface.presentation < 1
        onTriggered: {
            test.check(surface.travel >= surface.expansion, "travel leads growth")
            if (surface.contentOpacity > 0 && !surface.retiring)
                test.check(surface.expansion > 0.84, "input waits for sufficient geometry")
        }
    }
    Timer {
        interval: 100; repeat: true; running: true
        onTriggered: {
            switch (test.step++) {
            case 0:
                test.capture("01-pill")
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
                test.capture("03-ready")
                surface.errorText = "Contraseña incorrecta. Inténtalo de nuevo."
                break
            case 10: test.capture("04-rejected"); break
            case 13:
                test.check(test.sawRejection && Math.abs(surface.fieldOffset) < 0.01, "rejection recoils and settles")
                surface.errorText = ""
                surface.authenticated = true
                break
            case 16:
                test.check(surface.successProgress > 0.5 && !surface.departing, "success shown before departure")
                test.capture("05-success")
                break
            case 19:
                test.check(surface.retiring && (!surface.departing || surface.contentOpacity <= 0.001), "content withdraws before collapse")
                test.capture("06-return")
                break
            case 24:
                test.check(surface.departing && surface.presentation < 0.01, "success returns to pill")
                test.capture("07-pill-return")
                break
            case 26:
                test.check(Config.update({appearance: {reduceMotion: true}}).ok, "temporary config ready")
                surface.authenticated = false
                surface.retiring = false
                surface.entered = false
                surface.entered = true
                surface.errorText = "Otro error"
                break
            case 28:
                test.check(surface.presentation === 1 && surface.fieldOffset === 0, "reduced motion resolves geometry without recoil")
                console.log("PASS: lockscreen morph interruption, rejection, success ordering, return and reduced motion")
                Qt.quit()
            }
        }
    }
}
