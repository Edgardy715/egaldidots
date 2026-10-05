import QtQuick
import Quickshell
import "lockscreen"
import "Singletons"

ShellRoot {
    id: test
    settings.watchFiles: false
    property int step: 0

    function check(ok, message) {
        if (!ok) { console.error("FAIL: " + message); Qt.exit(1) }
    }
    function find(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children) {
            const found = find(child, name)
            if (found) return found
        }
        return null
    }
    function countMatches(input, dots) {
        check(dots.model.count === input.text.length, "dots match committed text length")
        for (let i = 0; i < dots.model.count; i++)
            check(Object.keys(dots.model.get(i)).join() === "slot", "visual model contains identifiers only")
    }
    function capture(name) {
        const directory = Quickshell.env("ISLA_LOCK_CAPTURE_DIR")
        if (directory) surface.grabToImage(result => result.saveToFile(directory + "/" + name + ".png"))
    }

    Window {
        visible: true; width: 1200; height: 900
        LockSurface {
            id: surface
            anchors.fill: parent
            username: "Vista previa"
            avatarSource: ""
            secured: true
            preview: true
            onUnlockRequested: test.check(false, "fixture must not authenticate")
        }
    }
    Timer {
        interval: 180; repeat: true; running: true
        onTriggered: {
            const input = test.find(surface, "lockPassword")
            const dots = test.find(surface, "lockPasswordDots")
            test.check(!!input && !!dots, "lock input and visual dots load")
            switch (test.step++) {
            case 0:
                surface.activateInput("ab")
                test.countMatches(input, dots)
                input.insert(1, "C")
                test.countMatches(input, dots)
                input.select(0, 2)
                input.remove(0, 2)
                test.countMatches(input, dots)
                test.check(input.text === "b", "range deletion keeps remaining text")
                break
            case 1:
                input.text = "fixture"
                input.select(2, 5)
                input.remove(2, 5)
                input.insert(2, "XY")
                test.countMatches(input, dots)
                input.text = "sample"
                test.countMatches(input, dots)
                break
            case 2:
                for (let i = 0; i < 20; i++) {
                    input.insert(0, "x")
                    input.remove(0, 1)
                }
                test.countMatches(input, dots)
                input.selectAll()
                test.check(input.selectionEnd - input.selectionStart === input.text.length, "selection stays native")
                input.clear()
                test.countMatches(input, dots)
                break
            case 3:
                input.text = "sample"
                test.countMatches(input, dots)
                break
            case 4:
                test.check(dots.contentWidth > 0 && dots.itemAtIndex(0) !== null, "visual dots are instantiated")
                test.capture("typing-steady")
                break
            case 5:
                input.text = "x".repeat(60)
                input.cursorPosition = input.text.length
                test.countMatches(input, dots)
                break
            case 6:
                test.check(test.find(surface, "lockField").dotOffset < 0, "long input follows the caret")
                surface.visible = false
                input.text = "hidden"
                test.countMatches(input, dots)
                surface.visible = true
                test.check(Config.update({appearance: {reduceMotion: true}}).ok, "temporary reduced motion applies")
                input.clear()
                input.insert(0, "ok")
                test.countMatches(input, dots)
                break
            case 7:
                surface.responseVisible = true
                test.check(!test.find(surface, "lockPasswordDots").visible, "visible response hides custom dots")
                surface.responseVisible = false
                test.check(dots.visible, "masked response restores custom dots")
                console.log("PASS: lockscreen rapid edits, selection, visibility, reduced motion and visual model privacy")
                Qt.quit()
            }
        }
    }
}
