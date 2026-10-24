import QtQuick
import QtTest
import Quickshell
import "components"
import "windows"
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    SurfaceRouter { id: router; focusedMonitorName: Quickshell.screens[0].name; reduceMotion: Flags.reduceMotion }
    IslandOverlay { id: overlay; modelData: Quickshell.screens[0]; router: router }
    Timer { id: finish; interval: 120; onTriggered: Qt.quit() }
    TestCase {
        name: "PetsSurfaces"
        when: Config.loaded
        function check(condition, message) { if (!condition) throw new Error(message) }
        function pets(node) {
            let count = ["mediaPetHost", "wallpaperPetHost", "workspacePetHost"].includes(node.objectName)
                && node.petVisible ? 1 : 0
            for (const child of node.children || []) count += pets(child)
            return count
        }
        function until(predicate, message) {
            for (let i = 0; i < 300 && !predicate(); i++) {
                check(pets(overlay.contentItem) <= 1, "never duplicate pets during transition")
                wait(20)
            }
            if (!predicate()) {
                const modules = findChild(overlay.contentItem, "islandModules")
                console.log("PET_CONTEXT_DEBUG", JSON.stringify({enabled: Config.pets.enabled, size: Config.pets.size,
                    monitor: modules.petMonitorActive, fullscreen: overlay.monFullscreen,
                    visible: overlay.visible, changing: overlay.layoutChanging, phase: overlay.layoutPhase,
                    workspace: !!modules.workspaceItem, modulePresented: modules.presented,
                    width: modules.workspaceItem ? modules.workspaceItem.width : 0,
                    fits: modules.workspaceItem ? modules.workspaceItem.fits : false,
                    exposed: modules.workspaceModule.exposure}))
            }
            check(predicate(), message)
            check(pets(overlay.contentItem) <= 1, "one visible pet after transition")
        }
        function shot(name) {
            const dir = Quickshell.env("ISLA_TEST_OUTPUT")
            if (!dir) return
            findChild(overlay.contentItem, "islandOverlayContent").grabToImage(result => result.saveToFile(dir + "/" + name + ".png"))
            wait(100)
        }
        function open(name) { router.toggleSurface(Quickshell.screens[0].name, name) }
        function host(name) { return findChild(overlay.contentItem, name) }
        function test_surfaces() {
            try {
                const modules = findChild(overlay.contentItem, "islandModules")
                until(() => modules.petVisible, "workspace pet first")
                Config.update({pets: {workspaceSurface: false}})
                check(!modules.petVisible, "workspace surface opt-out")
                Config.update({pets: {workspaceSurface: true, character: "blob", sleepEnabled: false, gazeEnabled: false}})
                until(() => modules.petVisible, "workspace opt-in")
                const workspace = host("workspacePetHost")
                check(workspace.item.character === "blob" && !workspace.item.runtime.sleepEnabled
                    && !workspace.item.runtime.gazeEnabled, "workspace receives character and behaviors")
                Config.update({pets: {character: "ghost", sleepEnabled: true, gazeEnabled: true}})
                shot("workspaces")
                for (const layout of ["split", "compact"]) {
                    Config.update({appearance: {barLayout: layout}})
                    until(() => overlay.compact === (layout === "compact") && !overlay.layoutChanging && modules.petVisible, "layout settles")
                    open("media")
                    until(() => host("mediaPetHost") && host("mediaPetHost").petVisible, "media host receives context in " + layout)
                    let media = host("mediaPetHost")
                    Config.update({pets: {mediaSurface: false}})
                    check(!media.item, "composition media opt-out")
                    Config.update({pets: {mediaSurface: true, character: "octopus"}})
                    until(() => media.petVisible, "composition media opt-in")
                    check(media.item.character === "octopus", "media character from Config")
                    Config.update({pets: {character: "ghost"}})
                    check(!modules.petVisible && pets(overlay.contentItem) === 1, "media displaces workspace pet")
                    check(!media.item.runtime.reacting, "opening does not replay old track")
                    const baselineConsumers = Object.keys(Cava.consumers).sort().join(",")
                    Players.fixture.isPlaying = false
                    check(media.item.runtime.resting && !media.item.runtime.reacting, "pause gives resting eyes")
                    wait(300)
                    shot("media-" + layout + "-paused")
                    Players.fixture.isPlaying = true
                    check(media.item.runtime.reacting && !media.item.runtime.resting, "resume reacts")
                    wait(700)
                    media.item.runtime.sleep()
                    Players.fixture.position = 120
                    wait(120)
                    check(media.item.runtime.sleeping, "MPRIS position never wakes or reacts")
                    Players.fixture.trackTitle = "New fixture track " + layout
                    check(!media.item.runtime.sleeping && media.item.runtime.reacting, "track metadata wakes pet")
                    wait(700)
                    check(Object.keys(Cava.consumers).sort().join(",") === baselineConsumers, "pet events add no audio consumer")
                    shot("media-" + layout)
                    router.focusedMonitorName = "inactive-monitor"
                    check(!media.item, "media unloads on monitor change")
                    Players.fixture.trackTitle = "Hidden track " + layout
                    router.focusedMonitorName = Quickshell.screens[0].name
                    until(() => media.item !== null, "media returns")
                    check(!media.item.runtime.reacting, "hidden track is not replayed")
                    let owner = media.parent
                    while (owner && !String(owner).includes("PillSurfaceHost")) owner = owner.parent
                    check(owner !== null, "find actual presenting host")
                    owner.suspended = true
                    check(!media.item, "suspended surface unloads pet")
                    Players.fixture.trackTitle = "Suspended track " + layout
                    owner.suspended = false
                    until(() => media.item !== null, "resume suspended host")
                    check(!media.item.runtime.reacting, "suspended event never replays")
                    open("wallpaper")
                    until(() => host("wallpaperPetHost") && host("wallpaperPetHost").petVisible, "wallpaper host after media docking")
                    const wallpaper = findChild(overlay.contentItem, "wallpaperThumbnails")
                    const surface = findChild(overlay.contentItem, "islandPill").surfaceItem
                    let pet = host("wallpaperPetHost")
                    Config.update({pets: {wallpaperSurface: false}})
                    check(!pet.item, "composition wallpaper opt-out")
                    Config.update({pets: {wallpaperSurface: true, character: "blob"}})
                    until(() => pet.petVisible, "composition wallpaper opt-in")
                    check(pet.item.character === "blob", "wallpaper character from Config")
                    Config.update({pets: {wallpaperReactions: false}})
                    surface.selectIndex(2)
                    check(!pet.item.runtime.reacting, "wallpaper reactions opt-out")
                    Config.update({pets: {character: "ghost", wallpaperReactions: true}})
                    check(!modules.petVisible && pets(overlay.contentItem) === 1, "wallpaper displaces other hosts")
                    check(!pet.item.runtime.reacting, "wallpaper initial selection has no replay")
                    surface.selectIndex(1)
                    wait(50)
                    check(pet.item.runtime.reacting && pet.lookTarget.y > 0, "selection reaction uses thumbnail position")
                    shot("wallpaper-" + layout + "-selection")
                    wait(700)
                    shot("wallpaper-" + layout + "-settled")
                    mouseMove(wallpaper.currentItem, 56, 30)
                    check(pet.item.runtime.engaged, "thumbnail hover observes without taking input")
                    surface.selectIndex(2)
                    check(!pet.item.runtime.engaged, "keyboard selection overrides stationary hover")
                    surface.selectIndex(1)
                    mouseMove(overlay.contentItem, overlay.width - 10, overlay.height - 10)
                    wait(700)
                    surface.commitSelection()
                    check(Wallpapers.applying && Wallpapers.attempts > 0 && !pet.item.runtime.reacting, "apply click is not success")
                    Wallpapers.finish(Wallpapers.lastAttemptPath, false)
                    check(!pet.item.runtime.reacting, "failure has no success reaction")
                    surface.commitSelection()
                    Wallpapers.finish(Wallpapers.lastAttemptPath, true)
                    check(pet.item.runtime.reacting, "confirmed matching success reacts")
                    shot("wallpaper-" + layout + "-applied")
                    router.close()
                    check(!pet.item, "closing cancels wallpaper work immediately")
                    until(() => modules.petVisible, "workspace pet returns after wallpaper")
                    Players.fixture.trackTitle = "A quiet afternoon"
                    Wallpapers.current = ""
                }
                open("wallpaper")
                until(() => host("wallpaperPetHost") && host("wallpaperPetHost").petVisible, "pending apply surface opens")
                const pendingSurface = findChild(overlay.contentItem, "islandPill").surfaceItem
                pendingSurface.selectIndex(2)
                pendingSurface.commitSelection()
                const pendingPath = Wallpapers.lastAttemptPath
                check(Wallpapers.applying, "pending apply begins")
                router.close()
                Wallpapers.finish(pendingPath, true)
                until(() => modules.petVisible, "late apply result never revives closed pet")
                for (let i = 0; i < 4; i++) {
                    open("media"); wait(40)
                    open("wallpaper"); wait(40)
                    check(pets(overlay.contentItem) <= 1, "rapid retarget never duplicates pet")
                    router.close(); wait(20)
                }
                until(() => modules.petVisible, "rapid changes return to workspace")
                Config.update({appearance: {reduceMotion: true}})
                open("media")
                until(() => host("mediaPetHost") && host("mediaPetHost").petVisible, "reduced media opens")
                Players.fixture.trackTitle = "Reduced track"
                check(!host("mediaPetHost").item.runtime.reacting, "reduced media is still")
                open("wallpaper")
                until(() => host("wallpaperPetHost") && host("wallpaperPetHost").petVisible, "reduced wallpaper opens")
                const surface = findChild(overlay.contentItem, "islandPill").surfaceItem
                surface.selectIndex(1)
                check(!host("wallpaperPetHost").item.runtime.reacting, "reduced selection stays still")
                Config.update({pets: {size: 48}})
                check(!host("wallpaperPetHost").item, "oversize wallpaper falls back to icon")
                Config.update({pets: {size: 24, enabled: false}})
                check(pets(overlay.contentItem) === 0, "opt-out unloads all surface pets")
                router.close()
                console.log("PASS: pets surface routing, unique instance, semantic media/wallpaper events, confirmed success, no audio consumers, reduced and opt-out")
                finish.start()
            } catch (error) { console.error("FAIL: pets surfaces " + error); Qt.exit(1) }
        }
    }
}
