import QtQuick
import "../"
import "../Singletons"
import "../components"

// Island surface for the shortcut explorer (SUPER+K). Editing hands off to the
// Crucible manager through HyprlandBinds.focusId.
PillSurface {
    id: root
    mTop: Theme.marginMd; mLeft: Theme.marginMd; mRight: Theme.marginMd; mBottom: Theme.marginMd
    signal requestPage(string name)
    property alias explorer: view

    ShortcutExplorer {
        id: view
        anchors.fill: parent
        s: root.s
        binds: HyprlandBinds
        open: root.open
        closing: root.closing
        onRequestClose: root.requestClose()
        onEditRequested: id => { HyprlandBinds.focusId = id; root.requestPage("settings") }
    }
}
