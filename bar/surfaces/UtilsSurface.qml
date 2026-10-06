import QtQuick
import "../"
import "../components"
import "../Singletons"

PillSurface {
    id: root
    signal requestPage(string name)

    mTop: Theme.marginLg
    mLeft: Theme.marginLg
    mRight: Theme.marginLg
    mBottom: Theme.marginMd
    clip: true

    QuickControlsAdapter {
        anchors.fill: parent
        s: root.s
        contentReady: root.contentReady
        onRequestPage: (name) => root.requestPage(name)
    }
}
