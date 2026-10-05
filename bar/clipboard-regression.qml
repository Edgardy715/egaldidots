import QtQuick
import Quickshell
import "surfaces"
import "Singletons"

ShellRoot {
    Window {
        id: scene
        property int frames: 0
        property int framesBeforeClear: 0
        property int captureStep: 0
        readonly property string kind: Quickshell.env("ISLA_CLIPBOARD_TEST_TYPE")
        function readyImage(item, name) {
            if (item.objectName === name && item.status === Image.Ready) return true
            for (const child of item.children)
                if (readyImage(child, name)) return true
            return false
        }
        visible: true
        width: 620
        height: 540
        FrameAnimation { running: true; onTriggered: scene.frames++ }
        ClipboardSurface {
            id: clipboard
            anchors.fill: parent
            open: true
            onRequestClose: {
                console.log("PASS: clipboard loads, filters and copies without blocking")
                Qt.quit()
            }
        }
        Component.onCompleted: if (kind === "clear-reduced") Config.update({appearance: {reduceMotion: true}})
        Timer {
            interval: 50; repeat: true
            running: Quickshell.env("ISLA_CLIPBOARD_CAPTURE_DIR").length > 0
            onTriggered: {
                scene.captureStep++
                if (scene.captureStep >= 23 && scene.captureStep <= 29) {
                    const path = Quickshell.env("ISLA_CLIPBOARD_CAPTURE_DIR") + "/" + scene.kind + "-" + scene.captureStep + ".png"
                    clipboard.grabToImage(result => result.saveToFile(path))
                }
            }
        }
        Timer {
            interval: 400
            running: true
            onTriggered: {
                if (scene.frames < 5 || clipboard.entries.length !== 2 || clipboard.entries[0].text !== "texto") {
                    console.error("FAIL: clipboard entries")
                    Qt.exit(1)
                    return
                }
                clipboard.selectedIndex = 1
                clipboard.query = "texto"
                clipboard.filterEntries()
                if (clipboard.selectedIndex !== 0 || clipboard.filteredEntries.length !== 1) {
                    console.error("FAIL: clipboard selection after filtering")
                    Qt.exit(1)
                    return
                }
                clipboard.query = ""
                clipboard.filterEntries()
                clipboard.selectedIndex = Quickshell.env("ISLA_CLIPBOARD_TEST_TYPE") === "image" ? 1 : 0
            }
        }
        Timer {
            interval: 1000
            running: true
            onTriggered: {
                if (scene.kind.startsWith("clear")) {
                    scene.framesBeforeClear = scene.frames
                    clipboard.clearHistory()
                    clipboard.clearHistory()
                    clipboard.copyEntry(clipboard.entries[0])
                    if (!clipboard.clearing || clipboard.copying) {
                        console.error("FAIL: clearing guard")
                        Qt.exit(1)
                    }
                    return
                }
                if (clipboard.selectedIndex === 1 && (!scene.readyImage(clipboard, "clipboardThumbnail")
                        || !scene.readyImage(clipboard, "clipboardSelectedPreview"))) {
                    console.error("FAIL: clipboard image previews")
                    Qt.exit(1)
                    return
                }
                clipboard.copyEntry(clipboard.selectedEntry)
            }
        }
        Timer {
            interval: 1250
            running: scene.kind === "clear"
            onTriggered: {
                if (!clipboard.clearing || clipboard.entries.length !== 2) {
                    console.error("FAIL: clear must preserve content during exit")
                    Qt.exit(1)
                }
            }
        }
        Timer {
            interval: 1500
            running: scene.kind.startsWith("clear")
            onTriggered: {
                const failed = scene.kind === "clear-error"
                if (clipboard.clearing || scene.frames - scene.framesBeforeClear < 5
                        || (failed ? clipboard.entries.length !== 2 || !clipboard.errorMessage.length
                                   : clipboard.entries.length !== 0 || clipboard.filteredEntries.length !== 0 || clipboard.selectedEntry !== null)) {
                    console.error("FAIL: clear result or animation frames")
                    Qt.exit(1)
                    return
                }
                console.log("PASS: clipboard clears asynchronously")
                Qt.quit()
            }
        }
        Timer { interval: 3000; running: true; onTriggered: { console.error("FAIL: clipboard timeout"); Qt.exit(1) } }
    }
}
