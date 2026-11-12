import QtQuick
import "../Singletons"
import "../"

/**
 * Isla · GlassCard. Grupo tonal dentro de una superficie.
 *
 * Una superficie ya es vidrio (borde, sombra y material propios): la tarjeta sólo se
 * separa por tono, sin borde, sombra ni brillo propios (vidrio sobre vidrio, WWDC25;
 * elevación tonal de Material 3). Antes llevaba una textura fuera de pantalla con
 * desenfoque por tarjeta. El radio por defecto es concéntrico al de la superficie.
 *
 * Props:
 *   radius_   — radio del contenedor
 *   s         — escala del host
 *   pad       — padding interior (0 para layout fluido)
 *   clickable — si el contenido es clickable (hover sube el tono)
 * signal clicked() (solo si `clickable: true`).
 *
 * Los hijos declarados dentro de GlassCard caen en `content` (capa sobre el fondo).
 */
Item {
    id: root

    property real s: 1
    property real radius_: Theme.radiusLg * s
    property real pad: 0
    property bool clickable: false

    signal clicked()

    InteractionMotion { id: response; hovered: washMa.containsMouse; pressed: washMa.pressed && washMa.containsMouse; enabled: root.clickable; extent: root.height }

    Rectangle {
        id: glass
        scale: response.visualScale
        anchors.fill: parent
        radius: root.radius_
        color: !root.clickable ? Theme.tonalFill
            : washMa.pressed ? Theme.tonalFillPressed
            : washMa.containsMouse ? Theme.tonalFillHover : Theme.tonalFill
        Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
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
