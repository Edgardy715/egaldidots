import QtQuick
import Quickshell
import Quickshell.Io
import "lockscreen"
import "Singletons"

// Visual QA for the lock screen: plays the whole choreography in a preview
// window (secure → rest → access → typing → error → success → unlock) and saves
// numbered frames to ISLA_LOCK_CAPTURE_DIR. It never acquires the session lock
// or starts PAM: every state is set directly on LockSurface.
//
//   ISLA_CONFIG=/tmp/isla-lock.json ISLA_LOCK_CAPTURE_DIR=/tmp/lock-frames \
//   [ISLA_LOCK_SNAPSHOT=/tmp/desk.png] [ISLA_LOCK_WIDE=1] quickshell -p bar/lockscreen-filmstrip.qml
//
// Frames are grabbed from the scene graph, so they show what each tick renders,
// not presentation timing. Use them for continuity, not for FPS.
ShellRoot {
    id: test
    readonly property string directory: Quickshell.env("ISLA_LOCK_CAPTURE_DIR") || ""
    readonly property int frameStep: Number(Quickshell.env("ISLA_LOCK_FRAME_MS")) || 40
    property string wallpaper: Quickshell.env("ISLA_LOCK_WALLPAPER") || ""
    property double origin: Date.now()
    property string phase: "boot"
    property int shot: 0
    property double exitFinishedAt: -1

    function find(item, name) {
        if (!item) return null
        if (item.objectName === name) return item
        for (const child of item.children) {
            const match = find(child, name)
            if (match) return match
        }
        return null
    }
    function capture(label) {
        if (!directory || !window.contentItem) return
        const name = String(shot++).padStart(3, "0") + "-" + test.phase + "-" + String(Date.now() - origin).padStart(5, "0") + (label ? "-" + label : "")
        window.contentItem.grabToImage(result => result.saveToFile(directory + "/" + name + ".png"), Qt.size(window.width / 2, window.height / 2))
    }

    FileView {
        path: Config.paletteFile
        printErrors: false
        onLoaded: {
            if (test.wallpaper) return
            try { test.wallpaper = JSON.parse(text()).wallpaper || "" } catch (e) {}
        }
    }

    QtObject {
        id: player
        property bool isPlaying: Quickshell.env("ISLA_LOCK_MEDIA") === "1"
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
        visible: true
        width: Number(Quickshell.env("QS_LOCK_PREVIEW_WIDTH")) || 1440
        height: Number(Quickshell.env("QS_LOCK_PREVIEW_HEIGHT")) || 900
        visibility: Quickshell.env("ISLA_LOCK_WIDE") === "1" ? Window.FullScreen : Window.Windowed
        title: "Isla · Película del bloqueo"
        color: "black"

        LockSurface {
            id: surface
            anchors.fill: parent
            username: "isla"
            wallpaper: test.wallpaper
            player: player
            preview: true
            secured: false
            onExitFinished: if (test.exitFinishedAt < 0) test.exitFinishedAt = Date.now() - test.origin
        }
    }

    Timer {
        id: frames
        interval: test.frameStep
        repeat: true
        onTriggered: test.capture("")
    }

    // [delay before the step, action]. Frames run continuously from `secure`.
    property var script: [
        [700, () => {
            const snapshot = Quickshell.env("ISLA_LOCK_SNAPSHOT")
            if (snapshot) surface.snapshotSource = "file://" + snapshot
            test.origin = Date.now()
            test.phase = "enter"
            test.capture("start")
            surface.secured = true
            frames.start()
        }],
        [1500, () => { test.phase = "rest"; test.capture("settled") }],
        [400, () => { test.phase = "access"; surface.activateInput("") }],
        [900, () => { test.phase = "typing"; test.find(surface, "lockPassword").insert(0, "c") }],
        [110, () => test.find(surface, "lockPassword").insert(1, "o")],
        [110, () => test.find(surface, "lockPassword").insert(2, "r")],
        [110, () => test.find(surface, "lockPassword").insert(3, "r")],
        [110, () => test.find(surface, "lockPassword").insert(4, "e")],
        [110, () => test.find(surface, "lockPassword").insert(5, "c")],
        [400, () => { test.phase = "verify"; surface.attemptUnlock(); surface.busy = true }],
        [500, () => { test.phase = "error"; surface.busy = false; surface.errorText = "Contraseña incorrecta. Inténtalo de nuevo." }],
        [900, () => { test.phase = "retype"; test.find(surface, "lockPassword").insert(0, "x") }],
        [110, () => test.find(surface, "lockPassword").insert(1, "y")],
        [110, () => test.find(surface, "lockPassword").insert(2, "z")],
        [400, () => { test.phase = "verify2"; surface.attemptUnlock(); surface.errorText = ""; surface.busy = true }],
        [450, () => { test.phase = "success"; surface.busy = false; surface.authenticated = true }],
        [3200, () => {
            frames.stop()
            console.log("filmstrip: exitFinished at " + test.exitFinishedAt + " ms after secure")
            Qt.quit()
        }]
    ]
    property int stepIndex: 0
    Timer {
        id: stepper
        interval: test.script[0][0]
        running: true
        onTriggered: {
            test.script[test.stepIndex][1]()
            test.stepIndex++
            if (test.stepIndex < test.script.length) {
                interval = test.script[test.stepIndex][0]
                restart()
            }
        }
    }
}
