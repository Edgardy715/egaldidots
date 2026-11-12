import QtQuick
import "../../Singletons"

// Row list over a file model (grid with one column). Same pooling rules as FileGrid.
FilesViewBase {
    id: root

    columns: 1
    cellW: width
    cellH: Math.round(iconSize + 14)
    flick: list

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        model: root.model ? root.model.model : null
        reuseItems: true
        // The view must not keep a delegate alive for its own current item (the selection owns "current").
        currentIndex: -1
        onCurrentIndexChanged: if (currentIndex !== -1) currentIndex = -1
        cacheBuffer: Math.round(root.cellH * 6)
        boundsBehavior: Flickable.StopAtBounds
        delegate: FileDelegate {
            width: list.width
            height: root.cellH
            compact: true
            iconSize: root.iconSize
            entry: root._entry(index, root._rev)
            thumbResolver: root.resolveThumb
            thumbCancel: root.cancelThumb
            thumbEpoch: root.thumbEpoch
            fadeThumbs: root.animate
            onScreen: !pooled && y + height > list.contentY && y < list.contentY + list.height
            visible: !pooled
            ListView.onPooled: pooled = true
            ListView.onReused: pooled = false
            onBuilt: root.createdCount++
        }
    }
}
