import QtQuick
import QtQuick.Controls.Basic
import QtTest
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    Window {
        id: scene
        visible: true; width: 820; height: 430
        title: "Isla · Escritura"
        color: Theme.background
        Rectangle { anchors.fill: parent; color: scene.color }
        Column {
            x: 24; y: 24; width: 340; spacing: 16
            Text { text: "Búsqueda"; color: Theme.foreground; font.pixelSize: 18 }
            IslaTextField { id: search; width: parent.width; height: 44; floating: false; placeholderText: "Buscar aplicaciones…" }
            Text { text: "Etiqueta flotante"; color: Theme.foreground; font.pixelSize: 18 }
            IslaTextField { id: field; width: parent.width; height: 48; placeholderText: "Nombre de la fuente" }
            Text { text: "Respuesta protegida"; color: Theme.foreground; font.pixelSize: 18 }
            TextField {
                id: secret
                width: parent.width; height: 44
                color: Theme.foreground; font.pixelSize: 16
                echoMode: TextInput.Password; passwordMaskDelay: 0
                placeholderText: "Contraseña"; placeholderTextColor: "transparent"
                background: Rectangle { radius: 12; color: Qt.alpha(Theme.foreground, 0.06); border.color: Theme.hair }
                cursorDelegate: InputCaret { input: secret; color: secret.color }
                InputPlaceholder { input: secret }
            }
        }
        WifiCredentials { id: wifi; x: 410; y: 24; width: 380; height: 360; ssid: "Red de prueba"; active: false }
        Timer { id: done; interval: 100; onTriggered: Qt.quit() }
        TestCase {
            name: "TextboxMotion"
            when: scene.visible
            function ensure(ok, message) { if (!ok) console.error("FAIL: " + message); verify(ok, message) }
            function shot(name) {
                const dir = Quickshell.env("ISLA_TEXTBOX_SHOTS")
                if (!dir) return
                scene.contentItem.grabToImage(result => result.saveToFile(dir + "/" + name + ".png"))
                wait(60)
            }
            function test_typing() {
                Config.update({appearance: {reduceMotion: false, motionScale: 1}})
                wait(150)
                search.forceActiveFocus()
                wait(80)
                let caret = findChild(search, "inputCaret")
                const hint = findChild(search, "inputPlaceholder")
                ensure(caret && caret.engaged, "caret engages with focus")
                shot("01-ready")
                for (let i = 0; i < 12; i++) {
                    keyClick(Qt.Key_A)
                    ensure(caret.ink === 1, "typing keeps caret solid")
                    ensure(Math.abs(caret.x - search.cursorRectangle.x) <= 1, "caret follows native position immediately")
                }
                ensure(!hint.visible, "placeholder never overlaps typing")
                shot("02-typing")
                search.selectAll()
                ensure(!caret.engaged, "selection hides the caret")
                keyClick(Qt.Key_Backspace)
                ensure(search.length === 0, "selection deletion remains native")
                wait(180)
                ensure(hint.opacity === 1, "hint returns after clearing")
                search.insert(0, "Texto largo de prueba áéíóú · 漢字 · 🙂 ".repeat(4))
                search.cursorPosition = search.length
                ensure(Math.abs(caret.x - search.cursorRectangle.x) <= 1, "long insertion and scroll never trail")
                keyClick(Qt.Key_Home)
                ensure(search.cursorPosition === 0, "home navigation")
                keyClick(Qt.Key_End)
                ensure(search.cursorPosition === search.length, "end navigation")
                shot("03-long-input")
                wait(700)
                ensure(caret.resting, "idle caret resumes soft blink")
                shot("03b-idle")
                search.visible = false
                ensure(!caret.engaged && !caret.resting && caret.ink === 1, "hidden input stops and resets")
                search.visible = true
                field.forceActiveFocus()
                wait(70); shot("04a-floating-moving")
                wait(180)
                const floatingHint = findChild(field, "inputPlaceholder")
                ensure(Math.abs(floatingHint.scale - 0.72) < 0.01, "floating label settles without font reflow")
                keyClick(Qt.Key_I); keyClick(Qt.Key_N)
                shot("04-floating")
                secret.forceActiveFocus()
                keyClick(Qt.Key_A); keyClick(Qt.Key_B)
                const secureCaret = findChild(secret, "inputCaret")
                ensure(secret.displayText !== secret.text && secureCaret.engaged, "protected field uses same caret and keeps masking")
                shot("05-protected")
                secret.readOnly = true
                ensure(!secureCaret.engaged, "read-only state stops cursor work")
                secret.clear()
                wifi.active = true
                wait(100)
                ensure(wifi.input.activeFocus, "wifi focus")
                keyClick(Qt.Key_A); keyClick(Qt.Key_B)
                const wifiCaret = findChild(wifi.input, "inputCaret")
                ensure(wifiCaret && wifiCaret.engaged, "wifi shares typing response")
                shot("06-wifi")
                Config.update({appearance: {reduceMotion: true}})
                ensure(wifiCaret.ink === 1 && !wifiCaret.resting, "reduced motion is steady")
                wifi.active = false
                ensure(wifi.input.length === 0 && !wifiCaret.engaged, "closing clears secret and stops cursor")
                console.log("PASS: caret geometry, typing, selection, long insertion, navigation, placeholders, masking, hidden and reduced motion")
                done.start()
            }
        }
    }
}
