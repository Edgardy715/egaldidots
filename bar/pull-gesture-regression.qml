pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "Singletons"
import "Singletons/Settings.js" as Settings
import "components"
import "components/RubberBand.js" as RubberBand
import "settings"

ShellRoot {
    id: test
    settings.watchFiles: false
    property bool done: false
    Timer { interval: 20; running: test.done; onTriggered: Qt.quit() }
    Component {
        id: motionFactory
        PillMorphMotion {
            restW: 150; coreH: 38; targetW: surfaceOpen ? 650 : 150
            targetH: surfaceOpen ? 438 : 38; targetRadius: surfaceOpen ? 24 : 19
            manualStep: true
        }
    }
    SurfaceRouter { id: navigation; focusedMonitorName: "focused" }
    OverlayInputPolicy {
        id: inputPolicy
        surface: pill.surface
        pointerPull: (pill.pullGesture.candidate || pill.pullGesture.active) && !pill.pullGesture.scrolling
    }
    SignalSpy { id: focusChanges; target: inputPolicy; signalName: "exclusiveFocusChanged" }
    SignalSpy { id: maskChanges; target: inputPolicy; signalName: "maskModeChanged" }
    FileView { id: diskConfig; path: Config.configFile; printErrors: false }
    SignalSpy { id: saved; target: Config; signalName: "saved" }
    Component {
        id: gestureFactory
        PillPullGesture {
            target: "calendar"
            plannedW: 650; plannedH: 438; plannedRadius: 24
            rubberBand: (value, limit) => RubberBand.rubberBand(value, limit, 0.55)
            onPrepare: name => { motion.surfaceName = name; motion.surfaceOpen = true }
            onSettled: (name, opened) => { motion.surfaceName = opened ? name : ""; motion.surfaceOpen = opened }
        }
    }
    Window {
        id: scene
        width: 1000; height: 750; visible: true
        Pill {
            id: pill
            x: (scene.width - width) / 2; y: 10
            notificationsEnabled: false
            pullTarget: "calendar"
            pullMotion.manualStep: true
            onPullPrepare: name => surface = name
            onPullSettled: (name, opened) => surface = opened ? name : ""
            onRequestSurface: name => { scene.clicks++; surface = name }
        }
        property int clicks: 0
        Loader {
            id: edots
            anchors.fill: parent
            active: false
            sourceComponent: EdotsWindow { page: 2 }
        }
        TestCase {
            id: checks
            name: "PillPull"
            when: scene.visible && Config.loaded
            function check(ok, message) {
                if (!ok) { console.error("FAIL:", message); Qt.exit(1); throw new Error(message) }
            }
            function near(a, b, message, epsilon) {
                check(Math.abs(a - b) < (epsilon || 1), message + " actual=" + a + " expected=" + b)
            }
            function pair(opened) {
                const m = motionFactory.createObject(scene.contentItem, {surfaceOpen: !!opened})
                m.springW = m.width; m.springH = m.height
                const g = gestureFactory.createObject(test, {motion: m})
                return {m: m, g: g}
            }
            function drop(p) { p.g.destroy(); p.m.destroy() }
            function surfaceHost(item) {
                if (item instanceof PillSurfaceHost) return item
                for (const child of item.children || []) {
                    const found = surfaceHost(child)
                    if (found) return found
                }
                return null
            }
            function cleanupTestCase() { test.done = true }
            function test_gesture() {
                Config.update({appearance: {reduceMotion: false, motionScale: 1}})
                let p = pair(false), m = p.m, g = p.g
                g.press(0, 0, 0, false, "")
                check(!g.move(30, 7, 10), "horizontal motion does not start")
                check(!g.move(0, 6, 20), "strict six pixel threshold")
                for (const d of [10, 80, 200, 390, 400]) {
                    g.move(0, d, 50 + d)
                    near(m.height, 38 + d, "1:1 height at " + d)
                    near(m.width, 150 + 500 * d / 400, "interpolated width at " + d)
                    near(m.radius, 19 + 5 * d / 400, "interpolated radius at " + d, 0.01)
                }
                g.move(0, 500, 600)
                check(m.height > 438 && m.height < 478, "upper rubber band bounded by 40")
                near(m.height, 438 + RubberBand.rubberBand(100, 40, 0.55), "shared rubber formula")
                g.move(0, -30, 700)
                check(m.height < 38 && m.height > 28, "lower rubber band bounded by 10")
                g.cancel(); m.step(2); drop(p)

                p = pair(false); m = p.m; g = p.g
                g.press(0, 0, 0, false, "")
                for (const t of [10, 20, 40, 60, 80]) g.move(0, t, t)
                check(g.progress < 0.5, "fling starts below halfway")
                check(g.release(80), "fling opens below halfway")
                near(m.velH, 1000, "regression velocity", 100)
                const h = m.height, w = m.width, vh = m.velH, vw = m.velW
                m.step(1 / 60)
                near(m.height, h + vh / 60, "handoff extrapolated height")
                near(m.width, w + vw / 60, "handoff extrapolated width")
                m.step(2); check(!m.integrating, "spring settles silently")
                drop(p)

                p = pair(false); m = p.m; g = p.g
                g.press(0, 0, 0, false, ""); g.move(0, 60, 500)
                check(!g.release(700), "slow short pull closes")
                m.step(1 / 60); m.step(2)
                near(m.height, 38, "short pull returns to rest"); check(!m.integrating, "rest has no integrator")
                drop(p)

                p = pair(true); m = p.m; g = p.g
                g.press(0, 0, 0, true, "calendar")
                g.move(0, -100, 500); near(m.height, 338, "closing follows pointer")
                g.move(0, -300, 1000); near(m.height, 138, "closing follows pointer lower")
                check(!g.release(1200), "slow close below half closes")
                m.step(1 / 60); m.step(2); drop(p)

                p = pair(true); m = p.m; g = p.g
                g.press(0, 0, 0, true, "calendar")
                for (const t of [10, 20, 40, 60, 80]) g.move(0, -t, t)
                check(g.progress > 0.5 && !g.release(80), "upward fling closes above halfway")
                m.step(1 / 60); m.step(2); drop(p)

                p = pair(false); m = p.m; g = p.g
                m.surfaceOpen = true; m.surfaceName = "calendar"
                m.step(0.04)
                const caughtH = m.height, caughtW = m.width, caughtV = m.velH
                g.press(0, 0, 50, true, "calendar")
                near(m.height, caughtH, "catch preserves height")
                near(m.width, caughtW, "catch preserves width")
                near(m.velH, caughtV, "catch preserves velocity", 0.001)
                m.step(0.1); near(m.height, caughtH, "caught spring stays still")
                g.move(0, 15, 70); near(m.height, caughtH + 15, "catch continues downward")
                g.release(70); m.step(1 / 60); m.step(2); drop(p)

                p = pair(true); m = p.m; g = p.g
                m.surfaceOpen = false; m.step(0.04)
                const closingH = m.height, closingV = m.velH
                g.press(0, 0, 50, false, "")
                near(m.height, closingH, "catch closing preserves height")
                near(m.velH, closingV, "catch closing preserves velocity", 0.001)
                g.move(0, -15, 70)
                near(m.height, closingH - 15, "caught closing continues upward")
                g.release(70); m.step(1 / 60); m.step(2); drop(p)

                p = pair(false); m = p.m; g = p.g
                check(!g.wheel(0, 0, 0, false, "", true), "angle-only wheel ignored")
                check(!g.wheel(0, -20, 0, true, "notifs", false), "scrolled list retains wheel")
                check(g.wheel(0, 30, 10, false, "", true), "pixel wheel begins pull")
                near(m.height, 68, "pixel wheel 1:1")
                g.release(10); m.step(1 / 60); m.step(2); drop(p)

                for (const inverted of [false, true]) {
                    p = pair(false); m = p.m; g = p.g
                    check(g.wheel(0, inverted ? -30 : 30, 10, false, "", true, inverted), "physical downward scroll opens, inverted=" + inverted)
                    near(m.height, 68, "physical scroll follows fingers regardless of natural scrolling")
                    g.cancel(); m.step(2); drop(p)
                    p = pair(true); m = p.m; g = p.g
                    check(!g.wheel(0, inverted ? 30 : -30, 10, true, "notifs", false, inverted), "displaced list retains physical upward scroll")
                    check(g.wheel(0, inverted ? 30 : -30, 10, true, "calendar", true, inverted), "physical upward scroll closes, inverted=" + inverted)
                    near(m.height, 408, "physical upward scroll closes 1:1")
                    g.cancel(); m.step(2); drop(p)
                }

                p = pair(false); m = p.m; g = p.g
                m.reduceMotion = true; g.reduceMotion = true
                g.press(0, 0, 0, false, ""); g.move(0, 300, 1000)
                near(m.height, 38, "reduced motion stays still until release")
                check(g.release(1200), "reduced motion threshold opens")
                near(m.height, 438, "reduced motion snaps on release")
                check(!m.integrating && !m.grabbed, "reduced motion has no spring")
                drop(p)
                p = pair(false); p.g.enabled = false
                check(!p.g.press(0, 0, 0, false, ""), "disabled gesture ignores press")
                check(!p.g.wheel(0, 50, 0, false, "", true), "disabled gesture ignores wheel")
                drop(p)
                p = pair(false); m = p.m; g = p.g
                g.press(0, 0, 0, false, ""); g.move(0, 80, 80)
                m.reduceMotion = true; g.reduceMotion = true
                check(!m.grabbed && !g.candidate, "enabling reduced motion cancels an existing grab")
                drop(p)

                p = pair(false); m = p.m; g = p.g
                g.wheel(0, 30, Date.now(), false, "", true)
                wait(Motion.pullScrollTimeout + 50)
                check(!g.candidate && !g.scrollEnd.running, "pixel wheel ends after 120 ms silence")
                m.step(1 / 60); m.step(2); drop(p)

                // Deferred wheel path: acceptance is pure, side effects run after Qt's delivery.
                p = pair(false); m = p.m; g = p.g
                check(g.wheelWanted(0, 30, false, true, false), "wheelWanted accepts downward open")
                check(!g.wheelWanted(0, -30, false, true, false), "wheelWanted rejects upward while closed")
                check(!g.wheelWanted(0, -30, true, false, false), "wheelWanted rejects displaced list")
                check(!g.wheelWanted(0, -30, true, true, false), "wheelWanted never closes an open surface")
                check(!g.wheelWanted(30, 5, false, true, false), "wheelWanted rejects horizontal")
                check(!g.candidate && !g.scrolling && m.height === 38, "wheelWanted has no side effects")
                const t0 = Date.now()
                g.queueWheel(0, 30, t0, false, "", true, false)
                check(!g.scrolling && m.height === 38, "queued wheel waits for the event loop")
                wait(0)
                check(g.scrolling, "flushed wheel begins pull")
                near(m.height, 68, "flushed wheel stays 1:1")
                check(g.wheelWanted(0, -5, false, true, false), "active scroll keeps every step")
                for (let i = 1; i <= 6; ++i) g.queueWheel(0, 30, t0 + i * 16, false, "", true, false)
                g.queueWheelRelease(t0 + 6 * 16)   // Pill passes the last step time on timeout
                wait(0)
                check(!g.scrolling, "queued release ends the scroll")
                m.step(1 / 60)
                check(m.velH > 0, "timeout release keeps flick velocity from the last step: " + m.velH)
                m.step(2)
                near(m.height, 438, "fast queued flick opens")
                drop(p)
                check(Settings.defaults({}).gestures.enabled && Settings.defaults({}).gestures.pullTarget === "auto", "gesture defaults")
                check(!Settings.validate({gestures: {pullTarget: "bad"}}, {}).ok, "invalid target rejected")
                check(!Settings.validate({gestures: {enabled: "yes"}}, {}).ok, "invalid boolean rejected")
            }
            function test_pointer() {
                pill.surface = ""; pill.pullMotion.step(2)
                wait(100)
                const rest = pill.height
                const p = pill.mapToItem(scene.contentItem, pill.width / 2, pill.height / 2)
                focusChanges.clear(); maskChanges.clear()
                mousePress(pill, pill.width / 2, pill.height / 2, Qt.LeftButton)
                wait(10)
                check(pill.pullGesture.candidate, "passive press observes real mouse input")
                check(!inputPolicy.exclusiveFocus && inputPolicy.maskMode === "pill", "press latches rest input policy")
                mouseMove(scene.contentItem, p.x, p.y + 30, 30)
                mouseMove(scene.contentItem, p.x, p.y + 80, 30)
                check(pill.pullGesture.active, "vertical handler grabs real pointer")
                near(pill.height, rest + 80, "real pointer tracks 1:1")
                near(pill.surfaceContentProgress, 80 / (pill.targetH - pill.coreH), "content follows gesture progress", 0.01)
                const host = surfaceHost(pill)
                near(host.layoutHeight, pill.targetH, "content layout stays at destination height")
                near(host.layoutWidth, pill.targetW, "content layout stays at destination width")
                near(host.opacity, 0, "content stays hidden at +80 pixels", 0.001)
                check(!inputPolicy.exclusiveFocus && inputPolicy.maskMode === "pill", "prepare cannot change input policy during pointer grab")
                check(focusChanges.count === 0 && maskChanges.count === 0, "opening press emits no transient focus or mask changes")
                // Content incubates asynchronously; test its gesture fade once ready.
                tryVerify(() => !!pill.surfaceItem && host.loadReveal === 1, 3000)
                near(host.opacity, 0, "loaded content also stays hidden at +80 pixels", 0.001)
                const span = pill.targetH - pill.coreH
                mouseMove(scene.contentItem, p.x, p.y + span * 0.8, 100)
                check(host.opacity > 0 && host.opacity < 1, "content fades as geometry approaches destination: opacity=" + host.opacity + " exposure=" + host.gestureExposure)
                mouseMove(scene.contentItem, p.x, p.y + span * 0.96, 100)
                near(host.opacity, 1, "content fully revealed near destination", 0.01)
                near(host.layoutWidth, pill.targetW, "reveal never lays out at partial width")
                mouseRelease(scene.contentItem, p.x, p.y + span * 0.96, Qt.LeftButton)
                check(!pill.pullGesture.candidate && !pill.pullMotion.grabbed, "real release hands off")
                check(inputPolicy.exclusiveFocus && inputPolicy.maskMode === "full" && inputPolicy.escapeShortcutEnabled, "release open immediately restores keyboard and Escape")
                pill.pullMotion.step(1 / 60); pill.pullMotion.step(2)
                pill.surface = ""; pill.pullMotion.step(2); wait(100)
                const before = scene.clicks
                // El reloj ya no está en el centro de la pill: se pulsa su propia zona.
                const clockHit = (function find(item) {
                    if (item.objectName === "clockCalendarHit") return item
                    for (const child of item.children) { const found = find(child); if (found) return found }
                    return null
                })(pill)
                check(clockHit !== null, "clock hit area exists")
                const clockPoint = clockHit.mapToItem(pill, clockHit.width / 2, clockHit.height / 2)
                mouseClick(pill, clockPoint.x, clockPoint.y, Qt.LeftButton)
                check(scene.clicks === before + 1, "simple click keeps existing calendar action")
                check(!pill.pullMotion.grabbed, "click leaves no grab")
                pill.pullMotion.step(2)
                tryVerify(() => !!pill.surfaceItem, 3000)
                check(!pill.pullCanStart(Qt.point(pill.width / 2, pill.height / 2)), "calendar controls retain their pointer")
                check(pill.pullCanStart(Qt.point(pill.width / 2, 4)), "free surface rim is a grip")
                pill.y = 120
                const openH = pill.height
                const top = pill.mapToItem(scene.contentItem, pill.width / 2, 4)
                focusChanges.clear(); maskChanges.clear()
                mousePress(pill, pill.width / 2, 4, Qt.LeftButton)
                check(pill.pullGesture.candidate, "open rim observes press")
                mouseMove(scene.contentItem, top.x, top.y - 30, 30)
                mouseMove(scene.contentItem, top.x, top.y - 80, 30)
                check(pill.pullGesture.active, "upward handler grabs pointer outside pill")
                near(pill.height, openH - 80, "real open-surface pointer closes 1:1")
                mouseMove(scene.contentItem, top.x, top.y - (openH - pill.coreH) * 0.55, 100)
                near(host.opacity, 0, "closing withdraws content before geometry", 0.001)
                check(pill.height > pill.coreH && inputPolicy.exclusiveFocus && inputPolicy.maskMode === "full", "closing retains open input policy until release")
                check(focusChanges.count === 0 && maskChanges.count === 0, "closing press emits no transient focus or mask changes")
                mouseRelease(scene.contentItem, top.x, top.y - (openH - pill.coreH) * 0.55, Qt.LeftButton)
                check(!inputPolicy.exclusiveFocus && inputPolicy.maskMode === "pill", "close release leaves no modal capture")
                pill.pullMotion.step(1 / 60); pill.pullMotion.step(2)
                pill.surface = "wallpaper"
                check(!pill.pullCanStart(Qt.point(4, 4)) && !pill.pullCanWheel(Qt.point(4, 4)), "wallpaper drag and wheel excluded")
                pill.surface = ""; pill.pullMotion.step(2)
                mousePress(pill, pill.width / 2, pill.height / 2, Qt.LeftButton)
                const again = pill.mapToItem(scene.contentItem, pill.width / 2, pill.height / 2)
                mouseMove(scene.contentItem, again.x, again.y + 30, 30)
                mouseMove(scene.contentItem, again.x, again.y + 80, 30)
                check(pill.pullGesture.active, "pull active before external dismissal")
                pill.surface = ""
                check(!pill.pullGesture.candidate && !pill.pullMotion.grabbed, "external close cancels gesture")
                mouseRelease(scene.contentItem, again.x, again.y + 80, Qt.LeftButton)
                check(pill.surface === "", "release cannot undo external close")
                pill.pullMotion.step(1 / 60); pill.pullMotion.step(2)
                wait(100)
                check(!pill.pullMotion.integrating && !pill.pullGesture.scrollEnd.running
                    && !host.contentLayerActive, "rest has no spring, gesture timer or content layer")

            }
            function textExists(item, value) {
                if (item.text !== undefined && item.text === value && item.visible) return true
                for (const child of item.children || []) if (textExists(child, value)) return true
                return false
            }
            function test_pull_route() {
                navigation.present("", "")
                navigation.mediaAvailable = true
                for (const target of ["utils", "media", "notifs", "calendar"]) {
                    check(navigation.pull("", target), "IPC route accepts " + target)
                    check(navigation.openMon === "focused" && navigation.openSurface === target, "IPC resolves focused monitor")
                    check(navigation.pull("", target) && navigation.openSurface === "", "IPC toggles " + target + " closed")
                }
                check(navigation.pull("", "auto", undefined, true) && navigation.openSurface === "media", "auto picks displayed media")
                check(navigation.pull("", "auto", undefined, true) && navigation.openSurface === "", "auto toggles displayed media closed")
                check(navigation.pull("", "auto", undefined, false) && navigation.openSurface === "utils", "auto without displayed media picks utils")
                check(navigation.pull("other", "utils") && navigation.openMon === "other", "toggle opens on requested monitor")
                check(!navigation.pull("", "bad") && navigation.openMon === "other", "invalid IPC target leaves route untouched")
                navigation.present("", ""); navigation.mediaAvailable = false
                check(!navigation.pull("", "media"), "IPC rejects unavailable media")
                check(navigation.pull("", "auto", undefined, true) && navigation.openSurface === "utils", "auto falls back when media unavailable")
                navigation.present("focused", "auth")
                check(!navigation.pull("", "calendar") && navigation.openSurface === "auth", "IPC preserves authentication")
                navigation.present("", "")
            }
            function test_release_settle() {
                const host = surfaceHost(pill)
                pill.y = 10
                pill.pullTarget = "utils"
                // Exercise both deterministic 60 Hz integration and FrameAnimation.
                for (const manual of [true, false]) {
                    pill.surface = ""; pill.pullMotion.step(2); wait(100)
                    const p = pill.mapToItem(scene.contentItem, pill.width / 2, pill.height / 2)
                    mousePress(pill, pill.width / 2, pill.height / 2, Qt.LeftButton)
                    for (let i = 1; i <= 30; ++i)
                        mouseMove(scene.contentItem, p.x, p.y + i * 10, 10)
                    tryVerify(() => host.displayedSurface === "utils" && !!pill.surfaceItem && host.loadReveal === 1, 3000)
                    wait(100)
                    near(pill.pullGesture.destinationH, pill.targetH, "pull destination follows measured utils height", 0.001)
                    near(pill.pullGesture.plannedH, pill.targetH, "planned utils height uses actual surface target", 0.001)
                    near(pill.targetW, IslandGeometry.utilitiesSurface.width * pill.s, "utils width uses canonical surface size", 0.001)
                    near(pill.targetH, Math.min(IslandGeometry.utilitiesSurface.height * pill.s, pill.surfaceItem.contentHeightHint),
                        "utils height uses measured content capped by canonical size", 0.001)
                    near(pill.height, pill.targetH + RubberBand.rubberBand(pill.coreH + 300 - pill.targetH, Motion.pullOverdrag * pill.s, 0.55),
                        "300px drag uses rubber above actual utils height", 0.001)
                    const heldW = pill.width, heldH = pill.height
                    mouseRelease(scene.contentItem, p.x, p.y + 300, Qt.LeftButton)
                    check(pill.surface === "utils" && !pill.pullMotion.grabbed, "300px held pull releases open")
                    near(pill.width, heldW, "release preserves held width", 0.001)
                    near(pill.height, heldH, "release preserves held height", 0.001)
                    if (manual) {
                        for (let frame = 0; frame < 36; ++frame) pill.pullMotion.step(1 / 60)
                    } else {
                        pill.pullMotion.manualStep = false
                        wait(600)
                        pill.pullMotion.manualStep = true
                    }
                    const mode = manual ? "simulated" : "FrameAnimation"
                    check(!pill.pullMotion.integrating, "released utils settles within 600ms: " + mode)
                    check(!pill.pullMotion.pullRevealing, "settled utils exits pull reveal within 600ms: " + mode)
                    near(pill.surfaceContentProgress, 1, "settled utils content fully revealed: " + mode, 0.001)
                    near(host.opacity, 1, "settled utils opacity full: " + mode, 0.001)
                    near(pill.surfaceItem.opacity, 1, "settled surface itself fully opaque: " + mode, 0.001)
                    check(!host.contentLayerActive, "settled utils has no materialization blur: " + mode)
                    near(pill.width, pill.targetW, "settled width equals normal surface target: " + mode, 0.001)
                    near(pill.height, pill.targetH, "settled height equals normal measured surface target: " + mode, 0.001)
                }
                pill.surface = ""; pill.pullMotion.step(2); wait(100)
                pill.pullTarget = "calendar"
                console.log("PASS: held 300px utils drag, live measured destination, rubber, full content/opacity, no blur or pending integration within 600ms (60Hz + FrameAnimation)")
            }
            function test_settings() {
                check(Config.configFile.startsWith("/tmp/"), "persistence test uses temporary ISLA_CONFIG")
                check(Config.update({gestures: {enabled: false, pullTarget: "notifs"}, regional: {language: "es"}}).ok, "valid gesture patch")
                check(Config.save(), "save accepted")
                tryCompare(saved, "count", 1, 3000)
                diskConfig.reload()
                tryVerify(() => {
                    try { const d = JSON.parse(diskConfig.text()); return d.gestures.enabled === false && d.gestures.pullTarget === "notifs" }
                    catch (e) { return false }
                }, 3000)
                Config.update({gestures: {enabled: true, pullTarget: "media"}})
                Config.discard()
                check(Config.snapshot().effective.gestures.enabled === false && Config.snapshot().effective.gestures.pullTarget === "notifs", "discard restores persisted settings")
                edots.active = true
                tryVerify(() => edots.item && textExists(edots.item, "Gestos de arrastre") && textExists(edots.item, "Destino del gesto"), 3000)
                Config.update({regional: {language: "en"}})
                tryVerify(() => textExists(edots.item, "Drag gestures") && textExists(edots.item, "Gesture destination"), 3000)
                edots.item.searchQuery = "Gesture destination"
                tryVerify(() => edots.item.resultCount === 1, 3000)
                check(textExists(edots.item, "Gesture destination"), "gesture settings searchable in Edots")
                edots.active = false
                Config.discard()
                console.log("PASS: pull tracking, rubber, regression velocity, handoff, close, catch, wheel timeout, reduced motion, disabled, real pointer/click, persisted settings and bilingual Edots")

            }
        }
    }
}
