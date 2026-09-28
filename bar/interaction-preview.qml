import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtTest
import Quickshell
import "components"
import "Singletons"
import "surfaces"

// Isolated visual/input QA: no service actions, power commands or settings writes.
ShellRoot {
    Window {
        id: window
        width: 820; height: 740; visible: true
        title: "Isla · Interacciones"
        color: Theme.background
        Item {
            id: scene
            anchors.fill: parent
            Column {
                x: 36; y: 28; spacing: 22
                Text { text: "Isla · Interacciones"; font.family: Theme.font; font.pixelSize: 22; color: Theme.foreground }
                Row {
                    spacing: 16
                    CtrlBtn { id: play; iconName: "play_arrow"; primary: true; size: 48; accessibleName: "Reproducir"; onClicked: iconName = iconName === "pause" ? "play_arrow" : "pause" }
                    CtrlBtn { iconName: "chevron_left"; size: 28 }
                    CtrlBtn { iconName: "chevron_right"; size: 28 }
                    CtrlBtn { iconName: "settings"; size: 32 }
                    CtrlBtn { iconName: "close"; size: 32 }
                    Toggle { id: toggle; checked: true; onToggled: on => checked = on }
                    CtrlBtn { iconName: "volume_off"; dim: true; size: 32 }
                    MotionButton {
                        id: openButton
                        width: 144; height: 40; text: "Abrir"
                        background: Rectangle { radius: 12; color: Qt.alpha(Theme.accent, 0.13 + 0.08 * openButton.interaction.presence + 0.06 * openButton.interaction.pressure) }
                        contentItem: Row {
                            spacing: 12
                            Text { text: openButton.text; color: Theme.foreground; font.family: Theme.font; font.pixelSize: 14 }
                            MaterialIcon { iconName: "arrow_forward"; hovered: openButton.hovered; font.pixelSize: 20 }
                        }
                    }
                }
                Text { text: "Sesión · acciones simuladas"; font.family: Theme.font; font.pixelSize: 13; color: Theme.dim }
                Item {
                    width: 740; height: 470
                    GlassCard { anchors.fill: parent; radius_: 34 }
                    SessionSurface { id: session; open: true; actions: fake }
                }
            }
        }
        QtObject { id: fake; property int calls: 0; function lock() { calls++ } function suspend() { calls++ } function logout() { calls++ } function reboot() { calls++ } function shutdown() { calls++ } }
        TestCase {
            name: "VisualInteraction"
            when: window.visible
            function shot(name) {
                scene.grabToImage(result => result.saveToFile("/tmp/isla-interaction-" + name + ".png"))
                wait(70)
            }
            function check(ok, why) { if (!ok) { console.error("FAIL: visual interaction", why); throw new Error(why) } }
            function test_preview() {
                wait(500)
                shot("normal")
                mouseMove(openButton, 70, 20)
                wait(150); shot("hover")
                mousePress(openButton, 70, 20)
                wait(80); shot("press")
                mouseRelease(openButton, 70, 20)
                wait(200); shot("release")
                mouseClick(play, 24, 24)
                wait(45); shot("swap")
                wait(220); shot("final")
                for (let action of [4, 2, 3, 1]) {
                    const card = findChild(session, "sessionAction" + action)
                    const icon = findChild(session, "sessionIcon" + action)
                    check(card && icon, "session action present " + action)
                    const width = card.width
                    mouseMove(card, card.width / 2, card.height / 2)
                    wait(180)
                    check(icon.emphasis > 0.95, "session icon responds " + action)
                    if (action === 3) shot("power-hover")
                    mousePress(card, card.width / 2, card.height / 2)
                    wait(90)
                    check(card.background.scale < 0.98 && card.contentItem.scale < 0.98, "session composition compresses")
                    check(card.scale === 1 && card.width === width, "session hitbox stays fixed")
                    if (action === 3) shot("power-press")
                    mouseMove(scene, scene.width - 2, scene.height - 2)
                    mouseRelease(scene, scene.width - 2, scene.height - 2)
                    wait(240)
                    check(Math.abs(card.background.scale - 1) < 0.003, "session release settles")
                }
                check(fake.calls === 0 && session.pending === -1, "cancelled gestures never execute power")
                console.log("PASS: Wayland sequence plus all four session icons, composition pressure, fixed hitboxes and safe cancellation")
            }
        }
    }
}
