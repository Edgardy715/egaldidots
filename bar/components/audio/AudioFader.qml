import QtQuick
import QtQuick.Controls.Basic
import "../../Singletons"

Slider {
    id: root
    property real s: 1
    property real volume: 0
    property real maximum: 1
    property bool muted: false
    property string label: ""
    property bool pending: false
    property real pendingValue: 0
    readonly property real displayVolume: pressed || pending ? value : volume
    onVolumeChanged: if (pending && Math.abs(volume - pendingValue) < 0.015) { pending = false; confirmation.stop() }
    onVisibleChanged: if (!visible) { pending = false; confirmation.stop() }
    onEnabledChanged: if (!enabled) { pending = false; confirmation.stop() }
    Timer { id: confirmation; interval: 1600; onTriggered: root.pending = false }
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
        x: root.leftPadding; y: (root.height - height) / 2
        width: root.availableWidth; height: 6 * root.s
        radius: height / 2
        color: Qt.alpha(Theme.foreground, Theme.alphaSubtle)
        Rectangle {
            height: parent.height; width: parent.width * root.visualPosition; radius: parent.radius
            color: root.muted ? Theme.iconSecondary : root.value > 1 ? Theme.error : Theme.accent
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }
        Rectangle {
            visible: root.maximum > 1
            x: parent.width / root.maximum; y: -3 * root.s
            width: root.s; height: parent.height + 6 * root.s
            color: Theme.foreground
        }
    }
    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * root.availableWidth - width / 2
        y: (root.height - height) / 2
        width: 14 * root.s; height: width; radius: width / 2
        color: root.muted ? Theme.iconSecondary : Theme.foreground
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
