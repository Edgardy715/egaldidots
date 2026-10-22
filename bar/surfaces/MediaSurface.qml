import QtQuick
import "../components"
import "../Singletons"

MediaView {
    id: root
    musicAccent: MediaPalette.accent
    lyricsSupported: Players.has && Players.sourceInfo.icon === "spotify"
    lyricsStatus: lyricSession.status
    lyricsSynced: lyricSession.synced
    lyricLines: lyricSession.lines
    onLyricsRetryRequested: lyricSession.retry()
    musicPresentation: Players.isMusicSource
    artUrl: Players.artUrl
    serviceIcon: Players.serviceIcon
    serviceLabel: Players.serviceLabel
    sourceInfo: Players.sourceInfo
    playerCount: Players.list.length
    cavaAvailable: Cava.available
    cavaHasFrame: Cava.hasFrame
    cavaValues: Cava.values
    playback: session
    readonly property string consumerId: "media:" + (root.screenName || "default")
    property string registeredConsumerId: ""

    MediaSession {
        id: session
        player: Players.active
        trackKey: Players.trackKey
        active: root.open
    }

    LyricsController {
        id: lyricSession
        active: root.open && root.lyricsOpen && root.lyricsSupported
        title: session.title
        artist: session.artist
        album: session.album
        duration: session.player ? session.player.length : 0
    }

    function syncCava() {
        if (registeredConsumerId && registeredConsumerId !== consumerId)
            Cava.setConsumer(registeredConsumerId, false)
        registeredConsumerId = consumerId
        Cava.setConsumer(consumerId, root.open && root.visible && session.isPlaying)
    }
    Component.onCompleted: syncCava()
    Component.onDestruction: Cava.setConsumer(registeredConsumerId, false)
    onOpenChanged: syncCava()
    onVisibleChanged: syncCava()
    onConsumerIdChanged: syncCava()
    Connections {
        target: session
        function onIsPlayingChanged() { root.syncCava() }
    }

    onCyclePlayerRequested: direction => Players.cycleManual(direction)
    onPreviousRequested: session.previous()
    onNextRequested: session.next()
    onTogglePlayingRequested: session.togglePlaying()
    onToggleShuffleRequested: session.toggleShuffle()
    onCycleRepeatRequested: session.cycleRepeat()
    onSeekRequested: position => session.seekTo(position)
    onDragStarted: fraction => session.beginDrag(fraction)
    onDragMoved: fraction => session.dragFraction = fraction
    onDragCommitted: fraction => session.commitDrag(fraction)
    onDragCanceled: session.cancelDrag()
}
