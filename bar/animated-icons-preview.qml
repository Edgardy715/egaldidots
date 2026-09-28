import QtQuick
import QtTest
import Quickshell
import "components"
import "components/AnimatedIconData.js" as IconData
import "Singletons"

ShellRoot {
    Window {
        id: window
        width: 800; height: 380; visible: true
        color: Theme.background
        title: "Isla · Iconos animados"
        property bool engaged: false
        Item {
            id: scene
            width: 800; height: 380
            Rectangle { anchors.fill: parent; color: Theme.background }
            Text { x: 28; y: 22; text: "Isla · Trazos y piezas en movimiento"; color: Theme.foreground; font.family: Theme.font; font.pixelSize: 22 }
            Grid {
                x: 28; y: 78; columns: 8; spacing: 12
                Repeater {
                    id: icons
                    model: ["power_settings_new", "restart_alt", "dark_mode", "logout", "lock", "wifi", "notifications", "settings", "volume_up", "bluetooth", "download", "check", "delete", "search", "play_arrow", "battery_charging_full"]
                    delegate: Rectangle {
                        required property string modelData
                        required property int index
                        width: 82; height: 112; radius: 16
                        color: Qt.alpha(Theme.accent, 0.075)
                        MaterialIcon {
                            id: icon
                            objectName: "galleryIcon" + index
                            x: 23; y: 20; font.pixelSize: 36
                            color: Theme.foreground; iconName: modelData
                            hovered: window.engaged
                        }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; y: 78; text: modelData.replace("_settings_new", "").replace("battery_charging_full", "battery"); font.pixelSize: 10; color: Theme.dim }
                    }
                }
            }
            Text { x: 28; y: 342; text: "Animación finita al entrar, pulsar o cambiar de estado · QML nativo"; font.pixelSize: 13; color: Theme.dim }
        }
        Timer { interval: 80; running: checks.finished; onTriggered: Qt.quit() }
        TestCase {
            id: checks
            name: "AnimatedIcons"
            when: window.visible
            property bool finished: false
            function check(ok, why) { if (!ok) { console.error("FAIL: vector icons", why); throw new Error(why) } }
            function shot(name) { scene.grabToImage(result => result.saveToFile("/tmp/isla-icons-" + name + ".png")); wait(90) }
            function test_parts() {
                wait(350); shot("rest")
                window.engaged = true
                wait(180)
                for (let i = 0; i < icons.count; i++) {
                    const icon = findChild(scene, "galleryIcon" + i)
                    const vector = findChild(icon, "animatedSymbol")
                    check(icon.vectorIcon && vector.supported, "native vector " + i)
                    check(vector.animating && vector.progress > 0 && vector.progress < 1, "finite motion " + i)
                    const part = findChild(vector, "animatedPart0")
                    check(part && part.pulse > 0, "individual part responds " + i)
                }
                shot("motion")
                wait(650)
                const power = findChild(findChild(scene, "galleryIcon0"), "animatedSymbol")
                check(power.progress === 1 && !power.animating, "hover settles without loop")
                window.engaged = false
                window.engaged = true
                wait(80)
                Config.update({appearance: {reduceMotion: true}})
                check(power.progress === 1 && !power.animating, "reduced motion stops active parts")
                Config.update({appearance: {reduceMotion: false}})
                window.engaged = false
                window.engaged = true
                wait(60)
                window.visible = false
                check(power.progress === 1 && !power.animating, "hidden stops motion")
                console.log("PASS: sixteen native vector families, animated parts, finite hover, reduced motion and hidden stop")
                finished = true
            }
        }
    }
}
