import QtQuick
import Quickshell
import "components"
import "Singletons"

// Capture fixture for docs/surface-materialize-2026-10-25/capture.py (Wayland).
// Drives the production Pill through open/close of calendar, launcher (two-phase
// close, as SurfaceRouter does it), mixer, and a direct calendar -> mixer switch.
// Per frame it logs "MAT_F <epoch ms> <width> <height> <radius> <contentProgress>
// <closeness>" so the grim samples can be matched with the real geometry.
ShellRoot {
    settings.watchFiles: false
    Window {
        id: scene
        visible: true
        width: 900; height: 740
        title: "Isla · materialización · captura"
        color: "#3b4552"
        Pill {
            id: pill
            x: (scene.width - width) / 2
            y: 16
            screenName: "materialize-capture"
            notificationsEnabled: false
        }
        property bool recording: false
        FrameAnimation {
            running: true
            onTriggered: if (scene.recording)
                console.log("MAT_F", Date.now(), pill.width.toFixed(2), pill.height.toFixed(2),
                            pill.morphRadius.toFixed(2), pill.surfaceContentProgress.toFixed(4),
                            pill.morphCloseness.toFixed(4))
        }

        property int phaseResults: 250
        property int phasePill: 420
        // [offset ms, mark, action]
        readonly property var script: {
            const rest = 500, hold = 1500, tail = 1100
            const items = []
            let t = 0
            function add(dt, mark, fn) { t += dt; items.push({at: t, mark: mark, fn: fn}) }
            const open = name => () => { pill.surface = name }
            const closePlain = () => { pill.surface = "" }
            const closeLauncher = () => { pill.launcherClosing = true; pill.launcherClosePhase = 1 }
            for (const name of ["calendar", "launcher", "mixer"]) {
                add(rest, name + "-open", open(name))
                if (name === "launcher") {
                    add(hold, name + "-close", closeLauncher)
                    add(phaseResults, name + "-close-phase2", () => { pill.launcherClosePhase = 2 })
                    add(phasePill, name + "-close-end", () => {
                        pill.surface = ""; pill.launcherClosePhase = 0; pill.launcherClosing = false
                    })
                    t += 0
                    add(tail, name + "-settled", () => {})
                } else {
                    add(hold, name + "-close", closePlain)
                    add(tail, name + "-settled", () => {})
                }
            }
            add(rest, "switch-calendar-open", open("calendar"))
            add(hold, "switch-calendar-to-mixer", open("mixer"))
            add(hold, "switch-mixer-close", closePlain)
            add(tail, "switch-settled", () => {})
            return items
        }
        property int cursor: 0
        property real t0: 0
        Timer {
            id: driver
            interval: 1; repeat: true; running: false
            onTriggered: {
                const now = Date.now() - scene.t0
                while (scene.cursor < scene.script.length && scene.script[scene.cursor].at <= now) {
                    const item = scene.script[scene.cursor++]
                    console.log("MAT_MARK", Date.now(), item.mark)
                    item.fn()
                }
                if (scene.cursor >= scene.script.length) {
                    driver.stop()
                    scene.recording = false
                    console.log("MAT_END", Date.now())
                    Qt.quit()
                }
            }
        }
        Timer {
            interval: 600; running: Config.loaded && scene.visible; repeat: false
            onTriggered: {
                const p = pill.mapToItem(null, 0, 0)
                console.log("MAT_GEOM", p.x, p.y, pill.width, pill.height, scene.width, scene.height)
                scene.recording = true
                scene.t0 = Date.now()
                console.log("MAT_START", scene.t0)
                driver.start()
            }
        }
    }
}
