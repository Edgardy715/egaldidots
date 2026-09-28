import QtQuick
import Quickshell
import "components"
import "Singletons"

// Finite stress fixture; FrameAnimation exists only here, never in controls.
ShellRoot {
    Window {
        id: scene
        visible: true; width: 800; height: 600; color: Theme.background
        property bool hovered: false
        property bool pressed: false
        property int phase: 0
        property int frames: 0
        property real totalTime: 0
        property real worstTime: 0
        property real maximumScale: 1
        property int unsettled: 0
        Grid {
            columns: 12; spacing: 12; x: 24; y: 24
            Repeater {
                id: buttons
                model: 96
                delegate: Item {
                    width: 48; height: 48
                    InteractionMotion { id: motion; hovered: scene.hovered; pressed: scene.pressed; extent: 48 }
                    property alias response: motion
                    Rectangle { anchors.fill: parent; radius: 14; color: Qt.alpha(Theme.accent, 0.12 + 0.06 * motion.presence); scale: motion.visualScale }
                    MaterialIcon { anchors.centerIn: parent; font.pixelSize: 22; hovered: scene.hovered; iconName: scene.phase % 2 ? "volume_off" : "volume_up"; scale: motion.visualScale }
                }
            }
        }
        FrameAnimation {
            running: scene.phase > 0 && scene.phase < 13
            onTriggered: {
                scene.frames++
                scene.totalTime += frameTime
                scene.worstTime = Math.max(scene.worstTime, frameTime)
                scene.maximumScale = Math.max(scene.maximumScale, buttons.itemAt(0).response.visualScale)
            }
        }
        Timer {
            interval: 180; running: true; repeat: true
            onTriggered: {
                scene.phase++
                scene.hovered = scene.phase < 11
                scene.pressed = scene.phase < 11 && scene.phase % 2 === 1
                if (scene.phase === 14) {
                    for (let i = 0; i < buttons.count; i++) {
                        if (Math.abs(buttons.itemAt(i).response.visualScale - 1) > 0.003) scene.unsettled++
                    }
                    console.log("PERF: 96 controls, frames", scene.frames, "mean ms", (1000 * scene.totalTime / scene.frames).toFixed(2), "max ms", (1000 * scene.worstTime).toFixed(2), "max scale", scene.maximumScale.toFixed(4), "unsettled", scene.unsettled)
                    if (scene.unsettled || scene.maximumScale > 1.006) { console.error("FAIL: physical return settling"); Qt.exit(1) }
                    else { console.log("PASS: finite interaction stress and bounded spring return"); Qt.quit() }
                }
            }
        }
    }
}
