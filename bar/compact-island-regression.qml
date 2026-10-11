import QtQuick
import QtTest
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    QtObject {
        id: player
        property bool isPlaying: true
        property bool canControl: true
        property bool canTogglePlaying: true
        property bool canSeek: true
        property bool positionSupported: true
        property bool lengthSupported: true
        property real length: 240
        property real position: 80
        property real rate: 1
        property string trackTitle: "Una canción de título largo"
        property string trackArtist: "Artista de prueba"
        property int toggles: 0
        function togglePlaying() { toggles++; isPlaying = !isPlaying }
    }
    Window {
        id: scene
        visible: true
        width: 1100; height: 650
        color: "#242424"
        Pill {
            id: pill
            x: (scene.width - width) / 2
            y: 16
            restHeight: IslandGeometry.compactRestHeight
            restLeftWidth: modules.compact ? modules.leftWidth : 0
            restRightWidth: modules.compact ? modules.rightWidth : 0
            screenName: "compact-test"
            notificationsEnabled: false
        }
        TopBarModules {
            id: modules
            compact: true
            hasMedia: false
            mediaPlayer: player
            mediaArtUrl: ""
            onRequestSurface: name => pill.surface = name
            x: pill.x; y: pill.y
            width: pill.width; height: pill.height
            availableWidth: Math.max(0, Math.min(500, (scene.width - pill.restCenterWidth - 72) / 2))
            centerWidth: pill.restCenterWidth
            presented: !pill.surfaceOpen
            opacity: presented ? Math.max(0, Math.min(1, (pill.width - pill.restW + 40) / 40)) : 0
            screenName: "compact-test"
        }
        Timer { interval: 50; running: checks.finished; onTriggered: Qt.quit() }
        TestCase {
            id: checks
            name: "CompactIsland"
            when: scene.visible
            property bool finished: false
            function check(ok, message) {
                if (!ok) { console.error("FAIL:", message); throw new Error(message) }
            }
            function shot(name) {
                const dir = Quickshell.env("ISLA_COMPACT_SHOTS")
                if (dir) grabImage(scene.contentItem).save(dir + "/" + name + ".png")
            }
            function settle() {
                wait(700)
                if (!pill.surfaceOpen) tryVerify(() => Math.abs(pill.width - pill.restW) < 1, 2500)
            }
            function checkBounds() {
                check(pill.width <= scene.width + 1, "unit fits monitor: " + pill.width + "/" + scene.width)
                check(Math.abs(pill.height - 56) < 0.01, "rest height")
                for (const module of [modules.workspaceModule, modules.statusModule, modules.userModule, modules.mediaModule]) {
                    if (!module.interactive) continue
                    check(module.x >= 0 && module.x + module.width <= pill.width, "module inside body horizontally")
                    check(module.y >= 0 && module.y + module.height <= pill.height, "module inside body vertically")
                }
                const centerLeft = modules.clockX
                if (modules.workspaceModule.interactive) check(modules.workspaceModule.x + modules.workspaceModule.width < centerLeft, "workspaces clear clock")
                if (modules.statusModule.interactive) check(modules.statusModule.x > centerLeft + pill.restCenterWidth, "status clears clock")
                const naturalWidth = pill.restCenterWidth + modules.leftWidth + modules.rightWidth + 36
                    + (modules.leftWidth > 0 ? 18 : 0) + (modules.rightWidth > 0 ? 18 : 0)
                check(Math.abs(pill.width - naturalWidth) < 1, "body fits actual contents without mirrored empty reserve")
            }
            function test_compact() {
                tryVerify(() => Config.loaded)
                check(Config.update({appearance: {reduceMotion: false}, modules: {
                    workspaceRail: true, systemStatus: true, userAvatar: true,
                    apps: true, audio: true, network: true, battery: true}}).ok)
                settle()
                checkBounds()
                modules.statusItem.windows = Array.from({length: 14}, (_, i) => ({lastIpcObject: {class: "fixture" + i}}))
                settle()
                checkBounds()
                check(modules.statusItem.contentWidth <= modules.availableWidth - 50, "apps respect shared width budget")
                shot("many-apps")
                scene.width = 620
                settle()
                checkBounds()
                shot("narrow")
                scene.width = 1100
                settle()
                modules.hasMedia = true
                settle()
                checkBounds()
                check(modules.mediaModule.interactive && modules.mediaModule.item.playing, "music integrated inside unit")
                check(!findChild(modules.mediaModule.item, "compactMediaToggle"), "compact music has no transport button")
                player.isPlaying = false
                check(!modules.cavaActive, "paused music releases CAVA consumer")
                modules.mediaModule.item.requestMedia()
                settle()
                check(pill.surface === "media" && pill.surfaceItem && pill.surfaceContentProgress > 0.99, "music opens in main body")
                pill.surface = ""
                for (let i = 0; i < 35; i++) {
                    wait(16)
                    if (modules.statusModule.interactive) {
                        check(modules.statusModule.x >= modules.clockX + pill.restCenterWidth + 16,
                            "return never enables overlapping status")
                    }
                }
                settle()
                checkBounds()
                scene.width = 620
                settle()
                checkBounds()
                check(modules.mediaModule.interactive, "music remains accessible on narrow monitor")
                shot("music-narrow")
                scene.width = 1100
                settle()
                const longMediaWidth = modules.mediaWidth
                player.trackTitle = "Sol"
                player.trackArtist = "Ana"
                settle()
                check(modules.mediaWidth < longMediaWidth, "short metadata releases unused width")
                checkBounds()
                shot("music-short")
                player.trackTitle = "Una canción de título largo"
                player.trackArtist = "Artista de prueba"
                settle()
                shot("music-paused")
                player.isPlaying = true
                tryVerify(() => modules.cavaActive, 1000, "resume reactivates compact visualizer")
                wait(100)
                shot("music-playing")
                for (const name of ["mixer", "workspaces", "calendar", "launcher"]) {
                    pill.surface = name
                    settle()
                    check(pill.surfaceItem && pill.surfaceContentProgress > 0.99, name + " content reveals")
                    check(!modules.workspaceModule.interactive && !modules.statusModule.interactive, "panel releases module input")
                }
                pill.surface = ""
                settle()
                checkBounds()
                check(Config.update({appearance: {reduceMotion: true}}).ok)
                pill.surface = "connectivity"
                settle()
                check(pill.surfaceContentProgress > 0.99, "reduced motion reveals narrower surface")
                pill.surface = ""
                settle()
                checkBounds()
                modules.compact = false
                settle()
                check(!modules.mediaModule.active && !modules.cavaActive, "split layout releases integrated music")
                modules.compact = true
                settle()
                check(modules.mediaModule.interactive && modules.cavaActive, "compact layout restores music")
                modules.hasMedia = false
                check(Config.update({modules: {workspaceRail: false, systemStatus: false, userAvatar: false}}).ok)
                settle()
                checkBounds()
                check(pill.width < 180, "clock-only unit has no empty module reserve")
                console.log("PASS: compact unit bounds, packed clock, app overflow, narrow monitor, panels, integrated music, layout switch and reduced motion")
                finished = true
            }
        }
    }
}
