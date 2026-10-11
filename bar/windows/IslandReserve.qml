import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Singletons"

PanelWindow {
    id: reserve
    required property var modelData
    readonly property real s: modelData ? (modelData.height / 1080) * Flags.uiScale : 1
    readonly property real topGap: 8 * Flags.topGap * s
    property bool compact: Config.appearance.barLayout === "compact"
    readonly property real restHeight: (compact ? IslandGeometry.compactRestHeight : IslandGeometry.restHeight) * s
    /** trim del aire pill→ventana sin tocar gaps_out del desktop. */
    property real reservedH: Math.max(0, restHeight + topGap - 12 * (1 - Flags.appGap) * s)

    Behavior on reservedH {
        enabled: !Flags.reduceMotion
        SmoothedAnimation { duration: Motion.morph; velocity: -1 }
    }

    screen: modelData
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: reservedH
    aboveWindows: true

    anchors { top: true; left: true; right: true }
    implicitHeight: reservedH

    mask: emptyReserve
    Region { id: emptyReserve }
}
