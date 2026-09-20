import QtQuick
import "Singletons"

/**
 * Isla · PillSurface. Base de surfaces (puerto de Ricelin PillSurface.qml):
 * rellena el cuerpo de la pill inset por sus márgenes (escalados por `s`), entra
 * con el morph a medida que se asienta (`Math.pow(morphCloseness, 1.3)`), y sólo
 * está habilitada cuando está abierta. El host fija `open`, `s`, `morphCloseness`;
 * la surface declara `mTop/mLeft/mRight/mBottom`. `requestClose()` pide al host
 * despido. `settled` latch (igual que Ricelin) para evitar el flicker de 1 frame
 * en relayouts internos.
 *
 * Pane transition (nivel caelestia): al cargarse, la surface entra con un slide-up
 * de 8px + scale 0.96→1 (curvas emphasizedDecel asimétricas). SOLO se animan
 * transform/scale — la opacidad la conduce el host (morphCloseness), así el
 * contenido nunca puede quedar invisible por un fallo del timer de entrada.
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
    //* Latch: ya asentó el morph abierto → mantiene opacidad 1 si un relayout interno cráter morphCloseness 1 frame.
    property bool settled: false
    // Nota: si la surface pone `clip: true` a nivel root, recortará también el
    // fondo a sus propios límites (con márgenes ≠ 0 volvería el "rectángulo
    // dentro"). En ese caso, mover el clip al contenedor de contenido interno
    // (como hace WallpaperSurface con su estantería).
    property color bgColor: "transparent"
    property alias bgRect: _surfaceBg
    // pane-transition entry: slide-up 8px→0 + scale 0.96→1 (nunca toca opacity)
    property bool _entering: true

    signal requestClose()

    // Los márgenes pertenecen al contrato visual de cada surface. Aplicarlos
    // aquí mantiene el contenido dentro del vidrio y evita que los encabezados
    // crezcan hasta quedar cortados por el morph del host.
    anchors.fill: parent
    anchors.topMargin: surface.mTop * surface.s
    anchors.leftMargin: surface.mLeft * surface.s
    anchors.rightMargin: surface.mRight * surface.s
    anchors.bottomMargin: surface.mBottom * surface.s
    onOpenChanged: {
        if (!open) {
            settled = false;
            _entering = true;
        }
    }
    onMorphClosenessChanged: {
        if (open && morphCloseness > 0.92) {
            settled = true;
        }
    }
    enabled: open
    opacity: open ? (settled ? 1 : Math.pow(morphCloseness, 1.3)) : 0
    visible: opacity > 0.01
    transformOrigin: Item.Center
    scale: surface._entering ? 0.96 : 1

    Rectangle {
        id: _surfaceBg

        anchors.fill: parent
        z: -9999
        color: surface.bgColor
        visible: surface.bgColor !== Qt.rgba(0, 0, 0, 0)
    }

    Timer {
        interval: Motion.glide + 40
        repeat: false
        running: surface.open && surface._entering
        onTriggered: surface._entering = false
    }

    Behavior on scale {
        Anim {
            type: Anim.EmphasizedIn
        }

    }

    transform: Translate {
        id: entryT

        y: surface._entering ? 8 * s : 0

        Behavior on y {
            Anim {
                type: Anim.EmphasizedIn
            }

        }

    }

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }

    }

}
