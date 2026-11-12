import QtQuick
import Quickshell.Io
import "../../Singletons"
import ".."
import "FileKinds.js" as Kinds
import "PathUtil.js" as PathUtil

// Quick preview (Space). The card grows from `originRect` (the item's rect in this component's
// parent coordinates) with Motion.surfaceSpring and returns to it on close; with reduceMotion it
// only fades. Leaf component: it reads no service. Images load asynchronously with a bounded
// sourceSize; text reads at most 64 KiB through `head -c` (the path is an argv element, never
// shell text) and only for a regular file, so a FIFO or a huge file cannot block or flood the UI.
// Nothing runs while closed: no spring, no process, no image source.
FocusScope {
    id: root

    property string path: ""
    property bool isDir: false
    property real fileSize: 0
    property rect originRect: Qt.rect(0, 0, 0, 0)
    property bool open: false
    // False while the window is hidden: the spring snaps and the preview closes without animating.
    property bool hostActive: true
    signal closed()
    signal step(int delta)

    readonly property int textLimit: 65536
    readonly property string fileName: path.slice(path.lastIndexOf("/") + 1)
    readonly property string kind: Kinds.kindOf(fileName, isDir)
    readonly property bool wantsText: kind === "text" || kind === "code"
    readonly property bool wantsImage: kind === "image"
    // "none" | "loading" | "ready" | "binary": state of the text preview.
    property string textState: "none"
    property string textContent: ""
    readonly property bool truncated: wantsText && fileSize > textLimit
    // Observable animation state (tests): 0 = at originRect, 1 = fully open.
    readonly property real progress: grow.value
    readonly property bool animating: grow.integrating || fade.running
    readonly property bool shown: open || grow.value > 0.001 || grow.integrating || fadeValue > 0.001
    // reduceMotion replaces the growth by this short fade.
    property real fadeValue: open ? 1 : 0

    visible: shown
    z: 70

    function toggle() { if (open) close(false); else open = true }
    // Asks to close; the owner restores focus from `closed`. `instant` skips the animation.
    function close(instant) {
        if (!open) return
        open = false
        if (instant === true) { grow.snap(0); fadeValue = 0; fade.stop() }
        closed()
    }
    onHostActiveChanged: if (!hostActive) close(true)

    onOpenChanged: {
        if (open) { forceActiveFocus(); _load() }
        else _stopReader()
        // Only reduceMotion fades; otherwise fadeValue follows `open` instantly and the spring drives the opacity.
        if (Flags.reduceMotion && hostActive) { fade.to = open ? 1 : 0; fade.restart() }
        else { fade.stop(); fadeValue = open ? 1 : 0 }
    }
    onPathChanged: if (open) _load()
    onWantsTextChanged: if (open) _load()

    // ---- text reader --------------------------------------------------------
    property var _reader: null
    property int _token: 0
    function _stopReader() {
        _token++
        if (_reader) { _reader.running = false; _reader.destroy(); _reader = null }
    }
    function _load() {
        _stopReader()
        textContent = ""
        if (!wantsText || path.length === 0) { textState = "none"; return }
        textState = "loading"
        const token = _token
        _reader = readerComponent.createObject(root, {
            token: token,
            command: ["sh", "-c", '[ -f "$1" ] && exec head -c ' + root.textLimit + ' -- "$1"', "sh", path]
        })
        if (_reader) _reader.running = true
    }
    function _textDone(token, text) {
        if (token !== _token) return
        if (text.length === 0 || text.indexOf("\u0000") >= 0) { textState = "binary"; return }
        textContent = text
        textState = "ready"
    }
    Component {
        id: readerComponent
        Process {
            id: proc
            property int token: 0
            stdout: StdioCollector { onStreamFinished: root._textDone(proc.token, text) }
        }
    }

    // ---- motion --------------------------------------------------------------
    SpringValue {
        id: grow
        spring: root.open ? Motion.quickLookSpring.open : Motion.quickLookSpring.close
        active: root.hostActive
        target: root.open ? 1 : 0
    }
    NumberAnimation {
        id: fade
        target: root
        property: "fadeValue"
        to: root.open ? 1 : 0
        duration: Motion.fast   // reduceMotion only: a short fade, never longer than Motion.fast
        easing.type: Easing.OutCubic
        running: false
    }

    readonly property real p: Flags.reduceMotion ? 1 : grow.value
    readonly property real cardOpacity: Flags.reduceMotion ? fadeValue : Math.max(0, Math.min(1, grow.value * 3))
    readonly property real contentOpacity: Flags.reduceMotion ? 1 : Math.max(0, Math.min(1, (grow.value - 0.35) / 0.45))

    // ---- visuals -------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha("black", Math.max(0, 0.35 * root.cardOpacity))
        MouseArea { anchors.fill: parent; onClicked: root.close(false) }
    }

    Item {
        id: card
        objectName: "quickLookCard"
        readonly property real fw: Math.max(220, Math.min(root.width - 48, 760))
        readonly property real fh: Math.max(180, Math.min(root.height - 48, 560))
        readonly property bool hasOrigin: root.originRect.width > 0 && root.originRect.height > 0
        readonly property real s0: hasOrigin ? Math.max(0.05, Math.min(1, root.originRect.width / fw)) : 0.6
        readonly property real cx0: hasOrigin ? root.originRect.x + root.originRect.width / 2 : root.width / 2
        readonly property real cy0: hasOrigin ? root.originRect.y + root.originRect.height / 2 : root.height / 2
        width: fw
        height: fh
        x: cx0 + (root.width / 2 - cx0) * root.p - fw / 2
        y: cy0 + (root.height / 2 - cy0) * root.p - fh / 2
        scale: s0 + (1 - s0) * root.p
        opacity: root.cardOpacity
        transformOrigin: Item.Center

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusXxl
            color: Theme.surfaceContainer
            border.width: 1
            border.color: Qt.alpha(Theme.foreground, Theme.alphaHairline)
            MouseArea { anchors.fill: parent }   // clicks inside never reach the dimmer
        }

        Item {
            anchors.fill: parent
            anchors.margins: Theme.spacingXl
            opacity: root.contentOpacity

            Text {
                id: title
                width: parent.width
                height: 24
                elide: Text.ElideMiddle
                textFormat: Text.PlainText
                verticalAlignment: Text.AlignVCenter
                text: root.fileName + (root.isDir || root.fileSize <= 0 ? "" : "  ·  " + Kinds.formatSize(root.fileSize))
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeTitle
                color: Theme.foreground
            }
            Item {
                id: body
                y: title.height + Theme.spacingMd
                width: parent.width
                height: parent.height - y - hint.height - Theme.spacingMd
                clip: true

                Image {
                    id: picture
                    objectName: "quickLookImage"
                    anchors.fill: parent
                    visible: root.wantsImage
                    source: root.shown && root.wantsImage && root.path.length ? PathUtil.toUrl(root.path) : ""
                    asynchronous: true
                    cache: false
                    // Decoded at most to this box (aspect preserved, never upscaled).
                    sourceSize: Qt.size(1600, 1200)
                    fillMode: Image.PreserveAspectFit
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { enabled: root.open; NumberAnimation { duration: Motion.fast } }
                }
                Flickable {
                    id: scroller
                    anchors.fill: parent
                    visible: root.wantsText && root.textState === "ready"
                    contentWidth: width
                    contentHeight: textBody.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    Text {
                        id: textBody
                        objectName: "quickLookText"
                        width: scroller.width
                        text: root.textContent
                        textFormat: Text.PlainText
                        wrapMode: Text.WrapAnywhere
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.foreground
                    }
                }
                // Folders, other kinds, binary files and unreadable text: a large glyph.
                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingMd
                    visible: !(root.wantsImage && picture.status === Image.Ready) && !scroller.visible
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Kinds.iconOf(root.kind)
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 96
                        color: root.isDir ? Theme.accent : Qt.alpha(Theme.foreground, Theme.alphaIconSec)
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: root.textState === "loading"
                        text: I18n.tr("Cargando…")
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSizeSmall
                        color: Qt.alpha(Theme.foreground, Theme.alphaDisabled)
                    }
                }
            }
            Text {
                id: hint
                anchors.bottom: parent.bottom
                width: parent.width
                height: 18
                elide: Text.ElideRight
                text: (root.truncated ? I18n.tr("Se muestran los primeros 64 KiB") + "  ·  " : "")
                    + I18n.tr("Espacio o Esc para cerrar  ·  ← → para cambiar")
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeSmall
                color: Qt.alpha(Theme.foreground, Theme.alphaDisabled)
            }
        }
    }

    Keys.onPressed: e => {
        if (!root.open) { e.accepted = false; return }
        if (e.modifiers & (Qt.ControlModifier | Qt.AltModifier)) { e.accepted = false; return }
        e.accepted = true
        if (e.key === Qt.Key_Space || e.key === Qt.Key_Escape) root.close(false)
        else if (e.key === Qt.Key_Left || e.key === Qt.Key_Up) root.step(-1)
        else if (e.key === Qt.Key_Right || e.key === Qt.Key_Down) root.step(1)
    }
}
