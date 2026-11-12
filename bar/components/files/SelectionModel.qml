import QtQuick

// Selection of a file view. Stores paths (not indices), so it survives re-sorting and
// refreshes; currentIndex is recomputed from currentPath when the model changes.
// Leaf component: data comes in through `model` (FilesModel-like: count, get(i)->{path}, path),
// nothing is read from Config/FileOps.
QtObject {
    id: root

    property var model: null
    // Set of selected paths {path: true}. Replaced (never mutated) so bindings update.
    property var selected: ({})
    readonly property int count: _count
    property int _count: 0
    property int currentIndex: -1
    property string currentPath: ""
    property string anchorPath: ""
    property int _anchorIndex: -1
    property bool _pruneNeeded: false
    property bool _syncing: false

    onCurrentIndexChanged: if (!_syncing) currentPath = pathAt(currentIndex)

    function pathAt(i) {
        const entry = root.model && i >= 0 && i < root.model.count ? root.model.get(i) : null
        return entry ? entry.path : ""
    }
    function isSelected(i) { return root.selected[pathAt(i)] === true }
    function paths() { return Object.keys(root.selected) }

    function _publish(set, size) { root.selected = set; root._count = size }
    function _setCurrent(i) { root.currentIndex = i; root.currentPath = pathAt(i) }
    function _setAnchor(i) { root._anchorIndex = i; root.anchorPath = pathAt(i) }
    function _anchor() {
        if (root.anchorPath.length === 0) return -1
        if (pathAt(root._anchorIndex) === root.anchorPath) return root._anchorIndex
        root._anchorIndex = _find(root.anchorPath)
        return root._anchorIndex
    }
    function _find(path) {
        const m = root.model
        if (!m || path.length === 0) return -1
        const slash = path.lastIndexOf("/")
        if (m.indexOfName) {
            const i = m.indexOfName(path.slice(slash + 1))
            if (i >= 0 && pathAt(i) === path) return i
        }
        for (let i = 0; i < m.count; i++) if (pathAt(i) === path) return i
        return -1
    }
    function _range(from, to) {
        const lo = Math.max(0, Math.min(from, to)), hi = Math.min(root.model.count - 1, Math.max(from, to))
        const set = {}
        let size = 0
        for (let i = lo; i <= hi; i++) { set[pathAt(i)] = true; size++ }
        return { set: set, size: size }
    }

    function select(i) {
        if (!root.model || i < 0 || i >= root.model.count) return
        const path = pathAt(i), set = {}
        set[path] = true
        _publish(set, 1)
        _setCurrent(i)
        _setAnchor(i)
    }
    function toggle(i) {
        if (!root.model || i < 0 || i >= root.model.count) return
        const path = pathAt(i), set = Object.assign({}, root.selected)
        let size = root._count
        if (set[path]) { delete set[path]; size-- } else { set[path] = true; size++ }
        _publish(set, size)
        _setCurrent(i)
        _setAnchor(i)
    }
    function extendTo(i) {
        if (!root.model || i < 0 || i >= root.model.count) return
        let a = _anchor()
        if (a < 0) a = root.currentIndex >= 0 ? root.currentIndex : i
        const r = _range(a, i)
        _publish(r.set, r.size)
        _setCurrent(i)
        if (root.anchorPath.length === 0) _setAnchor(a)
    }
    // rect and itemRectFn(i) share one coordinate space. opts: {first, last} limit the scanned
    // indices; {base} is a set kept in the result (ctrl + band).
    function selectRect(rect, itemRectFn, opts) {
        if (!root.model) return
        const o = opts || {}
        const first = Math.max(0, o.first ?? 0), last = Math.min(root.model.count - 1, o.last ?? root.model.count - 1)
        const set = o.base ? Object.assign({}, o.base) : {}
        let size = o.base ? (o.baseCount ?? Object.keys(o.base).length) : 0
        const rx2 = rect.x + rect.width, ry2 = rect.y + rect.height
        for (let i = first; i <= last; i++) {
            const r = itemRectFn(i)
            if (r.x < rx2 && r.x + r.width > rect.x && r.y < ry2 && r.y + r.height > rect.y) {
                const path = pathAt(i)
                if (!set[path]) { set[path] = true; size++ }
            }
        }
        _publish(set, size)
    }
    function selectAll() {
        if (!root.model) return
        const r = _range(0, root.model.count - 1)
        _publish(r.set, r.size)
        if (root.currentIndex < 0 && root.model.count > 0) { _setCurrent(0); _setAnchor(0) }
    }
    function clear() { _publish({}, 0) }

    function moveTo(i, extend) {
        const n = root.model ? root.model.count : 0
        if (n === 0) return
        const target = Math.max(0, Math.min(n - 1, i))
        if (extend) {
            if (root.currentIndex < 0) select(target)
            else {
                if (_anchor() < 0) _setAnchor(root.currentIndex)
                extendTo(target)
            }
        } else select(target)
    }
    function move(delta, extend) {
        const n = root.model ? root.model.count : 0
        if (n === 0) return
        const base = root.currentIndex
        moveTo(base < 0 ? (delta > 0 ? 0 : n - 1) : base + delta, extend)
    }

    // Drop selected paths that are no longer in the model (removal, rename, filter change).
    function prune() {
        const m = root.model
        if (!m || root._count === 0) return
        const present = {}
        for (let i = 0; i < m.count; i++) present[pathAt(i)] = true
        const set = {}
        let size = 0
        for (const p of Object.keys(root.selected)) if (present[p]) { set[p] = true; size++ }
        if (size !== root._count) _publish(set, size)
    }
    // Re-derive currentIndex (and drop vanished paths) after the model changed.
    function resync() {
        const m = root.model
        if (!m) return
        const n = m.count
        if (root._pruneNeeded) { root._pruneNeeded = false; root.prune() }
        if (root.currentPath.length === 0) return
        if (pathAt(root.currentIndex) === root.currentPath) return
        const found = _find(root.currentPath)
        root._syncing = true
        if (found >= 0) root.currentIndex = found
        else { root.currentIndex = n === 0 ? -1 : Math.min(root.currentIndex, n - 1); root.currentPath = pathAt(root.currentIndex) }
        root._syncing = false
    }
    function _later(prune) { if (prune) root._pruneNeeded = true; Qt.callLater(root.resync) }
    function _reset() { root.clear(); root.currentIndex = -1; root.currentPath = ""; root.anchorPath = ""; root._anchorIndex = -1; root._pruneNeeded = false }

    onModelChanged: _reset()

    property Connections _top: Connections {
        target: root.model
        ignoreUnknownSignals: true
        function onCountChanged() { root._later(false) }
        function onFilterChanged() { root._later(true) }
        function onPathChanged() { root._reset() }
    }
    property Connections _rows: Connections {
        target: root.model ? root.model.model : null
        ignoreUnknownSignals: true
        function onModelReset() { root._later(true) }
        function onLayoutChanged() { root._later(true) }
        function onRowsInserted() { root._later(false) }
        function onRowsRemoved() { root._later(true) }
        function onRowsMoved() { root._later(false) }
        function onDataChanged() { root._later(true) }
    }
}
