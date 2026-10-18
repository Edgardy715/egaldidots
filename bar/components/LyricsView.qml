pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../"
import "../Singletons"
import "LyricsData.js" as LyricsData

ColumnLayout {
    id: root
    property color musicAccent: Theme.accent
    property real s: 1
    property string title: ""
    property string artist: ""
    property string status: "idle"
    property bool synced: false
    property var lines: []
    property real position: 0
    property bool following: true
    // Browsing is temporary: reopening or a quiet interval resumes the sung line.
    function browse() { following = false; followResume.restart() }
    Timer {
        id: followResume
        objectName: "lyricsFollowResume"
        interval: 3200
        onTriggered: {
            if (!root.visible) return
            if (lyrics.moving || lyrics.dragging) restart()
            else root.following = true
        }
    }
    property bool canSeek: false
    property bool motionEnabled: true
    readonly property bool motionAllowed: visible && motionEnabled && Flags.mediaTransitions && !Flags.reduceMotion
    signal seekRequested(real position)
    readonly property int lineIndex: synced ? LyricsData.indexAt(lines, position) : -1
    signal retryRequested()
    signal closeRequested()
    spacing: 8 * s
    onLinesChanged: { following = true; Qt.callLater(lyrics.reset) }
    onStatusChanged: if (status === "ready") Qt.callLater(lyrics.follow, false)
    onLineIndexChanged: Qt.callLater(lyrics.follow, true)
    onFollowingChanged: if (following) { followResume.stop(); Qt.callLater(lyrics.follow, true) }
    onVisibleChanged: {
        if (visible) { following = true; lyrics.forceActiveFocus(); Qt.callLater(lyrics.follow, false) }
        else followResume.stop()
    }
    Keys.onEscapePressed: root.closeRequested()

    RowLayout {
        Layout.fillWidth: true
        spacing: 12 * root.s
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 3 * root.s
            Text {
                Layout.fillWidth: true
                text: root.title
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.family: Theme.fontMedia
                font.pixelSize: 16 * Flags.fontScale * root.s
                font.weight: Font.DemiBold
                color: Theme.foreground
            }
            Text {
                Layout.fillWidth: true
                objectName: "mediaLyricsStatus"
                text: root.status === "ready" && root.synced ? qsTr("Letra sincronizada · LRCLIB") : qsTr("Letras · LRCLIB")
                color: Theme.iconSecondary
                font.family: Theme.fontMedia
                font.pixelSize: Theme.fontSizeSmall * root.s
                elide: Text.ElideRight
            }
        }
        MediaTransportButton {
            visible: root.synced && root.status === "ready"
            iconName: "my_location"
            accessibleName: qsTr("Seguir la reproducción")
            active: root.following
            size: 32; s: root.s
            onClicked: { root.following = true; lyrics.follow(true) }
        }
        MediaTransportButton { iconName: "close"; accessibleName: qsTr("Volver a la portada"); size: 32; s: root.s; onClicked: root.closeRequested() }
    }
    ListView {
        id: lyrics
        objectName: "mediaLyricsList"
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 0
        visible: root.status === "ready"
        clip: true
        spacing: 12 * root.s
        model: root.lines
        activeFocusOnTab: true
        currentIndex: root.following ? root.lineIndex : -1
        // Move the logical viewport once; each visible line catches up from its current position.
        signal stepped(real delta)
        signal settled()
        function reset() {
            settled()
            positionViewAtBeginning()
            follow(false)
        }
        function follow(animated) {
            if (!root.visible || !root.following || root.status !== "ready" || root.lineIndex < 0) return
            const row = itemAtIndex(root.lineIndex)
            if (!row) { settled(); positionViewAtIndex(root.lineIndex, ListView.Center); return }
            const target = Math.max(originY, Math.min(row.y + row.height / 2 - height / 2,
                                                     originY + Math.max(0, contentHeight - height)))
            const delta = target - contentY
            contentY = target
            if (animated && root.motionAllowed && Math.abs(delta) < height * 0.85) stepped(delta)
            else settled()
        }
        onHeightChanged: Qt.callLater(follow, false)
        onCountChanged: Qt.callLater(follow, false)
        onDraggingChanged: if (dragging) root.browse()
        onMovementEnded: if (!root.following) followResume.restart()
        Keys.onUpPressed: { root.browse(); contentY = Math.max(0, contentY - 50 * root.s) }
        Keys.onDownPressed: { root.browse(); contentY = Math.min(Math.max(0, contentHeight - height), contentY + 50 * root.s) }
        WheelHandler { onWheel: event => { root.browse(); event.accepted = false } }
        delegate: Item {
            id: line
            required property var modelData
            required property int index
            readonly property bool current: root.synced && index === root.lineIndex
            readonly property color color: label.color
            property real emphasis: current ? 1 : 0
            property real travel: 0
            width: lyrics.width
            height: label.implicitHeight + 20 * root.s
            scale: !root.synced || !root.motionAllowed ? 1 : 0.97 + 0.03 * emphasis
            transformOrigin: Item.Left
            transform: Translate { y: line.travel }
            Accessible.role: root.canSeek && root.synced ? Accessible.Button : Accessible.StaticText
            activeFocusOnTab: (root.canSeek && root.synced) || activeFocus
            Keys.onReturnPressed: seek()
            Keys.onEnterPressed: seek()
            Keys.onSpacePressed: seek()
            Accessible.name: label.text
            Accessible.onPressAction: line.seek()
            function seek() {
                if (!root.canSeek || !root.synced || !isFinite(modelData.time) || modelData.time < 0) return
                root.following = true
                root.seekRequested(modelData.time)
            }
            onVisibleChanged: if (!visible) { settle.stop(); travel = 0 }
            Behavior on emphasis {
                enabled: root.motionAllowed
                NumberAnimation { id: emphasisMotion; duration: Motion.standard; easing.type: Motion.easeStandard }
            }
            Connections {
                target: lyrics
                function onSettled() { settle.stop(); line.travel = 0 }
                function onStepped(delta) {
                    settle.stop()
                    line.travel += delta
                    settle.start()
                }
            }
            Connections {
                target: root
                function onMotionAllowedChanged() {
                    if (!root.motionAllowed) { settle.stop(); line.travel = 0; emphasisMotion.complete() }
                }
                function onFollowingChanged() {
                    if (!root.following) { settle.stop(); line.travel = 0 }
                }
            }
            SequentialAnimation {
                id: settle
                PauseAnimation { duration: Math.min(5, Math.abs(line.index - root.lineIndex)) * 16 * Motion.mult }
                NumberAnimation { target: line; property: "travel"; to: 0; duration: Motion.standardLarge; easing.type: Motion.easeStandard }
            }
            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusMd * root.s
                color: Qt.alpha(root.musicAccent, 0.09 * line.emphasis)
                border.width: line.activeFocus ? Theme.borderHairline : 0
                border.color: Theme.accent
            }
            Text {
                id: label
                objectName: "lyricGlowLabel"
                layer.enabled: root.visible && root.status === "ready" && root.synced && line.emphasis > 0.01
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: root.musicAccent
                    shadowOpacity: 0.9 * line.emphasis
                    shadowBlur: 0.8
                    blurMax: 16
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                }
                width: parent.width
                y: 10 * root.s
                leftPadding: 12 * root.s
                rightPadding: 12 * root.s
                text: line.modelData.text
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                font.family: Theme.fontMedia
                font.pixelSize: 22 * Flags.fontScale * root.s
                font.weight: Font.DemiBold
                color: line.current || !root.synced ? Theme.foreground : Theme.iconSecondary
                Behavior on color { enabled: root.motionAllowed; ColorAnimation { duration: Motion.standard } }
                Accessible.ignored: true
            }
            MouseArea {
                anchors.fill: parent
                enabled: root.canSeek && root.synced
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: line.seek()
            }
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.status !== "ready"
        spacing: 10 * root.s
        Item { Layout.fillHeight: true }
        Text {
            Layout.fillWidth: true
            text: root.status === "loading" ? qsTr("Buscando letras…")
                : root.status === "instrumental" ? qsTr("Esta pista es instrumental.")
                : root.status === "error" ? qsTr("No se pudieron cargar las letras. Vuelve a intentarlo en un momento.")
                : root.status === "metadata" ? qsTr("Falta el título o el artista de la canción.")
                : qsTr("No hay letras disponibles para esta canción.")
            font.family: Theme.fontMedia
            font.pixelSize: Theme.fontSizeBodyLg * root.s
            color: Theme.iconSecondary
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }
        MediaTransportButton { Layout.alignment: Qt.AlignHCenter; visible: root.status === "error" || root.status === "empty"; iconName: "refresh"; accessibleName: qsTr("Reintentar letras"); s: root.s; onClicked: root.retryRequested() }
        Item { Layout.fillHeight: true }
    }
}
