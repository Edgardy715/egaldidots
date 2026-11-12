import QtQuick
import QtQuick.Effects
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

    // Tinta del rayo: trazo y relleno comparten un único color animado.
    readonly property color boltTarget: charge > 0.35 ? Theme.background : tint
    property color boltInk: boltTarget
    Behavior on boltInk { ColorAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

    // Neutral at a healthy level: the bar keeps a single accent; colour only for charge states.
    readonly property color fillTint: tint

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
        border.width: Math.max(1, Math.round(1.2 * root.s))
        border.color: root.tint
        Behavior on border.color { ColorAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

        Rectangle {
            id: chargeFill
            // Border width plus a constant gap, so the fill never touches the outline at fractional scales.
            readonly property real inset: shell.border.width + Math.round(0.8 * root.s)
            x: inset
            anchors.verticalCenter: parent.verticalCenter
            width: (shell.width - 2 * inset) * root.charge
            height: shell.height - 2 * inset
            radius: Math.min(2 * root.s, width / 2)
            color: root.fillTint
            Behavior on color { ColorAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
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
        Behavior on color { ColorAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
    }

    // Rayo de Tidemark: al conectar el cargador el trazo se dibuja de punta a punta
    // y luego se rellena; al desconectar se borra. Muelle interrumpible, sin timers.
    SpringValue {
        id: boltDraw
        target: root.charging ? 1 : 0
        active: root.visible && (!Window.window || Window.window.visible)
        spring: Motion.strokeSpring.morph
        Component.onCompleted: snap()
    }
    // El relleno entra al final del trazo y el trazo se retira a la vez: en reposo
    // el rayo conserva su silueta, sin el grosor extra del contorno.
    readonly property real boltFill: Math.max(0, Math.min(1, (boltDraw.value - Motion.strokeBoltFillStart) / (1 - Motion.strokeBoltFillStart)))
    Shape {
        objectName: "batteryBolt"
        x: root.charge > 0.35
            ? Math.max(2 * root.s, Math.min((shell.width - width) / 2, 2 * root.s + (chargeFill.width - width) / 2))
            : (shell.width - width) / 2
        anchors.verticalCenter: shell.verticalCenter
        width: 7 * root.s
        height: 10 * root.s
        visible: boltDraw.value > 0.01
        preferredRendererType: Shape.CurveRenderer
        // Relleno sin trim (trim recortaría también el relleno); aparece al final del trazo.
        ShapePath {
            strokeWidth: -1
            fillColor: Qt.alpha(root.boltInk, root.boltFill)
            startX: 4.1 * root.s; startY: 0
            PathLine { x: 0.5 * root.s; y: 5.4 * root.s }
            PathLine { x: 3.2 * root.s; y: 5.4 * root.s }
            PathLine { x: 2.5 * root.s; y: 10 * root.s }
            PathLine { x: 6.5 * root.s; y: 4.2 * root.s }
            PathLine { x: 3.8 * root.s; y: 4.2 * root.s }
            PathLine { x: 4.1 * root.s; y: 0 }
        }
        ShapePath {
            strokeWidth: 1 * root.s
            strokeColor: Qt.alpha(root.boltInk, 1 - root.boltFill)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            trim.end: Math.max(0, Math.min(1, boltDraw.value))
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
