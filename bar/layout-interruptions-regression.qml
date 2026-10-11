import QtQuick
import QtTest
import Quickshell
import "components"
import "windows"
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    QtObject {
        id: player
        property bool isPlaying: true
        property bool canControl: true
        property bool canTogglePlaying: true
        property string trackTitle: "Título largo para probar música durante cambios de composición"
        property string trackArtist: "Artista de prueba"
        property real length: 240
        property real position: 80
    }
    SurfaceRouter { id: router; focusedMonitorName: Quickshell.screens[0].name; reduceMotion: Flags.reduceMotion }
    IslandOverlay { id: overlay; modelData: Quickshell.screens[0]; router: router }
    IslandReserve { modelData: Quickshell.screens[0]; compact: overlay.compact }
    TestCase {
        name: "LayoutInterruptions"
        when: Config.loaded
        function must(ok, message) {
            if (!ok) { console.error("FAIL:", message); throw new Error(message) }
        }
        function until(predicate, message) {
            for (let i = 0; i < 375; i++) {
                if (predicate()) return
                wait(16)
            }
            must(false, message)
        }
        function settled(mode) {
            until(() => overlay.compact === (mode === "compact") && !overlay.layoutChanging, "layout settles: " + mode)
        }
        function test_notificationsAndMusic() {
            Config.update({appearance: {reduceMotion: false, barLayout: "split"}})
            settled("split")
            const pill = findChild(overlay.contentItem, "islandPill")
            const modules = findChild(overlay.contentItem, "islandModules")
            const drop = findChild(overlay.contentItem, "islandMediaCompanion")
            const notification = findChild(pill, "pillNotificationMotion")
            must(pill && modules && notification && drop, "fixture finds native modules and notification flow")
            drop.open = true
            wait(250)
            must(drop.phase !== "idle", "simulated split companion is present")
            Config.update({appearance: {barLayout: "compact"}})
            drop.open = Qt.binding(() => !overlay.layoutChanging && !overlay.compact && !overlay.surfaceOpen)
            for (let i = 0; i < 375 && overlay.layoutChanging; i++) {
                if (drop.phase !== "idle") must(!overlay.compact, "old drop absorbs before mode commit")
                wait(16)
            }
            settled("compact")
            Config.update({appearance: {barLayout: "split"}})
            settled("split")
            pill.notificationsEnabled = false
            notification.holdDuration = 250
            modules.mediaPlayer = player
            modules.hasMedia = true
            modules.mediaArtUrl = ""
            for (const mode of ["compact", "split"]) {
                router.toggleSurface("", "calendar")
                wait(250)
                notification.popup = {summary: "Notificación simulada", body: "Cambio durante la entrada", appName: "Fixture", appIcon: "", actions: []}
                wait(70)
                Config.update({appearance: {barLayout: mode}})
                settled(mode)
                compare(overlay.surface, "calendar")
                until(() => notification.notifState === "idle", "notification completes")
                until(() => !pill.surfaceNotifSuspended, "surface restores after notification")
                notification.popup = null
                router.close()
                wait(700)
                player.isPlaying = !player.isPlaying
                Config.update({appearance: {barLayout: mode === "compact" ? "split" : "compact"}})
                wait(60)
                modules.hasMedia = false
                wait(60)
                modules.hasMedia = true
                Config.update({appearance: {barLayout: mode}})
                settled(mode)
                wait(500)
                if (mode === "compact") must(modules.mediaModule.interactive, "compact music restores after reversal")
                else must(!modules.mediaModule.active && !modules.cavaActive, "split releases integrated media and CAVA")
                pill.showVolumeOSD()
                wait(100)
            }
            console.log("PASS: notification during surface/layout change, pause, media disappearance/reappearance, rapid reversal and inline OSD")
        }
    }
}
