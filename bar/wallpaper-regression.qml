import QtQuick
import Quickshell
import "Singletons"

// Uses the local library without applying or modifying wallpapers.
ShellRoot {
    Item {
        width: 1920; height: 1080
        Pill { id: pill; s: 1; screenName: "wallpaper-regression" }
    }
    function check(ok, message) {
        if (!ok) { console.error("FAIL", message); Qt.exit(1) }
    }
    function find(item, name) {
        if (item.objectName === name) return item
        for (let child of item.children) {
            const found = find(child, name)
            if (found) return found
        }
        return null
    }
    Timer {
        interval: 20; running: true
        onTriggered: { Config.update({ appearance: { reduceMotion: true } }); pill.surface = "wallpaper" }
    }
    Timer {
        interval: 1000; running: true
        onTriggered: {
            check(pill.surfaceItem && Wallpapers.count > 1, "local library must be available")
            pill.surfaceItem.cycle(1)
            pill.surfaceItem.cycle(1)
            pill.surfaceItem.cycle(-1)
        }
    }
    Timer {
        interval: 2300; running: true
        onTriggered: {
            const preview = find(pill, "wallpaperPreview")
            const hero = find(pill, "heroImage")
            const previous = find(pill, "previousPreview")
            const thumb = find(pill, "previewThumbnail")
            check(preview && preview.height > 0 && preview.height <= preview.parent.height,
                  "preview must fit its available height")
            check(hero && hero.status === Image.Ready && hero.opacity === 1, "latest image must be visible")
            check(previous.opacity === 0 && thumb.opacity === 0,
                  "previous image and cropped thumbnail must not leak into aspect-fit margins")
            check(hero.fillMode === Image.PreserveAspectFit, "full image must not be cropped")
            console.log("PASS: wallpaper bounds, rapid navigation, aspect-fit isolation")
            Qt.quit()
        }
    }
}
