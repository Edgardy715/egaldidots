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
                if (!ok) { console.error("FAIL:", message); Qt.exit(1); throw new Error(message) }
            }
            function shot(name) {
                const dir = Quickshell.env("ISLA_COMPACT_SHOTS")
                if (dir) grabImage(scene.contentItem).save(dir + "/" + name + ".png")
            }
            function settle() {
                wait(700)
                if (!pill.surfaceOpen) {
                    tryVerify(() => Math.abs(pill.width - pill.restW) < 1 && Math.abs(pill.height - pill.coreH) < 0.01, 2500)
                    tryVerify(() => pill.restHeaderOpacity > 0.99, 2500)
                }
            }
            function sampleMorph(name) {
                const start = Date.now()
                for (let frame = 0; frame < 18; frame++) {
                    wait(24)
                    if (Quickshell.env("ISLA_COMPACT_FRAMES")) {
                        shot(name + "-" + frame)
                        console.log("FRAME_SAMPLE", name, frame, Date.now() - start,
                            pill.width, pill.height, modules.contentFits, modules.statusModule.exposure)
                    }
                    if (modules.statusModule.interactive)
                        check(modules.statusModule.x >= modules.clockX + pill.restCenterWidth + 16,
                            "sampled return keeps status clear of clock")
                }
            }
            function checkBounds() {
                check(pill.width <= scene.width + 1, "unit fits monitor: " + pill.width + "/" + scene.width)
                check(Math.abs(pill.height - 56) < 0.01, "rest height: " + pill.height + " target=" + pill.targetH + " surface=" + pill.surface + " reduced=" + Flags.reduceMotion)
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
                check(modules.mediaModule.item.hasProgress, "compact progress ring is enabled for a timed player")
                check(modules.mediaModule.item.progress > 0.3, "compact progress ring receives the session clock")
                player.isPlaying = false
                player.position = 120
                check(Math.abs(modules.mediaModule.item.progress - 0.5) < 0.001, "paused/external seek updates compact ring")
                player.length = 0
                check(!modules.mediaModule.item.hasProgress, "unknown duration hides compact ring")
                player.length = 240
                check(!modules.cavaActive, "paused music releases CAVA consumer")
                const openHit = findChild(modules.mediaModule.item, "compactMediaOpen")
                openHit.forceActiveFocus()
                check(openHit.activeFocus, "integrated music accepts keyboard focus")
                keyClick(Qt.Key_Return)
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
                mouseClick(modules.mediaModule.item, modules.mediaWidth - 2, 19)
                settle()
                check(pill.surface === "media", "entire compact media row opens with pointer")
                pill.surface = ""
                settle()
                scene.width = 620
                settle()
                checkBounds()
                check(modules.mediaModule.interactive, "music remains accessible on narrow monitor")
                check(modules.mediaWidth >= 112 || modules.mediaWidth === 36, "narrow music reserves a readable line or just the cover")
                const lens = findChild(modules.workspaceItem, "workspaceLens")
                check(lens.width <= modules.workspaceItem.slot, "workspace selection stays inside its cell")
                shot("music-narrow")
                scene.width = 1100
                settle()
                const longMediaWidth = modules.mediaWidth
                player.trackTitle = "Sol"
                player.trackArtist = "Ana"
                settle()
                check(modules.mediaWidth < longMediaWidth, "short metadata releases unused width")
                const summary = findChild(modules.mediaModule.item, "compactMediaSummary")
                check(summary.textWidth >= 64, "short metadata remains readable rather than reserving an empty column")
                check(Config.update({appearance: {fontScale: 1.5}}).ok)
                settle()
                check(summary.titlePixelSize === Theme.fontSizeBodyLg, "compact title respects global text scale")
                check(summary.artistPixelSize === Theme.fontSizeSmall, "compact artist respects global text scale")
                shot("large-text")
                check(Config.update({appearance: {fontScale: 1}}).ok)
                modules.workspaceItem.count = 30
                settle()
                check(modules.workspaceWidth === 0, "oversized workspace rail withdraws")
                check(modules.mediaWidth === modules.mediaNaturalWidth, "hidden rail releases music width")
                modules.workspaceItem.count = 5
                settle()
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
                if (Quickshell.env("ISLA_COMPACT_FRAMES")) {
                    for (let pass = 0; pass < 2; pass++) {
                        pill.surface = "calendar"
                        sampleMorph("calendar-open-" + pass)
                        settle()
                        pill.surface = ""
                        sampleMorph("calendar-close-" + pass)
                        settle()
                        checkBounds()
                    }
                }
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
                check(Config.update({appearance: {reduceMotion: false}}).ok)
                for (const delay of [60, 160, 330]) {
                    const start = Date.now()
                    pill.surface = "calendar"
                    wait(delay)
                    shot("opening-" + delay)
                    console.log("MOTION_SAMPLE", delay, Date.now() - start, pill.width, pill.height)
                    pill.surface = "mixer"
                    wait(60)
                    pill.surface = ""
                    settle()
                    checkBounds()
                }
                pill.surface = "calendar"
                wait(100)
                check(Config.update({appearance: {reduceMotion: true}}).ok)
                settle()
                check(Math.abs(pill.height - pill.targetH) < 0.01, "reduced motion completes an in-flight morph")
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
