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
                    {body: body, leftSide: leftDrop, surfaceName: "session"})
            }
        }
    }
    property int n: 0
    property var log: []
    Timer {
        id: cap
        interval: 25; repeat: true; running: true
        onTriggered: {
            const d = drop.item
            if (n === 4) { Config.update({appearance: {reduceMotion: false}}); d.open = true }
            if (n === 30) d.open = false
            if (n >= 4) {
                const name = out + "/f" + String(n).padStart(3, "0") + ".png"
                scene.grabToImage(r => r.saveToFile(name))
                console.log("F", n, d.phase, d.stretch.toFixed(3), d.joined, d.captureExtra.toFixed(1), d.xPos.toFixed(1), d.wPos.toFixed(1))
            }
            n++
            if (n > 62) { running = false; Qt.quit() }
        }
    }
}
