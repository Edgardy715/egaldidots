pragma ComponentBehavior: Bound
import QtQuick
import "../Singletons"

Item {
    id: root
    required property string screenName
    property real s: 1
    property real topGap: 8 * s
    property real availableWidth: 360
    property bool presented: true
    readonly property alias workspaceModule: workspaceLoader
    readonly property alias statusModule: statusLoader
    readonly property TopWorkspaceRail workspaceItem: workspaceLoader.status === Loader.Ready ? (workspaceLoader.item as TopWorkspaceRail) : null
    readonly property TopSystemStatus statusItem: statusLoader.status === Loader.Ready ? (statusLoader.item as TopSystemStatus) : null
    signal requestSurface(string name)

    OptionalModule {
        id: workspaceLoader
        anchors.left: parent.left
        anchors.leftMargin: 26 * root.s
        anchors.top: parent.top
        anchors.topMargin: root.topGap
        s: root.s
        requested: Config.modules.workspaceRail
        presented: root.presented && (!root.workspaceItem || root.workspaceItem.fits)
        animateChanges: Config.modules.animateChanges
        sourceComponent: TopWorkspaceRail {
            s: root.s
            WorkspaceModel { id: workspaceData; screenName: root.screenName }
            activeId: workspaceData.activeId
            count: workspaceData.count
            occupied: workspaceData.occupied
            availableWidth: root.availableWidth
            onWorkspaceRequested: id => workspaceData.activate(id)
            onRequestWorkspaces: root.requestSurface("workspaces")
        }
    }
    OptionalModule {
        id: statusLoader
        anchors.right: parent.right
        anchors.rightMargin: 26 * root.s
        anchors.top: parent.top
        anchors.topMargin: root.topGap
        s: root.s
        requested: Config.modules.systemStatus && (Config.modules.apps || Config.modules.audio
            || Config.modules.network || Config.modules.battery)
        presented: root.presented && (!root.statusItem || root.statusItem.fits)
        animateChanges: Config.modules.animateChanges
        sourceComponent: TopSystemStatus {
            s: root.s
            screenName: root.screenName
            availableWidth: root.availableWidth
            showApps: Config.modules.apps
            showAudio: Config.modules.audio
            showNetwork: Config.modules.network
            showBattery: Config.modules.battery
            animateChanges: Config.modules.animateChanges
            onRequestSurface: name => root.requestSurface(name)
        }
    }
}
