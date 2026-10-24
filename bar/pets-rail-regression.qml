pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Quickshell
import "components"
import "pets"
import "Singletons"

ShellRoot {
    id: root
    settings.watchFiles: false
    readonly property Item layer: layerLoader.item
    readonly property Item actor: layer ? layer.actor : null
    property int requested: 0
    property real sourceX: 0
    function find(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children || []) { const match = find(child, name); if (match) return match }
        return null
    }
    function mark(id) { return find(rail, "workspaceMark-" + id) }
    function landed() { return layer.perchId === "rail" && !layer.transferPending && actor.parent === perch }
    readonly property Item perch: find(rail, "railPetPerch")
    Connections {
        target: root.actor
        function onFlightYChanged() {
            if (!root.layer || root.layer.phase !== "flight") return
            const top = root.actor.flightY - root.actor.reachRows * root.actor.px
                + root.layer.flightHost.mapToItem(null, 0, 0).y
            if (top < -0.05) { console.error("FAIL: hop silhouette crossed window top: " + top); Qt.exit(1) }
        }
    }
    // Scene x of the pet's origin per frame while armed; a hop never teleports it.
    property bool watchJump: false
    property bool retargetOnLand: false
    property bool landRetargeted: false
    property real lastSceneX: NaN
    property real maxJump: 0
    function sceneX() { return root.actor.mapToItem(null, root.actor.originX * root.actor.px, 0).x }
    FrameAnimation {
        running: root.watchJump
        onTriggered: {
            const x = root.sceneX()
            if (!isNaN(root.lastSceneX)) root.maxJump = Math.max(root.maxJump, Math.abs(x - root.lastSceneX))
            root.lastSceneX = x
        }
    }
    Connections {
        target: root.layer
        function onPhaseChanged() {
            if (!root.retargetOnLand || root.layer.phase !== "land") return
            root.retargetOnLand = false
            root.landRetargeted = true
            // A workspace event arrives after land() returns; the pet must leave from where it stands.
            Qt.callLater(() => {
                const before = root.sceneX()
                rail.activeId = 2
                if (Math.abs(root.sceneX() - before) > 0.5) { console.error("FAIL: land retarget moved the pet " + (root.sceneX() - before)); Qt.exit(1) }
            })
        }
    }
    TestCase { id: input; when: false; function test_input() {} }
    Window {
        id: window
        visible: true; width: 800; height: 200; color: "#202124"
        Loader { id: layerLoader; sourceComponent: PetLayer { monitorActive: true } }
        TopWorkspaceRail {
            id: rail
            x: 20; y: 8
            style: "pet"
            petLayer: root.layer
            onWorkspaceRequested: id => root.requested = id
        }
        PetPerch {
            id: home
            x: 450; y: 20; width: 100; height: 48
            petLayer: root.layer
            perchId: "bar"; kind: "niche"; priority: 0; available: true
        }
    }
    property int step: 0
    property real started: 0
    property bool acted: false
    readonly property var steps: [
        {name: "pet occupies the real rail and fades the active dot", act: () => {},
         done: () => root.actor && root.landed() && root.perch.occupied && root.mark(1).opacity < 0.01},
        {name: "rail pet has no input and lens has no frame driver", act: () => {},
         done: () => !root.actor.inputEnabled && !rail.lensAnimating},
        {name: "native click through occupied cell requests workspace", act: () => input.mouseClick(rail, root.perch.restX, rail.height / 2),
         done: () => root.requested === 1},
        {name: "native hover looks toward another cell in one still frame",
         act: () => input.mouseMove(rail, rail.navWidth + rail.inset + 4.5 * rail.slot, rail.height / 2),
         done: () => rail.hoverId === 5 && root.actor.anim === "look_right" && !root.actor.animating},
        {name: "leaving the rail returns to idle", act: () => input.mouseMove(window.contentItem, 760, 180),
         done: () => rail.hoverId === 0 && root.actor.anim === "idle"},
        {name: "1 to 3 crouches at the old cell without moving the lens",
         act: () => {
             root.sourceX = root.actor.mapToItem(root.layer.flightHost, root.actor.originX * root.actor.px, 0).x
             const before = root.sceneX()
             root.lastSceneX = NaN; root.maxJump = 0; root.watchJump = true
             rail.activeId = 3
             // The perch moves in this same call; a resting pet must not move with it.
             if (Math.abs(root.sceneX() - before) > 0.5) { console.error("FAIL: rest hop moved with the perch " + (root.sceneX() - before)); Qt.exit(1) }
         },
         done: () => root.layer.flying && !rail.lensAnimating && Math.abs(root.actor.flightX - root.sourceX) < 0.1},
        {name: "hop lands in cell 3 with no pending jump", act: () => {},
         done: () => {
             const ok = root.landed() && Math.abs(root.actor.centerX - root.perch.restX) < 0.1 && root.mark(3).opacity < 0.01
             if (ok) {
                 root.watchJump = false
                 if (root.maxJump > 0.6 * rail.slot) { console.error("FAIL: rest hop teleported " + root.maxJump); Qt.exit(1) }
             }
             return ok
         }},
        {name: "retarget during the landing crouch leaves from the landing point",
         act: () => { root.lastSceneX = NaN; root.maxJump = 0; root.watchJump = true; root.retargetOnLand = true; rail.activeId = 4 },
         done: () => {
             const ok = root.landRetargeted && root.landed() && Math.abs(root.actor.centerX - root.perch.restX) < 0.1
                 && root.mark(2).opacity < 0.01
             if (ok) {
                 root.watchJump = false
                 console.log("max frame jump " + root.maxJump.toFixed(2) + " px, slot " + rail.slot)
                 if (root.maxJump > 0.6 * rail.slot) { console.error("FAIL: hop teleported " + root.maxJump); Qt.exit(1) }
             }
             return ok
         }},
        {name: "start rapid 1 to 5 to 2 sequence", act: () => { rail.activeId = 1 },
         done: () => root.layer.phase === "flight"},
        {name: "retarget to cell 5 in the air", act: () => { rail.activeId = 5 }, done: () => root.layer.phase === "flight"},
        {name: "final retarget lands only in cell 2", act: () => { rail.activeId = 2 },
         done: () => root.landed() && root.actor.posX === root.perch.restX && root.mark(2).opacity < 0.01},
        {name: "unpresented module falls back to the bar", act: () => { rail.presented = false },
         done: () => root.layer.perchId === "bar" && !root.perch.occupied && root.mark(2).opacity > 0.99},
        {name: "rail returns when presented", act: () => { rail.presented = true }, done: () => root.landed()},
        {name: "rail that does not fit falls back", act: () => { rail.availableWidth = 90 },
         done: () => !rail.fits && root.layer.perchId === "bar"},
        {name: "restore rail space", act: () => { rail.availableWidth = 320 }, done: () => root.landed()},
        {name: "monitor without focus keeps the active dot", act: () => { root.layer.monitorActive = false },
         done: () => !root.actor.shown && !root.perch.occupied && root.mark(2).opacity > 0.99},
        {name: "monitor focus restores rail", act: () => { root.layer.monitorActive = true }, done: () => root.landed()},
        {name: "disabled pet leaves dots and no actor", act: () => { layerLoader.active = false },
         done: () => !root.layer && !root.perch.occupied && root.mark(2).opacity > 0.99},
        {name: "reload the pet", act: () => { layerLoader.active = true }, done: () => root.actor && root.landed()},
        {name: "reduced motion moves immediately", act: () => { Config.update({appearance: {reduceMotion: true}}); rail.activeId = 4 },
         done: () => root.landed() && root.actor.posX === root.perch.restX && !root.layer.flying && !rail.lensAnimating},
        {name: "compact rail uses its own cell geometry", act: () => { rail.integrated = true; Config.update({appearance: {reduceMotion: false}}); rail.activeId = 2 },
         done: () => root.landed() && root.actor.posX === root.perch.restX && !rail.lensAnimating},
        {name: "Pac-Man still moves and chews", act: () => { rail.style = "pacman"; rail.activeId = 5 },
         done: () => root.find(rail, "workspacePacman").chewing && rail.lensAnimating && !root.perch.available},
        {name: "Pac-Man settles and pet returns to bar", act: () => {},
         done: () => !rail.lensAnimating && root.layer.perchId === "bar" && root.actor.parent === home}
    ]
    Timer {
        interval: 20; running: true; repeat: true
        onTriggered: {
            if (!Config.loaded || !PetPack.ready) return
            const entry = root.steps[root.step]
            if (!root.acted) { root.acted = true; root.started = Date.now(); entry.act(); return }
            if (entry.done()) {
                console.log("ok: " + entry.name)
                root.step++; root.acted = false
                if (root.step === root.steps.length) { console.log("PASS: pet rail occupation, hops, retarget, native click/hover, layouts, reduced, fallback and Pac-Man"); Qt.quit() }
            } else if (Date.now() - root.started > 3000) {
                console.error("FAIL: " + entry.name + " " + JSON.stringify({phase: root.layer ? root.layer.phase : "", perch: root.layer ? root.layer.perchId : "", active: rail.activeId, hover: rail.hoverId, anim: root.actor ? root.actor.anim : ""}))
                Qt.exit(1)
            }
        }
    }
}
