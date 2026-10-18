import QtQuick
import "../Singletons"

// Media adapter: source selection/CAVA stay outside the shared motion engine.
FluidCompanion {
    id: root
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
    readonly property real progress: player && player.length > 0
        ? Math.max(0, Math.min(1, (player.position || 0) / player.length)) : 0
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
            clip: true
            anchors.fill: parent
            anchors.leftMargin: 3 * root.s
            anchors.rightMargin: 3 * root.s

            IslandMediaCover {
                musicAccent: MediaPalette.accent
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                s: root.s
                hovered: root.hovered
                pressed: root.pressed
                diameter: 34 * root.s
                ringWidth: 1.8 * root.s
                ringGap: 2 * root.s
                progress: root.progress
                hasProgress: root.player && root.player.length > 0
                artUrl: Players.artUrl || ""
            }

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
                    title: root.player ? (root.player.trackTitle || qsTr("Sin título")) : qsTr("Sin contenido")
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
