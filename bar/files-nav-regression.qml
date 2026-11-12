import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "components/files"
import "components/files/PathUtil.js" as PathUtil
import "Singletons"

// Run: ISLA_CONFIG=$(mktemp -u).json QT_QPA_PLATFORM=offscreen qs -p bar/files-nav-regression.qml
// Builds its own fixture under mktemp (never HOME) and removes it at the end.
// Offscreen is a logic check, not visual QA.
ShellRoot {
    id: suite
    settings.watchFiles: false
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
            root=$(mktemp -d /tmp/isla-files-test.XXXXXX)
            mkdir -p "$root/home/Documentos" "$root/home/Música" "$root/home/with space" "$root/cfg"
            printf '%s\\n' 'XDG_DOCUMENTS_DIR="$HOME/Documentos"' 'XDG_MUSIC_DIR="$HOME/Música"' \
                'XDG_DESKTOP_DIR="$HOME/Escritorio"' 'XDG_VIDEOS_DIR="$HOME/Vídeos"' > "$root/cfg/user-dirs.dirs"
            printf '%s' "$root"`]
        stdout: StdioCollector { onStreamFinished: { suite.root = text.trim(); suite.fixtureReady = suite.root.length > 0 } }
    }
    Process {
        id: cleaner
        command: ["rm", "-rf", suite.root]
        onExited: { suite.cleaned = true }
    }
    // A failure is sticky: finish(0) can never overwrite an earlier finish(1). The fixture is removed
    // from test_99 (the last test) and `cleaned` is only set once the rm Process has really exited.
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
            else suite.cleaned = true
        }
    }
    Timer { interval: 60000; running: true; onTriggered: { console.error("FAIL: files nav global watchdog"); suite.finish(1); Qt.exit(1) } }

    PlacesData { id: data }
    PlacesData { id: injected }

    Window {
        id: window
        visible: true
        width: 640
        height: 480
        color: Theme.background
        PathBar {
            id: bar
            x: 20; y: 20; width: 500
            path: "/"
            homeDir: suite.root + "/home"
            onNavigateTo: p => checks.navigated.push(p)
        }
        Sidebar {
            id: side
            x: 20; y: 80; width: 200; height: 300
            places: data.places
            drives: injected.drives
            onNavigateTo: p => checks.navigated.push(p)
        }
        TestCase {
            id: checks
            name: "FilesNav"
            when: window.visible && suite.fixtureReady
            property var navigated: []
            property int reached: 0       // test functions that ran to their last line
            function check(value, label) {
                if (suite.exitCode !== 0) throw Error("aborted after an earlier failure")
                if (!value) { console.error("FAIL: files nav", label); suite.finish(1); throw Error(label) }
            }
            // Polls fn (exceptions count as false) and fails loudly on timeout.
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
            function names(list) { return list.map(x => x.name) }

            function test_01_crumbs() {
                let c = PathUtil.segments("/")
                check(c.length === 1 && c[0].name === "/" && c[0].path === "/", "root crumbs")
                bar.path = "/"
                check(bar.crumbs.length === 1, "bar root crumbs")
                bar.path = '/home/u'
                c = bar.crumbs
                check(JSON.stringify(c) === JSON.stringify([{name: "/", path: "/"}, {name: "home", path: "/home"}, {name: "u", path: '/home/u'}]), "home/u crumbs " + JSON.stringify(c))
                bar.path = '/home/u/My Docs/a b/'
                c = bar.crumbs
                check(c.length === 5 && c[3].name === "My Docs" && c[4].path === '/home/u/My Docs/a b', "spaces crumbs " + JSON.stringify(c))
                reached++
            }
            function test_02_breadcrumb_click() {
                bar.path = '/home/u'
                navigated = []
                waitFor(() => bar.width > 0 && bar.crumbs.length === 3, "crumbs")
                // second crumb ("home") sits right of the "/" crumb; click a point inside it
                let hit = false
                for (let x = 8; x < 200 && !hit; x += 6) {
                    mouseClick(bar, x, 18)
                    if (navigated.length > 0) hit = true
                }
                check(hit && ["/", "/home", '/home/u'].indexOf(navigated[0]) >= 0, "crumb click navigates " + JSON.stringify(navigated))
                reached++
            }
            function test_03_edit_enter_cancel() {
                navigated = []
                bar.path = suite.root
                bar.startEditing()
                check(bar.editing, "editing starts")
                check(bar.text === suite.root, "field seeded with path")
                // Esc cancels
                keyClick(Qt.Key_Escape)
                check(!bar.editing && navigated.length === 0, "esc cancels without navigating")
                // nonexistent path: error, no signal
                bar.startEditing()
                const bad = suite.root + "/no-such-dir"
                typeInto(bad)
                keyClick(Qt.Key_Return)
                waitFor(() => bar.invalid, "invalid flagged")
                wait(150)
                check(navigated.length === 0 && bar.editing, "no navigation for missing dir")
                // typing clears the error
                typeInto(suite.root + '/home/with space')
                check(!bar.invalid, "error cleared on edit")
                keyClick(Qt.Key_Return)
                waitFor(() => navigated.length === 1, "navigated for existing dir")
                check(navigated[0] === suite.root + '/home/with space' && !bar.editing, "path with space navigates " + navigated[0])
                // relative path is invalid; ~ expands
                bar.startEditing(); typeInto("relative/dir"); keyClick(Qt.Key_Return)
                check(bar.invalid && navigated.length === 1, "relative path rejected")
                typeInto("~/Documentos"); keyClick(Qt.Key_Return)
                waitFor(() => navigated.length === 2, "tilde expands")
                check(navigated[1] === suite.root + '/home/Documentos', "tilde target " + navigated[1])
                reached++
            }
            function test_03b_error_then_focus_loss() {
                navigated = []
                bar.startEditing()
                typeInto(suite.root + "/missing")
                keyClick(Qt.Key_Return)
                waitFor(() => bar.invalid, "error shown")
                check(bar._pending === "", "pending cleared after error")
                // a probe for an existing dir, then the user cancels before it returns: nothing navigates
                typeInto(suite.root + "/home")
                keyClick(Qt.Key_Return)
                bar.cancel()
                wait(300)
                check(navigated.length === 0 && !bar.editing, "late exit after cancel ignored")
                // error followed by losing focus leaves edit mode
                bar.startEditing()
                typeInto(suite.root + "/missing")
                keyClick(Qt.Key_Return)
                waitFor(() => bar.invalid, "error again")
                bar.children.filter(c => c.hasOwnProperty("cursorPosition"))[0].focus = false
                waitFor(() => !bar.editing, "focus loss exits edit mode")
                check(navigated.length === 0 && !bar.invalid, "no navigation, error reset")
                reached++
            }
            function test_03c_deep_path_keeps_current_visible() {
                bar.path = "/aaaaaaaaaaaa/bbbbbbbbbbbb/cccccccccccc/dddddddddddd/eeeeeeeeeeee/ffffffffffff/current-folder"
                wait(50)
                waitFor(() => !bar.animating, "crumb row settles after the path change")   // the row slides (Task 8)
                const clip = bar.children.filter(c => c.clip === true)[0]
                check(!!clip, "clip item exists")
                const row = clip.children[0]
                check(row.width > clip.width, "deep path overflows " + row.width + " vs " + clip.width)
                check(row.x + row.width <= clip.width + 0.5 && row.x < 0, "last crumb right-aligned and visible")
                bar.path = '/home/u'
                wait(50)
                waitFor(() => !bar.animating, "crumb row settles on the short path")
                check(row.x >= 0, "short path starts left")
                reached++
            }
            function typeInto(text) {
                const field = bar.children.filter(c => c.hasOwnProperty("cursorPosition"))[0]
                check(!!field, "text field exists")
                field.forceActiveFocus()
                field.text = text
            }

            function test_04_places() {
                data.homeDir = suite.root + "/home"
                data.configHome = suite.root + "/cfg"
                data.refreshPlaces()
                waitFor(() => data.userDirsOutput.length > 0, "places output")
                const n = names(data.places)
                check(JSON.stringify(n) === JSON.stringify(["Inicio", "Documentos", "Música"]), "only existing xdg dirs " + JSON.stringify(n))
                check(data.places[1].path === suite.root + '/home/Documentos', "documentos path")
                check(data.places[0].icon.length > 0, "icon present")
                check(side.places.length === 3, "sidebar bound to places")
                // injection path
                check(data.parsePlaces("").length === 0, "empty output")
                check(data.parsePlaces("HOME=relative\nJUNK").length === 0, "garbage ignored")
                reached++
            }
            function test_05_drives() {
                const json = JSON.stringify({ blockdevices: [
                    { name: "sda", label: null, mountpoint: null, size: "100G", rm: false, type: "disk", children: [
                        { name: "sda1", label: null, mountpoint: "/boot/efi", size: "512M", rm: false, type: "part" },
                        { name: "sda2", label: "Datos", mountpoint: "/mnt/datos", size: "99G", rm: false, type: "part" },
                        { name: "sda3", label: null, mountpoint: null, size: "1G", rm: false, type: "part" }] },
                    { name: "sdb", label: null, mountpoint: null, size: "16G", rm: true, type: "disk", children: [
                        { name: "sdb1", label: "USB", mountpoint: null, size: "16G", rm: true, type: "part" }] },
                    { name: "sdc1", label: "Stick", mountpoint: "/run/media/u/Stick", size: "8G", rm: "1", type: "part" },
                    { name: "loop0", label: null, mountpoint: "/var/lib/snap", size: "1G", rm: false, type: "loop" },
                    { name: "zram0", label: null, mountpoint: "[SWAP]", size: "8G", rm: false, type: "disk" }] })
                const d = data.parseDrives(json)
                check(JSON.stringify(names(d)) === JSON.stringify(["Datos", "USB", "Stick"]), "drive names " + JSON.stringify(names(d)))
                check(d[0].mounted && d[0].path === "/mnt/datos" && d[0].size === "99G", "mounted drive")
                check(!d[1].mounted && d[1].path === "", "unmounted drive flagged")
                injected.lsblkOutput = json
                check(side.drives.length === 3, "sidebar bound to drives")
                // MOUNTPOINTS (array): "/" wins, else the shortest; boot/efi prefixes only exclude real subpaths
                const multi = data.parseDrives(JSON.stringify({ blockdevices: [
                    { name: "nvme0n1p2", label: "Sistema", mountpoints: ["/var/log", "/", "/home"], size: "400G", rm: false, type: "part" },
                    { name: "sdb1", label: "Datos", mountpoints: ["/mnt/x/deep", "/mnt/x", null], size: "1T", rm: false, type: "part" },
                    { name: "sdc1", label: "Arranque", mountpoints: ["/bootstrap"], size: "1G", rm: false, type: "part" },
                    { name: "sdd1", label: "Boot", mountpoints: ["/boot"], size: "1G", rm: false, type: "part" },
                    { name: "sde1", label: "Efi", mountpoints: ["/efi/x"], size: "1G", rm: false, type: "part" },
                    { name: "sr0", label: "DVD", mountpoints: [], size: "1024M", rm: true, type: "rom" },
                    { name: "sdf", label: "Vacio", mountpoints: [], size: "0B", rm: true, type: "disk" },
                    { name: "sdg1", label: "Swap", mountpoints: ["[SWAP]"], size: "8G", rm: false, type: "part" }] }))
                check(JSON.stringify(multi.map(x => x.name + "@" + x.path)) === JSON.stringify(["Sistema@/", "Datos@/mnt/x", "Arranque@/bootstrap"]), "mountpoints choice " + JSON.stringify(multi))
                reached++
            }
            function test_06_malformed() {
                for (const bad of ["", "{", "not json", "null", "[]", "{\"blockdevices\": 3}", "{\"blockdevices\": [null, 4, {\"children\": 7}]}"]) {
                    let r = null
                    try { r = data.parseDrives(bad) } catch (e) { check(false, "threw on " + bad) }
                    check(Array.isArray(r), "array for " + bad)
                    if (bad !== "{\"blockdevices\": [null, 4, {\"children\": 7}]}") check(r.length === 0, "empty for " + bad)
                }
                injected.lsblkOutput = "{"
                check(side.drives.length === 0, "sidebar survives bad json")
                reached++
            }
            function test_07_sidebar_click() {
                navigated = []
                injected.lsblkOutput = JSON.stringify({ blockdevices: [
                    { name: "sdc1", label: "Stick", mountpoint: "/run/media/u/Stick", size: "8G", rm: true, type: "part" },
                    { name: "sdd1", label: "Off", mountpoint: null, size: "1G", rm: true, type: "part" }] })
                side.currentPath = ""
                wait(50)
                // rows: header(Lugares) + 3 places, header(Unidades) + 2 drives; hunt by clicking down the column
                for (let y = 20; y < 300; y += 10) mouseClick(side, 30, y)
                check(navigated.indexOf(suite.root + '/home/Documentos') >= 0, "place click navigates")
                check(navigated.indexOf("/run/media/u/Stick") >= 0, "mounted drive click navigates")
                check(navigated.indexOf("") < 0, "unmounted drive is inert")
                reached++
            }
            function test_08_dot_segments_resolve() {
                const N = PathUtil.normalize
                check(N("/a/b/..") === "/a", "normalize /a/b/.. -> " + N("/a/b/.."))
                check(N("/a/./b//c/") === "/a/b/c", "normalize dots and double slashes -> " + N("/a/./b//c/"))
                check(N("/..") === "/" && N("/a/../..") === "/" && N("/") === "/", "normalize never climbs above /")
                check(N("/a/..b/.c") === "/a/..b/.c", "names that merely start with dots are kept")
                navigated = []
                bar.path = suite.root
                bar.startEditing()
                typeInto(suite.root + "/home/with space/..")
                keyClick(Qt.Key_Return)
                waitFor(() => navigated.length === 1, "path with .. navigates")
                check(navigated[0] === suite.root + "/home", "bar resolves .. to " + navigated[0])
                bar.startEditing(); typeInto("~/Documentos/../with space"); keyClick(Qt.Key_Return)
                waitFor(() => navigated.length === 2, "tilde plus .. navigates")
                check(navigated[1] === suite.root + "/home/with space", "tilde and .. -> " + navigated[1])
                reached++
            }
            function test_99_exit() {
                suite.finish(0)
                for (let i = 0; i < 1200 && !suite.cleaned; i++) wait(50)
                if (!suite.cleaned) { console.error("FAIL: files nav fixture cleanup did not finish"); suite.exitCode = 1 }
                if (suite.exitCode === 0 && reached !== 10) {
                    console.error("FAIL: files nav tests incompletos (" + reached + "/10 llegaron a su ultima linea)")
                    suite.exitCode = 1
                }
                if (suite.exitCode !== 0) Qt.exit(suite.exitCode)
                else console.log("PASS: files navigation (crumbs, path edit/validate, xdg places, lsblk drives, malformed json, sidebar clicks)")
            }
        }
    }
}
