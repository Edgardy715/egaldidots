import QtQuick
import Quickshell
import "../"
import "../Singletons"
import "../components"

PillSurface {
    id: root
    mTop: 24; mLeft: 24; mRight: 24; mBottom: 24

    // Kept injectable for regression fixtures; only this composition invokes it.
    property var actions: Session
    readonly property alias focused: view.focused
    readonly property alias pending: view.pending
    readonly property alias displayedPending: view.displayedPending
    readonly property alias choices: view.choices
    readonly property alias primaryOrder: view.primaryOrder
    readonly property alias navigationOrder: view.navigationOrder

    function select(index) { view.select(index) }
    function activate(index) { view.activate(index) }
    function confirm() { view.confirm() }
    function cancel() { view.cancel() }
    function handleKey(event) { view.handleKey(event) }

    SessionView {
        id: view
        anchors.fill: parent
        s: root.s
        open: root.open
        userName: Config.profile.displayName.trim() || Quickshell.env("USER") || qsTr("Usuario")
        avatarSource: "file://" + Config.userAvatar
        onActionRequested: action => {
            if (root.actions && typeof root.actions[action] === "function") root.actions[action]()
        }
        onCloseRequested: root.requestClose()
    }
}
