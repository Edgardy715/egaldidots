import QtQuick
import "../Singletons/Visitors.js" as Visitors

// Event policy lives in composition; the face only receives data and moments.
Item {
    id: root
    property bool active: false
    property bool reduced: false
    property bool asleep: false
    property bool blocked: false
    property bool night: false
    property bool codeFocused: false
    property bool musicVisible: false
    property bool playing: false
    property real seek: 0.5
    property real beat: 0
    property real workspaceLook: 0
    property real memoryPlayfulness: 1      // slow mood from IrisMemory, 0.6..1.6
    property bool greetingPending: false    // a first-of-day greeting awaits its screen
    property bool recording: false          // a capture is engaged: the face keeps a red glint
    property bool batteryLow: false         // laptop battery at 15 % or less and discharging
    property string batteryKind: ""         // last battery state seen: discharging, charging, paused or full
    property string deferredGesture: ""     // a system gesture waiting for the face to be seen
    property bool focusActive: false        // the open surface has a point of interest
    property real focusX: 0                 // that point as a vector from the face, saturated to -1..1
    property real focusY: 0
    property bool pointerInside: false
    property real pointerX: 0
    property real pointerY: 0
    property var options: ({followPointer: true, reactToCode: true, reactToMusic: true, reactAtNight: true, reactToSystem: true, followFocus: true, mischief: "rare"})
    readonly property var traits: ({ reactionDelay: 260, curiosity: 0.65, nightChance: 0.10, mischiefInterval: 600000 })
    readonly property bool running: active && !reduced && !asleep
    readonly property bool canReact: !!options.reactToSystem && !reduced && !asleep
    readonly property bool tired: !!options.reactToSystem && batteryLow
    readonly property bool recordingAware: !!options.reactToSystem && recording
    readonly property bool followingFocus: running && focusActive && !!options.followFocus
    property int busyFaces: 0               // faces mid-gesture (see noteMoment)
    readonly property bool greetingReady: running && !blocked && greetingPending && busyFaces === 0
    readonly property bool concentrating: running && !!options.reactToCode && codeFocused && !pointerInside
    // A point of interest wins over the pointer; without one the pointer leads.
    readonly property real lookX: !running ? 0 : followingFocus ? Math.max(-1, Math.min(1, focusX))
        : pointerInside && options.followPointer ? sampledX
        : workspaceLook !== 0 ? workspaceLook * traits.curiosity
        : musicVisible && playing && options.reactToMusic ? seek * 2 - 1 : 0
    readonly property real lookY: !running ? 0 : followingFocus ? Math.max(-1, Math.min(1, focusY))
        : pointerInside && options.followPointer ? sampledY : concentrating ? 0.65 : 0
    readonly property real pupilBeat: running && musicVisible && playing && options.reactToMusic ? Math.max(0, Math.min(1, beat)) : 0
    property real sampledX: 0
    property real sampledY: 0
    property double lastMischief: 0
    property double lastYawn: 0
    signal gestureRequested(string kind)
    signal settleRequested()
    signal interacted()
    signal visited(string kind)            // a visitor scene played to its end
    signal greetingRequested()
    onBlockedChanged: if (blocked) settleRequested()
    onCanReactChanged: if (!canReact) deferredGesture = ""
    // Real, discrete system events. "now" needs a free, visible face; "defer" waits for
    // it (only a critical notification is worth waiting for); "surface" is for events of
    // the surface that blocks the idle gestures itself, such as a failed password.
    function react(kind, mode) {
        if (!canReact) return false
        if (running && (!blocked || mode === "surface")) { gestureRequested(kind); return true }
        if (mode === "defer") deferredGesture = kind
        return false
    }
    function noteBattery(percent, status) {
        const kind = status === "charging" && percent >= 100 ? "full" : status
        const was = batteryKind
        batteryKind = kind
        batteryLow = status === "discharging" && percent <= 15
        if (!was || was === kind) return
        if (kind === "full") react("stretch")
        else if (kind === "charging" && was !== "full") react("content")
    }
    // Faces report when a gesture starts and ends; the greeting waits for all of them.
    function noteMoment(active) { busyFaces = Math.max(0, busyFaces + (active ? 1 : -1)) }
    function samplePointer() {
        sampledX = pointerInside ? pointerX : 0
        sampledY = pointerInside ? pointerY : 0
    }
    function queuePointer() { if (running && options.followPointer && !pointerDelay.running) pointerDelay.start() }
    function greet(kind) {
        const gesture = ({ "habitual": "welcome", "unusual": "surprised", "return": "welcomeBack" })[kind]
        if (gesture) gestureRequested(gesture)
    }
    function tryMischief(now, chance) {
        if (!running || blocked || options.mischief === "never" || now - lastMischief < traits.mischiefInterval) return false
        // A warmer Iris is slightly more playful: the roll shrinks, the interval does not.
        const roll = chance / memoryPlayfulness
        if (roll >= (options.mischief === "normal" ? 0.28 : 0.08)) return false
        lastMischief = now
        // The slot once reserved for the firefly now belongs to the visitors that suit the clock.
        gestureRequested(roll < 0.0125 ? Visitors.pick(new Date(now), roll / 0.0125) : roll < 0.025 ? "holdSneeze" : roll < 0.05 ? "roll" : "wink")
        return true
    }
    function tryYawn(now, chance) {
        if (!running || blocked || !night || !options.reactAtNight || now - lastYawn < 120000 || chance >= traits.nightChance) return false
        lastYawn = now
        gestureRequested(chance < 0.025 ? "doze" : "yawn")
        return true
    }
    onPointerXChanged: queuePointer()
    onPointerYChanged: queuePointer()
    onPointerInsideChanged: queuePointer()
    onRunningChanged: if (!running) { pointerDelay.stop(); sampledX = 0; sampledY = 0 }
    // The greeting follows once every face has finished its wake-up (dust, yawn, stretch);
    // this short beat only lets a gesture that starts with the wake claim the face first.
    Timer { interval: 300; running: root.greetingReady; onTriggered: root.greetingRequested() }
    Timer {
        interval: 600; running: root.deferredGesture !== "" && root.running && !root.blocked
        onTriggered: { const kind = root.deferredGesture; root.deferredGesture = ""; root.gestureRequested(kind) }
    }
    Timer { id: pointerDelay; interval: root.traits.reactionDelay; onTriggered: root.samplePointer() }
    Timer {
        interval: 120000; repeat: true
        running: root.running && !root.blocked && root.night && root.options.reactAtNight
        onTriggered: root.tryYawn(Date.now(), Math.random())
    }
    Timer {
        interval: root.traits.mischiefInterval; repeat: true
        running: root.running && !root.blocked && root.options.mischief !== "never"
        onTriggered: root.tryMischief(Date.now(), Math.random())
    }
}
