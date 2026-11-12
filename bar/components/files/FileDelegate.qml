import QtQuick
import "../../Singletons"
import "FileKinds.js" as Kinds
import "PathUtil.js" as PathUtil

// One file cell (grid) or row (list). Deliberately minimal: an icon glyph, one lazily
// loaded Image and one or three Text items; no handlers, no effects. Pointer and keyboard
// live in the view. Video thumbnails come from `thumbResolver(path, size, cb)` and are
// requested only while the delegate is on screen.
Item {
    id: root
    objectName: "fileDelegate"

    required property int index
    property var entry: ({})
    property bool compact: false          // list row instead of grid cell
    property real iconSize: 64
    property bool onScreen: true
    property bool pooled: false
    property var thumbResolver: null
    // function (path, size, cb, stamp): withdraws a request made through thumbResolver (optional).
    property var thumbCancel: null
    // False while the window is hidden: a thumbnail then appears without its fade.
    property bool fadeThumbs: true
    signal built()

    readonly property string name: entry.name ?? ""
    readonly property string path: entry.path ?? ""
    readonly property string stamp: String(entry.modified ?? "")
    readonly property string _key: path + "|" + stamp
    readonly property bool isDir: entry.isDir === true
    readonly property string kind: Kinds.kindOf(name, isDir)
    readonly property int thumbStatus: thumb.status
    readonly property real thumbOpacity: thumb.opacity
    property string videoThumb: ""
    property string _videoFor: ""
    property int thumbEpoch: 0     // bumped by the view when its resolver or folder changes
    onThumbEpochChanged: { _cancelVideo(); _videoFor = ""; _requestVideo() }
    readonly property bool live: onScreen && !pooled && path.length > 0
    readonly property string thumbSource: !live ? ""
        : kind === "image" ? (entry.url || PathUtil.toUrl(path))
        : kind === "video" ? videoThumb : ""

    // The request in flight, so it can be withdrawn when the delegate is recycled or destroyed.
    property var _pending: null
    function _cancelVideo() {
        const p = _pending
        _pending = null
        if (p && thumbCancel) thumbCancel(p.path, p.size, p.cb, p.stamp)
    }
    function _requestVideo() {
        if (!live || kind !== "video" || !thumbResolver) return
        if (_videoFor === _key) return
        _cancelVideo()
        const requested = _key
        _videoFor = requested
        videoThumb = ""
        const size = Math.round(iconSize * 2), at = path, mod = stamp
        const cb = (thumbPath, ok) => {
            if (root && root._pending && root._pending.cb === cb) root._pending = null
            if (ok && root && root._videoFor === requested && thumbPath) root.videoThumb = PathUtil.toUrl(thumbPath)
        }
        _pending = { path: at, size: size, cb: cb, stamp: mod }
        // 4th argument (modified stamp) is only used by the view's memo, not by the resolver.
        thumbResolver(at, size, cb, mod)
    }
    onLiveChanged: { if (!live && _pending) { _cancelVideo(); _videoFor = "" } _requestVideo() }
    on_KeyChanged: { if (_videoFor !== _key) { _cancelVideo(); videoThumb = ""; _videoFor = "" } _requestVideo() }
    onKindChanged: _requestVideo()
    Component.onCompleted: { _requestVideo(); built() }
    Component.onDestruction: _cancelVideo()

    Item {
        id: box
        width: root.iconSize
        height: root.iconSize
        x: root.compact ? 10 : (root.width - width) / 2
        y: root.compact ? (root.height - height) / 2 : 6
        Text {
            anchors.centerIn: parent
            // Cross-fades with the thumbnail: no second animation, it follows thumb.opacity.
            visible: thumb.opacity < 1
            opacity: 1 - thumb.opacity
            text: Kinds.iconOf(root.kind)
            font.family: "Material Symbols Rounded"
            font.pixelSize: Math.round(root.iconSize * 0.72)
            color: root.isDir ? Theme.accent : Qt.alpha(Theme.foreground, Theme.alphaIconSec)
        }
        Image {
            id: thumb
            anchors.fill: parent
            source: root.thumbSource
            asynchronous: true
            cache: true
            sourceSize: Qt.size(root.iconSize * 2, root.iconSize * 2)
            fillMode: Image.PreserveAspectFit
            opacity: 0
            // Fade only after a real asynchronous load (status went through Loading). A cache hit on a
            // recycled delegate reaches Ready directly and shows at once, so scrolling never re-fades.
            property bool _loaded: false
            onStatusChanged: {
                if (status === Image.Loading) { _loaded = true; thumbFade.stop(); opacity = 0 }
                else if (status === Image.Ready) {
                    if (_loaded && root.fadeThumbs && root.live) thumbFade.restart()
                    else { thumbFade.stop(); opacity = 1 }
                    _loaded = false
                } else { _loaded = false; thumbFade.stop(); opacity = 0 }
            }
            NumberAnimation { id: thumbFade; target: thumb; property: "opacity"; from: 0; to: 1; duration: Motion.fast; easing.type: Easing.OutCubic }
        }
    }

    Text {
        id: label
        text: root.name
        textFormat: Text.PlainText
        color: Theme.foreground
        font.family: Theme.font
        font.pixelSize: Theme.fontSizeSmall
        elide: Text.ElideMiddle
        wrapMode: root.compact ? Text.NoWrap : Text.Wrap
        maximumLineCount: root.compact ? 1 : 2
        horizontalAlignment: root.compact ? Text.AlignLeft : Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        x: root.compact ? box.x + box.width + 12 : 6
        y: root.compact ? (root.height - height) / 2 : box.y + box.height + 6
        width: root.compact ? Math.max(40, root.width - x - (meta.visible ? meta.width + 24 : 12)) : root.width - 12
    }
    Text {
        id: meta
        visible: root.compact && root.width > 420 && root.path.length > 0
        text: root.isDir ? "" : Kinds.formatSize(root.entry.size)
        textFormat: Text.PlainText
        color: Qt.alpha(Theme.foreground, Theme.alphaIconSec)
        font.family: Theme.font
        font.pixelSize: Theme.fontSizeSmall
        horizontalAlignment: Text.AlignRight
        width: 72
        x: root.width - width - 12
        y: (root.height - height) / 2
    }
}
