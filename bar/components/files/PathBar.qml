import QtQuick
import Quickshell.Io
import "../../Singletons"
import ".."
import "PathUtil.js" as PathUtil

// Breadcrumb path bar. Click a segment to navigate; Ctrl+L (or a click on the free area) turns it
// into an editable field. Enter navigates only if the folder exists (checked with `test -d`),
// otherwise the field shows an error and nothing is emitted; Esc cancels. Leaf component.
Item {
    id: root

    property string path: "/"
    property string homeDir: ""
    property bool editing: false
    property bool invalid: false
    readonly property var crumbs: PathUtil.segments(path)
    readonly property string text: field.text
    signal navigateTo(string path)
    // Something was dropped on a segment: its folder, the dropped urls and whether the proposed
    // action is a copy. The composition decides what to do (own drag moves, anything else copies).
    signal pathDropped(string folder, var urls, bool copy)
    // Set by the owner: the pure move/copy decision of a drop (own drag = Ctrl at its start, foreign = copy).
    property bool dropCopy: true
    // Bound by the composition: true while the drag in flight is the explorer's own (it may move;
    // a foreign drag is only ever copied, so its source is never deleted).
    property bool internalDrag: false
    // False while the window is hidden: a path change then lays the crumbs out without motion.
    property bool animate: true

    // Crumbs re-arrange on a path change: the row keeps its previous x for the new crumbs (the shared
    // prefix stays put) and springs to the new rest x; segments that were not shown before fade in.
    // A resize, the first path or an inactive bar place the row at once. `_laidPath`/`_shownPaths`
    // describe the last laid-out path and are updated after the new crumbs exist (callLater).
    property string _laidPath: ""
    property var _shownPaths: ({})
    function _crumbIsNew(p) {
        return animate && !Flags.reduceMotion && _laidPath.length > 0 && path !== _laidPath && _shownPaths[p] !== true
    }
    onPathChanged: Qt.callLater(_placeRow)
    onWidthChanged: _placeRow()
    function _placeRow() {
        const goal = row.restX
        const slide = animate && path !== _laidPath && _laidPath.length > 0
        rowX.target = goal
        if (!slide) rowX.snap(goal)
        _laidPath = path
        const now = {}
        for (const c of PathUtil.segments(path)) now[c.path] = true
        _shownPaths = now
    }
    SpringValue {
        id: rowX
        spring: Motion.filesCrumbSpring
        active: root.animate
        maxStep: 1 / 30
        settleDistance: 0.05
        settleSpeed: 0.5
    }
    readonly property bool animating: rowX.integrating

    implicitHeight: 36

    function startEditing() {
        _seq++            // a probe from a previous edit must not navigate
        _pending = ""
        field.text = root.path
        invalid = false
        editing = true
        field.forceActiveFocus()
        field.selectAll()
    }
    function cancel() {
        invalid = false
        editing = false
        _pending = ""
        _seq++            // a probe still in flight is ignored when it exits
    }
    function _resolve(raw) {
        let value = String(raw).trim()
        if (value === "~" || value.indexOf("~/") === 0) value = homeDir + value.slice(1)
        if (value.length === 0 || value.charAt(0) !== "/") return ""
        return PathUtil.normalize(value)
    }
    function commit() {
        const target = _resolve(field.text)
        _seq++
        if (target.length === 0) { _pending = ""; invalid = true; return }
        _pending = target
        const seq = _seq
        const proc = probeComponent.createObject(root, { command: ["test", "-d", target] })
        proc.exited.connect(code => {
            if (seq === root._seq && root._pending === target) {
                root._pending = ""
                if (code === 0) {
                    root.invalid = false
                    root.editing = false
                    root.navigateTo(target)
                } else {
                    root.invalid = true
                    if (!field.activeFocus) root.cancel()
                }
            }
            proc.destroy()
        })
        proc.running = true
    }
    property string _pending: ""
    property int _seq: 0

    // One Process per request, so a late exit can never be mistaken for the current one.
    Component { id: probeComponent; Process {} }

    Shortcut {
        sequence: "Ctrl+L"
        enabled: root.visible
        onActivated: root.startEditing()
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSm
        color: Qt.alpha(Theme.foreground, Theme.alphaFaint)
        border.width: 1
        border.color: root.invalid ? Theme.error : (root.editing ? Qt.alpha(Theme.accent, Theme.alphaIconSec) : Theme.border)
        Behavior on border.color { enabled: !Flags.reduceMotion; ColorAnimation { duration: Motion.fast } }
    }

    Item {
      id: crumbClip
      visible: !root.editing
      clip: true
      anchors.fill: parent
      anchors.margins: 1
    Row {
        id: row
        objectName: "crumbRow"
        anchors.verticalCenter: parent.verticalCenter
        // Short paths start at the left; deep ones overflow to the left so the current folder stays visible.
        readonly property real restX: width + Theme.spacingMd * 2 > crumbClip.width ? crumbClip.width - width - Theme.spacingMd : Theme.spacingMd
        // Same path (resize, late layout): follow at once, or retarget a slide that is still running.
        onRestXChanged: if (root.path === root._laidPath) { rowX.target = restX; if (!rowX.integrating) rowX.snap(restX) }
        x: rowX.value
        spacing: 2
        Repeater {
            model: root.crumbs
            delegate: Row {
                required property var modelData
                required property int index
                spacing: 2
                NumberAnimation on opacity {
                    id: crumbFade
                    running: false
                    from: 0; to: 1
                    duration: Motion.fast
                    easing.type: Easing.OutCubic
                }
                Component.onCompleted: if (root._crumbIsNew(modelData.path)) crumbFade.start()
                Text {
                    visible: index > 1
                    anchors.verticalCenter: parent.verticalCenter
                    text: "chevron_right"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 14
                    color: Qt.alpha(Theme.foreground, Theme.alphaDisabled)
                }
                Rectangle {
                    width: crumb.implicitWidth + 12
                    height: 24
                    radius: Theme.radiusXs
                    color: crumbDrop.containsDrag ? Qt.alpha(Theme.accent, Theme.alphaEmphasis)
                        : area.containsMouse ? Qt.alpha(Theme.foreground, Theme.alphaFaint * 2) : "transparent"
                    Behavior on color { enabled: !Flags.reduceMotion; ColorAnimation { duration: Motion.fast } }
                    Text {
                        id: crumb
                        anchors.centerIn: parent
                        text: modelData.name
                        textFormat: Text.PlainText
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSizeSmall
                        color: index === root.crumbs.length - 1 ? Theme.foreground : Qt.alpha(Theme.foreground, Theme.alphaIconSec)
                    }
                    DropArea {
                        id: crumbDrop
                        objectName: "crumbDrop_" + index
                        anchors.fill: parent
                        onEntered: drag => { drag.accepted = drag.hasUrls && (root.internalDrag || (drag.supportedActions & Qt.CopyAction) !== 0) }
                        onDropped: drop => {
                            const urls = drop.urls.map(u => String(u))
                            const copy = root.dropCopy
                            drop.accept(copy ? Qt.CopyAction : Qt.MoveAction)
                            root.pathDropped(modelData.path, urls, copy)
                        }
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.navigateTo(modelData.path)
                    }
                }
            }
        }
    }
    }
    MouseArea {
        anchors.fill: parent
        z: -1
        visible: !root.editing
        onDoubleClicked: root.startEditing()
    }

    TextInput {
        id: field
        visible: root.editing
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingXl
        anchors.rightMargin: Theme.spacingXl
        verticalAlignment: TextInput.AlignVCenter
        color: root.invalid ? Theme.error : Theme.foreground
        font.family: Theme.font
        font.pixelSize: Theme.fontSizeSmall
        selectByMouse: true
        selectionColor: Qt.alpha(Theme.accent, Theme.alphaSelected)
        selectedTextColor: Theme.foreground
        clip: true
        onTextChanged: if (root.editing) root.invalid = false
        onActiveFocusChanged: if (!activeFocus && root.editing && root._pending.length === 0) root.cancel()
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.commit(); event.accepted = true }
            else if (event.key === Qt.Key_Escape) { root.cancel(); event.accepted = true }
        }
    }
}
