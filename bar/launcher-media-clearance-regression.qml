import QtQuick
import QtTest
import Quickshell
import "Singletons"
import "components"
import "windows"

// Closing the launcher with music playing: the returning pill and the media
// droplet never overlap unjoined.
ShellRoot {
    settings.watchFiles: false
    SurfaceRouter { id: navigation; focusedMonitorName: Quickshell.screens[0].name; reduceMotion: Flags.reduceMotion }
    IslandOverlay { id: overlay; router: navigation; modelData: Quickshell.screens[0] }
    property var pill: null
    property var drop: null
    property bool sampling: false
    property real minGap: 1e9
    property real minWidth: 1e9
    property real growth: 0
    property bool budded: false
    FrameAnimation {
        running: sampling
        onTriggered: {
            if (drop.phase === "nacimiento") budded = true
            if (budded) {
                minWidth = Math.min(minWidth, pill.width)
                growth = Math.max(growth, pill.width - minWidth)
            }
            if (drop.active && !drop.joined && drop.phase !== "retornando" && drop.phase !== "absorbiendo")
                minGap = Math.min(minGap, drop.visualX - pill.x - pill.width)
        }
    }
    TestCase {
        name: "LauncherMediaClearance"
        when: Config.loaded && overlay.visible
        function test_clearance() {
            pill = findChild(overlay.contentItem, "islandPill")
            drop = findChild(overlay.contentItem, "islandMediaCompanion")
            verify(pill && drop)
            {
                verify(Config.update({appearance: {barLayout: "split", reduceMotion: false}}).ok)
                Players.fixturePresent = true; Players.fixturePlaying = true
                navigation.close()
                wait(2500)
                tryCompare(drop, "phase", "companion", 5000)
                for (const hold of [1400, 500]) {
                    navigation.toggleSurface("", "launcher")
                    wait(hold)
                    minGap = 1e9; minWidth = 1e9; growth = 0; budded = false
                    sampling = true
                    navigation.close()
                    wait(2600)
                    sampling = false
                    const label = "hold=" + hold
                    console.log("clearance " + label + " minGap=" + minGap.toFixed(1)
                        + " growthAfterBud=" + growth.toFixed(1))
                    verify(minGap >= 0, label + " droplet overlapped the pill by " + (-minGap).toFixed(1) + " px")
                    compare(drop.phase, "companion", label)
                    // The pill returns once: it never widens toward a droplet already born,
                    // not even from a launcher-width blip at the handoff.
                    verify(growth < 0.5, label + " pill grew " + growth.toFixed(1) + " px after the droplet bud")
                    // A short visit may close before the droplet is absorbed; a long one buds it again.
                    if (hold === 1400) verify(budded, label + " the droplet buds again after the launcher")
                }
            }
            // Reduced motion closes in one step: no overlap.
            verify(Config.update({appearance: {barLayout: "split", reduceMotion: true}}).ok)
            navigation.toggleSurface("", "launcher")
            wait(1400)
            minGap = 1e9; budded = false; minWidth = 1e9; growth = 0
            sampling = true
            navigation.close()
            wait(2600)
            sampling = false
            console.log("clearance reduceMotion minGap=" + minGap.toFixed(1) + " growthAfterBud=" + growth.toFixed(1))
            verify(minGap >= 0, "reduced motion: droplet overlapped the pill by " + (-minGap).toFixed(1) + " px")
            verify(growth < 0.5, "reduced motion: pill grew " + growth.toFixed(1) + " px after the droplet bud")
            compare(drop.phase, "companion")
            console.log("PASS: launcher media clearance")
        }
    }
}
