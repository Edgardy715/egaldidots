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
    readonly property real contentHeightHint: controls.contentHeight + (mTop + mBottom) * s

    QuickControlsAdapter {
        id: controls
        anchors.fill: parent
        s: root.s
        contentReady: root.contentReady
        onRequestPage: (name) => root.requestPage(name)
    }
}
