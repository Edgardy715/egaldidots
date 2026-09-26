import QtQuick
import Quickshell.Services.Mpris

// Per-view playback session. Inject an MPRIS-compatible player and track key;
// owns capabilities, seeking and the visible position clock, never selection.
QtObject {
    id: root

    property var player: null
    property bool active: false
    property string trackKey: ""
    readonly property bool hasPlayer: !!player
    readonly property bool isPlaying: !!player && player.isPlaying
    readonly property string title: player ? (player.trackTitle || qsTr("Sin título")) : qsTr("Sin contenido")
    readonly property string artist: player ? (player.trackArtist || qsTr("Artista desconocido")) : ""
    readonly property string album: player ? (player.trackAlbum || "") : ""
    readonly property bool albumDistinct: album.length > 0
        && album.toLowerCase() !== title.toLowerCase()
        && album.toLowerCase() !== artist.toLowerCase()
    readonly property bool canSeek: !!player && !!player.canControl && !!player.canSeek
        && !!player.positionSupported && !!player.lengthSupported
        && isFinite(player.length) && player.length > 0
    readonly property bool canShuffle: !!player && !!player.canControl && !!player.shuffleSupported
    readonly property bool canRepeat: !!player && !!player.canControl && !!player.loopSupported
    readonly property bool canPrevious: !!player && !!player.canControl && !!player.canGoPrevious
    readonly property bool canNext: !!player && !!player.canControl && !!player.canGoNext
    readonly property bool canToggle: !!player && !!player.canControl && !!player.canTogglePlaying

    property real position: player ? Math.max(0, player.position || 0) : 0
    property real lastPositionAt: 0
    property bool dragging: false
    property real dragFraction: 0
    readonly property real progress: player && canSeek
        ? Math.max(0, Math.min(1, (dragging ? dragFraction * player.length : position) / player.length))
        : 0

    readonly property var loopNone: MprisLoopState.None
    readonly property var loopTrack: MprisLoopState.Track
    readonly property bool repeatOne: !!player && canRepeat && player.loopState === loopTrack

    readonly property real displayPosition: dragging && player ? dragFraction * player.length : position
    readonly property real remaining: player ? Math.max(0, player.length - displayPosition) : 0
    readonly property bool shuffleEnabled: !!player && canShuffle && player.shuffle
    readonly property bool repeatEnabled: !!player && canRepeat && player.loopState !== loopNone

    function syncPosition() {
        if (!dragging) {
            position = player ? Math.max(0, player.position || 0) : 0
            lastPositionAt = Date.now()
        }
    }

    function previous() { if (canPrevious) player.previous() }
    function next() { if (canNext) player.next() }
    function togglePlaying() { if (canToggle) player.togglePlaying() }

    function seekTo(value) {
        if (!canSeek || !isFinite(value)) return
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

    function cancelDrag() { dragging = false; dragFraction = 0; syncPosition() }
    function beginDrag(fraction) {
        if (!canSeek) return
        dragging = true
        dragFraction = Math.max(0, Math.min(1, fraction))
    }
    function commitDrag(fraction) {
        if (!dragging) return
        dragging = false
        if (canSeek) seekTo(fraction * player.length)
    }

    Component.onCompleted: syncPosition()
    onActiveChanged: { if (!active) cancelDrag(); else syncPosition() }
    onPlayerChanged: cancelDrag()
    onTrackKeyChanged: cancelDrag()
    onCanSeekChanged: if (!canSeek) cancelDrag()
    onIsPlayingChanged: syncPosition()

    property Connections playerConnections: Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onPositionChanged() { root.syncPosition() }
    }

    property Timer positionTimer: Timer {
        interval: 60
        repeat: true
        running: root.active && root.canSeek && root.isPlaying && !root.dragging
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

}
