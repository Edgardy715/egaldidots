import QtQuick
import "../Singletons"

// One actor: perches own it at rest; the flight host owns it during transfers.
Item {
    id: petLayer

    property bool monitorActive: false
    property bool coding: false
    property bool homeReturnPending: false
    property real lastPillLook: 0
    property string pillDirection: ""
    property string pendingPillDirection: ""
    property real s: 1
    readonly property bool jumps: Config.pets.jumps && !Flags.reduceMotion
    property var perches: []
    property int revision: 0
    property bool closing: false
    Component.onDestruction: closing = true

    readonly property Item candidatePerch: {
        void revision
        if (!monitorActive || !PetPack.ready) return null
        let best = null
        for (const perch of perches) {
            if (perch.available && (best === null || perch.priority > best.priority)) best = perch
        }
        return best
    }
    property Item activePerch: null
    onActivePerchChanged: { pillReturn.stop(); pillLookDelay.stop(); pendingPillDirection = ""; pillDirection = "" }
    onCandidatePerchChanged: settleTimer.restart()
    onMonitorActiveChanged: { if (!monitorActive) silence() }
    onJumpsChanged: { if (!jumps && phase !== "") attach() }

    readonly property Item actor: petActor
    readonly property Item flightHost: flightItem
    readonly property bool petVisible: petActor.shown
    readonly property string perchId: activePerch ? activePerch.perchId : ""
    readonly property real bodyWidth: petActor.hit[2] * petActor.px
    readonly property real reachRight: petActor.reachRight * petActor.px
    readonly property int reachRows: petActor.reachRows
    readonly property bool flying: phase === "crouch" || phase === "flight" || phase === "land"
    readonly property bool motionRunning: motion.running
    readonly property bool transferPending: phase !== ""
    property string phase: ""
    property real motionAt: 0
    onPhaseChanged: { motionAt = Date.now(); frameGate.stop() }
    property real elapsed: 0
    property real duration: 0
    property real velocityX: 0
    property real velocityY: 0
    property real lostAt: 0
    property bool apexPassed: false
    property bool airborne: false
    property real fadeFrom: 1
    // Perch the actor last left; only a pet leaving the launcher waits for home.
    property string departedFrom: ""
    // Waiting outside the close hold dims toward 0.4 so it never sits opaque over a surface.
    readonly property bool dimming: phase === "wait" && !homeReturnPending && petActor.flightOpacity > 0.401
    // A relay from a dimmed wait restores opacity from its crouch on.
    readonly property bool driven: monitorActive
        && (["flight", "entry", "fade"].indexOf(phase) >= 0 || dimming
            || (phase === "crouch" && petActor.flightOpacity < 0.999))

    function register(perch) {
        if (perches.indexOf(perch) >= 0) return
        perches.push(perch)
        revision++
    }
    function unregister(perch) {
        // Capture while the old visual parent still exists, before its destruction.
        if (activePerch === perch) {
            detach()
            departedFrom = perch.perchId
            activePerch = null
            loseTarget()
        }
        const index = perches.indexOf(perch)
        if (index < 0) return
        perches.splice(index, 1)
        revision++
    }
    function notify(kind) { petActor.handleEvent(kind) }
    function lookAt(direction) { petActor.lookAt(direction) }
    function pillLook(pointerX, pointerY, pill, hovered) {
        if (!petActor.shown || petActor.asleep || phase !== "" || perchId !== "bar"
            || ["idle", "look_left", "look_right", "look_up"].indexOf(petActor.anim) < 0) {
            pillReturn.stop()
            pillLookDelay.stop()
            pendingPillDirection = ""
            pillDirection = ""
            return
        }
        if (!hovered) { pillLookDelay.stop(); pendingPillDirection = ""; pillReturn.restart(); return }
        pillReturn.stop()
        const body = petActor.mapToItem(pill, petActor.originX * petActor.px, petActor.hit[1] * petActor.px)
        const direction = pointerX >= body.x - petActor.hit[2] * petActor.px / 2
            && pointerX <= body.x + petActor.hit[2] * petActor.px / 2 && pointerY < body.y
            ? "up" : pointerX < body.x ? "left" : "right"
        const time = Date.now()
        if (direction === pillDirection) { pillLookDelay.stop(); pendingPillDirection = ""; return }
        if (time - lastPillLook < 250) {
            pendingPillDirection = direction
            pillLookDelay.interval = Math.max(1, 250 - (time - lastPillLook))
            pillLookDelay.restart()
            return
        }
        pillLookDelay.stop()
        pendingPillDirection = ""
        applyPillLook(direction)
    }
    function applyPillLook(direction) {
        pillDirection = direction
        lastPillLook = Date.now()
        petActor.lookAt(direction === "up" ? "up" : direction === "left" ? -1 : 1)
    }
    function holdForHome() {
        if (!monitorActive || !jumps || !petActor.shown) return
        const fromLauncher = activePerch ? activePerch.perchId === "launcher"
            : phase !== "" && departedFrom === "launcher"
        if (!fromLauncher) return
        homeReturnPending = true
        if (phase === "wait") loseTarget()
    }
    // Reopening the launcher mid-close keeps the hold: the pet flies back when it returns.
    function cancelHomeReturn(reopened) {
        if (reopened && phase === "wait" && homeReturnPending) return
        const held = homeReturnPending
        homeReturnPending = false
        // The ordinary grace starts now, so the pet dims before it fades; an
        // ordinary wait keeps its running grace.
        if (held && phase === "wait") { lostAt = 0; loseTarget() }
    }
    // A locked perch calls this before moving its rest point, so the hop starts where the pet is.
    function prepareHop() {
        if (!activePerch || !monitorActive || !jumps) return
        if (phase === "" || phase === "land") {
            detach()
            phaseTimer.stop()
            airborne = false
            velocityX = 0
            velocityY = 0
            phase = "ready"
        }
    }
    function cancelHop() { if (phase === "ready") attach() }
    function minimumY(px) {
        return petActor.reachRows * px + 2 * s - flightItem.mapToItem(null, 0, 0).y
    }
    function jumpHeight(px, distance) { return Math.max(9 * px, Math.min(36 * px, 9 * px + 0.12 * distance)) }

    function targetPoint() {
        if (!activePerch) return Qt.point(petActor.flightX, petActor.flightY)
        const px = petActor.perchPx
        const floor = activePerch.kind === "niche"
            ? activePerch.height / 2 + petActor.bodyRows / 2 * px : activePerch.floorY
        return activePerch.mapToItem(flightItem, activePerch.restX, floor)
    }
    function detach() {
        if (petActor.detached) return
        const feet = petActor.mapToItem(flightItem, petActor.originX * petActor.px, petActor.footRow * petActor.px)
        petActor.flightX = feet.x
        petActor.flightY = feet.y
        petActor.flightPx = petActor.px
        // Carry the shown opacity: a niche may still be revealing when the pet leaves it.
        petActor.flightOpacity = petActor.opacity
        petActor.retained = petActor.shown
        petActor.transit = true
        petActor.wake()
        velocityX = 0
        velocityY = 0
    }
    function attach() {
        phaseTimer.stop()
        graceTimer.stop()
        phase = ""
        airborne = false
        homeReturnPending = false
        departedFrom = ""
        petActor.retained = false
        petActor.transit = false
        petActor.arriving = false
        petActor.greetIfReady()
        velocityX = 0
        velocityY = 0
    }
    function silence() {
        settleTimer.stop()
        activePerch = null
        attach()
        lostAt = 0
    }
    function loseTarget() {
        phaseTimer.stop()
        if (!monitorActive || !jumps || !petActor.retained) { attach(); return }
        if (!lostAt) lostAt = Date.now()
        phase = "wait"
        // wait to wait emits no phase change; the dim must not replay the time already held.
        motionAt = Date.now()
        frameGate.stop()
        if (airborne) petActor.travelPose(1)
        else petActor.play(petActor.baseAnim())
        // Bound a close-only wait if all home surfaces are disabled in the meantime.
        graceTimer.interval = homeReturnPending ? 2500 : Math.max(1, 400 - (Date.now() - lostAt))
        graceTimer.restart()
    }
    function fade() {
        phaseTimer.stop()
        graceTimer.stop()
        elapsed = 0
        fadeFrom = petActor.detached ? petActor.flightOpacity : petActor.opacity
        phase = "fade"
    }
    function enter() {
        if (!activePerch || !monitorActive) { attach(); return }
        if (!jumps) { attach(); return }
        detach()
        petActor.retained = true
        petActor.flightPx = petActor.perchPx
        petActor.flightOpacity = 0
        elapsed = 0
        phase = "entry"
        const point = targetPoint()
        petActor.flightX = point.x
        petActor.flightY = point.y - 6 * s
        petActor.travelPose(1)
    }
    function startFlight(milliseconds, height, preserveVelocity) {
        const point = targetPoint()
        const dx = point.x - petActor.flightX
        const dy = point.y - petActor.flightY
        duration = milliseconds
        elapsed = 0
        height = Math.min(height, Math.max(0, Math.min(petActor.flightY, point.y)
            - minimumY(Math.max(petActor.flightPx, petActor.perchPx))))
        if (!preserveVelocity) {
            velocityX = dx / duration
            const rise = petActor.flightY - Math.min(petActor.flightY, point.y) + height
            velocityY = -2 * Math.sqrt(rise) * (Math.sqrt(rise) + Math.sqrt(rise + dy)) / duration
        }
        apexPassed = false
        petActor.flightMirrored = dx < 0
        phase = preserveVelocity ? "flight" : "crouch"
        petActor.travelPose(preserveVelocity ? 1 : 0)
        if (!preserveVelocity) { phaseTimer.interval = 80; phaseTimer.restart() }
    }
    function transfer() {
        if (!monitorActive) { silence(); return }
        const next = candidatePerch
        if (next === activePerch) return
        const hadSource = petActor.shown
        const wasFlying = phase === "flight" || (phase === "wait" && airborne)
        if (hadSource) detach()
        if (hadSource && activePerch) departedFrom = activePerch.perchId
        petActor.arriving = true
        activePerch = next
        if (!next) { loseTarget(); return }
        graceTimer.stop()
        if (!jumps) { attach(); return }
        if (phase === "fade") return
        const relay = hadSource && (homeReturnPending || !lostAt || Date.now() - lostAt <= 400)
        lostAt = 0
        if (!relay) {
            if (hadSource) fade()
            else enter()
            return
        }
        const point = targetPoint()
        const distance = Math.hypot(point.x - petActor.flightX, point.y - petActor.flightY)
        if (distance > 900 * s) { fade(); return }
        phaseTimer.stop()
        const jumpPx = Math.max(petActor.flightPx, petActor.perchPx)
        startFlight(Math.max(380, Math.min(520, 380 + 0.18 * distance / s)),
                    jumpHeight(jumpPx, distance), wasFlying)
    }
    // Rail calls this after restX changes. Repeated requests replace the destination.
    function hop(milliseconds, height, direction) {
        // A leaving pet keeps fading; its entry reads the perch's new rest point.
        if (!activePerch || !monitorActive || phase === "fade") return
        if (!jumps) { attach(); petActor.posX = activePerch.restX; return }
        const preserve = phase === "flight" || (phase === "wait" && airborne)
        // A locked perch may have updated its bounds before the hop notification.
        const source = !petActor.transit
            ? activePerch.mapToItem(flightItem, petActor.posX, petActor.y + petActor.footRow * petActor.px) : null
        detach()
        if (source) { petActor.flightX = source.x; petActor.flightY = source.y }
        phaseTimer.stop()
        startFlight(milliseconds, height * Math.max(1, petActor.perchPx / (2 * s)), preserve)
        petActor.flightMirrored = direction < 0
    }
    function tick(milliseconds) {
        const dt = Math.min(milliseconds, 50)
        elapsed += dt
        if (phase === "fade") {
            petActor.flightOpacity = Math.max(0, fadeFrom - elapsed / 160)
            if (petActor.flightOpacity <= 0) {
                attach()
                if (activePerch) enter()
            }
        } else if (phase === "entry") {
            const point = targetPoint()
            const remaining = Math.pow(1 - Math.min(1, elapsed / 200), 3)
            petActor.flightX = point.x
            petActor.flightY = point.y - 6 * s * remaining
            // Scaled by the perch's own reveal so the hand-off to it never dips.
            petActor.flightOpacity = (1 - remaining) * (activePerch ? activePerch.reveal : 1)
            if (elapsed >= 200) land()
        } else if (phase === "wait") {
            petActor.flightOpacity = Math.max(0.4, petActor.flightOpacity - 0.6 * dt / 160)
        } else if (phase === "crouch") {
            petActor.flightOpacity = Math.min(1, petActor.flightOpacity + dt / 120)
        } else if (phase === "flight") {
            // Converge on the destination's reveal by touchdown, so a niche still opening takes no step.
            const reveal = activePerch ? activePerch.reveal : 1
            const ceiling = 1 - Math.min(1, elapsed / duration) * (1 - reveal)
            petActor.flightOpacity = Math.min(ceiling, petActor.flightOpacity + dt / 120)
            const point = targetPoint()
            const remaining = Math.max(dt, duration - elapsed + dt)
            // Recompute acceleration to a moving endpoint while preserving current velocity.
            const ax = 2 * (point.x - petActor.flightX - velocityX * remaining) / (remaining * remaining)
            let ay = 2 * (point.y - petActor.flightY - velocityY * remaining) / (remaining * remaining)
            const clearance = petActor.flightY - minimumY(petActor.flightPx)
            if (velocityY < 0 && clearance > 0)
                ay = Math.max(ay, velocityY * velocityY / (2 * clearance))
            petActor.flightX += velocityX * dt + ax * dt * dt / 2
            petActor.flightY += velocityY * dt + ay * dt * dt / 2
            velocityX += ax * dt
            velocityY += ay * dt
            if (!apexPassed && velocityY >= 0) {
                apexPassed = true
            }
            if (apexPassed && petActor.flightY >= minimumY(petActor.perchPx)) {
                petActor.flightPx = petActor.perchPx
            }
            if (elapsed >= duration) land()
        }
    }
    function land() {
        phase = "land"
        petActor.flightPx = petActor.perchPx
        const point = targetPoint()
        petActor.flightX = point.x
        petActor.flightY = point.y
        petActor.posX = activePerch.restX
        petActor.travelPose(2)
        phaseTimer.interval = 90
        phaseTimer.restart()
    }

    Timer { id: settleTimer; interval: 0; onTriggered: petLayer.transfer() }
    Timer {
        id: pillLookDelay; repeat: false
        onTriggered: {
            if (petLayer.pendingPillDirection && petActor.shown && !petActor.asleep
                && petLayer.phase === "" && petLayer.perchId === "bar"
                && ["idle", "look_left", "look_right", "look_up"].indexOf(petActor.anim) >= 0)
                petLayer.applyPillLook(petLayer.pendingPillDirection)
            petLayer.pendingPillDirection = ""
        }
    }
    Timer {
        id: pillReturn; interval: 1200
        onTriggered: {
            petLayer.pillDirection = ""
            if (petLayer.perchId === "bar" && petLayer.phase === "" && !petActor.asleep) petActor.lookAt(0)
        }
    }
    Connections {
        target: petActor
        function onAnimChanged() {
            if (["idle", "look_left", "look_right", "look_up"].indexOf(petActor.anim) < 0) {
                pillReturn.stop(); pillLookDelay.stop(); petLayer.pendingPillDirection = ""; petLayer.pillDirection = ""
            }
        }
        function onAsleepChanged() { if (petActor.asleep) { pillReturn.stop(); pillLookDelay.stop(); petLayer.pendingPillDirection = ""; petLayer.pillDirection = "" } }
        function onShownChanged() { if (!petActor.shown) { pillReturn.stop(); pillLookDelay.stop(); petLayer.pendingPillDirection = ""; petLayer.pillDirection = "" } }
    }
    Timer { id: graceTimer; onTriggered: { petLayer.homeReturnPending = false; petLayer.fade() } }
    Timer {
        id: phaseTimer
        onTriggered: {
            if (petLayer.phase === "crouch") {
                petLayer.elapsed = 0
                petLayer.airborne = true
                petLayer.phase = "flight"
                petActor.travelPose(1)
            } else if (petLayer.phase === "land") petLayer.attach()
        }
    }
    FrameAnimation {
        id: motion
        running: petLayer.driven && !frameGate.running
        onTriggered: {
            const at = Date.now()
            let remaining = Math.max(0, at - petLayer.motionAt)
            petLayer.motionAt = at
            while (remaining > 0 && running) {
                const dt = Math.min(remaining, 50)
                petLayer.tick(dt)
                remaining -= dt
            }
            if (petLayer.driven) frameGate.restart()
        }
    }
    // A running FrameAnimation renders at monitor Hz even when its writes are throttled.
    Timer { id: frameGate; interval: 24 }
    Item { id: flightItem }
    PetActor {
        id: petActor
        perch: petLayer.activePerch
        detached: transit && petLayer.phase !== "land"
        parent: detached ? flightItem : (petLayer.activePerch || petLayer)
        s: petLayer.s
        desiredPx: Config.pets.scale === "small" ? 1 : Config.pets.scale === "large" ? 3 : 2
        coding: petLayer.coding
        codingReaction: Config.pets.codingReaction
        musicReaction: Config.pets.musicReaction
        nightReaction: Config.pets.nightReaction
        sleepEnabled: Config.pets.sleepEnabled
        mischief: Config.pets.mischief
        sleepAfterMs: Math.round(Math.max(1, Config.pets.sleepAfter) * 60000)
    }
}
