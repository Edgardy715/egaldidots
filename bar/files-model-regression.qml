import QtQuick
import Quickshell
import Quickshell.Io
import "components/files"
import "components/files/PathUtil.js" as PathUtil

// Run: ISLA_CONFIG=/tmp/isla-files-test.json QT_QPA_PLATFORM=offscreen qs -p bar/files-model-regression.qml
// Builds its own fixture under mktemp (override the parent with ISLA_FILES_TEST_DIR) and removes it at the end.
ShellRoot {
    id: suite
    property string root: ""
    property var queue: []
    property int lostCount: 0
    property string lostFallback: ""

    function fail(message) {
        console.error("FAIL: " + message)
        cleanup(1)
    }
    function check(ok, message) { if (!ok) { fail(message); return false } return true }
    function cleanup(code) {
        watchdog.stop()
        if (suite.root.length && suite.root.indexOf("/isla-files-test.") !== -1) {
            cleaner.finalCode = code
            cleaner.running = true
        } else Qt.exit(code)
    }
    // Poll until condition() holds, then run next(); fail on timeout.
    function waitFor(condition, label, next) {
        let waited = 0
        poll.callback = () => {
            waited += poll.interval
            if (condition()) { poll.stop(); next() }
            else if (waited > 8000) { poll.stop(); fail("timeout waiting for " + label + " [status=" + model._folderModel.status + " count=" + model.count + " path=" + model.path + " unl=" + model.unlistable + "]") }
        }
        poll.restart()
    }
    function settled(path) {
        return !model.loading && model.ready && model.path === path
    }

    Timer { id: poll; interval: 20; repeat: true; property var callback: null; onTriggered: if (callback) callback() }
    Timer { id: watchdog; interval: 40000; running: true; onTriggered: suite.fail("global watchdog") }

    Process {
        id: cleaner
        property int finalCode: 0
        command: ["rm", "-rf", suite.root]
        onExited: Qt.exit(finalCode)
    }
    Process {
        id: maker
        command: ["sh", "-c", `
            set -e
            base=\${ISLA_FILES_TEST_DIR:-/tmp}
            root=$(mktemp -d "$base/isla-files-test.XXXXXX")
            mkdir "$root/empty" "$root/many" "$root/links" "$root/cafe" "$root/doomed" "$root/doomed/sub" "$root/hidden"
            (cd "$root/many" && seq -f 'f%g' 1 20000 | xargs touch)
            ln -s /nonexistent-target "$root/links/dangling"
            touch "$root/links/real.txt"
            touch "$root/cafe/Café.txt" "$root/cafe/Zeta.txt" "$root/cafe/Cafetera.md"
            touch "$root/hidden/.secret" "$root/hidden/open"
            touch "$root/doomed/sub/x"
            mkdir "$root/onlydangling" "$root/gone"
            ln -s /nonexistent-target "$root/onlydangling/broken"
            mkdir "$root/odd"
            for n in 'a #1' 'p%41' 'q?x' 'a%2Fb'; do mkdir "$root/odd/$n"; touch "$root/odd/$n/inner.txt"; done
            printf '%s' "$root"`]
        stdout: StdioCollector { id: makerOut; onStreamFinished: { suite.root = text.trim(); suite.pureChecks(); } }
        onExited: code => { if (code !== 0) suite.fail("fixture creation failed") }
    }

    FilesModel {
        id: model
        onPathLost: fallback => { suite.lostCount++; suite.lostFallback = fallback }
    }

    function pureChecks() {
        const tricky = "/t/a#b%20c?.txt"
        const url = PathUtil.toUrl(tricky)
        if (!check(url.indexOf("file:///") === 0, "toUrl scheme: " + url)) return
        if (!check(url.indexOf("#") === -1 && url.indexOf("?") === -1 && url.indexOf(" ") === -1, "toUrl leaves reserved chars: " + url)) return
        if (!check(PathUtil.fromUrl(url) === tricky, "fromUrl round trip: " + PathUtil.fromUrl(url))) return
        const nl = "/t/a\nb c.txt"
        if (!check(PathUtil.fromUrl(PathUtil.toUrl(nl)) === nl && PathUtil.toUrl(nl).indexOf("\n") === -1, "newline round trip")) return
        if (!check(PathUtil.fromUrl(Qt.url("file:///mnt/u")) === "/mnt/u", "fromUrl accepts url objects")) return
        const seg = PathUtil.segments("/mnt/u/x")
        if (!check(seg.length === 4 && seg[0].name === "/" && seg[0].path === "/" && seg[3].name === "x"
                   && seg[3].path === "/mnt/u/x" && seg[2].path === "/mnt/u", "segments: " + JSON.stringify(seg))) return
        if (!check(PathUtil.segments("/").length === 1, "segments root")) return
        if (!check(PathUtil.parent("/mnt/u/x") === "/mnt/u" && PathUtil.parent("/mnt") === "/"
                   && PathUtil.parent("/") === "/" && PathUtil.parent("/mnt/u/") === "/mnt", "parent")) return
        const alive = { "/mnt": true, "/": true }
        if (!check(PathUtil.nearestExisting("/mnt/u/x", p => alive[p] === true) === "/mnt", "nearestExisting")) return
        if (!check(PathUtil.nearestExisting("/zz/y", () => false) === "/", "nearestExisting floor")) return
        stepEmpty()
    }

    function stepEmpty() {
        const p = suite.root + "/empty"
        model.navigate(p)
        waitFor(() => settled(p), "empty folder", () => {
            if (!check(model.count === 0, "empty folder count " + model.count)) return
            stepMany()
        })
    }
    function stepMany() {
        const p = suite.root + "/many"
        model.navigate(p)
        waitFor(() => settled(p) && model.count > 0, "20000 files", () => {
            if (!check(model.count === 20000, "many count " + model.count)) return
            if (!check(model.get(0).name.length > 0 && model.get(0).isDir === false, "get(0)")) return
            if (!check(model.indexOfName("f777") >= 0 && model.get(model.indexOfName("f777")).name === "f777", "indexOfName")) return
            if (!check(model.indexOfName("nope") === -1, "indexOfName missing")) return
            stepLinks()
        })
    }
    function stepLinks() {
        const p = suite.root + "/links"
        model.navigate(p)
        waitFor(() => settled(p) && model.count > 0, "links", () => {
            // FolderListModel (QDir without System) omits broken symlinks: the listing must not hang or error.
            if (!check(model.count === 1 && model.indexOfName("real.txt") >= 0, "links count " + model.count)) return
            console.log("NOTE: broken symlink hidden by FolderListModel (indexOfName=" + model.indexOfName("dangling") + ")")
            stepFilter()
        })
    }
    function stepFilter() {
        const p = suite.root + "/cafe"
        model.navigate(p)
        waitFor(() => settled(p) && model.count === 3, "cafe", () => {
            model.filter = "cafe"
            waitFor(() => model.count === 2, "filter cafe", () => {
                const names = [model.get(0).name, model.get(1).name].sort()
                if (!check(names.includes("Café.txt") && names.includes("Cafetera.md"), "filter results " + JSON.stringify(names))) return
                if (!check(model.get(0).path.indexOf(p + "/") === 0 && model.get(0).url.indexOf("file:///") === 0, "get fields while filtered")) return
                model.filter = "CAFÉ"
                waitFor(() => model.count === 2, "filter accents/case", () => {
                    model.filter = ""
                    waitFor(() => model.count === 3, "filter cleared", stepHidden)
                })
            })
        })
    }
    function stepHidden() {
        const p = suite.root + "/hidden"
        model.navigate(p)
        waitFor(() => settled(p), "hidden", () => {
            if (!check(model.count === 1, "hidden off count " + model.count)) return
            model.showHidden = true
            waitFor(() => model.count === 2, "hidden on", stepOdd)
        })
    }
    property var oddNames: ["a #1", "p%41", "q?x", "a%2Fb"]
    property int oddIndex: 0
    // Names FolderListModel may fail to open: each must list its file or flag `unlistable`.
    function stepOdd() {
        if (oddIndex >= oddNames.length) { model.showHidden = false; stepDangling(); return }
        const p = suite.root + "/odd/" + oddNames[oddIndex]
        model.navigate(p)
        model.watchPath = true
        waitFor(() => model.path === p && (model.count === 1 || model.unlistable), "odd " + oddNames[oddIndex], () => {
            model.watchPath = false
            waitFor(() => model.count === 1 || model.unlistable, "odd result " + oddNames[oddIndex], () => {
                console.log("NOTE: odd '" + oddNames[oddIndex] + "' count=" + model.count + " unlistable=" + model.unlistable)
                if (!check(model.count === 1 && !model.unlistable && model.get(0).name === "inner.txt"
                           && model.get(0).path === suite.root + "/odd/" + oddNames[oddIndex] + "/inner.txt", "odd name not listed: " + oddNames[oddIndex])) return
                oddIndex++
                stepOdd()
            })
        })
    }
    // Positive unlistable: only a broken symlink inside; a folder with real files must stay false (checked in stepOdd).
    function stepDangling() {
        const p = suite.root + "/onlydangling"
        model.navigate(p)
        model.watchPath = true
        waitFor(() => model.path === p && model.unlistable, "unlistable onlydangling", () => {
            model.watchPath = false
            if (!check(model.count === 0 && model.unlistable === true, "onlydangling count/unlistable")) return
            stepFastNav()
        })
    }
    // A -> B quickly with B already deleted: pathLost must arrive without waiting for a slow tick.
    function stepFastNav() {
        const a = suite.root + "/empty"
        const b = suite.root + "/gone"
        suite.lostCount = 0
        suite.lostFallback = ""
        deleter.running = true
        suite.waitFor(() => !deleter.running, "gone deleted", () => {
            model.watchPath = false
            model.navigate(a)
            model.navigate(b)
            suite.waitFor(() => suite.lostCount > 0, "pathLost for fast nav", () => {
                if (!suite.check(suite.lostCount === 1 && suite.lostFallback === suite.root, "fast nav pathLost " + suite.lostCount + " " + suite.lostFallback)) return
                stepGet()
            })
        })
    }
    Process { id: deleter; command: ["rm", "-rf", suite.root + "/gone"] }
    function stepGet() {
        model.filter = "zzz"
        if (!check(model.get(0) === null && model.get(-1) === null && model.get(5) === null, "get out of range")) return
        model.filter = ""
        const p = suite.root + "/empty"
        model.navigate(p)
        if (!check(model.path === p, "path")) return
        model.navigate(p + "/")
        if (!check(model.path === p, "trailing slash normalised: " + model.path)) return
        waitFor(() => settled(p), "empty again", () => {
            model.recheck()
            waitFor(() => !model.unlistable, "empty not unlistable", () => {
                if (!check(model.unlistable === false, "empty folder flagged unlistable")) return
                stepLost()
            })
        })
    }
    function stepLost() {
        const p = suite.root + "/doomed/sub"
        suite.lostCount = 0
        suite.lostFallback = ""
        model.navigate(p)
        waitFor(() => settled(p) && model.count === 1, "doomed/sub", () => {
            killer.running = true
        })
    }
    Process {
        id: killer
        command: ["rm", "-rf", suite.root + "/doomed"]
        onExited: suite.waitFor(() => suite.lostCount > 0, "pathLost", () => {
            if (!suite.check(suite.lostFallback === suite.root, "pathLost fallback " + suite.lostFallback)) return
            // Several watch ticks later it must still have been emitted exactly once.
            model.watchPath = true
            let ticks = 0
            suite.waitFor(() => ++ticks > 200, "ticks", () => {
                if (!suite.check(suite.lostCount === 1, "pathLost emitted " + suite.lostCount + " times")) return
            console.log("PASS: PathUtil and FilesModel (empty, 20000 files, dangling symlink, filter, hidden, odd names, pathLost)")
            suite.cleanup(0)
            })
        })
    }

    Component.onCompleted: maker.running = true
}
