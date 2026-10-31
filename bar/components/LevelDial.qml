import QtQuick
import "../Singletons"

// Arco de nivel de Tidemark alrededor de un glifo: volumen (VolumeGlyph con mute),
// micrófono o brillo (icono fijo). El arco crece con cabeza y sigue al valor con
// muelle; el glifo cambia de estado por trazo, no por swap. Presentación pura.
Item {
    id: root
    // "volume" | "mic" | "brightness"
    property string kind: "volume"
    property real level: 0
    property bool muted: false
    property string iconName: ""
    property color color: Theme.accent
    property real diameter: 20
    readonly property real shown: arc.shown
    implicitWidth: diameter
    implicitHeight: diameter
    Accessible.ignored: true

    LevelStroke {
        id: arc
        anchors.fill: parent
        shape: "arc"
        value: root.muted ? 0 : root.level
        head: false
        color: root.color
        lineWidth: Math.max(1.5, root.diameter * Theme.strokeRing * 1.4)
    }
    VolumeGlyph {
        anchors.centerIn: parent
        size: root.diameter * 0.54
        visible: root.kind === "volume"
        level: root.level
        muted: root.muted
        color: root.color
    }
    MaterialIcon {
        anchors.centerIn: parent
        visible: root.kind !== "volume"
        iconName: root.iconName
        color: root.color
        font.pixelSize: root.diameter * 0.54
    }
}
