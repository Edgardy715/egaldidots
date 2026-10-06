import QtQuick
import "../Singletons"

Item {
    id: root
    property bool open: false
    property bool navigating: false
    property int selectedIndex: 0
    property string pendingPath: ""
    property string feedback: ""
    property color accentFallback: "white"
    readonly property var wallpaperModel: wpModel
    readonly property bool applying: Wallpapers.applying
    readonly property bool scanning: Wallpapers.scanning
    readonly property string applyError: Wallpapers.applyError
    readonly property var sel: wpModel.count > 0 ? wpModel.get(Math.max(0, Math.min(selectedIndex, wpModel.count - 1))) : null
    readonly property color previewAccent: Wallpapers.accentFor(sel ? sel.path : "", accentFallback)
    signal selectionRequested(int index)
    signal applied()
    onSelectedIndexChanged: requestVisibleThumbs()
    onOpenChanged: if (open) { feedback = ""; syncCurrentIndex() }
    function selectIndex(index) {
        if (wpModel.count === 0 || Wallpapers.applying) return
        selectionRequested(((index % wpModel.count) + wpModel.count) % wpModel.count)
    }
    function syncCurrentIndex() {
        if (wpModel.count === 0 || navigating) return
        if (Wallpapers.current !== "") {
            for (var i = 0; i < wpModel.count; i++) if (wpModel.get(i).path === Wallpapers.current) {
                selectionRequested(i)
                return
            }
        }
        selectionRequested(0)
    }
    function requestVisibleThumbs() {
        if (wpModel.count === 0) return
        for (var offset = -3; offset <= 3; offset++) {
            var i = ((selectedIndex + offset) % wpModel.count + wpModel.count) % wpModel.count
            var it = wpModel.get(i)
            if (it && !it.thumbReady && !it.thumbFailed) Wallpapers.requestThumbnail(it.path, it.thumb)
        }
    }
    function requestThumbnail(path, thumb) { Wallpapers.requestThumbnail(path, thumb) }
    function refresh() { Wallpapers.forceRefresh() }
    function commitIndex(index) {
        if (wpModel.count === 0 || Wallpapers.applying || feedback === "done") return
        var item = wpModel.get(index)
        if (!item) return
        pendingPath = item.path
        feedback = Wallpapers.setWallpaper(item.path) ? "applying" : "error"
    }
    function applyPath(path) {
        if (!path) return
        for (var i = 0; i < wpModel.count; i++) if (wpModel.get(i).path === path) {
            selectIndex(i)
            commitIndex(i)
            return
        }
        commitIndex(selectedIndex)
    }
    Component.onCompleted: {
        if (Wallpapers.count > 0) {
            wpModel.sync()
            syncCurrentIndex()
            requestVisibleThumbs()
        } else if (!Wallpapers.scanning) Wallpapers.forceRefresh()
    }
    ListModel {
        id: wpModel

        function sync() {
            var src = Wallpapers.list;
            var same = src.length === wpModel.count;
            if (same) {
                for (var i = 0; i < src.length; i++) if (wpModel.get(i).path !== src[i].path) {
                    same = false;
                    break;
                }
            }
            if (same) {
                for (var i = 0; i < src.length; i++) {
                    var w = src[i];
                    wpModel.set(i, {
                        "path": w.path,
                        "baseName": w.baseName,
                        "thumb": w.thumb,
                        "thumbReady": w.thumbReady === true,
                        "thumbSource": w.thumbReady ? ("file://" + encodeURI(w.thumb)) : "",
                        "cacheRevision": w.cacheRevision || 0,
                        "shimmer": !w.thumbReady,
                        "thumbFailed": false,
                        "applied": w.path === Wallpapers.current
                    });
                }
            } else {
                wpModel.clear();
                for (var i = 0; i < src.length; i++) {
                    var w = src[i];
                    wpModel.append({
                        "path": w.path,
                        "baseName": w.baseName,
                        "thumb": w.thumb,
                        "thumbReady": w.thumbReady === true,
                        "thumbSource": w.thumbReady ? ("file://" + encodeURI(w.thumb)) : "",
                        "cacheRevision": w.cacheRevision || 0,
                        "shimmer": !w.thumbReady,
                        "thumbFailed": false,
                        "applied": w.path === Wallpapers.current
                    });
                }
            }
        }

    }

    Connections {
        function onListChanged() {
            wpModel.sync();
            if (!navigating) {
                root.syncCurrentIndex();
                root.requestVisibleThumbs();
            }
        }

        function onCurrentChanged() {
            if (!navigating)
                root.syncCurrentIndex();

            wpModel.sync();
        }

        function onApplyFinished(path, success) {
            if (path !== root.pendingPath)
                return ;

            root.feedback = success ? "done" : "error";
            if (success) {
                root.applied()
            }
        }

        function onThumbUpdated(path, thumbSource, cacheRevision) {
            for (var i = 0; i < wpModel.count; i++) {
                if (wpModel.get(i).path === path) {
                    wpModel.setProperty(i, "thumbSource", thumbSource);
                    wpModel.setProperty(i, "cacheRevision", cacheRevision);
                    wpModel.setProperty(i, "thumbReady", true);
                    wpModel.setProperty(i, "shimmer", false);
                    wpModel.setProperty(i, "thumbFailed", false);
                    break;
                }
            }
        }

        function onThumbFailed(path) {
            for (var i = 0; i < wpModel.count; i++) if (wpModel.get(i).path === path) {
                wpModel.setProperty(i, "thumbFailed", true);
                break;
            }
        }

        target: Wallpapers
    }

}
