import QtQuick
import QtQuick.Shapes
import "../"
import "../Singletons"

Item {
    id: root
    property real s: 1
    property real level: 0
    property bool charging: false
    property bool chargePaused: false

    readonly property real charge: Math.max(0, Math.min(1, Number.isFinite(level) ? level : 0))
    readonly property color tint: charging ? "#30d158"
        : chargePaused ? "#8e8e93"
        : charge <= 0.2 ? "#ff453a"
        : charge <= 0.4 ? "#ffd60a" : Theme.iconSecondary

    width: 27 * s
    height: 14 * s

    Rectangle {
        id: shell
        x: 0
        anchors.verticalCenter: parent.verticalCenter
        width: 23 * root.s
        height: 12 * root.s
        radius: 3.4 * root.s
        color: "transparent"
        border.width: 1.2 * root.s
        border.color: root.tint

        Rectangle {
            id: chargeFill
            x: 2 * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: (shell.width - 4 * root.s) * root.charge
            height: shell.height - 4 * root.s
            radius: Math.min(2 * root.s, width / 2)
            color: root.tint
            visible: root.charge > 0
            Behavior on width { Anim { type: Anim.DefaultEffects } }
        }
    }

    Rectangle {
        x: 24 * root.s
        anchors.verticalCenter: parent.verticalCenter
        width: 2.5 * root.s
        height: 5 * root.s
        radius: 1.2 * root.s
        color: root.tint
    }

    Shape {
        x: root.charge > 0.35
            ? Math.max(2 * root.s, Math.min((shell.width - width) / 2, 2 * root.s + (chargeFill.width - width) / 2))
            : (shell.width - width) / 2
        anchors.verticalCenter: shell.verticalCenter
        width: 7 * root.s
        height: 10 * root.s
        visible: root.charging
        ShapePath {
            strokeWidth: -1
            fillColor: root.charge > 0.35 ? Theme.background : root.tint
            startX: 4.1 * root.s; startY: 0
            PathLine { x: 0.5 * root.s; y: 5.4 * root.s }
            PathLine { x: 3.2 * root.s; y: 5.4 * root.s }
            PathLine { x: 2.5 * root.s; y: 10 * root.s }
            PathLine { x: 6.5 * root.s; y: 4.2 * root.s }
            PathLine { x: 3.8 * root.s; y: 4.2 * root.s }
            PathLine { x: 4.1 * root.s; y: 0 }
        }
    }

}
