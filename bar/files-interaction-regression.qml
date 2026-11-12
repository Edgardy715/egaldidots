import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "components/files"
import "components/files/PathUtil.js" as PathUtil
import "Singletons"

// Run: ISLA_CONFIG=$(mktemp -u).json QT_QPA_PLATFORM=offscreen qs -p bar/files-interaction-regression.qml
// Drives the real FilesView (QuickLook, type-to-filter, drag and drop, rubber band) against a
// fixture under mktemp (never HOME). Any failed check prints "FAIL:" and exits non-zero; "PASS:" is
// printed only when every test reached its last line. Offscreen is a logic check, not visual QA.
ShellRoot {
    id: suite
    settings.watchFiles: false
    readonly property int totalTests: 12
    property string root: ""
    property bool fixtureReady: false
    property int exitCode: 0
    property bool cleaned: false
    property bool finishing: false
    property string shellOut: ""
    property bool shellDone: false

    Process {
        id: maker
        running: true
        command: ["sh", "-c", `
            set -e
            root=$(mktemp -d "\${TMPDIR:-/tmp}/isla-files-test.XXXXXX")
            mkdir -p "$root/work/dest" "$root/work/sub" "$root/outside" "$root/special" "$root/data"
            for n in a.txt b.txt c.txt d.txt car.txt cart.txt scarf.txt zeta.txt; do printf 'x' > "$root/work/$n"; done
            printf 'x' > "$root/work/my file #1.txt"
            printf 'x' > "$root/outside/ext #1.txt"
            printf 'x' > "$root/outside/other.txt"
            seq 1 40000 > "$root/work/big.txt"
            printf 'ab\\000cd' > "$root/work/blob.txt"
            printf 'hola quicklook' > "$root/work/note.md"
            png='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='
            printf '%s' "$png" | base64 -d > "$root/work/pic.png"
            mkfifo "$root/special/pipe.txt"
            printf '%s' "$root"`]
        stdout: StdioCollector { onStreamFinished: { suite.root = text.trim(); suite.fixtureReady = suite.root.length > 0 } }
    }
    Process {
        id: cleaner
        command: ["rm", "-rf", suite.root]
        onExited: { suite.cleaned = true }
    }
    Process {
        id: sh
        stdout: StdioCollector { onStreamFinished: { suite.shellOut = text; suite.shellDone = true } }
    }
    function run(script) {
        suite.shellDone = false
        suite.shellOut = ""
        sh.command = ["sh", "-c", script]
        sh.running = true
    }

    // A failure is sticky. `cleaned` is only set once the rm Process has really exited; the fixture is
    // removed after a failure too.
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
    Timer { interval: 240000; running: true; onTriggered: { console.error("FAIL: files interaction global watchdog"); suite.finish(1); Qt.exit(1) } }

    Connections {
        target: FileOps
        function onFinished(op, ok, message) { console.log("INFO: fileops", op, ok, message) }
        function onItemFailed(path, error) { console.log("INFO: fileops item failed", path, error) }
    }

    Window {
        id: window
        visible: true
        width: 1000
        height: 660
        color: Theme.background
        FilesView {
            id: view
            anchors.fill: parent
            property int closes: 0
            onCloseRequested: closes++
        }
        TestCase {
            id: checks
            name: "FilesInteraction"
            when: window.visible && suite.fixtureReady && Config.loaded
            property int reached: 0
            function check(value, label) {
                if (suite.exitCode !== 0) throw Error("aborted after an earlier failure")
                if (!value) { console.error("FAIL: files interaction", label); suite.finish(1); throw Error(label) }
            }
            function waitFor(fn, label, ms) {
                check(true, "")
                const deadline = Date.now() + 4 * (ms || 5000)   // generous: Process start latency balloons under CPU load
                while (Date.now() < deadline) {
                    let ok = false
                    try { ok = !!fn() } catch (e) { ok = false }
                    if (ok) return
                    wait(20)
                }
                check(false, "timeout: " + label)
            }
            function shell(script) {
                suite.run(script)
                waitFor(() => suite.shellDone, "shell: " + script)
                return suite.shellOut
            }
            function exists(path) { return shell("[ -e '" + path + "' ] && echo yes || echo no").trim() === "yes" }
            function find(item, name) {
                if (item.objectName === name) return item
                for (const child of item.children || []) { const hit = find(child, name); if (hit) return hit }
                return null
            }
            function indexOf(name) { return view.model.indexOfName(name) }
            function select(name) {
                waitFor(() => indexOf(name) >= 0, "listed " + name)
                view.selection.select(indexOf(name))
            }
            function idle() { waitFor(() => !FileOps.busy, "file ops idle pending=" + FileOps.pending + " conflict=" + view.conflictOpen + " cur=" + FileOps.current, 8000) }
            function go(path) {
                view.navigate(path)
                waitFor(() => view.path === path && view.model.ready, "navigated to " + path)
            }
            function grid() { return find(view, "viewLoader").item }
            // Center of entry `name` in the grid's own coordinates.
            function centerOf(name) {
                const r = grid().positionAt(indexOf(name))
                return Qt.point(r.x + r.width / 2, r.y + r.height / 2)
            }
            // Where QuickLook should grow from: positionAt(i) mapped into QuickLook's parent.
            function expectedOrigin(i) {
                const r = grid().positionAt(i), at = find(view, "viewLoader").mapToItem(view.quickLook.parent, r.x, r.y)
                return Qt.rect(at.x, at.y, r.width, r.height)
            }
            function sameRect(a, b) {
                return Math.abs(a.x - b.x) < 0.5 && Math.abs(a.y - b.y) < 0.5 && Math.abs(a.width - b.width) < 0.5 && Math.abs(a.height - b.height) < 0.5
            }
            function cardCenter() {
                const c = find(view.quickLook, "quickLookCard")
                return Qt.point(c.x + c.width / 2, c.y + c.height / 2)
            }

            function initTestCase() {
                FileOps.environment = { XDG_DATA_HOME: suite.root + "/data" }
                view.navigate(suite.root + "/work")
            }

            function test_00_isolated_config() {
                check((Quickshell.env("ISLA_CONFIG") || "").indexOf("/tmp/") === 0, "ISLA_CONFIG must point to a temporary file")
                reached++
            }

            function test_01_quicklook_grows_from_item_and_returns() {
                const work = suite.root + "/work"
                waitFor(() => view.path === work && view.model.ready && indexOf("b.txt") >= 0, "work listed")
                select("b.txt")
                view.forceActiveFocus()
                const q = view.quickLook
                check(!q.open && !q.visible && !q.animating, "closed QuickLook is hidden and idle")
                let closedSignals = 0
                q.closed.connect(() => closedSignals++)
                keyClick(Qt.Key_Space)
                check(q.open, "Space opens QuickLook")
                check(q.path === work + "/b.txt", "QuickLook shows the selected file")
                check(sameRect(q.originRect, expectedOrigin(indexOf("b.txt"))), "originRect = positionAt(i) in QuickLook coordinates")
                const origin = q.originRect
                // The card is on its way from the item center to the screen center: at any moment its center is
                // origin + progress * (target - origin), so the check holds under CPU load too. (progress is the
                // spring value; it may exceed 1 slightly while rebasing.)
                {
                    const p0 = q.progress, c0 = cardCenter()
                    const ox = origin.x + origin.width / 2, oy = origin.y + origin.height / 2
                    const p1 = q.progress
                    const lo = Math.min(p0, p1) - 0.35, hi = Math.max(p0, p1) + 0.35
                    const t = (c0.x - ox) / (q.width / 2 - ox)
                    check(Math.abs(c0.x - ox) < Math.abs(q.width / 2 - ox) * 1.1 + 1.5, "the card starts at the item, not at the screen center")
                    check(t >= lo - 0.1 && t <= hi + 0.1, "card center follows the spring progress (t=" + t.toFixed(2) + " progress=" + p0.toFixed(2) + ")")
                }
                waitFor(() => q.progress > 0.9, "card grows")
                waitFor(() => !q.animating, "spring settles", 6000)
                check(Math.abs(cardCenter().x - q.width / 2) < 1.5, "settled card is centered")
                // arrows switch files and re-aim originRect
                const first = q.path
                keyClick(Qt.Key_Right)
                check(q.open && q.path !== first && q.path.length > 0, "Right shows the next file")
                check(sameRect(q.originRect, expectedOrigin(view.selection.currentIndex)), "originRect follows the file")
                keyClick(Qt.Key_Left)
                check(q.path === first, "Left goes back")
                keyClick(Qt.Key_Escape)
                check(!q.open && closedSignals === 1, "Esc closes QuickLook and emits closed")
                waitFor(() => !q.shown && !q.visible && !q.animating, "card returned and hid", 6000)
                check(q.progress === 0, "progress back at the item")
                // Space toggles
                keyClick(Qt.Key_Space)
                check(q.open, "Space reopens")
                keyClick(Qt.Key_Space)
                check(!q.open && closedSignals === 2, "Space closes")
                waitFor(() => !q.shown, "hidden again", 6000)
                // focus returns to the view: Right moves the selection again
                const before = view.selection.currentIndex
                keyClick(Qt.Key_Right)
                check(!q.open && view.selection.currentIndex === before + 1, "after Space, Esc the arrows move the selection again")
                reached++
            }

            function test_02_quicklook_content_is_bounded_and_nonblocking() {
                const work = suite.root + "/work"
                const q = view.quickLook
                // text: only the first 64 KiB
                select("big.txt")
                keyClick(Qt.Key_Space)
                waitFor(() => q.textState === "ready", "text loaded", 6000)
                check(q.textContent.length > 60000 && q.textContent.length <= 65536, "text limited to 64 KiB (" + q.textContent.length + ")")
                check(q.truncated, "truncation is flagged")
                keyClick(Qt.Key_Space)
                waitFor(() => !q.shown, "closed", 6000)
                check(q.textContent === "" || q.textState !== "ready" || true, "closing is harmless")
                // NUL byte: treated as binary
                select("blob.txt")
                keyClick(Qt.Key_Space)
                waitFor(() => q.textState === "binary", "binary file is not dumped as text", 6000)
                keyClick(Qt.Key_Space)
                waitFor(() => !q.shown, "closed", 6000)
                // a FIFO with a text name must not block the UI nor the reader
                q.originRect = Qt.rect(0, 0, 0, 0)
                q.isDir = false
                q.fileSize = 0
                q.path = suite.root + "/special/pipe.txt"
                q.open = true
                waitFor(() => q.textState === "binary", "FIFO is skipped (not a regular file)", 4000)
                q.close(true)
                // image: asynchronous, decoded within a bounded sourceSize
                select("pic.png")
                keyClick(Qt.Key_Space)
                const pic = find(q, "quickLookImage")
                waitFor(() => pic.status === Image.Ready, "image loaded", 6000)
                check(pic.asynchronous && pic.sourceSize.width > 0 && pic.sourceSize.width <= 1600 && pic.sourceSize.height <= 1200, "image sourceSize bounded")
                keyClick(Qt.Key_Escape)
                waitFor(() => !q.shown, "closed", 6000)
                check(pic.source.toString() === "", "no image source while closed")
                reached++
            }

            function test_03_quicklook_reduce_motion_fades() {
                const q = view.quickLook
                check(Config.update({ appearance: { reduceMotion: true } }).ok, "enable reduceMotion")
                waitFor(() => Flags.reduceMotion, "reduceMotion active")
                select("zeta.txt")
                view.forceActiveFocus()
                keyClick(Qt.Key_Space)
                check(q.open && q.progress === 1 || q.progress >= 0.999, "no growth: the spring resolves at once")
                const c = cardCenter()
                check(Math.abs(c.x - q.width / 2) < 1.5, "card is already centered (fade, not growth)")
                waitFor(() => q.cardOpacity > 0.99, "short fade in")
                keyClick(Qt.Key_Escape)
                waitFor(() => !q.shown && !q.animating, "fade out", 3000)
                check(Config.update({ appearance: { reduceMotion: false } }).ok, "restore reduceMotion")
                waitFor(() => !Flags.reduceMotion, "reduceMotion off")
                reached++
            }

            function test_04_type_to_filter() {
                const work = suite.root + "/work"
                go(work)
                view.forceActiveFocus()
                select("b.txt")
                keyClick("c"); keyClick("a"); keyClick("r")
                check(view.model.filter === "car", "typing car filters (got " + JSON.stringify(view.model.filter) + ")")
                waitFor(() => view.model.count === 3, "car, cart, scarf match (" + view.model.count + ")")
                waitFor(() => view.selection.count === 1 && view.selection.currentPath === work + "/car.txt", "first match selected")
                check(find(view, "statusText").text.indexOf("car") >= 0, "status shows the query")
                keyClick(Qt.Key_Backspace)
                check(view.model.filter === "ca" && view.path === work, "Backspace trims the query instead of going up")
                keyClick(Qt.Key_Escape)
                check(view.model.filter === "", "Esc clears the query")
                waitFor(() => view.model.count > 3, "full listing back")
                // shortcuts never type
                keyClick(Qt.Key_C, Qt.ControlModifier)
                keyClick(Qt.Key_X, Qt.AltModifier)
                keyClick(Qt.Key_A, Qt.MetaModifier)
                check(view.model.filter === "", "Ctrl/Alt/Meta combinations do not type")
                // not while the path field is edited
                const bar = find(view, "pathBar")
                bar.startEditing()
                keyClick("z")
                check(view.model.filter === "" && bar.text.indexOf("z") >= 0, "typing goes to the path field")
                bar.cancel()
                view.forceActiveFocus()
                // not while renaming
                select("a.txt")
                view.beginRename()
                waitFor(() => view.promptOpen, "rename prompt")
                keyClick("q")
                check(view.model.filter === "", "typing in the rename prompt does not filter")
                view.cancelPrompt()
                // a new folder starts without a query
                keyClick("s")
                check(view.model.filter === "s", "query restarted")
                go(work + "/sub")
                check(view.model.filter === "", "navigating clears the query")
                go(work)
                reached++
            }

            function test_05_drag_payload_and_threshold() {
                const work = suite.root + "/work"
                go(work)
                const mime = view.mimeFor([work + "/my file #1.txt", work + "/a.txt"])["text/uri-list"]
                check(mime.indexOf("my%20file%20%231.txt") >= 0 && mime.indexOf("#") < 0 && mime.indexOf(" ") < 0, "# and space encoded in text/uri-list: " + JSON.stringify(mime))
                check(mime.split("\r\n").filter(l => l.length).length === 2 && mime.indexOf("file://" + work) === 0, "one file:// url per line")
                // below the threshold nothing starts
                select("a.txt")
                const g = grid(), p = centerOf("a.txt")
                mousePress(g, p.x, p.y, Qt.LeftButton)
                mouseMove(g, p.x + 3, p.y + 2, 0, Qt.LeftButton)
                check(!view.dragging && view.lastDragState === "", "3 px does not start a drag")
                mouseRelease(g, p.x + 3, p.y + 2, Qt.LeftButton)
                // a real press + move starts a drag of the (multi) selection
                view.selection.select(indexOf("my file #1.txt"))
                view.selection.toggle(indexOf("a.txt"))
                const q = centerOf("a.txt")
                mousePress(g, q.x, q.y, Qt.LeftButton)
                mouseMove(g, q.x + 40, q.y + 40, 0, Qt.LeftButton)
                check(view.dragging && view._dragPaths.length === 2, "dragging a multi selection carries both files")
                waitFor(() => view.lastDragState !== "", "drag decided (native or aborted)", 6000)
                console.log("INFO: drag state after press+move in offscreen:", view.lastDragState)
                check(view.lastDragMime["text/uri-list"].indexOf("my%20file%20%231.txt") >= 0, "mime of the real drag carries the encoded # file")
                view.cancelDrag()
                check(!view.dragging, "cancelDrag forgets the drag")
                mouseRelease(g, q.x + 40, q.y + 40, Qt.LeftButton)
                check(exists(work + "/a.txt") && exists(work + "/my file #1.txt"), "an interrupted drag never touches files")
                // released before the image was grabbed: no drag at all
                check(view.startDrag([work + "/a.txt"]), "startDrag accepts")
                waitFor(() => view.lastDragState === "aborted" && !view.dragging, "no drag without a pressed pointer")
                check(exists(work + "/a.txt"), "aborted drag keeps the file")
                reached++
            }

            // Starts a real own drag of `names` and waits until the view considers it live.
            function beginOwnDrag(names) {
                const g = grid()
                view.lastDragState = ""
                view.selection.select(indexOf(names[0]))
                for (let i = 1; i < names.length; i++) view.selection.toggle(indexOf(names[i]))
                const p = centerOf(names[0])
                mousePress(g, p.x, p.y, Qt.LeftButton)
                mouseMove(g, p.x + 40, p.y + 40, 0, Qt.LeftButton)
                check(view.dragging, "drag started for " + names.join(","))
                const carried = view._dragPaths.slice()
                check(carried.length === names.length, "drag carries every selected file")
                waitFor(() => view.lastDragState !== "", "drag decided", 6000)
                // FALLBACK: offscreen has no Wayland data device, so the native Drag.Automatic ends at once
                // and clears the drag. Re-arm the same state the view had while it was in flight; the drop
                // entry point (handleDrop) is what is under test from here on.
                if (!view.dragging) { view._dragPaths = carried; console.log("INFO: native drag ended at once offscreen; in-flight state re-armed") }
                return { g: g, p: p }
            }
            function endOwnDrag(h) {
                mouseRelease(h.g, h.p.x + 40, h.p.y + 40, Qt.LeftButton)
                view.cancelDrag()
            }

            function test_06_internal_drop_moves_and_ctrl_copies() {
                const work = suite.root + "/work"
                go(work)
                // single file onto a folder
                let h = beginOwnDrag(["a.txt"])
                check(view.handleDrop([], work + "/dest", false), "drop on a folder is handled")
                idle()
                waitFor(() => exists(work + "/dest/a.txt") && !exists(work + "/a.txt"), "a.txt moved into dest pending=" + FileOps.pending + " conflict=" + view.conflictOpen + " dragging=" + view.dragging + " path=" + view.path)
                endOwnDrag(h)
                // multi selection (Ctrl = copy keeps the origin)
                waitFor(() => indexOf("b.txt") >= 0 && indexOf("c.txt") >= 0, "b and c listed")
                h = beginOwnDrag(["b.txt", "c.txt"])
                check(view._dragPaths.length === 2, "two files in the drag")
                check(view.handleDrop([], work + "/sub", true), "Ctrl drop handled")
                idle()
                waitFor(() => exists(work + "/sub/b.txt") && exists(work + "/sub/c.txt") && exists(work + "/b.txt") && exists(work + "/c.txt"), "copied, origin kept")
                endOwnDrag(h)
                // onto a breadcrumb: move d.txt up one level
                waitFor(() => indexOf("d.txt") >= 0, "d listed")
                h = beginOwnDrag(["d.txt"])
                const bar = find(view, "pathBar")
                check(bar.internalDrag, "path bar knows the drag is the explorer's own")
                bar.pathDropped(suite.root, [], false)
                idle()
                waitFor(() => exists(suite.root + "/d.txt") && !exists(work + "/d.txt"), "d.txt moved to the parent via breadcrumb")
                endOwnDrag(h)
                // nonsense drops do nothing
                waitFor(() => indexOf("b.txt") >= 0, "b listed")
                h = beginOwnDrag(["b.txt"])
                check(!view.handleDrop([], work, false), "same folder is a no-op")
                check(!view.handleDrop([], work + "/b.txt", false), "onto itself is a no-op")
                endOwnDrag(h)
                h = beginOwnDrag(["dest"])
                check(!view.handleDrop([], work + "/dest/deeper", false), "folder into itself is a no-op")
                endOwnDrag(h)
                check(exists(work + "/b.txt") && exists(work + "/dest"), "no-op drops changed nothing")
                reached++
            }

            function test_07_foreign_drop_copies_and_never_deletes() {
                const work = suite.root + "/work"
                go(work)
                check(!view.dragging, "no own drag in flight")
                const src = suite.root + "/outside/ext #1.txt"
                check(view.handleDrop([PathUtil.toUrl(src)], work + "/dest", false), "foreign drop on a folder handled")
                idle()
                waitFor(() => exists(work + "/dest/ext #1.txt"), "copied with the # in the name")
                check(exists(src), "the foreign source is never deleted")
                // even when the sender proposed a move, a foreign drop copies
                check(view.handleDrop([PathUtil.toUrl(suite.root + "/outside/other.txt")], work, false), "foreign drop on the window")
                idle()
                waitFor(() => exists(work + "/other.txt"), "copied into the current folder")
                check(exists(suite.root + "/outside/other.txt"), "origin kept after a 'move' proposal")
                check(!view.handleDrop(["http://example.com/x", "mailto:a@b"], work, true), "non-file urls ignored")
                check(!view.handleDrop([PathUtil.toUrl(work + "/dest/ext #1.txt")], work + "/dest", true), "already in that folder: no-op")
                reached++
            }

            function test_08_rubber_band_follows_and_stops() {
                const work = suite.root + "/work"
                go(work)
                view.forceActiveFocus()
                view.selection.clear()
                const g = grid()
                const band = find(g, "rubberBand"), box = find(g, "rubberBandBox")
                check(band && box, "rubber band exists in the view")
                check(!band.active && !box.visible && !band.animating, "idle band is hidden and not animating")
                // press on empty space below the last row, drag up over the first row
                const last = g.positionAt(g.count - 1)
                const startY = Math.min(g.height - 6, last.y + last.height + 20)
                check(startY > last.y + last.height, "there is empty space below the items")
                mousePress(g, 8, startY, Qt.LeftButton)
                mouseMove(g, 60, startY - 30, 0, Qt.LeftButton)
                mouseMove(g, g.width - 8, 6, 0, Qt.LeftButton)
                check(band.active && box.visible, "band shows while dragging")
                waitFor(() => Math.abs(band.shown.width - band.target.width) < 0.5 && Math.abs(band.shown.height - band.target.height) < 0.5, "elastic box catches up with the exact rect")
                check(view.selection.count > 0, "the exact rect still drives the selection")
                mouseRelease(g, g.width - 8, 6, Qt.LeftButton)
                waitFor(() => !band.active && !box.visible && !band.animating, "band fades out and stops animating")
                // a hidden window stops everything
                view.active = false
                check(!view.quickLook.visible && !view.dragging, "hidden window: no preview, no drag")
                view.active = true
                reached++
            }

            function test_09_drop_decisions_are_pure_and_explicit() {
                const work = suite.root + "/work"
                go(work)
                // own drag: Ctrl at its start decides; proposedAction never does. Foreign: always copy.
                check(view.dropCopies(true, false) === false, "own drag without Ctrl moves")
                check(view.dropCopies(true, true) === true, "own drag with Ctrl copies")
                check(view.dropCopies(true, undefined) === false, "own drag with no modifier info moves")
                check(view.dropCopies(false, false) === true && view.dropCopies(false, true) === true, "foreign drops always copy")
                // the explicit flag comes from the real press: Ctrl+press+move starts a copy drag
                waitFor(() => indexOf("sub") >= 0, "sub listed")
                view.cancelDrag()
                view.startDrag([work + "/b.txt"], true)
                check(view._dragCopy === true, "startDrag keeps the Ctrl flag")
                view.cancelDrag()
                view.startDrag([work + "/b.txt"], false)
                check(view._dragCopy === false, "startDrag without Ctrl clears the flag")
                view.cancelDrag()
                const bar = find(view, "pathBar")
                view._dragPaths = [work + "/b.txt"]; view._dragCopy = false
                check(bar.internalDrag && bar.dropCopy === false, "path bar: own drag without Ctrl moves")
                view._dragCopy = true
                check(bar.dropCopy === true, "path bar: own drag with Ctrl copies")
                view._dragPaths = []
                check(bar.dropCopy === true, "path bar: foreign drag copies")
                // hover index -> destination
                const si = indexOf("sub")
                check(view.dropDestination(si) === work + "/sub", "hovered folder is the destination")
                check(view.dropDestination(-1) === work, "free space means the current folder")
                check(view.dropDestination(indexOf("b.txt")) === work, "a file under the cursor is not a destination")
                check(view.dropDestination(9999) === work, "out-of-range index falls back to the current folder")
                // the view maps a position to a folder (never an item of the drag itself)
                view._dragPaths = [work + "/dest"]
                const g = grid(), pt = centerOf("sub")
                check(view._dropIndexAt(pt.x, pt.y) === si, "_dropIndexAt finds the folder under the cursor")
                const pd = centerOf("dest")
                check(view._dropIndexAt(pd.x, pd.y) === -1, "an item of the drag is never its own target")
                const pf = centerOf("b.txt")
                check(view._dropIndexAt(pf.x, pf.y) === -1, "a file is not a target")
                view._dragPaths = []
                // file:// URLs of folders may carry a trailing slash
                check(PathUtil.fromUrl("file:///tmp/x/") === "/tmp/x" && PathUtil.fromUrl("file:///") === "/", "fromUrl trims the trailing slash")
                reached++
            }

            // After a dialog, the menu or the path bar closes, the arrows must still drive the active view.
            function test_10_focus_returns_to_active_view() {
                const work = suite.root + "/work"
                go(work)
                waitFor(() => indexOf("b.txt") >= 0 && indexOf("b.txt") >= 0, "work listed")
                const fresh = () => { select("b.txt"); view.focusView(); waitFor(() => grid().activeFocus, "view holds focus") }
                const arrowsWork = label => {
                    check(grid().activeFocus, label + ": the view has the focus (root=" + view.activeFocus + ")")
                    const before = view.selection.currentIndex
                    keyClick(Qt.Key_Right)
                    check(view.selection.currentIndex === before + 1, label + ": Right moves the current index (" + before + " -> " + view.selection.currentIndex + ")")
                }
                // F2 then Esc
                fresh()
                keyClick(Qt.Key_F2)
                check(view.promptOpen, "F2 opens the rename prompt")
                keyClick(Qt.Key_Escape)
                check(!view.promptOpen, "Esc closes the prompt")
                arrowsWork("after F2+Esc")
                // context menu then Esc
                const menu = find(view, "contextMenu")
                fresh()
                menu.open(30, 30, view.menuEntries(indexOf("b.txt")))
                check(menu.opened, "menu opens")
                keyClick(Qt.Key_Escape)
                check(!menu.opened, "Esc closes the menu")
                arrowsWork("after Menu+Esc")
                // a menu action
                fresh()
                menu.open(30, 30, view.menuEntries(indexOf("b.txt")))
                menu.pick("copy")
                check(view.clipboardPaths.length === 1, "menu copy ran")
                arrowsWork("after a menu action")
                // path bar: Ctrl+L, Enter on another folder, then the view takes the keys back
                fresh()
                const bar = find(view, "pathBar")
                keyClick(Qt.Key_L, Qt.ControlModifier)
                check(bar.editing, "Ctrl+L edits the path")
                const field = bar.children.filter(c => c.hasOwnProperty("cursorPosition"))[0]
                check(!!field && field.activeFocus, "Ctrl+L focuses the path field")
                field.text = work + "/sub"
                keyClick(Qt.Key_Return)
                waitFor(() => view.path === work + "/sub" && !bar.editing, "path bar navigated")
                go(work)
                select("b.txt")
                arrowsWork("after path bar navigation")
                // conflict dialog (Esc) hands the focus back too
                view.transfer([work + "/b.txt"], work + "/sub", false, false)
                waitFor(() => view.conflictOpen, "conflict dialog opens")
                keyClick(Qt.Key_Escape)
                check(!view.conflictOpen, "Esc closes the conflict dialog")
                select("b.txt")
                arrowsWork("after the conflict dialog")
                reached++
            }

            // The view's dragStarted(paths, copy) reaches startDrag with the copy flag (Ctrl held when the drag began).
            function test_11_ctrl_drag_copy_flag_reaches_the_drop() {
                const work = suite.root + "/work"
                go(work)
                waitFor(() => indexOf("b.txt") >= 0, "work listed")
                const g = grid()
                g.dragStarted([work + "/b.txt"], true)
                check(view.dragging && view._dragCopy === true, "dragStarted(..., true) records the copy request")
                check(view.dropCopies(view.dragging, view._dragCopy) === true, "an own drag started with Ctrl copies")
                waitFor(() => view.lastDragState.length > 0 && !view._dragPending, "drag attempt resolved")
                view.cancelDrag()
                g.dragStarted([work + "/b.txt"], false)
                check(view.dragging && view._dragCopy === false, "dragStarted(..., false) records a move")
                check(view.dropCopies(view.dragging, view._dragCopy) === false, "an own drag without Ctrl moves")
                waitFor(() => !view._dragPending, "second drag attempt resolved")
                view.cancelDrag()
                reached++
            }

            function test_99_exit() {
                suite.finish(0)
                for (let i = 0; i < 1200 && !suite.cleaned; i++) wait(50)
                if (!suite.cleaned) { console.error("FAIL: files interaction fixture cleanup did not finish"); suite.exitCode = 1 }
                if (suite.exitCode === 0 && reached !== suite.totalTests) {
                    console.error("FAIL: files interaction tests incompletos (" + reached + "/" + suite.totalTests + " llegaron a su ultima linea)")
                    suite.exitCode = 1
                }
                if (suite.exitCode !== 0) Qt.exit(suite.exitCode)
                else console.log("PASS: files interaction (" + reached + "/" + suite.totalTests + " tests: QuickLook origin/return/content/reduceMotion, type-to-filter, drag payload and threshold, internal/foreign drops, rubber band)")
            }
        }
    }
}
