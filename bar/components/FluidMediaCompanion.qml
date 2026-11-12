import QtQuick
import "../Singletons"

// Media adapter: source selection/CAVA stay outside the shared motion engine.
FluidCompanion {
    id: root
    // Arrastrar la gota no la descarta: sin ella no se sabe qué suena. Sólo rebota.
    gestureDismissable: false
    property alias dismissedUntilTrackChange: root.gestureDismissed
    property string gestureTrack: Players.trackKeyNoArt
    property var gesturePlayer: Players.active
    function resetGestureDismissal() {
        if (!gestureDismissed) return
        gestureDismissed = false
        if (open) start()
    }
    onGestureTrackChanged: resetGestureDismissal()
    onGesturePlayerChanged: resetGestureDismissal()
    artUrl: Players.artUrl
    artworkTransition: sharedArtwork
    mediaPlaying: Players.live
    ArtworkImage {
        id: sharedArtwork
        visible: false
        width: 416 * root.s; height: width
        sourceSize: Qt.size(416 * root.s, 416 * root.s)
        source: root.expanded || root.surfaceItem !== null ? root.artUrl : ""
        transitionsEnabled: Flags.mediaTransitions
        motionVisible: root.visible && root.opacity > 0.01 && root.active
        preloadAmbient: true
    }
    readonly property real playingW: collapsedW + 34 * s
    compactWidth: Players.live ? playingW : collapsedW
    readonly property string cavaConsumerId: "fluid-media:" + (screenName || "default")
    readonly property var player: Players.active
    readonly property real progress: Players.progressOf(player)
    signal requestMedia()
    onRequestToggle: requestMedia()
    function syncCava(): void { Cava.setConsumer(cavaConsumerId, Players.live && active && !expanded && visible) }
    Component.onCompleted: syncCava()
    Component.onDestruction: Cava.setConsumer(cavaConsumerId, false)
    onActiveChanged: syncCava()
    onExpandedChanged: syncCava()
    onVisibleChanged: syncCava()
    Connections {
        target: Players
        function onLiveChanged() { root.syncCava() }
    }
    compactContent: Component {
        Item {
            opacity: (1 - root.cardContentProgress) * root.contentExposure
            visible: opacity > 0.01
            anchors.fill: parent
            anchors.leftMargin: 3 * root.s
            anchors.rightMargin: 3 * root.s

            IslandMediaCover {
                musicAccent: MediaPalette.accent
                anchors.left: parent.left
                // Same inset on the left as above and below: the cover sits centred in the drop's end cap.
                anchors.leftMargin: (root.moduleH - diameter) / 2 - 3 * root.s
                anchors.verticalCenter: parent.verticalCenter
                s: root.s
                hovered: root.hovered
                pressed: root.pressed
                trackTransitions: !root.expanded && root.cardContentProgress < 0.01
                trackKey: Players.trackKeyNoArt
                // The ring hugs the drop's end cap, concentric with the glass edge.
                diameter: 34 * root.s
                hasProgress: Players.has
                progress: root.progress
                ringWidth: 2.5 * root.s
                ringGap: 1.5 * root.s
                ringGlow: false
                ringTrackColor: Qt.alpha(Theme.foreground, 0.16)
                // Dark or grey covers still read: the arc keeps the artwork hue but never sinks below the glass.
                ringColor: Qt.hsla(Math.max(0, musicAccent.hslHue), musicAccent.hslSaturation,
                                   Math.max(0.72, musicAccent.hslLightness), 1)
                trackWave: true
                artUrl: Players.artUrl || ""
            }

            Item {
                anchors.fill: parent
                clip: true

                Item {
                    x: 42 * root.s
                    width: 132 * root.s
                    height: parent.height
                    opacity: root.titleProgress
                    visible: opacity > 0.01
                    IslandMediaMetadata {
                        anchors.verticalCenter: parent.verticalCenter
                        s: root.s
                        contentWidth: 132 * root.s
                        coreH: root.moduleH
                        title: root.player ? (root.player.trackTitle || I18n.tr("Sin título")) : I18n.tr("Sin contenido")
                        artist: root.player ? (root.player.trackArtist || "") : ""
                        playing: Players.live && root.hovered
                    }
                }

                IslandMediaVisualizer {
                    musicAccent: MediaPalette.accent
                    objectName: "mediaVisualizer"
                    // Never cross the cover, even while the container is narrowing.
                    x: Math.max(IslandGeometry.restHeight * root.s,
                                root.wPos - IslandGeometry.restHeight * root.s)
                    anchors.verticalCenter: parent.verticalCenter
                    s: root.s
                    coreH: root.moduleH
                    hasMedia: Players.has
                    isPlaying: Players.live
                    hasFrame: Cava.hasFrame
                    values: Cava.values
                    hiddenForAuth: !Players.live
                    onRequestMedia: root.requestMedia()
                }
            }
        }
    }
}
