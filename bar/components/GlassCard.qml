import QtQuick
import QtQuick.Effects
import "../Singletons"
import "../"

/**
 * Isla · GlassCard. Tarjeta de vidrio unificada (reemplaza las ~5 copias en
 * Utils/Connectivity): gradiente cardTop→cardBot @glassAlpha, borde 1px, sheen
 * superior y sombra MultiEffect separada (texto nunca pasa por el layerEffect).
 *
 * Props:
 *   radius_   — radio del contenedor (default 16·s)
 *   s         — escala del host
 *   pad       — padding interior (0 para layout fluido)
 *   clickable — si el contenido es clickable (refleja wash + cursor)
 * signal clicked() (solo si `clickable: true`).
 *
 * Los hijos declarados dentro de GlassCard caen en `content` (capa sobre el vidrio).
 */
Item {
    id: root

    property real s: 1
    property real radius_: 16 * s
    property real pad: 0
    property bool clickable: false
    property color borderColor: Theme.border
    property real borderWidth: 1
    property color washColor: Qt.alpha(Theme.foreground, Theme.alphaFaint)

    signal clicked()

    InteractionMotion { id: response; hovered: washMa.containsMouse; pressed: washMa.pressed && washMa.containsMouse; enabled: root.clickable; extent: root.height }
    // sombra separada: un rect fantasma detrás recibe el blur; el vidrio (que
    // contiene texto) se dibuja limpio encima.
    Rectangle {
        id: shadow
        anchors.fill: parent
        radius: root.radius_
        color: "transparent"
        border.width: Theme.borderHairline
        border.color: root.borderColor
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.30)
            shadowBlur: 0.55
            shadowVerticalOffset: 1.5 * root.s
        }
    }

    Rectangle {
        id: glass
        scale: response.visualScale
        anchors.fill: parent
        radius: root.radius_
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.alpha(Theme.cardTop, Math.min(1, Flags.glassAlpha + 0.10)) }
            GradientStop { position: 1.0; color: Qt.alpha(Theme.cardBot, Flags.glassAlpha) }
        }
        border.width: root.borderWidth
        border.color: root.borderColor

        // catch-light superior
        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: 1 * root.s
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.82
            height: 1 * root.s
            radius: height / 2
            color: Theme.sheen
        }

        // wash de hover (solo tarjetas clickables)
        Rectangle {
            id: wash
            anchors.fill: parent
            radius: parent.radius
            color: washMa.containsMouse ? root.washColor : "transparent"
            Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
        }

    }

    // capa de contenido (default property): todo lo declarado dentro cae aquí
    default property alias content: contentItem.data
    Item {
        id: contentItem
        scale: response.visualScale
        anchors.fill: parent
        anchors.margins: root.pad
        z: 1
    }
    MotionArea {
        id: washMa
        anchors.fill: parent
        enabled: root.clickable
        feedbackEnabled: false
        hoverEnabled: root.clickable
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.clickable) root.clicked()
    }
}
