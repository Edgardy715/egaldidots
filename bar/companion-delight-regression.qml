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
        width: 780; height: 360
        title: "Isla · tacto e historias · prueba"
        color: Theme.surface
        property string phase: "Reposo"
        Text {
            x: 32; y: 30
            text: window.phase
            color: Theme.foreground
            font.family: Theme.font; font.pixelSize: 22
        }
        Text {
            x: 32; y: 70
            text: "Tamaño real                         Escala 1,5                                  Detalle ×3"
            color: Theme.iconSecondary
            font.family: Theme.font; font.pixelSize: 14
        }
        CompanionBehavior { id: policy; active: true }
        IslandActivityChip { id: actual; x: 55; y: 165; companionContext: policy }
        IslandActivityChip { id: medium; x: 280; y: 155; s: 1.5; coreH: 38 * s; companionContext: policy }
        IslandActivityChip { id: detail; x: 550; y: 125; s: 3; coreH: 38 * s; companionContext: policy }
        Timer { id: exitTimer; interval: 120; onTriggered: Qt.quit() }
        TestCase {
            name: "CompanionDelight"
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
            function still(face) {
                return face.gesture === "" && face.winkLid === 1 && face.lowerLid === 0
                    && face.breath === 1 && face.squash === 1 && face.tilt === 0
                    && face.touch === 0 && face.materialX === 0 && face.materialY === 0
                    && face.materialScaleX === 1 && face.materialScaleY === 1
                    && !face.visitorOwnsGaze && face.visitProgress === 0 && !findChild(face, "companionVisitor").visible
            }
            function test_touchAndStory() {
                try {
                    Config.update({appearance: {reduceMotion: false}})
                    mouseMove(window.contentItem, 5, 5)
                    wait(350)
                    const chips = [actual, medium, detail]
                    const faces = chips.map(chip => findChild(chip, "activityCompanion"))
                    shot("rest", "Reposo · superficie quieta")
                    for (const position of [-1, 1]) {
                        for (const face of faces) { face.stroke(120, position, position); face.stroke(120, position, position); face.stroke(120, position, position) }
                        wait(140)
                        for (let i = 0; i < chips.length; i++) {
                            const face = faces[i], chip = chips[i]
                            const plate = findChild(chip, "companionHoverPlate")
                            check(face.touch > 0.15 && face.materialScaleX < 1 && face.materialScaleY > 1, "touch deforms the material: scale=" + chip.s + " touch=" + face.touch + " target=" + face.touchTarget + " gesture=" + face.gesture + " interactive=" + face.interactive)
                            check(face.materialX * position > 0, "material follows the hand")
                            const a = plate.mapToItem(chip, 0, 0), b = plate.mapToItem(chip, plate.width, plate.height)
                            check(a.x >= -0.01 && b.x <= chip.width + 0.01 && a.y >= 0 && b.y <= chip.height, "material stays inside the chip at scale " + chip.s)
                            check(chip.width === 36 * chip.s, "touch preserves layout width")
                        }
                        shot(position < 0 ? "touch-left" : "touch-right", "Caricia · ojos y superficie siguen la mano")
                        wait(600)
                    }
                    check(faces.every(still), "release settles without another event")
                    for (let click = 0; click < 4; click++) {
                        for (const face of faces) face.interact()
                        if (click < 3) wait(120)
                    }
                    wait(420)
                    check(faces.every(face => face.lowerLid > 0.4 && face.breath > 1.04), "story anticipates a sneeze")
                    check(faces.every(face => !face.cheerful && face.smile < 0.15), "fourth click clears the third click's smile so anticipation remains visible")
                    shot("anticipation", "Una pequeña historia · viene un estornudo…")
                    wait(250)
                    shot("relief", "…lo contiene y te hace un guiño")
                    wait(1200)
                    check(faces.every(still), "story returns to stillness")
                    for (const delay of [120, 650, 1100]) {
                        const face = faces[0]
                        face.play("holdSneeze"); wait(delay); face.stroke(120, 1, 0.7)
                        check(face.gesture === "" && face.tilt === 0 && face.breath === 1, "touch interrupts every story phase")
                        wait(650)
                        check(still(face), "interrupted story has no delayed action")
                    }
                    const face = faces[0]
                    face.play("holdSneeze"); wait(200); face.approachPointer(true)
                    check(face.gesture === "" && face.lowerLid === 0, "approaching interrupts the story")
                    face.settle()
                    for (const stop of ["reduced", "hidden", "suspended", "blocked", "asleep"]) {
                        face.play("holdSneeze"); wait(120)
                        if (stop === "reduced") face.reduced = true
                        else if (stop === "hidden") actual.visible = false
                        else if (stop === "suspended") policy.active = false
                        else if (stop === "blocked") policy.blocked = true
                        else face.asleep = true
                        check(still(face) || (stop === "asleep" && face.gesture === "yawn"), stop + " cancels story")
                        face.reduced = false; actual.visible = true; policy.active = true; policy.blocked = false; face.asleep = false; face.settle()
                    }
                    for (const f of faces) { f.settle(); f.play("firefly") }
                    wait(800)
                    for (const f of faces) {
                        const light = findChild(f, "companionVisitor")
                        check(light.visible && light.opacity > 0.5, "firefly appears at scale " + f.s)
                        check(f.gazeX < -0.5 * f.s && f.gazeY < 0, "eyes notice the light on the left: s=" + f.s + " gaze=" + f.gazeX + "," + f.gazeY + " progress=" + f.visitProgress)
                        check(light.x >= 0 && light.x + light.width <= f.width && light.y >= 0, "firefly fits the face")
                    }
                    shot("firefly-left", "Una visita diminuta · descubre la luciérnaga")
                    wait(900)
                    for (const f of faces) check(f.gazeX > 0.5 * f.s, "eyes follow the light across the face")
                    shot("firefly-right", "La sigue con la mirada · después vuelve al reposo")
                    wait(1600)
                    check(faces.every(still), "firefly departs without another event")
                    for (const delay of [120, 1100, 2300]) {
                        face.play("firefly"); wait(delay); face.stroke(120, 1, 0.7)
                        check(face.gesture === "" && face.visitProgress === 0, "touch cancels every firefly phase")
                        wait(650); check(still(face), "interrupted firefly cannot return")
                    }
                    face.play("firefly"); wait(120); face.approachPointer(true)
                    check(!face.visiting && face.visitProgress === 0, "approaching cancels the firefly")
                    face.settle()
                    for (const stop of ["reduced", "hidden", "suspended", "blocked", "asleep"]) {
                        face.play("firefly"); wait(120)
                        if (stop === "reduced") face.reduced = true
                        else if (stop === "hidden") actual.visible = false
                        else if (stop === "suspended") policy.active = false
                        else if (stop === "blocked") policy.blocked = true
                        else face.asleep = true
                        check(!face.visiting && face.visitProgress === 0, stop + " cancels the firefly")
                        face.reduced = false; actual.visible = true; policy.active = true; policy.blocked = false; face.asleep = false; face.settle()
                    }
                    face.lookX = 1; face.lookY = 1
                    wait(2200)
                    const initialX = face.gazeX, initialY = face.gazeY
                    check(initialX > 2 * face.s, "nonzero gaze before continuity check")
                    face.play("firefly")
                    check(Math.abs(face.gazeX - initialX) < 0.01 && Math.abs(face.gazeY - initialY) < 0.01, "firefly starts at the current gaze")
                    wait(1100)
                    const interruptedX = face.gazeX, interruptedY = face.gazeY
                    face.stopMoment()
                    check(Math.abs(face.gazeX - interruptedX) < 0.01 && Math.abs(face.gazeY - interruptedY) < 0.01, "interruption preserves gaze for spring return: before=" + interruptedX + "," + interruptedY + " after=" + face.gazeX + "," + face.gazeY)
                    face.lookX = 0; face.lookY = 0; face.settle()
                    policy.lastMischief = 0
                    check(policy.tryMischief(700000, 0.01) && face.visiting, "existing rare opportunity launches a visitor")
                    check(!policy.tryMischief(800000, 0.01), "firefly keeps ten minute cadence")
                    for (const f of faces) f.settle()
                    policy.options = Object.assign({}, policy.options, {followPointer: false})
                    face.stroke(120, 1, 1); wait(120)
                    check(face.touch > 0 && face.materialX === 0, "followPointer opt-out keeps touch without lateral tracking")
                    face.reduced = true
                    check(still(face), "reduced resets material immediately")
                    face.stroke(120, 1, 1); face.play("holdSneeze"); face.play("firefly"); wait(300)
                    check(still(face), "reduced refuses new motion")
                    for (const f of faces) f.settle()
                    shot("settled", "Reposo · sin movimiento pendiente")
                    console.log("PASS: companion material, story phases, firefly gaze and cadence, interruptions, scales, opt-out, reduced and hidden")
                    exitTimer.start()
                } catch (error) { console.error("FAIL: companion delight " + error); Qt.exit(1) }
            }
        }
    }
}
