//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
import QtQuick
import QtTest
import Quickshell
import Quickshell.Wayland
import "components"
import "surfaces"
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    PanelWindow {
        implicitWidth: 1280; implicitHeight: 900
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}
        Item { id: body; x: 590; y: 8; width: 100; height: 38 }
        FluidCompanion {
            id: drop
            anchors.fill: parent
            body: body
            centered: true
            surfaceName: "settings"
            surfaceSize: IslandGeometry.settingsSurface
            retainExpandedContent: true
            asynchronousExpandedContent: true
            expandedContent: Component {
                SettingsSurface {
                    open: drop.open || (drop.active && drop.cardContentProgress > 0.01)
                    closing: !drop.open
                    morphCloseness: drop.cardContentProgress
                }
            }
        }
    }
    TestCase {
        name: "SettingsAsync"
        when: Config.loaded
        function test_coldOpenRetainAndInterrupt() {
            Config.update({appearance: {reduceMotion: false}})
            drop.expanded = true
            drop.open = true
            verify(drop.surfaceItem === null, "opening does not synchronously construct the editor")
            drop.open = false
            wait(30)
            drop.open = true
            tryVerify(() => drop.surfaceItem !== null, 5000)
            const retained = drop.surfaceItem
            compare(retained.width, drop.cardW)
            compare(retained.height, drop.cardH)
            tryVerify(() => drop.cardContentProgress === 1, 3000)
            drop.open = false
            wait(60)
            compare(retained.width, drop.cardW)
            compare(retained.height, drop.cardH)
            drop.open = true
            compare(drop.surfaceItem, retained)
            tryVerify(() => drop.settled, 3000)
            drop.open = false
            tryVerify(() => drop.phase === "idle", 3000)
            compare(drop.surfaceItem, retained)
            Config.update({appearance: {reduceMotion: true}})
            drop.open = true
            tryVerify(() => drop.phase === "media", 1000)
            compare(drop.surfaceItem, retained)
            drop.open = false
            compare(drop.phase, "idle")
            console.log("PASS: asynchronous settings cold open, loading cancellation/reopen, retained editor and reduced motion")
        }
    }
}
