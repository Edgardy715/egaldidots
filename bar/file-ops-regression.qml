import QtQuick
import Quickshell
import Quickshell.Io
import "Singletons"

// Run: ISLA_FILES_TEST_DIR=$(mktemp -d) ISLA_CONFIG=$(mktemp -u).json QT_QPA_PLATFORM=offscreen qs -p bar/file-ops-regression.qml
// Fixture under ISLA_FILES_TEST_DIR (default /tmp); trash and thumbnail caches are redirected
// into it through FileOps.environment, so the real HOME and trash are never touched.
ShellRoot {
    id: suite
    settings.watchFiles: false

    property string root: ""
    property var log: []            // finished() events in arrival order
    property var itemErrors: []
    property real maxProgress: 0
    property bool cancelOnProgress: false
    property bool cancelSent: false
    property int step: 0
    property int maxThumbs: 0
    property bool fixPythonOnFinish: false
    readonly property var weird: [
        "sp ace #hash?q %25 \"dq\" 'sq'.txt",
        "uni ñ 日本語 🙂.txt",
        "nl\nin name.txt"
    ]

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
    function waitFor(condition, label, next, limit) {
        let waited = 0
        poll.callback = () => {
            waited += poll.interval
            if (condition()) { poll.stop(); next() }
            else if (waited > (limit || 10000)) { poll.stop(); fail("timeout waiting for " + label + " log=" + JSON.stringify(suite.log)) }
        }
        poll.restart()
    }
    // Wait until the n-th finished() event arrived, then hand it to next().
    function waitFinished(count, label, next) {
        waitFor(() => suite.log.length >= count, label, () => next(suite.log[count - 1]))
    }
    function idle(next) { waitFor(() => !FileOps.busy, "idle", next) }
    // Run a python check; script gets argv[1:] and exits 0 when everything holds.
    function verify(script, args, label, next) {
        checker.label = label
        checker.after = next
        checker.command = ["python3", "-I", "-c", script].concat(args)
        checker.running = true
    }

    Timer { id: poll; interval: 20; repeat: true; property var callback: null; onTriggered: if (callback) callback() }
    Timer { id: watchdog; interval: 90000; running: true; onTriggered: suite.fail("global watchdog") }

    Connections {
        target: FileOps
        function onFinished(op, ok, message) {
            if (suite.fixPythonOnFinish) { suite.fixPythonOnFinish = false; FileOps.pythonPath = "python3" }
            suite.log = suite.log.concat([{op: op, ok: ok, message: message}])
        }
        function on_ActiveThumbsChanged() { suite.maxThumbs = Math.max(suite.maxThumbs, FileOps._activeThumbs) }
        function onItemFailed(path, error) { suite.itemErrors = suite.itemErrors.concat([{path: path, error: error}]) }
        function onProgressChanged() {
            suite.maxProgress = Math.max(suite.maxProgress, FileOps.progress)
            if (suite.cancelOnProgress && !suite.cancelSent && FileOps.progress > 0 && FileOps.progress < 1) {
                suite.cancelSent = true
                FileOps.cancel()
            }
        }
    }

    Process {
        id: cleaner
        property int finalCode: 0
        command: ["rm", "-rf", suite.root]
        onExited: Qt.exit(finalCode)
    }
    Process {
        id: checker
        property string label: ""
        property var after: null
        onExited: code => {
            if (code !== 0) suite.fail("verify failed: " + label + " (exit " + code + ")")
            else if (after) after()
        }
    }
    Process {
        id: maker
        command: ["sh", "-c", `
            set -e
            base=\${ISLA_FILES_TEST_DIR:-/tmp}
            root=$(mktemp -d "$base/isla-files-test.XXXXXX")
            mkdir "$root/src" "$root/dst" "$root/dst2" "$root/dst3" "$root/weird" "$root/big" "$root/xdg" "$root/misc"
            printf hello > "$root/src/a.txt"
            truncate -s 256M "$root/big/big.bin"
            printf r0 > "$root/misc/r0"
            echo "$root"
        `]
        stdout: StdioCollector { id: makerOut }
        onExited: code => {
            if (code !== 0) { suite.fail("fixture creation failed"); return }
            suite.root = makerOut.text.trim()
            suite.createWeird()
        }
    }
    Process {
        id: weirdMaker
        stdinEnabled: true
        command: ["python3", "-I", "-c", `
import json, os, sys
root = sys.argv[1]
for name in json.loads(sys.argv[2]):
    with open(os.path.join(root, "weird", name), "w") as fp:
        fp.write(name)
`]
        onExited: code => {
            if (code !== 0) { suite.fail("weird fixture failed"); return }
            FileOps.environment = ({XDG_DATA_HOME: suite.root + "/xdg/data", XDG_CACHE_HOME: suite.root + "/xdg/cache"})
            suite.runAll()
        }
    }
    function createWeird() {
        weirdMaker.command = weirdMaker.command.slice(0, 4).concat([suite.root, JSON.stringify(suite.weird)])
        weirdMaker.running = true
    }

    function runAll() {
        const r = suite.root
        const names = JSON.stringify(suite.weird)
        const sequence = [
            // 1. copy + progress to 1.0
            next => {
                suite.maxProgress = 0
                FileOps.copy([r + "/src/a.txt"], r + "/dst", "skip")
                check(FileOps.busy, "busy right after copy()")
                waitFinished(1, "copy", ev => {
                    if (!check(ev.op === "copy" && ev.ok, "copy finished ok: " + JSON.stringify(ev))) return
                    check(suite.maxProgress === 1, "progress reached 1.0 (max " + suite.maxProgress + ")")
                    idle(() => {
                        check(FileOps.progress === 1 || FileOps.progress === 0, "progress settled")
                        check(FileOps.current === "", "current cleared when idle")
                        check(!FileOps.canUndo, "copy is not undoable")
                        verify("import sys; assert open(sys.argv[1] + '/dst/a.txt').read() == 'hello'", [r], "copied content", next)
                    })
                })
            },
            // 2. odd names survive the JSON round trip
            next => {
                const paths = suite.weird.map(n => r + "/weird/" + n)
                FileOps.copy(paths, r + "/dst2", "skip")
                waitFinished(2, "weird copy", ev => {
                    if (!check(ev.op === "copy" && ev.ok, "weird copy ok: " + JSON.stringify(ev))) return
                    verify("import json, os, sys\nroot = sys.argv[1] + '/dst2'\nnames = json.loads(sys.argv[2])\n"
                        + "assert sorted(os.listdir(root)) == sorted(names), os.listdir(root)\n"
                        + "for n in names: assert open(os.path.join(root, n)).read() == n\n",
                        [r, names], "weird names intact", next)
                })
            },
            // 3. conflicts query
            next => {
                let got = null
                FileOps.conflicts([r + "/src/a.txt", r + "/weird/" + suite.weird[1]], r + "/dst2", (result, ok) => got = {result: result, ok: ok})
                waitFor(() => got !== null, "conflicts callback", () => {
                    check(got.ok && JSON.stringify(got.result) === JSON.stringify([suite.weird[1]]), "conflicts names: " + JSON.stringify(got))
                    next()
                })
            },
            // 4. trash then undo restores
            next => {
                FileOps.trash([r + "/dst/a.txt"])
                waitFinished(3, "trash", ev => {
                    if (!check(ev.op === "trash" && ev.ok, "trash ok: " + JSON.stringify(ev))) return
                    check(FileOps.canUndo, "trash is undoable")
                    verify("import os, sys; assert not os.path.lexists(sys.argv[1] + '/dst/a.txt'); assert os.listdir(sys.argv[1] + '/xdg/data/Trash/files') == ['a.txt']", [r], "trashed", () => {
                        FileOps.undo()
                        waitFinished(4, "undo trash", uev => {
                            if (!check(uev.op === "undo" && uev.ok, "undo ok: " + JSON.stringify(uev))) return
                            check(!FileOps.canUndo, "undo stack empty after undo")
                            verify("import sys; assert open(sys.argv[1] + '/dst/a.txt').read() == 'hello'", [r], "restored", next)
                        })
                    })
                })
            },
            // 5. move then undo (moveback), rename then undo
            next => {
                FileOps.move([r + "/dst/a.txt"], r + "/dst3", "skip")
                waitFinished(5, "move", ev => {
                    if (!check(ev.op === "move" && ev.ok && FileOps.canUndo, "move ok+undoable: " + JSON.stringify(ev))) return
                    verify("import os, sys; assert os.path.exists(sys.argv[1] + '/dst3/a.txt') and not os.path.exists(sys.argv[1] + '/dst/a.txt')", [r], "moved", () => {
                        FileOps.undo()
                        waitFinished(6, "undo move", uev => {
                            if (!check(uev.op === "undo" && uev.ok, "undo move ok: " + JSON.stringify(uev))) return
                            verify("import os, sys; assert os.path.exists(sys.argv[1] + '/dst/a.txt') and not os.path.exists(sys.argv[1] + '/dst3/a.txt')", [r], "moved back", next)
                        })
                    })
                })
            },
            next => {
                FileOps.rename(r + "/dst/a.txt", "b b.txt")
                waitFinished(7, "rename", ev => {
                    if (!check(ev.op === "rename" && ev.ok && FileOps.canUndo, "rename ok: " + JSON.stringify(ev))) return
                    FileOps.undo()
                    waitFinished(8, "undo rename", uev => {
                        if (!check(uev.ok, "undo rename ok: " + JSON.stringify(uev))) return
                        verify("import os, sys; assert os.path.exists(sys.argv[1] + '/dst/a.txt') and not os.path.exists(sys.argv[1] + '/dst/b b.txt')", [r], "renamed back", next)
                    })
                })
            },
            // 6. cancel a large copy
            next => {
                suite.cancelOnProgress = true
                suite.cancelSent = false
                FileOps.copy([r + "/big/big.bin"], r + "/dst3", "skip")
                waitFinished(9, "cancelled copy", ev => {
                    suite.cancelOnProgress = false
                    check(suite.cancelSent, "cancel() was issued mid-copy")
                    if (!check(ev.op === "copy" && ev.ok === false, "cancelled copy reports ok=false: " + JSON.stringify(ev))) return
                    idle(() => verify("import os, sys; assert not os.path.lexists(sys.argv[1] + '/dst3/big.bin'), 'partial left'", [r], "no partial file", next))
                })
            },
            // 7. FIFO order
            next => {
                FileOps.copy([r + "/src/a.txt"], r + "/dst3", "skip")
                FileOps.mkdir(r + "/dst3", "made dir")
                FileOps.rename(r + "/misc/r0", "r0-renamed")
                waitFinished(12, "three queued jobs", () => {
                    const tail = suite.log.slice(9, 12).map(e => e.op)
                    check(JSON.stringify(tail) === JSON.stringify(["copy", "mkdir", "rename"]), "FIFO order: " + JSON.stringify(tail))
                    check(suite.log.slice(9, 12).every(e => e.ok), "queued jobs ok")
                    // undo stack bounded to 20: chain 21 renames, then undo everything
                    FileOps.undo()   // undo r0-renamed first so the chain starts from r0
                    waitFinished(13, "undo rename r0", () => {
                        let from = r + "/misc/r0"
                        for (let i = 1; i <= 21; ++i) {
                            FileOps.rename(from, "r" + i)
                            from = r + "/misc/r" + i
                        }
                        waitFinished(13 + 21, "21 renames", () => idle(() => {
                            // drain the stack one undo at a time (undo() is ignored while busy)
                            let undone = 0
                            const base = suite.log.length
                            const drain = () => {
                                if (!FileOps.canUndo) {
                                    check(undone === 20, "undo stack bounded at 20 (got " + undone + ")")
                                    verify("import os, sys; d = sys.argv[1] + '/misc'; assert os.listdir(d) == ['r1'], os.listdir(d); assert open(d + '/r1').read() == 'r0'", [r], "oldest rename not undone", next)
                                    return
                                }
                                FileOps.undo()
                                undone++
                                waitFinished(base + undone, "undo " + undone, () => idle(drain))
                            }
                            drain()
                        }))
                    })
                })
            },
            // 8. missing helper never hangs
            next => {
                const before = suite.log.length
                FileOps.helperPath = "/no/existe"
                FileOps.copy([r + "/src/a.txt"], r + "/dst3", "skip")
                waitFinished(before + 1, "copy with missing helper", ev => {
                    check(ev.op === "copy" && ev.ok === false && String(ev.message).length > 0, "missing helper reports failure: " + JSON.stringify(ev))
                    let got = null
                    FileOps.thumb(r + "/src/a.txt", 128, (result, ok) => got = {result: result, ok: ok})
                    waitFor(() => got !== null, "thumb callback with missing helper", () => {
                        check(got.ok === false && got.result === "", "thumb falls back: " + JSON.stringify(got))
                        FileOps.helperPath = ""
                        idle(next)
                    })
                })
            },
            // 10. thumbs: capped at 3 processes, dedup, cancelThumb
            next => {
                suite.maxThumbs = 0
                const spawned = FileOps._thumbSpawned
                let calls = 0
                let dropped = 0
                for (let i = 0; i < 20; ++i) FileOps.thumb(r + "/src/none" + i + ".mp4", 128, () => calls++)
                FileOps.cancelThumb(r + "/src/none19.mp4", 128)
                FileOps.thumb(r + "/src/none19.mp4", 128, () => dropped++)   // fresh request after cancel
                let dedup = 0
                FileOps.thumb(r + "/src/none0.mp4", 128, () => dedup++)       // joins the live request
                waitFor(() => calls >= 19 && dropped === 1 && dedup === 1 && FileOps._activeThumbs === 0, "20 thumbs", () => {
                    check(suite.maxThumbs >= 1 && suite.maxThumbs <= 3, "never more than 3 thumb processes (max " + suite.maxThumbs + ")")
                    check(FileOps._thumbSpawned - spawned === 20, "20 processes for 20 distinct requests + dedup (" + (FileOps._thumbSpawned - spawned) + ")")
                    // dropped request: queue 6, cancel the last queued one, its cb must never run
                    let ran = 0, never = 0
                    for (let i = 0; i < 6; ++i) FileOps.thumb(r + "/src/c" + i + ".mp4", 64, () => ran++)
                    FileOps.thumb(r + "/src/cancelled.mp4", 64, () => never++)
                    FileOps.cancelThumb(r + "/src/cancelled.mp4", 64)
                    waitFor(() => ran >= 6 && FileOps._activeThumbs === 0, "6 thumbs", () => {
                        check(never === 0, "cancelled thumb callback not called")
                        // drain: 12 requests, 3 start at once; withdrawing the other 9 empties the queue and spawns nothing more
                        const base = FileOps._thumbSpawned
                        let late = 0
                        for (let i = 0; i < 12; ++i) FileOps.thumb(r + "/src/d" + i + ".mp4", 32, () => late++)
                        check(FileOps._thumbQueue.length === 9, "9 thumbs queued behind 3 running (" + FileOps._thumbQueue.length + ")")
                        for (let i = 0; i < 12; ++i) FileOps.cancelThumb(r + "/src/d" + i + ".mp4", 32)
                        check(FileOps._thumbQueue.length === 0, "withdrawing drains the queue (" + FileOps._thumbQueue.length + ")")
                        waitFor(() => FileOps._activeThumbs === 0, "running thumbs finish", () => {
                            check(FileOps._thumbSpawned - base === 3, "no new spawn for withdrawn paths (" + (FileOps._thumbSpawned - base) + ")")
                            next()
                        })
                    })
                })
            },
            // 11. interpreter that cannot start: no hang, queue advances, queries answer
            next => {
                const before = suite.log.length
                FileOps.pythonPath = "/no/existe/python"
                suite.fixPythonOnFinish = true
                FileOps.copy([r + "/src/a.txt"], r + "/dst3", "keepboth")
                FileOps.mkdir(r + "/dst3", "after failure")
                waitFinished(before + 2, "unstartable then next", () => {
                    const a = suite.log[before], b = suite.log[before + 1]
                    check(a.op === "copy" && a.ok === false && String(a.message).length > 0, "unstartable copy fails clearly: " + JSON.stringify(a))
                    check(b.op === "mkdir" && b.ok === true, "next queued job still runs: " + JSON.stringify(b))
                    FileOps.pythonPath = "/no/existe/python"
                    let c = null, t = null
                    FileOps.conflicts([r + "/src/a.txt"], r + "/dst", (res, ok) => c = {res: res, ok: ok})
                    FileOps.thumb(r + "/src/x.mp4", 99, (res, ok) => t = {res: res, ok: ok})
                    waitFor(() => c !== null && t !== null, "query callbacks", () => {
                        FileOps.pythonPath = "python3"
                        check(c.ok === false && c.res.length === 0 && t.ok === false && t.res === "", "queries fail without hanging")
                        check(FileOps._activeThumbs === 0, "thumb slot released")
                        idle(next)
                    })
                })
            },
            // 12. undo() is a no-op while busy and canUndo is false meanwhile
            next => {
                const before = suite.log.length
                FileOps.rename(r + "/misc/r1", "r1-again")
                waitFinished(before + 1, "rename for undo", () => idle(() => {
                    check(FileOps.canUndo, "canUndo after rename")
                    FileOps.copy([r + "/src/a.txt"], r + "/dst3", "keepboth")
                    check(FileOps.busy && !FileOps.canUndo, "canUndo false while busy")
                    check(FileOps.undo() === false, "undo() ignored while busy")
                    waitFinished(before + 2, "copy while undo ignored", ev => idle(() => {
                        check(ev.op === "copy" && ev.ok, "copy unaffected")
                        check(FileOps.canUndo, "entry kept after the ignored undo")
                        FileOps.undo()
                        waitFinished(before + 3, "real undo", uev => { check(uev.op === "undo" && uev.ok, "undo works once idle"); next() })
                    }))
                }))
            },
            // 9. invalid request: errors surface as itemFailed
            next => {
                const before = suite.log.length
                suite.itemErrors = []
                FileOps.copy(["relative/path"], r + "/dst3", "skip")
                waitFinished(before + 1, "rejected copy", ev => {
                    check(ev.ok === false && suite.itemErrors.length > 0, "rejected request: " + JSON.stringify(ev) + JSON.stringify(suite.itemErrors))
                    next()
                })
            }
        ]
        let index = 0
        const advance = () => {
            if (index >= sequence.length) {
                console.log("PASS: file operations queue (" + sequence.length + " scenarios)")
                suite.cleanup(0)
                return
            }
            sequence[index++](advance)
        }
        advance()
    }

    Component.onCompleted: maker.running = true
}
