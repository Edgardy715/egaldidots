import QtQuick
import Quickshell
import "Singletons"
import "components"

// Synthetic model only: never starts the wallpaper apply process.
ShellRoot {
    WallpaperController { id: controller }

    function check(value, message) {
        if (!value) { console.error("FAIL", message); Qt.exit(1) }
    }

    Timer {
        interval: 300
        running: true
        onTriggered: {
            const path = "/tmp/wall #1?.png"
            const thumb = "/tmp/thumb #1?.jpg"
            const source = Wallpapers.fileSource(thumb, 2)
            Wallpapers.list = [{ path: path, baseName: "wall #1?", thumb: thumb,
                                 thumbReady: true, thumbSource: source, cacheRevision: 2 }]
            check(controller.wallpaperModel.count === 1, "model receives scanned item")
            check(controller.wallpaperModel.get(0).thumbSource === source,
                  "model retains versioned thumbnail URL")
            check(source.includes("%23") && source.includes("%3F") && source.endsWith("?v=2"),
                  "file URL escapes reserved path characters")
            Wallpapers.current = path
            check(controller.wallpaperModel.get(0).thumbSource === source,
                  "current wallpaper update retains thumbnail revision")
            controller.applyPath("/tmp/missing.png")
            check(controller.feedback === "" && controller.pendingPath === "",
                  "stale preview path cannot apply a different wallpaper")
            Wallpapers.requestThumbnail(path, "/tmp/wrong-cache.jpg")
            check(!Wallpapers.pendingThumbs[path], "thumbnail request rejects wrong cache path")
            Wallpapers.list = Wallpapers.list.concat([{path:"/tmp/second.png", baseName:"second", thumb:"/tmp/second.jpg", thumbReady:false}])
            controller.pendingPath = path
            controller.feedback = "done"
            controller.selectedIndex = 1
            check(controller.feedback === "", "exploring after completion clears done and permits next apply")
            console.log("PASS: wallpaper model URLs, revisions and stale requests")
            Qt.quit()
        }
    }
}
