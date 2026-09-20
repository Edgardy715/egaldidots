import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Services.Mpris
import "../"
import "../components"
import "../Singletons"

PillSurface {
    id: root

    mTop: Theme.marginMd
    mLeft: Theme.marginMd
    mRight: Theme.marginMd
    mBottom: Theme.marginMd

    readonly property var player: Players.active
    readonly property bool hasPlayer: player !== null
    readonly property bool isPlaying: hasPlayer && player.isPlaying
    readonly property string title: hasPlayer ? (player.trackTitle || qsTr("Sin título")) : qsTr("Sin contenido")
    readonly property string artist: hasPlayer ? (player.trackArtist || qsTr("Artista desconocido")) : ""
    readonly property string album: hasPlayer ? (player.trackAlbum || "") : ""
    readonly property bool albumDistinct: album.length > 0
        && album.toLowerCase() !== title.toLowerCase()
        && album.toLowerCase() !== artist.toLowerCase()
    readonly property bool canSeek: hasPlayer && !!player.canControl && !!player.canSeek
        && !!player.positionSupported && !!player.lengthSupported
        && isFinite(player.length) && player.length > 0
    readonly property bool canShuffle: hasPlayer && !!player.canControl && !!player.shuffleSupported
    readonly property bool canRepeat: hasPlayer && !!player.canControl && !!player.loopSupported
    readonly property bool canPrevious: hasPlayer && !!player.canControl && !!player.canGoPrevious
    readonly property bool canNext: hasPlayer && !!player.canControl && !!player.canGoNext
    readonly property bool canToggle: hasPlayer && !!player.canControl && !!player.canTogglePlaying

    property real position: hasPlayer ? Math.max(0, player.position || 0) : 0
    property real lastPositionAt: 0
    property bool dragging: false
    property real dragFraction: 0
    readonly property real progress: canSeek
        ? Math.max(0, Math.min(1, (dragging ? dragFraction * player.length : position) / player.length))
        : 0
    readonly property string consumerId: "media:" + (root.screenName || "default")

    readonly property var loopNone: MprisLoopState.None
    readonly property var loopTrack: MprisLoopState.Track
    readonly property bool repeatOne: canRepeat && player.loopState === loopTrack

    function syncPosition() {
        if (!dragging && player) {
            position = Math.max(0, player.position || 0)
            lastPositionAt = Date.now()
        }
    }

    function syncCava() { Cava.setConsumer(root.consumerId, root.open && root.isPlaying) }
    function invoke(method) { if (player && typeof player[method] === "function") player[method]() }

    function seekTo(value) {
        if (!canSeek) return
        const next = Math.max(0, Math.min(player.length, value))
        position = next
        lastPositionAt = Date.now()
        player.position = next
    }

    function toggleShuffle() { if (canShuffle) player.shuffle = !player.shuffle }

    function cycleRepeat() {
        if (!canRepeat) return
        const next = player.loopState === loopNone
            ? loopTrack
            : player.loopState === loopTrack ? MprisLoopState.Playlist : loopNone
        player.loopState = next
    }

    function formatTime(value) {
        if (!isFinite(value) || value < 0) return "—:—"
        const total = Math.floor(value)
        return Math.floor(total / 60) + ":" + String(total % 60).padStart(2, "0")
    }

    Component.onCompleted: { syncPosition(); syncCava() }
    Component.onDestruction: Cava.setConsumer(root.consumerId, false)
    onOpenChanged: syncCava()
    onIsPlayingChanged: syncCava()
    onScreenNameChanged: syncCava()
    onPlayerChanged: { dragging = false; dragFraction = 0; syncPosition(); syncCava() }

    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onPositionChanged() { root.syncPosition() }
        function onIsPlayingChanged() { root.syncCava() }
    }
    Connections {
        target: Players
        function onTrackKeyChanged() { root.dragging = false; root.dragFraction = 0; root.syncPosition() }
    }

    Timer {
        interval: 60
        repeat: true
        running: root.open && root.canSeek && root.isPlaying && !root.dragging
        onTriggered: {
            if (!root.player) return
            const now = Date.now()
            const elapsed = root.lastPositionAt > 0 ? (now - root.lastPositionAt) / 1000 : 0
            root.lastPositionAt = now
            const rate = isFinite(root.player.rate) && root.player.rate > 0 ? root.player.rate : 1
            if (elapsed > 0 && elapsed < 2)
                root.position = Math.min(root.player.length, root.position + elapsed * rate)
        }
    }

    Item {
        anchors.fill: parent
        visible: !root.hasPlayer
        opacity: visible ? 1 : 0
        Behavior on opacity { Anim { type: Anim.DefaultEffects } }
        ColumnLayout {
            anchors.centerIn: parent
            spacing: Theme.spacingMd * root.s
            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                iconName: "music_off"
                color: Theme.iconSecondary
                font.pixelSize: Theme.fontSizeCover * root.s
                Accessible.ignored: true
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Ningún medio disponible")
                color: Theme.iconSecondary
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeBodyLg * root.s
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: Theme.spacingXxl * root.s
        visible: root.hasPlayer
        opacity: visible ? 1 : 0
        Behavior on opacity { Anim { type: Anim.DefaultEffects } }

        Item {
            id: artworkColumn
            Layout.preferredWidth: Math.min(208 * root.s, parent.height)
            Layout.preferredHeight: Layout.preferredWidth
            Layout.alignment: Qt.AlignVCenter

            Image {
                id: artSource
                anchors.fill: parent
                source: Players.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize: Qt.size(416 * root.s, 416 * root.s)
                visible: false
            }
            Rectangle {
                id: artMask
                anchors.fill: parent
                radius: Theme.radiusXxl * root.s
                color: "white"
                visible: false
            }
            OpacityMask {
                anchors.fill: parent
                source: artSource
                maskSource: artMask
                opacity: artSource.status === Image.Ready ? 1 : 0
                Behavior on opacity { Anim { type: Anim.DefaultEffects } }
            }
            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusXxl * root.s
                color: Qt.alpha(Theme.accent, Theme.alphaSubtle)
                visible: artSource.status !== Image.Ready
                Behavior on color { ColorAnimation { duration: Motion.standard } }
                MaterialIcon {
                    anchors.centerIn: parent
                    iconName: "music_note"
                    color: Theme.iconSecondary
                    font.pixelSize: Theme.fontSizeCover * root.s
                    Accessible.ignored: true
                }
            }
            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusXxl * root.s
                color: "transparent"
                border.color: Theme.border
                border.width: Theme.borderHairline * root.s
            }
        }

        ColumnLayout {
            id: content
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Theme.spacingMd * root.s

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSm * root.s
                Rectangle {
                    Layout.preferredWidth: statusText.implicitWidth + 20 * root.s
                    Layout.preferredHeight: 24 * root.s
                    radius: height / 2
                    color: Qt.alpha(root.isPlaying ? Theme.accent : Theme.foreground,
                                    root.isPlaying ? Theme.alphaChip : Theme.alphaSoft)
                    border.color: Qt.alpha(root.isPlaying ? Theme.accent : Theme.foreground,
                                           root.isPlaying ? Theme.alphaStrong : Theme.alphaHairline)
                    border.width: Theme.borderHairline * root.s
                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.spacingXs * root.s
                        MaterialIcon {
                            iconName: root.isPlaying ? "graphic_eq" : "pause_circle"
                            color: root.isPlaying ? Theme.accent : Theme.iconSecondary
                            font.pixelSize: Theme.fontSizeLabel * root.s
                        }
                        Text {
                            id: statusText
                            text: root.isPlaying ? qsTr("EN REPRODUCCIÓN") : qsTr("EN PAUSA")
                            color: root.isPlaying ? Theme.accent : Theme.iconSecondary
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSizeCaption * root.s
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.6 * root.s
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: Players.serviceLabel || ""
                    color: Theme.iconMuted
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeSmall * root.s
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignRight
                }
                Row {
                    visible: Players.list.length > 1
                    spacing: 0
                    CtrlBtn { iconName: "chevron_left"; accessibleName: qsTr("Reproductor anterior"); size: 28; s: root.s; onClicked: Players.cycleManual(-1) }
                    CtrlBtn { iconName: "chevron_right"; accessibleName: qsTr("Siguiente reproductor"); size: 28; s: root.s; onClicked: Players.cycleManual(1) }
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Theme.iconPrimary
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeDisplay * root.s
                font.weight: Font.Medium
                font.letterSpacing: -0.15 * root.s
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: root.artist
                color: Theme.iconSecondary
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeBodyLg * root.s
                font.letterSpacing: 0.05 * root.s
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: root.albumDistinct
                text: root.album
                color: Theme.iconMuted
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeSmall * root.s
                elide: Text.ElideRight
            }

            Item {
                id: cavaView
                Layout.fillWidth: true
                Layout.preferredHeight: 46 * root.s
                readonly property int count: Math.max(12, Math.min(48, Math.floor(width / (8 * root.s))))
                readonly property real gap: 3 * root.s
                readonly property real barWidth: Math.max(2 * root.s, (width - (count - 1) * gap) / count)
                Repeater {
                    model: cavaView.count
                    delegate: Rectangle {
                        required property int index
                        readonly property real signal: root.isPlaying && Cava.available && Cava.values.length > 0
                            ? Cava.values[Math.min(Cava.values.length - 1,
                              Math.floor(index * Cava.values.length / cavaView.count))] || 0 : 0
                        width: cavaView.barWidth
                        height: Math.max(2 * root.s, (8 * root.s) + signal * 34 * root.s)
                        x: index * (cavaView.barWidth + cavaView.gap)
                        y: cavaView.height - height
                        radius: width / 2
                        color: Qt.alpha(Theme.accent, Theme.alphaEmphasis + signal * 0.55)
                        Behavior on height { Anim { type: Anim.FastEffects } }
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                    }
                }
            }

            Item {
                id: seekBar
                Layout.fillWidth: true
                Layout.preferredHeight: 28 * root.s
                visible: root.canSeek
                readonly property real trackInset: 2 * root.s
                readonly property real trackWidth: width - 4 * root.s
                function fractionAt(x) { return Math.max(0, Math.min(1, (x - trackInset) / trackWidth)) }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: seekBar.trackInset
                    width: seekBar.trackWidth
                    height: 4 * root.s
                    radius: height / 2
                    color: Qt.alpha(Theme.foreground, Theme.alphaSubtle)
                    Rectangle {
                        width: parent.width * root.progress
                        height: parent.height
                        radius: parent.radius
                        color: Theme.accent
                        Behavior on width { enabled: !root.dragging; Anim { type: Anim.FastEffects } }
                    }
                }
                Rectangle {
                    x: seekBar.trackInset + seekBar.trackWidth * root.progress - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 9 * root.s
                    height: width
                    radius: width / 2
                    color: Theme.accent
                    scale: seekMouse.containsMouse || root.dragging ? 1.2 : 1
                    Behavior on scale { Anim { type: Anim.FastEffects } }
                }
                MouseArea {
                    id: seekMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.canSeek
                    cursorShape: Qt.PointingHandCursor
                    onPressed: (mouse) => { root.dragging = true; root.dragFraction = seekBar.fractionAt(mouse.x) }
                    onPositionChanged: (mouse) => { if (root.dragging) root.dragFraction = seekBar.fractionAt(mouse.x) }
                    onReleased: (mouse) => { root.dragging = false; root.seekTo(seekBar.fractionAt(mouse.x) * root.player.length) }
                    onCanceled: root.dragging = false
                }
            }
            RowLayout {
                Layout.fillWidth: true
                visible: root.canSeek
                Text {
                    text: root.formatTime(root.dragging ? root.dragFraction * root.player.length : root.position)
                    color: Theme.iconPrimary
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall * root.s
                    font.letterSpacing: 0.2 * root.s
                    Layout.fillWidth: true
                }
                Text {
                    text: root.formatTime(root.player ? root.player.length : 0)
                    color: Theme.iconSecondary
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall * root.s
                    font.letterSpacing: 0.2 * root.s
                    horizontalAlignment: Text.AlignRight
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingLg * root.s
                CtrlBtn { iconName: "shuffle"; accessibleName: qsTr("Aleatorio"); active: root.canShuffle && root.player.shuffle; dim: !root.canShuffle; s: root.s; onClicked: root.toggleShuffle() }
                Item { Layout.fillWidth: true }
                CtrlBtn { iconName: "skip_previous"; accessibleName: qsTr("Anterior"); dim: !root.canPrevious; s: root.s; onClicked: root.invoke("previous") }
                CtrlBtn {
                    iconName: root.isPlaying ? "pause" : "play_arrow"
                    accessibleName: root.isPlaying ? qsTr("Pausar") : qsTr("Reproducir")
                    size: 48
                    active: true
                    dim: !root.canToggle
                    s: root.s
                    onClicked: root.invoke("togglePlaying")
                }
                CtrlBtn { iconName: "skip_next"; accessibleName: qsTr("Siguiente"); dim: !root.canNext; s: root.s; onClicked: root.invoke("next") }
                Item { Layout.fillWidth: true }
                CtrlBtn { iconName: root.repeatOne ? "repeat_one" : "repeat"; accessibleName: qsTr("Repetir"); active: root.canRepeat && root.player.loopState !== root.loopNone; dim: !root.canRepeat; s: root.s; onClicked: root.cycleRepeat() }
            }
        }
    }
}
