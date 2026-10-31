pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "Visitors.js" as Visitors

// Iris' slow memory: at which hours the day usually begins, and how warm the
// relationship is. Only an hour histogram and two numbers are stored, in a file
// apart from shell.json. Nothing here polls: the file is read the first time
// something is noted, saved once after a quiet debounce, and warmth fades by
// arithmetic on the last-seen timestamp rather than by a timer.
Singleton {
    id: root

    readonly property string file: Quickshell.env("ISLA_IRIS") || Config.configHome + "/isla/iris.json"
    readonly property bool enabled: Config.companion.remember
    readonly property real playfulness: enabled ? 0.6 + warmth : 1
    // "" | "habitual" | "unusual" | "return"; pending until consumeGreeting().
    readonly property string greetingKind: enabled ? _greeting : ""

    property var hours: new Array(24).fill(0)  // first-activity-of-day counts per hour, 0..99
    property int days: 0                        // days with a first activity, 0..365
    property string lastDay: ""                 // local YYYY-MM-DD of the last first activity
    property double lastSeen: 0                 // ms of the last noted activity
    property real warmth: 0.4                   // 0..1; 0.4 makes playfulness neutral
    property var sightings: ({})                // visitor kind -> times seen to the end, 1..99
    property bool loaded: false

    property bool _wanted: false                // something asked for memory: read lazily
    property bool _activityPending: false       // noteActivity() arrived before the file did
    property bool _writable: true
    property string _greeting: ""
    property string _saveText: ""

    function noteActivity() {
        if (!enabled) return
        _wanted = true
        if (!loaded) _activityPending = true
        else _applyActivity(Date.now())
    }

    function noteInteraction() {
        if (!enabled) return
        _wanted = true
        if (!loaded) return
        _age(Date.now())
        warmth = Math.min(1, warmth + 0.04)
        saveTimer.restart()
    }

    function noteSighting(kind) {
        if (!enabled || !Visitors.has(kind)) return
        _wanted = true
        if (!loaded) return
        sightings = Visitors.sanitize(Object.assign({}, sightings, { [kind]: (sightings[kind] || 0) + 1 }))
        saveTimer.restart()
    }

    // Hands the greeting to exactly one caller, whichever screen asks first.
    function consumeGreeting() {
        const kind = greetingKind
        _greeting = ""
        return kind
    }

    function save() {
        if (!enabled || !loaded || !_writable) return
        if (mkdir.running) { saveTimer.restart(); return }
        _saveText = JSON.stringify({ hours: hours, days: days, lastDay: lastDay, lastSeen: lastSeen, warmth: warmth, sightings: sightings }) + "\n"
        mkdir.running = true
    }

    // Warmth fades 0.015 per hour away; lastSeen moves to now.
    function _age(now) {
        const away = lastSeen > 0 ? Math.max(0, now - lastSeen) : 0
        warmth = Math.max(0, warmth - 0.015 * away / 3600000)
        lastSeen = now
        return away
    }

    function _applyActivity(now) {
        const away = _age(now)
        const date = new Date(now)
        const day = Qt.formatDate(date, "yyyy-MM-dd")
        if (day !== lastDay) {
            const hour = date.getHours()
            _greeting = away > 36 * 3600000 ? "return" : _classify(hour)
            // A new day ages the histogram a little so habits can change.
            const next = hours.map(count => Math.round(count * 0.95))
            next[hour] = Math.min(99, next[hour] + 1)
            hours = next
            days = Math.min(365, days + 1)
            lastDay = day
        }
        saveTimer.restart()
    }

    // Judged against the history before today's contribution.
    function _classify(hour) {
        const peak = Math.max(...hours)
        if (days < 5 || peak <= 0) return "habitual"
        const nearby = Math.max(hours[hour], hours[(hour + 23) % 24], hours[(hour + 1) % 24])
        return nearby >= peak * 0.25 ? "habitual" : "unusual"
    }

    function _accept(text) {
        let data = {}
        try { data = JSON.parse(text) } catch (exception) { console.warn("[Isla Iris] ignoring unreadable memory: " + exception) }
        if (!data || typeof data !== "object") data = {}
        const count = value => Math.max(0, Math.min(99, Math.round(Number(value)) || 0))
        hours = Array.from({ length: 24 }, (unused, hour) => count(Array.isArray(data.hours) ? data.hours[hour] : 0))
        days = Math.max(0, Math.min(365, Math.round(Number(data.days)) || 0))
        lastDay = /^\d{4}-\d{2}-\d{2}$/.test(data.lastDay) ? data.lastDay : ""
        lastSeen = Math.max(0, Number(data.lastSeen) || 0)
        warmth = typeof data.warmth === "number" && Number.isFinite(data.warmth) ? Math.max(0, Math.min(1, data.warmth)) : 0.4
        sightings = Visitors.sanitize(data.sightings)
        loaded = true
        if (_activityPending) {
            _activityPending = false
            _applyActivity(Date.now())
        }
    }

    onEnabledChanged: if (!enabled) {
        saveTimer.stop()
        _activityPending = false
        _greeting = ""
        loaded = false
    }

    Timer { id: saveTimer; interval: 2500; onTriggered: root.save() }

    Process {
        id: mkdir
        command: ["mkdir", "-p", "--", root.file.slice(0, root.file.lastIndexOf("/")) || "."]
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0 && exitStatus === 0 && root.enabled) store.setText(root._saveText)
        }
    }

    FileView {
        id: store
        path: root._wanted && root.enabled ? root.file : ""
        atomicWrites: true
        printErrors: false
        onLoaded: root._accept(store.text())
        onLoadFailed: function(reason) {
            // Absence is a fresh start; any other failure must not overwrite the file.
            if (reason !== FileViewError.FileNotFound) {
                root._writable = false
                console.warn("[Isla Iris] cannot read " + root.file)
            }
            root._accept("{}")
        }
    }
}
