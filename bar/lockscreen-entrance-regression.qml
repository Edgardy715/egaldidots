import QtQuick
import Quickshell
import "lockscreen"
import "Singletons"

ShellRoot {
    id: test
    property int step: 0
    property int waits: 0
    property bool narrow: false
    function check(ok, message) {
        if (!ok) { console.error("FAIL: " + message); Qt.exit(1) }
    }
    function find(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children) {
            const match = find(child, name)
            if (match) return match
        }
        return null
    }
    function capture(name) {
        const directory = Quickshell.env("ISLA_LOCK_CAPTURE_DIR")
        if (directory) surface.grabToImage(result => result.saveToFile(directory + "/" + name + ".png"))
    }
    QtObject {
        id: player
        property bool isPlaying: true
        property string trackTitle: "En la misma ciudad"
        property string trackArtist: "Álvaro Díaz"
        property bool canControl: true
        property bool canTogglePlaying: true
        property bool canGoPrevious: true
        property bool canGoNext: true
        property bool positionSupported: true
        property bool lengthSupported: true
        property bool canSeek: true
        property real length: 240
        property real rate: 1
        property real position: 42
        function togglePlaying() { isPlaying = !isPlaying }
        function previous() {}
        function next() {}
    }
    Window {
        id: window
        visible: true; width: 1200; height: 900
        title: "Isla · Entrada al bloqueo"
        visibility: Quickshell.env("ISLA_LOCK_WIDE") === "1" ? Window.FullScreen : Window.Windowed
        color: "#090b11"
        LockSurface {
            id: surface
            width: test.narrow ? Math.min(380, parent.width) : parent.width
            height: parent.height
            username: "Vista previa"; avatarSource: ""
            wallpaper: Quickshell.env("ISLA_LOCK_WALLPAPER")
            preview: true; player: player
            artUrl: Quickshell.env("ISLA_LOCK_ART")
            onUnlockRequested: test.check(false, "preview never submits authentication")
        }
    }
    Timer {
        interval: 100; repeat: true; running: true
        onTriggered: {
            // La entrada dura 2*Motion.morph: espera a que termine antes de la comprobación.
            if (test.step === 8 && surface.entrance < 1 && test.waits++ < 120) return
            switch (test.step++) {
            case 0:
                test.check(surface.entrance === 0, "entrance waits for compositor security")
                surface.activateInput("x")
                test.check(!surface.authActive, "insecure input rejected")
                surface.secured = true
                break
            case 2:
                test.check(surface.entrance > 0 && surface.entrance < 1, "entrance has intermediate frames")
                test.capture("01-entering")
                break
            case 8:
                test.check(surface.entrance === 1 && surface.restingMedia === 1, "clock and playing media settle ")
                {
                    const clock = test.find(surface, "lockRestClock")
                    const media = test.find(surface, "lockMedia")
                    test.check(media.visible && clock.y + clock.height < media.y, "clock and media capsule remain separate")
                    test.check(Math.abs(media.x + media.width / 2 - surface.width / 2) < 1, "media capsule is centred")
                }
                test.capture("02-clock-player")
                player.togglePlaying()
                break
            case 9:
                test.check(surface.restingMedia > 0 && surface.restingMedia < 1, "pause withdraws smoothly")
                player.togglePlaying()
                break
            case 14:
                test.check(surface.restingMedia === 1, "resume retargets without stale state")
                surface.activateInput("")
                break
            case 22:
                test.check(surface.restingMedia === 0 && surface.presentation === 1, "auth owns media after rest withdraws")
                test.capture("03-auth-player")
                surface.authActive = false
                break
            case 30:
                test.check(surface.restingMedia === 1 && surface.presentation === 0, "idle returns with playing media")
                surface.player = null
                break
            case 31:
                test.check(test.find(surface, "lockMedia").player !== null && surface.mediaShow > 0, "vanished player capsule retained during withdrawal")
                break
            case 35:
                test.check(surface.restingMedia === 0, "player disappearance settles")
                test.capture("06-no-media")
                break
            case 36:
                test.check(Config.update({appearance: {reduceMotion: true}}).ok, "temporary reduced motion setting")
                surface.entered = false
                surface.player = player
                surface.entered = true
                break
            case 38:
                test.check(surface.entrance === 1 && surface.restingMedia === 1, "reduced motion resolves immediately")
                test.narrow = true
                surface.activateInput("")
                break
            case 40:
                test.check(test.find(surface, "lockMedia").hasPlayer && test.find(surface, "lockMedia").visible, "narrow auth media uses injected player")
                const seek = test.find(test.find(surface, "lockMedia"), "lockMediaSeek")
                seek.value = 0.5
                seek.moved()
                test.check(Math.abs(player.position - 120) < 0.1, "seek control forwards supported position")
                test.capture("04-narrow-player")
                console.log("PASS: lock entrance security gate, playing media, pause/resume interruption, auth handoff, disappearance and reduced motion")
                break
            case 42:
                player.trackTitle = "Una canción con un título especialmente largo para comprobar la composición"
                player.trackArtist = "Un artista con nombre largo"
                player.canGoNext = false
                surface.artUrl = "file://" + Quickshell.env("ISLA_LOCK_WALLPAPER")
                test.check(Config.update({appearance: {fontScale: 1.75}}).ok, "large text setting")
                surface.errorText = "Contraseña incorrecta. Revisa los caracteres e inténtalo de nuevo."
                break
            case 44: {
                const media = test.find(surface, "lockMedia")
                const text = test.find(media, "lockMediaMetadata")
                const controls = test.find(media, "lockMediaControls")
                test.check(text.x + text.width <= controls.x, "long metadata stays beside controls")
                test.check(text.y >= 0 && text.y + text.height <= media.height, "metadata fits enlarged capsule")
                test.check(controls.y >= 0 && controls.y + controls.height <= media.height, "controls fit enlarged capsule")
                const feedback = test.find(surface, "lockFeedback")
                test.check(feedback.y + feedback.implicitHeight <= media.y, "long error stays above the media capsule")
                test.capture("05-large-text-player")
                break
            }
            case 46: Qt.quit()
            }
        }
    }
}
