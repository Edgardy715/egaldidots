import QtQuick
import "../../Singletons"

// Icon grid over a file model. ~120 delegates cover a screen; delegates are pooled
// (reuseItems) with a one-screen-ish cacheBuffer, so 20 000 entries stay cheap.
FilesViewBase {
    id: root

    columns: Math.max(1, Math.floor(width / (iconSize + 32)))
    cellW: Math.floor(width / columns)
    cellH: Math.round(iconSize + 12 + Theme.fontSizeSmall * 2.8 + 8)
    flick: grid

    GridView {
        id: grid
        anchors.fill: parent
        clip: true
        model: root.model ? root.model.model : null
        cellWidth: root.cellW
        cellHeight: root.cellH
        reuseItems: true
        // The view must not keep a delegate alive for its own current item (the selection owns "current").
        currentIndex: -1
        onCurrentIndexChanged: if (currentIndex !== -1) currentIndex = -1
        cacheBuffer: Math.round(root.cellH * 2)
        boundsBehavior: Flickable.StopAtBounds
        delegate: FileDelegate {
            width: root.cellW
            height: root.cellH
            iconSize: root.iconSize
            entry: root._entry(index, root._rev)
            thumbResolver: root.resolveThumb
            thumbCancel: root.cancelThumb
            thumbEpoch: root.thumbEpoch
            fadeThumbs: root.animate
            onScreen: !pooled && y + height > grid.contentY && y < grid.contentY + grid.height
            visible: !pooled
            GridView.onPooled: pooled = true
            GridView.onReused: pooled = false
            onBuilt: root.createdCount++
        }
    }
}
