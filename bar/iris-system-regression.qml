import QtQuick
import QtTest
import Quickshell
import "components"
import "Singletons"

// Run with temporary ISLA_CONFIG and ISLA_IRIS. Drives the composition hooks of
// Iris' system reactions (policy functions and properties); never touches the real
// battery, recorder, notifications, focus timer or authorization services.
ShellRoot {
    settings.watchFiles: false
    Window {
        id: window
        visible: true
        width: 360; height: 160
        title: "Isla · Iris · sistema · prueba"
        color: Theme.surface
        CompanionBehavior { id: policy; active: true }
        IslandActivityChip { id: chip; x: 40; y: 60; s: 2; coreH: 38 * s; companionContext: policy }
        Timer { id: exitTimer; interval: 120; onTriggered: Qt.quit() }
        TestCase {
            name: "IrisSystem"
            when: Config.loaded && window.visible
            function check(ok, message) { if (!ok) throw new Error(message) }
            function still(face) {
                return face.gesture === "" && !face.glad && !face.wary && face.lid === 1 && face.winkLid === 1
                    && face.lowerLid === 0 && face.breath === 1 && face.squash === 1 && face.tilt === 0 && face.shake === 0
            }
            function setOption(value) { policy.options = Object.assign({}, policy.options, {reactToSystem: value}) }
            function test_systemReactions() {
                try {
                    Config.update({appearance: {reduceMotion: false}})
                    check(Config.companion.reactToSystem === true, "reactToSystem defaults to true")
                    const face = findChild(chip, "activityCompanion")
                    mouseMove(window.contentItem, 5, 5)
                    wait(300)

                    // Silence by default: a repeated state is not an event.
                    policy.noteBattery(50, "discharging"); policy.noteBattery(49, "discharging")
                    wait(100)
                    check(face.gesture === "" && !policy.tired && !face.tired, "unchanged battery is silent")

                    // Critical notification: the face is hidden behind it, so the gesture waits.
                    policy.active = false; policy.blocked = true
                    check(!policy.react("surprised", "defer") && policy.deferredGesture === "surprised", "critical notification is deferred")
                    wait(300)
                    check(face.gesture === "", "nothing plays while the notification covers the face")
                    policy.blocked = false; policy.active = true
                    wait(400)
                    check(face.gesture === "", "it waits for the face to settle in")
                    wait(500)
                    check(face.gesture === "surprised" && policy.deferredGesture === "", "critical notification surprises once the face is free: " + face.gesture)
                    wait(1500)
                    check(still(face), "deferred surprise ends in stillness")
                    policy.blocked = true
                    check(!policy.react("stretch") && policy.deferredGesture === "" && face.gesture === "", "other events are never deferred")
                    policy.blocked = false

                    // Battery: low is a lasting state, charging and full are gestures.
                    policy.noteBattery(20, "discharging")
                    check(policy.batteryKind === "discharging" && !policy.tired, "above 15 % is not tired")
                    policy.noteBattery(15, "discharging")
                    check(policy.tired && face.tired, "15 % discharging is tired")
                    tryVerify(() => Math.abs(face.droop - 0.35) < 0.005, 2000, "tired lids settle at 0.35: " + face.droop)
                    check(face.gesture === "", "tired is a state, not a gesture")
                    policy.noteBattery(14, "charging")
                    check(!policy.tired && face.gesture === "content", "plugging in ends tiredness and is content: " + face.gesture)
                    wait(300)
                    check(face.cheerful && face.lowerLid > 0, "content squints with a smile")
                    wait(2200)
                    check(still(face) && !face.cheerful, "content ends in stillness")
                    tryVerify(() => face.droop === 0, 2000, "lids lift again")
                    policy.noteBattery(100, "charging")
                    check(face.gesture === "stretch", "full battery stretches: " + face.gesture)
                    wait(330)
                    check(face.squash > 1.05 && face.tilt < 0, "stretch lengthens the eyes and leans back: " + face.squash + "," + face.tilt)
                    wait(1000)
                    check(still(face), "stretch ends in stillness")
                    policy.noteBattery(100, "charging"); wait(100)
                    check(face.gesture === "", "same state is silent")
                    policy.noteBattery(99, "charging"); wait(100)
                    check(face.gesture === "", "dipping from full is not a new charge")
                    policy.noteBattery(80, "discharging"); policy.noteBattery(80, "paused"); wait(100)
                    check(face.gesture === "", "unplugging or pausing is silent")

                    // Recording: no idle gestures, a red glint, then relief.
                    policy.recording = true; policy.blocked = true
                    check(face.recordingAware && !policy.tryMischief(Date.now() + 700000, 0.001), "recording shows the glint and keeps the face still")
                    policy.blocked = false; policy.recording = false
                    check(!face.recordingAware, "glint ends with the capture")
                    check(policy.react("relief") && face.gesture === "relief", "capture end relieves")
                    wait(150)
                    check(face.lid < 1 || face.squash < 1, "relief blinks slowly and exhales")
                    chip.mood = "finished"
                    check(face.gesture === "relief", "saved celebration does not trample the relief")
                    chip.mood = "rest"
                    wait(1000)
                    check(still(face), "relief ends in stillness")

                    // Authorization: the prompt blocks idle gestures but not its own verdict.
                    policy.blocked = true
                    check(!policy.react("no") && face.gesture === "", "authorization needs the surface mode")
                    check(policy.react("no", "surface") && face.gesture === "no", "wrong password shakes no")
                    wait(300)
                    check(face.wary && Math.abs(face.shake) > 0, "gaze shakes with a wary lid: " + face.shake)
                    wait(300)
                    check(face.droop > 0.1, "upper lid lowers: " + face.droop)
                    wait(1100)
                    check(still(face), "no ends in stillness")
                    tryVerify(() => face.droop === 0, 2000, "wary lid lifts")
                    check(policy.react("wink", "surface") && face.gesture === "wink", "success winks")
                    wait(1200)
                    check(still(face), "wink ends in stillness")
                    policy.blocked = false

                    // Every reaction cancels cleanly and never outlives its conditions.
                    for (const kind of ["surprised", "stretch", "content", "no", "relief"]) {
                        for (const stop of ["reduced", "hidden", "suspended", "blocked", "asleep"]) {
                            face.play(kind); wait(250)
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
                    policy.reduced = true
                    check(!policy.react("stretch") && !policy.react("surprised", "defer") && policy.deferredGesture === "", "reduced refuses every reaction")
                    policy.reduced = false
                    face.reduced = true
                    face.play("no"); face.play("relief"); face.play("stretch"); face.play("content"); wait(200)
                    check(still(face), "reduced face refuses the new gestures")
                    face.reduced = false

                    // The option silences all of it.
                    policy.active = false; policy.react("surprised", "defer"); policy.active = true
                    check(policy.deferredGesture === "surprised", "a deferred gesture is waiting")
                    policy.noteBattery(15, "discharging"); policy.recording = true
                    check(policy.tired && face.recordingAware, "state shows with the option on")
                    setOption(false)
                    check(policy.deferredGesture === "" && !policy.tired && !face.tired && !face.recordingAware, "disabling clears the waiting gesture and states")
                    for (const [kind, mode] of [["surprised", "defer"], ["relief", ""], ["no", "surface"], ["wink", "surface"]])
                        check(!policy.react(kind, mode), kind + " is silent with the option off")
                    policy.noteBattery(50, "charging"); policy.noteBattery(100, "charging"); policy.noteBattery(14, "discharging")
                    wait(300)
                    check(face.gesture === "" && !policy.tired && policy.batteryKind === "discharging", "battery gestures are silent with the option off")
                    policy.recording = false
                    setOption(true)
                    face.settle()
                    console.log("PASS: Iris system reactions (notification, battery, recording, authorization), stillness, cancellation and reactToSystem opt-out")
                    exitTimer.start()
                } catch (error) { console.error("FAIL: Iris system " + error); Qt.exit(1) }
            }
        }
    }
}
