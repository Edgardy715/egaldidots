import QtQuick
import QtTest
import Quickshell
import "components"
import "Singletons"

// Escenario de demo: botón de play grande que se divide en gotitas y se funde.
ShellRoot {
    settings.watchFiles: false
    Window {
        id: scene
        title: "play-drops-demo"
        visible: true
        width: 360; height: 260
        color: Theme.cardBot
        // Con DEMO_FRAMES, guarda la escena a ~30 fps (no depende del escritorio visible).
        property int frame: 0
        Timer {
            interval: 33; repeat: true; running: Quickshell.env("DEMO_FRAMES") !== null
            onTriggered: { const n = ("0000" + scene.frame++).slice(-4); stage.grabToImage(r => r.saveToFile(Quickshell.env("DEMO_FRAMES") + "/f_" + n + ".png")) }
        }
        Item { id: stage; anchors.centerIn: parent; width: 340; height: 220
        Row {
            anchors.centerIn: parent; spacing: 30
            MediaTransportButton { id: small; primary: true; size: 56; primaryColor: "#7fd1b9"; iconName: playing ? "pause" : "play_arrow"; anchors.verticalCenter: parent.verticalCenter }
            MediaTransportButton { id: play; primary: true; size: 150; iconSize: 60; primaryColor: "#c792ea"; iconName: playing ? "pause" : "play_arrow" }
        }
        }
        TestCase {
            when: scene.visible
            function test_demo() {
                wait(1200)
                play.playing = true; small.playing = true; wait(3200)
                play.playing = false; small.playing = false; wait(1600)
                play.playing = true; small.playing = true; wait(2200)
                mouseMove(play, 75, 75); wait(1400)
                mouseMove(scene.contentItem, 5, 5); wait(1500)
                play.playing = false; small.playing = false; wait(1600)
                Qt.quit()
            }
        }
    }
}
