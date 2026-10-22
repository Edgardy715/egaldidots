import QtQuick
import QtTest
import Quickshell
import "Singletons"
import "surfaces"
import "lockscreen"

ShellRoot {
    settings.watchFiles: false
    Window {
        id: window
        visible: true; width: 1000; height: 700
        color: Theme.background
        Rectangle { anchors.fill: parent; color: Theme.background }
        OverviewSurface {
            id: overview
            width: 900; height: 340; open: true
            mon: ({id: 1, activeWorkspace: {id: 1}, width: 1920, height: 1080,
                   scale: 1, reserved: [0, 0, 0, 0], x: 0, y: 0})
            windowsByWorkspace: ({})
            toplevelByAddress: ({})
            hasMedia: false; mediaArtUrl: ""; mediaTitle: ""; mediaArtist: ""
        }
        LockSurface {
            id: lock
            anchors.fill: parent
            username: "Fixture"; avatarSource: ""; preview: true; secured: true
        }
        TestCase {
            when: Config.loaded && window.visible
            function imageWithSource(item, source) {
                if (item.source !== undefined && String(item.source) === source) return item
                for (const child of item.children || []) {
                    const found = imageWithSource(child, source)
                    if (found) return found
                }
                return null
            }
            function test_reservedCharacters() {
                let stage = "fixture path"
                try {
                    const path = Quickshell.env("ISLA_TEST_IMAGE")
                    verify(path.includes("#") && path.includes("?"))
                    // This process has isolated cache/config; no wallpaper application.
                    Wallpapers.appliedInSession = true
                    Wallpapers.current = path
                    lock.wallpaper = path
                    const expected = "file://" + path.split("/").map(encodeURIComponent).join("/")
                    stage = "overview source: " + overview.wallpaperSource
                    compare(overview.wallpaperSource, expected)
                    const imageSource = String(Qt.resolvedUrl(expected))
                    stage = "overview image: " + imageSource
                    tryVerify(() => imageWithSource(overview, imageSource) !== null)
                    stage = "lockscreen image: " + imageSource
                    tryVerify(() => imageWithSource(lock, imageSource) !== null)
                    stage = "overview decode"
                    tryCompare(imageWithSource(overview, imageSource), "status", Image.Ready)
                    stage = "lockscreen decode"
                    tryCompare(imageWithSource(lock, imageSource), "status", Image.Ready)
                    const output = Quickshell.env("ISLA_TEST_OUTPUT")
                    if (output) {
                        tryCompare(lock, "entrance", 1)
                        let captured = false
                        window.contentItem.grabToImage(image => { captured = image.saveToFile(output + "/wallpaper-path.png") })
                        tryVerify(() => captured)
                        lock.visible = false
                        wait(100)
                        captured = false
                        window.contentItem.grabToImage(image => { captured = image.saveToFile(output + "/overview-path.png") })
                        tryVerify(() => captured)
                    }
                    console.log("PASS: overview and lockscreen load reserved-character wallpaper paths")
                } catch (error) {
                    console.error("FAIL: wallpaper source (" + stage + "): " + error)
                    Qt.exit(1)
                }
            }
        }
    }
}
