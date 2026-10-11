import QtQuick
import QtTest
import Quickshell
import "components"
import "windows"
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    SurfaceRouter {
        id: router
        focusedMonitorName: Quickshell.screens[0].name
        reduceMotion: Flags.reduceMotion
    }
    IslandOverlay { id: overlay; modelData: Quickshell.screens[0]; router: router }
    IslandReserve { modelData: Quickshell.screens[0]; compact: overlay.compact }
    TestCase {
        id: checks
        name: "LayoutMotion"
        property bool auditEnabled: false
        Connections {
            target: overlay
            function onCompactChanged() {
                if (checks.auditEnabled && !Flags.reduceMotion)
                    checks.verify(overlay.layoutContentWithdrawn, "mode commits only after clock/modules withdraw")
            }
        }
        when: Config.loaded
        function layout(mode) {
            verify(Config.update({appearance: {barLayout: mode}}).ok)
            tryVerify(() => overlay.compact === (mode === "compact") && !overlay.layoutChanging, 6000)
        }
        function mediaReady() {
            tryVerify(() => overlay.mediaOpen && overlay.mediaSurfaceItem && overlay.mediaSurfaceItem.open, 6000)
            wait(500)
        }
        function test_bothDirections() {
            auditEnabled = true
            for (const reduced of [false, true]) {
                verify(Config.update({appearance: {reduceMotion: reduced}}).ok)
                layout("split")
                layout("compact")
                layout("split")
                router.toggleSurface("", "media")
                mediaReady()
                layout("compact")
                mediaReady()
                layout("split")
                mediaReady()
                router.close()
                wait(1000)
                for (const name of ["calendar", "mixer", "connectivity", "workspaces", "notifs", "clipboard", "launcher", "wallpaper", "overview", "settings", "session"]) {
                    router.toggleSurface("", name)
                    tryVerify(() => overlay.surface === name && !overlay.mediaDocking, 6000)
                    wait(600)
                    layout("compact")
                    compare(overlay.surface, name)
                    layout("split")
                    compare(overlay.surface, name)
                    router.close()
                    wait(650)
                }
            }
            Config.update({appearance: {reduceMotion: false}})
            for (let i = 0; i < 4; i++) {
                Config.update({appearance: {barLayout: "compact"}})
                wait(80)
                Config.update({appearance: {barLayout: "split"}})
                wait(80)
            }
            layout("compact")
            router.toggleSurface("", "media")
            wait(180)
            Config.update({appearance: {barLayout: "split"}})
            wait(180)
            Config.update({appearance: {barLayout: "compact"}})
            mediaReady()
            layout("split")
            mediaReady()
            router.close()
            layout("compact")
            Config.update({appearance: {barLayout: "split"}})
            wait(80)
            router.toggleSurface("", "calendar")
            layout("compact")
            compare(overlay.surface, "calendar")
            router.close()
            console.log("PASS: animated layouts both directions, all non-destructive surfaces, media transfer, interruptions and reduced motion")
        }
    }
}
