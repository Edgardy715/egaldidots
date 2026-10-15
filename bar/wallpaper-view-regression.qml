import QtQuick
import QtTest
import Quickshell
import "Singletons"
import "components"

ShellRoot {
    settings.watchFiles: false
    Window {
        id: window
        visible: true
        width: 1040; height: 720
        Rectangle {
            id: stage
            anchors.centerIn: parent
            width: 1000; height: 640
            color: Theme.background
            ListModel { id: library }
            WallpaperView {
                id: view
                anchors.fill: parent
                open: true
                wallpaperModel: library
                previewAccent: Theme.accent
                property int closes: 0
                property int commits: 0
                onRequestClose: closes++
                onCommitRequested: commits++
            }
        }
        TestCase {
            id: checks
            name: "WallpaperView"
            property bool completed: false
            when: window.visible
            function assertTrue(value, message) {
                if (!value) { console.error("FAIL: wallpaper view", message); Qt.exit(1); throw new Error(message) }
            }
            function assertEqual(actual, expected, message) { assertTrue(actual === expected, message || (actual + " !== " + expected)) }
            function waitFor(predicate, timeout) {
                const deadline = Date.now() + (timeout || 3000)
                while (!predicate() && Date.now() < deadline) wait(15)
                assertTrue(predicate(), "timed out awaiting wallpaper state " + new Error().stack)
            }
            function expectProperty(item, key, value) { waitFor(() => item[key] === value); assertEqual(item[key], value, key) }
            function capture(name) {
                const dir = Quickshell.env("ISLA_TEST_OUTPUT")
                if (!dir) return
                let saved = false
                stage.grabToImage(image => { saved = image.saveToFile(dir + "/" + name + ".png") })
                waitFor(() => saved, 3000)
            }
            function find(item, name) {
                if (item.objectName === name) return item
                for (const child of item.children) { const found = find(child, name); if (found) return found }
                return null
            }
            function test_journey() {
                Config.update({appearance:{reduceMotion:false}})
                for (const color of ["#888888", "#ffff00", "#0000ff", "#b776ab"]) {
                    view.previewAccent = color
                    const luminance = view.previewLuminance
                    const content = view.onPreviewAccent.r === 0 ? 0 : 1
                    assertTrue((Math.max(luminance,content)+0.05)/(Math.min(luminance,content)+0.05) >= 4.5, "apply label contrast")
                }
                view.previewAccent = Theme.accent
                const paths = ["wallhaven-5yk6k9.jpg", "wallhaven-d8ey2m.png", "wallhaven-7pzrwv.png"]
                for (const name of paths) library.append({path: Quickshell.shellDir + "/../wallpapers/Wallpapers/" + name, baseName:name, thumb:"", thumbSource:"file://" + Quickshell.shellDir + "/../wallpapers/Wallpapers/" + name, thumbReady:true, thumbFailed:false, applied:false})
                wait(700)
                const hero = find(view, "heroImage")
                expectProperty(hero, "status", Image.Ready)
                expectProperty(hero, "opacity", 1)
                capture("01-gallery")
                view.cycle(1); waitFor(() => hero.opacity > 0 && hero.opacity < 1, 3000); capture("motion-midpoint")
                const midSource = hero.source.toString()
                const midOpacity = hero.opacity
                view.cycle(1)
                assertEqual(hero.source.toString(), midSource, "retarget keeps visible fade")
                assertTrue(hero.opacity >= midOpacity, "retarget never resets opacity")
                wait(500)
                view.selectIndex(0); wait(450)
                for (let i=0; i<8; i++) { view.cycle(1); wait(35) }
                expectProperty(hero, "opacity", 1)
                assertEqual(view.currentIndex, 2)
                capture("02-navigation")
                const checkInline = find(view, "wallpaperInlineConfirmation")
                view.applying = true; view.feedback = "applying"
                const selection = view.currentIndex
                view.cycle(1); assertEqual(view.currentIndex, selection)
                wait(250)
                assertTrue(checkInline.busy && checkInline.visible, "loading belongs to wallpaper view")
                capture("03-applying")
                view.applying = false; view.feedback = "error"; view.applyError = "No se pudo actualizar la paleta. Puedes volver a intentarlo."
                stage.width = 640
                Config.update({appearance:{fontScale:1.4}})
                wait(150); capture("04-error-compact")
                library.setProperty(view.currentIndex, "applied", true)
                wait(30); assertTrue(view.selApplied, "applied marker updates for current selection")
                view.commitSelection(); assertEqual(view.commits, 1, "partial apply can retry colors")
                view.feedback = "done"; view.applied(); wait(100)
                view.closing = true; view.open = false; wait(100)
                view.closing = false; view.open = true
                wait(950); assertEqual(view.closes, 0, "reopen cancels old completion close")
                Config.update({appearance:{fontScale:1.75}})
                wait(80); capture("06-large-type")
                Config.update({appearance:{fontScale:1,reduceMotion:true}})
                view.cycle(1); wait(100)
                expectProperty(hero,"opacity",1)
                view.feedback = ""; stage.width = 1000
                library.setProperty(view.currentIndex, "path", "/tmp/isla-wallpaper-missing.png")
                expectProperty(hero, "status", Image.Error)
                assertEqual(find(view, "previewThumbnail").opacity, 1, "failed hero retains thumbnail fallback")
                library.clear(); wait(100); capture("05-empty")
                view.commitSelection(); assertEqual(view.commits,1)
                completed = true
                console.log("PASS: wallpaper preview, rapid navigation, busy gating, error layout, reopen and reduced motion")
            }
        }
        Timer { interval: 100; running: checks.completed; onTriggered: Qt.quit() }
    }
}
