import QtQuick
import Quickshell
import "components"
import "windows"
import "Singletons"

/**
 * Production composition for Eshell Pets (Wayland): the overlay owns one layer
 * while enabled, the pet rests in the bar niche, moves to the launcher perch
 * while the launcher is open, returns on close, hides off the focused monitor
 * and releases the niche when disabled.
 */
ShellRoot {
    id: root
    settings.watchFiles: false
    SurfaceRouter {
        id: router
        focusedMonitorName: Quickshell.screens[0].name
        reduceMotion: Flags.reduceMotion
    }
    IslandOverlay { id: overlay; modelData: Quickshell.screens[0]; router: router }

    function find(item, name) {
        if (!item) return null
        if (item.objectName === name) return item
        const kids = item.children || []
        for (let i = 0; i < kids.length; i++) {
            const found = find(kids[i], name)
            if (found) return found
        }
        return null
    }
    function perch(name) { return find(overlay.contentItem, name) }
    function pet() { return overlay.petLayer }

    // The bar perch must not drop out while the niche opens or the launcher closes.
    property int barDrops: 0
    property int flights: 0
    property int flightsBefore: 0
    property string lastPerch: ""
    property int fades: 0
    property int fadesBefore: 0
    property int optOutHolds: 0
    Connections {
        target: root.pet()
        function onFlyingChanged() { if (root.pet().flying) root.flights++ }
        function onPhaseChanged() { if (root.pet().phase === "fade") root.fades++ }
        function onHomeReturnPendingChanged() {
            if (root.pet().homeReturnPending && !Config.pets.launcherSurface) root.optOutHolds++
        }
        function onPerchIdChanged() {
            const now = root.pet().perchId
            root.lastPerch = now
        }
    }
    Connections {
        target: root.pet() ? root.pet().actor : null
        function onShownChanged() {
            if (!root.pet().actor.shown && router.focusedMonitorName === Quickshell.screens[0].name
                    && Config.pets.enabled) root.barDrops++
        }
    }

    property int step: 0
    property real stepStart: 0
    property bool acted: false
    readonly property var steps: [
        {name: "enabling loads one layer",
         act: () => Config.update({pets: {enabled: true}, appearance: {barLayout: "split"}}),
         done: () => root.pet() !== null && root.perch("barPetPerch") !== null},
        {name: "the pet rests in the bar niche, which reserves its width",
         act: () => {},
         done: () => root.pet().perchId === "bar" && root.pet().petVisible
                     && root.perch("barPetPerch").width > root.pet().bodyWidth,
         timeout: 6000},
        {name: "the niche settled without dropping the pet",
         act: () => {},
         done: () => Math.abs(root.perch("barPetPerch").width - root.perch("barPetPerch").target) < 0.5
                     && root.pet().perchId === "bar" && root.barDrops === 0,
         timeout: 4000},
        {name: "opening the launcher moves it to the launcher perch",
         act: () => { root.flightsBefore = root.flights; router.toggleSurface("", "launcher") },
         done: () => overlay.launcherOpen && root.pet().perchId === "launcher"
                     && root.pet().actor.parent === root.perch("launcherPetPerch")
                     && root.flights > root.flightsBefore,
         timeout: 6000},
        {name: "the launcher perch keeps the pet above the search field",
         act: () => {},
         done: () => {
             const p = root.perch("launcherPetPerch")
             const a = root.pet().actor
             return a.y + a.footRow * a.px <= p.height + 0.5 && p.y < 0
         }},
        {name: "closing holds the origin while the home niche is unavailable",
         act: () => router.close(),
         done: () => root.pet().homeReturnPending && root.pet().phase === "wait"
                     && root.pet().actor.shown,
         timeout: 2000},
        {name: "reopening cancels the pending home return",
         act: () => { root.fadesBefore = root.fades; root.flightsBefore = root.flights; router.toggleSurface("", "launcher") },
         done: () => overlay.launcherOpen && !root.pet().homeReturnPending
                     && root.pet().perchId === "launcher" && !root.pet().transferPending
                     && root.fades === root.fadesBefore && root.flights > root.flightsBefore,
         timeout: 6000},
        {name: "closing returns it to the bar",
         act: () => { root.flightsBefore = root.flights; router.close() },
         done: () => !overlay.surfaceOpen && root.pet().perchId === "bar"
                     && Math.abs(root.perch("barPetPerch").width - root.perch("barPetPerch").target) < 0.5
                     && root.pet().actor.parent === root.perch("barPetPerch")
                     && root.flights > root.flightsBefore,
         timeout: 6000},
        {name: "returning to the bar did not drop the pet",
         act: () => {},
         done: () => root.barDrops === 0 && root.pet().perchId === "bar"},
        {name: "Mascota occupies the split rail and closes the clock niche",
         act: () => Config.update({appearance: {workspaceStyle: "pet"}}),
         done: () => root.pet().perchId === "rail" && root.perch("railPetPerch").occupied
                     && root.pet().actor.parent === root.perch("railPetPerch")
                     && root.perch("barPetPerch").width < 0.5,
         timeout: 5000},
        {name: "rail to launcher uses the shared flight engine",
         act: () => { root.flightsBefore = root.flights; router.toggleSurface("", "launcher") },
         done: () => root.pet().actor.parent === root.perch("launcherPetPerch")
                     && root.flights > root.flightsBefore,
         timeout: 6000},
        {name: "launcher returns to rail without opening the clock niche",
         act: () => { root.flightsBefore = root.flights; router.close() },
         done: () => root.pet().perchId === "rail" && !root.pet().transferPending
                     && root.flights > root.flightsBefore && root.perch("barPetPerch").width < 0.5,
         timeout: 6000},
        {name: "Mascota also occupies the integrated compact rail",
         act: () => Config.update({appearance: {barLayout: "compact"}}),
         done: () => overlay.compact && !overlay.layoutChanging && root.pet().perchId === "rail"
                     && !root.pet().transferPending && root.perch("barPetPerch").width < 0.5,
         timeout: 7000},
        {name: "restore split and the clock niche",
         act: () => Config.update({appearance: {barLayout: "split", workspaceStyle: "numbers"}}),
         done: () => !overlay.compact && !overlay.layoutChanging && root.pet().perchId === "bar"
                     && !root.pet().transferPending,
         timeout: 7000},
        {name: "another focused monitor hides it",
         act: () => { router.focusedMonitorName = "isla-test-elsewhere" },
         done: () => root.pet().perchId === "" && !root.pet().petVisible && root.perch("barPetPerch").width < 0.5,
         timeout: 4000},
        {name: "focus back shows it",
         act: () => { router.focusedMonitorName = Quickshell.screens[0].name },
         done: () => root.pet().perchId === "bar",
         timeout: 4000},
        {name: "launcher opt-out keeps it in the bar",
         act: () => { Config.update({pets: {launcherSurface: false}}); router.toggleSurface("", "launcher") },
         done: () => overlay.launcherOpen && root.pet().perchId !== "launcher",
         timeout: 6000},
        {name: "closing an opted-out launcher never arms the home hold",
         act: () => router.close(),
         done: () => !overlay.surfaceOpen && root.pet().perchId === "bar" && !root.pet().transferPending
                     && root.optOutHolds === 0 && !root.pet().homeReturnPending,
         timeout: 4000},
        {name: "disabling unloads the layer and releases the niche",
         act: () => { router.close(); Config.update({pets: {enabled: false, launcherSurface: true}}) },
         done: () => root.pet() === null && root.perch("barPetPerch").width < 0.5,
         timeout: 6000}
    ]

    Timer {
        interval: 100; repeat: true; running: true
        onTriggered: {
            if (!Config.loaded) return
            const current = root.steps[root.step]
            const now = Date.now()
            if (!root.acted) {
                root.acted = true
                root.stepStart = now
                current.act()
                return
            }
            if (current.done()) {
                console.log("ok: " + current.name)
                root.step++
                root.acted = false
                if (root.step >= root.steps.length) {
                    console.log("PASS: pets overlay composition, bar niche, launcher perch, focus and opt-outs")
                    Qt.quit()
                }
                return
            }
            if (now - root.stepStart > (current.timeout || 3000)) {
                const layer = root.pet()
                console.error("FAIL: " + current.name + " " + JSON.stringify({
                    perch: layer ? layer.perchId : null, phase: layer ? layer.phase : null,
                    flights: root.flights, flightsBefore: root.flightsBefore, surface: overlay.surface,
                    bar: root.perch("barPetPerch") ? root.perch("barPetPerch").width : -1}))
                Qt.exit(1)
            }
        }
    }
}
