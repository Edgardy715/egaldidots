import QtQuick
import "../"
import "../Singletons"
import "../components"

PillSurface {
    id: root
    mTop: Theme.marginSm
    mLeft: Theme.marginXl
    mRight: Theme.marginXl
    mBottom: Theme.marginXs
    readonly property color previewAccent: view.previewAccent
    readonly property var sel: view.sel
    readonly property string selName: view.selName
    readonly property bool selApplied: view.selApplied
    function cycle(dir) { view.cycle(dir) }
    function goIndex(num) { view.goIndex(num) }
    function selectIndex(index) { view.selectIndex(index) }
    function commitSelection() { view.commitSelection() }
    function applyPath(path) { controller.applyPath(path) }

    WallpaperController {
        id: controller
        open: root.open
        navigating: view.navigating
        selectedIndex: view.currentIndex
        accentFallback: Theme.accent
        onSelectionRequested: index => view.selectIndex(index)
        onApplied: view.applied()
    }
    WallpaperView {
        id: view
        anchors.fill: parent
        s: root.s
        open: root.open
        closing: root.closing
        wallpaperModel: controller.wallpaperModel
        applying: controller.applying
        scanning: controller.scanning
        applyError: controller.applyError
        feedback: controller.feedback
        previewAccent: controller.previewAccent
        mediaHas: Players.has
        mediaArtUrl: Players.artUrl
        mediaHasProgress: !!(Players.active && Players.active.length > 0)
        mediaProgress: mediaHasProgress ? Math.max(0, Math.min(1, Players.active.position / Players.active.length)) : 0
        mediaTitle: Players.title
        mediaArtist: Players.artist
        onRequestClose: root.requestClose()
        onSelectionChanged: index => { if (index >= 0) controller.selectedIndex = index }
        onCommitRequested: index => controller.commitIndex(index)
        onApplyPathRequested: path => controller.applyPath(path)
        onRefreshRequested: controller.refresh()
        onThumbnailRequested: (path, thumb) => controller.requestThumbnail(path, thumb)
    }
}
