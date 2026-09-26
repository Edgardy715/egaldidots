import QtQuick
import Quickshell
import "Singletons"
import "components"

// QT_QPA_PLATFORM=offscreen quickshell -p bar/media-motion-regression.qml
ShellRoot {
    Item {
        width: 1920; height: 1080
        Item { id: body; x: 900; y: 8; width: 94; height: 38 }
        FluidMediaCompanion { id: drop; anchors.fill: parent; body: body; screenName: "media-test" }
    }
    function check(ok, message) {
        if (!ok) { console.error("FAIL", message); Qt.exit(1) }
    }
    function find(item, name) {
        if (item.objectName === name) return item
        for (let child of item.children) {
            const found = find(child, name)
            if (found) return found
        }
        return null
    }
    Timer {
        interval: 20; running: true
        onTriggered: { Config.update({ appearance: { reduceMotion: true } }); drop.open = true }
    }
    Timer {
        interval: 100; running: true
        onTriggered: {
            check(drop.phase === "companion", "birth must finish")
            check(drop.targetW === (Players.live ? drop.playingW : drop.collapsedW),
                  "birth must use current playback width")
            const bars = find(drop, "mediaVisualizer")
            check(bars !== null, "visualizer exists")
            for (let width = 34; width <= 218; width++) {
                drop.wPos = width
                check(bars.x >= 38, "bars must never overlap cover during morph")
            }
            drop.open = false
        }
    }
    Timer {
        interval: 150; running: true
        onTriggered: { drop.open = true }
    }
    Timer {
        interval: 230; running: true
        onTriggered: {
            check(drop.targetW === (Players.live ? drop.playingW : drop.collapsedW),
                  "rebirth after absorption must use current playback width")
            console.log("PASS: media birth, rebirth, cover exclusion; playing:", Players.live)
            Qt.quit()
        }
    }
}
