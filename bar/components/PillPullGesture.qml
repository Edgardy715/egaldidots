import QtQuick
import "../Singletons"

// Input-independent gesture state. Positions use the stable overlay coordinate
// system, samples use milliseconds, and spring velocities use pixels/second.
QtObject {
    id: root
    required property var motion
    property bool enabled: true
    property bool reduceMotion: false
    property real s: 1
    property string target: "utils"
    function resolveTarget(preference, mediaVisible, activityLive) {
        return preference === "auto" ? (mediaVisible ? "media" : activityLive ? "focus" : "utils") : preference
    }
    property string mode: "surface"
    property string kind: "surface"
    property string direction: ""
    readonly property real contentOffset: contentSpring.value
    readonly property real contentVelocity: contentSpring.velocity
    property real startContentOffset: 0
    property bool manualStep: false
    property bool contentHandoff: false
    property string pendingNotificationAction: ""
    readonly property alias contentMotion: root.contentSpring
    property SpringValue contentSpring: SpringValue {
        spring: Motion.surfaceSpring.close.w
        manualStep: true
        settleDistance: 0.1
        settleSpeed: 0.1
    }
    property FrameAnimation contentFrames: FrameAnimation {
        running: contentSpring.integrating && !root.candidate && !root.manualStep
        onTriggered: root.stepContent(frameTime)
    }
    function stepContent(dt) {
        if (candidate || !contentSpring.integrating) return
        if (contentHandoff) {
            contentHandoff = false
            contentSpring.value += contentSpring.velocity * Math.min(dt, 2)
        } else contentSpring.step(dt)
        if (pendingNotificationAction && (Math.abs(contentOffset) >= startW * 0.65 || !contentSpring.integrating)) {
            pendingNotificationAction = ""
            finishNotificationRelease("dismiss", false, false)
        }
    }
    signal notificationStarted()
    signal notificationFinished(string action)
    function resetNotificationContent() {
        startContentOffset = 0
        contentHandoff = false
        contentSpring.target = 0
        contentSpring.snap(0)
    }
    function finishPendingNotification() {
        if (!pendingNotificationAction) return
        pendingNotificationAction = ""
        contentSpring.snap(contentSpring.target)
        finishNotificationRelease("dismiss", false, false)
    }
    function beginSampling(time, x, y) { samples = [{t: time, w: x, h: y}] }
    function finishSampling(time) {
        if (samples.length) sample(time, samples[samples.length - 1].w, samples[samples.length - 1].h)
        velocityW = slope("w") * 1000; velocityH = slope("h") * 1000
    }
    property var rubberBand: null
    property bool candidate: false
    property bool active: false
    property bool resolving: false
    property bool wasOpen: false
    property bool catching: false
    property real plannedW: 0
    property real plannedH: 0
    property real plannedRadius: 0
    property bool scrolling: false
    property string surface: ""
    property real startX: 0
    property real startY: 0
    property real startW: 0
    property real startH: 0
    property real startRadius: 0
    property real destinationW: 0
    property real destinationH: 0
    property real destinationRadius: 0
    property real progress: 0
    property real scrollY: 0
    property var samples: []
    property real velocityW: 0
    property real velocityH: 0
    signal prepare(string name)
    signal settled(string name, bool opened)

    function press(x, y, time, opened, name) {
        if (!enabled || candidate || pendingNotificationAction) return false
        kind = mode; direction = ""
        startContentOffset = contentOffset
        contentSpring.snap(startContentOffset)
        candidate = true; wasOpen = opened; catching = motion.integrating; surface = opened ? name : target
        startX = x; startY = y
        startW = motion.width; startH = motion.height; startRadius = motion.radius
        beginSampling(time, startW, startH)
        velocityW = motion.velW; velocityH = motion.velH
        if (!reduceMotion) motion.grab()
        if (kind === "notification") {
            surface = "notifs"
            motion.gestureSpring = !reduceMotion
            notificationStarted()
        }
        return true
    }
    function sample(time, w, h) {
        const next = samples.filter(p => time - p.t <= Motion.pullSampleWindow)
        if (next.length && next[next.length - 1].t === time) next.pop()
        next.push({t: time, w: w, h: h})
        samples = next
    }
    function slope(key) {
        if (samples.length < 2) return 0
        let t = 0, v = 0, numerator = 0, denominator = 0
        const origin = samples[0].t
        for (const p of samples) { t += p.t - origin; v += p[key] }
        t /= samples.length; v /= samples.length
        for (const p of samples) {
            const d = p.t - origin - t
            numerator += d * (p[key] - v); denominator += d * d
        }
        return denominator > 0 ? numerator / denominator : 0
    }
    function wantsMove(x, y) {
        const dx = x - startX, dy = y - startY
        if (kind === "notification") return candidate && Math.max(Math.abs(dx), Math.abs(dy)) > Motion.pullThreshold * s
        return candidate && Math.abs(dy) > Motion.pullThreshold * s && Math.abs(dy) > Math.abs(dx)
            && (catching || (!wasOpen && dy > 0) || (wasOpen && dy < 0))
    }
    function move(x, y, time) {
        if (!candidate) return false
        const dx = x - startX, dy = y - startY
        if (!active) {
            if (!wantsMove(x, y)) return false
            active = true
            if (kind === "notification") {
                direction = Math.abs(dx) > Math.abs(dy) ? "horizontal" : dy < 0 ? "up" : "down"
                if (direction === "horizontal") beginSampling(samples[0].t, startContentOffset, startH)
            }
            else if (!reduceMotion) prepare(surface)
        }
        if (kind === "notification") return moveNotification(dx, dy, time)
        // Async content can shrink the surface after prepare (notably utils).
        // Follow its current destination, rather than the initial maximum size.
        destinationW = reduceMotion ? (wasOpen ? startW : plannedW) : motion.targetW
        destinationH = reduceMotion ? (wasOpen ? startH : plannedH) : motion.targetH
        destinationRadius = reduceMotion ? (wasOpen ? startRadius : plannedRadius) : motion.targetRadius
        const rawH = startH + dy
        const span = Math.max(1, destinationH - motion.coreH)
        progress = Math.max(0, Math.min(1, (rawH - motion.coreH) / span))
        let h = rawH
        if (!reduceMotion && rubberBand) {
            if (h > destinationH) h = destinationH + rubberBand(h - destinationH, Motion.pullOverdrag * s)
            else if (h < motion.coreH) h = motion.coreH + rubberBand(h - motion.coreH, Motion.pullUnderdrag * s)
        }
        const p0 = (startH - motion.coreH) / span
        // Anchor both segments at the caught spring position, even when its two
        // axes are at different phases. No width jump on an interruption.
        const w = h >= startH
            ? startW + (destinationW - startW) * Math.min(1, (h - startH) / Math.max(1, destinationH - startH))
            : startW + (motion.restW - startW) * Math.min(1, (startH - h) / Math.max(1, startH - motion.coreH))
        const r = progress >= p0
            ? startRadius + (destinationRadius - startRadius) * Math.min(1, (progress - p0) / Math.max(0.001, 1 - p0))
            : startRadius + (motion.coreH / 2 - startRadius) * Math.min(1, (p0 - progress) / Math.max(0.001, p0))
        sample(time, w, h)
        if (!reduceMotion) {
            motion.grabW = w; motion.grabH = h; motion.grabRadius = r
            motion.grabProgress = progress
        }
        return true
    }
    function moveNotification(dx, dy, time) {
        let w = startW, h = startH, r = startRadius
        if (direction === "horizontal") {
            const limit = Math.max(startW * 0.4, s)
            const travel = startContentOffset + dx
            const raw = Math.abs(travel) <= limit ? travel
                : Math.sign(travel) * limit + (rubberBand ? rubberBand(travel - Math.sign(travel) * limit, 40 * s) : 0)
            contentSpring.snap(reduceMotion ? 0 : raw)
            progress = Math.abs(dx) / Math.max(1, startW)
            sample(time, raw, startH)
        } else if (direction === "up") {
            h = Math.max(motion.coreH, startH + dy)
            progress = Math.max(0, -dy / Math.max(1, startH - motion.coreH))
            w = startW + (motion.restW - startW) * Math.min(1, progress)
            r = startRadius + (motion.coreH / 2 - startRadius) * Math.min(1, progress)
            // Measure the hand before the height clamp, so an upward fling at
            // the compact height still carries its release velocity.
            sample(time, w, startH + dy)
        } else {
            destinationW = plannedW; destinationH = plannedH; destinationRadius = plannedRadius
            h = Math.max(startH, startH + dy)
            if (h > destinationH && rubberBand) h = destinationH + rubberBand(h - destinationH, Motion.pullOverdrag * s)
            progress = Math.max(0, (h - startH) / Math.max(1, destinationH - startH))
            w = startW + (destinationW - startW) * Math.min(1, progress)
            r = startRadius + (destinationRadius - startRadius) * Math.min(1, progress)
            sample(time, w, h)
        }
        if (!reduceMotion) { motion.grabW = w; motion.grabH = h; motion.grabRadius = r; motion.grabProgress = progress }
        return true
    }
    function releaseNotification(time, cancelled) {
        finishSampling(time)
        const dismiss = !cancelled && active && (direction === "up"
            ? progress > 0.4 || velocityH < -350 * s
            : direction === "horizontal" && (progress > 0.4 || Math.abs(velocityW) > 350 * s))
        const opened = !cancelled && active && direction === "down" && (progress > 0.5 || velocityH > 350 * s)
        if (direction === "horizontal" && !reduceMotion) {
            // The container stays caught until its text has actually left.
            // Returning text and an interrupted return retain position/velocity.
            contentSpring.target = dismiss ? Math.sign(contentOffset || velocityW) * startW : 0
            contentSpring.velocity = cancelled ? 0 : velocityW
            contentSpring.retarget()
            contentHandoff = true
            velocityW = 0; velocityH = 0
            if (dismiss) {
                pendingNotificationAction = "dismiss"
                candidate = false; active = false; scrolling = false
                return true
            }
        }
        finishNotificationRelease(dismiss ? "dismiss" : opened ? "open" : "return", opened, cancelled)
        return opened || dismiss
    }
    function finishNotificationRelease(action, opened, cancelled) {
        resolving = true
        notificationFinished(action)
        if (opened) settled("notifs", true)
        if (motion.grabbed) motion.release(cancelled ? 0 : velocityW, cancelled ? 0 : velocityH)
        resolving = false; candidate = false; active = false; scrolling = false
    }
    function release(time) {
        if (!candidate) return false
        scrollEnd.stop()
        if (kind === "notification") return releaseNotification(time, false)
        if (!active) {
            candidate = false; scrolling = false
            if (motion.grabbed) motion.release(velocityW, velocityH, false)
            return false
        }
        // Include a stationary release; holding still removes an old fling.
        finishSampling(time)
        const fling = Motion.pullFling * s * 1000
        const opened = velocityH < -fling ? false : progress > 0.5 || velocityH > fling
        resolving = true
        settled(surface, opened)
        if (motion.grabbed) motion.release(velocityW, velocityH)
        resolving = false
        candidate = false; active = false; scrolling = false
        return opened
    }
    function cancel(restore) {
        if (!candidate) return
        scrollEnd.stop()
        if (kind === "notification") { releaseNotification(Date.now(), true); return }
        resolving = true
        if (active && restore !== false) settled(surface, wasOpen)
        if (motion.grabbed) motion.release(0, 0)
        resolving = false
        candidate = false; active = false; scrolling = false
    }
    function wheel(dx, dy, time, opened, name, atTop, inverted) {
        // Follow physical fingers even when the compositor reverses scroll deltas.
        if (inverted) { dx = -dx; dy = -dy }
        if (!enabled || (dx === 0 && dy === 0) || Math.abs(dx) >= Math.abs(dy)) return false
        if (!candidate) {
            if (opened && (!atTop || dy >= 0) || !opened && dy <= 0) return false
            if (!press(0, 0, time, opened, name)) return false
            scrollY = 0; scrolling = true
        }
        if (!scrolling) return false
        scrollY += dy
        move(0, scrollY, time)
        lastWheelTime = time
        scrollEnd.restart()
        return true
    }
    // Side-effect-free twin of wheel(): decides acceptance while Qt is still
    // delivering the event. The real work runs from queueWheel() afterwards,
    // because opening/closing a surface destroys items in Qt's delivery list
    // (use-after-free SIGSEGV in deliverSinglePointEventUntilAccepted).
    function wheelWanted(dx, dy, opened, atTop, inverted) {
        if (inverted) { dx = -dx; dy = -dy }
        if (!enabled || pendingNotificationAction || (dx === 0 && dy === 0) || Math.abs(dx) >= Math.abs(dy)) return false
        if (scrolling || wheelQueue.length) return true
        // El scroll nunca cierra una surface abierta: choca con desplazarse hacia abajo.
        if (opened) return false
        if (candidate) return false
        return !(opened && (!atTop || dy >= 0) || !opened && dy <= 0)
    }
    property var wheelQueue: []
    property bool wheelReleasePending: false
    property real wheelReleaseTime: 0
    // A scroll has no lift-off event unless the device reports ScrollEnd, so
    // idle-timeout releases measure the flick at the last scroll step: the
    // timeout is ours, not the user holding still.
    property real lastWheelTime: 0
    function queueWheel(dx, dy, time, opened, name, atTop, inverted) {
        wheelQueue = wheelQueue.concat([[dx, dy, time, opened, name, atTop, inverted]])
        Qt.callLater(flushWheel)
    }
    function queueWheelRelease(time) {
        wheelReleasePending = true
        wheelReleaseTime = time
        Qt.callLater(flushWheel)
    }
    function flushWheel() {
        const queue = wheelQueue
        wheelQueue = []
        for (const e of queue) wheel(e[0], e[1], e[2], e[3], e[4], e[5], e[6])
        if (wheelReleasePending) {
            wheelReleasePending = false
            if (scrolling) release(Math.max(lastWheelTime, wheelReleaseTime || lastWheelTime))
        }
    }
    property Timer scrollEnd: Timer {
        interval: Motion.pullScrollTimeout
        onTriggered: root.release(root.scrolling ? root.lastWheelTime : Date.now())
    }
    onEnabledChanged: if (!enabled) { cancel(); finishPendingNotification() }
    onReduceMotionChanged: {
        if (candidate) cancel()
        if (reduceMotion) {
            if (pendingNotificationAction) finishPendingNotification()
            else resetNotificationContent()
        }
    }
}
