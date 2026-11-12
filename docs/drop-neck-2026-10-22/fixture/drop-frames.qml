import QtQuick
import Quickshell
import "file:///home/zdito/.config/quickshell/bar/components"
import "file:///home/zdito/.config/quickshell/bar/Singletons"

ShellRoot {
    settings.watchFiles: false
    property string out: Quickshell.env("DROP_OUT") || "/tmp"
    property bool legacy: Quickshell.env("DROP_LEGACY") === "1"
    property bool leftDrop: Quickshell.env("DROP_LEFT") === "1"
    Window {
        id: win
        width: 420; height: 90; visible: true; color: "transparent"
        Item {
            id: scene
            width: 420; height: 90
            // Busy backdrop: translucency and doubled glass show up against it.
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#3a6ea5" }
                    GradientStop { position: 0.5; color: "#c58b4a" }
                    GradientStop { position: 1; color: "#6a3d8f" }
                }
            }
            Repeater {
                model: 14
                Rectangle { x: index * 32; y: 0; width: 3; height: 90; color: Qt.rgba(1, 1, 1, 0.35); rotation: 20 }
            }
            Item {
                id: body; x: leftDrop ? 230 : 70; y: 26; width: 120; height: 38
                PillMaterial {
                    s: 1
                    visible: Quickshell.env("DROP_NOBODY") !== "1"
                    morphRadius: 19
                    suppressEdge: drop.item ? drop.item.joined : false
                    edgeExposure: drop.item ? drop.item.edgeExposure : 1
                    captureExtra: drop.item && !leftDrop ? drop.item.captureExtra : 0
                    captureLeftExtra: drop.item && leftDrop ? drop.item.captureExtra : 0
                }
            }
            Loader {
                id: drop
                anchors.fill: parent
                z: 3
                Component.onCompleted: setSource(legacy
                    ? "file:///home/zdito/.config/quickshell/bar/components/_LegacyCompanion.qml"
                    : "file:///home/zdito/.config/quickshell/bar/components/FluidCompanion.qml",
                    {body: body, visible: true, leftSide: leftDrop, surfaceName: "session"})
            }
        }
    }
    property var stretches: [0.55, 0.8, 1.0, 1.06, 1.12, 1.18, 1.24, 1.32]
    property int index: -1
    function place(stretch) {
        const d = drop.item
        d.phase = "companion"; d.bond = stretch < 1.3; d.concealed = false
        d.wPos = 42; d.hPos = 38; d.yPos = body.y
        // xPos is right-facing; visualX reflects it for the left droplet.
        d.xPos = d.capX + stretch * (d.bodyRadius + d.dropRadius) - d.wPos / 2
        d.targetX = d.xPos; d.targetY = d.yPos; d.targetW = d.wPos; d.targetH = d.hPos
        d.vx = d.vy = d.vw = d.vh = 0
        d.captureExtra = stretch < 1.0 ? 6 : 0; d.captureTarget = d.captureExtra; d.captureV = 0
        d.updateBond()
    }
    Timer {
        id: step
        interval: 120; running: true; repeat: true
        onTriggered: {
            if (index >= 0) {
                const name = out + "/s" + index + ".png"
                scene.grabToImage(r => r.saveToFile(name))
            }
            index++
            if (index >= stretches.length) { running = false; quitTimer.start(); return }
            Config.update({appearance: {reduceMotion: false}})
            place(stretches[index])
        }
    }
    Timer { id: quitTimer; interval: 300; onTriggered: Qt.quit() }
}
