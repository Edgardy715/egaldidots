import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import "../"
import "../components"
import "../Singletons"

PillSurface {
    id: root

    mTop: 24
    mLeft: 24
    mRight: 24
    mBottom: 24

    readonly property string mediaFont: Theme.fontMedia

    readonly property bool musicPresentation: Players.isMusicSource
    // The host uses this presentation hint to reserve the album line.
    readonly property bool albumDistinct: session.albumDistinct
    readonly property string consumerId: "media:" + (root.screenName || "default")
    property string registeredConsumerId: ""

    MediaSession {
        id: session
        player: Players.active
        trackKey: Players.trackKey
        active: root.open
    }

    function syncCava() {
        if (registeredConsumerId && registeredConsumerId !== consumerId)
            Cava.setConsumer(registeredConsumerId, false)
        registeredConsumerId = consumerId
        Cava.setConsumer(consumerId, root.open && session.isPlaying)
    }
    Component.onCompleted: syncCava()
    Component.onDestruction: Cava.setConsumer(registeredConsumerId, false)
    onOpenChanged: syncCava()
    onConsumerIdChanged: syncCava()
    Connections {
        target: session
        function onIsPlayingChanged() { root.syncCava() }
    }

    Item {
        anchors.fill: parent
        visible: !session.hasPlayer
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
                color: Qt.alpha(Theme.foreground, 0.72)
                font.family: root.mediaFont
                font.pixelSize: Theme.fontSizeBodyLg * root.s
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 24 * root.s
        visible: session.hasPlayer
        opacity: visible ? 1 : 0
        Behavior on opacity { Anim { type: Anim.DefaultEffects } }

        Item {
            id: artworkColumn
            Layout.preferredWidth: Math.min(208 * root.s, parent.height)
            Layout.preferredHeight: root.musicPresentation ? Layout.preferredWidth : Layout.preferredWidth * 9 / 16
            Layout.alignment: Qt.AlignVCenter

            Image {
                id: artSource
                anchors.fill: parent
                source: Players.artUrl
                fillMode: root.musicPresentation ? Image.PreserveAspectCrop : Image.PreserveAspectFit
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
            Layout.alignment: Qt.AlignVCenter
            spacing: 6 * root.s

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSm * root.s
                Text {
                    text: session.isPlaying ? (root.musicPresentation ? qsTr("Ahora suena") : qsTr("Reproduciendo")) : qsTr("En pausa")
                    color: Qt.alpha(Theme.foreground, 0.65)
                    font.family: root.mediaFont
                    font.pixelSize: 11 * root.s
                }
                Item { Layout.fillWidth: true }
                Item {
                    Layout.preferredWidth: 16 * root.s
                    Layout.preferredHeight: 16 * root.s
                    Image {
                        id: sourceIcon
                        anchors.fill: parent
                        source: Players.serviceIcon
                        sourceSize: Qt.size(32, 32)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }
                    MaterialIcon {
                        anchors.fill: parent
                        visible: sourceIcon.status !== Image.Ready
                        iconName: Players.sourceInfo.glyph
                        color: Players.sourceInfo.color || Theme.iconSecondary
                        font.pixelSize: 16 * root.s
                    }
                }
                Text {
                    Layout.maximumWidth: 110 * root.s
                    text: Players.serviceLabel
                    color: Theme.iconSecondary
                    font.family: root.mediaFont
                    font.pixelSize: Theme.fontSizeSmall * root.s
                    elide: Text.ElideRight
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
                text: session.title
                color: Theme.iconPrimary
                font.family: root.mediaFont
                font.pixelSize: 20 * Flags.fontScale * root.s
                font.weight: Font.DemiBold
                font.letterSpacing: -0.35 * root.s
                wrapMode: Text.Wrap
                maximumLineCount: 2
                lineHeight: 1.12
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: session.artist + (root.musicPresentation && session.albumDistinct ? " · " + session.album : "")
                color: Qt.alpha(Theme.foreground, 0.72)
                font.family: root.mediaFont
                font.pixelSize: Theme.fontSizeBodyLg * root.s
                font.letterSpacing: 0.05 * root.s
                elide: Text.ElideRight
            }
            Item {
                id: cavaView
                visible: root.musicPresentation
                Layout.fillWidth: true
                Layout.preferredHeight: 18 * root.s
                readonly property int count: Math.max(12, Math.min(32, Math.floor(width / (8 * root.s))))
                readonly property real gap: 3 * root.s
                readonly property real barWidth: Math.max(2 * root.s, (width - (count - 1) * gap) / count)
                Repeater {
                    model: cavaView.count
                    delegate: Rectangle {
                        required property int index
                        readonly property real signal: session.isPlaying && Cava.available && Cava.values.length > 0
                            ? Cava.values[Math.min(Cava.values.length - 1,
                              Math.floor(index * Cava.values.length / cavaView.count))] || 0 : 0
                        width: cavaView.barWidth
                        height: Math.max(2 * root.s, (2 * root.s) + signal * 14 * root.s)
                        x: index * (cavaView.barWidth + cavaView.gap)
                        y: cavaView.height - height
                        radius: width / 2
                        color: Qt.alpha(Theme.foreground, 0.20 + signal * 0.35)
                        Behavior on height { Anim { type: Anim.FastEffects } }
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                    }
                }
            }

            Item {
                id: seekBar
                Layout.fillWidth: true
                Layout.preferredHeight: 24 * root.s
                visible: session.canSeek
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
                        width: parent.width * session.progress
                        height: parent.height
                        radius: parent.radius
                        color: Qt.alpha(Theme.foreground, 0.85)
                        Behavior on width { enabled: !session.dragging; Anim { type: Anim.FastEffects } }
                    }
                }
                Rectangle {
                    x: seekBar.trackInset + seekBar.trackWidth * session.progress - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 9 * root.s
                    height: width
                    radius: width / 2
                    color: Theme.foreground
                    opacity: seekMouse.containsMouse || session.dragging ? 1 : 0
                    Behavior on opacity { Anim { type: Anim.FastEffects } }
                    scale: seekMouse.containsMouse || session.dragging ? 1.2 : 1
                    Behavior on scale { Anim { type: Anim.FastEffects } }
                }
                MouseArea {
                    id: seekMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: session.canSeek
                    cursorShape: Qt.PointingHandCursor
                    onPressed: (mouse) => { session.beginDrag(seekBar.fractionAt(mouse.x)) }
                    onPositionChanged: (mouse) => { if (session.dragging) session.dragFraction = seekBar.fractionAt(mouse.x) }
                    onReleased: (mouse) => { session.commitDrag(seekBar.fractionAt(mouse.x)) }
                    onCanceled: session.cancelDrag()
                }
            }
            RowLayout {
                Layout.fillWidth: true
                visible: session.canSeek
                Text {
                    text: session.formatTime(session.displayPosition)
                    color: Theme.iconSecondary
                    font.family: root.mediaFont
                    font.pixelSize: Theme.fontSizeSmall * root.s
                    font.letterSpacing: 0.2 * root.s
                    Layout.fillWidth: true
                }
                Text {
                    text: "−" + session.formatTime(session.remaining)
                    color: Theme.iconSecondary
                    font.family: root.mediaFont
                    font.pixelSize: Theme.fontSizeSmall * root.s
                    font.letterSpacing: 0.2 * root.s
                    horizontalAlignment: Text.AlignRight
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingLg * root.s
                CtrlBtn { visible: root.musicPresentation || session.canShuffle; iconName: "shuffle"; accessibleName: qsTr("Aleatorio"); active: session.shuffleEnabled; dim: !session.canShuffle; s: root.s; onClicked: session.toggleShuffle() }
                Item { Layout.fillWidth: true }
                CtrlBtn { iconName: "skip_previous"; iconSize: 28; accessibleName: qsTr("Anterior"); dim: !session.canPrevious; s: root.s; onClicked: session.previous() }
                CtrlBtn {
                    iconName: session.isPlaying ? "pause" : "play_arrow"
                    accessibleName: session.isPlaying ? qsTr("Pausar") : qsTr("Reproducir")
                    size: 52
                    iconSize: 30
                    primary: true
                    dim: !session.canToggle
                    s: root.s
                    onClicked: session.togglePlaying()
                }
                CtrlBtn { iconName: "skip_next"; iconSize: 28; accessibleName: qsTr("Siguiente"); dim: !session.canNext; s: root.s; onClicked: session.next() }
                Item { Layout.fillWidth: true }
                CtrlBtn { visible: root.musicPresentation || session.canRepeat; iconName: session.repeatOne ? "repeat_one" : "repeat"; accessibleName: qsTr("Repetir"); active: session.repeatEnabled; dim: !session.canRepeat; s: root.s; onClicked: session.cycleRepeat() }
            }
        }
    }
}
