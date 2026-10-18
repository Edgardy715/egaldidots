import QtQuick
import "../"
import "../components"
import "../Singletons"

PillSurface {
    id: root
    readonly property bool popupOpen: adapter.popupOpen
    mTop: Theme.marginXl
    mLeft: Theme.marginXl
    mRight: Theme.marginXl
    mBottom: Theme.marginXl
    MixerAdapter {
        id: adapter
        anchors.fill: parent
        s: root.s
        active: root.active
        onRequestClose: root.requestClose()
    }
}
