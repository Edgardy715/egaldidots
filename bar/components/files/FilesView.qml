import QtQuick
import Quickshell
import Quickshell.Io
import "../../Singletons"
import ".."
import "PathUtil.js" as PathUtil

// Composition of the file explorer: wires the leaf components (model, selection, views, path
// bar, sidebar) to the services (Config.files, FileOps) and owns history, internal clipboard,
// context menu, name prompts and the conflict dialog. Opening a file never goes through a shell:
// the opener (xdg-open, or ISLA_FILES_OPENER for tests) gets the path as one argv element.
FocusScope {
    id: root

    property string startPath: ""
    property string selectName: ""
    // False while the window is hidden: stops the folder poll, the open animation and thumbnails.
    property bool active: true
    readonly property string homeDir: Quickshell.env("HOME") || "/"
    readonly property string path: files.path
    readonly property alias model: files
    readonly property alias selection: sel
    readonly property alias quickLook: quick
    readonly property bool canBack: _back.length > 0
    readonly property bool canForward: _fwd.length > 0
    readonly property bool conflictOpen: _conflict !== null
    readonly property var conflictNames: _conflict ? _conflict.names : []
    readonly property bool promptOpen: _prompt !== null
    property string notice: ""
    property var clipboardPaths: []
    property bool clipboardCut: false
    property var _back: []
    property var _fwd: []
    property var _conflict: null
    property var _prompt: null
    // Drag and drop state. `_dragPaths` is the explorer's own drag in flight (empty = none).
    property var _dragPaths: []
    property bool _dragPending: false
    // Ctrl held when the drag started: the one explicit copy request of our own drags (DragEvent carries
    // no modifiers, and proposedAction is Copy by default with Drag.Automatic, so it never decides).
    property bool _dragCopy: false
    readonly property bool dragging: _dragPaths.length > 0
    property int _hoverIndex: -1
    // Test hook: how the last drag was started ("native" = Drag.active reached, "aborted" = pointer released first).
    property string lastDragState: ""
    property var lastDragMime: null
    property string _wantName: ""
    property int _wantTries: 0
    property string opener: Quickshell.env("ISLA_FILES_OPENER") || "xdg-open"
    signal closeRequested()
    // Motion state (tests): any explorer animation in flight. All of them stop while `active` is false.
    readonly property bool opening: openSpring.integrating || openFade.running
    readonly property bool animating: opening || nav.running || quick.animating || pathBar.animating
        || (viewLoader.item ? viewLoader.item.highlightAnimating : false)
    readonly property alias navTransition: nav

    // Keyboard focus goes back to the active view (arrows, Enter, Home/End, Ctrl+A live there), not to the root.
    function focusView() {
        if (viewLoader.item) viewLoader.item.forceActiveFocus()
        else root.forceActiveFocus()
    }

    // ---- navigation -------------------------------------------------------

    function navigate(target, record) {
        const next = PathUtil.normalize(target)
        if (!next.length || next === files.path) return
        if (record !== false) {
            if (files.path.length) _back = _back.concat([files.path]).slice(-100)
            _fwd = []
        }
        files.filter = ""
        files.navigate(next)
    }
    function goBack() {
        if (!_back.length) return
        const to = _back[_back.length - 1]
        _back = _back.slice(0, -1)
        _fwd = _fwd.concat([files.path])
        files.navigate(to)
    }
    function goForward() {
        if (!_fwd.length) return
        const to = _fwd[_fwd.length - 1]
        _fwd = _fwd.slice(0, -1)
        _back = _back.concat([files.path])
        files.navigate(to)
    }
    function goUp() { navigate(PathUtil.parent(files.path)) }
    // Shows `folder`; when `name` is given it is selected once the listing has it.
    function openTarget(folder, name) {
        navigate(folder)
        _selectLater(name || "")
    }
    function _selectLater(name) {
        _wantName = name
        _wantTries = 0
        if (name.length) wantTimer.restart()
    }
    function _trySelect() {
        if (!_wantName.length) { wantTimer.stop(); return }
        const i = files.indexOfName(_wantName)
        if (i >= 0) {
            sel.select(i)
            if (viewLoader.item) viewLoader.item.ensureVisible(i)
            _wantName = ""
            wantTimer.stop()
        } else if (++_wantTries > 40) { _wantName = ""; wantTimer.stop() }
    }
    Timer { id: wantTimer; interval: 50; repeat: true; onTriggered: root._trySelect() }

    // ---- actions ----------------------------------------------------------

    function openEntry(index) {
        const entry = files.get(index)
        if (!entry) return
        if (entry.isDir) navigate(entry.path)
        else launch(root.opener, entry.path)
    }
    // Detached launch: the child must outlive this view (a Process is killed with its parent object).
    // A `command -v` probe (program is an argv element, never shell text) reports a missing program.
    function launch(program, argument) {
        const probe = openerComponent.createObject(root, { command: ["sh", "-c", 'command -v -- "$1" >/dev/null', "sh", program] })
        if (!probe) return
        probe.exited.connect(code => {
            if (code === 0) Quickshell.execDetached([program, argument])
            else root.notice = I18n.tr("No se pudo abrir") + ": " + program
            probe.destroy()
        })
        probe.running = true
    }
    Component { id: openerComponent; Process {} }

    function selectedPaths() {
        const p = sel.paths()
        if (p.length === 0 && sel.currentPath.length) return [sel.currentPath]
        return p
    }
    function copySelection() { const p = selectedPaths(); if (p.length) { clipboardPaths = p; clipboardCut = false } }
    function cutSelection() { const p = selectedPaths(); if (p.length) { clipboardPaths = p; clipboardCut = true } }
    function copyPathText() {
        const p = selectedPaths()
        const text = p.length ? p.join("\n") : files.path
        const proc = openerComponent.createObject(root, { command: ["wl-copy", "--", text] })
        if (!proc) return
        proc.exited.connect(() => proc.destroy())
        proc.running = true
    }
    function paste() {
        if (!clipboardPaths.length) return
        transfer(clipboardPaths.slice(), files.path, clipboardCut, true)
    }
    // Copy or move `sources` into `dest`, asking first when names collide (clipboard paste and drops).
    function transfer(sources, dest, cut, fromClipboard) {
        FileOps.conflicts(sources, dest, (names, ok) => {
            if (!names.length) root._runTransfer(sources, dest, cut, "skip", fromClipboard)
            else root._conflict = { sources: sources, dest: dest, cut: cut, names: names, clip: fromClipboard === true }
        })
    }
    function _runTransfer(sources, dest, cut, policy, fromClipboard) {
        if (cut) {
            FileOps.move(sources, dest, policy)
            if (fromClipboard === true) { clipboardPaths = []; clipboardCut = false }
        } else FileOps.copy(sources, dest, policy)
    }
    function resolveConflict(policy) {
        const c = _conflict
        _conflict = null
        if (c && policy !== "cancel") _runTransfer(c.sources, c.dest, c.cut, policy, c.clip)
        focusView()
    }
    function trashSelection() { const p = selectedPaths(); if (p.length) FileOps.trash(p) }
    // Only moves, trash and renames are recorded (copy/mkdir are not undoable), so the notice names what is
    // being reverted: Ctrl+Z never silently reverts an older action. Nothing to undo says so.
    function undo() {
        if (FileOps.busy) return
        if (!FileOps.canUndo) { notice = I18n.tr("Nada que deshacer"); return }
        FileOps.undo()
    }
    function undoText() {
        const u = FileOps.lastUndo
        const verb = u.label === "trash" ? I18n.tr("papelera") : u.label === "rename" ? I18n.tr("renombrar") : I18n.tr("mover")
        return I18n.tr("Deshecho: %1").replace("%1", () => verb + (u.count > 1 ? " " + I18n.tr("%1 elementos").replace("%1", u.count) : ""))
    }
    function beginRename() {
        if (sel.currentIndex < 0) return
        const entry = files.get(sel.currentIndex)
        if (entry) _prompt = { kind: "rename", title: I18n.tr("Renombrar"), text: entry.name, path: entry.path }
    }
    function beginNewFolder() { _prompt = { kind: "mkdir", title: I18n.tr("Carpeta nueva"), text: I18n.tr("Carpeta nueva"), path: "" } }
    function beginOpenWith() {
        if (sel.currentIndex < 0) return
        const entry = files.get(sel.currentIndex)
        if (entry) _prompt = { kind: "openwith", title: I18n.tr("Abrir con…"), text: "", path: entry.path }
    }
    function acceptPrompt(text) {
        const p = _prompt, name = String(text).trim()
        _prompt = null
        focusView()
        if (!p || !name.length) return
        if (p.kind === "rename") { if (name !== p.text) { FileOps.rename(p.path, name); _selectLater(name) } }
        else if (p.kind === "mkdir") { FileOps.mkdir(files.path, name); _selectLater(name) }
        else if (p.kind === "openwith") launch(name, p.path)
    }
    function cancelPrompt() { _prompt = null; focusView() }
    // Config.update is refused while a save is in flight; retry shortly instead of dropping the change.
    property var _configPatch: null
    property int _configTries: 0
    function setFiles(patch) {
        _configPatch = patch
        _configTries = 0
        _applyConfig()
    }
    function _applyConfig() {
        if (!_configPatch) return
        if (Config.update({ files: _configPatch }).ok) {
            _configPatch = null
            Config.save()
        } else if (++_configTries < 20) configRetry.restart()
        else _configPatch = null
    }
    Timer { id: configRetry; interval: 100; onTriggered: root._applyConfig() }
    function toggleHidden() { setFiles({ showHidden: !Config.files.showHidden }) }

    function menuEntries(index) {
        const on = index >= 0, one = sel.count <= 1 && on
        const entry = on ? files.get(index) : null
        const open = [{ id: "open", label: I18n.tr("Abrir"), enabled: on }]
        if (one && entry && !entry.isDir) open.push({ id: "openwith", label: I18n.tr("Abrir con…") })
        return open.concat([
            { separator: true },
            { id: "copy", label: I18n.tr("Copiar"), enabled: on },
            { id: "cut", label: I18n.tr("Cortar"), enabled: on },
            { id: "paste", label: I18n.tr("Pegar"), enabled: clipboardPaths.length > 0 },
            { separator: true },
            { id: "rename", label: I18n.tr("Renombrar"), enabled: one },
            { id: "trash", label: I18n.tr("Papelera"), enabled: on },
            { id: "mkdir", label: I18n.tr("Carpeta nueva") },
            { separator: true },
            { id: "copypath", label: I18n.tr("Copiar ruta") }
        ])
    }
    function runMenu(id) {
        if (id === "open") { if (sel.currentIndex >= 0) openEntry(sel.currentIndex) }
        else if (id === "openwith") beginOpenWith()
        else if (id === "copy") copySelection()
        else if (id === "cut") cutSelection()
        else if (id === "paste") paste()
        else if (id === "rename") beginRename()
        else if (id === "trash") trashSelection()
        else if (id === "mkdir") beginNewFolder()
        else if (id === "copypath") copyPathText()
        // A prompt opened by the action takes the focus itself (modal.onVisibleChanged).
        if (!promptOpen) focusView()
    }

    // ---- type to filter -------------------------------------------------------

    function _printable(text) { return /^[^\u0000-\u0020\u007f]+$/.test(text) }
    function _filterSelectFirst() {
        if (files.count > 0) {
            sel.select(0)
            if (viewLoader.item) viewLoader.item.ensureVisible(0)
        } else sel.clear()
    }
    function typeFilter(text) { files.filter = files.filter + text; _filterSelectFirst() }
    function trimFilter() { files.filter = files.filter.slice(0, -1); _filterSelectFirst() }
    function clearFilter() { files.filter = "" }

    // ---- quick look -----------------------------------------------------------

    // Points QuickLook at entry `i`: its rect (in QuickLook's coordinates) is where it grows from.
    function _syncQuick(i) {
        const view = viewLoader.item, entry = files.get(i)
        if (!view || !entry) return false
        view.ensureVisible(i)
        const r = view.positionAt(i)
        const at = viewLoader.mapToItem(quick.parent, r.x, r.y)
        quick.originRect = Qt.rect(at.x, at.y, r.width, r.height)
        quick.isDir = entry.isDir
        quick.fileSize = Number(entry.size) || 0
        quick.path = entry.path
        return true
    }
    function toggleQuickLook() {
        if (quick.open) { quick.close(false); return }
        if (sel.currentIndex >= 0 && _syncQuick(sel.currentIndex)) quick.open = true
    }
    function _quickStep(delta) {
        const next = Math.max(0, Math.min(files.count - 1, sel.currentIndex + delta))
        if (next === sel.currentIndex) return
        sel.select(next)
        _syncQuick(next)
    }

    // ---- drag and drop --------------------------------------------------------

    function mimeFor(paths) {
        return { "text/uri-list": paths.map(p => PathUtil.toUrl(p)).join("\r\n") + "\r\n" }
    }
    // Starts a drag of `paths`. The badge is grabbed to an image first (one or two frames), so the
    // drag only starts if the pointer is still down; otherwise nothing happens.
    function startDrag(paths, copy) {
        if (!paths || paths.length === 0 || dragging || _dragPending) return false
        _dragCopy = copy === true
        _dragPaths = paths.slice()
        _dragPending = true
        lastDragMime = mimeFor(_dragPaths)
        const first = _dragPaths[0]
        dragBadge.label = first.slice(first.lastIndexOf("/") + 1) + (_dragPaths.length > 1 ? "  +" + (_dragPaths.length - 1) : "")
        if (!dragBadge.grabToImage(result => root._beginDrag(result ? result.url : ""))) _beginDrag("")
        return true
    }
    function _beginDrag(imageUrl) {
        if (!_dragPending) return
        _dragPending = false
        const view = viewLoader.item
        if (!view || !view.pointerPressed) { lastDragState = "aborted"; _dragPaths = []; return }
        dragBadge.Drag.imageSource = imageUrl
        dragBadge.Drag.mimeData = lastDragMime
        dragBadge.Drag.active = true
        lastDragState = "native"
    }
    // Esc / drop outside the window / the window hiding: forget the drag. Never touches a file.
    function cancelDrag() {
        _dragPending = false
        if (dragBadge.Drag.active) { dragBadge.Drag.cancel() }
        dragBadge.Drag.active = false
        _dragPaths = []
        _hoverIndex = -1
    }
    function _dragEnded() {
        _dragPending = false
        _dragPaths = []
        _hoverIndex = -1
    }
    // Folder under the cursor (view coordinates) or -1. Items of the drag itself never count.
    function _dropIndexAt(x, y) {
        const view = viewLoader.item
        if (!view || !view.flick) return -1
        const i = view.indexAtContent(x + view.flick.contentX, y + view.flick.contentY)
        const entry = i >= 0 ? files.get(i) : null
        return entry && entry.isDir && _dragPaths.indexOf(entry.path) < 0 ? i : -1
    }
    // Single entry point of every drop. Our own drag moves (Ctrl copies); anything foreign copies, so the
    // source is never deleted. Returns false when nothing remains to do (same folder, folder into itself...).
    // Pure decision: our own drags move unless Ctrl asked for a copy; anything foreign always copies.
    function dropCopies(own, ctrlCopy) { return own ? ctrlCopy === true : true }
    // Pure: destination folder of a drop given the folder under the cursor (-1 = the listing itself).
    function dropDestination(hoverIndex) {
        const folder = hoverIndex >= 0 ? files.get(hoverIndex) : null
        return folder && folder.isDir ? folder.path : files.path
    }
    function handleDrop(urls, dest, copy) {
        const own = dragging
        const target = PathUtil.normalize(dest)
        let paths = own ? _dragPaths.slice()
            : urls.map(u => String(u)).filter(u => u.indexOf("file:///") === 0).map(u => PathUtil.fromUrl(u))
        paths = paths.filter(p => p.length > 0 && p !== target && target.indexOf(p + "/") !== 0 && PathUtil.parent(p) !== target)
        if (!target.length || paths.length === 0) return false
        transfer(paths, target, own && copy !== true, false)
        return true
    }

    // ---- model, selection, services ----------------------------------------

    FilesModel {
        id: files
        showHidden: Config.files.showHidden
        sortField: Config.files.sortField
        sortReversed: Config.files.sortReversed
        dirsFirst: Config.files.dirsFirst
        watchPath: root.active
        onPathLost: fallback => {
            root.notice = I18n.tr("La carpeta ya no existe")
            root._back = root._back.filter(p => p !== files.path)
            files.navigate(fallback)
        }
        // Unreadable folder: warn and go back to the last valid directory (the previous one, else the parent).
        onDenied: dir => {
            root.notice = I18n.tr("Sin permiso") + ": " + dir.slice(dir.lastIndexOf("/") + 1)
            const prev = root._back.length ? root._back[root._back.length - 1] : PathUtil.parent(dir)
            if (root._back.length) root._back = root._back.slice(0, -1)
            files.navigate(prev)
        }
    }
    SelectionModel { id: sel; model: files }
    PlacesData { id: placesData; active: root.active }

    // A new folder starts without a query and without a preview; a vanished entry closes the preview.
    Connections {
        target: files
        function onPathChanged() {
            root._enterFolder(files.path)
            quick.close(true)
            if (files.filter.length) files.filter = ""
            root.cancelDrag()
        }
        function onCountChanged() {
            if (quick.open && files.indexOfName(quick.fileName) < 0) quick.close(true)
        }
    }
    onActiveChanged: if (!active) { cancelDrag(); quick.close(true); openFade.complete() }

    // Directional entry of the new listing: into a child +1, up to an ancestor -1, a lateral jump
    // fades only. The first folder has no entry of its own (the window opening covers it).
    property string _navFrom: ""
    function _enterFolder(to) {
        const from = _navFrom
        _navFrom = to
        if (!from.length || !to.length || from === to) return
        const under = (a, b) => b.indexOf(a === "/" ? "/" : a + "/") === 0
        nav.direction = under(from, to) ? 1 : under(to, from) ? -1 : 0
        nav.run()
    }
    NavTransition {
        id: nav
        active: root.active
        holding: files.loading
    }

    Connections {
        target: FileOps
        function onFinished(op, ok, message) {
            if (!ok) root.notice = message
            else if (op === "undo") root.notice = root.undoText()
            else if (op === "trash") root.notice = I18n.tr("Movido a la papelera")
        }
        function onItemFailed(path, error) { root.notice = path + ": " + error }
    }
    Timer { id: noticeTimer; interval: 6000; running: root.notice.length > 0; onTriggered: root.notice = "" }
    onNoticeChanged: if (notice.length) noticeTimer.restart()

    Component.onCompleted: {
        navigate(startPath.length ? startPath : homeDir, false)
        if (selectName.length) _selectLater(selectName)
        placesData.refresh()
        openSpring.target = 1
        if (Flags.reduceMotion && root.active) { _openFadeValue = 0; openFade.start() }
        viewLoader.forceActiveFocus()
    }

    // ---- keyboard -----------------------------------------------------------

    Keys.onPressed: e => {
        if (conflictOpen || promptOpen || menu.opened) return
        const ctrl = (e.modifiers & Qt.ControlModifier) !== 0, alt = (e.modifiers & Qt.AltModifier) !== 0
        const shift = (e.modifiers & Qt.ShiftModifier) !== 0, meta = (e.modifiers & Qt.MetaModifier) !== 0
        // Plain keys (no Ctrl/Alt/Meta) feed search and preview, but never while the path field is being edited.
        const plain = !ctrl && !alt && !meta && !pathBar.editing
        e.accepted = true
        if (plain && e.key === Qt.Key_Space) toggleQuickLook()
        else if (plain && e.key === Qt.Key_Escape && files.filter.length) clearFilter()
        else if (plain && e.key === Qt.Key_Backspace && files.filter.length) trimFilter()
        else if (plain && _printable(e.text)) typeFilter(e.text)
        else if (alt && e.key === Qt.Key_Left) goBack()
        else if (alt && e.key === Qt.Key_Right) goForward()
        else if (alt && e.key === Qt.Key_Up) goUp()
        else if (!ctrl && !alt && e.key === Qt.Key_Backspace) goUp()
        else if (ctrl && e.key === Qt.Key_C) copySelection()
        else if (ctrl && e.key === Qt.Key_X) cutSelection()
        else if (ctrl && e.key === Qt.Key_V) paste()
        else if (ctrl && e.key === Qt.Key_Z) undo()
        else if (ctrl && e.key === Qt.Key_L) pathBar.startEditing()
        else if (ctrl && e.key === Qt.Key_H) toggleHidden()
        else if (ctrl && e.key === Qt.Key_W) closeRequested()
        else if (ctrl && shift && e.key === Qt.Key_N) beginNewFolder()
        else if (e.key === Qt.Key_F2) beginRename()
        else if (e.key === Qt.Key_Delete) trashSelection()
        else e.accepted = false
    }

    // ---- appearance ---------------------------------------------------------

    // Window opening: the glass unfolds with the surface spring (banded, ~3 % overshoot) from
    // Motion.materializeScale. A late first frame (window mapping) is capped at 1/30 s per step, so it
    // slows the start instead of skipping it. reduceMotion: a fade of Motion.fast, no scale.
    SpringValue {
        id: openSpring
        spring: Motion.surfaceSpring.open.w
        active: root.active
        maxStep: 1 / 30
        target: 0
    }
    property real _openFadeValue: 1
    NumberAnimation { id: openFade; target: root; property: "_openFadeValue"; to: 1; duration: Motion.fast }

    Rectangle {
        id: glass
        objectName: "glass"
        anchors.fill: parent
        radius: Theme.radiusXl
        color: Qt.alpha(Theme.background, 0.9)
        border.width: 1
        border.color: Qt.alpha(Theme.foreground, Theme.alphaHair)
        opacity: Flags.reduceMotion ? root._openFadeValue : Math.max(0, Math.min(1, openSpring.value * 1.4))
        scale: Flags.reduceMotion ? 1 : Motion.materializeScale + (1 - Motion.materializeScale) * openSpring.value
        transformOrigin: Item.Center

        Sidebar {
            id: sidebar
            x: Theme.spacingMd
            y: Theme.spacingMd
            width: 176
            height: parent.height - 2 * Theme.spacingMd
            places: placesData.places
            drives: placesData.drives
            currentPath: files.path
            onNavigateTo: p => root.navigate(p)
        }

        Row {
            id: toolbar
            x: sidebar.x + sidebar.width + Theme.spacingMd
            y: Theme.spacingMd
            height: 36
            spacing: Theme.spacingSm
            Repeater {
                model: [
                    { icon: "arrow_back", act: "back" },
                    { icon: "arrow_forward", act: "forward" },
                    { icon: "arrow_upward", act: "up" },
                    { icon: Config.files.view === "list" ? "grid_view" : "view_list", act: "view" }
                ]
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool live: modelData.act === "back" ? root.canBack : modelData.act === "forward" ? root.canForward
                        : modelData.act === "up" ? files.path !== "/" : true
                    objectName: "nav_" + modelData.act
                    width: 32; height: 32; y: 2
                    radius: Theme.radiusSm
                    color: Qt.alpha(Theme.foreground, tap.containsMouse && live ? Theme.alphaWash : 0)
                    Text {
                        anchors.centerIn: parent
                        text: modelData.icon
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 20
                        color: Qt.alpha(Theme.foreground, live ? 1 : Theme.alphaDisabled)
                    }
                    MouseArea {
                        id: tap
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: live
                        onClicked: {
                            if (modelData.act === "back") root.goBack()
                            else if (modelData.act === "forward") root.goForward()
                            else if (modelData.act === "up") root.goUp()
                            else root.setFiles({ view: Config.files.view === "list" ? "grid" : "list" })
                        }
                    }
                }
            }
        }

        PathBar {
            id: pathBar
            objectName: "pathBar"
            x: toolbar.x + toolbar.width + Theme.spacingMd
            y: Theme.spacingMd
            width: parent.width - x - Theme.spacingMd
            path: files.path
            homeDir: root.homeDir
            onNavigateTo: p => { root.navigate(p); root.focusView() }
            internalDrag: root.dragging
            animate: root.active
            dropCopy: root.dropCopies(root.dragging, root._dragCopy)
            onPathDropped: (folder, urls, copy) => root.handleDrop(urls, folder, copy)
        }

        Loader {
            id: viewLoader
            objectName: "viewLoader"
            x: toolbar.x
            y: pathBar.y + pathBar.height + Theme.spacingMd
            width: parent.width - x - Theme.spacingMd
            height: parent.height - y - status.height - 2 * Theme.spacingMd
            sourceComponent: Config.files.view === "list" ? listComponent : gridComponent
            focus: true
            onLoaded: if (root.active) item.forceActiveFocus()
            opacity: nav.fade
            transform: Translate { x: nav.offset }
        }
        Component { id: gridComponent; FileGrid { model: files; selection: sel; iconSize: Config.files.iconSize; thumbResolver: FileOps.thumb; thumbCanceller: FileOps.cancelThumb; loadThumbs: root.active; filtering: files.filter.length > 0; animate: root.active } }
        Component { id: listComponent; FileList { model: files; selection: sel; iconSize: 28; thumbResolver: FileOps.thumb; thumbCanceller: FileOps.cancelThumb; loadThumbs: root.active; filtering: files.filter.length > 0; animate: root.active } }
        Connections {
            target: viewLoader.item
            ignoreUnknownSignals: true
            function onActivated(index) { root.openEntry(index) }
            function onDragStarted(paths, copy) { root.startDrag(paths, copy) }
            function onContextRequested(index, pos) {
                const at = viewLoader.mapToItem(root, pos.x, pos.y)
                menu.open(at.x, at.y, root.menuEntries(index))
            }
        }

        Text {
            anchors.centerIn: viewLoader
            visible: files.ready && files.count === 0
            text: files.unlistable ? I18n.tr("Algunos elementos no se pueden mostrar")
                : files.filter.length ? I18n.tr("Sin coincidencias") : I18n.tr("Carpeta vacía")
            font.family: Theme.font
            font.pixelSize: Theme.fontSizeBody
            color: Qt.alpha(Theme.foreground, Theme.alphaDisabled)
        }

        // Drop target of the listing: a folder under the cursor receives the drop, free space means
        // the current folder. Mouse events pass through (DropArea has no pointer handling).
        DropArea {
            id: viewDrop
            objectName: "viewDrop"
            x: viewLoader.x; y: viewLoader.y; width: viewLoader.width; height: viewLoader.height
            z: 5
            onEntered: drag => { drag.accepted = drag.hasUrls && (root.dragging || (drag.supportedActions & Qt.CopyAction) !== 0) }
            onPositionChanged: drag => { root._hoverIndex = root._dropIndexAt(drag.x, drag.y) }
            onExited: root._hoverIndex = -1
            onDropped: drop => {
                const copy = root.dropCopies(root.dragging, root._dragCopy)
                const dest = root.dropDestination(root._hoverIndex)
                drop.accept(copy ? Qt.CopyAction : Qt.MoveAction)
                root._hoverIndex = -1
                root.handleDrop(drop.urls.map(u => String(u)), dest, copy)
            }
        }
        Rectangle {
            objectName: "dropHighlight"
            readonly property rect r: root._hoverIndex >= 0 && viewLoader.item ? viewLoader.item.positionAt(root._hoverIndex) : Qt.rect(0, 0, 0, 0)
            visible: root._hoverIndex >= 0
            x: viewLoader.x + r.x + 3; y: viewLoader.y + r.y + 3; width: r.width - 6; height: r.height - 6
            z: 6
            radius: Theme.radiusLg
            color: Qt.alpha(Theme.accent, Theme.alphaEmphasis)
            border.width: Theme.borderHairline
            border.color: Qt.alpha(Theme.accent, Theme.alphaStrong)
        }
        // Drag proxy: off screen, visible only while its image is being grabbed. Native drag (Wayland/X11 DnD).
        Rectangle {
            id: dragBadge
            objectName: "dragBadge"
            property string label: ""
            x: -4000; y: -4000
            visible: root._dragPending
            width: Math.min(220, badgeText.implicitWidth + 24); height: 28
            radius: Theme.radiusSm
            color: Theme.surfaceContainer
            border.width: 1
            border.color: Qt.alpha(Theme.accent, Theme.alphaStrong)
            Text {
                id: badgeText
                anchors.centerIn: parent
                width: parent.width - 16
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideMiddle
                textFormat: Text.PlainText
                text: dragBadge.label
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.foreground
            }
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
            Drag.proposedAction: Qt.MoveAction
            Drag.hotSpot: Qt.point(12, 14)
            Drag.onDragFinished: root._dragEnded()
        }

        QuickLook {
            id: quick
            objectName: "quickLook"
            anchors.fill: parent
            hostActive: root.active
            onClosed: root.focusView()
            onStep: delta => root._quickStep(delta)
        }

        Item {
            id: status
            objectName: "statusBar"
            x: viewLoader.x
            y: parent.height - height - Theme.spacingMd
            width: viewLoader.width
            height: 26
            Text {
                id: statusText
                objectName: "statusText"
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * 0.5
                elide: Text.ElideRight
                text: files.filter.length ? I18n.tr("Buscar: %1").replace("%1", () => files.filter)
                    : sel.count > 0 ? I18n.tr("%1 seleccionados").replace("%1", sel.count)
                    : I18n.tr("%1 elementos").replace("%1", files.count)
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeSmall
                color: Qt.alpha(Theme.foreground, Theme.alphaDisabled)
            }
            Text {
                objectName: "noticeText"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * 0.5 - (progressBar.visible ? 0 : 0)
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideLeft
                visible: !FileOps.busy
                text: root.notice.length ? root.notice
                    : files.unlistable ? I18n.tr("Algunos elementos no se pueden mostrar") : ""
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeSmall
                color: root.notice.length ? Theme.foreground : Qt.alpha(Theme.foreground, Theme.alphaDisabled)
            }
            Item {
                id: progressBar
                objectName: "progressBar"
                visible: FileOps.busy
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * 0.5
                height: parent.height
                Rectangle {
                    id: track
                    anchors.left: parent.left
                    anchors.right: cancelHit.left
                    anchors.rightMargin: Theme.spacingMd
                    anchors.verticalCenter: parent.verticalCenter
                    height: 4
                    radius: 2
                    color: Qt.alpha(Theme.foreground, Theme.alphaSubtle)
                    Rectangle {
                        width: parent.width * FileOps.progress
                        height: parent.height
                        radius: 2
                        color: Theme.accent
                    }
                }
                Text {
                    id: cancelHit
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("Cancelar")
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.accent
                    MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: FileOps.cancel() }
                }
            }
        }

        ContextMenu {
            id: menu
            anchors.fill: parent
            onTriggered: id => root.runMenu(id)
            onDismissed: root.focusView()
        }

        // Modal layer: conflict choice or a one-line name prompt.
        FocusScope {
            id: modal
            objectName: "modal"
            anchors.fill: parent
            z: 60
            visible: root.conflictOpen || root.promptOpen
            focus: visible
            onVisibleChanged: if (visible) {
                // The name field keeps the scope's focus after a prompt: release it so Esc of a conflict dialog reaches `modal`.
                if (!root.promptOpen) nameField.focus = false
                forceActiveFocus()
                if (root.promptOpen) { nameField.text = root._prompt.text; nameField.forceActiveFocus(); nameField.selectAll() }
            }
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Escape) { root.conflictOpen ? root.resolveConflict("cancel") : root.cancelPrompt() }
                e.accepted = true
            }
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
            Rectangle { anchors.fill: parent; radius: glass.radius; color: Qt.alpha("black", 0.35) }
            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 48, 420)
                height: dialogColumn.height + 2 * Theme.spacingXxl
                radius: Theme.radiusXxl
                color: Theme.surfaceContainer
                border.width: 1
                border.color: Qt.alpha(Theme.foreground, Theme.alphaHairline)
                Column {
                    id: dialogColumn
                    x: Theme.spacingXxl; y: Theme.spacingXxl
                    width: parent.width - 2 * Theme.spacingXxl
                    spacing: Theme.spacingXl
                    Text {
                        objectName: "dialogTitle"
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: root.conflictOpen
                            ? (root.conflictNames.length === 1
                                ? I18n.tr("«%1» ya existe en esta carpeta").replace("%1", root.conflictNames[0])
                                : I18n.tr("%1 elementos ya existen en esta carpeta").replace("%1", root.conflictNames.length))
                            : (root.promptOpen ? root._prompt.title : "")
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSizeTitle
                        color: Theme.foreground
                    }
                    Rectangle {
                        visible: root.promptOpen
                        width: parent.width
                        height: 34
                        radius: Theme.radiusSm
                        color: Qt.alpha(Theme.foreground, Theme.alphaSoft)
                        TextInput {
                            id: nameField
                            objectName: "nameField"
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSizeBody
                            color: Theme.foreground
                            selectionColor: Theme.accent
                            onAccepted: root.acceptPrompt(text)
                            Keys.onEscapePressed: root.cancelPrompt()
                        }
                    }
                    Row {
                        spacing: Theme.spacingMd
                        layoutDirection: Qt.RightToLeft
                        width: parent.width
                        Repeater {
                            model: root.conflictOpen
                                ? [{ id: "overwrite", label: I18n.tr("Reemplazar") }, { id: "keepboth", label: I18n.tr("Mantener ambos") },
                                   { id: "skip", label: I18n.tr("Omitir") }]
                                : [{ id: "ok", label: I18n.tr("Aceptar") }, { id: "cancel", label: I18n.tr("Cancelar") }]
                            delegate: Rectangle {
                                required property var modelData
                                objectName: "dialog_" + modelData.id
                                width: label.implicitWidth + 24
                                height: 30
                                radius: Theme.radiusSm
                                color: Qt.alpha(modelData.id === "overwrite" || modelData.id === "ok" ? Theme.accent : Theme.foreground,
                                                btn.containsMouse ? Theme.alphaWashStrong : Theme.alphaSoft)
                                Text { id: label; anchors.centerIn: parent; text: modelData.label; font.family: Theme.font; font.pixelSize: Theme.fontSizeBody; color: Theme.foreground }
                                MouseArea {
                                    id: btn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        if (root.conflictOpen) root.resolveConflict(modelData.id)
                                        else if (modelData.id === "ok") root.acceptPrompt(nameField.text)
                                        else root.cancelPrompt()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
