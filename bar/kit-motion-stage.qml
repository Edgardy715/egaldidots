import QtQuick
import QtTest
import Quickshell
import "components"
import "kit"
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    Window {
        id: scene
        title: "kit-motion-demo"
        visible: true
        width: 600; height: 380
        color: Theme.cardBot
        Column {
            x: 40; y: 34; spacing: 26
            Row {
                spacing: 40
                IslaSwitch { id: sw }
                IslaSwitch { id: sw2; checked: true }
            }
            IslaSlider { id: sl; width: 520; from: 0; to: 1; value: 0.2 }
            IslaSegmented {
                id: seg; width: 520; inline: true
                options: ["Números", "Puntos", "Barras", "Cápsulas"]
                current: "Números"
                onChosen: v => current = v
            }
            Row {
                spacing: 18
                MediaTransportButton { id: shuffle; iconName: "shuffle"; anchors.verticalCenter: parent.verticalCenter }
                MediaTransportButton { id: play; primary: true; size: 64; primaryColor: "#c792ea"; iconName: playing ? "pause" : "play_arrow" }
                MediaTransportButton { id: rep; iconName: "repeat"; anchors.verticalCenter: parent.verticalCenter }
                SwiftMediaTimeline {
                    id: tl; width: 300; height: 32; anchors.verticalCenter: parent.verticalCenter
                    active: true; length: 120; musicAccent: "#c792ea"; progress: 0.3; playing: play.playing
                }
            }
        }
        TestCase {
            when: scene.visible
            name: "demo"
            function test_demo() {
                wait(1400)
                mouseMove(sw, 30, 22); wait(300)
                mouseClick(sw, 30, 22); wait(900)
                mouseClick(sw, 30, 22); wait(700)
                mouseClick(sw2, 30, 22); wait(900)
                const y = sl.height / 2
                mouseMove(sl, 20 + 0.2 * 480, y); wait(400)
                mousePress(sl, 20 + 0.2 * 480, y); wait(250)
                for (let i = 0; i <= 14; ++i) { mouseMove(sl, 20 + (0.2 + 0.65 * i / 14) * 480, y); wait(16) }
                wait(500)
                for (let i = 0; i <= 10; ++i) { mouseMove(sl, 20 + (0.85 - 0.45 * i / 10) * 480, y); wait(16) }
                wait(300)
                mouseRelease(sl, 20 + 0.4 * 480, y); wait(900)
                const chips = ["Barras", "Puntos", "Cápsulas"]
                for (const c of chips) { seg.chosen(c); wait(800) }
                mouseClick(shuffle); shuffle.active = true; wait(600)
                mouseMove(play, 32, 32); wait(300)
                mouseClick(play, 32, 32); play.playing = true; wait(3000)
                mouseMove(tl, 200, 16); wait(1200)
                play.playing = false; wait(1200)
                Qt.quit()
            }
        }
    }
}
