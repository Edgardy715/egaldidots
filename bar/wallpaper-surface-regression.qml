import QtQuick
import QtTest
import Quickshell
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    Window {
        id: window
        visible: true
        width: 1120; height: 740
        Rectangle {
            id: stage
            width: 1120; height: 740
            color: Theme.background
            Pill { id: pill; anchors.horizontalCenter: parent.horizontalCenter; y: 20; s: 1; screenName: "wallpaper-test"; onRequestClose: surface = "" }
        }
        TestCase {
            id: checks
            name: "WallpaperSurface"
            when: window.visible
            property bool finished: false
            function find(item, name) {
                if (item.objectName === name) return item
                for (const child of item.children) { const result = find(child, name); if (result) return result }
                return null
            }
            function capture(name) {
                const directory = Quickshell.env("ISLA_TEST_OUTPUT")
                if (!directory) return
                let saved = false
                stage.grabToImage(image => { saved = image.saveToFile(directory + "/" + name + ".png") })
                tryVerify(() => saved, 3000)
            }
            function test_surface() {
                for (const layout of ["split", "compact"]) for (const reduced of [false,true]) {
                    Config.update({appearance:{barLayout:layout,reduceMotion:reduced}})
                    pill.surface = "wallpaper"
                    tryVerify(() => pill.surfaceItem !== null && Wallpapers.count > 1, 5000)
                    wait(reduced ? 200 : 750)
                    verify(pill.width > 800 && pill.height > 500)
                    capture("surface-" + layout + "-" + reduced)
                    if (layout === "split" && !reduced) {
                        for (const index of [4, 5, 6, 14, 4]) {
                            pill.surfaceItem.selectIndex(index)
                            wait(45)
                        }
                        capture("strip-fast-navigation")
                        wait(300)
                        const list = find(pill, "wallpaperThumbnails")
                        let visibleThumbnails = 0
                        for (const child of list.contentItem.children) {
                            if (child.objectName !== "wallpaperThumbnail"
                                || child.x + child.width <= list.contentX || child.x >= list.contentX + list.width) continue
                            const image = find(child, "wallpaperThumbnailImage")
                            if (!image || image.status !== Image.Ready) {
                                console.error("FAIL: visible wallpaper thumbnail", child.index)
                                Qt.exit(1); return
                            }
                            visibleThumbnails++
                        }
                        if (visibleThumbnails < Math.floor(list.width / (112 + 10))) { console.error("FAIL: incomplete thumbnail strip"); Qt.exit(1); return }
                    }
                    pill.surfaceItem.cycle(1)
                    pill.surface = ""; wait(70)
                    pill.surface = "wallpaper"; wait(reduced ? 200 : 600)
                    verify(pill.surfaceItem !== null)
                    pill.surface = ""; wait(reduced ? 200 : 600)
                }
                console.log("PASS: wallpaper surface split/compact normal/reduced and interrupted reopen")
                finished = true
            }
        }
        Timer { interval: 100; running: checks.finished; onTriggered: Qt.quit() }
    }
}
