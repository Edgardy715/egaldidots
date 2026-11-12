import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "components/files"
import "Singletons"

// Run: ISLA_CONFIG=$(mktemp -u).json QT_QPA_PLATFORM=offscreen qs -p bar/files-integration-regression.qml
// Drives the real FilesView (composition) against a fixture under mktemp (never HOME); trash goes
// to an isolated XDG_DATA_HOME and the opener is a stub script. Offscreen is a logic check, not visual QA.
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
            mkdir -p "$root/work/sub" "$root/work/dest" "$root/work/doomed/child" "$root/work/broken" "$root/data"
            printf 'source' > "$root/work/a.txt"
            printf 'dest-original' > "$root/work/dest/a.txt"
            printf 'x' > "$root/work/my file #1.txt"
            printf 'x' > "$root/work/trashme.txt"
            printf 'x' > "$root/work/.hidden"
            printf 'x' > "$root/work/sub/inner.txt"
            ln -s /nonexistent-target "$root/work/broken/dangling"
            mkdir -p "$root/work/-dash"
            printf 'x' > "$root/work/it's here.txt"
            printf 'x' > "$root/work/"'$(touch PWNED).txt'
            printf 'x' > "$root/work/50%.txt"
            printf 'x' > "$root/work/line$(printf '\\nbreak').txt"
            printf 'x' > "$root/work/-dash/-rf.txt"
            cat > "$root/opener.sh" <<'STUB'
#!/bin/sh
hex=$(printf '%s' "$1" | od -An -v -tx1 | tr -d ' \n')
printf '%s|%s\n' "$#" "$hex" >> "$(dirname "$0")/opener.log"
STUB
            chmod +x "$root/opener.sh"
            printf '%s' "$root"`]
        stdout: StdioCollector { onStreamFinished: { suite.root = text.trim(); suite.fixtureReady = suite.root.length > 0 } }
    }
    Process {
        id: cleaner
        command: ["rm", "-rf", suite.root]
        onExited: { suite.cleaned = true }
    }
    // Generic one-shot shell for fixtures and observations; result lands in shellOut.
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

    // A failure is sticky: finish(0) can never overwrite an earlier finish(1). `cleaned` is only
    // set once the rm Process has really exited; the fixture is also removed after a failure.
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
    Timer { interval: 90000; running: true; onTriggered: { console.error("FAIL: files integration global watchdog"); suite.finish(1); Qt.exit(1) } }

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
            name: "FilesIntegration"
            when: window.visible && suite.fixtureReady && Config.loaded
            property int reached: 0       // test functions that ran to their last line
            function check(value, label) {
                if (suite.exitCode !== 0) throw Error("aborted after an earlier failure")
                if (!value) { console.error("FAIL: files integration", label); suite.finish(1); throw Error(label) }
            }
            // Polls fn (exceptions count as false) and fails loudly on timeout.
            function waitFor(fn, label, ms) {
                check(true, "")
                const deadline = Date.now() + (ms || 5000)
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
            function idle() { waitFor(() => !FileOps.busy, "file ops idle", 8000) }
            function go(path) {
                view.navigate(path)
                waitFor(() => view.path === path && view.model.ready, "navigated to " + path)
            }

            function initTestCase() {
                FileOps.environment = { XDG_DATA_HOME: suite.root + "/data" }
                view.opener = suite.root + "/opener.sh"
                view.navigate(suite.root + "/work")
            }

            // Config.save() runs in this suite: never against the real settings file. This is a test
            // function (not initTestCase) so a failure still cleans the fixture and exits non-zero.
            function test_00_isolated_config() {
                check((Quickshell.env("ISLA_CONFIG") || "").indexOf("/tmp/") === 0, "ISLA_CONFIG must point to a temporary file")
                reached++
            }
            function test_01_navigation_history() {
                const work = suite.root + "/work"
                waitFor(() => view.path === work, "initial folder")
                waitFor(() => view.model.indexOfName("sub") >= 0, "work listed")
                view.forceActiveFocus()
                view.openEntry(indexOf("sub"))
                waitFor(() => view.path === work + "/sub", "enter sub")
                check(view.canBack && !view.canForward, "history after enter")
                keyClick(Qt.Key_Left, Qt.AltModifier)
                waitFor(() => view.path === work, "Alt+Left back")
                check(view.canForward, "forward available")
                keyClick(Qt.Key_Right, Qt.AltModifier)
                waitFor(() => view.path === work + "/sub", "Alt+Right forward")
                keyClick(Qt.Key_Backspace)
                waitFor(() => view.path === work, "Backspace goes up")
                view.goUp()
                waitFor(() => view.path === suite.root, "goUp from work")
                go(work)
                reached++
            }
            function hexOf(text) {
                let out = ""
                for (let i = 0; i < text.length; i++) out += ("0" + text.charCodeAt(i).toString(16)).slice(-2)
                return out
            }
            // Opens `name` from the listing and expects the stub to receive exactly one argument: the path.
            function expectOpened(dir, name) {
                waitFor(() => indexOf(name) >= 0, "listed " + JSON.stringify(name))
                view.openEntry(indexOf(name))
                const want = "1|" + hexOf(dir + "/" + name)
                waitFor(() => shell("cat '" + suite.root + "/opener.log' 2>/dev/null").split("\n").indexOf(want) >= 0,
                        "opener got the whole path as one argument: " + JSON.stringify(name))
            }
            function test_02_open_file_argument_intact() {
                const work = suite.root + "/work"
                // spaces and #, quote, $(), %, newline: any shell interpolation of the path would break one
                for (const name of ["my file #1.txt", "it's here.txt", "$(touch PWNED).txt", "50%.txt", "line\nbreak.txt"])
                    expectOpened(work, name)
                check(shell("[ -e '" + work + "/PWNED' ] && echo yes || echo no").trim() === "no", "nothing was executed from a file name")
                // a path segment that starts with "-"
                go(work + "/-dash")
                expectOpened(work + "/-dash", "-rf.txt")
                go(work)
                reached++
            }
            function test_03_copy_paste_conflict() {
                const work = suite.root + "/work"
                select("a.txt")
                keyClick(Qt.Key_C, Qt.ControlModifier)
                check(view.clipboardPaths.length === 1 && !view.clipboardCut, "copied to internal clipboard")
                go(work + "/dest")
                keyClick(Qt.Key_V, Qt.ControlModifier)
                waitFor(() => view.conflictOpen, "conflict dialog opens")
                check(JSON.stringify(view.conflictNames) === JSON.stringify(["a.txt"]), "conflict names " + JSON.stringify(view.conflictNames))
                const modal = find(view, "modal")
                check(modal && modal.visible, "dialog is visible")
                const title = find(view, "dialogTitle")
                check(title.text.indexOf("a.txt") >= 0, "dialog names the file: " + title.text)
                // Skip, through its real button
                mouseClick(find(view, "dialog_skip"))
                check(!view.conflictOpen, "skip closes the dialog")
                idle()
                check(shell("cat '" + work + "/dest/a.txt'") === "dest-original", "skip keeps the destination")
                // Keep both
                keyClick(Qt.Key_V, Qt.ControlModifier)
                waitFor(() => view.conflictOpen, "second conflict")
                view.resolveConflict("keepboth")
                idle()
                check(shell("ls '" + work + "/dest' | wc -l").trim() === "2", "keepboth adds a second file")
                // Replace
                keyClick(Qt.Key_V, Qt.ControlModifier)
                waitFor(() => view.conflictOpen, "third conflict")
                view.resolveConflict("overwrite")
                idle()
                check(shell("cat '" + work + "/dest/a.txt'") === "source", "overwrite replaces the destination")
                // Esc cancels the dialog without touching anything
                keyClick(Qt.Key_V, Qt.ControlModifier)
                waitFor(() => view.conflictOpen, "fourth conflict")
                keyClick(Qt.Key_Escape)
                check(!view.conflictOpen, "Esc closes the dialog")
                go(work)
                reached++
            }
            function test_04_trash_and_undo() {
                const work = suite.root + "/work"
                select("trashme.txt")
                keyClick(Qt.Key_Delete)
                waitFor(() => indexOf("trashme.txt") < 0, "trashed item leaves the listing")
                idle()
                check(shell("[ -e '" + work + "/trashme.txt' ] && echo yes || echo no").trim() === "no", "file gone from disk")
                check(FileOps.canUndo, "undo available")
                keyClick(Qt.Key_Z, Qt.ControlModifier)
                waitFor(() => indexOf("trashme.txt") >= 0, "Ctrl+Z restores it")
                idle()
                reached++
            }
            function test_05_context_menu_and_actions() {
                waitFor(() => view.model.count > 0, "listed")
                const menu = find(view, "contextMenu")
                view.selection.select(indexOf("sub"))
                const ids = view.menuEntries(indexOf("sub")).filter(e => !e.separator).map(e => e.id)
                for (const id of ["open", "copy", "cut", "paste", "rename", "trash", "mkdir", "copypath"])
                    check(ids.indexOf(id) >= 0, "menu has " + id)
                const file = view.menuEntries(indexOf("a.txt")).map(e => e.id)
                check(file.indexOf("openwith") >= 0, "menu has openwith for a file")
                // A real right click opens the menu
                const item = find(view, "fileDelegate")
                check(item !== null, "a delegate exists")
                mouseClick(item, item.width / 2, item.height / 2, Qt.RightButton)
                waitFor(() => menu.opened, "right click opens the menu")
                check(menu.entries.length >= 9, "menu populated")
                // While the menu is open Delete / Ctrl+V must not reach the view
                const victim = suite.root + "/work/" + view.selection.currentPath.slice(view.selection.currentPath.lastIndexOf("/") + 1)
                keyClick(Qt.Key_Delete)
                keyClick(Qt.Key_V, Qt.ControlModifier)
                wait(300)
                idle()
                check(menu.opened, "menu stays open on foreign keys")
                check(shell("[ -e '" + victim + "' ] && echo yes || echo no").trim() === "yes", "Delete under the open menu trashed nothing")
                keyClick(Qt.Key_Escape)
                check(!menu.opened, "Esc closes the menu")
                // New folder through the prompt
                view.beginNewFolder()
                check(view.promptOpen, "prompt opens")
                find(view, "nameField").text = "creada"
                find(view, "nameField").accepted()
                waitFor(() => indexOf("creada") >= 0, "new folder listed")
                idle()
                waitFor(() => view.selection.currentIndex === indexOf("creada"), "new folder selected")
                // Rename
                view.beginRename()
                find(view, "nameField").text = "renombrada"
                find(view, "nameField").accepted()
                waitFor(() => indexOf("renombrada") >= 0 && indexOf("creada") < 0, "renamed")
                idle()
                reached++
            }
            function test_06_config_binds_view_and_hidden() {
                waitFor(() => view.model.count > 0, "listed")
                check(indexOf(".hidden") < 0, "hidden file not listed by default")
                keyClick(Qt.Key_H, Qt.ControlModifier)
                waitFor(() => indexOf(".hidden") >= 0, "Ctrl+H shows hidden files (Config.files.showHidden)")
                check(Config.files.showHidden === true, "Config updated")
                keyClick(Qt.Key_H, Qt.ControlModifier)
                waitFor(() => indexOf(".hidden") < 0, "Ctrl+H hides again")
                view.setFiles({ view: "list" })
                waitFor(() => { const v = find(view, "fileDelegate"); return v && v.compact === true }, "list view loaded from Config.files.view")
                mouseClick(find(view, "nav_view"))
                waitFor(() => { const v = find(view, "fileDelegate"); return v && v.compact === false }, "grid view again")
                reached++
            }
            function test_07_path_lost_falls_back() {
                const work = suite.root + "/work"
                go(work + "/doomed/child")
                shell("rm -rf '" + work + "/doomed'")
                waitFor(() => view.path === work, "fallback to the nearest existing folder", 9000)
                check(view.notice.length > 0, "notice shown")
                reached++
            }
            function test_08_unlistable_notice() {
                const work = suite.root + "/work"
                go(work + "/broken")
                waitFor(() => view.model.unlistable, "folder reports unlistable")
                const note = find(view, "noticeText")
                waitFor(() => note.visible && note.text.length > 0, "unlistable notice is visible")
                go(work)
                reached++
            }
            function test_09_close_shortcut() {
                view.forceActiveFocus()
                const n = view.closes
                keyClick(Qt.Key_W, Qt.ControlModifier)
                check(view.closes === n + 1, "Ctrl+W asks the host to close")
                reached++
            }
            // Ctrl+Z names what it reverts (copy/mkdir are not undoable, so an older action is the one undone)
            // and says so when there is nothing to undo.
            function test_10_undo_names_what_it_reverts() {
                const work = suite.root + "/work"
                go(work)
                FileOps._undo = []; FileOps._undoMeta = []; FileOps.undoDepth = 0
                view.forceActiveFocus()
                view.notice = ""
                keyClick(Qt.Key_Z, Qt.ControlModifier)
                check(view.notice === I18n.tr("Nada que deshacer"), "empty stack: notice (" + view.notice + ")")
                select("trashme.txt")
                keyClick(Qt.Key_Delete)
                waitFor(() => indexOf("trashme.txt") < 0, "trashed")
                idle()
                FileOps.mkdir(work, "after-trash-dir")      // not undoable: must not hide the trash
                idle()
                check(FileOps.undoDepth === 1, "mkdir is not recorded (depth " + FileOps.undoDepth + ")")
                view.forceActiveFocus()
                view.notice = ""
                keyClick(Qt.Key_Z, Qt.ControlModifier)
                waitFor(() => FileOps.undoDepth === 0 && !FileOps.busy && indexOf("trashme.txt") >= 0, "trash undone")
                waitFor(() => view.notice.indexOf(I18n.tr("Deshecho: %1").replace("%1", "")) === 0, "undo notice (" + view.notice + ")")
                check(view.notice.indexOf(I18n.tr("papelera")) >= 0, "the notice names the trash, not the mkdir (" + view.notice + ")")
                view.notice = ""
                keyClick(Qt.Key_Z, Qt.ControlModifier)
                check(view.notice === I18n.tr("Nada que deshacer"), "second Ctrl+Z has nothing to undo (" + view.notice + ")")
                // several items: the count is part of the notice
                FileOps.trash([work + "/trashme.txt", work + "/my file #1.txt"])
                idle()
                view.notice = ""
                keyClick(Qt.Key_Z, Qt.ControlModifier)
                waitFor(() => view.notice.indexOf(I18n.tr("%1 elementos").replace("%1", 2)) >= 0, "count in the notice (" + view.notice + ")")
                idle()
                reached++
            }
            // A folder without read/enter permission is not shown as "empty": warn and go back to the last valid folder.
            function test_11_unreadable_folder_goes_back_with_notice() {
                const work = suite.root + "/work"
                go(work)
                shell("mkdir -p '" + work + "/locked' && chmod 000 '" + work + "/locked'")
                try {
                    view.notice = ""
                    const canBack = view.canBack
                    view.navigate(work + "/locked")
                    waitFor(() => view.path === work && view.notice.indexOf(I18n.tr("Sin permiso")) === 0, "denied: back to the previous folder with a notice (path " + view.path + ", notice " + view.notice + ")")
                    check(view.notice.indexOf("locked") >= 0, "the notice names the folder (" + view.notice + ")")
                    check(view.canBack === canBack, "the failed visit is not left in the history")
                } finally {
                    shell("chmod 755 '" + work + "/locked'")
                }
                // a readable empty folder is still just empty
                shell("mkdir -p '" + work + "/blank'")
                view.notice = ""
                view.navigate(work + "/blank")
                waitFor(() => view.path === work + "/blank" && view.model.ready, "empty folder opens")
                wait(600)
                check(view.path === work + "/blank" && view.notice.length === 0, "an empty readable folder is not denied")
                go(work)
                reached++
            }
            function test_99_exit() {
                suite.finish(0)
                for (let i = 0; i < 1200 && !suite.cleaned; i++) wait(50)
                if (!suite.cleaned) { console.error("FAIL: files integration fixture cleanup did not finish"); suite.exitCode = 1 }
                if (suite.exitCode === 0 && reached !== suite.totalTests) {
                    console.error("FAIL: files integration tests incompletos (" + reached + "/" + suite.totalTests + " llegaron a su ultima linea)")
                    suite.exitCode = 1
                }
                if (suite.exitCode !== 0) Qt.exit(suite.exitCode)
                else console.log("PASS: files integration (history, opener argv, conflict dialog, trash+undo, menu, mkdir/rename, config binds, pathLost, unlistable, close, undo notices, unreadable folder)")
            }
        }
    }
}
