import QtQuick
import "../../Singletons"

// Own context menu for the explorer (no Popup: it must live inside the FloatingWindow's scene).
// Leaf component: `entries` arrive as a property, the choice leaves as triggered(id). A click
// outside, Esc or a choice closes it. entries: [{id, label, enabled, separator}].
Item {
    id: root
    objectName: "contextMenu"

    property var entries: []
    readonly property bool opened: _open
    property bool _open: false
    property real _x: 0
    property real _y: 0
    signal triggered(string id)
    signal dismissed()

    visible: _open || fade.running
    z: 50

    function open(x, y, list) {
        entries = list
        _x = Math.max(4, Math.min(x, root.width - panel.width - 4))
        _y = Math.max(4, Math.min(y, root.height - panel.height - 4))
        _open = true
        forceActiveFocus()
    }
    function close() {
        if (!_open) return
        _open = false
        dismissed()
    }
    function pick(id) { _open = false; triggered(id) }

    // The menu is modal: every key is consumed while open so Del/Ctrl+V never reach the view.
    Keys.onPressed: e => {
        if (!root._open) return
        if (e.key === Qt.Key_Escape) root.close()
        e.accepted = true
    }

    MouseArea {
        anchors.fill: parent
        enabled: root._open
        acceptedButtons: Qt.AllButtons
        onPressed: root.close()
    }

    Rectangle {
        id: panel
        x: root._x
        y: root._y
        width: 220
        height: col.height + 2 * Theme.spacingSm
        radius: Theme.radiusLg
        color: Theme.surfaceContainer
        border.width: 1
        border.color: Qt.alpha(Theme.foreground, Theme.alphaHairline)
        opacity: root._open ? 1 : 0
        Behavior on opacity {
            NumberAnimation { id: fade; duration: Motion.fast; easing.type: Motion.easeStandard }
        }

        Column {
            id: col
            x: Theme.spacingSm
            y: Theme.spacingSm
            width: parent.width - 2 * Theme.spacingSm
            Repeater {
                model: root.entries
                delegate: Item {
                    id: row
                    required property var modelData
                    readonly property bool sep: modelData.separator === true
                    readonly property bool live: !sep && modelData.enabled !== false
                    width: col.width
                    height: sep ? 9 : 30
                    Rectangle {
                        visible: row.sep
                        anchors.centerIn: parent
                        width: parent.width - 16
                        height: 1
                        color: Qt.alpha(Theme.foreground, Theme.alphaHair)
                    }
                    Rectangle {
                        visible: !row.sep
                        anchors.fill: parent
                        radius: Theme.radiusSm
                        color: Qt.alpha(Theme.foreground, hit.containsMouse && row.live ? Theme.alphaWash : 0)
                    }
                    Text {
                        visible: !row.sep
                        anchors.verticalCenter: parent.verticalCenter
                        x: 10
                        text: row.modelData.label ?? ""
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSizeBody
                        color: Qt.alpha(Theme.foreground, row.live ? 1 : Theme.alphaDisabled)
                    }
                    MouseArea {
                        id: hit
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: row.live
                        onClicked: root.pick(row.modelData.id)
                    }
                }
            }
        }
    }
}
