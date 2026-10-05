import QtQuick
import QtTest
import Quickshell
import "surfaces"
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    Window {
        id: window
        visible: true
        width: 700; height: 520
        color: Theme.background
        Rectangle { anchors.fill: parent; color: window.color }
        LauncherSurface { id: launcher; x: 40; y: 30; width: 620; height: 460; open: true }
        WallpaperSurface { id: wallpaper; x: 40; y: 30; width: 620; height: 460; visible: false; open: false }
        Timer { id: exitTimer; interval: 100; onTriggered: Qt.quit() }
        TestCase {
            name: "LauncherInputMotion"
            when: window.visible
            function shot(name) {
                const dir = Quickshell.env("ISLA_INPUT_SHOTS")
                if (!dir) return
                window.contentItem.grabToImage(result => result.saveToFile(dir + "/" + name + ".png"))
                wait(120)
            }
            function test_typing() {
                wait(150)
                const input = findChild(launcher, "launcherSearch")
                verify(input, "launcher input exists")
                input.forceActiveFocus()
                verify(input.activeFocus, "native input accepts focus")
                shot("launcher-empty")
                keyClick(Qt.Key_C)
                keyClick(Qt.Key_A)
                keyClick(Qt.Key_L)
                keyClick(Qt.Key_C)
                compare(launcher.query, "calc")
                compare(input.cursorPosition, 4)
                wait(160)
                shot("launcher-typed")
                input.text = "calculus"
                compare(launcher.query, "calculus")
                input.selectAll()
                keyClick(Qt.Key_Backspace)
                compare(launcher.query, "")
                compare(input.cursorPosition, 0)
                shot("launcher-cleared")
                Config.update({ appearance: { reduceMotion: true } })
                launcher.open = false
                wait(100)
                verify(!launcher.query.length, "close keeps no stale input")
                launcher.open = true
                wait(Motion.morph + 100)
                verify(input.activeFocus, "focus returns after reopening")
                shot("launcher-reopened")
                if (Quickshell.env("ISLA_INPUT_SHOTS") && Wallpapers.count > 1) {
                    launcher.visible = false
                    wallpaper.visible = true
                    wallpaper.open = true
                    wait(650)
                    shot("wallpaper-first")
                    wallpaper.cycle(1)
                    wallpaper.cycle(1)
                    wallpaper.cycle(-1)
                    wait(650)
                    shot("wallpaper-retarget")
                }
                console.log("PASS: launcher native typing, clear, reduced motion, reopen and optional wallpaper preview")
                exitTimer.start()
            }
        }
    }
}
