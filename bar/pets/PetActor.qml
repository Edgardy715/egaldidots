import QtQuick
import "../Singletons"

/**
 * The pet itself: a state machine over the package's animations.
 *
 * Cost rules: a single-shot frame timer runs only while the current animation
 * has more than one frame to show; a single-shot brain timer picks idle
 * behaviour every few seconds; a sleep timer waits for inactivity. Hidden or
 * asleep, none of them run and the sprite is a still image. Reduced motion
 * keeps one still pose per state: no walking, no idle behaviour.
 */
Item {
    id: actor

    property Item perch: null
    property real s: 1
    property bool transit: false
    property bool detached: transit
    property bool retained: false
    property real flightX: 0
    property real flightY: 0
    property int flightPx: 2
    property real flightOpacity: 1
    property bool flightMirrored: false
    readonly property bool inputEnabled: hitArea.enabled
    property int desiredPx: 2
    property bool sleepEnabled: true
    property int sleepAfterMs: 120000
    property bool coding: false
    property bool codingReaction: true
    property bool musicReaction: true
    property bool nightReaction: true
    property var now: () => new Date()
    property var random: () => Math.random()
    property int musicDurationMs: 8000
    property real musicUntil: 0
    property real hiddenAt: 0
    property bool greetPending: false
    property bool arriving: false
    property real lastNightYawn: 0
    property string mischief: "normal"
    property real nextMischiefAt: 0
    property real perchChangedAt: 0
    readonly property bool home: perch !== null && (perch.perchId === "bar" || perch.perchId === "rail")
    readonly property bool musicArmed: musicTimer.running
    readonly property int sleepInterval: sleepTimer.interval
    readonly property int brainInterval: brainTimer.interval

    readonly property var pack: PetPack.data
    readonly property bool reduced: Flags.reduceMotion
    readonly property bool shown: (perch !== null || retained) && pack !== null
    readonly property var hit: pack ? pack.hit : [0, 0, 1, 1]
    readonly property int canvasW: pack ? pack.canvas.width : 1
    readonly property int canvasH: pack ? pack.canvas.height : 1
    readonly property int footRow: pack ? pack.canvas.baseline : 1
    readonly property int originX: pack ? pack.canvas.originX : 0
    readonly property int bodyRows: Math.max(1, footRow - hit[1])
    // How far any pose reaches past the body: [left, top, right, bottom) in canvas cells.
    readonly property var bounds: pack && pack.bounds ? pack.bounds : [hit[0], hit[1], hit[0] + hit[2], footRow]
    readonly property int reachRows: Math.max(bodyRows, footRow - bounds[1])
    readonly property int reachRight: Math.max(hit[0] + hit[2], bounds[2]) - originX
    readonly property int basePx: Math.max(1, Math.round(desiredPx * s))
    // A perch never grows for the pet: past its headroom the pixels shrink. A
    // niche centres the body inside its own padding; a line or edge has content
    // above it, so there every pose must fit.
    readonly property int perchPx: perch
        ? Math.max(1, Math.min(basePx, Math.floor(perch.headroom / (perch.kind === "niche" ? bodyRows : reachRows))))
        : basePx
    readonly property int px: detached ? flightPx : perchPx

    // Behaviour state.
    property string anim: ""
    property var current: null
    property int step: 0
    property int loops: 0
    property bool settled: false
    property bool asleep: false
    property real posX: 0
    property real walkTarget: 0
    property int walkDir: 0
    property real lastWalk: 0
    property var clickTimes: []
    property real lastHappy: 0
    property real lastInteraction: 0
    property real lastStretch: 0
    property string afterWake: ""
    property real strokeLastX: -1
    property int strokeDir: 0
    property int strokes: 0
    property real strokeStart: 0

    readonly property real centerX: perch ? Math.max(perch.minX, Math.min(perch.maxX, posX)) : 0
    readonly property bool edgePose: current !== null && current.edge === true
    // Which timers are alive; the cost contract is that a still pet has none ticking.
    readonly property bool animating: frameTimer.running
    readonly property bool thinking: brainTimer.running
    readonly property bool sleepArmed: sleepTimer.running
    readonly property bool dozePending: sleeping.pending

    visible: shown
    opacity: detached ? flightOpacity : (perch ? perch.reveal : 0)
    width: canvasW * px
    height: canvasH * px
    x: detached ? flightX - originX * px : Math.round(centerX - originX * px)
    y: detached ? flightY - footRow * px : !perch ? 0 : Math.round(perch.kind === "niche"
        ? perch.height / 2 - (hit[1] + footRow) / 2 * px
        : perch.floorY - footRow * px)
    z: 50
    Accessible.ignored: true

    function baseAnim() {
        if (asleep) return "sleep"
        if ((perch && perch.mood === "music") || (home && musicReaction && musicUntil > timestamp())) return "dance"
        if (home && coding && codingReaction) return "code"
        return "idle"
    }

    function play(name) {
        if (sleeping.pending && name !== "doze") {
            sleeping.pending = false
            armSleep()
        }
        // Reset the step first so the sprite never indexes the new strip with an old step.
        step = 0
        current = PetPack.animation(name)
        anim = name
        loops = 0
        settled = false
        if (name !== "walk") walkDir = 0
        schedule()
    }

    function schedule() {
        frameTimer.stop()
        if (!shown || transit || current === null || settled) return
        if (reduced) {
            // One still pose; a one-shot animation still ends on time.
            if (!current.loop || (anim !== "walk" && anim !== baseAnim())) {
                frameTimer.interval = current.ms.reduce((sum, value) => sum + value, 0)
                frameTimer.start()
            }
            return
        }
        if (current.loop && current.f.length === 1) return
        frameTimer.interval = current.ms[step]
        frameTimer.start()
    }

    function advance() {
        if (current === null) return
        if (walkDir !== 0) {
            posX += walkDir * Math.max(1, current.stepPx) * px
            if ((walkDir > 0 && posX >= walkTarget) || (walkDir < 0 && posX <= walkTarget)) {
                posX = walkTarget
                walkDir = 0
                play(baseAnim())
                return
            }
        }
        if (reduced) { finish(); return }
        if (step + 1 < current.f.length) {
            step++
            schedule()
            return
        }
        // Only resting states loop; a looping reaction (happy, wave) plays one cycle.
        const resting = anim === "walk" || anim === baseAnim()
        if (!current.loop || !resting) { finish(); return }
        loops++
        if (anim === "idle" && loops % 4 === 0) { play("idle_breath"); return }
        if (current.settleAfterLoops > 0 && loops >= current.settleAfterLoops) {
            // Settled poses (sleep) stay still: no timer until something wakes it.
            step = 0
            settled = true
            return
        }
        step = 0
        schedule()
    }

    function finish() {
        if (anim === "doze" && sleeping.pending) {
            sleeping.pending = false
            asleep = true
        }
        if (anim === "wake" && afterWake) {
            const event = afterWake
            afterWake = ""
            act(event)
            return
        }
        if (anim === "love") { play("happy"); return }
        play(baseAnim())
    }

    function free(cx) {
        if (!perch || perch.avoidTo < perch.avoidFrom || perch.avoidFrom < 0) return true
        const half = hit[2] * px / 2 + 4 * s
        return cx + half < perch.avoidFrom || cx - half > perch.avoidTo
    }

    function walkTo(target) {
        if (!perch || transit || reduced) return false
        target = Math.max(perch.minX, Math.min(perch.maxX, target))
        if (Math.abs(target - centerX) < 2 * px) return false
        posX = centerX
        walkTarget = target
        walkDir = target > centerX ? 1 : -1
        lastWalk = Date.now()
        play("walk")
        return true
    }

    // Moves off an avoided range (a playhead) toward the roomier side.
    function keepClear() {
        if (!perch || free(centerX)) return
        const half = hit[2] * px / 2 + 6 * s
        const left = perch.avoidFrom - half
        const right = perch.avoidTo + half
        const target = left - perch.minX >= perch.maxX - right ? left : right
        if (!walkTo(target)) posX = target
    }

    function clearIfIdle() {
        if (shown && !transit && walkDir === 0) keepClear()
    }

    // Timers are armed only from here; a restart() would break a running binding.
    function timestamp() { return now().getTime() }
    function night() { const hour = now().getHours(); return hour >= 23 || hour < 6 }
    function armBrain() {
        if (shown && !transit && !asleep && !reduced) {
            brainTimer.interval = baseAnim() === "code" ? 20000 + Math.floor(random() * 20000)
                                                       : 3000 + Math.floor(random() * 4000)
            brainTimer.restart()
        } else brainTimer.stop()
    }
    function armSleep() {
        sleepTimer.stop()
        if (shown && !transit && sleepEnabled && !asleep) {
            sleepTimer.interval = nightReaction && night() ? Math.max(60000, sleepAfterMs / 2) : sleepAfterMs
            sleepTimer.start()
        }
    }
    function armMusic() {
        musicTimer.stop()
        if (shown && !transit && !asleep && home && musicReaction && musicUntil > timestamp()) {
            musicTimer.interval = Math.max(1, musicUntil - timestamp())
            musicTimer.start()
        }
    }
    function refreshBase() {
        if (shown && !transit && !asleep && (anim === "idle" || anim === "code" || anim === "dance"))
            play(baseAnim())
        armBrain()
        armMusic()
    }
    function think() {
        if (!shown || transit || asleep || reduced) return
        if (anim === "code" && settled) play(baseAnim())
        else if (anim === "idle") {
            if (tryMischief()) { armBrain(); return }
            const time = timestamp()
            if (time - lastInteraction > 90000 && time - lastStretch > 60000 && random() < 0.04) {
                lastStretch = time
                play("stretch")
            } else if (nightReaction && night() && time - lastNightYawn >= 120000 && random() < 0.12) {
                lastNightYawn = time
                act("nightYawn")
            } else {
                const roomy = perch.maxX - perch.minX > 3 * hit[2] * px
                const roll = random()
                if (roomy && roll < 0.22 && time - lastWalk > 20000) {
                    const span = perch.maxX - perch.minX
                    let target = perch.minX + random() * span
                    for (let tries = 0; tries < 4 && !free(target); tries++) target = perch.minX + random() * span
                    if (free(target)) walkTo(target)
                } else if (roll < 0.6) act("blink")
                else if (roll < 0.85) act(random() < 0.5 ? "lookLeft" : "lookRight")
                else if (perch.kind === "edge") act("perchEdge")
            }
        }
        armBrain()
    }

    function planMischief() {
        const mean = {rare: 900000, normal: 360000, frequent: 120000}[mischief] || 0
        nextMischiefAt = mean ? timestamp() + mean * (0.6 + 0.8 * random()) : 0
    }
    function tryMischief() {
        const time = timestamp()
        if (!shown || transit || asleep || reduced || !perch || perch.perchId === "launcher"
            || anim !== "idle" || walkDir !== 0 || time - perchChangedAt < 3000
            || !nextMischiefAt || time < nextMischiefAt || mischief === "never") return false
        const entries = pack.mischief || []
        let roll = random() * entries.reduce((sum, entry) => sum + entry.weight, 0)
        planMischief()
        for (const entry of entries) {
            roll -= entry.weight
            if (roll < 0) { play(entry.animation); return true }
        }
        return false
    }

    function wake(event) {
        sleeping.pending = false
        lastInteraction = timestamp()
        if (asleep) {
            asleep = false
            afterWake = reduced ? "" : (event || "")
            play(reduced ? baseAnim() : "wake")
            armSleep()
            return true
        }
        armSleep()
        return false
    }

    function act(event) {
        const name = pack && pack.events ? pack.events[event] : ""
        if (name) play(name)
    }

    function handleEvent(kind) {
        if (!shown) return
        if (kind === "musicStart") {
            if (!musicReaction || !home || asleep) return
            musicUntil = timestamp() + musicDurationMs
            if (!transit) play(baseAnim())
            armMusic()
            return
        }
        if (kind === "codingFocus") {
            if (!codingReaction || !coding) return
            if (wake("coding")) return
            refreshBase()
            return
        }
        if (kind === "music" && asleep) return
        if (transit) return
        if (wake(kind)) return
        if (kind === "music") play(baseAnim())
        else act(kind)
    }

    function sleepNow() {
        sleeping.pending = false
        afterWake = ""
        asleep = true
        play("sleep")
    }

    function pet() {
        const now = Date.now()
        if (now - lastHappy < 2500) return
        lastHappy = now
        if (wake("pet")) return
        act("pet")
    }

    // Three clicks within 1.5 s are a pat.
    function click() {
        if (wake("click")) return
        const now = Date.now()
        clickTimes = clickTimes.filter(time => now - time < 1500).concat([now])
        if (clickTimes.length >= 3) {
            clickTimes = []
            pet()
        } else {
            act("click")
        }
    }

    function travelPose(index) {
        step = 0
        current = PetPack.animation("hop")
        anim = "hop"
        if (current) step = Math.min(index, current.f.length - 1)
        frameTimer.stop()
    }

    function lookAt(direction) {
        if (!shown || transit || asleep) return
        play(direction === 0 ? baseAnim() : direction === "up" ? "look_up" : direction < 0 ? "look_left" : "look_right")
        if (direction !== 0) { frameTimer.stop(); settled = true }
    }

    function placeInPerch() {
        if (shown && !nextMischiefAt && mischief !== "never") planMischief()
        if (transit) { frameTimer.stop(); armBrain(); armSleep(); armMusic(); return }

        walkDir = 0
        posX = perch ? perch.restX : 0
        lastInteraction = timestamp()
        asleep = false
        sleeping.pending = false
        if (shown) {
            play(baseAnim())
            greetIfReady()
        } else frameTimer.stop()
        armSleep()
        armBrain()
        armMusic()
    }

    function greetIfReady() {
        if (shown && !transit && !arriving && greetPending && home) {
            greetPending = false
            act("greet")
        }
    }
    function visibilityChanged() {
        if (!shown) {
            hiddenAt = timestamp()
            musicUntil = 0
        } else if (hiddenAt) {
            if (timestamp() - hiddenAt > 600000) greetPending = true
            hiddenAt = 0
        }
        placeInPerch()
    }

    onCodingChanged: { if (!(coding && codingReaction && wake("coding"))) refreshBase() }
    onMischiefChanged: planMischief()
    onCodingReactionChanged: refreshBase()
    onMusicReactionChanged: { if (!musicReaction) musicUntil = 0; refreshBase() }
    onNightReactionChanged: armSleep()
    onNowChanged: armSleep()
    onHomeChanged: refreshBase()
    onTransitChanged: placeInPerch()
    onPerchChanged: { perchChangedAt = timestamp(); placeInPerch() }
    onShownChanged: visibilityChanged()
    onAsleepChanged: { if (asleep) musicUntil = 0; armBrain(); armSleep(); armMusic() }
    onReducedChanged: {
        armBrain()
        if (shown) play(baseAnim())
    }
    onSleepEnabledChanged: {
        if (!sleepEnabled) {
            sleeping.pending = false
            if (asleep) {
                asleep = false
                play(baseAnim())
            }
        }
        armSleep()
    }
    Connections {
        target: actor.perch
        function onMoodChanged() { if (!actor.transit && !actor.asleep && actor.walkDir === 0) actor.play(actor.baseAnim()) }
        // Both ends of the range move together; check once they have settled.
        function onAvoidFromChanged() { Qt.callLater(actor.clearIfIdle) }
        function onAvoidToChanged() { Qt.callLater(actor.clearIfIdle) }
    }

    QtObject {
        id: sleeping
        property bool pending: false
    }

    Timer {
        id: frameTimer
        repeat: false
        onTriggered: actor.advance()
    }

    Timer {
        id: brainTimer
        repeat: false
        onTriggered: actor.think()
    }
    Timer {
        id: musicTimer
        repeat: false
        onTriggered: { actor.musicUntil = 0; actor.refreshBase() }
    }

    Timer {
        id: sleepTimer
        repeat: false
        onTriggered: {
            if (!actor.sleepEnabled) return
            if (actor.walkDir !== 0 || hitArea.containsMouse || actor.baseAnim() === "dance") { actor.armSleep(); return }
            if (actor.reduced) actor.sleepNow()
            else { sleeping.pending = true; actor.play("doze") }
        }
    }

    PetSprite {
        source: PetPack.atlas
        frame: actor.current ? actor.current.f[Math.min(actor.step, actor.current.f.length - 1)] : 0
        frameCount: actor.pack ? actor.pack.frameCount : 1
        frameWidth: actor.canvasW
        frameHeight: actor.canvasH
        px: actor.px
        mirrored: actor.transit ? actor.flightMirrored : actor.walkDir < 0
    }

    // The body is the only target: the transparent canvas never takes input.
    MouseArea {
        id: hitArea
        x: actor.hit[0] * actor.px
        y: actor.hit[1] * actor.px
        width: actor.hit[2] * actor.px
        height: actor.bodyRows * actor.px
        enabled: actor.shown && !actor.transit && actor.perch !== null && actor.perch.interactive
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        Accessible.ignored: true
        onEntered: {
            const woke = actor.wake("hover")
            actor.strokes = 0
            actor.strokeLastX = -1
            if (!woke && actor.anim === actor.baseAnim() && actor.walkDir === 0) actor.act("hover")
        }
        onPositionChanged: mouse => {
            // A stroke is the cursor going back and forth across the body.
            const now = Date.now()
            if (actor.strokeLastX >= 0 && Math.abs(mouse.x - actor.strokeLastX) >= 3 * actor.s) {
                const dir = mouse.x > actor.strokeLastX ? 1 : -1
                if (actor.strokeDir !== 0 && dir !== actor.strokeDir) {
                    if (now - actor.strokeStart > 1500) { actor.strokes = 0; actor.strokeStart = now }
                    if (++actor.strokes >= 3) { actor.strokes = 0; actor.pet() }
                }
                actor.strokeDir = dir
                actor.strokeLastX = mouse.x
            } else if (actor.strokeLastX < 0) {
                actor.strokeLastX = mouse.x
                actor.strokeStart = now
            }
        }
        onClicked: actor.click()
    }
}
