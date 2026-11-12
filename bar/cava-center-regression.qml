import QtQuick
import Quickshell
import "components"
import "Singletons"
ShellRoot {
    settings.watchFiles: false
    property int sample: 0
    property real maxDrift: 0
    property int inspectedBars: 0
    Window {
        id: scene
        visible: true
        width: 180; height: 100
        color: Theme.background
        IslandMediaVisualizer {
            id: wave
            anchors.centerIn: parent
            coreH: 38
            hasMedia: true; isPlaying: true; hasFrame: true
            values: Array(24).fill(0)
        }
    }
    function inspect(item) {
        if (item.parent && item.parent.minHeight !== undefined && item.radius !== undefined) {
            const center = item.mapToItem(wave, item.width / 2, item.height / 2)
            const drift = Math.abs(center.y - wave.height / 2)
            inspectedBars++
            maxDrift = Math.max(maxDrift, drift)
        }
        for (const child of item.children) inspect(child)
    }
    Component.onCompleted: Config.update({appearance: {reduceMotion: false}})
    Timer {
        running: true; repeat: true; interval: 10
        onTriggered: {
            inspectedBars = 0
            inspect(wave)
            const bars = wave.children.find(child => child.objectName === "smallCavaBars")
            if (!bars || bars.layer.enabled) {
                console.error("FAIL: small CAVA bars stay unlayered (no halo)"); Qt.exit(1); return
            }
            if (sample === 40 || sample === 100) {
                const dir = Quickshell.env("ISLA_TEST_OUTPUT")
                const capturedSample = sample
                if (dir) scene.contentItem.grabToImage(result => result.saveToFile(dir + "/cava-neon-" + capturedSample + ".png"))
            }
            if (++sample > 120) {
                console.log("center drift", maxDrift)
                if (inspectedBars !== 5 || maxDrift > 0.001) { console.error("FAIL: spectrum center moves with height"); Qt.exit(1) }
                else { console.log("PASS: spectrum center fixed across fractional heights; bars carry no halo"); Qt.quit() }
                return
            }
            wave.s = sample > 60 ? 1.25 : 1
            wave.coreH = 38 * wave.s
            wave.values = Array(24).fill((sample % 60) / 60)
        }
    }
}
