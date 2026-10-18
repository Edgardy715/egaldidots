pragma ComponentBehavior: Bound
import QtQuick
import Qt5Compat.GraphicalEffects
import "../Singletons"

// Small artwork field: blur is rendered at texture size, then stretched to the panel.
Item {
    id: root
    objectName: "mediaAmbient"
    property string artUrl: ""
    property var artworkTransition: null
    property bool playing: false
    property bool settled: false
    readonly property bool shown: visible && width > 0 && height > 0
    readonly property bool flowing: shown && settled && playing
        && Flags.mediaTransitions && !Flags.reduceMotion && artUrl.length > 0
    readonly property size textureSize: Qt.size(192, 128)
    property real phase: 0
    property real pace: flowing ? 1 : 0
    Behavior on pace {
        enabled: root.shown && Flags.mediaTransitions && !Flags.reduceMotion
        NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
    }
    Timer {
        id: driftClock
        objectName: "mediaAmbientClock"
        interval: 33
        repeat: true
        running: root.shown && (root.flowing || root.pace > 0.001)
        onTriggered: root.phase += interval / 1000 * root.pace
    }

    Item {
        id: texture
        width: root.textureSize.width
        height: root.textureSize.height
        transform: Scale {
            origin.x: 0; origin.y: 0
            xScale: root.width / texture.width
            yScale: root.height / texture.height
        }
        layer.enabled: root.shown && root.artUrl.length > 0
        layer.effect: FastBlur { radius: 22 }

        ArtworkImage {
            objectName: "mediaAmbientImage"
            x: -24 + 9 * Math.sin(root.phase * 0.43)
            y: -20 + 7 * Math.sin(root.phase * 0.31 + 1.2)
            width: texture.width + 48
            height: texture.height + 40
            source: root.artUrl
            sourceSize: Qt.size(256, 256)
            fillMode: Image.PreserveAspectCrop
            opacity: 0.32
            transitionsEnabled: Flags.mediaTransitions
            transitionSource: root.artworkTransition
            motionVisible: root.shown
        }
    }
}
