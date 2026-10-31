import QtQuick
import Quickshell
import "Singletons"

// Probe (not a regression): records the Cuerpo hover in/out on a real GPU window.
// ISLA_CONFIG=<tmp> PROBE_OUT=<dir> PROBE_NIGHT=0|1 [PROBE_LIGHT=1] [PROBE_HOUR=h] quickshell -p bar/body-hover-probe.qml
ShellRoot {
    settings.watchFiles: false
    Window {
        id: scene
        visible: true
        width: 420; height: 120
        color: "#1d4f78"
        Pill {
            id: pill
            x: (scene.width - width) / 2; y: 30
            notificationsEnabled: false
        }
        property string out: Quickshell.env("PROBE_OUT") || "/tmp"
        property bool night: Quickshell.env("PROBE_NIGHT") === "1"
        property bool light: Quickshell.env("PROBE_LIGHT") === "1"
        property string hourOverride: Quickshell.env("PROBE_HOUR") || ""
        property real t0: 0
        property int shot: 0
        property string phase: "settle"
        // The palette file loads asynchronously and would overwrite an early override.
        function applyLight() {
            IslaPalette.colors = Object.assign({}, IslaPalette.colors, {surface: "#fff8f7", on_surface: "#231919",
                surface_container_high: "#f3e5e4", surface_container_low: "#fff0ef", primary: "#904a47",
                secondary: "#77524f", tertiary: "#6f5c2e", outline: "#857371"})
            IslaPalette.mode = "light"
            color = "#c9d6df"
            console.info("THEME dark=" + Theme.dark + " fg=" + Theme.foreground + " top=" + Theme.cardTop + " bot=" + Theme.cardBot + " fill=" + pill.bodyPresentation.fillAlpha + " wall=" + pill.bodyPresentation.shader.wallMix)
        }
        function now() { return (Date.now() - t0) / 1000 }
        function log() {
            const b = pill.bodyPresentation, e = b.engine, g = b.shader
            console.info("P " + now().toFixed(3) + " " + phase + " hov=" + pill.hovered
                + " exp=" + b.exposure.toFixed(3) + " rest=" + b.resting + " mood=" + e.currentMood
                + " w=" + pill.width.toFixed(1) + " h=" + pill.height.toFixed(1)
                + " hw=" + g.pillHalfW.toFixed(2) + " hh=" + g.pillHalfH.toFixed(2)
                + " cx=" + (g.pillCx - b.margin - b.width / 2).toFixed(2) + " cy=" + (g.pillCy - b.margin - b.height / 2).toFixed(2)
                + " bulge=" + g.bulge.z.toFixed(2) + " lean=" + e.state.lean.x.toFixed(2)
                + " mat=" + (1 - b.exposure).toFixed(3))
        }
        Timer {
            id: sampler
            interval: 33; repeat: true; running: false
            onTriggered: {
                scene.log()
                const n = scene.shot++
                scene.contentItem.grabToImage(r => r.saveToFile(scene.out + "/f" + String(n).padStart(3, "0") + "-" + scene.phase + ".png"))
            }
        }
        Component.onCompleted: {
            Config.update({appearance: {personality: true, liquidSurfaces: true, reduceTransparency: false, reduceMotion: false},
                companion: {reactAtNight: night}})
            if (hourOverride !== "") pill.bodyPresentation.hour = Number(hourOverride)
            t0 = Date.now()
            script.start()
        }
        SequentialAnimation {
            id: script
            PauseAnimation { duration: 1200 }
            ScriptAction { script: if (scene.light) scene.applyLight() }
            PauseAnimation { duration: 1300 }
            ScriptAction { script: { scene.phase = "rest"; sampler.running = true } }
            PauseAnimation { duration: 300 }
            ScriptAction { script: { scene.phase = "in"; pill.pointerX = pill.width * 0.35; pill.pointerY = pill.height / 2; pill.hovered = true } }
            PauseAnimation { duration: 400 }
            ScriptAction { script: pill.pointerX = pill.width * 0.55 }
            PauseAnimation { duration: 800 }
            ScriptAction { script: { scene.phase = "out"; pill.pointerX = pill.width * 0.95; pill.hovered = false } }
            PauseAnimation { duration: 2500 }
            ScriptAction { script: { sampler.running = false; scene.log(); Qt.quit() } }
        }
    }
}
