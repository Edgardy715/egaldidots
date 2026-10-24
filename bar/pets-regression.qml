pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "pets"
import "Singletons"

/**
 * Offscreen runtime checks for Eshell Pets: perch routing by priority and
 * availability, the headroom pixel clamp, settled sleep with no timers,
 * hidden and reduced-motion cost, three clicks, music and keeping clear of
 * an avoided range. Each step acts once and then waits for its condition.
 */
ShellRoot {
    id: root
    settings.watchFiles: false
    readonly property Item actor: layerLoader.item ? layerLoader.item.actor : null
    readonly property Item petLayer: layerLoader.item

    function fail(message) {
        console.error("FAIL: " + message + " " + JSON.stringify(root.state()))
        Qt.exit(1)
    }
    function state() {
        if (!actor) return {}
        return {perch: petLayer.perchId, anim: actor.anim, px: actor.px, shown: actor.shown, asleep: actor.asleep,
                settled: actor.settled, animating: actor.animating, thinking: actor.thinking,
                sleepArmed: actor.sleepArmed, walkDir: actor.walkDir, centerX: actor.centerX}
    }
    function stillAndQuiet() {
        return !actor.animating && !actor.thinking && !actor.sleepArmed && !actor.musicArmed
    }

    Window {
        width: 420; height: 200
        visible: true
        color: "#202124"

        Loader {
            id: layerLoader
            sourceComponent: PetLayer { monitorActive: true }
        }
        PetPerch {
            id: low
            x: 10; y: 10; width: 120; height: 40
            petLayer: root.petLayer
            perchId: "low"; priority: 0; kind: "niche"
            available: true
        }
        PetPerch {
            id: high
            x: 10; y: 80; width: 380; height: 80
            petLayer: root.petLayer
            perchId: "high"; priority: 2; kind: "line"
            floorY: 60
            available: true
        }
        Loader {
            id: removable
            active: false
            sourceComponent: PetPerch {
                x: 180; y: 60; width: 60; height: 40
                petLayer: root.petLayer
                perchId: "removable"; priority: 9; kind: "line"
                available: true
            }
        }
    }

    // Opacity direction check armed per step: 1 never dips, -1 never rises, 2 relay restores.
    property int watchOpacity: 0
    property real lastOpacity: 0
    property bool bounceOnFade: false
    property real hiddenAt: 0
    property real requireWaitUntil: 0
    property bool hopDuringFade: false
    FrameAnimation {
        running: root.watchOpacity !== 0
        onTriggered: {
            const o = root.actor ? root.actor.opacity : 0
            const age = Date.now() - root.stepStart
            if (root.watchOpacity === 1 && o < root.lastOpacity - 0.02)
                root.fail("entry opacity dipped " + root.lastOpacity + " -> " + o)
            if (root.watchOpacity === -1 && o < root.lastOpacity - 0.4)
                root.fail("lost-source opacity snapped " + root.lastOpacity + " -> " + o)
            // tick() caps dt at 50 ms, so a legitimate rise is at most 50/120 per frame.
            if (root.watchOpacity === 4 && o > root.lastOpacity + 0.45)
                root.fail("detach jumped " + root.lastOpacity + " -> " + o)
            if (root.watchOpacity === 3 && Math.abs(o - root.lastOpacity) > 0.25)
                root.fail("flight hand-off stepped " + root.lastOpacity + " -> " + o)
            if (root.watchOpacity === -1 && o > root.lastOpacity + 0.02)
                root.fail("lost-source opacity rose " + root.lastOpacity + " -> " + o)
            if (root.watchOpacity === -1 && age >= 200 && root.actor.shown && o > 0.45)
                root.fail("lost source still opaque after 200 ms: " + o)
            if (root.watchOpacity === 2 && age >= 150 && root.petLayer.phase === "flight" && o < 0.99)
                root.fail("relay flight did not restore opacity: " + o)
            if (root.watchOpacity === -1 && Date.now() < root.requireWaitUntil && root.petLayer.phase === "fade")
                root.fail("cancelled hold skipped its grace and faded at " + age + " ms")
            if (root.watchOpacity === -1 && !root.actor.shown && !root.hiddenAt) root.hiddenAt = Date.now()
            root.lastOpacity = o
        }
    }
    Connections {
        target: root.petLayer
        function onPhaseChanged() {
            if (!root.bounceOnFade || root.petLayer.phase !== "fade") return
            root.bounceOnFade = false
            low.available = true
            bounceTimer.start()
        }
    }
    Timer {
        id: bounceTimer; interval: 30
        onTriggered: {
            // A perch that hops while the pet fades must not revive it.
            if (root.petLayer.activePerch === low && root.petLayer.phase === "fade") {
                root.hopDuringFade = true
                root.petLayer.hop(200, 8, 1)
                if (root.petLayer.phase !== "fade") root.fail("a hop revived a fading pet: " + root.petLayer.phase)
            }
            low.available = false
        }
    }
    NumberAnimation { id: slowReveal; target: low; property: "reveal"; from: 0; to: 1; duration: 900 }
    NumberAnimation { id: revealRamp; target: low; property: "reveal"; from: 0; to: 1; duration: 420 }

    property int step: 0
    property real stepStart: 0
    property bool acted: false
    property real retargetX: 0
    property real retargetY: 0
    property real retargetVX: 0
    property real retargetVY: 0
    property real clockMs: new Date(2026, 9, 23, 15).getTime()
    readonly property var steps: [
        {name: "package ready and highest priority wins",
         act: () => {},
         done: () => root.actor && root.actor.shown && root.petLayer.perchId === "high" && root.actor.parent === high},
        {name: "resting idle keeps only the brain and sleep timers",
         act: () => {},
         done: () => root.actor.anim === "idle" && root.actor.thinking && root.actor.sleepArmed},
        {name: "unavailable perch falls back by priority",
         act: () => { high.available = false },
         done: () => root.petLayer.perchId === "low" && root.actor.parent === low},
        {name: "a relay detaches the one actor and disables input",
         act: () => {
             high.available = true
             root.petLayer.transfer()
             const point = root.petLayer.targetPoint()
             const dx = point.x - root.actor.flightX
             const dy = point.y - root.actor.flightY
             const distance = Math.hypot(dx, dy)
             const duration = Math.max(380, Math.min(520, 380 + 0.18 * distance / root.petLayer.s))
             const px = Math.max(root.actor.flightPx, root.actor.perchPx)
             const height = Math.min(root.petLayer.jumpHeight(px, distance),
                 Math.max(0, Math.min(root.actor.flightY, point.y) - root.petLayer.minimumY(px)))
             const rise = root.actor.flightY - Math.min(root.actor.flightY, point.y) + height
             const velocityY = -2 * Math.sqrt(rise) * (Math.sqrt(rise) + Math.sqrt(rise + dy)) / duration
             if (Math.abs(root.petLayer.velocityY - velocityY) > 0.000001)
                 root.fail("transfer ignored jump height or ceiling")
         },
         done: () => root.petLayer.phase === "flight" && root.petLayer.flying
                     && root.actor.parent === root.petLayer.flightHost && !root.actor.inputEnabled
                     && root.stillAndQuiet()},
        {name: "retarget preserves position and velocity synchronously",
         act: () => {
             root.retargetX = root.actor.flightX; root.retargetY = root.actor.flightY
             root.retargetVX = root.petLayer.velocityX; root.retargetVY = root.petLayer.velocityY
             high.available = false
             root.petLayer.transfer()
             if (root.actor.flightX !== root.retargetX || root.actor.flightY !== root.retargetY
                 || root.petLayer.velocityX !== root.retargetVX || root.petLayer.velocityY !== root.retargetVY)
                 root.fail("retarget discontinuity")
         },
         done: () => root.actor.parent === low && !root.petLayer.motionRunning && root.actor.inputEnabled,
         timeout: 650},
        {name: "the endpoint follows a moving surface every frame",
         act: () => { high.available = true },
         done: () => root.petLayer.phase === "flight"},
        {name: "moving target lands exactly on the new endpoint",
         act: () => { high.x += 70; high.y += 10 },
         done: () => root.actor.parent === high && !root.petLayer.transferPending
                     && Math.abs(root.actor.centerX - high.restX) < 1,
         timeout: 650},
        {name: "losing a source holds its feet in the layer during grace",
         act: () => { low.available = false; high.available = false },
         done: () => root.petLayer.phase === "wait" && root.actor.shown && root.stillAndQuiet()
                     && root.actor.parent === root.petLayer.flightHost && !root.actor.inputEnabled},
        {name: "no target fades after grace and leaves no animation alive",
         act: () => {},
         done: () => !root.actor.shown && root.stillAndQuiet() && !root.petLayer.motionRunning
                     && !root.petLayer.transferPending,
         timeout: 650},
        {name: "a fresh entry drops from above with opacity instead of flying",
         act: () => { low.available = true },
         done: () => root.petLayer.phase === "entry" && !root.petLayer.flying
                     && root.actor.flightOpacity > 0 && root.actor.flightOpacity < 1
                     && root.actor.flightY < root.petLayer.targetPoint().y},
        {name: "entry settles and jumps can be disabled independently",
         act: () => {},
         done: () => root.actor.parent === low && !root.petLayer.transferPending},
        {name: "jumps false places immediately without disabling base timers",
         act: () => { Config.update({pets: {jumps: false}}); high.available = true },
         done: () => root.actor.parent === high && !root.petLayer.transferPending
                     && root.actor.thinking && root.actor.sleepArmed && root.actor.inputEnabled},
        {name: "jumps false also returns immediately",
         act: () => {
             high.available = false
             root.petLayer.transfer()
             if (root.actor.parent !== low || root.petLayer.transferPending) root.fail("jumps false moved")
             Config.update({pets: {jumps: true}})
         },
         done: () => root.actor.parent === low && !root.petLayer.transferPending},
        {name: "a missing source keeps a short relay window",
         act: () => { low.available = false },
         done: () => root.petLayer.phase === "wait" && root.actor.shown},
        {name: "a destination within grace relays from the held source",
         act: () => { high.available = true },
         done: () => root.petLayer.phase === "flight" && root.petLayer.flying},
        {name: "short relay settles at the destination",
         act: () => { root.watchOpacity = 2 },
         done: () => {
             const ok = root.actor.parent === high && !root.petLayer.transferPending && root.actor.opacity > 0.99
             if (ok) root.watchOpacity = 0
             return ok
         }},
        {name: "launcher close can retain its origin while the home niche returns",
         act: () => {
             root.petLayer.holdForHome()
             if (root.petLayer.homeReturnPending) root.fail("a non-launcher origin armed the home hold")
             high.perchId = "launcher"
             root.petLayer.holdForHome()
             low.available = false; high.available = false
         },
         done: () => root.petLayer.phase === "wait" && root.petLayer.homeReturnPending},
        {name: "approved home return stays visible beyond the ordinary grace",
         act: () => {},
         done: () => Date.now() - root.stepStart > 550 && root.petLayer.phase === "wait" && root.actor.shown && root.stillAndQuiet()},
        {name: "late home arrival flies from the held origin",
         act: () => { low.available = true },
         done: () => root.petLayer.phase === "flight" && root.actor.shown},
        {name: "home arrival clears the special retention state",
         act: () => { high.perchId = "high" },
         done: () => root.actor.parent === low && !root.petLayer.transferPending && !root.petLayer.homeReturnPending},
        {name: "a surface transfer wakes its sleeping origin before flying",
         act: () => { root.actor.sleepNow(); high.available = true },
         done: () => root.petLayer.phase === "flight" && !root.actor.asleep && root.stillAndQuiet()},
        {name: "flight from sleep restores the awake base on landing", act: () => {},
         done: () => root.actor.parent === high && !root.petLayer.transferPending && !root.actor.asleep},
        {name: "restore home before monitor interruption",
         act: () => { high.available = false; low.available = true },
         done: () => root.actor.parent === low && !root.petLayer.transferPending},
        {name: "monitor deactivation silences an in-progress flight immediately",
         act: () => { high.available = true },
         done: () => root.petLayer.phase === "flight"},
        {name: "hidden monitor has no transfer or actor timers",
         act: () => { root.petLayer.monitorActive = false },
         done: () => !root.actor.shown && root.stillAndQuiet() && !root.petLayer.motionRunning
                     && !root.petLayer.transferPending},
        {name: "monitor return uses entry rather than a stale relay",
         act: () => { high.available = false; root.petLayer.monitorActive = true },
         done: () => root.petLayer.phase === "entry" && !root.petLayer.flying},
        {name: "monitor entry settles",
         act: () => {},
         done: () => root.actor.parent === low && !root.petLayer.transferPending},
        {name: "a distant destination fades instead of flying",
         act: () => { high.x = 1100; high.available = true },
         done: () => root.petLayer.phase === "fade" && !root.petLayer.flying},
        {name: "a distant destination enters at its own feet",
         act: () => {},
         done: () => root.petLayer.phase === "entry" && !root.petLayer.flying
                     && Math.abs(root.actor.flightX - root.petLayer.targetPoint().x) < 1},
        {name: "distant entry settles before restoring the fixture",
         act: () => {},
         done: () => root.actor.parent === high && !root.petLayer.transferPending},
        {name: "restore home immediately with jumps disabled",
         act: () => { Config.update({pets: {jumps: false}}); high.available = false; high.x = 10 },
         done: () => root.actor.parent === low && !root.petLayer.transferPending},
        {name: "restore jump preference",
         act: () => { Config.update({pets: {jumps: true}}) },
         done: () => root.petLayer.jumps},
        {name: "locked perch hop keeps the old feet after bounds move",
         act: () => {
             const feet = root.actor.mapToItem(root.petLayer.flightHost, root.actor.originX * root.actor.px,
                                               root.actor.footRow * root.actor.px)
             low.minX = 95; low.maxX = 95
             root.petLayer.hop(280, 12, 1)
             if (Math.abs(root.actor.flightX - feet.x) > 0.01 || Math.abs(root.actor.flightY - feet.y) > 0.01)
                 root.fail("locked hop source moved")
         },
         done: () => root.actor.parent === low && !root.petLayer.transferPending && root.actor.posX === 95},
        {name: "noninteractive perches leave input to their surface",
         act: () => { low.interactive = false; low.minX = 0; low.maxX = low.width },
         done: () => !root.actor.inputEnabled},
        {name: "restore normal perch input",
         act: () => { low.interactive = true },
         done: () => root.actor.inputEnabled},
        {name: "a disposable surface can host the single actor",
         act: () => { removable.active = true },
         done: () => root.actor.parent === removable.item && !root.petLayer.transferPending},
        {name: "destroying the surface detaches the actor before deleting children",
         act: () => {
             removable.active = false
             if (!root.actor || root.actor.parent !== root.petLayer.flightHost)
                 root.fail("surface destroyed its actor")
         },
         done: () => root.actor.parent === low && !root.petLayer.transferPending},
        {name: "headroom clamps the pixel scale and never grows the perch",
         act: () => { low.headroom = 20 },
         done: () => root.actor.px === Math.max(1, Math.floor(20 / root.actor.bodyRows))
                     && root.actor.px * root.actor.bodyRows <= 20 && low.height === 40},
        {name: "a line perch fits every pose, not just the body",
         act: () => { high.headroom = 30 },
         done: () => root.actor.parent === low || (root.actor.px * root.actor.reachRows <= 30)},
        {name: "no perch hides the pet and stops every timer",
         act: () => { low.available = false },
         done: () => !root.actor.shown && !root.actor.visible && root.stillAndQuiet() && root.petLayer.perchId === ""},
        {name: "entry into a still-revealing niche never dips",
         act: () => { low.reveal = 0; root.lastOpacity = 0; root.watchOpacity = 1; low.available = true; revealRamp.start() },
         done: () => {
             const ok = root.actor.parent === low && !root.petLayer.transferPending && low.reveal === 1
             if (ok) root.watchOpacity = 0
             return ok
         }},
        {name: "a lost source dims, never rises when a destination flickers mid-fade, and hides",
         act: () => {
             root.lastOpacity = root.actor.opacity; root.bounceOnFade = true; root.hiddenAt = 0
             root.watchOpacity = -1; low.available = false
         },
         done: () => {
             const ok = !root.actor.shown && !root.bounceOnFade && !bounceTimer.running
             if (ok) {
                 const hid = (root.hiddenAt || Date.now()) - root.stepStart
                 console.log("lost source hidden after " + hid + " ms")
                 if (hid > 580) root.fail("lost source hid too late: " + hid)
                 if (!root.hopDuringFade) root.fail("the mid-fade hop was never exercised")
                 root.watchOpacity = 0
             }
             return ok
         },
         timeout: 1500},
        {name: "a launcher origin rests before its close hold",
         act: () => { high.perchId = "launcher"; high.available = true },
         done: () => root.actor.parent === high && !root.petLayer.transferPending},
        {name: "the close hold keeps the pet opaque",
         act: () => { root.petLayer.holdForHome(); high.available = false },
         done: () => Date.now() - root.stepStart > 300 && root.petLayer.phase === "wait"
                     && root.petLayer.homeReturnPending && root.actor.opacity > 0.99},
        {name: "cancelling the hold dims gradually and then hides",
         act: () => {
             root.lastOpacity = root.actor.opacity; root.hiddenAt = 0
             root.requireWaitUntil = Date.now() + 300
             root.watchOpacity = -1; root.petLayer.cancelHomeReturn()
         },
         done: () => {
             const ok = !root.actor.shown
             if (ok) {
                 root.watchOpacity = 0; high.perchId = "high"
                 const hid = (root.hiddenAt || Date.now()) - root.stepStart
                 console.log("cancelled hold hidden after " + hid + " ms")
                 if (hid > 580) root.fail("cancelled hold hid too late: " + hid)
             }
             return ok
         },
         timeout: 1500},
        {name: "the line perch returns for a relay",
         act: () => { high.available = true },
         done: () => root.actor.parent === high && !root.petLayer.transferPending},
        {name: "a relay into a slowly revealing niche lands without a step",
         act: () => {
             low.reveal = 0; root.lastOpacity = root.actor.opacity; root.watchOpacity = 3
             low.available = true; high.available = false; slowReveal.start()
         },
         done: () => {
             const ok = root.actor.parent === low && !root.petLayer.transferPending && low.reveal === 1
             if (ok) root.watchOpacity = 0
             return ok
         }},
        {name: "leaving a half-revealed niche carries its opacity into the relay",
         act: () => {
             low.reveal = 0.4; root.lastOpacity = root.actor.opacity; root.watchOpacity = 4
             high.available = true; low.available = false
         },
         done: () => {
             const ok = root.actor.parent === high && !root.petLayer.transferPending
             if (ok) { root.watchOpacity = 0; low.reveal = 1 }
             return ok
         }},
        {name: "the line perch leaves and the pet hides again",
         act: () => { high.available = false },
         done: () => !root.actor.shown && root.petLayer.perchId === ""},
        {name: "returning perch shows the pet at its rest position",
         act: () => { high.available = true },
         done: () => root.actor.shown && root.actor.anim === "idle" && Math.abs(root.actor.centerX - high.restX) < 1
                     && root.actor.px === Math.max(1, Math.floor(30 / root.actor.reachRows))},
        {name: "restoring headroom restores the pixel size",
         act: () => { high.headroom = 1e6 },
         done: () => root.actor.px === root.actor.basePx},
        {name: "three clicks within the window show love first",
         act: () => { root.actor.click(); root.actor.click(); root.actor.click() },
         done: () => root.actor.anim === "love"},
        {name: "love finishes in happy",
         act: () => {}, done: () => root.actor.anim === "happy"},
        {name: "a reaction returns to idle",
         act: () => {},
         done: () => root.actor.anim === "idle"},
        {name: "single click reacts once",
         act: () => { root.actor.click() },
         done: () => root.actor.anim === "react"},
        {name: "music mood dances",
         act: () => { high.mood = "music" },
         done: () => root.actor.anim === "dance" && root.actor.animating},
        {name: "mood cleared returns to idle",
         act: () => { high.mood = "" },
         done: () => root.actor.anim === "idle"},
        {name: "an avoided range under the pet makes it walk clear",
         act: () => { high.avoidFrom = root.actor.centerX - 10; high.avoidTo = root.actor.centerX + 10 },
         done: () => root.actor.walkDir === 0 && root.actor.free(root.actor.centerX)},
        {name: "sleep settles to a still pose with no timers",
         act: () => { high.avoidFrom = -1; high.avoidTo = -1; root.actor.sleepNow() },
         done: () => root.actor.asleep && root.actor.settled && root.stillAndQuiet(),
         timeout: 9000},
        {name: "a click wakes it",
         act: () => { root.actor.click() },
         done: () => !root.actor.asleep && root.actor.sleepArmed && root.actor.anim === "wake"},
        {name: "click wake plays its reaction",
         act: () => {}, done: () => root.actor.anim === "react", timeout: 3000},
        {name: "wake ends in its base reaction then idle",
         act: () => {}, done: () => root.actor.anim === "idle", timeout: 3000},
        {name: "reduced motion keeps one still pose and refuses walks",
         act: () => { Config.update({appearance: {reduceMotion: true}}) },
         done: () => Flags.reduceMotion && root.actor.anim === "idle" && !root.actor.animating
                     && !root.actor.thinking && !root.actor.walkTo(high.minX)},
        {name: "reduced motion stays quiet across a perch change",
         act: () => { low.available = true; high.available = false },
         done: () => root.actor.parent === low && !root.actor.thinking && root.actor.sleepArmed},
        {name: "and back again",
         act: () => { high.available = true },
         done: () => root.actor.parent === high && !root.actor.thinking && root.actor.anim === "idle"},
        {name: "reduced motion still ends a reaction on time",
         act: () => { root.actor.click() },
         done: () => root.actor.anim === "idle" && !root.actor.animating,
         timeout: 3000},
        {name: "reduced music shows the dance pose without frames",
         act: () => { high.mood = "music" },
         done: () => root.actor.anim === "dance" && !root.actor.animating},
        {name: "turning sleep off disarms the sleep timer",
         act: () => { high.mood = ""; Config.update({pets: {sleepEnabled: false}}); root.actor.click() },
         done: () => !root.actor.sleepArmed && !root.actor.asleep},
        {name: "turning sleep off wakes a sleeping pet",
         act: () => { Config.update({pets: {sleepEnabled: true}}); root.actor.sleepNow(); Config.update({pets: {sleepEnabled: false}}) },
         done: () => !root.actor.asleep && !root.actor.sleepArmed && root.actor.anim !== "sleep"},
        {name: "coding starts only on a home perch",
         act: () => {
             Config.update({appearance: {reduceMotion: false}, pets: {sleepEnabled: true}})
             high.perchId = "bar"
             root.actor.now = () => new Date(root.clockMs)
             root.actor.random = () => 0.95
             root.petLayer.coding = true
         },
         done: () => root.actor.anim === "code" && root.actor.animating && root.actor.brainInterval >= 20000},
        {name: "code settles after four loops from the real package metadata",
         act: () => {
             if (root.actor.current.settleAfterLoops !== 4) root.fail("code package metadata")
             root.actor.current = Object.assign({}, root.actor.current,
                 {ms: root.actor.current.ms.map(() => 20)})
             root.actor.schedule()
         },
         done: () => root.actor.anim === "code" && root.actor.loops === 4 && root.actor.settled && !root.actor.animating},
        {name: "the code brain resumes a settled loop without polling focus",
         act: () => { root.actor.think() },
         done: () => root.actor.anim === "code" && !root.actor.settled && root.actor.animating},
        {name: "coding does not play in the launcher",
         act: () => { high.perchId = "launcher" },
         done: () => root.actor.anim === "idle"},
        {name: "coding focus wakes and rearms sleep even when coding remains true",
         act: () => { high.perchId = "bar"; root.actor.sleepNow(); root.petLayer.notify("codingFocus") },
         done: () => !root.actor.asleep && root.actor.sleepArmed && root.actor.anim === "code"},
        {name: "coding opt-out restores idle",
         act: () => { Config.update({pets: {codingReaction: false}}) },
         done: () => root.actor.anim === "idle"},
        {name: "disabled coding focus does not wake a sleeping pet",
         act: () => { root.actor.sleepNow(); root.petLayer.notify("codingFocus") },
         done: () => root.actor.asleep && !root.actor.sleepArmed},
        {name: "music pulse starts a configurable home dance",
         act: () => {
             root.petLayer.coding = false
             root.actor.wake()
             root.actor.musicDurationMs = 350
             root.petLayer.notify("musicStart")
         },
         done: () => root.actor.anim === "dance" && root.actor.musicArmed},
        {name: "music pulse ends and restores the base state",
         act: () => {},
         done: () => root.actor.anim === "idle" && !root.actor.musicArmed},
        {name: "music opt-out rejects pulses",
         act: () => { Config.update({pets: {musicReaction: false}}); root.petLayer.notify("musicStart") },
         done: () => root.actor.anim === "idle" && !root.actor.musicArmed},
        {name: "media mood still dances when the home reaction is disabled",
         act: () => { high.perchId = "media"; high.mood = "music" },
         done: () => root.actor.anim === "dance" && !root.actor.musicArmed},
        {name: "night halves the sleep interval with a one-minute minimum",
         act: () => { high.mood = ""; high.perchId = "bar"; root.clockMs = new Date(2026, 9, 23, 1).getTime(); root.actor.sleepAfterMs = 180000; root.actor.armSleep() },
         done: () => root.actor.sleepInterval === 90000},
        {name: "night sleep honors the minimum",
         act: () => { root.actor.sleepAfterMs = 60000; root.actor.armSleep() },
         done: () => root.actor.sleepInterval === 60000},
        {name: "day uses the configured sleep interval",
         act: () => { root.clockMs = new Date(2026, 9, 23, 15).getTime(); root.actor.sleepAfterMs = 180000; root.actor.armSleep() },
         done: () => root.actor.sleepInterval === 180000},
        {name: "night opt-out keeps the normal interval",
         act: () => { root.clockMs = new Date(2026, 9, 23, 1).getTime(); Config.update({pets: {nightReaction: false}}) },
         done: () => root.actor.sleepInterval === 180000},
        {name: "night brain can yawn with the injected clock and random source",
         act: () => { Config.update({pets: {nightReaction: true}}); root.actor.random = () => 0; root.actor.play("idle"); root.actor.think() },
         done: () => root.actor.anim === "yawn" && root.actor.lastNightYawn === root.clockMs},
        {name: "a night yawn is limited to once per two minutes",
         act: () => { root.actor.play("idle"); root.actor.think() },
         done: () => root.actor.anim !== "yawn"},
        {name: "a hidden pet cancels the pulse timer and all behavior",
         act: () => {
             root.actor.random = () => 0.95
             Config.update({pets: {musicReaction: true}})
             root.petLayer.notify("musicStart")
             root.petLayer.monitorActive = false
         },
         done: () => !root.actor.shown && root.stillAndQuiet()},
        {name: "return after ten minutes queues greeting through entry",
         act: () => { root.clockMs += 601000; root.petLayer.monitorActive = true },
         done: () => root.petLayer.phase === "entry" && root.actor.greetPending},
        {name: "greeting plays once after the landing pose",
         act: () => {},
         done: () => !root.petLayer.transferPending && root.actor.anim === "wave" && !root.actor.greetPending},
        {name: "greeting returns to base and is not repeated",
         act: () => {},
         done: () => root.actor.anim === "idle" && !root.actor.greetPending},
        {name: "reduced greeting ends after one still cycle",
         act: () => { Config.update({appearance: {reduceMotion: true}}); root.actor.act("greet") },
         done: () => root.actor.anim === "idle" && !root.actor.animating},
        {name: "sleep cancels a home pulse timer",
         act: () => { root.petLayer.notify("musicStart"); root.actor.sleepNow() },
         done: () => root.actor.asleep && !root.actor.musicArmed && !root.actor.thinking && !root.actor.sleepArmed},
        {name: "music pulses preserve sleep and leave the reaction timer stopped",
         act: () => { root.petLayer.notify("musicStart") },
         done: () => root.actor.asleep && root.actor.baseAnim() === "sleep" && !root.actor.musicArmed},
        {name: "frequent mischief uses the package and schedules its next visit",
         act: () => {
             Config.update({appearance: {reduceMotion: false}, pets: {mischief: "frequent", sleepEnabled: false, musicReaction: false, nightReaction: false}})
             root.actor.wake(); root.actor.random = () => 0.1; root.actor.planMischief()
             root.clockMs += 200000; root.actor.play("idle"); root.actor.think()
         },
         done: () => root.actor.anim === "twirl" && root.actor.nextMischiefAt - root.clockMs >= 72000
                     && root.actor.nextMischiefAt - root.clockMs <= 168000},
        {name: "mischief returns after exactly one cycle", act: () => {}, done: () => root.actor.anim === "idle"},
        {name: "weighted middle draw selects sneeze",
         act: () => { root.actor.random = () => 0.5; root.actor.nextMischiefAt = root.clockMs - 1; root.actor.think() },
         done: () => root.actor.anim === "sneeze"},
        {name: "sneeze returns to base", act: () => {}, done: () => root.actor.anim === "idle"},
        {name: "weighted last draw selects wave",
         act: () => { root.actor.random = () => 0.95; root.actor.nextMischiefAt = root.clockMs - 1; root.actor.think() },
         done: () => root.actor.anim === "wave"},
        {name: "wave returns to base", act: () => {}, done: () => root.actor.anim === "idle"},
        {name: "never disarms mischief even after time passes",
         act: () => { Config.update({pets: {mischief: "never"}}); root.clockMs += 1000000; root.actor.think() },
         done: () => root.actor.nextMischiefAt === 0 && root.actor.anim === "idle"},
        {name: "mischief is blocked in launcher, sleep, reduced, transit, walks and perch cooldown",
         act: () => {
             Config.update({pets: {mischief: "frequent"}})
             root.actor.nextMischiefAt = root.clockMs - 1
             high.perchId = "launcher"
             if (root.actor.tryMischief()) root.fail("mischief in launcher")
             high.perchId = "bar"; root.actor.sleepNow()
             if (root.actor.tryMischief()) root.fail("mischief during sleep")
             root.actor.wake(); Config.update({appearance: {reduceMotion: true}})
             if (root.actor.tryMischief()) root.fail("mischief with reduced motion")
             Config.update({appearance: {reduceMotion: false}}); root.actor.transit = true
             if (root.actor.tryMischief()) root.fail("mischief in transit")
             root.actor.transit = false; root.actor.walkDir = 1
             if (root.actor.tryMischief()) root.fail("mischief during walk")
             root.actor.walkDir = 0; root.actor.perchChangedAt = root.clockMs
             if (root.actor.tryMischief()) root.fail("mischief just after perch change")
             root.clockMs += 3001; root.actor.play("idle"); root.actor.think()
         },
         done: () => root.actor.anim === "wave"},
        {name: "hidden mischief never runs a timer or animation",
         act: () => { root.petLayer.monitorActive = false; root.actor.nextMischiefAt = root.clockMs - 1; if (root.actor.tryMischief()) root.fail("hidden mischief") },
         done: () => !root.actor.shown && root.stillAndQuiet()},
        {name: "the jump arc grows with px and distance and has a cap",
         act: () => {
             if (!(root.petLayer.jumpHeight(7, 200) > root.petLayer.jumpHeight(2, 200)
                   && root.petLayer.jumpHeight(7, 400) > root.petLayer.jumpHeight(7, 200)
                   && root.petLayer.jumpHeight(7, 10000) === 252)) root.fail("jump height scaling")
         }, done: () => true},
        {name: "a quiet pet starts doze before sleeping",
         act: () => {
             Config.update({pets: {sleepEnabled: true, mischief: "never", nightReaction: false}})
             root.petLayer.monitorActive = true
             root.actor.sleepAfterMs = 1
             root.actor.armSleep()
         }, done: () => root.actor.anim === "doze" && root.actor.dozePending && !root.actor.asleep},
        {name: "music interrupts doze and rearms sleep",
         act: () => { root.actor.sleepAfterMs = 180000; Config.update({pets: {musicReaction: true}}); root.petLayer.notify("musicStart") },
         done: () => root.actor.anim === "dance" && !root.actor.dozePending && root.actor.sleepArmed},
        {name: "music interruption can doze again",
         act: () => { root.actor.musicUntil = 0; root.actor.play("idle"); root.actor.sleepAfterMs = 1; root.actor.armSleep() },
         done: () => root.actor.anim === "doze" && root.actor.dozePending},
        {name: "reduced motion interrupts doze and rearms sleep",
         act: () => { root.actor.sleepAfterMs = 180000; Config.update({appearance: {reduceMotion: true}}) },
         done: () => Flags.reduceMotion && root.actor.anim === "idle" && !root.actor.dozePending && root.actor.sleepArmed},
        {name: "normal motion can doze again",
         act: () => { Config.update({appearance: {reduceMotion: false}}); root.actor.sleepAfterMs = 1; root.actor.armSleep() },
         done: () => root.actor.anim === "doze" && root.actor.dozePending},
        {name: "music mood interrupts doze and rearms sleep",
         act: () => { root.actor.sleepAfterMs = 180000; high.mood = "music" },
         done: () => root.actor.anim === "dance" && !root.actor.dozePending && root.actor.sleepArmed},
        {name: "clearing mood can doze again",
         act: () => { high.mood = ""; root.actor.sleepAfterMs = 1; root.actor.armSleep() },
         done: () => root.actor.anim === "doze" && root.actor.dozePending},
        {name: "doze finishes in settled timer-free sleep",
         act: () => {}, done: () => root.actor.asleep && root.actor.anim === "sleep" && root.stillAndQuiet(), timeout: 9000},
        {name: "distant pill hover does not wake a sleeping pet",
         act: () => { root.petLayer.pillLook(0, 0, high, true) },
         done: () => root.actor.asleep && root.actor.anim === "sleep" && root.stillAndQuiet()},
        {name: "body hover wakes with the wake animation",
         act: () => { root.actor.sleepAfterMs = 180000; root.actor.wake("hover") },
         done: () => root.actor.anim === "wake" && !root.actor.asleep},
        {name: "hover wake looks up before returning to base",
         act: () => {}, done: () => root.actor.anim === "look_up", timeout: 3000},
        {name: "wake reaches the base after its reaction",
         act: () => {}, done: () => root.actor.anim === "idle", timeout: 3000},
        {name: "pet wake plays love",
         act: () => { root.actor.sleepNow(); root.actor.wake("pet") },
         done: () => root.actor.anim === "wake"},
        {name: "pet wake reaches love before happy",
         act: () => {}, done: () => root.actor.anim === "love", timeout: 3000},
        {name: "pet wake returns to idle after happy",
         act: () => {}, done: () => root.actor.anim === "idle", timeout: 3000},
        {name: "pill hover looks left and right from the actor",
         act: () => {
             root.petLayer.pillLook(0, 30, high, true)
             if (root.actor.anim !== "look_left") root.fail("left pill look")
             root.petLayer.pillLook(high.width, 30, high, true)
             if (root.actor.anim !== "look_left") root.fail("pill look changed before 250 ms")
         }, done: () => root.actor.anim === "look_right", timeout: 700},
        {name: "interrupted pill look resumes on the same side",
         act: () => {
             root.actor.click()
             if (root.petLayer.pillDirection !== "") root.fail("interrupted look kept its direction")
             root.actor.play("idle")
             root.petLayer.pillLook(high.width, 30, high, true)
         }, done: () => root.actor.anim === "look_right", timeout: 700},
        {name: "pill hover above the body looks up",
         act: () => {
             root.petLayer.lastPillLook -= 251
             const body = root.actor.mapToItem(high, root.actor.originX * root.actor.px, root.actor.hit[1] * root.actor.px)
             root.petLayer.pillLook(body.x, body.y - 1, high, true)
         }, done: () => root.actor.anim === "look_up"},
        {name: "pill look returns to idle after exit",
         act: () => { root.petLayer.pillLook(0, 0, high, false) },
         done: () => root.actor.anim === "idle", timeout: 1800},
        {name: "stretch is unavailable before ninety seconds of rest",
         act: () => { root.actor.lastInteraction = root.clockMs; root.actor.random = () => 0.02; root.actor.think() },
         done: () => root.actor.anim !== "stretch"},
        {name: "stretch is a low-weight long-rest choice",
         act: () => { root.actor.lastInteraction = root.clockMs - 91000; root.actor.play("idle"); root.actor.think() },
         done: () => root.actor.anim === "stretch"},
        {name: "idle uses its alternate breath on every fourth cycle",
         act: () => {
             root.actor.play("idle")
             root.actor.loops = 3
             root.actor.step = root.actor.current.f.length - 1
             root.actor.advance()
         }, done: () => root.actor.anim === "idle_breath"},
        {name: "reduced motion sleeps directly without doze",
         act: () => {
             Config.update({appearance: {reduceMotion: true}})
             root.actor.sleepAfterMs = 1
             root.actor.armSleep()
         }, done: () => root.actor.anim === "sleep" && root.actor.asleep && !root.actor.animating},
        {name: "reduced motion wakes directly without wake",
         act: () => { root.actor.sleepAfterMs = 180000; root.actor.click() },
         done: () => root.actor.anim === "idle" && !root.actor.asleep && !root.actor.animating},
        {name: "unloading the layer releases every perch",
         act: () => { Config.update({appearance: {reduceMotion: false}, pets: {sleepEnabled: true}}); layerLoader.active = false },
         done: () => !low.occupied && !high.occupied}
    ]

    Timer {
        interval: 50; repeat: true; running: true
        onTriggered: {
            if (!Config.loaded || !PetPack.ready) return
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
                    console.log("PASS: pets routing, headroom clamp, hidden/sleep/reduced cost, clicks, music and keep-clear")
                    Qt.quit()
                }
                return
            }
            if (now - root.stepStart > (current.timeout || 2500)) root.fail(current.name)
        }
    }
}
