import QtQuick
import "Singletons"

/**
 * Isla · PillSurface. Base de surfaces (puerto de Ricelin PillSurface.qml):
 * rellena el cuerpo de la pill inset por sus márgenes (escalados por `s`), entra
 * con el morph a medida que se asienta (una curva suave ligada a `morphCloseness`), y sólo
 * está habilitada cuando está abierta. El host fija `open`, `s`, `morphCloseness`;
 * la surface declara `mTop/mLeft/mRight/mBottom`. `requestClose()` pide al host
 * despido. El contenido se revela según la geometría actual del vidrio.
 */
Item {
    // ---- Fondo de surface (opcional, para looks creativos sin perder el morph) ----
    // `bgColor`: pinta un fondo DETRÁS del contenido, llenando toda la surface
    // (que ya ocupa el tamaño de la pill gracias a anchors.fill: parent).
    // Default transparent = glass del body se ve (comportamiento de siempre).
    // `bgRect` (alias) permite looks más complejos desde la surface:
    //   bgRect.gradient: Gradient { ... }   ·  bgRect.radius / border / etc.

    id: surface

    property real s: 1
    property bool open: false
    property bool closing: false
    property real morphCloseness: 1
    property string screenName: ""
    property real morphRadius: 0
    property real mTop: Theme.marginNone
    property real mLeft: Theme.marginNone
    property real mRight: Theme.marginNone
    property real mBottom: Theme.marginNone
    readonly property bool active: open && !closing
    readonly property bool contentReady: active && morphCloseness > 0.2
    // Nota: si la surface pone `clip: true` a nivel root, recortará también el
    // fondo a sus propios límites (con márgenes ≠ 0 volvería el "rectángulo
    // dentro"). En ese caso, mover el clip al contenedor de contenido interno
    // (como hace WallpaperSurface con su estantería).
    property color bgColor: "transparent"
    property alias bgRect: _surfaceBg

    signal requestClose()

    // Los márgenes pertenecen al contrato visual de cada surface. Aplicarlos
    // aquí mantiene el contenido dentro del vidrio y evita que los encabezados
    // crezcan hasta quedar cortados por el morph del host.
    anchors.fill: parent
    anchors.topMargin: surface.mTop * surface.s
    anchors.leftMargin: surface.mLeft * surface.s
    anchors.rightMargin: surface.mRight * surface.s
    anchors.bottomMargin: surface.mBottom * surface.s
    enabled: open
    readonly property real morphExposure: Math.max(0, Math.min(1, morphCloseness))
    opacity: open ? morphExposure * morphExposure * (3 - 2 * morphExposure) : 0
    visible: opacity > 0.01

    Rectangle {
        id: _surfaceBg

        anchors.fill: parent
        z: -9999
        color: surface.bgColor
        visible: surface.bgColor !== Qt.rgba(0, 0, 0, 0)
    }

}
