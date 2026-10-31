pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import "../Singletons"
import "../Singletons/Visitors.js" as Visitors

// The island's own face. It is the system's expression, not a guest: every
// gesture answers a real event (focus, recording, confirmations, music, presence)
// and settles to stillness. No idle loop; moments are finite and stop when hidden.
Item {
    id: root
    property real s: 1
    // The eye takes a trace of the theme accent; the palette changes it softly.
    property color eyeColor: Qt.tint(Theme.foreground, Qt.alpha(Theme.accent, 0.12))
    Behavior on eyeColor { enabled: !root.reduced && !root.suspended && root.visible; ColorAnimation { duration: Motion.standard } }
    property bool reduced: Flags.reduceMotion
    property string mood: "rest"
    property bool engaged: false
    property real lookX: 0
    property real lookY: 0
    property bool asleep: false     // the user left: eyes close to a line
    property bool sleepy: false     // late night: heavier lids
    property bool listening: false  // music playing; its start is a moment
    property var context: null
    readonly property bool suspended: context ? !context.active : false
    property string gesture: ""
    property real winkLid: 1
    property real lowerLid: 0
    property real roll: 0
    property real breath: 1
    property double lastClick: 0
    property int clickCount: 0
    property bool pointerOver: false
    property real touchTarget: 0
    property real touch: touchTarget
    property real touchDirection: 0
    property real localLook: 0
    property bool lingering: false
    property double affectionUntil: 0
    property double sleptAt: 0
    readonly property bool followsPointer: !context || !!context.options.followPointer
    readonly property bool interactive: !reduced && !suspended && visible && !asleep
    readonly property real materialX: followsPointer ? Math.max(-1, Math.min(1, localLook)) * touch * 1.1 * s : 0
    readonly property real materialY: touch * 0.8 * s
    readonly property real materialScaleX: 1 - touch * 0.08
    readonly property real materialScaleY: 1 + touch * 0.08
    readonly property real beat: context ? context.pupilBeat : 0
    readonly property bool concentrating: context ? context.concentrating : false
    readonly property bool tired: context ? context.tired : false                 // low battery: lids stay heavy
    readonly property bool recordingAware: context ? context.recordingAware : false // a capture runs: red glint
    readonly property bool squinting: gesture === "squint" || gesture === "content"
    property real highlightX: gazeX * 0.32
    property real highlightY: gazeY * 0.32
    property real lid: 1
    readonly property bool smiling: mood === "received" || mood === "connected" || mood === "finished" || cheerful || glad
    readonly property bool resting: mood === "paused"
    readonly property bool awake: !asleep
    property bool cheerful: false   // brief joy after a pat or a song starting
    property bool glad: false       // the smile inside a welcome; its animation owns it

    // Expression targets. Openness 1 is the neutral eye; 0 a closed line.
    readonly property real openTarget: gesture === "yawn" ? 1.15 : gesture === "surprised" ? 1.25 : asleep ? 0
        : smiling ? 1
        : gesture === "curious" ? 1.12
        : mood === "attention" ? 1.18
        : resting ? 0.28
        : mood === "working" || concentrating ? 0.62
        : engaged ? 1.08 : 1
    property real open: openTarget
    readonly property real eyeOpening: open * (1 - touch * 0.72)
    // Late at night the upper lid hangs flat over the eye; attention lifts it.
    property bool wary: false       // a brief lowered upper lid while it shakes its head
    property real droop: asleep || smiling || mood !== "rest" ? 0 : wary ? 0.25
        : sleepy ? (engaged ? 0.22 : 0.48) : tired ? (engaged ? 0.16 : 0.35) : 0
    property real smile: smiling && !asleep ? 1 - touch * 0.65 : 0
    // A visitor (see Visitors.js) crosses the slot while the shared progress and
    // envelope drive the gaze directly; a spring retargeted every frame would lag.
    property bool visitorOwnsGaze: false
    property real visitProgress: 0
    property real visitStartX: 0
    property real visitStartY: 0
    readonly property bool visiting: Visitors.has(gesture)
    readonly property var visitorSpec: Visitors.table[visiting ? gesture : "firefly"]
    readonly property real visitPresence: visiting ? Math.min(1, visitProgress * 8, (1 - visitProgress) * 8) : 0
    readonly property real visitorX: visitorSpec.x(visitProgress) * s
    readonly property real visitorY: visitorSpec.y(visitProgress) * s
    property real gazeX: reduced || asleep ? 0 : visiting ? (visitStartX * (1 - visitPresence) + (visitorX / s - 15) * 0.23 * visitPresence) * s : Math.max(-1, Math.min(1, followsPointer && (pointerOver || lingering) ? localLook : lookX)) * 3 * s
    property real gazeY: reduced || asleep ? 0 : visiting ? (visitStartY * (1 - visitPresence) + (visitorY / s - 13) * 0.2 * visitPresence) * s
        : mood === "working" ? 1.2 * s : Math.max(-1, Math.min(1, lookY)) * 1.8 * s
    // Transient body language, always returning to zero.
    property real hop: 0
    property real tilt: 0
    property real squash: 1
    property real shake: 0           // gaze offset of a "no", in units of the full gaze range
    readonly property real restDrop: asleep ? 1.2 * s : 0
    width: 30 * s; height: 26 * s
    Accessible.ignored: true

    function stopMoment() {
        visitorOwnsGaze = false
        touchRelease.stop()
        touchBehavior.enabled = false
        touchTarget = 0
        touch = Qt.binding(() => root.touchTarget)
        touchBehavior.enabled = Qt.binding(() => root.interactive)
        blink.stop(); lid = 1
        celebration.stop(); swayMotion.stop(); patMotion.stop(); wakeMotion.stop(); specialMotion.stop(); dozeMotion.stop(); heldSneeze.stop(); visitorMotion.stop(); welcomeMotion.stop(); surprisedMotion.stop(); shakeMotion.stop(); reliefMotion.stop()
        glad = false; wary = false; shake = 0; winkLid = 1; lowerLid = 0; roll = 0; breath = 1; hop = 0; tilt = 0; squash = 1
        gesture = ""
        visitProgress = 0
    }
    function touched() { if (context) context.interacted() }
    function interact(choice) {
        if (suspended || !visible || asleep) return
        touched()
        const now = Date.now()
        clickCount = now - lastClick < 1100 ? clickCount + 1 : 1
        lastClick = now
        if (clickCount === 5) { play("firefly"); return }
        if (clickCount === 4) { play("holdSneeze"); return }
        if (clickCount >= 3) { play("squint"); return }
        approach.stop()
        play(choice || (clickCount === 2 ? "roll" : now < affectionUntil ? "wink" : "curious"))
    }
    function play(kind) {
        if (reduced || suspended || !visible || (asleep && kind !== "yawn")) return
        const startX = gazeX / s, startY = gazeY / s
        stopMoment()
        visitStartX = startX; visitStartY = startY
        visitorOwnsGaze = Visitors.has(kind)
        gesture = kind
        if (kind === "squint" || kind === "content") { cheerful = true; cheerHold.restart() }
        if (kind === "holdSneeze" || visitorOwnsGaze) { cheerHold.stop(); cheerful = false }
        if (visitorOwnsGaze) visitorMotion.restart()
        else if (kind === "holdSneeze") heldSneeze.restart()
        else if (kind === "doze") dozeMotion.restart()
        else if (kind === "welcome" || kind === "welcomeBack") welcomeMotion.restart()
        else if (kind === "surprised") surprisedMotion.restart()
        else if (kind === "no" || kind === "dust") shakeMotion.restart()
        else if (kind === "relief") reliefMotion.restart()
        else specialMotion.restart()
    }
    function finishVisit() {
        const kind = gesture, popped = visitorSpec.pop
        visitorOwnsGaze = false; gesture = ""; visitProgress = 0
        if (popped) blink.restart()
        if (context) context.visited(kind)
    }
    function finishShake() {
        wary = false
        if (gesture === "dust") play("yawn")
        else gesture = ""
    }
    function approachPointer(inside) {
        pointerOver = inside
        approach.stop(); linger.stop()
        if (!interactive) return
        if (inside) {
            if (gesture === "holdSneeze" || visiting) stopMoment()
            lingering = false
            if (Date.now() < affectionUntil) { cheerful = true; cheerHold.restart() }
            greet(); approach.restart()
        } else {
            lingering = followsPointer
            if (lingering) linger.restart()
        }
    }
    function stroke(speed, direction, position) {
        if (!interactive) return
        approach.stop()
        localLook = position
        touchDirection = followsPointer ? direction : 0
        if (speed > 550) {
            touchTarget = 0
            if (!tickleCooldown.running) { play("squint"); tickleCooldown.restart(); touched() }
        } else {
            if (touchTarget === 0) touched()
            if (gesture !== "" || blink.running || celebration.running || swayMotion.running || wakeMotion.running) stopMoment()
            touchTarget = Math.min(1, touchTarget + 0.24)
            touchRelease.restart()
        }
    }
    function wakeAfter(milliseconds) {
        // Not `interactive`: when asleep flips, that binding may not have been re-evaluated yet.
        if (reduced || suspended || !visible || asleep) return
        stopMoment()
        if (milliseconds < 60000) play(Date.now() < affectionUntil ? "wink" : "curious")
        else if (milliseconds < 1800000) wakeMotion.restart()
        else play("dust")  // half an hour asleep: it shakes the dust off
    }
    function greet() {
        if (reduced || suspended || !visible || asleep || cooldown.running) return
        stopMoment()
        blink.restart()
        cooldown.restart()
    }
    function nod() {
        if (reduced || suspended || !visible || asleep) return
        play("wink")
    }
    function celebrate() {
        if (reduced || suspended || !visible || asleep) return
        stopMoment(); celebration.restart()
    }
    function sway() {
        if (reduced || suspended || !visible || asleep) return
        stopMoment(); swayMotion.restart()
    }
    function pat() {
        if (reduced || suspended || !visible || asleep) return
        touched()
        affectionUntil = Date.now() + 30000
        cheerful = true
        cheerHold.restart()
        stopMoment(); gesture = "pat"; patMotion.restart()
    }
    function settle() {
        blink.stop(); cooldown.stop(); celebration.stop(); swayMotion.stop()
        stopMoment(); cheerHold.stop()
        approach.stop(); linger.stop(); touchRelease.stop(); tickleCooldown.stop()
        pointerOver = false; lingering = false; touchTarget = 0; touchDirection = 0
        touchMotion.complete(); directionMotion.complete()
        gazeXMotion.complete(); gazeYMotion.complete(); openMotion.complete(); smileMotion.complete(); droopMotion.complete()
        highlightXMotion.complete(); highlightYMotion.complete()
        lid = 1; hop = 0; tilt = 0; squash = 1; cheerful = false
    }
    // A gesture or the stretch of a wake-up is running; the context holds the greeting back.
    readonly property bool momentActive: gesture !== "" || wakeMotion.running
    onMomentActiveChanged: if (context) context.noteMoment(momentActive)
    Component.onDestruction: if (momentActive && context) context.noteMoment(false)
    onSuspendedChanged: if (suspended) settle()
    onReducedChanged: if (reduced) settle()
    onVisibleChanged: if (!visible) settle()
    onMoodChanged: {
        if (mood === "finished") { if (gesture !== "relief") celebrate() }
        else if (mood === "received" || mood === "connected") nod()
        else if (mood !== "rest") greet()
    }
    onAsleepChanged: {
        if (asleep) { sleptAt = Date.now(); settle(); play("yawn"); return }
        wakeAfter(Date.now() - sleptAt)
    }
    onListeningChanged: if (listening && !reduced && !asleep && !suspended && visible) {
        cheerful = true
        cheerHold.restart()
        sway()
    }

    Connections {
        target: root.context
        function onGestureRequested(kind) { root.play(kind) }
        function onSettleRequested() { root.settle() }
    }
    onConcentratingChanged: if (concentrating) greet()
    Behavior on highlightX { enabled: !root.reduced && !root.suspended && root.visible; SmoothedAnimation { id: highlightXMotion; duration: 380; velocity: -1 } }
    Behavior on highlightY { enabled: !root.reduced && !root.suspended && root.visible; SmoothedAnimation { id: highlightYMotion; duration: 380; velocity: -1 } }
    Behavior on open { enabled: !root.reduced && !root.suspended && root.visible; SpringAnimation { id: openMotion; spring: 5; damping: 0.42; epsilon: 0.005 } }
    Behavior on smile { enabled: !root.reduced && !root.suspended && root.visible; SpringAnimation { id: smileMotion; spring: 5; damping: 0.5; epsilon: 0.005 } }
    Behavior on droop { enabled: !root.reduced && !root.suspended && root.visible; NumberAnimation { id: droopMotion; duration: 520; easing.type: Easing.InOutSine } }
    Behavior on gazeX { enabled: !root.visitorOwnsGaze && !root.reduced && !root.suspended && root.visible; SpringAnimation { id: gazeXMotion; spring: 4; damping: 0.4; epsilon: 0.01 } }
    Behavior on gazeY { enabled: !root.visitorOwnsGaze && !root.reduced && !root.suspended && root.visible; SpringAnimation { id: gazeYMotion; spring: 4; damping: 0.4; epsilon: 0.01 } }
    Behavior on touchDirection { enabled: root.interactive; SmoothedAnimation { id: directionMotion; duration: 180; velocity: -1 } }
    Behavior on touch { id: touchBehavior; enabled: root.interactive; SmoothedAnimation { id: touchMotion; duration: 220; velocity: -1 } }
    Timer { id: touchRelease; interval: 260; onTriggered: root.touchTarget = 0 }
    Timer { id: tickleCooldown; interval: 1800 }
    Timer { id: approach; interval: 750; onTriggered: if (root.interactive && root.pointerOver && root.gesture === "") root.play("curious") }
    Timer { id: linger; interval: 850; onTriggered: root.lingering = false }
    Timer { id: cooldown; interval: 2400 }
    Timer { id: cheerHold; interval: 1800; onTriggered: root.cheerful = false }

    SequentialAnimation {
        id: blink
        NumberAnimation { target: root; property: "lid"; to: 0.12; duration: 70 }
        NumberAnimation { target: root; property: "lid"; to: 1; duration: root.concentrating ? 340 : 150; easing.type: Easing.OutCubic }
        PauseAnimation { duration: 110 }
        NumberAnimation { target: root; property: "lid"; to: root.mood === "attention" ? 0.12 : 1; duration: 65 }
        NumberAnimation { target: root; property: "lid"; to: 1; duration: 160; easing.type: Easing.OutCubic }
    }
    // A rare night moment: trying to stay awake, then giving in to a yawn.
    SequentialAnimation {
        id: dozeMotion
        NumberAnimation { target: root; property: "lowerLid"; to: 0.65; duration: 360; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "lowerLid"; to: 0; duration: 180; easing.type: Easing.OutCubic }
        PauseAnimation { duration: 180 }
        ScriptAction { script: root.play("yawn") }
    }
    // A false start, a held sneeze, then a quiet, self-satisfied wink.
    SequentialAnimation {
        id: heldSneeze
        ParallelAnimation {
            NumberAnimation { target: root; property: "lowerLid"; to: 0.45; duration: 360; easing.type: Easing.InOutSine }
            NumberAnimation { target: root; property: "breath"; to: 1.06; duration: 360; easing.type: Easing.InOutSine }
            NumberAnimation { target: root; property: "tilt"; to: -6; duration: 360; easing.type: Easing.InOutSine }
        }
        PauseAnimation { duration: 220 }
        ParallelAnimation {
            NumberAnimation { target: root; property: "lowerLid"; to: 0.7; duration: 160; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "squash"; to: 0.92; duration: 160; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "tilt"; to: 3; duration: 160; easing.type: Easing.OutCubic }
        }
        PauseAnimation { duration: 180 }
        ParallelAnimation {
            NumberAnimation { target: root; properties: "breath,squash"; to: 1; duration: 400; easing.type: Easing.InOutSine }
            NumberAnimation { target: root; properties: "lowerLid,tilt"; to: 0; duration: 400; easing.type: Easing.InOutSine }
            NumberAnimation { target: root; property: "winkLid"; to: 0.08; duration: 220; easing.type: Easing.InOutSine }
        }
        PauseAnimation { duration: 180 }
        NumberAnimation { target: root; property: "winkLid"; to: 1; duration: 240; easing.type: Easing.OutCubic }
        ScriptAction { script: root.gesture = "" }
    }
    // A visitor crosses once; its duration and shape come from Visitors.js. The sighting
    // is noted only when the scene was seen to the end.
    SequentialAnimation {
        id: visitorMotion
        NumberAnimation { target: root; property: "visitProgress"; from: 0; to: 1; duration: root.visitorSpec.duration; easing.type: Easing.InOutSine }
        ScriptAction { script: root.finishVisit() }
    }
    // One exclusive finite moment: anticipation, expression, then release.
    SequentialAnimation {
        id: specialMotion
        ParallelAnimation {
            NumberAnimation { target: root; property: "squash"; to: root.gesture === "sneeze" ? 1.12 : 0.94; duration: 140; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "breath"; to: 1.035; duration: 140 }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "winkLid"; to: root.gesture === "wink" ? 0.08 : 1; duration: 140; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "lowerLid"; to: root.gesture === "yawn" ? 0.7 : root.squinting ? 0.4 : 0; duration: 220 }
            NumberAnimation { target: root; property: "tilt"; to: root.gesture === "curious" ? -9 : root.gesture === "stretch" ? -5 : root.gesture === "sneeze" ? 7 : 0; duration: 240; easing.type: Easing.OutBack }
            NumberAnimation { target: root; property: "roll"; to: root.gesture === "roll" ? 1 : 0; duration: 280; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "squash"; to: root.gesture === "yawn" || root.gesture === "stretch" ? 1.18 : root.gesture === "sneeze" ? 0.76 : 1.04; duration: 240; easing.type: Easing.OutBack }
        }
        PauseAnimation { duration: root.gesture === "yawn" ? 400 : 170 }
        ParallelAnimation {
            NumberAnimation { target: root; properties: "winkLid,squash,breath"; to: 1; duration: 380; easing.type: Easing.OutBack }
            NumberAnimation { target: root; properties: "lowerLid,tilt,roll"; to: 0; duration: 380; easing.type: Easing.OutCubic }
        }
        ScriptAction { script: root.gesture = "" }
    }
    // The day's first greeting: a slow blink, then a smile that lasts about 2.2 s
    // (3.6 s when Iris has not seen you for a long while), then back to rest.
    SequentialAnimation {
        id: welcomeMotion
        NumberAnimation { target: root; property: "lid"; to: 0.12; duration: 220; easing.type: Easing.InOutSine }
        ScriptAction { script: root.glad = true }
        ParallelAnimation {
            NumberAnimation { target: root; property: "lid"; to: 1; duration: 260; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "squash"; to: 1.05; duration: 260; easing.type: Easing.OutBack }
        }
        PauseAnimation { duration: (root.gesture === "welcomeBack" ? 3600 : 2200) - 640 }
        NumberAnimation { target: root; property: "squash"; to: 1; duration: 380; easing.type: Easing.OutBack }
        ScriptAction { script: { root.glad = false; root.gesture = "" } }
    }
    // An unusual hour: eyes open wide with a tilt, one blink, then rest.
    SequentialAnimation {
        id: surprisedMotion
        ParallelAnimation {
            NumberAnimation { target: root; property: "tilt"; to: -7; duration: 240; easing.type: Easing.OutBack }
            PauseAnimation { duration: 420 }
        }
        NumberAnimation { target: root; property: "lid"; to: 0.12; duration: 70 }
        NumberAnimation { target: root; property: "lid"; to: 1; duration: 150; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "tilt"; to: 0; duration: 380; easing.type: Easing.OutCubic }
        ScriptAction { script: root.gesture = "" }
    }
    // The gaze swings twice, each swing smaller than the last. A refused password ("no")
    // lowers the lid a little and holds; the dust of a long sleep ("dust") is shorter and
    // gentler, then blinks the dust away and yawns.
    readonly property real shakeAmp: gesture === "dust" ? 0.5 : 1
    readonly property int shakeStep: gesture === "dust" ? 100 : 120
    SequentialAnimation {
        id: shakeMotion
        ScriptAction { script: root.wary = root.gesture === "no" }
        NumberAnimation { target: root; property: "shake"; to: root.shakeAmp; duration: root.shakeStep; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "shake"; to: -root.shakeAmp; duration: root.shakeStep; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "shake"; to: root.shakeAmp / 2; duration: root.shakeStep; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "shake"; to: -root.shakeAmp / 2; duration: root.shakeStep; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "shake"; to: 0; duration: root.shakeStep; easing.type: Easing.InOutSine }
        ScriptAction { script: if (root.gesture === "dust") blink.restart() }
        PauseAnimation { duration: root.gesture === "dust" ? 560 : 360 }
        ScriptAction { script: root.finishShake() }
    }
    // A capture ended: a slow blink and an exhale.
    SequentialAnimation {
        id: reliefMotion
        ParallelAnimation {
            NumberAnimation { target: root; property: "lid"; to: 0.12; duration: 220; easing.type: Easing.InOutSine }
            NumberAnimation { target: root; property: "squash"; to: 0.94; duration: 220; easing.type: Easing.OutCubic }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "lid"; to: 1; duration: 260; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "squash"; to: 1; duration: 380; easing.type: Easing.OutBack }
        }
        ScriptAction { script: root.gesture = "" }
    }
    // Something finished: two hops with anticipation, the only celebration.
    SequentialAnimation {
        id: celebration
        loops: 2
        NumberAnimation { target: root; property: "squash"; to: 0.86; duration: 70; easing.type: Easing.OutQuad }
        ParallelAnimation {
            NumberAnimation { target: root; property: "squash"; to: 1.06; duration: 140; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "hop"; to: -3.4 * root.s; duration: 160; easing.type: Easing.OutQuad }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "hop"; to: 0; duration: 170; easing.type: Easing.InQuad }
            NumberAnimation { target: root; property: "squash"; to: 0.9; duration: 170; easing.type: Easing.InQuad }
        }
        NumberAnimation { target: root; property: "squash"; to: 1; duration: 160; easing.type: Easing.OutBack }
    }
    // A song starts: two decaying sways, then still.
    SequentialAnimation {
        id: swayMotion
        NumberAnimation { target: root; property: "tilt"; to: 8; duration: 260; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "tilt"; to: -6; duration: 420; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "tilt"; to: 4; duration: 400; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "tilt"; to: 0; duration: 380; easing.type: Easing.InOutSine }
    }
    // Being stroked: it melts a little.
    SequentialAnimation {
        id: patMotion
        NumberAnimation { target: root; property: "squash"; to: 0.84; duration: 160; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "squash"; to: 1; duration: 420; easing.type: Easing.OutBack }
        ScriptAction { script: root.gesture = "" }
    }
    // Coming back after the user returns: eyes open wide, then blink.
    SequentialAnimation {
        id: wakeMotion
        NumberAnimation { target: root; property: "squash"; to: 1.1; duration: 180; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "squash"; to: 1; duration: 260; easing.type: Easing.OutBack }
        PauseAnimation { duration: 120 }
        ScriptAction { script: { cooldown.stop(); root.greet() } }
    }

    Item {
        id: visitor
        objectName: "companionVisitor"
        readonly property var spec: root.visitorSpec
        readonly property color tone: Theme[spec.color]
        visible: root.visiting && opacity > 0.001
        opacity: root.visitPresence
        width: Math.max(spec.halo, spec.w, spec.h) * root.s; height: width
        x: root.visitorX - width / 2; y: root.visitorY - height / 2
        // A bubble bursts over its last eighth: it swells as the envelope fades it out.
        scale: spec.pop ? 1 + 0.6 * Math.max(0, (root.visitProgress - 0.875) * 8) : 1
        rotation: spec.flutter * Math.sin(root.visitProgress * Math.PI * 24)
        Rectangle {
            anchors.centerIn: parent
            visible: visitor.spec.halo > 0
            width: visitor.spec.halo * root.s; height: width; radius: width / 2
            color: Qt.alpha(visitor.tone, visitor.spec.haloAlpha)
        }
        Rectangle {
            anchors.centerIn: parent
            width: visitor.spec.w * root.s; height: visitor.spec.h * root.s
            radius: Math.min(width, height) / 2
            color: visitor.spec.ring > 0 ? "transparent" : visitor.tone
            border.width: visitor.spec.ring * root.s
            border.color: visitor.tone
        }
    }
    Item {
        id: face
        anchors.fill: parent
        transform: [
            Scale { origin.x: face.width / 2; origin.y: face.height / 2; xScale: root.materialScaleX; yScale: root.materialScaleY },
            Scale { origin.x: face.width / 2; origin.y: face.height * 0.8; xScale: 1 / Math.sqrt(root.squash); yScale: root.squash * root.breath },
            Rotation { origin.x: face.width / 2; origin.y: face.height; angle: root.tilt + root.touchDirection * root.touch * 5 },
            Translate { x: root.materialX; y: root.hop + root.restDrop + root.materialY }
        ]
        Repeater {
            model: 2
            Item {
                id: eye
                required property int index
                readonly property real eyeW: (5.8 + 1.2 * Math.max(0, 1 - root.eyeOpening)) * root.s
                x: (index === 0 ? 9.5 : 20.5) * root.s + root.gazeX + root.shake * 3 * root.s + Math.sin(root.roll * Math.PI) * 1.5 * root.s - width / 2
                y: root.height / 2 + root.gazeY - root.roll * 1.2 * root.s - 5 * root.s
                width: 7 * root.s; height: 10 * root.s
                // Open eye: a capsule whose height is the openness, closing toward a line.
                // The mask cuts its top flat when the lid droops.
                Item {
                    id: lidMask
                    readonly property real fullH: Math.max(1.7 * root.s, 10 * root.s * root.eyeOpening * root.lid * (eye.index === 0 ? root.winkLid : 0.96))
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: eye.eyeW
                    height: Math.max(1.7 * root.s, fullH * Math.max(0, 1 - root.droop - root.lowerLid))
                    y: parent.height / 2 - fullH / 2 + fullH * root.droop
                    clip: true
                    opacity: 1 - root.smile
                    visible: opacity > 0.01
                    Rectangle {
                        y: -lidMask.fullH * root.droop
                        width: parent.width
                        height: lidMask.fullH
                        radius: Math.min(width, height) / 2
                        antialiasing: true
                        color: root.mood === "attention" && root.awake ? Theme.accentStrong : root.eyeColor
                        Rectangle {
                            objectName: "companionPupil"
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: root.highlightX
                            anchors.verticalCenterOffset: root.highlightY - root.beat * 0.7 * root.s
                            width: (Theme.dark ? 1.9 : 1.6) * root.s; height: width * (1 + root.beat * 0.18)
                            radius: width / 2
                            color: root.recordingAware ? Theme.error : Theme.surface
                            opacity: root.recordingAware ? 0.85 : 0.5
                            Behavior on color { enabled: !root.reduced; ColorAnimation { duration: 220 } }
                            visible: root.open > 0.4 && !root.asleep && root.lid > 0.5
                        }
                    }
                }
                // Smiling eye: an arc with round caps, read as ∩.
                Shape {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height / 2 - 2.6 * root.s + (1 - root.smile) * 1.5 * root.s
                    width: 7.2 * root.s; height: 3.6 * root.s
                    preferredRendererType: Shape.CurveRenderer
                    opacity: root.smile
                    visible: opacity > 0.01
                    rotation: eye.index === 0 ? -7 : 7
                    transform: Scale { origin.y: 1.7 * root.s; yScale: eye.index === 0 ? root.winkLid : 1 }
                    ShapePath {
                        strokeColor: root.smiling ? Qt.tint(root.eyeColor, Qt.alpha(Theme.accent, 0.28)) : root.eyeColor
                        strokeWidth: 1.9 * root.s
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        startX: 0.95 * root.s; startY: 3.2 * root.s
                        PathArc { x: 6.25 * root.s; y: 3.2 * root.s; radiusX: 2.7 * root.s; radiusY: 2.7 * root.s }
                    }
                }
            }
        }
    }
}
