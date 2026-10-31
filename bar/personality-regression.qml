import QtQuick
import QtTest
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    Window {
        id: window
        visible: true
        width: 1000; height: 720
        color: Theme.background
        Pill {
            id: pill
            anchors.horizontalCenter: parent.horizontalCenter
            y: 42
            screenName: "personality-fixture"
            notificationsEnabled: false
            property int surfaceRequests: 0
            onRequestSurface: surfaceRequests++
        }
        IslandActivityChip {
            id: recordingChip
            x: 32; y: 180
            label: "REC · 00:12"
            recordingPhase: "recording"
        }
        CompanionBehavior { id: behavior; active: true }
        IslandCompanion { id: eyes; x: 32; y: 32; visible: false }
        IslandCompanion { id: face; x: 32; y: 120; reduced: false }
        Timer { id: exitTimer; interval: 120; onTriggered: Qt.quit() }
        TestCase {
            name: "IslandPersonality"
            when: Config.loaded && window.visible
            function shot(name) {
                const dir = Quickshell.env("ISLA_TEST_OUTPUT")
                if (!dir || !dir.length) return
                window.contentItem.grabToImage(result => result.saveToFile(dir + "/" + name + ".png"))
                wait(60)
            }
            function check(ok, message) { if (!ok) throw new Error(message || "condition failed") }
            function eventually(callback, timeout, message) {
                let elapsed = 0
                while (!callback() && elapsed < timeout) { wait(25); elapsed += 25 }
                check(callback(), message || "eventual condition failed")
            }
            // Every moment is finite and returns the body to rest.
            function companionMoments() {
                const newStill = () => face.gesture === "" && face.winkLid === 1 && face.lowerLid === 0 && face.roll === 0 && face.breath === 1
                for (const kind of ["wink", "curious", "roll", "sneeze", "yawn", "squint", "doze", "holdSneeze", "firefly"]) {
                    face.play(kind)
                    check(face.gesture === kind, kind + " starts")
                    eventually(newStill, 3000, kind + " returns to rest")
                    face.play(kind); wait(120); face.reduced = true
                    check(newStill(), kind + " stops reduced")
                    face.reduced = false
                    face.play(kind); wait(120); face.visible = false
                    check(newStill(), kind + " stops hidden")
                    face.visible = true
                }
                behavior.blocked = true
                check(!behavior.tryMischief(700000, 0), "blocked mischief")
                behavior.blocked = false; behavior.options = {mischief: "never", reactAtNight: true}
                check(!behavior.tryMischief(700000, 0), "disabled mischief")
                behavior.options = {mischief: "rare", reactAtNight: true, followPointer: true, reactToCode: true, reactToMusic: true}
                check(behavior.tryMischief(700000, 0), "rare opportunity")
                check(!behavior.tryMischief(800000, 0), "ten minute cadence")
                behavior.night = true
                check(!behavior.tryYawn(200000, 0.12), "night probability bounded")
                check(behavior.tryYawn(200000, 0.09), "night opportunity")
                check(!behavior.tryYawn(220000, 0), "two minute yawn cadence")
                behavior.pointerInside = true; behavior.pointerX = 1
                wait(120); check(behavior.sampledX === 0, "pointer waits at least 250 ms")
                eventually(() => behavior.sampledX === 1, 1000, "pointer samples latest position")
                behavior.active = false
                check(behavior.lookX === 0 && behavior.pupilBeat === 0, "hidden policy is still")
                behavior.active = true; behavior.pointerInside = false; behavior.codeFocused = true
                check(behavior.concentrating && behavior.lookY > 0, "code focus looks down")
                behavior.musicVisible = true; behavior.playing = true; behavior.seek = 0.8; behavior.beat = 0.7
                check(behavior.lookX > 0 && behavior.pupilBeat === 0.7, "visible music follows seek and beat")
                behavior.musicVisible = false
                check(behavior.pupilBeat === 0, "hidden music has no pupil bounce")
                behavior.reduced = true
                check(!behavior.concentrating && behavior.lookY === 0, "reduced policy stops motion")
                face.settle()

                face.greet(); wait(35); face.play("roll"); wait(30)
                check(face.gesture === "roll" && face.lid === 1, "a gesture replaces the greeting blink")
                face.settle()

                const still = () => face.hop === 0 && face.tilt === 0 && face.squash === 1
                face.mood = "finished"
                check(face.smiling, "finishing smiles")
                wait(150)
                check(face.hop < 0 || face.squash !== 1, "finishing celebrates")
                eventually(still, 1600, "celebration ends at rest")
                face.mood = "rest"
                face.listening = true
                wait(200)
                check(face.tilt > 0 && face.cheerful, "music start sways")
                eventually(() => still() && !face.cheerful, 2600, "sway is two beats, then still")
                face.pat()
                check(face.cheerful, "pat brightens")
                eventually(() => !face.cheerful && still() && face.gesture === "", 2400, "pat settles")
                face.sleepy = true
                eventually(() => face.droop > 0.45, 900, "night lowers the lid")
                face.engaged = true
                eventually(() => face.droop < 0.25, 900, "attention lifts the lid")
                face.engaged = false; face.sleepy = false
                face.asleep = true
                eventually(() => face.open < 0.05 && face.gazeX === 0, 2200, "absence closes the eyes")
                face.greet(); face.nod(); face.celebrate()
                check(face.lid === 1 && still(), "asleep ignores gestures")
                face.asleep = false
                eventually(() => face.open > 0.95 && face.lid === 1 && still(), 1800, "return wakes and settles")
                face.mood = "finished"
                wait(120)
                face.reduced = true
                check(still() && face.lid === 1, "reduced motion cuts a moment")
                face.pat(); face.listening = false; face.listening = true
                check(!face.cheerful && still(), "reduced ignores new pat and music moments")
                wait(1900)
                check(!face.cheerful && still(), "reduced has no delayed cheer transition")
                face.reduced = false
                face.mood = "rest"
                face.listening = false; face.listening = true
                wait(120)
                face.visible = false
                check(still() && !face.cheerful, "hiding cuts a moment")
                face.visible = true
            }
            function companionInteractions() {
                face.settle(); face.mood = "rest"; face.listening = false
                face.affectionUntil = 0; face.lastClick = 0
                face.interact(); check(face.gesture === "curious", "first click is curious")
                check(face.openTarget === 1.12, "curiosity opens the eyes")
                face.interact(); check(face.gesture === "roll", "second click plays")
                face.interact(); check(face.gesture === "squint", "third click asks for a pause")
                face.interact(); check(face.gesture === "holdSneeze", "fourth click discovers a small story")
                face.interact(); check(face.gesture === "firefly", "fifth click discovers the firefly")
                check(!face.cheerful, "story clears the third click's cheerful expression")
                face.lastClick = Date.now() - 1200
                face.interact(); check(face.gesture === "curious", "click sequence resets after a pause")
                face.settle()
                face.approachPointer(true)
                eventually(() => face.gesture === "curious", 1400, "lingering hover becomes curiosity")
                face.stroke(120, 1, 0.7); wait(80)
                face.stroke(120, -1, -0.7); wait(80)
                face.stroke(120, 1, 0.7); wait(100)
                eventually(() => face.touch > 0.3 && face.eyeOpening < 0.8, 180, "gentle stroke closes eyes progressively")
                face.approachPointer(false)
                check(face.lingering, "eyes follow a departed cursor briefly")
                eventually(() => !face.lingering && face.touch < 0.01, 1600, "stroke and lingering settle")
                face.stroke(900, 1, 0.6)
                check(face.gesture === "squint" && face.affectionUntil === 0, "fast movement tickles without earning a pat")
                face.settle(); face.celebrate(); wait(100); face.stroke(120, 1, 0.7); wait(90)
                check(face.hop === 0 && face.squash === 1 && face.touch > 0, "stroke replaces celebration")
                face.sway(); wait(100); face.stroke(120, 1, 0.7); wait(90)
                check(face.tilt === 0 && face.touch > 0, "stroke replaces music sway")
                face.wakeAfter(90000); wait(100); face.stroke(120, 1, 0.7); wait(90)
                check(face.squash === 1 && face.touch > 0, "stroke replaces waking stretch")
                face.pat()
                check(face.touch === 0, "discrete pat replaces continuous stroke")
                check(face.affectionUntil > Date.now(), "pat remembers affection briefly")
                face.settle(); face.approachPointer(true)
                check(face.cheerful, "return within affection window is warmer")
                face.settle(); face.affectionUntil = Date.now() - 1
                face.approachPointer(true)
                check(!face.cheerful, "affection expires without a background clock")
                face.settle(); face.wakeAfter(15000)
                check(face.gesture === "curious", "short absence recognizes return")
                face.settle(); face.wakeAfter(90000); wait(100)
                check(face.squash > 1, "long absence stretches")
                face.settle(); face.approachPointer(true); face.stroke(120, 1, 0.6)
                face.visible = false; wait(1100)
                check(face.gesture === "" && face.touch === 0 && !face.lingering && !face.pointerOver, "hidden cancels delayed interactions")
                face.visible = true; face.reduced = true
                face.approachPointer(true); face.stroke(120, 1, 0.6); face.wakeAfter(90000); wait(1000)
                check(face.gesture === "" && face.touch === 0 && face.squash === 1, "reduced refuses new interactions")
                face.reduced = false; face.settle()
                behavior.reduced = false
                behavior.options = {followPointer: false, reactToCode: false, reactToMusic: false, reactAtNight: false, mischief: "never"}
                face.context = behavior
                face.approachPointer(true); face.stroke(120, 1, 0.8); face.approachPointer(false)
                check(face.touchDirection === 0 && !face.lingering, "followPointer off disables touch lean and lingering")
                face.settle(); face.context = null
            }
            function test_receptionAndActivity() {
                try {
                DesktopStatus.monitorServices = false
                Config.update({appearance: {reduceMotion: false, personality: true}})
                wait(900)
                companionMoments()
                companionInteractions()
                eventually(() => pill.restHeaderOpacity > 0.99 && Math.abs(pill.width - pill.restW) < 1, 4000, "rest settles before capture")
                shot("rest")
                const restWidth = pill.restCenterWidth
                const activityHit = findChild(pill, "islandActivityHit")
                const companion = findChild(pill, "activityCompanion")
                const policy = findChild(pill, "companionBehavior")
                pill.companionBlocked = true
                check(policy.blocked && !policy.tryMischief(Date.now(), 0), "host launcher/auth guard blocks mischief")
                pill.companionBlocked = false
                check(activityHit && companion, "companion control exists")
                mouseMove(activityHit, activityHit.width / 2, activityHit.height / 2)
                wait(550)
                check(companion.engaged, "hover engages the expression")
                check(Math.abs(pill.restCenterWidth - restWidth) < 1, "hover keeps header geometry")
                shot("companion-hover")
                for (let pass = 0; pass < 4; pass++) {
                    mouseMove(activityHit, activityHit.width * (pass % 2 ? 0.75 : 0.25), activityHit.height / 2)
                    wait(70)
                }
                check(companion.cheerful, "stroking side to side is a pat")
                activityHit.forceActiveFocus()
                check(companion.engaged && activityHit.activeFocus, "keyboard has equivalent feedback")
                eventually(() => !companion.cheerful, 2400, "stroke settles before click")
                mouseClick(activityHit, activityHit.width / 2, activityHit.height / 2)
                check(companion.gesture !== "pat" && companion.gesture.length > 0, "click plays a distinct gesture")
                check(pill.surfaceRequests === 0, "pet click never requests a panel")
                eventually(() => !companion.cheerful, 2400, "click settles")
                activityHit.forceActiveFocus()
                keyClick(Qt.Key_Space)
                check(companion.gesture !== "pat" && companion.gesture.length > 0 && pill.surfaceRequests === 0, "keyboard plays without navigation")
                const recordingFace = findChild(recordingChip, "activityCompanion")
                const recordingHit = findChild(recordingChip, "islandActivityHit")
                const indicator = findChild(recordingChip, "recordingIndicator")
                check(recordingFace.visible && indicator.visible, "recording keeps the face alongside its indicator")
                check(indicator.x >= recordingHit.width, "recording is outside the pet hit area")
                mouseClick(recordingHit, recordingHit.width / 2, recordingHit.height / 2)
                check(recordingFace.gesture.length > 0, "pet stays interactive during recording")
                for (let pass = 0; pass < 5; pass++) {
                    mouseMove(recordingHit, recordingHit.width / 2, recordingHit.height * (pass % 2 ? 0.75 : 0.25))
                    wait(70)
                }
                check(recordingFace.cheerful, "vertical stroking is also a physical pat")
                shot("recording-with-companion")
                recordingChip.companionEnabled = false
                check(!recordingHit.enabled && !recordingFace.visible && indicator.visible, "opt-out preserves recording status without a hidden pet control")
                shot("companion-focus")
                pill.hovered = true
                pill.pointerX = pill.width
                pill.pointerY = pill.height
                wait(200)
                shot("look-right")
                pill.lastBatteryStatus = "discharging"
                DesktopStatus.batteryOSD(67, "charging")
                check(pill.activityNotice === qsTr("Cargando · %1%").arg(67), "battery event reaches charging notice")
                check(pill.receiving, "charging starts finite reception")
                wait(160)
                shot("charge-early")
                wait(180)
                shot("charge-wave")
                eventually(() => pill.restCenterWidth > restWidth, 1200)
                eventually(() => !pill.receiving, 4000, "pulse stops without idle clock")
                shot("charge-settled")
                pill.surface = "focus"
                eventually(() => pill.surfaceItem !== null, 3000)
                wait(700)
                shot("focus")
                for (let frame = 0; frame < 10; frame++) {
                    if (frame === 0) pill.surfaceItem.feedbackRequested("received")
                    wait(80)
                    shot("pulse-" + String(frame).padStart(2, "0"))
                }
                pill.surfaceItem.feedbackRequested("received")
                check(pill.receiving, "surface result reaches shared material")
                wait(230)
                shot("focus-reception")
                pill.respond("received")
                wait(90)
                check(pill.receiving, "repeat retargets pulse")
                Config.update({appearance: {reduceMotion: true}})
                check(!pill.receiving, "reduced motion cancels running pulse")
                pill.respond("received")
                check(!pill.receiving, "reduced result remains still")
                eyes.visible = true
                eyes.reduced = true
                eyes.lookX = 1
                check(eyes.gazeX === 0, "reduced gaze")
                check(eyes.lid === 1, "reduced blink")
                pill.surface = ""
                wait(100)
                Config.update({appearance: {personality: false}})
                pill.activityNotice = ""
                wait(150)
                check(pill.restCenterWidth < restWidth, "companion can be disabled")
                Config.update({appearance: {personality: true, reduceMotion: false}})
                pill.respond("received")
                check(pill.receiving)
                pill.visible = false
                check(!pill.receiving, "hidden material stops pulse")
                console.log("PASS: companion moments, pat, reception, charging, shared surface feedback, eyes, reduced motion, visibility and opt-out")
                exitTimer.start()
                } catch (error) { console.error("FAIL: personality " + error); Qt.exit(1) }
            }
        }
    }
}
