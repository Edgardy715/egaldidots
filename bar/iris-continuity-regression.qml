import QtQuick
import QtTest
import Quickshell
import "components"
import "Singletons"

// Run with temporary ISLA_CONFIG and ISLA_IRIS. Covers Iris' continuity across
// surfaces: the attention mechanism (precedence, saturation, opt-outs), the perch
// (rest -> corner -> back, retarget, reduced, hidden) and the surface producers.
ShellRoot {
    settings.watchFiles: false
    Window {
        id: scene
        visible: true
        width: 1100; height: 650
        title: "Isla · Iris · continuidad · prueba"
        color: "#242424"
        Pill {
            id: pill
            x: (scene.width - width) / 2
            y: 16
            screenName: "continuity-test"
            notificationsEnabled: false
        }
        // Mechanism fixture: a policy and a face with no pill around them.
        CompanionBehavior { id: policy; active: true }
        IslandCompanion { id: bareFace; x: 20; y: 300; context: policy; lookX: policy.lookX; lookY: policy.lookY }
        // Producer fixtures.
        LauncherView { id: launcher; x: 20; y: 340; width: 500; height: 260; open: true }
        LyricsView {
            id: lyrics
            x: 540; y: 340; width: 500; height: 260
            open: true; status: "ready"; synced: true; position: 0
            lines: [{time: 0, text: "uno"}, {time: 2, text: "dos"}, {time: 4, text: "tres"}, {time: 6, text: "cuatro"}, {time: 8, text: "cinco"}]
        }
        ListModel {
            id: wallpapers
            Component.onCompleted: { for (let i = 0; i < 6; i++) append({path: "/nonexistent/w" + i + ".png", baseName: "w" + i, thumb: "", thumbReady: true,
                thumbSource: "", cacheRevision: 0, shimmer: false, thumbFailed: true, applied: false}) }
        }
        WallpaperView { id: picker; x: 20; y: 340; width: 700; height: 300; visible: false; open: false; s: 1; wallpaperModel: wallpapers }
        Timer { id: quitTimer; interval: 80; onTriggered: Qt.quit() }
        TestCase {
            id: checks
            name: "IrisContinuity"
            when: Config.loaded && scene.visible
            function check(ok, message) { if (!ok) { console.error("FAIL:", message); Qt.exit(1); throw new Error(message) } }
            function setOptions(patch) { policy.options = Object.assign({}, policy.options, patch) }
            function shot(name) {
                const dir = Quickshell.env("ISLA_CONTINUITY_SHOTS")
                if (dir) grabImage(scene.contentItem).save(dir + "/" + name + ".png")
            }

            function test_00_mechanism() {
                try {
                    Config.update({appearance: {reduceMotion: false, personality: true}})
                    check(Config.companion.followFocus === true, "followFocus defaults to true")
                    policy.active = true; policy.reduced = false; policy.asleep = false
                    setOptions({followFocus: true, followPointer: true})
                    check(policy.lookX === 0 && policy.lookY === 0, "no focus means the existing behaviour (still)")

                    policy.focusActive = true; policy.focusX = 0.5; policy.focusY = -0.25
                    check(policy.lookX === 0.5 && policy.lookY === -0.25, "focus drives the gaze: " + policy.lookX + "," + policy.lookY)
                    policy.focusX = 7; policy.focusY = -9
                    check(policy.lookX === 1 && policy.lookY === -1, "focus saturates to -1..1")

                    // A point of interest beats the pointer; without one the pointer leads as before.
                    policy.pointerInside = true; policy.pointerX = -0.4; policy.pointerY = 0.3
                    policy.sampledX = -0.4; policy.sampledY = 0.3
                    check(policy.lookX === 1 && policy.lookY === -1, "focus beats the pointer: " + policy.lookX + "," + policy.lookY)
                    setOptions({followFocus: false})
                    check(policy.lookX === -0.4 && policy.lookY === 0.3, "followFocus=false leaves the pointer in charge")
                    setOptions({followFocus: true})
                    policy.focusActive = false
                    check(policy.lookX === -0.4 && policy.lookY === 0.3, "without focus the pointer leads")
                    setOptions({followPointer: false})
                    check(policy.lookX === 0, "without focus and followPointer the gaze rests")
                    setOptions({followPointer: true})
                    policy.focusActive = true
                    policy.pointerInside = false; policy.sampledX = 0; policy.sampledY = 0

                    // Gaze goes through the face's springs, not a new motor.
                    policy.focusX = 1; policy.focusY = 0
                    tryVerify(() => bareFace.gazeX > 0.5, 1500)
                    check(bareFace.gazeX <= 3 * bareFace.s + 0.01, "gaze stays inside the eye: " + bareFace.gazeX)

                    setOptions({followFocus: false})
                    check(policy.lookX === 0 && !policy.followingFocus, "followFocus=false turns attention off")
                    setOptions({followFocus: true})
                    check(policy.lookX === 1, "followFocus=true restores it")
                    policy.reduced = true
                    check(policy.lookX === 0 && policy.lookY === 0, "reduced turns attention off")
                    policy.reduced = false
                    policy.asleep = true
                    check(policy.lookX === 0, "asleep turns attention off")
                    policy.asleep = false
                    policy.active = false
                    check(policy.lookX === 0, "a hidden face does not look")
                    policy.active = true
                    policy.blocked = true
                    check(policy.lookX === 1, "blocked (launcher/auth) does not block the gaze")
                    policy.blocked = false
                    policy.focusActive = false
                    check(policy.lookX === 0, "focus released goes back to rest")
                    console.log("PASS: attention mechanism (precedence, saturation, opt-outs, springs)")
                } catch (e) { console.error("FAIL: mechanism", e); Qt.exit(1); throw e }
            }

            function test_10_perch() {
                try {
                    Config.update({appearance: {reduceMotion: false, personality: true}})
                    pill.surface = ""
                    wait(900)
                    const perch = findChild(pill, "irisPerch")
                    check(perch !== null, "the perch exists")
                    check(pill.perchTravel === 0 && !perch.visible && !pill.perchShown, "perch is not visible at rest")
                    check(!perch.interactive, "a hidden perch is inactive")

                    pill.surface = "mixer"
                    // Travel is one value 0 -> 1: monotonic, a real animation, no frame jumps. The
                    // pixel position also follows the growing pill's corner, which the pill owns.
                    let prev = pill.perchTravel, prevTime = Date.now()
                    let monotonic = true, sawMid = false, maxStep = 0
                    for (let i = 0; i < 40; i++) {
                        wait(16)
                        const t = pill.perchTravel, now = Date.now()
                        if (t + 1e-6 < prev) monotonic = false
                        if (t > 0.05 && t < 0.95) sawMid = true
                        if (now - prevTime <= 30) maxStep = Math.max(maxStep, (t - prev) / (now - prevTime))
                        prev = t; prevTime = now
                    }
                    console.log("MAXSTEP open travel/ms", maxStep.toFixed(4))
                    check(monotonic, "travel is monotonic 0 -> 1")
                    check(sawMid, "travel is a real animation, not a cut")
                    check(maxStep < 0.01, "no frame jump beyond the curve (SmoothedAnimation peak 2 / 400 ms = 0.005 per ms, 2x margin): " + maxStep)
                    wait(300)
                    check(Math.abs(pill.perchTravel - 1) < 0.001, "travel reaches 1: " + pill.perchTravel)
                    check(perch.visible && perch.opacity > 0.99, "perch is shown on an open surface")
                    check(pill.faceVisible && policy2().active, "the behaviour stays active through the perch")
                    const cx = perch.x + perch.width / 2, cy = perch.y + perch.height / 2
                    check(Math.abs(cx - pill.perchTarget.x) < 0.5 && Math.abs(cy - pill.perchTarget.y) < 0.5,
                          "perch rests on its corner: " + cx + "," + cy + " vs " + pill.perchTarget.x + "," + pill.perchTarget.y)
                    check(cx > pill.width / 2 && cy < pill.restHeight, "the corner is top right")
                    check(perch.interactive, "a shown perch is active")

                    // Retarget mid-way: close, interrupt on the way back, reopen.
                    pill.surface = ""
                    wait(120)
                    const mid = pill.perchTravel
                    check(mid > 0.02 && mid < 0.999, "closing travels back from the current state: " + mid)
                    prev = mid
                    pill.surface = "calendar"
                    let worst = 0
                    for (let i = 0; i < 8; i++) {
                        wait(16)
                        worst = Math.max(worst, Math.abs(pill.perchTravel - prev))
                        prev = pill.perchTravel
                    }
                    console.log("MAXSTEP retarget travel/frame", worst.toFixed(3))
                    check(worst < 0.32, "retarget continues from the current travel, within one curve step: " + worst)
                    wait(900)
                    check(Math.abs(pill.perchTravel - 1) < 0.001, "perch ends in the corner after the retarget")

                    pill.surface = ""
                    wait(900)
                    check(pill.perchTravel === 0 && !perch.visible, "perch travels back and hides on close")
                    check(!policy2().active || pill.restHeaderOpacity > 0.01, "behaviour follows the visible face")

                    // The launcher and the auth prompt keep the face in their own header.
                    pill.surface = "launcher"
                    wait(900)
                    check(pill.perchTravel === 0 && !perch.visible, "launcher keeps the face in its header")
                    pill.surface = ""
                    wait(900)

                    // Reduced motion: no travel at all, nothing running.
                    Config.update({appearance: {reduceMotion: true}})
                    wait(100)
                    pill.surface = "mixer"
                    wait(700)
                    check(pill.perchTravel === 0 && !perch.visible, "reduced motion: the perch does not travel")
                    pill.surface = ""
                    Config.update({appearance: {reduceMotion: false}})
                    wait(700)
                    // Personality off: no face, no perch.
                    Config.update({appearance: {personality: false}})
                    pill.surface = "mixer"
                    wait(700)
                    check(pill.perchTravel === 0 && !perch.visible, "personality off: no perch")
                    pill.surface = ""
                    Config.update({appearance: {personality: true}})
                    wait(700)
                    console.log("PASS: perch (rest, travel, retarget, close, launcher, reduced, hidden)")
                } catch (e) { console.error("FAIL: perch", e); Qt.exit(1); throw e }
            }
            function policy2() { return findChild(pill, "companionBehavior") }

            function centerOf(item) { return item.mapToItem(pill, item.width / 2, item.height / 2) }
            function dist(a, b) { return Math.hypot(a.x - b.x, a.y - b.y) }

            // At every scale the corner lies inside the pill on the scaled rest strip, and the way
            // back (to rest, or straight to the launcher) ends on the real header face without a jump.
            function test_15_perchScales() {
                try {
                    Config.update({appearance: {reduceMotion: false, personality: true}})
                    const perch = findChild(pill, "irisPerch")
                    const face = findChild(pill, "activityCompanion")
                    check(perch !== null && face !== null, "the perch and the header face exist")
                    for (const scale of [1, 1.33, 2]) {
                        pill.s = scale
                        pill.surface = ""
                        wait(900)
                        const label = "s=" + scale + ": "
                        const home = centerOf(face)
                        check(Math.abs(pill.perchOrigin.x - home.x) < 0.5 && Math.abs(pill.perchOrigin.y - home.y) < 0.5,
                              label + "the origin is the real header face: " + pill.perchOrigin.x + "," + pill.perchOrigin.y + " vs " + home.x + "," + home.y)

                        pill.surface = "mixer"
                        wait(1000)
                        check(Math.abs(pill.perchTravel - 1) < 0.001, label + "travel reaches 1")
                        const rest = centerOf(perch)
                        console.log("PERCH", label, "corner", rest.x.toFixed(1), rest.y.toFixed(1), "home", home.x.toFixed(1), home.y.toFixed(1), "pill", pill.width.toFixed(1), pill.height.toFixed(1), "coreH", pill.coreH)
                        check(rest.x > 0 && rest.x < pill.width && rest.y > 0 && rest.y < pill.height, label + "the corner is inside the pill")
                        check(Math.abs(rest.y - pill.coreH / 2) < 0.5, label + "the corner sits on the scaled rest strip: " + rest.y + " vs " + pill.coreH / 2)

                        // Back to rest: the last visible frame sits on the face.
                        pill.surface = ""
                        let last = rest, lastFace = home, prevTravel = 1
                        for (let i = 0; i < 70; i++) {
                            wait(16)
                            check(pill.perchTravel <= prevTravel + 1e-6, label + "the way back never reverses")
                            prevTravel = pill.perchTravel
                            if (pill.perchShown) { last = centerOf(perch); lastFace = centerOf(face) }
                        }
                        const homeAfter = lastFace
                        check(!pill.perchShown, label + "the perch is hidden after the way back")
                        // The face is compared where it is in that same frame (the pill is still shrinking). Opacity
                        // equals travel, so what remains of the way (<= 3 %) is allowed in x; y must match.
                        check(Math.abs(last.y - homeAfter.y) < 1.5 * scale && dist(last, homeAfter) < 0.03 * dist(rest, homeAfter) + 2 * scale,
                              label + "the last visible frame sits on the face: " + dist(last, homeAfter).toFixed(2) + " dy " + (last.y - homeAfter.y).toFixed(2))

                        // Direct change to the launcher: it flies to the launcher's own header face.
                        pill.surface = "mixer"
                        wait(1000)
                        pill.surface = "launcher"
                        let step = 0, before = centerOf(perch)
                        last = before; lastFace = centerOf(face)
                        for (let i = 0; i < 70; i++) {
                            wait(16)
                            if (pill.perchShown) {
                                const c = centerOf(perch)
                                step = Math.max(step, dist(c, last)); last = c; lastFace = centerOf(face)
                            }
                        }
                        const launcherHome = lastFace
                        console.log("PERCH", label, "launcher max step", step.toFixed(1), "of", dist(before, launcherHome).toFixed(1))
                        check(!pill.perchShown, label + "the launcher keeps the face in its header")
                        check(Math.abs(last.y - launcherHome.y) < 1.5 * scale && dist(last, launcherHome) < 0.03 * dist(before, launcherHome) + 2 * scale,
                              label + "mixer to launcher ends on the launcher header face: " + dist(last, launcherHome).toFixed(2))
                        check(step < 0.6 * dist(before, launcherHome) + 4 * scale, label + "no jump on mixer to launcher: " + step)
                        pill.surface = ""
                        wait(900)
                    }
                    pill.s = 1
                    wait(300)
                    console.log("PASS: perch at s=1, 1.33 and 2 (corner inside the pill, no origin jump, mixer to launcher)")
                } catch (e) { console.error("FAIL: perch scales", e); Qt.exit(1); throw e }
            }

            function test_20_pillAttention() {
                try {
                    Config.update({appearance: {reduceMotion: false, personality: true}})
                    const cb = policy2()
                    pill.surface = "mixer"
                    wait(900)
                    check(!cb.focusActive, "a surface without a producer gives no focus")
                    const item = pill.surfaceItem
                    check(item !== null && item.focusActive === false, "the open surface exposes the contract")
                    // Fake a point on the left, below the face: the vector points left and down.
                    item.focusPoint = Qt.point(10, 200); item.focusActive = true
                    tryVerify(() => cb.focusActive, 500)
                    check(cb.focusX < -0.9 && cb.focusY > 0, "focus vector points from the face toward the point: " + cb.focusX + "," + cb.focusY)
                    check(Math.abs(cb.focusX) <= 1 && Math.abs(cb.focusY) <= 1, "vector is saturated")
                    item.focusActive = false
                    check(!cb.focusActive && cb.lookX === 0, "releasing the focus releases the gaze")
                    // Approval: wink bypasses blocked.
                    pill.companionBlocked = true
                    item.approved()
                    wait(50)
                    pill.companionBlocked = false
                    pill.surface = ""
                    wait(900)

                    // Producer + policy with the pointer over the pill: the wallpaper hover (left of
                    // and below the face) wins over the pointer.
                    picker.visible = true; picker.open = true
                    pill.attentionItem = picker
                    wait(400)
                    const thumbs = []
                    const list = findChild(picker, "wallpaperThumbnails")
                    for (let i = 0; i < list.contentItem.children.length; i++) {
                        const c = list.contentItem.children[i]
                        if (c.objectName === "wallpaperThumbnail") thumbs.push(c)
                    }
                    thumbs.sort((a, b) => a.x - b.x)
                    const hover = thumbs[0].mapToItem(scene.contentItem, 56, 30)
                    pill.hovered = true
                    pill.pointerX = pill.width * 0.9; pill.pointerY = 2
                    mouseMove(scene.contentItem, hover.x, hover.y)
                    tryVerify(() => cb.focusActive, 1000, "the hovered wallpaper becomes the focus")
                    tryVerify(() => cb.lookX < -0.5, 1500, "gaze goes left though the pointer is right: " + cb.lookX)
                    check(cb.pointerInside && cb.pointerX > 0.5 && cb.lookX < 0 && cb.lookY > 0,
                          "hover left-below the face beats the pointer: " + cb.lookX + "," + cb.lookY)
                    mouseMove(scene.contentItem, 5, 5)
                    tryVerify(() => !cb.focusActive, 1000)
                    wait(400)
                    check(cb.lookX > 0.5, "without focus the pointer leads again: " + cb.lookX)
                    pill.hovered = false
                    pill.attentionItem = null
                    picker.open = false; picker.visible = false
                    wait(300)
                    console.log("PASS: pill attention vector and approval wiring")
                } catch (e) { console.error("FAIL: pill attention", e); Qt.exit(1); throw e }
            }

            function test_30_producers() {
                try {
                    Config.update({appearance: {reduceMotion: false}})
                    // Launcher: the caret.
                    launcher.open = true
                    const field = findChild(launcher, "launcherSearch")
                    field.forceActiveFocus()
                    tryVerify(() => launcher.focusActive, 1000)
                    field.text = ""
                    wait(50)
                    const left = launcher.focusPoint.x
                    field.text = "firefox navegador largo"
                    field.cursorPosition = field.text.length
                    wait(50)
                    const right = launcher.focusPoint.x
                    check(right > left + 40, "launcher focus follows the caret: " + left + " -> " + right)
                    launcher.open = false
                    check(!launcher.focusActive, "closed launcher publishes no focus")

                    // Lyrics: the current line, only when synced.
                    lyrics.position = 0
                    wait(150)
                    check(lyrics.focusActive, "synced lyrics publish the current line")
                    const y0 = lyrics.focusPoint.y
                    lyrics.position = 9
                    wait(700)
                    const y1 = lyrics.focusPoint.y
                    check(lyrics.lineIndex === 4, "line advances: " + lyrics.lineIndex)
                    check(y1 >= y0 - 1 && y1 <= lyrics.height + lyrics.y, "the lyric point stays inside the list and lowers/steadies: " + y0 + " -> " + y1)
                    lyrics.synced = false
                    check(!lyrics.focusActive, "unsynced lyrics publish no focus")
                    lyrics.synced = true
                    lyrics.open = false
                    check(!lyrics.focusActive, "a closed lyrics view publishes no focus")

                    // Wallpaper picker: the thumbnail under the pointer.
                    picker.visible = true; picker.open = true
                    wait(400)
                    check(!picker.focusActive, "no hover, no focus")
                    const thumbs = []
                    const list = findChild(picker, "wallpaperThumbnails")
                    for (let i = 0; i < list.contentItem.children.length; i++) {
                        const c = list.contentItem.children[i]
                        if (c.objectName === "wallpaperThumbnail") thumbs.push(c)
                    }
                    check(thumbs.length >= 3, "the picker lays out thumbnails: " + thumbs.length)
                    thumbs.sort((a, b) => a.x - b.x)
                    const pa = thumbs[0].mapToItem(scene.contentItem, 56, 30)
                    mouseMove(scene.contentItem, pa.x, pa.y)
                    tryVerify(() => picker.focusActive, 1000)
                    const fa = picker.focusPoint.x
                    const pb = thumbs[2].mapToItem(scene.contentItem, 56, 30)
                    mouseMove(scene.contentItem, pb.x, pb.y)
                    tryVerify(() => picker.focusPoint.x > fa + 100, 1000)
                    mouseMove(scene.contentItem, 5, 5)
                    tryVerify(() => !picker.focusActive, 1000)
                    picker.open = false; picker.visible = false

                    console.log("PASS: producers (launcher caret, synced lyrics, wallpaper hover)")
                    shot("final")
                } catch (e) { console.error("FAIL: producers", e); Qt.exit(1); throw e }
            }

            // Native Wayland captures only (ISLA_TEST_OUTPUT): the driver script grabs the
            // window when it reads a marker. Without it this test just ends.
            function mark(name, pause) {
                if (!Quickshell.env("ISLA_TEST_OUTPUT")) return
                console.log("CONTINUITY_CAPTURE " + name)
                wait(pause)
            }
            function test_40_capture() {
                try {
                    if (Quickshell.env("ISLA_TEST_OUTPUT")) {
                        Config.update({appearance: {reduceMotion: false, personality: true}})
                        launcher.visible = false; lyrics.visible = false
                        pill.surface = ""
                        wait(900)
                        mark("perch-rest", 350)
                        pill.surface = "mixer"
                        wait(70)
                        console.log("CAPTURE_TRAVEL", pill.perchTravel.toFixed(3))
                        mark("perch-travel-a", 350)
                        wait(10)
                        pill.surface = ""
                        wait(900)
                        pill.surface = "mixer"
                        wait(140)
                        console.log("CAPTURE_TRAVEL", pill.perchTravel.toFixed(3))
                        mark("perch-travel-b", 350)
                        wait(1000)
                        mark("perch-mixer", 350)
                        pill.surface = ""
                        wait(110)
                        console.log("CAPTURE_TRAVEL", pill.perchTravel.toFixed(3))
                        mark("perch-closing", 350)
                        wait(900)
                        mark("perch-closed", 350)
                        // Launcher: caret at the left then at the right.
                        pill.surface = "launcher"
                        wait(1200)
                        mark("launcher-empty", 350)
                        const field = findChild(pill, "launcherSearch")
                        if (field) {
                            field.text = "firefox navegador largo para el caret"
                            field.cursorPosition = field.text.length
                            wait(900)
                            mark("launcher-caret-right", 350)
                            field.cursorPosition = 0
                            wait(900)
                            mark("launcher-caret-left", 350)
                        }
                        pill.surface = ""
                        wait(600)
                    }
                    quitTimer.start()
                } catch (e) { console.error("FAIL: capture", e); Qt.exit(1); throw e }
            }
        }
    }
}
