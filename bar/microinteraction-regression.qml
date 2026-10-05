import QtQuick
import QtTest
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    Window {
        id: scene
        width: 500; height: 320; visible: true
        ContentMotion { id: content; onConcealed: checks.concealed++ }
        AnimatedLabel { id: label; x: 20; y: 20; value: "Inicial"; font.pixelSize: 20 }
        MotionArea { id: hit; x: 360; y: 20; width: 80; height: 40; accessibleName: "Respuesta" }
        MotionList {
            id: rows
            x: 20; y: 70; width: 300; height: 230; spacing: 8
            model: ListModel {
                id: items
                ListElement { name: "Primero" }
                ListElement { name: "Segundo" }
                ListElement { name: "Tercero" }
            }
            delegate: Rectangle {
                required property string name
                width: rows.width; height: 40; radius: 12
                color: "steelblue"
                Text { anchors.centerIn: parent; text: parent.name }
            }
        }
        Timer { interval: 50; running: checks.finished; onTriggered: Qt.quit() }
        TestCase {
            id: checks
            name: "Microinteractions"
            when: scene.visible
            property int concealed: 0
            property bool finished: false
            function test_continuity() {
                wait(100)
                compare(label.text, "Inicial")
                content.shown = false
                wait(70)
                verify(content.progress > 0 && content.progress < 1, "content exits through intermediate geometry")
                const interrupted = content.progress
                content.shown = true
                verify(Math.abs(content.progress - interrupted) < 0.01, "retarget preserves current position")
                wait(250)
                compare(content.progress, 1)
                compare(concealed, 0)
                content.shown = false
                wait(250)
                compare(concealed, 1)
                label.value = "Intermedio"
                wait(35)
                verify(label.reveal < 1 && label.reveal > 0)
                label.value = "Último"
                wait(250)
                compare(label.text, "Último")
                compare(label.reveal, 1)
                hit.clicked(null)
                wait(35)
                verify(hit.activation > 0 && hit.activation < 1, "click acknowledgment progresses")
                compare(hit.width, 80)
                wait(300)
                compare(hit.activation, 0)
                hit.clicked(null)
                wait(30)
                hit.visible = false
                compare(hit.activation, 0)
                const departing = rows.itemAtIndex(1)
                const moving = rows.itemAtIndex(2)
                items.remove(1)
                wait(50)
                verify(departing && departing.opacity > 0 && departing.opacity < 1, "removed row remains while fading")
                verify(moving.y > 48 && moving.y < 96, "survivor moves continuously")
                wait(250)
                compare(moving.y, 48)
                Config.update({appearance: {reduceMotion: true}})
                label.value = "Reducido"
                compare(label.text, "Reducido")
                content.shown = true
                compare(content.progress, 1)
                content.shown = false
                compare(content.progress, 0)
                compare(content.visualScale, 1)
                compare(content.offset, 0)
                compare(concealed, 2)
                console.log("PASS: content interruption, text retarget, native remove/displacement and reduced motion")
                finished = true
            }
        }
    }
}
