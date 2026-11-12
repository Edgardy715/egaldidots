import QtQuick
import "../../Singletons"
import ".."

// Shared behaviour of FileGrid and FileList: pointer (click, ctrl/shift, rubber band, drag
// start, context), keyboard, selection highlight and geometry. The subclass supplies the
// Flickable (`flick`) and the cell metrics (`columns`, `cellW`, `cellH`); a list is a grid
// with one column. Leaf component: model/selection/iconSize/thumbResolver arrive as
// properties and requests leave as signals; nothing reads Config or FileOps.
FocusScope {
    id: root

    property var model: null              // FilesModel-like: count, get(i), model
    property var selection: null          // SelectionModel
    property real iconSize: 64
    // False while the window is hidden: the highlight and the thumbnails resolve without animating.
    property bool animate: true
    // True while a type-to-filter query is active: Esc then belongs to the composition (it clears
    // the query) instead of clearing the selection.
    property bool filtering: false
    // function (path, size, cb) -> calls cb(thumbPath, ok); bound by the composition.
    property var thumbResolver: null
    // function (path, size) -> drops a thumbnail request that has not started yet (optional).
    property var thumbCanceller: null
    // False while the window is hidden: queued requests are dropped and none is made until it shows again.
    property bool loadThumbs: true
    // Delegates call this instead of thumbResolver: a directory change makes FolderListModel
    // remove and re-insert every row, so delegates are rebuilt; resolved paths are remembered
    // per (path,size,modified) and in-flight requests are shared, so the resolver is asked once.
    // Bounded (LRU) and cleared when the resolver or the folder changes.
    readonly property int thumbMemoLimit: 500
    property var _thumbDone: ({})
    property var _thumbOrder: []
    property var _thumbWaiting: ({})
    readonly property int thumbMemoSize: _thumbOrder.length
    property int thumbEpoch: 0
    function _thumbDropWaiting() {
        const waiting = _thumbWaiting
        _thumbWaiting = ({})
        if (!thumbCanceller) return
        for (const key in waiting) thumbCanceller(waiting[key].path, waiting[key].size)
    }
    function _thumbForget() { _thumbDropWaiting(); _thumbDone = ({}); _thumbOrder = []; thumbEpoch++ }
    // A delegate that no longer needs `cb` (recycled, left the screen, changed file) withdraws it; the
    // queued job is cancelled once nobody is waiting for it.
    function cancelThumb(path, size, cb, stamp) {
        const key = size + "|" + path + "|" + (stamp ?? "")
        const list = _thumbWaiting[key]
        if (!list) return
        const at = list.indexOf(cb)
        if (at >= 0) list.splice(at, 1)
        if (list.length > 0) return
        delete _thumbWaiting[key]
        if (thumbCanceller) thumbCanceller(path, size)
    }
    onLoadThumbsChanged: { if (!loadThumbs) _thumbDropWaiting(); else thumbEpoch++ }
    onThumbResolverChanged: _thumbForget()
    Connections {
        target: root.model
        ignoreUnknownSignals: true
        function onPathChanged() { root._thumbForget() }
    }
    function resolveThumb(path, size, cb, stamp) {
        if (!root.thumbResolver || !root.loadThumbs) return
        const key = size + "|" + path + "|" + (stamp ?? "")
        const done = root._thumbDone, order = root._thumbOrder
        if (done[key] !== undefined) {
            const at = order.indexOf(key)
            if (at >= 0) { order.splice(at, 1); order.push(key) }
            cb(done[key], true)
            return
        }
        const waiting = root._thumbWaiting
        if (waiting[key]) { waiting[key].push(cb); return }
        waiting[key] = [cb]
        waiting[key].path = path
        waiting[key].size = size
        const resolver = root.thumbResolver
        resolver(path, size, (thumbPath, ok) => {
            if (!root || root._thumbWaiting !== waiting) return   // memory was cleared meanwhile
            const list = waiting[key] || []
            delete waiting[key]
            if (ok && thumbPath) {
                root._thumbDone[key] = thumbPath
                root._thumbOrder.push(key)
                while (root._thumbOrder.length > root.thumbMemoLimit) delete root._thumbDone[root._thumbOrder.shift()]
            }
            for (const f of list) f(thumbPath, ok)
        })
    }

    property Flickable flick: null
    property int columns: 1
    property real cellW: width
    property real cellH: 40
    readonly property real inset: 3

    readonly property int count: model ? model.count : 0
    readonly property bool pointerPressed: pointer.pressed
    property int _rev: 0
    property int createdCount: 0
    readonly property var _runs: computeRuns()
    readonly property int highlightCount: _runs.length
    readonly property bool highlightAnimating: slider.animating

    signal activated(int index)
    signal contextRequested(int index, point pos)
    signal dragStarted(var paths, bool copy)

    function _entry(i, rev) {
        return (root.model ? root.model.get(i) : null) ?? ({ name: "", path: "", url: "", isDir: false, size: 0, modified: null })
    }

    // ---- geometry (content coordinates unless noted) ----
    function contentRect(i) {
        const c = i % root.columns, r = Math.floor(i / root.columns)
        return Qt.rect(c * root.cellW, r * root.cellH, root.cellW, root.cellH)
    }
    // Rect of item i in this view's coordinates (for QuickLook and overlays).
    function positionAt(i) {
        if (!root.flick || i < 0 || i >= root.count) return Qt.rect(0, 0, 0, 0)
        const r = contentRect(i)
        return Qt.rect(r.x - root.flick.contentX + root.flick.x, r.y - root.flick.contentY + root.flick.y, r.width, r.height)
    }
    function indexAtContent(x, y) {
        if (x < 0 || y < 0) return -1
        const c = Math.floor(x / root.cellW)
        if (c >= root.columns) return -1
        const i = Math.floor(y / root.cellH) * root.columns + c
        return i < root.count ? i : -1
    }
    function ensureVisible(i) {
        const f = root.flick
        if (!f || i < 0 || i >= root.count) return
        const r = contentRect(i)
        const maxY = Math.max(0, f.contentHeight - f.height)
        if (r.y < f.contentY) f.contentY = Math.max(0, r.y)
        else if (r.y + r.height > f.contentY + f.height) f.contentY = Math.min(maxY, r.y + r.height - f.height)
    }
    function _firstVisible() { return root.flick ? Math.max(0, Math.floor(root.flick.contentY / root.cellH)) * root.columns : 0 }
    function _lastVisible() {
        if (!root.flick) return -1
        return Math.min(root.count - 1, (Math.floor((root.flick.contentY + root.flick.height) / root.cellH) + 1) * root.columns - 1)
    }

    // One highlight per contiguous selected run among visible items (split at row ends).
    function computeRuns() {
        const sel = root.selection ? root.selection.selected : null
        const rev = root._rev
        const f = root.flick, m = root.model
        if (!sel || !m || !f || root.count === 0 || root.cellH <= 0) return []
        if (root.selection.count === 0) return []
        const cols = root.columns, first = root._firstVisible(), last = root._lastVisible()
        const out = []
        let start = -1
        for (let i = first; i <= last + 1; i++) {
            const e = i <= last ? m.get(i) : null
            const on = e !== null && sel[e.path] === true
            if (on && start < 0) start = i
            else if (!on && start >= 0) {
                const end = i - 1
                if (cols === 1) {
                    out.push(Qt.rect(root.inset, start * root.cellH + root.inset,
                                     root.cellW - 2 * root.inset, (end - start + 1) * root.cellH - 2 * root.inset))
                    start = -1
                    continue
                }
                for (let row = Math.floor(start / cols); row <= Math.floor(end / cols); row++) {
                    const c1 = row === Math.floor(start / cols) ? start % cols : 0
                    const c2 = row === Math.floor(end / cols) ? end % cols : cols - 1
                    out.push(Qt.rect(c1 * root.cellW + root.inset, row * root.cellH + root.inset,
                                     (c2 - c1 + 1) * root.cellW - 2 * root.inset, root.cellH - 2 * root.inset))
                }
                start = -1
            }
        }
        return out
    }
    function highlightRect(n) { return n >= 0 && n < _runs.length ? _runs[n] : Qt.rect(0, 0, 0, 0) }

    Binding { target: root.selection; property: "model"; value: root.model; when: root.selection !== null; restoreMode: Binding.RestoreNone }

    Connections {
        target: root.model
        ignoreUnknownSignals: true
        function onCountChanged() { root._rev++ }
    }
    Connections {
        target: root.model ? root.model.model : null
        ignoreUnknownSignals: true
        function onModelReset() { root._rev++ }
        function onLayoutChanged() { root._rev++ }
        function onDataChanged() { root._rev++ }
        function onRowsInserted() { root._rev++ }
        function onRowsRemoved() { root._rev++ }
        function onRowsMoved() { root._rev++ }
    }

    // ---- overlays inside the scrolled content ----
    // The first run is a single highlight that slides between items when the selection changes. A
    // scroll, a resize, a model change, the rubber band, a jump farther than one screen or a highlight
    // that was hidden place it at once. Further runs (multiple selection) are drawn by the Repeater.
    Rectangle {
        id: slider
        objectName: "selectionHighlight"
        parent: root.flick ? root.flick.contentItem : root
        readonly property bool on: root._runs.length > 0
        readonly property rect goal: on ? root._runs[0] : Qt.rect(0, 0, 0, 0)
        readonly property rect shown: Qt.rect(hx.value, hy.value, Math.max(0, hw.value), Math.max(0, hh.value))
        readonly property bool animating: hx.integrating || hy.integrating || hw.integrating || hh.integrating
        property var _sel: null
        property string _geom: ""
        property bool _was: false
        onGoalChanged: _place()
        onOnChanged: _place()
        function _place() {
            const g = goal, sel = root.selection ? root.selection.selected : null
            const geom = root.columns + "|" + root.cellW + "|" + root.cellH + "|" + root.count
            const reach = root.flick ? root.flick.height : 0
            const far = Math.abs(g.x - hx.value) + Math.abs(g.y - hy.value) > reach
            const slide = on && _was && sel !== _sel && geom === _geom && !pointer.band && !far
            _sel = sel; _geom = geom; _was = on
            if (!on) return
            hx.target = g.x; hy.target = g.y; hw.target = g.width; hh.target = g.height
            if (!slide) { hx.snap(g.x); hy.snap(g.y); hw.snap(g.width); hh.snap(g.height) }
        }
        SpringValue { id: hx; spring: Motion.filesHighlightSpring; active: root.animate; settleDistance: 0.05; settleSpeed: 0.5 }
        SpringValue { id: hy; spring: Motion.filesHighlightSpring; active: root.animate; settleDistance: 0.05; settleSpeed: 0.5 }
        SpringValue { id: hw; spring: Motion.filesHighlightSpring; active: root.animate; settleDistance: 0.05; settleSpeed: 0.5 }
        SpringValue { id: hh; spring: Motion.filesHighlightSpring; active: root.animate; settleDistance: 0.05; settleSpeed: 0.5 }
        visible: on
        x: shown.x; y: shown.y; width: shown.width; height: shown.height
        z: -1
        radius: Theme.radiusLg
        color: Qt.alpha(Theme.accent, Theme.alphaEmphasis)
        border.width: Theme.borderHairline
        border.color: Qt.alpha(Theme.accent, Theme.alphaStrong)
    }
    Repeater {
        parent: root.flick ? root.flick.contentItem : root
        model: root._runs.slice(1)
        delegate: Rectangle {
            required property var modelData
            x: modelData.x; y: modelData.y; width: modelData.width; height: modelData.height
            z: -1
            radius: Theme.radiusLg
            color: Qt.alpha(Theme.accent, Theme.alphaEmphasis)
            border.width: Theme.borderHairline
            border.color: Qt.alpha(Theme.accent, Theme.alphaStrong)
        }
    }
    Rectangle {
        id: focusRing
        parent: root.flick ? root.flick.contentItem : root
        readonly property int idx: root.selection ? root.selection.currentIndex : -1
        visible: root.activeFocus && idx >= 0 && idx < root.count
        readonly property rect r: idx >= 0 ? root.contentRect(idx) : Qt.rect(0, 0, 0, 0)
        // When the current item is the single selected one, the ring rides on the sliding highlight
        // (no second animation); otherwise it sits on the current item.
        readonly property bool rides: root._runs.length === 1 && Math.abs(slider.goal.x - r.x - root.inset) < 0.5
            && Math.abs(slider.goal.y - r.y - root.inset) < 0.5 && Math.abs(slider.goal.width - r.width + 2 * root.inset) < 0.5
        x: rides ? slider.x : r.x + root.inset
        y: rides ? slider.y : r.y + root.inset
        width: rides ? slider.width : r.width - 2 * root.inset
        height: rides ? slider.height : r.height - 2 * root.inset
        z: -1
        radius: Theme.radiusLg
        color: "transparent"
        border.width: Theme.borderHairline
        border.color: Qt.alpha(Theme.accent, Theme.alphaIconOnAcc)
    }
    RubberBand {
        id: bandBox
        parent: root.flick ? root.flick.contentItem : root
        z: 10
        target: pointer.bandRect
        active: pointer.band && pointer.moved
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        z: 2   // above the view's Flickable, which is declared later by FileGrid/FileList
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        preventStealing: true
        property int pressIndex: -1
        property bool pending: false
        property bool band: false
        property bool moved: false
        property bool dragged: false
        property point origin
        property point contentOrigin
        property var bandBase: null
        property int bandBaseCount: 0
        property rect bandRect: Qt.rect(0, 0, 0, 0)

        function _index(m) { return root.flick ? root.indexAtContent(m.x + root.flick.contentX, m.y + root.flick.contentY) : -1 }

        onPressed: m => {
            root.forceActiveFocus()
            const idx = _index(m), sel = root.selection
            origin = Qt.point(m.x, m.y)
            contentOrigin = Qt.point(m.x + root.flick.contentX, m.y + root.flick.contentY)
            moved = false; dragged = false; band = false; pending = false; pressIndex = idx; bandBase = null
            if (!sel) return
            if (m.button === Qt.RightButton) {
                if (idx >= 0 && !sel.isSelected(idx)) sel.select(idx)
                else if (idx < 0) sel.clear()
                root.contextRequested(idx, Qt.point(m.x, m.y))
                return
            }
            const ctrl = (m.modifiers & Qt.ControlModifier) !== 0, shift = (m.modifiers & Qt.ShiftModifier) !== 0
            if (idx >= 0) {
                if (shift) sel.extendTo(idx)
                else if (ctrl) sel.toggle(idx)
                else if (sel.isSelected(idx)) pending = true
                else sel.select(idx)
            } else {
                band = true
                bandRect = Qt.rect(contentOrigin.x, contentOrigin.y, 0, 0)
                if (ctrl) { bandBase = sel.selected; bandBaseCount = sel.count }
                else if (!shift) sel.clear()
            }
        }
        onPositionChanged: m => {
            if (!pressed || !root.selection) return
            if (!moved && Math.abs(m.x - origin.x) + Math.abs(m.y - origin.y) > 8) moved = true
            if (!moved) return
            if (band) {
                const cx = m.x + root.flick.contentX, cy = m.y + root.flick.contentY
                const x1 = Math.min(contentOrigin.x, cx), y1 = Math.min(contentOrigin.y, cy)
                const x2 = Math.max(contentOrigin.x, cx), y2 = Math.max(contentOrigin.y, cy)
                bandRect = Qt.rect(x1, y1, x2 - x1, y2 - y1)
                root.selection.selectRect(bandRect, i => root.contentRect(i), {
                    first: Math.max(0, Math.floor(y1 / root.cellH)) * root.columns,
                    last: (Math.floor(y2 / root.cellH) + 1) * root.columns - 1,
                    base: bandBase, baseCount: bandBaseCount })
            } else if (pressIndex >= 0 && !dragged) {
                dragged = true; pending = false
                root.dragStarted(root.selection.paths(), (m.modifiers & Qt.ControlModifier) !== 0)
            }
        }
        onReleased: m => {
            if (pending && !moved && root.selection) root.selection.select(pressIndex)
            pending = false; band = false
        }
        onCanceled: { pending = false; band = false }
        onDoubleClicked: m => {
            const idx = _index(m)
            if (m.button === Qt.LeftButton && idx >= 0) root.activated(idx)
        }
    }

    // ---- keyboard ----
    function _step(delta) {
        const cur = root.selection.currentIndex
        if (cur < 0) return delta > 0 ? 0 : root.count - 1
        const target = cur + delta
        if (Math.abs(delta) === 1) return target
        if (target < 0) return cur
        if (target > root.count - 1) return Math.floor(cur / root.columns) < Math.floor((root.count - 1) / root.columns) ? root.count - 1 : cur
        return target
    }
    function _go(target, extend) {
        root.selection.moveTo(target, extend)
        root.ensureVisible(root.selection.currentIndex)
    }
    function _contextAtCurrent() {
        const i = root.selection.currentIndex
        if (i < 0 || i >= root.count) return
        const r = root.positionAt(i)
        root.contextRequested(i, Qt.point(r.x + r.width / 2, r.y + r.height / 2))
    }
    Keys.onPressed: e => {
        if (!root.selection || root.count === 0) return
        const extend = (e.modifiers & Qt.ShiftModifier) !== 0
        const rowsPerPage = Math.max(1, Math.floor((root.flick ? root.flick.height : root.height) / root.cellH) - 1)
        e.accepted = true
        const arrow = e.key === Qt.Key_Left || e.key === Qt.Key_Right || e.key === Qt.Key_Up || e.key === Qt.Key_Down
        if (arrow && (e.modifiers & (Qt.AltModifier | Qt.ControlModifier))) { e.accepted = false; return }
        switch (e.key) {
        case Qt.Key_Left:  if (root.columns > 1) root._go(root._step(-1), extend); break
        case Qt.Key_Right: if (root.columns > 1) root._go(root._step(1), extend); break
        case Qt.Key_Up:    root._go(root._step(-root.columns), extend); break
        case Qt.Key_Down:  root._go(root._step(root.columns), extend); break
        case Qt.Key_PageUp:   root._go(root._step(-root.columns * rowsPerPage), extend); break
        case Qt.Key_PageDown: root._go(root._step(root.columns * rowsPerPage), extend); break
        case Qt.Key_Home: root._go(0, extend); break
        case Qt.Key_End:  root._go(root.count - 1, extend); break
        case Qt.Key_A:
            if (e.modifiers & Qt.ControlModifier) root.selection.selectAll()
            else e.accepted = false
            break
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (root.selection.currentIndex >= 0) root.activated(root.selection.currentIndex)
            break
        case Qt.Key_Escape:
            if (!root.filtering && root.selection.count > 0) root.selection.clear()
            else e.accepted = false
            break
        case Qt.Key_Menu:
            root._contextAtCurrent(); break
        case Qt.Key_F10:
            if (extend) root._contextAtCurrent(); else e.accepted = false
            break
        default: e.accepted = false
        }
    }
}
