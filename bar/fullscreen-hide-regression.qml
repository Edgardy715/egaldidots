import QtQuick
import Quickshell
import "components"
import "windows"
import "Singletons"

// QT_QPA_PLATFORM=wayland quickshell -p bar/fullscreen-hide-regression.qml
// Fullscreen retira pill y gotas con un único progreso: mismas opacidad y
// desplazamiento a mitad de recorrido, sin gotas sueltas; reduceMotion directo.
ShellRoot {
    settings.watchFiles: false
    SurfaceRouter { id: router; focusedMonitorName: Quickshell.screens[0].name; reduceMotion: Flags.reduceMotion }
    IslandOverlay { id: overlay; modelData: Quickshell.screens[0]; router: router }
    property var pill: null
    property var music: null
    property var drop: null
    property var policy: null
    property var previous: []
    property int step: 0
    function check(ok, message) {
        if (!ok) { console.error("FAIL", message); Qt.exit(1) }
    }
    function find(item, name) {
        if (!item) return null
        if (item.objectName === name) return item
        const kids = item.data || item.children || []
        for (let i = 0; i < kids.length; i++) {
            const found = find(kids[i], name)
            if (found) return found
        }
        return null
    }
    function lift(item) { return item.transform.length ? item.transform[0].y : 0 }
    function fullscreen(on) {
        policy.monitors = on
            ? [{name: overlay.modelData.name, activeWorkspace: {lastIpcObject: {hasfullscreen: true}}}]
            : previous
    }
    Timer {
        interval: 50; repeat: true; running: true
        onTriggered: {
            if (step === 0) {
                if (!Config.loaded) return
                Recording.observe = false
                DesktopStatus.monitorServices = false
                Config.update({appearance: {barLayout: "split", reduceMotion: false}})
                step = 1
            } else if (step === 1) {
                if (overlay.layoutChanging || overlay.compact) return
                pill = find(overlay.contentItem, "islandPill")
                music = find(overlay.contentItem, "islandMediaCompanion")
                drop = find(overlay.contentItem, "islandRecordingCompanion")
                policy = find(overlay, "islandInputPolicy")
                check(pill && music && drop && policy, "overlay integration available")
                pill.notificationsEnabled = false
                previous = policy.monitors
                check(overlay.fullscreenHide === 0 && pill.opacity === 1 && music.opacity === 1,
                      "resting overlay is fully presented")
                fullscreen(true)
                stop()
                mid.start()
            }
        }
    }
    Timer {
        id: mid
        interval: Math.round(Motion.morph * 0.4)
        onTriggered: {
            const h = overlay.fullscreenHide
            check(h > 0.02 && h < 0.98, "fullscreen hide must travel, got " + h.toFixed(3))
            check(Math.abs(pill.opacity - music.opacity) < 0.001 && Math.abs(pill.opacity - drop.opacity) < 0.001,
                  "pill and drops must share opacity mid-travel")
            check(lift(pill) < -1 && Math.abs(lift(pill) - lift(music)) < 0.001 && Math.abs(lift(pill) - lift(drop)) < 0.001,
                  "pill and drops must share lift mid-travel")
            settled.start()
        }
    }
    Timer {
        id: settled
        interval: Motion.morph + 200
        onTriggered: {
            check(overlay.fullscreenHide === 1 && !pill.visible && music.opacity === 0,
                  "fullscreen must fully withdraw pill and drops")
            fullscreen(false)
            restored.start()
        }
    }
    Timer {
        id: restored
        interval: Motion.morph + 200
        onTriggered: {
            check(overlay.fullscreenHide === 0 && pill.opacity === 1 && lift(music) === 0,
                  "leaving fullscreen must restore pill and drops")
            Config.update({appearance: {reduceMotion: true}})
            fullscreen(true)
            check(overlay.fullscreenHide === 1, "reduced motion must resolve fullscreen directly")
            fullscreen(false)
            check(overlay.fullscreenHide === 0, "reduced motion must restore directly")
            Config.update({appearance: {reduceMotion: false}})
            console.log("PASS: fullscreen hide shared by pill and drops, interruptible, reduced motion direct")
            Qt.exit(0)
        }
    }
}
