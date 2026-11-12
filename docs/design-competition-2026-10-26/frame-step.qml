import QtQuick
import Quickshell
import "file:///home/zdito/.config/quickshell/bar/components"
ShellRoot {
    id: root
    Component {
        id: factory
        PillMorphMotion { manualStep: true; s: 1; restW: 150; coreH: 38; targetW: 150; targetH: 38; targetRadius: 19 }
    }
    Timer {
        interval: 100; running: true
        onTriggered: {
            for (const hz of [144, 60, 30, 20, 10]) {
                const m = factory.createObject(root)
                m.surfaceName = "calendar"; m.surfaceOpen = true
                m.targetW = 660; m.targetH = 470; m.targetRadius = 36
                let t90 = -1, t = 0, at600 = null
                while (m.integrating && t < 10) {
                    m.step(1 / hz); t += 1 / hz
                    if (t90 < 0 && m.width >= 150 + .9 * 510) t90 = t
                    if (at600 === null && t >= .6 - .000001) at600 = [m.width, m.height]
                }
                if (m.width !== 660 || m.height !== 470) { console.error("FAIL target", hz); Qt.exit(1); return }
                console.log("FRAME_STEP", JSON.stringify({hz: hz, t90_ms: Math.round(t90*1000), settle_ms: Math.round(t*1000), at600: at600}))
                m.destroy()
            }
            console.log("PASS: all frame schedules settle; output compares wall-clock response")
            Qt.quit()
        }
    }
}
