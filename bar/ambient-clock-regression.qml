import QtQuick
import QtTest
import Quickshell
import "Singletons"
import "components"

ShellRoot {
    settings.watchFiles: false
    Window {
        id: scene
        visible: true
        width: 160; height: 80
        AmbientSubscription {
            id: first
            property int ticks: 0
            property real largestDt: 0
            onTriggered: dt => { ticks++; largestDt = Math.max(largestDt, dt) }
        }
        AmbientSubscription { id: second }
        Loader {
            id: disposable
            active: false
            sourceComponent: AmbientSubscription { running: true }
        }
        TestCase {
            name: "AmbientClock"
            when: scene.visible
            function test_lifetime_and_cadence() {
                Config.update({appearance: {reduceMotion: false, ambientFps: 60}})
                first.running = true
                second.running = true
                compare(AmbientClock.subscribers, 2)
                wait(500)
                verify(first.ticks > 10 && first.ticks < 40, "cadencia acotada")
                verify(first.largestDt <= 0.05)
                first.running = false
                second.running = false
                verify(!AmbientClock.running)
                const count = first.ticks
                wait(120)
                compare(first.ticks, count)
                first.running = true
                Config.update({appearance: {reduceMotion: true}})
                verify(!AmbientClock.running)
                wait(120)
                compare(first.ticks, count)
                Config.update({appearance: {reduceMotion: false}})
                wait(100)
                verify(first.ticks > count)
                first.running = false
                compare(AmbientClock.subscribers, 0)
                disposable.active = true
                tryCompare(AmbientClock, "subscribers", 1)
                disposable.active = false
                tryCompare(AmbientClock, "subscribers", 0)
                verify(!AmbientClock.running, "destrucción libera la suscripción")
                Config.discard()
                console.log("PASS: reloj compartido, cadencia, dt, suspensión y reanudación")
                Qt.quit()
            }
        }
    }
    Timer { interval: 5000; running: true; onTriggered: Qt.exit(1) }
}
