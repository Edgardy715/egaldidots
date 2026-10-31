import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "components"
import "Singletons"
import "Singletons/Visitors.js" as Visitors

// Run with temporary ISLA_CONFIG and ISLA_IRIS. Covers Iris' small visitors (shape,
// clock-aware choice, gaze, cancellation, sightings), the dust shake after a long
// sleep and the eye tint and pupil in dark and light themes.
ShellRoot {
    settings.watchFiles: false
    Window {
        id: window
        visible: true
        width: 780; height: 360
        title: "Isla · Iris · visitas · prueba"
        color: Theme.surface
        property string phase: "Reposo"
        Text { x: 32; y: 30; text: window.phase; color: Theme.foreground; font.family: Theme.font; font.pixelSize: 22 }
        CompanionBehavior { id: policy; active: true }
        IslandActivityChip { id: actual; x: 55; y: 165; companionContext: policy }
        IslandActivityChip { id: medium; x: 280; y: 155; s: 1.5; coreH: 38 * s; companionContext: policy }
        IslandActivityChip { id: detail; x: 550; y: 125; s: 3; coreH: 38 * s; companionContext: policy }
        Connections { target: policy; function onVisited(kind) { IrisMemory.noteSighting(kind) } }
        FileView { id: reader; blockLoading: true; printErrors: false }
        FileView { id: writer; blockWrites: true; printErrors: false }
        SignalSpy { id: requests; target: policy; signalName: "gestureRequested" }
        SignalSpy { id: visits; target: policy; signalName: "visited" }
        Timer { id: exitTimer; interval: 120; onTriggered: Qt.quit() }
        TestCase {
            name: "IrisDelight"
            when: Config.loaded && window.visible
            function check(ok, message) { if (!ok) throw new Error(message) }
            function shot(name, caption) {
                window.phase = caption
                if (Quickshell.env("ISLA_TEST_OUTPUT")) {
                    wait(30)
                    console.log("DELIGHT_CAPTURE " + name)
                    wait(250)
                }
            }
            function stored() { reader.path = IrisMemory.file; reader.reload(); return reader.text() }
            function still(face) {
                return face.gesture === "" && !face.visitorOwnsGaze && face.visitProgress === 0 && !findChild(face, "companionVisitor").visible
                    && !face.wary && face.shake === 0 && face.lid === 1 && face.winkLid === 1 && face.lowerLid === 0
                    && face.breath === 1 && face.squash === 1 && face.tilt === 0
            }
            function luminance(c) {
                const f = v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
                return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b)
            }
            function contrast(a, b) {
                const x = luminance(a), y = luminance(b)
                return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05)
            }
            function shareOf(date, kind) {
                let hits = 0
                for (let i = 0; i < 1000; i++) if (Visitors.pick(date, (i + 0.5) / 1000) === kind) hits++
                return hits / 1000
            }
            function resetStops(faces) {
                for (const f of faces) { f.reduced = false; f.asleep = false; f.settle() }
                actual.visible = true; policy.active = true; policy.blocked = false
            }
            function test_visitorsAndDust() {
                try {
                    Config.update({appearance: {reduceMotion: false}, companion: {remember: true}})
                    mouseMove(window.contentItem, 5, 5)
                    wait(350)
                    const chips = [actual, medium, detail]
                    const faces = chips.map(chip => findChild(chip, "activityCompanion"))
                    IrisMemory.noteActivity()
                    tryVerify(() => IrisMemory.loaded, 3000, "memory loads")
                    IrisMemory.sightings = ({})

                    // The path of every visitor fits the 30x26 slot at every scale.
                    for (const kind of Visitors.kinds) {
                        const spec = Visitors.table[kind], size = Math.max(spec.halo, spec.w, spec.h)
                        for (let i = 0; i <= 200; i++) {
                            const p = i / 200, x = spec.x(p), y = spec.y(p)
                            check(x - size / 2 >= -0.01 && x + size / 2 <= 30.01 && y - size / 2 >= -0.01 && y + size / 2 <= 26.01,
                                  kind + " leaves the face slot at p=" + p + ": " + x + "," + y)
                        }
                    }

                    // Each visitor plays on all three scales, follows the gaze and leaves nothing behind.
                    for (const kind of Visitors.kinds) {
                        const spec = Visitors.table[kind], before = visits.count
                        for (const f of faces) f.settle()
                        for (const f of faces) f.play(kind)
                        check(faces.every(f => f.visiting && f.visitorOwnsGaze && f.gesture === kind), kind + " starts")
                        wait(spec.duration * 0.5)
                        for (const f of faces) {
                            const item = findChild(f, "companionVisitor")
                            check(item.visible && item.opacity > 0.5, kind + " appears at scale " + f.s)
                            check(item.x >= -0.01 && item.x + item.width <= f.width + 0.01 && item.y >= -0.01 && item.y + item.height <= f.height + 0.01,
                                  kind + " fits the face at scale " + f.s + ": " + item.x + "," + item.y + " " + item.width + "x" + item.height + " in " + f.width + "x" + f.height)
                        }
                        shot("visitor-" + kind, "Visita · " + spec.label)
                        // The captures above take time, so the gaze is awaited rather than sampled at a fixed instant.
                        if (kind === "raindrop") tryVerify(() => faces.every(f => f.gazeY > 0.4 * f.s), spec.duration, "eyes follow the raindrop down: " + faces[1].gazeY)
                        if (kind === "bubble") tryVerify(() => faces.every(f => f.gazeY < -0.4 * f.s), spec.duration, "eyes follow the bubble up: " + faces[1].gazeY)
                        tryVerify(() => faces.every(still), spec.duration + 1500, kind + " ends in stillness")
                        check(faces.every(still), kind + " ends in stillness: " + faces.map(f => f.gesture + "/" + f.lid))
                        check(visits.count === before + 3 && visits.signalArguments[visits.count - 1][0] === kind, kind + " is counted once per face that saw it to the end")
                    }
                    for (const kind of Visitors.kinds) check(IrisMemory.sightings[kind] === 3, "sighting recorded at the end: " + kind + "=" + IrisMemory.sightings[kind])

                    // Interruptions leave no sighting and no residue.
                    const face = faces[1], counted = visits.count
                    for (const kind of Visitors.kinds) {
                        for (const stop of ["reduced", "hidden", "suspended", "blocked", "asleep", "touch"]) {
                            face.play(kind); wait(150)
                            check(face.visiting, kind + " starts before " + stop)
                            if (stop === "reduced") face.reduced = true
                            else if (stop === "hidden") medium.visible = false
                            else if (stop === "suspended") policy.active = false
                            else if (stop === "blocked") policy.blocked = true
                            else if (stop === "asleep") face.asleep = true
                            else face.stroke(120, 1, 0.7)
                            check(!face.visiting && !face.visitorOwnsGaze && face.visitProgress === 0, stop + " cancels " + kind)
                            check(still(face) || (stop === "asleep" && face.gesture === "yawn"), stop + " leaves " + kind + " no residue: " + face.gesture)
                            medium.visible = true; resetStops(faces)
                            wait(100)
                        }
                    }
                    wait(500)
                    check(visits.count === counted, "a cancelled visit is never counted")
                    face.reduced = true
                    for (const kind of Visitors.kinds) face.play(kind)
                    check(still(face), "reduced refuses every visitor")
                    face.reduced = false

                    // Clock-aware choice, with explicit dates.
                    const day = new Date(2026, 5, 15, 14, 0), night = new Date(2026, 5, 15, 23, 30), late = new Date(2026, 5, 16, 5, 59)
                    const dawn = new Date(2026, 5, 16, 6, 0), winter = new Date(2026, 11, 15, 14, 0), edge = new Date(2026, 10, 30, 14, 0)
                    const seen = date => Visitors.kinds.filter(k => shareOf(date, k) > 0).sort().join(",")
                    check(seen(day) === "bubble,firefly,raindrop", "daytime visitors: " + seen(day))
                    check(seen(night) === "bubble,firefly,moth,raindrop", "23:30 allows the moth: " + seen(night))
                    check(seen(late) === "bubble,firefly,moth,raindrop", "05:59 allows the moth: " + seen(late))
                    check(seen(dawn) === "bubble,firefly,raindrop", "06:00 no longer allows the moth: " + seen(dawn))
                    check(seen(winter) === "bubble,firefly,raindrop,snowflake", "December allows the snowflake: " + seen(winter))
                    check(seen(edge) === "bubble,firefly,raindrop" && seen(new Date(2027, 0, 1, 14, 0)) === "bubble,firefly,raindrop", "snow stays in December")
                    check(Math.abs(shareOf(day, "firefly") - 0.5) < 0.01 && Math.abs(shareOf(day, "raindrop") - 0.25) < 0.01, "daytime weights 3 : 1.5 : 1.5")
                    check(Math.abs(shareOf(winter, "snowflake") - 0.3333) < 0.01, "snow weight 3 of 9 in December")
                    check(Visitors.pick(day, 0) === "firefly" && Visitors.pick(day, 0.9999) === "bubble", "pick covers the whole roll range")

                    // The mischief budget is unchanged: only the visitor slot was redistributed.
                    face.settle()
                    const noon = day.getTime()
                    let visitorSlots = 0, sneezes = 0, rolls = 0, winks = 0, expectedVisitors = 0
                    for (let i = 0; i < 1600; i++) {
                        const roll = i * 0.00005
                        policy.lastMischief = 0
                        const before = requests.count
                        const played = policy.tryMischief(noon, roll)
                        if (roll < 0.0125) expectedVisitors++
                        if (roll >= 0.08) { check(!played, "no mischief at roll " + roll); continue }
                        check(played && requests.count === before + 1, "mischief at roll " + roll)
                        const kind = requests.signalArguments[requests.count - 1][0]
                        if (Visitors.has(kind)) visitorSlots++
                        else if (kind === "holdSneeze") sneezes++
                        else if (kind === "roll") rolls++
                        else if (kind === "wink") winks++
                        else check(false, "unexpected request " + kind)
                    }
                    check(visitorSlots === expectedVisitors && visitorSlots === 250, "visitors keep the old 1.25 % slot: " + visitorSlots)
                    check(sneezes === 250 && rolls === 500 && winks === 600, "other slots unchanged: " + [sneezes, rolls, winks])
                    face.settle(); for (const f of faces) f.settle()
                    policy.lastMischief = 0
                    check(policy.tryMischief(noon, 0.01) && !policy.tryMischief(noon + 300000, 0.01) && policy.tryMischief(noon + 700000, 0.01), "ten minute cadence still applies")
                    for (const f of faces) f.settle()

                    // The fifth click is still the firefly.
                    face.lastClick = 0; face.clickCount = 0
                    for (let click = 0; click < 5; click++) face.interact()
                    check(face.gesture === "firefly", "fifth click plays the firefly: " + face.gesture)
                    face.settle()

                    // Sightings: persisted, capped, validated and opt-out aware.
                    for (let i = 0; i < 110; i++) IrisMemory.noteSighting("moth")
                    check(IrisMemory.sightings.moth === 99, "sightings are capped at 99")
                    IrisMemory.noteSighting("unicorn")
                    check(IrisMemory.sightings.unicorn === undefined, "unknown visitors are ignored")
                    IrisMemory.save()
                    tryVerify(() => { try { return JSON.parse(stored()).sightings.moth === 99 } catch (e) { return false } }, 3000, "sightings written")
                    check(JSON.parse(stored()).sightings.firefly === 3, "sightings persisted with the memory")
                    const garbage = '{"hours":[],"days":3,"sightings":{"firefly":500,"moth":-3,"bogus":4,"bubble":"x","raindrop":2.6,"snowflake":1}}'
                    const kept = JSON.stringify(IrisMemory.sightings)
                    Config.update({companion: {remember: false}})
                    check(!IrisMemory.loaded, "opt-out unloads the memory")
                    writer.path = IrisMemory.file; wait(50); writer.setText(garbage)
                    tryVerify(() => stored() === garbage, 3000, "damaged memory file written")
                    IrisMemory.noteSighting("firefly")
                    wait(300)
                    check(JSON.stringify(IrisMemory.sightings) === kept && stored() === garbage, "opt-out neither counts, reads nor writes sightings: " + JSON.stringify(IrisMemory.sightings))
                    Config.update({companion: {remember: true}})
                    IrisMemory.noteActivity()
                    tryVerify(() => IrisMemory.loaded, 3000, "memory reloads")
                    const clean = IrisMemory.sightings
                    check(clean.firefly === 99 && clean.raindrop === 3 && clean.snowflake === 1 && clean.moth === undefined && clean.bubble === undefined && clean.bogus === undefined,
                          "loaded sightings are validated: " + JSON.stringify(clean))
                    check(Visitors.summary({firefly: 3, moth: 1}) === "luciérnaga 3 · polilla 1" && Visitors.summary({}) === "", "summary reads in the face's own order")

                    // Dust after a long sleep: smaller than the refusal, then yawn, then stillness.
                    function track(kind, limit) {
                        let peak = 0, yawned = false
                        for (let t = 0; t < limit; t += 20) {
                            peak = Math.max(peak, Math.abs(face.shake)); yawned = yawned || face.gesture === "yawn"
                            wait(20)
                        }
                        return { peak: peak, yawned: yawned }
                    }
                    for (const f of faces) f.settle()
                    face.wakeAfter(10 * 60000)
                    check(face.gesture !== "dust", "ten minutes asleep does not shake dust")
                    for (const f of faces) f.settle()
                    face.wakeAfter(31 * 60000)
                    check(face.gesture === "dust" && !face.visiting, "half an hour asleep shakes the dust off")
                    const dust = track("dust", 900)
                    check(dust.peak > 0.2 && dust.peak <= 0.5 + 1e-6, "dust shake is small: " + dust.peak)
                    tryVerify(() => still(face), 6000, "dust ends in stillness")
                    face.play("no")
                    const refusal = track("no", 800)
                    check(refusal.peak > 0.6 && refusal.peak <= 1 + 1e-6 && refusal.peak > dust.peak, "refusal stays larger than dust: " + refusal.peak)
                    tryVerify(() => still(face), 4000, "refusal ends in stillness")
                    face.wakeAfter(31 * 60000)
                    // order check on a second pass: shake -> yawn -> still
                    face.settle(); face.play("dust")
                    const pass = track("dust", 2200)
                    check(pass.yawned, "dust is followed by a yawn")
                    tryVerify(() => still(face), 6000, "yawn after dust ends in stillness")
                    for (const stop of ["reduced", "hidden", "suspended", "blocked", "asleep"]) {
                        face.play("dust"); wait(120)
                        if (stop === "reduced") face.reduced = true
                        else if (stop === "hidden") medium.visible = false
                        else if (stop === "suspended") policy.active = false
                        else if (stop === "blocked") policy.blocked = true
                        else face.asleep = true
                        check(face.shake === 0 || face.gesture === "yawn", stop + " cancels dust: " + face.shake)
                        wait(80)
                        check(stop === "asleep" ? true : (face.gesture === "" && face.shake === 0), stop + " leaves no delayed dust: " + face.gesture)
                        medium.visible = true; resetStops(faces)
                    }

                    // Eye tint and pupil, dark and light.
                    const dark = IslaPalette.colors
                    const light = Object.assign({}, dark, {surface: "#fff8f7", on_surface: "#231919", primary: "#904a47", secondary: "#77524f", tertiary: "#6f5c2e"})
                    const original = IslaPalette.colors, originalMode = IslaPalette.mode
                    for (const theme of [{mode: "dark", colors: dark, pupil: 1.9}, {mode: "light", colors: light, pupil: 1.6}]) {
                        IslaPalette.mode = theme.mode; IslaPalette.colors = theme.colors
                        wait(500)
                        for (const f of faces) {
                            const eye = f.eyeColor, base = Theme.foreground, accent = Theme.accent
                            check(Math.abs(eye.r - (base.r * 0.88 + accent.r * 0.12)) < 0.02 && Math.abs(eye.g - (base.g * 0.88 + accent.g * 0.12)) < 0.02,
                                  theme.mode + " eye is the foreground with a 12 % accent trace: " + eye)
                            check(contrast(eye, Theme.surface) >= 4.5, theme.mode + " eye contrast " + contrast(eye, Theme.surface).toFixed(2))
                            const pupil = findChild(f, "companionPupil")
                            check(Math.abs(pupil.width - theme.pupil * f.s) < 0.01, theme.mode + " pupil " + pupil.width + " at scale " + f.s)
                        }
                        shot("tint-" + theme.mode, theme.mode === "dark" ? "Ojos · tema oscuro" : "Ojos · tema claro")
                    }
                    IslaPalette.mode = originalMode; IslaPalette.colors = original
                    wait(500)
                    for (const f of faces) f.settle()
                    shot("settled", "Reposo · sin movimiento pendiente")
                    console.log("PASS: Iris delight (visitors, clock choice, gaze, interruptions, sightings, dust, eye tint and pupil)")
                    exitTimer.start()
                } catch (error) { console.error("FAIL: Iris delight " + error); Qt.exit(1) }
            }
        }
    }
}
