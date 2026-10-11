pragma ComponentBehavior: Bound
import QtQuick
import "../Singletons"

Item {
    id: root
    required property string screenName
    property real s: 1
    property bool compact: false
    property real topGap: compact ? (height - 48 * s) / 2 : 8 * s
    property real availableWidth: 360
    property bool presented: true
    property real centerWidth: 0
    readonly property real contentWidth: centerWidth + leftWidth + rightWidth + 36 * s
        + (leftWidth > 0 ? 18 * s : 0) + (rightWidth > 0 ? 18 * s : 0)
    readonly property bool contentFits: !compact || width >= contentWidth - 1
    property bool hasMedia: Players.has
    property var mediaPlayer: Players.active
    property string mediaArtUrl: Players.artUrl || ""
    readonly property real workspaceWidth: workspaceItem && workspaceItem.fits ? workspaceItem.width : 0
    readonly property real mediaWidth: Math.min(mediaNaturalWidth, Math.max(76 * s,
        availableWidth - (workspaceLoader.active ? (48 + (workspaceItem ? workspaceItem.count : 5) * 19) * s : 0) - 12 * s))
    readonly property real mediaNaturalWidth: Math.min(256 * s,
        48 * s + Math.min(174 * s, Math.max(mediaTitleMetrics.width, mediaArtistMetrics.width)) + 34 * s)
    TextMetrics {
        id: mediaTitleMetrics
        text: mediaSession.title
        font.family: Theme.font
        font.pixelSize: 13 * root.s
        font.weight: Font.Medium
    }
    TextMetrics {
        id: mediaArtistMetrics
        text: mediaSession.artist
        font.family: Theme.font
        font.pixelSize: 11 * root.s
    }
    readonly property real leftWidth: workspaceWidth
        + (mediaLoader.active ? mediaWidth + (workspaceWidth > 0 ? 12 * s : 0) : 0)
    readonly property real rightWidth: (statusItem && statusItem.fits ? statusItem.width : 0)
        + (userLoader.active ? (statusItem && statusItem.fits ? 50 : 38) * s : 0)
    readonly property real clockX: 18 * s + leftWidth + (leftWidth > 0 ? 18 * s : 0)
    clip: compact
    readonly property bool withdrawn: workspaceLoader.exposure < 0.001 && statusLoader.exposure < 0.001
        && userLoader.exposure < 0.001 && mediaLoader.exposure < 0.001
    readonly property alias workspaceModule: workspaceLoader
    readonly property alias userModule: userLoader
    readonly property alias statusModule: statusLoader
    readonly property alias mediaModule: mediaLoader
    readonly property bool cavaActive: compact && mediaLoader.interactive && visible
        && mediaSession.isPlaying && mediaWidth >= 130 * s
    readonly property string cavaConsumerId: "compact-media:" + screenName
    onCavaActiveChanged: Cava.setConsumer(cavaConsumerId, cavaActive)
    Component.onCompleted: Cava.setConsumer(cavaConsumerId, cavaActive)
    Component.onDestruction: Cava.setConsumer(cavaConsumerId, false)
    MediaSession { id: mediaSession; player: root.mediaPlayer; active: mediaLoader.interactive && root.visible }
    readonly property TopWorkspaceRail workspaceItem: workspaceLoader.status === Loader.Ready ? (workspaceLoader.item as TopWorkspaceRail) : null
    readonly property TopSystemStatus statusItem: statusLoader.status === Loader.Ready ? (statusLoader.item as TopSystemStatus) : null
    signal requestSurface(string name)

    OptionalModule {
        id: workspaceLoader
        anchors.left: parent.left
        anchors.leftMargin: (root.compact ? 18 : 26) * root.s
        anchors.top: parent.top
        anchors.topMargin: root.topGap
        s: root.s
        requested: Config.modules.workspaceRail
        presented: root.presented && root.contentFits && (!root.workspaceItem || root.workspaceItem.fits)
        animateChanges: Config.modules.animateChanges
        sourceComponent: TopWorkspaceRail {
            s: root.s
            integrated: root.compact
            style: Config.appearance.workspaceStyle
            WorkspaceModel { id: workspaceData; screenName: root.screenName }
            activeId: workspaceData.activeId
            count: workspaceData.count
            occupied: workspaceData.occupied
            availableWidth: Math.max(0, root.availableWidth - (mediaLoader.active ? root.mediaWidth + 12 * root.s : 0))
            onWorkspaceRequested: id => workspaceData.activate(id)
            onRequestWorkspaces: root.requestSurface("workspaces")
        }
    }
    OptionalModule {
        id: userLoader
        requested: Config.modules.userAvatar
        anchors.right: parent.right
        anchors.rightMargin: (root.compact ? 18 : 26) * root.s
        anchors.top: parent.top
        anchors.topMargin: root.topGap + (root.compact ? 5 * root.s : 0)
        s: root.s
        presented: root.presented && root.contentFits
        animateChanges: Config.modules.animateChanges
        sourceComponent: TopUserStatus {
            s: root.s
            avatarSource: Config.userAvatarUrl
            userName: Config.profile.displayName || Config.home.split("/").pop()
            onClicked: root.requestSurface("profile")
        }
    }
    OptionalModule {
        id: statusLoader
        anchors.right: parent.right
        anchors.rightMargin: (root.compact ? 18 : 26) * root.s
            + (root.compact ? (userLoader.active ? 50 * root.s : 0) : 50 * root.s * userLoader.exposure)
        anchors.top: parent.top
        anchors.topMargin: root.topGap + (root.compact ? 5 * root.s : 0)
        s: root.s
        requested: Config.modules.systemStatus && (Config.modules.apps || Config.modules.audio
            || Config.modules.network || Config.modules.battery)
        presented: root.presented && root.contentFits && (!root.statusItem || root.statusItem.fits)
        animateChanges: Config.modules.animateChanges
        sourceComponent: TopSystemStatus {
            s: root.s
            screenName: root.screenName
            integrated: root.compact
            availableWidth: Math.max(0, root.availableWidth
                - (root.compact ? (userLoader.active ? 50 * root.s : 0) : 50 * root.s * userLoader.exposure))
            showApps: Config.modules.apps
            showAudio: Config.modules.audio
            showNetwork: Config.modules.network
            showBattery: Config.modules.battery
            animateChanges: Config.modules.animateChanges
            onRequestSurface: name => root.requestSurface(name)
        }
    }
    OptionalModule {
        id: mediaLoader
        x: (18 * root.s) + root.workspaceWidth + (root.workspaceWidth > 0 ? 12 * root.s : 0)
        y: root.topGap + 5 * root.s
        width: root.mediaWidth
        s: root.s
        requested: root.compact && root.hasMedia
        presented: root.presented && root.contentFits && root.mediaWidth <= root.availableWidth
        animateChanges: Config.modules.animateChanges
        sourceComponent: CompactMediaStatus {
            s: root.s
            title: mediaSession.title
            artist: mediaSession.artist
            artUrl: root.mediaArtUrl
            playing: mediaSession.isPlaying
            hasFrame: Cava.hasFrame
            values: Cava.values
            onRequestMedia: root.requestSurface("media")
        }
    }

    Repeater {
        model: [
            { position: 18 * root.s + root.workspaceWidth + 6 * root.s,
                shown: root.workspaceWidth > 0 && mediaLoader.active },
            { position: root.clockX - 9 * root.s, shown: root.leftWidth > 0 },
            { position: root.clockX + root.centerWidth + 9 * root.s, shown: root.rightWidth > 0 }
        ]
        Rectangle {
            required property var modelData
            x: modelData.position
            y: (root.height - height) / 2
            width: Theme.borderHairline
            height: 20 * root.s
            color: Theme.hair
            opacity: 0.65
            visible: root.compact && root.presented && root.contentFits && modelData.shown
        }
    }

}
