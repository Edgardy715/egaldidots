import QtQuick
import "../"
import "../Singletons"
import "../components"

PillSurface {
    id: root
    mTop: Theme.marginLg; mLeft: Theme.marginLg; mRight: Theme.marginLg; mBottom: Theme.marginMd
    clip: true
    readonly property alias activeSsid: adapter.activeSsid

    ConnectivityAdapter {
        id: adapter
        anchors.fill: parent
        s: root.s
        open: root.open
    }
}
