import QtQuick
import Qt.labs.folderlistmodel
import Quickshell.Io
import "PathUtil.js" as PathUtil

// Folder listing for the file explorer. Wraps FolderListModel; options are plain
// properties (the composition binds them to Config.files), never read from Config here.
// With an empty filter `model` is the FolderListModel itself (no row copies); with a
// filter, `model` is a small ListModel holding only the matching rows.
QtObject {
    id: root

    // Trailing slashes are dropped on assignment ("/" stays), so comparisons use one form.
    property string path: ""
    onPathChanged: {
        const clean = PathUtil.normalize(root.path)
        if (clean !== root.path) { root.path = clean; return }
        _lostFor = ""
        _deniedFor = ""
        _unlistable = false
        if (root.path.length) root.recheck()
    }
    property string filter: ""
    property bool showHidden: false
    property string sortField: "name"   // name | modified | size | type
    property bool sortReversed: false
    property bool dirsFirst: true
    // Poll for a vanished folder (an empty folder emits no model change when removed).
    // The composition enables it while the explorer is visible.
    property bool watchPath: false
    // True when the folder exists and was probed, yet the model lists nothing (FolderListModel
    // cannot open some names). The view should warn instead of showing a silently empty folder.
    // Semantics (for the view's notice, Task 6): the folder contains entries that cannot be
    // shown (broken symlinks, sockets, FIFOs, devices) and nothing else is listed.
    readonly property bool unlistable: _unlistable && count === 0
    property bool _unlistable: false
    property string _lostFor: ""

    readonly property bool loading: _folder.status === FolderListModel.Loading
    readonly property bool ready: _folder.status === FolderListModel.Ready
    readonly property int count: _filtering ? _matches.count : _folder.count
    readonly property var model: _filtering ? _matches : _folder
    readonly property bool _filtering: root.filter.length > 0
    signal pathLost(string fallback)
    // The folder exists but cannot be read or entered (no r/x permission): the host warns and goes back.
    signal denied(string path)
    property string _deniedFor: ""

    function navigate(target) { root.path = target }

    function get(i) {
        if (!(i >= 0 && i < root.count)) return null
        const match = _filtering ? _matches.get(i) : null
        if (_filtering && !match) return null
        const row = _filtering ? match.row : i
        if (row === undefined || row < 0 || row >= _folder.count) return null
        const filePath = _folder.get(row, "filePath")
        return {
            name: _folder.get(row, "fileName"),
            path: filePath,
            url: PathUtil.toUrl(filePath),
            isDir: _folder.get(row, "fileIsDir"),
            size: _folder.get(row, "fileSize"),
            modified: _folder.get(row, "fileModified")
        }
    }

    function indexOfName(name) {
        for (let i = 0; i < root.count; i++) {
            const match = _filtering ? _matches.get(i) : null
            if (_filtering && !match) return -1
            const row = _filtering ? match.row : i
            if (_folder.get(row, "fileName") === name) return i
        }
        return -1
    }

    // Re-check that the shown folder still exists (also called on model signals).
    function recheck() {
        if (root.path.length === 0 || _probe.running) return
        _probe.probedPath = root.path
        // $1 = shown path, $2 = 1 when hidden entries count, $3 = 1 when emptiness matters (the model lists nothing);
        // the rest are ancestors, deepest last. Output (NUL separated): existing ancestors, then "\x02denied" when
        // the folder exists but cannot be read/entered, else "\x01nonempty" if it has listable entries (checked
        // only when asked: an unsorted `ls -f | head` never sorts a big folder).
        _probe.command = ["sh", "-c", 'dir=$1; hid=$2; chk=$3; shift 3; for p in "$@"; do [ -d "$p" ] && printf "%s\\0" "$p"; done; '
            + 'if [ -d "$dir" ]; then if [ ! -r "$dir" ] || [ ! -x "$dir" ]; then printf "\\002denied\\0"; '
            + 'elif [ "$chk" = 1 ]; then if [ "$hid" = 1 ]; then f=$(ls -f -- "$dir" 2>/dev/null | grep -v "^\\.\\.\\?$" | head -n 1); '
            + 'else f=$(ls -f -- "$dir" 2>/dev/null | grep -v "^\\." | head -n 1); fi; [ -n "$f" ] && printf "\\001nonempty\\0"; fi; fi; true', "sh",
            root.path, root.showHidden ? "1" : "0", _folder.status === FolderListModel.Ready && _folder.count === 0 ? "1" : "0"]
            .concat(PathUtil.segments(root.path).map(s => s.path))
        _probe.running = true
    }

    function _rebuild() {
        _matches.clear()
        if (root.filter.length === 0) return
        const needle = PathUtil.fold(root.filter)
        const rows = []
        for (let i = 0; i < _folder.count; i++)
            if (PathUtil.fold(_folder.get(i, "fileName")).indexOf(needle) !== -1)
                rows.push({ row: i })
        _matches.append(rows)
    }
    onFilterChanged: _rebuild()

    property FolderListModel _folderModel: FolderListModel {
        id: _folder
        folder: root.path.length ? PathUtil.toFolderUrl(root.path) : ""
        showFiles: true
        showDirs: true
        showDotAndDotDot: false
        showHidden: root.showHidden
        showDirsFirst: root.dirsFirst
        sortReversed: root.sortReversed
        caseSensitive: false
        sortField: ({ name: FolderListModel.Name, modified: FolderListModel.Time,
                      size: FolderListModel.Size, type: FolderListModel.Type })[root.sortField]
                   ?? FolderListModel.Name
        onCountChanged: {
            root._rebuild()
            if (count === 0) root.recheck()
        }
        onStatusChanged: {
            if (status === FolderListModel.Ready) { root._rebuild(); if (count === 0) root.recheck() }
            else if (root.path.length) root.recheck()
        }
    }

    property ListModel _matchesModel: ListModel { id: _matches }

    property Process _probeProcess: Process {
        id: _probe
        property string probedPath: ""
        // A probe that finished for a stale path must not delay the check of the new one.
        onExited: if (root.path.length && probedPath !== root.path) root.recheck()
        stdout: StdioCollector {
            onStreamFinished: {
                const alive = {}
                let nonEmpty = false, noAccess = false
                for (const entry of text.split("\0")) {
                    if (entry === "\u0001nonempty") nonEmpty = true
                    else if (entry === "\u0002denied") noAccess = true
                    else if (entry.length) alive[entry] = true
                }
                if (_probe.probedPath !== root.path) return
                if (alive[root.path] === true) {
                    if (noAccess) {
                        if (root._deniedFor !== root.path) { root._deniedFor = root.path; root.denied(root.path) }
                        return
                    }
                    root._unlistable = nonEmpty && _folder.status === FolderListModel.Ready && _folder.count === 0
                    return
                }
                if (root._lostFor === root.path) return
                root._lostFor = root.path
                root.pathLost(PathUtil.nearestExisting(root.path, p => alive[p] === true))
            }
        }
    }

    property Timer _watch: Timer {
        interval: 2000
        repeat: true
        running: root.watchPath && root.path.length > 0
        onTriggered: root.recheck()
    }
}
