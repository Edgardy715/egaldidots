import QtQuick
import QtQuick.Controls.Basic
import "../../Singletons"
import "../RubberBand.js" as RubberBand

Slider {
    id: root
    property real s: 1
    property real volume: 0
    property real maximum: 1
    property bool muted: false
    property string label: ""
    property bool pending: false
    property real pendingValue: 0
    // Smooths external volume changes only; dragging/pending stays 1:1 with the pointer.
    property real shownPosition: visualPosition
    Behavior on shownPosition {
        enabled: !root.pressed && !root.pending && !Flags.reduceMotion
        SmoothedAnimation { duration: Motion.fast; velocity: -1 }
    }
    readonly property real displayVolume: pressed || pending ? value : volume
    onVolumeChanged: if (pending && Math.abs(volume - pendingValue) < 0.015) { pending = false; confirmation.stop() }
    onVisibleChanged: if (!visible) { pending = false; confirmation.stop() }
    onEnabledChanged: if (!enabled) { pending = false; confirmation.stop() }
    Timer { id: confirmation; interval: 1600; onTriggered: root.pending = false }
    // Banda elástica (como Slider): pasado un extremo el track se estira hacia el
    // puntero con resistencia y vuelve con el muelle de controles al soltar.
    readonly property real maxOverdrag: 10 * s
    property real overdrag: 0
    property bool overdragLive: false
    Behavior on overdrag {
        enabled: !root.overdragLive && !Flags.reduceMotion
        SpringAnimation { spring: Motion.controlSpring; damping: Motion.controlDamping; mass: 0.5; epsilon: 0.05 }
    }
    readonly property real squeeze: Math.min(1, Math.abs(overdrag) / maxOverdrag)
    function rubber(px) {
        return RubberBand.rubberBand(px, maxOverdrag, 0.55)
    }
    PointHandler {
        id: pointer
        target: null
        acceptedButtons: Qt.LeftButton
        onPointChanged: {
            if (!root.pressed || Flags.reduceMotion) return
            const x = point.position.x, lo = root.leftPadding, hi = root.leftPadding + root.availableWidth
            root.overdragLive = true
            root.overdrag = x < lo ? root.rubber(x - lo) : x > hi ? root.rubber(x - hi) : 0
        }
    }
    onPressedChanged: if (!pressed) { overdragLive = false; overdrag = 0 }
    signal edited(real volume)
    from: 0; to: maximum; stepSize: 0.01
    implicitHeight: 32 * s
    leftPadding: 7 * s; rightPadding: 7 * s
    hoverEnabled: true
    wheelEnabled: false
    Accessible.name: label
    Accessible.description: Math.round(volume * 100) + "%"
    Binding { target: root; property: "value"; value: root.volume; when: !root.pressed && !root.pending; restoreMode: Binding.RestoreBindingOrValue }
    onMoved: {
        pendingValue = Math.max(0, Math.min(1.5, value))
        pending = true
        confirmation.restart()
        edited(pendingValue)
    }
    background: Rectangle {
        x: root.leftPadding + Math.min(0, root.overdrag); y: (root.height - height) / 2
        width: root.availableWidth + Math.abs(root.overdrag); height: 6 * root.s * (1 - 0.2 * root.squeeze)
        radius: height / 2
        color: Qt.alpha(Theme.foreground, Theme.alphaSubtle)
        Rectangle {
            height: parent.height; width: parent.width * root.shownPosition; radius: parent.radius
            color: root.muted ? Theme.iconSecondary : root.value > 1 ? Theme.error : Theme.accent
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }
        Rectangle {
            visible: root.maximum > 1
            x: root.availableWidth / root.maximum - Math.min(0, root.overdrag); y: -3 * root.s
            width: root.s; height: parent.height + 6 * root.s
            color: Theme.foreground
        }
    }
    handle: Rectangle {
        x: root.leftPadding + root.shownPosition * root.availableWidth - width / 2 + root.overdrag
        y: (root.height - height) / 2
        width: 14 * root.s; height: width; radius: width / 2
        color: root.muted ? Theme.iconSecondary : Theme.foreground
        Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
        scale: Flags.reduceMotion ? 1 : root.pressed ? 1.24 : root.hovered || root.activeFocus ? 1.12 : 1
        Behavior on scale { SmoothedAnimation { duration: Motion.hover; velocity: -1 } }
        Rectangle {
            anchors.fill: parent; anchors.margins: -4 * root.s
            radius: width / 2; color: "transparent"
            border.width: 2 * root.s; border.color: Theme.accent
            opacity: root.activeFocus ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Motion.fast } }
        }
    }
    opacity: enabled ? 1 : 0.45
}
