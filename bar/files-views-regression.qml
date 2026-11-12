import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "components/files"
import "Singletons"

// Run: ISLA_CONFIG=$(mktemp -u).json QT_QPA_PLATFORM=offscreen qs -p bar/files-views-regression.qml
// Builds its own fixture under mktemp (never HOME) and removes it at the end.
// Offscreen is a logic/geometry check, not visual QA.
ShellRoot {
    id: suite
    settings.watchFiles: false
    property string root: ""
    property bool fixtureReady: false
    property var thumbCalls: []
    property int exitCode: 0

    Process {
        id: maker
        running: true
        command: ["sh", "-c", `
            set -e
            root=$(mktemp -d /tmp/isla-files-test.XXXXXX)
            mkdir "$root/few" "$root/many" "$root/few/sub" "$root/four" "$root/ren" "$root/flt"
            (cd "$root/four" && seq -f 'v%g.mp4' 1 400 | xargs touch)
            (cd "$root/ren" && touch a b c)
            (cd "$root/flt" && touch m1 m2 m3 n1 n2 n3)
            png='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='
            printf '%s' "$png" | base64 -d > "$root/few/a#b%20c.png"
            for n in b.txt c.txt d.txt e.txt clip.mp4; do touch "$root/few/$n"; done
            (cd "$root/many" && seq -f 'f%g' 1 20000 | xargs touch)
            printf '%s' "$root"`]
        stdout: StdioCollector { onStreamFinished: { suite.root = text.trim(); suite.fixtureReady = suite.root.length > 0 } }
    }
    Process { id: mutator }
    Process {
        id: cleaner
        command: ["rm", "-rf", suite.root]
        onExited: { suite.cleaned = true }
    }
    property bool cleaned: false
    // A passing run ends through QtTest itself (rc 0); a failing one exits from test_99 with its code.
    property bool finishing: false
    // A failure is sticky: finish(0) can never overwrite an earlier finish(1).
    // The fixture is removed from test_99 (the last test), which then exits with the code; and only after
    // the fixture removal (a Process) has really exited.
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
            if (suite.root.indexOf("/tmp/isla-files-test.") === 0) cleaner.running = true
            else suite.cleaned = true    // nothing to remove; otherwise only cleaner.onExited sets it
        }
    }
    Timer { interval: 150000; running: true; onTriggered: { console.error("FAIL: files views global watchdog"); suite.finish(1) } }

    QtObject {
        id: stub
        property var model: null
        property var names: ["p0", "p1", "p2", "p3", "p4", "p5", "p6", "p7", "p8", "p9"]
        property int count: names.length
        function get(i) { return i >= 0 && i < names.length ? { name: names[i], path: "/s/" + names[i] } : null }
    }
    SelectionModel { id: stubSel; model: stub }
    SelectionModel { id: sel }
    FilesModel { id: fm }
    FilesModel { id: big }
    FilesModel { id: fm2 }
    FilesModel { id: fm3 }
    SelectionModel { id: sel2; model: fm2 }
    SelectionModel { id: selBig }

    Window {
        id: window
        visible: true
        width: 640
        height: 480
        color: Theme.background
        Rectangle { anchors.fill: parent; color: Theme.background }
        Item {
            id: host
            anchors.fill: parent
            Keys.onEscapePressed: checks.escSeen++
            Keys.onLeftPressed: checks.leftSeen++
        FileGrid {
            id: grid
            anchors.fill: parent
            anchors.margins: 20
            model: fm
            selection: sel
            iconSize: 64
            onContextRequested: (i, pos) => { checks.ctxIndex = i; checks.ctxPos = pos; checks.ctxCount++ }
            thumbResolver: (path, size, cb) => { suite.thumbCalls.push(path); cb(suite.root + "/few/a#b%20c.png", true) }
        }
        FileGrid {
            id: bigGrid
            anchors.fill: parent
            anchors.margins: 20
            visible: false
            model: big
            selection: selBig
            iconSize: 64
        }
        FileList {
            id: list
            anchors.fill: parent
            anchors.margins: 20
            visible: false
            model: fm
            selection: sel
            iconSize: 28
        }
        }
        TestCase {
            id: checks
            name: "FilesViews"
            when: window.visible && suite.fixtureReady
            property int escSeen: 0
            property int leftSeen: 0
            property int ctxIndex: -2
            property point ctxPos
            property int ctxCount: 0
            function mutate(cmd) {
                mutator.command = ["sh", "-c", cmd]
                mutator.running = true
                waitFor(() => !mutator.running, "wait: () => !mutator.running", 5000)
            }
            property string passInfo: ""
            property int reached: 0       // test functions that ran to their last line
            function check(value, label) {
                if (suite.exitCode !== 0) throw Error("aborted after an earlier failure")
                if (!value) { console.error("FAIL: files views", label); suite.finish(1); throw Error(label) }
            }
            // Polls fn (exceptions count as false) and fails loudly on timeout; unlike
            // tryVerify, a timeout is never silent.
            function waitFor(fn, label, ms) {
                check(true, "")
                const deadline = Date.now() + (ms || 3000)
                while (Date.now() < deadline) {
                    let ok = false
                    try { ok = !!fn() } catch (e) { ok = false }
                    if (ok) return
                    wait(20)
                }
                check(false, "timeout: " + label)
            }
            function delegates(view) {
                const out = []
                for (const child of view.flick.contentItem.children)
                    if (child.objectName === "fileDelegate" && child.visible) out.push(child)
                return out
            }
            function allDelegates(view) {
                let n = 0
                for (const child of view.flick.contentItem.children) if (child.objectName === "fileDelegate") n++
                return n
            }
            function center(view, i) {
                const r = view.positionAt(i)
                return Qt.point(r.x + r.width / 2, r.y + r.height / 2)
            }
            function clickAt(view, i, mods) {
                const p = center(view, i)
                mouseClick(view, p.x, p.y, Qt.LeftButton, mods || Qt.NoModifier)
            }
            function pathsAt(from, to) {
                const out = []
                for (let i = from; i <= to; i++) out.push(fm.get(i).path)
                return out.sort()
            }
            function samePaths(a, b) { return JSON.stringify(a.slice().sort()) === JSON.stringify(b.slice().sort()) }

            // QtTest runs test_ functions alphabetically: keep the numeric prefixes.
            function test_01_selection_model() {
                const s = stubSel
                s.select(2)
                check(s.count === 1 && s.currentIndex === 2 && s.selected["/s/p2"] === true, "select")
                s.toggle(4)
                check(s.count === 2, "toggle on")
                s.toggle(4)
                check(s.count === 1 && s.selected["/s/p4"] === undefined, "toggle off")
                s.select(1); s.extendTo(4)
                check(s.count === 4 && s.currentIndex === 4 && s.selected["/s/p1"] && s.selected["/s/p4"], "extendTo range")
                s.extendTo(0)
                check(s.count === 2 && s.selected["/s/p0"] && s.selected["/s/p1"], "extendTo keeps anchor")
                s.select(5); s.move(1, false)
                check(s.count === 1 && s.currentIndex === 6, "move")
                s.move(-1, true)
                check(s.count === 2 && s.selected["/s/p5"] && s.selected["/s/p6"], "shift move")
                s.move(-100, false)
                check(s.currentIndex === 0, "move clamps")
                s.selectRect(Qt.rect(60, 0, 110, 20), i => Qt.rect(i * 50, 0, 40, 40))
                check(s.count === 3 && s.selected["/s/p1"] && s.selected["/s/p2"] && s.selected["/s/p3"], "rect crosses 3")
                s.selectRect(Qt.rect(60, 0, 40, 20), i => Qt.rect(i * 50, 0, 40, 40), { base: ({ "/s/p9": true }) })
                check(s.count === 2 && s.selected["/s/p9"] && s.selected["/s/p1"], "rect additive")
                s.selectAll()
                check(s.count === 10 && s.paths().length === 10, "selectAll")
                s.clear()
                check(s.count === 0 && s.paths().length === 0, "clear")
                s.select(3)
                stub.names = stub.names.slice().reverse()
                s.resync()
                check(s.count === 1 && s.selected["/s/p3"] === true && s.currentIndex === 6, "selection survives reorder (idx " + s.currentIndex + ")")
                reached++
            }

            function test_02_views_small() {
                fm.path = suite.root + "/few"
                waitFor(() => fm.ready && fm.count === 7, "wait: () => fm.ready && fm.count === 7", 8000)
                // order: sub, a#b%20c.png, b.txt, c.txt, clip.mp4, d.txt, e.txt
                check(fm.get(0).name === "sub" && fm.get(1).name === "a#b%20c.png", "fixture order " + fm.get(1).name)
                waitFor(() => delegates(grid).length === 7, "wait: () => delegates(grid).length === 7", 3000)
                const img = delegates(grid).filter(d => d.name === "a#b%20c.png")[0]
                check(img, "image delegate exists")
                waitFor(() => img.thumbStatus === Image.Ready, "odd-name thumbnail ready", 5000)
                waitFor(() => delegates(grid).filter(d => d.name === "clip.mp4")[0].videoThumb.length > 0, "video thumb resolved", 3000)
                check(suite.thumbCalls.filter(p => p.indexOf("clip.mp4") !== -1).length >= 1, "resolver asked for video")
                check(suite.thumbCalls.filter(p => p.indexOf("b.txt") !== -1).length === 0, "resolver not asked for text")
                check(grid.positionAt(1).width > 0 && grid.positionAt(1).x > grid.positionAt(0).x, "positionAt geometry")

                clickAt(grid, 2)
                check(sel.count === 1 && sel.selected[fm.get(2).path] === true && sel.currentIndex === 2, "click (count " + sel.count + " cur " + sel.currentIndex + " sel " + JSON.stringify(sel.selected) + " model " + (sel.model ? sel.model.path : "null") + " p2 " + fm.get(2).path + " pos " + JSON.stringify(center(grid,2)) + " idxAt " + grid.indexAtContent(center(grid,2).x + grid.flick.contentX, center(grid,2).y + grid.flick.contentY) + " sels " + (grid.selection === sel) + " cnt " + grid.count + " cols " + grid.columns + " ptr " + grid.children.length + ")")
                clickAt(grid, 4, Qt.ControlModifier)
                check(sel.count === 2 && sel.selected[fm.get(4).path], "ctrl-click")
                clickAt(grid, 1, Qt.ControlModifier)
                check(sel.count === 3, "ctrl-click adds")
                clickAt(grid, 5)
                clickAt(grid, 3, Qt.ShiftModifier)
                check(samePaths(sel.paths(), pathsAt(3, 5)), "shift-click range")
                check(grid.highlightCount === 1, "contiguous run is one highlight (" + grid.highlightCount + ")")
                const h = grid.highlightRect(0)
                check(h.width > grid.positionAt(3).width * 2, "highlight spans run")
                clickAt(grid, 1)
                clickAt(grid, 3, Qt.ControlModifier)
                check(grid.highlightCount === 2, "gap makes two highlights")

                grid.forceActiveFocus()
                clickAt(grid, 1)
                keyClick(Qt.Key_Right, Qt.ShiftModifier)
                keyClick(Qt.Key_Right, Qt.ShiftModifier)
                check(sel.count === 3 && sel.currentIndex === 3, "shift+right extends (" + sel.count + "/" + sel.currentIndex + ")")
                keyClick(Qt.Key_Left, Qt.ShiftModifier)
                check(sel.count === 2, "shift+left shrinks")
                keyClick(Qt.Key_Down)
                check(sel.count === 1 && sel.currentIndex === Math.min(6, 2 + grid.columns), "down moves a row (" + sel.currentIndex + ")")
                keyClick(Qt.Key_End)
                check(sel.currentIndex === 6 && sel.count === 1, "End")
                keyClick(Qt.Key_Home)
                check(sel.currentIndex === 0 && sel.count === 1, "Home")
                keyClick(Qt.Key_A, Qt.ControlModifier)
                check(sel.count === 7, "ctrl+A")
                keyClick(Qt.Key_Escape)
                check(sel.count === 0, "Escape clears")
                check(checks.escSeen === 0, "Escape consumed while selection exists")
                keyClick(Qt.Key_Escape)
                check(checks.escSeen === 1, "Escape reaches parent when nothing is selected")
                sel.select(2)
                keyClick(Qt.Key_Left, Qt.AltModifier)
                check(checks.leftSeen === 1 && sel.currentIndex === 2, "Alt+Left passes through")
                keyClick(Qt.Key_Right, Qt.ControlModifier)
                check(sel.currentIndex === 2, "Ctrl+Right not consumed as navigation")
                const before = checks.ctxCount
                keyClick(Qt.Key_Menu)
                const pr = grid.positionAt(2)
                check(checks.ctxCount === before + 1 && checks.ctxIndex === 2, "Menu key requests context on current")
                check(checks.ctxPos.x > pr.x && checks.ctxPos.x < pr.x + pr.width && checks.ctxPos.y > pr.y && checks.ctxPos.y < pr.y + pr.height, "context position inside current item")
                keyClick(Qt.Key_F10, Qt.ShiftModifier)
                check(checks.ctxCount === before + 2 && checks.ctxIndex === 2, "Shift+F10 requests context")
                keyClick(Qt.Key_F10)
                check(checks.ctxCount === before + 2, "plain F10 ignored")
                sel.clear()

                // rubber band crossing 3 items of the first row, started from empty space in the second row
                check(grid.columns >= 5 && grid.columns < 7, "grid layout has two rows (" + grid.columns + ")")
                const cw = grid.cellW, ch = grid.cellH
                const x0 = cw * (grid.columns - 0.5), y0 = ch * 1.5
                check(grid.indexAtContent(x0, y0) === -1, "band origin is empty space")
                mousePress(grid, x0, y0)
                mouseMove(grid, x0 - cw, y0 - ch * 0.5)
                mouseMove(grid, cw * (grid.columns - 3 + 0.5), ch * 0.5)
                wait(30)
                mouseRelease(grid, cw * (grid.columns - 3 + 0.5), ch * 0.5)
                check(sel.count === 3 && samePaths(sel.paths(), pathsAt(grid.columns - 3, grid.columns - 1)), "band selects 3 (" + sel.count + ")")

                // survives re-sorting
                clickAt(grid, 2)
                const keep = fm.get(2).path
                // directories sort first in both orders, so compare the last row, which does change
                const first = fm.get(fm.count - 1).path
                fm.sortReversed = true
                waitFor(() => fm.get(fm.count - 1).path !== first, "model reordered", 5000)
                waitFor(() => sel.currentIndex >= 0 && fm.get(sel.currentIndex).path === keep, "current follows path", 3000)
                check(sel.count === 1 && sel.selected[keep] === true, "selection survives sort")
                fm.sortReversed = false
                waitFor(() => fm.get(fm.count - 1).path === first, "model back in order", 5000)

                // list view
                grid.visible = false
                list.visible = true
                waitFor(() => delegates(list).length === 7, "wait: () => delegates(list).length === 7", 3000)
                clickAt(list, 0)
                clickAt(list, 3, Qt.ShiftModifier)
                check(sel.count === 4, "list shift-click")
                check(list.highlightCount === 1, "list: 4 contiguous rows are one highlight (" + list.highlightCount + ")")
                check(Math.abs(list.highlightRect(0).height - (list.cellH * 4 - 2 * list.inset)) < 0.5, "list highlight is 4 rows tall (" + list.highlightRect(0).height + ")")
                list.forceActiveFocus()
                keyClick(Qt.Key_Down, Qt.ShiftModifier)
                check(sel.count === 5 && sel.currentIndex === 4, "list shift+down")
                keyClick(Qt.Key_Right)
                check(sel.currentIndex === 4, "list ignores left/right")
                list.visible = false
                grid.visible = true

                // thumbnail memo: same path+modified is served once, a new modified stamp asks again
                const before2 = suite.thumbCalls.length
                const got = []
                grid.resolveThumb("/x/memo.mp4", 128, (t, ok) => got.push(t), "A")
                grid.resolveThumb("/x/memo.mp4", 128, (t, ok) => got.push(t), "A")
                check(suite.thumbCalls.length - before2 === 1, "memo: same path+stamp asks the resolver once (" + (suite.thumbCalls.length - before2) + ")")
                grid.resolveThumb("/x/memo.mp4", 128, (t, ok) => got.push(t), "B")
                check(suite.thumbCalls.length - before2 === 2, "memo: new modified stamp is not served the old thumbnail")
                for (let i = 0; i < grid.thumbMemoLimit + 20; i++) grid.resolveThumb("/x/lru" + i + ".mp4", 128, () => {}, "A")
                check(grid.thumbMemoSize <= grid.thumbMemoLimit, "memo is bounded (" + grid.thumbMemoSize + ")")
                const clipBefore = suite.thumbCalls.filter(p => p.indexOf("clip.mp4") !== -1).length
                const keepRes = grid.thumbResolver
                grid.thumbResolver = null
                grid.thumbResolver = keepRes
                check(grid.thumbMemoSize === 0, "memo cleared when the resolver changes")
                // a visible video delegate asks again after the resolver changed
                const clipCalls = () => suite.thumbCalls.filter(p => p.indexOf("clip.mp4") !== -1).length
                waitFor(() => clipCalls() > clipBefore, "delegate re-requests after resolver change", 3000)
                reached++
            }

            function test_03_prune() {
                fm2.path = suite.root + "/ren"
                waitFor(() => fm2.ready && fm2.count === 3, "wait: () => fm2.ready && fm2.count === 3", 8000)
                const ia = fm2.indexOfName("a")
                sel2.select(ia)
                const pa = fm2.get(ia).path
                check(sel2.count === 1, "a selected")
                mutate(`mv "${suite.root}/ren/a" "${suite.root}/ren/z"`)
                waitFor(() => fm2.indexOfName("z") >= 0 && fm2.indexOfName("a") < 0 && fm2.count === 3, "renamed", 8000)
                waitFor(() => sel2.selected[pa] === undefined, "renamed path pruned", 3000)
                check(sel2.count === 0 && sel2.paths().length === 0, "count follows prune")
                check(fm2.count === 3 && sel2.selected[fm2.get(fm2.indexOfName("z")).path] === undefined, "renamed z is not selected")
                check(sel2.currentPath === "" || fm2.indexOfName(sel2.currentPath.split("/").pop()) >= 0, "currentPath is valid or empty (" + sel2.currentPath + ")")

                fm2.path = suite.root + "/flt"
                waitFor(() => fm2.ready && fm2.count === 6, "wait: () => fm2.ready && fm2.count === 6", 8000)
                fm2.filter = "m"
                waitFor(() => fm2.count === 3 && fm2.get(0).name.charAt(0) === "m", "wait: () => fm2.count === 3 && fm2.get(0).name.charAt(0) === 'm'", 3000)
                sel2.selectAll()
                check(sel2.count === 3, "three selected")
                fm2.filter = "n"
                waitFor(() => fm2.count === 3 && fm2.get(0).name.charAt(0) === "n", "wait: () => fm2.count === 3 && fm2.get(0).name.charAt(0) === 'n'", 3000)
                waitFor(() => sel2.paths().every(p => p.indexOf("/n") !== -1), "selection only has present paths", 3000)
                check(sel2.count === sel2.paths().length, "count matches paths after filter swap")
                reached++
            }

            // FolderListModel removes and re-inserts every row on a directory change, so
            // delegates are rebuilt; the view must not ask the resolver for a path twice.
            function noDupes() {
                const seen = {}
                for (const p of suite.thumbCalls.slice(calls0)) { if (seen[p]) { console.error("dup", p); return false } seen[p] = true }
                return true
            }
            property int calls0: 0
            function test_04_stable_scroll() {
                grid.model = fm3
                fm3.path = suite.root + "/four"
                waitFor(() => fm3.ready && fm3.count === 400, "wait: () => fm3.ready && fm3.count === 400", 8000)
                waitFor(() => delegates(grid).length > 0, "wait: () => delegates(grid).length > 0", 3000)
                const f = grid.flick
                f.contentY = 3000
                wait(200)
                check(Math.abs(f.contentY - 3000) < 1, "scrolled to 3000 (" + f.contentY + ")")
                calls0 = suite.thumbCalls.length
                mutate(`touch "${suite.root}/four/zzz.mp4"`)
                waitFor(() => fm3.count === 401, "item added", 8000)
                wait(250)
                check(Math.abs(f.contentY - 3000) < 1, "contentY kept after add (" + f.contentY + ")")
                check(noDupes(), "no duplicate thumb requests after add")
                mutate(`rm "${suite.root}/four/zzz.mp4"`)
                waitFor(() => fm3.count === 400, "item removed", 8000)
                wait(250)
                check(Math.abs(f.contentY - 3000) < 1, "contentY kept after remove (" + f.contentY + ")")
                check(noDupes(), "no duplicate thumb requests after remove")
                grid.model = fm
                reached++
            }

            function test_05_many() {
                grid.visible = false
                bigGrid.visible = true
                big.path = suite.root + "/many"
                waitFor(() => big.ready && big.count === 20000, "wait: () => big.ready && big.count === 20000", 30000)
                waitFor(() => delegates(bigGrid).length > 0, "wait: () => delegates(bigGrid).length > 0", 5000)
                selBig.clear()
                check(allDelegates(bigGrid) < 200, "all delegates incl. pooled < 200 (" + allDelegates(bigGrid) + ")")
                const t0 = Date.now()
                selBig.selectAll()
                const dt = Date.now() - t0
                console.log("selectAll(20000):", dt, "ms")
                check(selBig.count === 20000, "selectAll count")
                check(dt < 4000, "selectAll time " + dt)
                selBig.clear()
                bigGrid.forceActiveFocus()
                keyClick(Qt.Key_End)
                check(selBig.currentIndex === 19999 && selBig.count === 1, "End on 20k")
                wait(150)
                const f = bigGrid.flick
                check(f.contentY >= f.contentHeight - f.height - 2, "scrolled to bottom (" + f.contentY + "/" + f.contentHeight + ")")
                waitFor(() => delegates(bigGrid).some(d => d.index === 19999), "last delegate exists", 3000)
                let ghosts = 0
                const buffer = bigGrid.cellH * 3
                for (const d of delegates(bigGrid)) {
                    if (d.index < 0 || d.index >= 20000 || d.y > f.contentY + f.height + buffer || d.y + d.height < f.contentY - buffer) ghosts++
                    else if (d.entry.path !== big.get(d.index).path) ghosts++
                }
                check(ghosts === 0, "no ghost delegates at bottom (" + ghosts + ")")
                check(allDelegates(bigGrid) < 200, "all delegates still < 200 after scroll (" + allDelegates(bigGrid) + ")")
                keyClick(Qt.Key_Home)
                wait(150)
                check(selBig.currentIndex === 0 && f.contentY <= 1, "Home scrolls to top (" + f.contentY + ")")
                waitFor(() => delegates(bigGrid).some(d => d.index === 0), "wait: () => delegates(bigGrid).some(d => d.index === 0)", 3000)
                keyClick(Qt.Key_PageDown)
                check(selBig.currentIndex > 0, "PageDown moves")
                check(reached === 4, "all four earlier tests ran to their last line (" + reached + ")")
                passInfo = "20k: all delegates=" + allDelegates(bigGrid)
                reached++
            }

            // A thumbnail request nobody waits for any more is withdrawn: recycled, destroyed or re-pointed
            // delegates, a folder change and a hidden window leave nothing queued behind.
            Component { id: delegateComponent; FileDelegate { width: 100; height: 100 } }
            Component { id: bareGridComponent; FileGrid { width: 300; height: 300 } }
            function test_06_thumb_requests_are_withdrawn() {
                // -- delegate level. Requests still wanted = asked and neither withdrawn nor answered.
                const asked = [], cancelled = []
                const resolver = (path, size, cb, stamp) => { asked.push({path: path, cb: cb}) }
                const canceller = (path, size, cb, stamp) => { cancelled.push({path: path, cb: cb}) }
                const wanted = () => asked.filter(a => !cancelled.some(c => c.cb === a.cb) && !a.done).map(a => a.path)
                const d = delegateComponent.createObject(checks, { index: 0, thumbResolver: resolver, thumbCancel: canceller,
                    entry: { name: "a.mp4", path: "/x/a.mp4", isDir: false, modified: "1" } })
                check(JSON.stringify(wanted()) === '["/x/a.mp4"]', "delegate wants exactly its video thumbnail " + JSON.stringify(wanted()))
                d.entry = { name: "b.mp4", path: "/x/b.mp4", isDir: false, modified: "1" }
                check(JSON.stringify(wanted()) === '["/x/b.mp4"]', "re-pointing withdraws the old request " + JSON.stringify(wanted()))
                d.onScreen = false
                check(wanted().length === 0, "leaving the screen withdraws the request " + JSON.stringify(wanted()))
                d.onScreen = true
                check(JSON.stringify(wanted()) === '["/x/b.mp4"]', "coming back asks again " + JSON.stringify(wanted()))
                const open = asked.filter(a => wanted().length && a.path === "/x/b.mp4" && !cancelled.some(c => c.cb === a.cb))[0]
                open.cb("/tmp/t.png", true)
                open.done = true
                const nCancelled = cancelled.length
                d.onScreen = false
                check(cancelled.length === nCancelled, "a finished request is not withdrawn")
                d.onScreen = true
                d.destroy()
                const d2 = delegateComponent.createObject(checks, { index: 1, thumbResolver: resolver, thumbCancel: canceller,
                    entry: { name: "c.mp4", path: "/x/c.mp4", isDir: false, modified: "1" } })
                check(wanted().indexOf("/x/c.mp4") >= 0, "second delegate waits for its thumbnail")
                d2.destroy()
                wait(50)
                check(wanted().indexOf("/x/c.mp4") < 0, "destroying a waiting delegate withdraws its request " + JSON.stringify(wanted()))
                // -- view level: waiters share one request, which is dropped when the last one leaves
                const dropped = []
                const started = []
                const g = bareGridComponent.createObject(checks, { model: fm, selection: sel, iconSize: 64,
                    thumbResolver: (path, size, cb) => { if (path.indexOf("/x/") === 0) started.push(path) },
                    thumbCanceller: (path, size) => { if (path.indexOf("/x/") === 0) dropped.push(path) } })
                const cb1 = () => {}, cb2 = () => {}
                g.resolveThumb("/x/s.mp4", 128, cb1, "1")
                g.resolveThumb("/x/s.mp4", 128, cb2, "1")
                g.resolveThumb("/x/t.mp4", 128, cb1, "1")
                check(started.length === 2, "two distinct requests started (" + started.length + ")")
                g.cancelThumb("/x/s.mp4", 128, cb1, "1")
                check(dropped.length === 0, "a request somebody still waits for stays")
                g.cancelThumb("/x/s.mp4", 128, cb2, "1")
                check(dropped.length === 1 && dropped[0] === "/x/s.mp4", "the last waiter drops the request")
                // folder change: every request still waiting is dropped
                fm.path = suite.root + "/ren"
                waitFor(() => dropped.length === 2 && dropped[1] === "/x/t.mp4", "folder change drops waiting requests (" + JSON.stringify(dropped) + ")")
                // hidden window: waiting requests dropped and none made while hidden; shown again re-requests
                g.resolveThumb("/x/u.mp4", 128, cb1, "1")
                check(started.length === 3, "request made while visible")
                g.loadThumbs = false
                check(dropped.length === 3 && dropped[2] === "/x/u.mp4", "hiding drops the waiting request")
                g.resolveThumb("/x/v.mp4", 128, cb1, "1")
                check(started.length === 3, "nothing is requested while hidden")
                const epoch = g.thumbEpoch
                g.loadThumbs = true
                check(g.thumbEpoch === epoch + 1, "showing again makes delegates ask again")
                g.destroy()
                reached++
            }

            // Runs last (alphabetical). Keeps QtTest from ending the process before the fixture
            // is removed and the sticky exit code is applied.
            function test_99_exit() {
                suite.finish(0)
                for (let i = 0; i < 1200 && !suite.cleaned; i++) wait(50)
                if (!suite.cleaned) { console.error("FAIL: files views fixture cleanup did not finish"); suite.exitCode = 1 }
                if (suite.exitCode === 0 && reached !== 6) {
                    console.error("FAIL: files views tests incompletos (" + reached + "/6 llegaron a su ultima linea)")
                    suite.exitCode = 1
                }
                if (suite.exitCode !== 0) Qt.exit(suite.exitCode)
                else console.log("PASS: files views (selection, click/ctrl/shift/keys/band, highlight runs, reorder, rename/filter prune, list highlight, thumb memo, resolver change re-requests, thumb withdrawal, " + passInfo + ")")
            }
        }
    }
}
