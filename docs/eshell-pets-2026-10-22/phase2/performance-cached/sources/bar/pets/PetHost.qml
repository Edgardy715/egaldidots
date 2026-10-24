pragma ComponentBehavior: Bound
import QtQuick

// The surface owns the safe region and targets; this loader owns all pet resources.
Loader {
    id: root
    property bool requested: false
    property bool presented: false
    property bool reduced: false
    property real availableWidth: 0
    property real availableHeight: 0
    property int workspaceId: 0
    property bool engaged: false
    property bool reactionsEnabled: true
    property string profile: "balanced"
    property point lookTarget: Qt.point(0, 0)
    property real lookExtent: 1
    readonly property bool fits: width > 0 && height > 0 && width <= availableWidth && height <= availableHeight
    readonly property bool petVisible: active && status === Loader.Ready
    active: requested && presented && visible && fits
    enabled: false
    Accessible.ignored: true
    sourceComponent: GhostPet {
        runtime: PetRuntime {
            active: root.petVisible
            reduced: root.reduced
            workspaceId: root.workspaceId
            engaged: root.engaged
            reactionsEnabled: root.reactionsEnabled
            profile: root.profile
            lookTarget: root.lookTarget
            lookExtent: root.lookExtent
        }
    }
}
