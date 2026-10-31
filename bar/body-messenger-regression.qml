import QtQuick
import QtTest
import Quickshell
import "body"

ShellRoot {
    settings.watchFiles: false
    Window {
        id: win
        width: 640; height: 400; visible: true
        BodyEngine {
            id: engine
            cx: 180; cy: 80; baseW: 220; baseH: 38
            manualStep: true; active: true; breathe: false; reduceMotion: messenger.reduceMotion
        }
        BodyShader {
            id: source
            visible: false
            width: 400; height: 200
            pill: engine.pill
            colA: "red"; colB: "green"; colC: "white"; colBg: "black"
        }
        BodyMessenger {
            id: messenger
            anchors.fill: parent
            engine: engine; bodyShader: source
            bodyOrigin: Qt.point(40, 10)
        }
        SignalSpy { id: delivered; target: messenger; signalName: "fileDelivered" }
        TestCase {
            name: "BodyMessenger"; when: win.visible
            property bool passed: false
            function advance(seconds) {
                for (let i = 0; i < seconds * 240; i++) engine.step(1/240)
            }
            function test_cycle() {
                verify(!messenger.offerFile("https://remote/a"))
                messenger.enabled = false
                messenger.acceptFiles = false
                verify(!messenger.offerFile("/tmp/disabled.mp4"))
                messenger.acceptFiles = true
                verify(messenger.offerFile("file:///tmp/messenger%20%24%28literal%29.mp4"))
                verify(!messenger.offerFile("/tmp/replacement.mp4"))
                compare(messenger.phase, "")
                verify(!messenger.presentationActive)
                messenger.enabled = true
                compare(messenger.phase, "collecting")
                verify(messenger.shaderActive)
                compare(engine.dropArea.width, 600)
                advance(7)
                compare(messenger.phase, "stored")
                verify(!messenger.shaderActive)
                verify(engine.dropHasItem)
                // The demo widens its core for the label; pill hosts keep the layout core
                // so the attention bulge stays anchored to the visible pill.
                fuzzyCompare(engine.state.hw.t, 132, 0.01)
                engine.storedWidens = false
                advance(0.25)
                verify(engine.state.hw.t <= 110.01, "stored file must not widen a pill host: " + engine.state.hw.t)
                engine.storedWidens = true
                advance(0.25)
                compare(messenger.fileName, "messenger $(literal).mp4")
                compare(delivered.count, 0)
                compare(messenger.hitItem.x, messenger.bodyOrigin.x + source.pill.x + Math.min(80, source.pill.z - 13) - 13)
                compare(messenger.shader.pill.x, source.pill.x + 40)
                messenger.enabled = false
                verify(!messenger.presentationActive)
                compare(engine.dropMode, "home")
                verify(messenger.hasFile)
                messenger.enabled = true
                // Returning from a surface keeps the stored file; no second pickup.
                compare(messenger.phase, "stored")
                verify(!messenger.shaderActive)
                verify(messenger.docked)
                compare(messenger.hitItem.x + 13, messenger.bodyOrigin.x + messenger.dock.x)
                mouseClick(messenger.hitItem, 13, 13)
                compare(messenger.phase, "delivering")
                verify(!messenger.activate())
                advance(7)
                compare(delivered.count, 1)
                compare(delivered.signalArguments[0][0], "/tmp/messenger $(literal).mp4")
                verify(!messenger.hasFile)
                verify(!messenger.presentationActive)
                compare(engine.dropMode, "home")
                messenger.reduceMotion = true
                verify(messenger.offerFile("/tmp/reduced.mp4"))
                compare(messenger.phase, "stored")
                verify(!messenger.shaderActive)
                verify(!engine.needsFrames)
                messenger.visible = false
                verify(!messenger.presentationActive)
                verify(messenger.hasFile)
                messenger.visible = true
                compare(messenger.phase, "stored")
                verify(!messenger.shaderActive)
                verify(!engine.needsFrames)
                messenger.hitItem.forceActiveFocus()
                keyClick(Qt.Key_Return)
                compare(delivered.count, 2)
                verify(!messenger.presentationActive)
                verify(!engine.needsFrames)
                // Reduce motion switched on mid-flight settles at once, without a replay.
                messenger.reduceMotion = false
                verify(messenger.offerFile("/tmp/mid-flight.mp4"))
                compare(messenger.phase, "collecting")
                advance(0.3)
                messenger.reduceMotion = true
                compare(messenger.phase, "stored")
                verify(!messenger.shaderActive)
                verify(!engine.needsFrames)
                messenger.reduceMotion = false
                compare(messenger.phase, "stored")
                verify(messenger.activate())
                advance(0.3)
                messenger.reduceMotion = true
                compare(delivered.count, 3)
                verify(!messenger.hasFile)
                compare(messenger.phase, "")
                verify(!engine.needsFrames)
                passed = true
            }
            function cleanupTestCase() {
                if (!passed) { Qt.exit(1); return }
                console.info("PASS: messenger cycle, bounded ownership, transforms, preserved path, reduceMotion and explicit delivery")
                Qt.quit()
            }
        }
    }
}
