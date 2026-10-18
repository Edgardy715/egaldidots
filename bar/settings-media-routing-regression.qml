import QtQuick
import QtTest
import Quickshell
import "Singletons"
import "components"
import "windows"

ShellRoot {
    settings.watchFiles: false
    SurfaceRouter { id: navigation; focusedMonitorName: Quickshell.screens[0].name }
    IslandOverlay { id: overlay; router: navigation; modelData: Quickshell.screens[0] }
    TestCase {
        id: checks
        parent: overlay.contentItem
        name: "SettingsMediaRouting"
        when: Config.loaded && overlay.visible
        property bool finished: false
        function findEditor(item) {
            if (typeof item.showProfile === "function") return item
            for (const child of item.children || []) {
                const found = findEditor(child)
                if (found) return found
            }
            return null
        }
        function capture(name) {
            const directory = Quickshell.env("ISLA_MEDIA_CAPTURE_DIR")
            if (!directory) return
            let scene = findEditor(overlay.contentItem)
            while (scene.parent && scene.parent !== overlay.contentItem) scene = scene.parent
            let saved = false
            scene.grabToImage(image => { saved = image.saveToFile(directory + "/" + name + ".png") })
            tryVerify(() => saved, 3000)
        }
        function test_routing() {
            try {
                const pill = findChild(overlay.contentItem, "islandPill")
                const media = findChild(overlay.contentItem, "islandMediaCompanion")
                verify(pill && media)
                for (const layout of ["split", "compact"]) {
                    for (const reduced of [false, true]) {
                        console.log("MODE", layout, reduced)
                        verify(Config.update({appearance: {barLayout: layout, reduceMotion: reduced}}).ok)
                        navigation.reduceMotion = reduced
                        tryCompare(overlay, "compact", layout === "compact", 5000)
                        tryCompare(overlay, "layoutChanging", false, 5000)
                        Players.fixturePresent = true
                        Players.fixturePlaying = true
                        navigation.close()
                        wait(800)
                        navigation.toggleSurface("", "settings")
                        compare(navigation.openSurface, "settings")
                        compare(navigation.mediaDockPendingMon, "")
                        verify(!overlay.mediaPanelOpen)
                        if (layout === "split") tryCompare(media, "open", true, 3000)
                        wait(1400)
                        if (!reduced) capture(layout + "-settings-music")
                        for (const destination of ["calendar", "media", "session"]) {
                            console.log("DESTINATION", destination); navigation.toggleSurface("", destination)
                            compare(navigation.openSurface, destination)
                            if (!reduced) {
                                verify(overlay.settingsReturning, "outgoing settings must return")
                                compare(pill.surface, "")
                                verify(!media.expanded, "media must wait for settings")
                            }
                            tryCompare(overlay, "settingsReturning", false, 5000)
                            if (destination === "calendar") {
                                tryCompare(pill, "surface", "calendar", 3000)
                                tryVerify(() => findChild(pill, "calendarMediaFooter") !== null, 3000)
                                let footer = findChild(pill, "calendarMediaFooter")
                                tryCompare(footer, "visible", true, 3000)
                                wait(1400)
                                if (!reduced) capture(layout + "-calendar-music")
                                const mediaButton = findChild(pill, "calendarMediaOpen")
                                mouseClick(mediaButton, mediaButton.width / 2, mediaButton.height / 2, Qt.LeftButton)
                                compare(navigation.openSurface, "media")
                                navigation.toggleSurface("", "calendar")
                                tryVerify(() => findChild(pill, "calendarMediaFooter") && findChild(pill, "calendarMediaFooter").visible, 3000)
                                footer = findChild(pill, "calendarMediaFooter")
                                Players.fixturePlaying = false
                                tryCompare(footer, "visible", true, 3000)
                                Players.fixturePresent = false
                                tryCompare(footer, "visible", false, 1000)
                                Players.fixturePresent = true
                            }
                            navigation.toggleSurface("", "settings")
                            wait(1400)
                        }
                        navigation.present(Quickshell.screens[0].name, "auth")
                        compare(pill.surface, "auth")
                        compare(pill.z, 5)
                        verify(!overlay.settingsOpen)
                        navigation.toggleSurface("", "settings")
                        wait(1400)
                        navigation.toggleSurface("", "calendar")
                        wait(60)
                        navigation.toggleSurface("", "settings")
                        tryCompare(overlay, "settingsOpen", true, 3000)
                        wait(1200)
                        compare(pill.surface, "")
                        verify(!overlay.settingsReturning, "reopened settings must cancel return")
                        if (layout === "split") verify(media.open)
                        navigation.close()
                        wait(1200)
                        navigation.toggleSurface("", "media")
                        tryVerify(() => overlay.mediaSurfaceItem !== null, 4000)
                        let mediaView = overlay.mediaSurfaceItem
                        let artwork = findChild(mediaView, "mediaArtworkImage")
                        tryVerify(() => artwork.ready, 4000)
                        verify(artwork.transitionSource !== null, "both layouts share panel artwork state")
                        wait(900)
                        const displayedArt = artwork.displayedSource
                        navigation.close()
                        if (!reduced) {
                            verify(artwork.ready, "close retains decoded art on its first frame")
                            compare(artwork.displayedSource, displayedArt)
                            wait(35)
                            if (overlay.mediaSurfaceItem && overlay.mediaSurfaceItem.visible)
                                verify(findChild(overlay.mediaSurfaceItem, "mediaArtworkImage").ready,
                                    "art remains while outgoing panel is visible")
                        }
                        wait(1000)
                    }
                }
                navigation.close()
                console.log("PASS: settings media routing, staged destinations, interruption, pause and removal in both layouts and motion modes")
            finished = true
            } catch (error) { console.error("FAIL: settings media routing", error.message); finished = true }
        }
    }
    Timer { interval: 100; running: checks.finished; onTriggered: Qt.quit() }
    Timer { interval: 90000; running: true; onTriggered: Qt.exit(2) }
}
