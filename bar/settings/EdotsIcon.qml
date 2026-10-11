import QtQuick
import "../components"
import "../Singletons"

// Every Edots symbol uses the same finite, semantic gesture engine.
MaterialIcon {
    id: root
    readonly property string symbolIdentity: iconName
    onSymbolIdentityChanged: Qt.callLater(replay)
    property bool selected: false
    property bool controlHovered: false
    property bool controlPressed: false
    readonly property bool exposed: visible && (!Window.window || Window.window.visible)
    readonly property bool engaged: pointer.hovered || controlHovered || (interaction && interaction.engaged)
    hovered: engaged || arrival.running
    pressed: controlPressed || (interaction && interaction.pressed)
    scale: Flags.reduceMotion ? 1 : pressed ? 0.94 : engaged ? 1.10 : 1
    Behavior on scale {
        enabled: root.exposed && !Flags.reduceMotion
        SpringAnimation { spring: Motion.controlSpring; damping: Motion.controlDamping; mass: 0.4; epsilon: 0.001 }
    }
    HoverHandler { id: pointer }
    Timer { id: arrival; interval: Motion.iconGesture; onTriggered: {} }
    function replay() {
        if (!exposed || Flags.reduceMotion) return
        arrival.stop()
        Qt.callLater(function() { if (root.exposed && !Flags.reduceMotion) arrival.start() })
    }
    onSelectedChanged: if (selected) replay()
    onExposedChanged: { if (exposed) replay(); else arrival.stop() }
    Component.onCompleted: Qt.callLater(replay)
    Connections {
        target: Flags
        function onReduceMotionChanged() { if (Flags.reduceMotion) arrival.stop() }
    }
}
