import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "components/files"
import "Singletons"

// Run: ISLA_CONFIG=$(mktemp -u).json QT_QPA_PLATFORM=offscreen qs -p bar/files-motion-regression.qml
// Motion of the explorer against the real FilesView and a fixture under mktemp (never HOME): window
// opening, directional folder entry (interrupted too), sliding selection highlight, crumbs, thumbnail
// fade, reduceMotion and the hidden window. Any failed check prints "FAIL:" and exits non-zero;
// "PASS:" is printed only when every test reached its last line. Offscreen timing is a logic check
// (values, continuity, end states), not visual QA.
ShellRoot {
    id: suite
    settings.watchFiles: false
    readonly property int totalTests: 10
    property string root: ""
    property bool fixtureReady: false
    property int exitCode: 0
    property bool cleaned: false
    property bool finishing: false

    Process {
        id: maker
        running: true
        command: ["sh", "-c", `
            set -e
            root=$(mktemp -d "\${TMPDIR:-/tmp}/isla-files-test.XXXXXX")
            mkdir -p "$root/work/sub/deep/deeper" "$root/work/sub/big" "$root/work/other" "$root/data"
            (cd "$root/work/sub/big" && seq -f 'f%05g.txt' 1 20000 | xargs touch)
            for n in a.txt b.txt c.txt d.txt e.txt; do printf 'x' > "$root/work/$n"; done
            printf 'x' > "$root/work/sub/s1.txt"
            printf 'x' > "$root/work/sub/deep/x.txt"
            png='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='
            printf '%s' "$png" | base64 -d > "$root/work/other/pic.png"
            printf '%s' "$root"`]
        stdout: StdioCollector { onStreamFinished: { suite.root = text.trim(); suite.fixtureReady = suite.root.length > 0 } }
    }
    Process {
        id: cleaner
        command: ["rm", "-rf", suite.root]
        onExited: { suite.cleaned = true }
    }

    function finish(code) {
        if (code !== 0) exitCode = code
        if (finishing) return
        finishing = true
        deferExit.start()
    }
    Timer {
        id: deferExit
        interval: 300
        onTriggered: {
            if (suite.root.indexOf("/isla-files-test.") > 0) cleaner.running = true
            else suite.cleaned = true
        }
    }
    Timer { interval: 180000; running: true; onTriggered: { console.error("FAIL: files motion global watchdog"); suite.finish(1); Qt.exit(1) } }

    Component {
        id: viewComponent
        FilesView { anchors.fill: parent }
    }

    Window {
        id: window
        visible: true
        width: 1000
        height: 660
        color: Theme.background
        Item { id: host; anchors.fill: parent }

        TestCase {
            id: checks
            name: "FilesMotion"
            when: window.visible && suite.fixtureReady && Config.loaded
            property int reached: 0
            property var view: null

            function check(value, label) {
                if (suite.exitCode !== 0) throw Error("aborted after an earlier failure")
                if (!value) { console.error("FAIL: files motion", label); suite.finish(1); throw Error(label) }
            }
            function waitFor(fn, label, ms) {
                check(true, "")
                const deadline = Date.now() + 4 * (ms || 5000)
                while (Date.now() < deadline) {
                    let ok = false
                    try { ok = !!fn() } catch (e) { ok = false }
                    if (ok) return
                    wait(10)
                }
                check(false, "timeout: " + label)
            }
            function find(item, name) {
                if (!item) return null
                if (item.objectName === name) return item
                for (const child of item.children || []) { const hit = find(child, name); if (hit) return hit }
                return null
            }
            // Every animation-like object under `item`: Animations (duration + loops), FrameAnimations
            // (frameTime) and SpringValues (integrating). Walks `data` so resources are included.
            function motions(item, out, seen) {
                out = out || []; seen = seen || new Set()
                if (!item || seen.has(item)) return out
                seen.add(item)
                if (item.duration !== undefined && item.loops !== undefined && item.running !== undefined) out.push({ kind: "anim", o: item })
                else if (item.frameTime !== undefined && item.running !== undefined) out.push({ kind: "frame", o: item })
                if (item.integrating !== undefined && item.snap !== undefined) out.push({ kind: "spring", o: item })
                const kids = item.data || item.children || []
                for (const k of kids) motions(k, out, seen)
                if (item.contentItem && item.contentItem !== item) motions(item.contentItem, out, seen)
                if (item.item) motions(item.item, out, seen)
                return out
            }
            function busy(list) {
                return list.filter(m => m.kind === "spring" ? m.o.integrating && m.o.active : m.o.running)
            }
            function describe(list) {
                return list.map(m => m.kind + ":" + (m.o.parent ? m.o.parent.objectName || m.o.parent.toString() : "?")
                    + (m.kind === "anim" ? "/" + m.o.duration : "")).join(", ")
            }
            function nav() { return view.navTransition }
            function loader() { return find(view, "viewLoader") }
            function glass() { return find(view, "glass") }
            function grid() { return loader().item }
            function highlight() { return find(grid(), "selectionHighlight") }
            function bar() { return find(view, "pathBar") }
            function idx(name) { return view.model.indexOfName(name) }
            function go(path) {
                view.navigate(path)
                waitFor(() => view.path === path && view.model.ready, "navigated to " + path)
            }
            function settle(label) {
                waitFor(() => !view.animating, "settled: " + label, 6000)
            }
            // Follows a running entry sample by sample. A step in x is allowed only what the spring's own
            // velocity explains since the last change (+1 px): worstStep > 0 means a jump.
            function followEntry() {
                const out = { worstStep: -Infinity, maxFrozenMs: 0, reversed: false, fadeDrop: 0, samples: 0 }
                let lx = nav().offset, lv = nav().offsetVelocity, lf = nav().fade, changedAt = Date.now(), frozenFrom = Date.now()
                let lastDelta = 0
                while (nav().running) {
                    wait(8)
                    const now = Date.now(), x = nav().offset, v = nav().offsetVelocity, f = nav().fade
                    out.samples++
                    if (x !== lx || f !== lf) {
                        const allowed = (Math.abs(v) + Math.abs(lv)) / 2 * (now - changedAt) / 1000 * 1.3 + 1
                        out.worstStep = Math.max(out.worstStep, Math.abs(x - lx) - allowed)
                        const delta = x - lx
                        if (Math.abs(delta) > 0.05 && Math.abs(lastDelta) > 0.05 && delta * lastDelta < 0) out.reversed = true
                        if (Math.abs(delta) > 0.05) lastDelta = delta
                        out.fadeDrop = Math.max(out.fadeDrop, lf - f)
                        changedAt = now; frozenFrom = now
                    } else if (f < 0.98) {
                        out.maxFrozenMs = Math.max(out.maxFrozenMs, now - frozenFrom)
                    }
                    lx = x; lv = v; lf = f
                }
                if (out.worstStep === -Infinity) out.worstStep = 0
                return out
            }
            function finalPose(label) {
                const t = loader().transform[0]
                check(nav().fade === 1 && nav().offset === 0, label + ": nav ends at fade 1 / offset 0 (fade=" + nav().fade + " offset=" + nav().offset + ")")
                check(loader().opacity === 1 && t.x === 0, label + ": content ends exactly in place (opacity=" + loader().opacity + " x=" + t.x + ")")
            }
            function setReduce(on) {
                Config.update({ appearance: { reduceMotion: on } })
                waitFor(() => Flags.reduceMotion === on, "reduceMotion " + on)
            }
            function openView(path) {
                if (view) { view.destroy(); view = null; wait(30) }
                view = viewComponent.createObject(host, { startPath: path })
                check(view !== null, "FilesView created")
            }

            function initTestCase() {
                FileOps.environment = { XDG_DATA_HOME: suite.root + "/data" }
            }

            function test_00_isolated_config() {
                check((Quickshell.env("ISLA_CONFIG") || "").indexOf("/tmp/") === 0, "ISLA_CONFIG must point to a temporary file")
                check(!Flags.reduceMotion, "default: motion enabled")
                reached++
            }

            // 20 samples of the opening: glass opacity never decreases, the scale overshoots ~3 % at most
            // and the selection highlight never moves more than 1 px between frames (it is placed, it does
            // not slide in from 0,0 while the window unfolds).
            function test_01_opening_monotonic() {
                const work = suite.root + "/work"
                openView(work)
                const g = glass()
                check(g !== null, "glass found")
                check(view.opening, "opening spring runs on creation")
                check(g.scale >= Motion.materializeScale - 1e-6 && g.scale < 0.99, "opening starts near materializeScale (" + g.scale.toFixed(3) + ")")
                waitFor(() => view.model.ready && idx("b.txt") >= 0, "work listed")
                view.selection.select(idx("b.txt"))
                let lastOpacity = -1, lastX = NaN, lastY = NaN, maxScale = 0, maxJump = 0, samples = 0, firstHl = null
                for (; samples < 20; samples++) {
                    const o = g.opacity, hl = highlight()
                    check(o >= lastOpacity - 1e-9, "opening opacity is monotonic (" + lastOpacity.toFixed(3) + " -> " + o.toFixed(3) + " at sample " + samples + ")")
                    lastOpacity = o
                    maxScale = Math.max(maxScale, g.scale)
                    if (hl && hl.visible) {
                        if (!firstHl) {
                            firstHl = Qt.point(hl.x, hl.y)
                            const r = grid().positionAt(idx("b.txt"))
                            check(Math.abs(hl.x - r.x - grid().inset) < 1 || Math.abs(hl.x - r.x) < 1, "highlight appears on its item, not sliding in (hl.x=" + hl.x + " item.x=" + r.x + ")")
                        }
                        if (!isNaN(lastX)) maxJump = Math.max(maxJump, Math.abs(hl.x - lastX), Math.abs(hl.y - lastY))
                        lastX = hl.x; lastY = hl.y
                    }
                    wait(16)
                }
                check(maxJump <= 1, "highlight never jumps more than 1 px between samples during the opening (" + maxJump + ")")
                waitFor(() => !view.opening, "opening settles", 4000)
                check(g.opacity === 1 && g.scale === 1, "opening ends exactly at opacity 1 / scale 1 (" + g.opacity + ", " + g.scale + ")")
                const overshoot = (maxScale - Motion.materializeScale) / (1 - Motion.materializeScale) - 1
                console.log("INFO: files motion opening overshoot sampled", (overshoot * 100).toFixed(2) + "%")
                check(overshoot <= 0.04, "opening overshoot stays about 3 % (" + (overshoot * 100).toFixed(2) + "%)")
                reached++
            }

            // Into a folder the content enters from the right (+offset), up it enters from the left; both
            // with a fade, never shifted more than Motion.filesNavTravel, ending exactly in place.
            function test_02_directional_entry() {
                const work = suite.root + "/work"
                settle("before entry")
                finalPose("initial folder")
                go(work + "/sub")
                check(nav().running, "entering a folder runs the transition")
                check(nav().offset > 0 && nav().offset <= Motion.filesNavTravel + 1e-6, "into a folder: enters from the right, at most travel (" + nav().offset + ")")
                check(nav().fade < 1, "into a folder: fades in (" + nav().fade + ")")
                let maxAbs = 0
                while (nav().running) { maxAbs = Math.max(maxAbs, Math.abs(nav().offset)); check(loader().opacity === nav().fade, "content opacity is the nav fade"); wait(8) }
                check(maxAbs <= Motion.filesNavTravel + 1e-6, "offset never exceeds the travel (" + maxAbs + ")")
                settle("after entry")
                finalPose("into sub")
                go(work)
                check(nav().offset < 0 && nav().offset >= -Motion.filesNavTravel - 1e-6, "up: enters from the left (" + nav().offset + ")")
                settle("after up")
                finalPose("up to work")
                go(work + "/other")
                go(work + "/sub")
                check(nav().offset === 0 && nav().fade < 1, "lateral jump fades only (offset=" + nav().offset + ")")
                settle("after lateral")
                finalPose("lateral")
                reached++
            }

            // Two navigations in a row: the second retargets from the current pose (no jump in opacity or
            // x) and the end state is exact, with nothing left half-faded or shifted.
            function test_03_interrupted_navigation() {
                const work = suite.root + "/work"
                go(work)
                settle("start")
                go(work + "/sub")
                waitFor(() => nav().fade > 0.15 && nav().running, "first entry under way", 2000)
                const f0 = nav().fade, x0 = nav().offset
                view.navigate(work + "/sub/deep")
                check(view.path === work + "/sub/deep", "second navigation applied")
                const f1 = nav().fade, x1 = nav().offset
                check(Math.abs(f1 - f0) < 0.05, "interrupt keeps the opacity (" + f0.toFixed(3) + " -> " + f1.toFixed(3) + ")")
                check(Math.abs(x1 - x0) < 1.5, "interrupt keeps the x (" + x0.toFixed(2) + " -> " + x1.toFixed(2) + ")")
                const trace = followEntry()
                check(trace.worstStep <= 0, "no x jump after the interrupt (worst step over the spring's own motion " + trace.worstStep.toFixed(2) + " px)")
                waitFor(() => view.model.ready, "deep listed")
                settle("after double navigation")
                finalPose("double navigation")
                // back-to-back without a frame in between, three times
                go(work); go(work + "/sub"); go(work + "/sub/deep/deeper")
                settle("after triple navigation")
                finalPose("triple navigation")
                reached++
            }

            // One highlight slides between items and ends exactly on the new item; the rest of the
            // selection (multiple runs) is drawn without a slide.
            function test_04_highlight_slides() {
                const work = suite.root + "/work"
                go(work)
                settle("listing")
                view.selection.select(idx("a.txt"))
                const hl = highlight()
                waitFor(() => hl.visible, "highlight shown")
                settle("first select")
                const start = Qt.point(hl.x, hl.y)
                view.selection.select(idx("c.txt"))
                const goal = hl.goal
                check(view.animating && grid().highlightAnimating, "a new selection slides the highlight")
                check(Math.abs(hl.x - start.x) < 1.5 && Math.abs(hl.y - start.y) < 1.5, "slide starts where the highlight was")
                let maxStep = 0, lx = hl.x, mid = false
                while (grid().highlightAnimating) {
                    wait(8)
                    maxStep = Math.max(maxStep, Math.abs(hl.x - lx)); lx = hl.x
                    if (Math.abs(hl.x - start.x) > 2 && Math.abs(hl.x - goal.x) > 2) mid = true
                }
                check(hl.x === goal.x && hl.y === goal.y && hl.width === goal.width && hl.height === goal.height, "highlight ends exactly on the item")
                check(mid || Math.abs(goal.x - start.x) < 4, "highlight passes through intermediate positions")
                check(grid().highlightCount === 1, "single selection draws one highlight")
                view.selection.toggle(idx("e.txt"))
                check(grid().highlightCount === 2, "a second run is drawn by the Repeater")
                settle("multi select")
                reached++
            }

            // A new crumb fades in; the existing ones do not. The thumbnail fades in after an asynchronous
            // load and the glyph cross-fades out with it (no second animation).
            function test_05_crumbs_and_thumbs() {
                const work = suite.root + "/work"
                go(work)
                settle("crumbs base")
                const row = find(bar(), "crumbRow")
                const before = row.children.filter(c => c.opacity !== undefined && c.width > 0).length
                go(work + "/sub")
                waitFor(() => row.children.filter(c => c.width > 0).length === before + 1, "one more crumb", 2000)
                const items = row.children.filter(c => c.width > 0 && c.opacity !== undefined && c.objectName !== "repeater")
                const last = items[items.length - 1]
                const sawFade = last.opacity < 1
                waitFor(() => last.opacity === 1, "new crumb ends opaque", 2000)
                check(items.slice(0, -1).every(c => c.opacity === 1), "existing crumbs stay opaque")
                settle("crumbs")
                console.log("INFO: files motion crumb fade observed:", sawFade)
                // thumbnails
                go(work + "/other")
                const d = () => grid().flick.contentItem.children.filter(c => c.objectName === "fileDelegate" && c.visible && c.name === "pic.png")[0]
                let thumbFaded = false
                waitFor(() => { if (d() && d().thumbStatus === Image.Ready && d().thumbOpacity < 1) thumbFaded = true
                    return d() && d().thumbStatus === Image.Ready }, "thumbnail loaded", 4000)
                waitFor(() => { if (d().thumbOpacity > 0 && d().thumbOpacity < 1) thumbFaded = true; return d().thumbOpacity === 1 }, "thumbnail ends opaque", 2000)
                console.log("INFO: files motion thumbnail fade observed:", thumbFaded)
                settle("thumb")
                check(d().thumbOpacity === 1, "thumbnail opacity exact")
                reached++
            }

            // Window hidden (active false): navigation, selection and crumbs resolve to their end state at
            // once and no animation, FrameAnimation or spring is left running.
            function test_06_hidden_window_does_not_animate() {
                const work = suite.root + "/work"
                go(work)
                settle("visible")
                view.selection.select(idx("a.txt"))
                settle("pre hidden")
                view.active = false
                view.navigate(work + "/sub")
                view.navigate(work + "/sub/deep")
                waitFor(() => view.model.ready, "hidden listing ready")
                view.navigate(work)
                waitFor(() => view.model.ready && idx("b.txt") >= 0, "hidden work listed")
                view.selection.select(idx("b.txt"))
                const all = motions(view)
                const nSpring = all.filter(m => m.kind === "spring").length, nAnim = all.filter(m => m.kind === "anim").length
                console.log("INFO: files motion scanner sees", nSpring, "springs,", nAnim, "animations,", all.filter(m => m.kind === "frame").length, "frame animations")
                check(nSpring >= 7 && nAnim >= 4, "the scanner reaches the explorer's springs and animations")
                for (let i = 0; i < 10; i++) {
                    const running = busy(motions(view))
                    check(running.length === 0, "nothing animates while hidden (" + describe(running) + ")")
                    check(!view.animating, "view reports no motion while hidden")
                    wait(16)
                }
                finalPose("hidden")
                const hl = highlight()
                check(hl.x === hl.goal.x && hl.y === hl.goal.y, "hidden highlight is already on its item")
                view.active = true
                settle("shown again")
                reached++
            }

            // reduceMotion: no offset, no scale, no spring; every animation that runs lasts <= Motion.fast
            // and the transitions finish within that time.
            function test_07_reduce_motion() {
                const work = suite.root + "/work"
                setReduce(true)
                openView(work)
                check(glass().scale === 1, "reduceMotion: no opening scale")
                check(glass().opacity < 1, "reduceMotion: the opening is a fade")
                let longest = 0, springs = 0
                const t0 = Date.now()
                const sample = () => {
                    for (const m of busy(motions(view))) {
                        if (m.kind === "anim") longest = Math.max(longest, m.o.duration)
                        else springs++
                    }
                }
                while (view.opening) { sample(); wait(4) }
                const openMs = Date.now() - t0
                check(glass().opacity === 1, "reduceMotion: opening ends opaque")
                waitFor(() => view.model.ready && idx("a.txt") >= 0, "reduced work listed")
                const t1 = Date.now()
                view.navigate(work + "/sub")
                check(nav().offset === 0, "reduceMotion: no offset")
                check(nav().fade < 1 && nav().running, "reduceMotion: a short fade")
                while (nav().running) { check(nav().offset === 0, "reduceMotion: offset stays 0"); sample(); wait(4) }
                const navMs = Date.now() - t1
                waitFor(() => view.model.ready && idx("s1.txt") >= 0, "reduced sub listed")
                view.selection.select(idx("s1.txt"))
                view.selection.select(idx("deep"))
                sample()
                check(!grid().highlightAnimating, "reduceMotion: the highlight does not slide")
                view.navigate(work + "/sub/deep")
                while (view.animating) { sample(); wait(4) }
                view.navigate(work + "/other")
                waitFor(() => view.model.ready, "other listed")
                while (view.animating) { sample(); wait(4) }
                check(longest <= Motion.fast, "reduceMotion: every running animation <= Motion.fast (" + longest + " > " + Motion.fast + ")")
                check(springs === 0, "reduceMotion: no spring integrates (" + springs + ")")
                // wall-clock with margin for offscreen timer granularity
                check(openMs <= Motion.fast + 120 && navMs <= Motion.fast + 120, "reduceMotion: transitions end within Motion.fast (open " + openMs + " ms, nav " + navMs + " ms, fast " + Motion.fast + " ms)")
                finalPose("reduced")
                console.log("INFO: files motion reduceMotion open", openMs, "ms nav", navMs, "ms longest anim", longest, "ms")
                reached++
            }

            // Toggling reduceMotion in the middle of a transition resolves it at once.
            function test_08_reduce_toggle_mid_transition() {
                const work = suite.root + "/work"
                setReduce(false)
                go(work)
                settle("toggle base")
                view.navigate(work + "/sub")
                check(nav().running, "transition under way")
                setReduce(true)
                waitFor(() => !nav().running, "toggle resolves the transition", 1000)
                finalPose("toggle")
                setReduce(false)
                reached++
            }

            // Interrupted on the way into a 20 000-file folder: the entry keeps moving from its pose (no
            // frozen stretch while the listing loads), the offset never reverses and the fade never drops.
            function test_09_interrupt_towards_big_folder() {
                const work = suite.root + "/work"
                go(work)
                settle("big base")
                go(work + "/sub")
                waitFor(() => nav().running && nav().fade > 0.4, "entry under way", 2000)
                const f0 = nav().fade, x0 = nav().offset
                view.navigate(work + "/sub/big")
                check(view.path === work + "/sub/big", "navigation to the big folder applied")
                check(Math.abs(nav().fade - f0) < 0.05 && Math.abs(nav().offset - x0) < 1.5, "interrupt keeps the pose")
                const trace = followEntry()
                console.log("INFO: files motion big-folder interrupt: samples", trace.samples, "max frozen", trace.maxFrozenMs, "ms worst step", trace.worstStep.toFixed(2))
                check(trace.maxFrozenMs <= 80, "no frozen stretch while the big listing loads (" + trace.maxFrozenMs + " ms)")
                check(!trace.reversed, "the offset never reverses direction")
                check(trace.fadeDrop <= 1e-6, "the fade never drops (" + trace.fadeDrop + ")")
                check(trace.worstStep <= 0, "no x jump (" + trace.worstStep.toFixed(2) + ")")
                waitFor(() => view.model.ready && view.model.count === 20000, "big folder listed", 10000)
                settle("big folder")
                finalPose("big folder")
                // A fresh entry (from rest) into the big folder may wait for the listing, bounded by filesNavHold.
                go(work + "/sub")
                settle("back from big")
                const t0 = Date.now()
                view.navigate(work + "/sub/big")
                waitFor(() => nav().fade > 0.05, "fresh entry starts", 3000)
                check(Date.now() - t0 <= Motion.filesNavHold + 400, "the hold of a fresh entry is bounded (" + (Date.now() - t0) + " ms)")
                waitFor(() => view.model.ready && view.model.count === 20000, "big folder listed again", 10000)
                settle("big again")
                finalPose("big again")
                // run() with a partial snapshot keeps the missing fields (no NaN)
                nav().run({ offset: 10 })
                check(isFinite(nav().fade) && isFinite(nav().offset), "partial snapshot gives finite values")
                settle("partial snapshot")
                finalPose("partial snapshot")
                reached++
            }

            function test_99_exit() {
                if (view) { view.destroy(); view = null }
                suite.finish(0)
                for (let i = 0; i < 1200 && !suite.cleaned; i++) wait(50)
                if (!suite.cleaned) { console.error("FAIL: files motion fixture cleanup did not finish"); suite.exitCode = 1 }
                if (suite.exitCode === 0 && reached !== suite.totalTests) {
                    console.error("FAIL: files motion tests incompletos (" + reached + "/" + suite.totalTests + " llegaron a su ultima linea)")
                    suite.exitCode = 1
                }
                if (suite.exitCode !== 0) Qt.exit(suite.exitCode)
                else console.log("PASS: files motion (" + reached + "/" + suite.totalTests + " tests: opening monotonic/overshoot, directional entry, interrupted navigation, sliding highlight, crumbs and thumbnail fade, hidden window, reduceMotion, interrupt towards a 20k folder)")
            }
        }
    }
}
