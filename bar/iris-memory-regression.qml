import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "components"
import "Singletons"

// Run with temporary ISLA_CONFIG and ISLA_IRIS (a path whose directory does not exist yet).
ShellRoot {
    settings.watchFiles: false
    Window {
        id: window
        visible: true
        width: 360; height: 160
        title: "Isla · Iris · memoria · prueba"
        color: Theme.surface
        CompanionBehavior { id: policy; active: true }
        IslandActivityChip { id: chip; x: 40; y: 60; s: 2; coreH: 38 * s; companionContext: policy }
        FileView { id: reader; blockLoading: true; printErrors: false }
        FileView { id: writer; blockWrites: true; atomicWrites: false; printErrors: false }
        SignalSpy { id: greetings; target: policy; signalName: "greetingRequested" }
        QtObject { id: probe; property var face: null; property string atGreeting: ""; property int busyAtGreeting: -1 }
        Connections {
            target: policy
            function onGreetingRequested() { if (probe.face) { probe.atGreeting = probe.face.gesture; probe.busyAtGreeting = policy.busyFaces } }
        }
        SignalSpy { id: touches; target: policy; signalName: "interacted" }
        Timer { id: exitTimer; interval: 120; onTriggered: Qt.quit() }
        TestCase {
            name: "IrisMemory"
            when: Config.loaded && window.visible
            readonly property int hour: new Date().getHours()
            readonly property double hourMs: 3600000
            function check(ok, message) { if (!ok) throw new Error(message) }
            function stored() { reader.path = IrisMemory.file; reader.reload(); reader.waitForJob(); return reader.text() }
            // Fabricates history that ended `ago` hours back, on an earlier day.
            function remember(days, peakHour, ago) {
                const hours = new Array(24).fill(0)
                hours[peakHour] = 40
                IrisMemory.hours = hours
                IrisMemory.days = days
                IrisMemory.lastDay = "2000-01-01"
                IrisMemory.lastSeen = Date.now() - ago * hourMs
            }
            function greeting() { IrisMemory.noteActivity(); return IrisMemory.consumeGreeting() }
            function still(face) {
                return face.gesture === "" && !face.glad && face.lid === 1 && face.winkLid === 1 && face.lowerLid === 0
                    && face.breath === 1 && face.squash === 1 && face.tilt === 0
            }
            function test_memoryAndGestures() {
                try {
                    Config.update({appearance: {reduceMotion: false}, companion: {remember: true}})
                    // Absent file: lazy, fresh start, neutral greeting, one consumer only.
                    check(!IrisMemory.loaded && IrisMemory.greetingKind === "", "nothing is read before it is needed")
                    IrisMemory.noteActivity()
                    tryVerify(() => IrisMemory.loaded, 3000, "absent file loads as a fresh start")
                    check(IrisMemory.days === 1 && IrisMemory.lastDay.length === 10, "first day recorded: " + IrisMemory.days)
                    check(IrisMemory.hours.reduce((a, b) => a + b, 0) === 1 && IrisMemory.hours[hour] === 1, "first activity lands in this hour")
                    check(IrisMemory.greetingKind === "habitual", "a new Iris greets neutrally")
                    check(IrisMemory.consumeGreeting() === "habitual" && IrisMemory.consumeGreeting() === "" && IrisMemory.greetingKind === "", "greeting is consumed once")
                    IrisMemory.noteActivity()
                    check(IrisMemory.greetingKind === "" && IrisMemory.days === 1, "later activity the same day is silent")
                    IrisMemory.save()
                    tryVerify(() => { try { return stored().indexOf('"days":1') >= 0 } catch (e) { return false } }, 3000, "memory file written with mkdir")
                    const saved = JSON.parse(stored())
                    check(saved.hours.length === 24 && saved.lastDay === IrisMemory.lastDay && saved.warmth === IrisMemory.warmth, "saved fields")
                    // Classification with fabricated history.
                    remember(10, hour, 3)
                    check(greeting() === "habitual", "usual hour is habitual")
                    remember(10, (hour + 1) % 24, 3)
                    check(greeting() === "habitual", "adjacent hour counts as habitual")
                    remember(10, (hour + 6) % 24, 3)
                    check(greeting() === "unusual", "distant hour is unusual")
                    remember(3, (hour + 6) % 24, 3)
                    check(greeting() === "habitual", "fewer than five days stays neutral")
                    remember(10, (hour + 6) % 24, 40)
                    check(greeting() === "return", "more than 36 h away is a return")
                    remember(10, (hour + 6) % 24, 35)
                    check(greeting() !== "return", "35 h away is not a return")
                    // Slow mood and histogram ageing.
                    remember(365, hour, 10)
                    IrisMemory.warmth = 0.5
                    IrisMemory.noteActivity()
                    check(Math.abs(IrisMemory.warmth - 0.35) < 0.002, "warmth fades 0.015 per hour away: " + IrisMemory.warmth)
                    check(IrisMemory.days === 365 && IrisMemory.hours[hour] === 39, "days capped, buckets aged 0.95 then incremented: " + IrisMemory.hours[hour])
                    IrisMemory.warmth = 0.98
                    IrisMemory.noteInteraction(); IrisMemory.noteInteraction()
                    check(IrisMemory.warmth === 1 && Math.abs(IrisMemory.playfulness - 1.6) < 1e-9, "warmth is capped and drives playfulness")
                    IrisMemory.warmth = 0
                    check(Math.abs(IrisMemory.playfulness - 0.6) < 1e-9, "playfulness floor")
                    IrisMemory.warmth = 0.4
                    // remember=false: inert, reads and writes nothing, deletes nothing.
                    IrisMemory.save()
                    tryVerify(() => stored().indexOf('"days":365') >= 0, 3000, "state saved before opting out")
                    const before = stored()
                    Config.update({companion: {remember: false}})
                    check(!IrisMemory.loaded && IrisMemory.greetingKind === "" && IrisMemory.playfulness === 1, "opt-out resets the surface")
                    IrisMemory.days = 77
                    IrisMemory.noteActivity(); IrisMemory.noteInteraction(); IrisMemory.save()
                    wait(3000)
                    check(stored() === before && IrisMemory.greetingKind === "" && !IrisMemory.loaded, "opt-out neither reads nor writes")
                    check(IrisMemory.consumeGreeting() === "", "opt-out never greets")
                    Config.update({companion: {remember: true}})

                    // Hostile file contents: a valid-but-empty value, a broken file and a null warmth.
                    for (const sample of [
                        {text: "null", days: 1, label: "JSON null"},
                        {text: "{broken", days: 1, label: "unparseable JSON"},
                        {text: '{"warmth": null, "days": 3}', days: 4, label: "null warmth"}]) {
                        Config.update({companion: {remember: false}})
                        writer.path = IrisMemory.file
                        writer.setText(sample.text)
                        Config.update({companion: {remember: true}})
                        IrisMemory.noteActivity()
                        tryVerify(() => IrisMemory.loaded, 3000, sample.label + " loads")
                        check(IrisMemory.warmth === 0.4 && IrisMemory.days === sample.days, sample.label + " falls back to defaults: " + IrisMemory.warmth + "," + IrisMemory.days)
                        check(IrisMemory.hours.length === 24 && IrisMemory.lastDay.length === 10, sample.label + " keeps a valid shape")
                        if (sample.text === "{broken") check(stored() === "{broken", "an unparseable file is not overwritten by loading it")
                        IrisMemory.consumeGreeting()
                    }
                    Config.update({companion: {remember: false}})
                    writer.setText("{}")
                    Config.update({companion: {remember: true}})
                    IrisMemory.noteActivity()
                    tryVerify(() => IrisMemory.loaded, 3000)

                    // Iris' face: interaction signal, greeting policy, mood-scaled mischief.
                    const face = findChild(chip, "activityCompanion")
                    mouseMove(window.contentItem, 5, 5)
                    wait(300)
                    face.interact(); face.pat(); face.stroke(120, 1, 0.5); face.stroke(120, 1, 0.5)
                    check(touches.count === 3, "click, pat and one stroke are interactions: " + touches.count)
                    face.settle(); wait(300)
                    policy.greetingPending = true
                    wait(100)
                    check(greetings.count === 0, "greeting waits a beat for the face to claim the wake-up")
                    wait(400)
                    check(greetings.count === 1, "greeting is requested once the face is free")
                    policy.greetingPending = false
                    policy.blocked = true; policy.greetingPending = true
                    wait(1500)
                    check(greetings.count === 1, "a blocked island does not greet")
                    policy.greetingPending = false; policy.blocked = false

                    // Waking after half an hour with a greeting pending: dust, the whole yawn, then the greeting.
                    policy.asleep = true; face.asleep = true
                    wait(300)
                    face.settle()
                    face.sleptAt = Date.now() - 31 * 60000
                    const greetedBefore = greetings.count
                    probe.face = face; probe.atGreeting = "unset"; probe.busyAtGreeting = -1
                    policy.greetingPending = true
                    policy.asleep = false; face.asleep = false
                    const seen = []
                    for (let i = 0; i < 200 && greetings.count === greetedBefore; i++) {
                        wait(40)
                        if (seen[seen.length - 1] !== face.gesture) seen.push(face.gesture)
                    }
                    check(greetings.count === greetedBefore + 1, "the long-sleep greeting is requested")
                    const dustAt = seen.indexOf("dust"), yawnAt = seen.indexOf("yawn")
                    check(dustAt >= 0 && yawnAt > dustAt, "dust and the full yawn come first: " + seen.join(">"))
                    check(probe.atGreeting === "" && probe.busyAtGreeting === 0, "the greeting finds a free face: " + probe.atGreeting + "," + probe.busyAtGreeting)
                    policy.greetingPending = false
                    face.settle()
                    check(policy.busyFaces === 0, "no face is left counted as busy: " + policy.busyFaces)
                    policy.lastMischief = 0
                    check(!policy.tryMischief(700000, 0.12), "neutral mood: 12 % roll is no mischief")
                    policy.memoryPlayfulness = 1.6
                    check(policy.tryMischief(700000, 0.12), "playful mood widens the window slightly")
                    policy.memoryPlayfulness = 1
                    face.settle()

                    // New gestures finish by themselves and leave nothing behind.
                    policy.greet("habitual"); wait(100)
                    check(face.gesture === "welcome", "habitual greeting is a welcome")
                    wait(500)
                    check(face.glad && face.smile > 0.5 && face.squash > 1, "welcome smiles after the slow blink")
                    wait(2800)
                    check(still(face), "welcome ends in stillness: " + face.gesture)
                    policy.greet("return"); wait(3000)
                    check(face.gesture === "welcomeBack" && face.glad, "returning welcome lasts longer")
                    wait(1500)
                    check(still(face), "returning welcome ends in stillness")
                    policy.greet("unusual"); wait(200)
                    check(face.gesture === "surprised" && face.openTarget === 1.25 && face.tilt < 0, "unusual hour opens the eyes with a tilt")
                    wait(1500)
                    check(still(face) && face.openTarget === 1, "surprise ends in stillness")
                    policy.greet("")
                    check(face.gesture === "", "no greeting kind, no gesture")
                    for (const kind of ["welcome", "surprised"]) {
                        for (const stop of ["reduced", "hidden", "suspended", "blocked", "asleep"]) {
                            face.play(kind); wait(300)
                            check(face.gesture === kind, kind + " starts before " + stop)
                            if (stop === "reduced") face.reduced = true
                            else if (stop === "hidden") chip.visible = false
                            else if (stop === "suspended") policy.active = false
                            else if (stop === "blocked") policy.blocked = true
                            else face.asleep = true
                            check(still(face) || (stop === "asleep" && face.gesture === "yawn"), stop + " cancels " + kind)
                            face.reduced = false; chip.visible = true; policy.active = true; policy.blocked = false; face.asleep = false; face.settle()
                        }
                    }
                    face.reduced = true
                    face.play("welcome"); face.play("surprised"); wait(200)
                    check(still(face), "reduced refuses the new gestures")
                    face.reduced = false
                    console.log("PASS: Iris memory (lazy load, classification, single greeting, ageing, opt-out) and welcome/surprised gestures")
                    exitTimer.start()
                } catch (error) { console.error("FAIL: Iris memory " + error); Qt.exit(1) }
            }
        }
    }
}
