import QtQuick

// One owner for retargetable dimensions, content exposure and notification breath.
Item {
    id: root
    property real s: 1
    property real targetW: 0
    property real targetH: 0
    property real targetRadius: 0
    property real restW: 0
    property real coreH: 38
    property bool surfaceOpen: false
    property string surfaceName: ""
    property bool workspaceAnimating: false
    property bool notifAnimating: false
    property bool notifHolding: false
    property bool reduceMotion: false
    property int morphDuration: 0
    property int notifCollapseDuration: 0
    readonly property int duration: notifAnimating ? notifCollapseDuration : morphDuration

    width: Math.min(targetW, 2000 * s)
    height: Math.min(targetH, 2000 * s)
    property real radius: targetRadius
    Behavior on width {
        enabled: !root.reduceMotion && (!root.workspaceAnimating || root.surfaceOpen || root.notifAnimating)
        SmoothedAnimation { duration: root.duration; velocity: -1 }
    }
    Behavior on height {
        enabled: !root.reduceMotion
        SmoothedAnimation { duration: root.duration; velocity: -1 }
    }
    Behavior on radius {
        enabled: !root.reduceMotion
        SmoothedAnimation { duration: root.duration; velocity: -1 }
    }
    readonly property real closeness: {
        var dw = Math.max(0.0001, targetW)
        var dh = Math.max(0.0001, targetH)
        var d = Math.max(Math.abs(width - targetW) / dw, Math.abs(height - targetH) / dh)
        return Math.max(0, 1 - d)
    }
    property real lastSurfaceW: 0
    property real lastSurfaceH: 0
    onTargetWChanged: {
        if (surfaceOpen) lastSurfaceW = targetW
        releaseHoldAtRest()
    }
    onTargetHChanged: {
        if (surfaceOpen) lastSurfaceH = targetH
        releaseHoldAtRest()
    }
    // Retorno con la surface aún abierta (fase 2 del cierre del launcher): una
    // reapertura en esa ventana debe volver a exponer el contenido por
    // crecimiento, no opaco dentro de la pill en reposo.
    function releaseHoldAtRest() {
        if (contentHeld && Math.abs(targetW - restW) < 1 && Math.abs(targetH - coreH) < 1)
            contentHeld = false
    }
    readonly property real surfaceGrowth: Math.max(0, Math.min(1, Math.min(
        Math.abs(lastSurfaceW - restW) < 1 ? 1 : (width - restW) / (lastSurfaceW - restW),
        Math.abs(lastSurfaceH - coreH) < 1 ? 1 : (height - coreH) / (lastSurfaceH - coreH))))
    readonly property real growthProgress: Math.max(0, Math.min(1,
        (surfaceGrowth - 0.45) / 0.35))
    // Una vez revelado, el contenido no vuelve a esconderse porque la misma
    // surface cambie de tamaño (p. ej. resultados del launcher al escribir):
    // surfaceGrowth se mide contra el destino nuevo y caía casi a 0, apagando
    // el campo de búsqueda ~200 ms. Cerrar, cambiar de surface o una
    // notificación vuelven a la exposición por crecimiento.
    property bool contentHeld: false
    readonly property real contentProgress: contentHeld ? 1 : growthProgress
    function holdContentIfRevealed() {
        if (surfaceOpen && !notifAnimating && growthProgress >= 0.999) contentHeld = true
    }
    onGrowthProgressChanged: holdContentIfRevealed()
    onSurfaceOpenChanged: if (!surfaceOpen) contentHeld = false
    // Tras evaluar los destinos nuevos: un cambio cuyo crecimiento ya está
    // completo no emite cambio de progreso y quedaría sin retener.
    onSurfaceNameChanged: {
        contentHeld = false
        Qt.callLater(holdContentIfRevealed)
    }
    onNotifAnimatingChanged: if (notifAnimating) contentHeld = false
        else Qt.callLater(holdContentIfRevealed)

    property real breath: 0
    SequentialAnimation on breath {
        running: !root.reduceMotion && root.notifHolding
        loops: Animation.Infinite
        NumberAnimation { from: 0; to: 1; duration: 1400; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1; to: 0; duration: 1400; easing.type: Easing.InOutSine }
    }
    // Entrada/salida continua del hold: sin ella el borde aparecía a 0.20,
    // desaparecía desde ~0.38 y el radio saltaba 2*s al iniciar collapse-out.
    property real holdLevel: notifHolding ? 1 : 0
    Behavior on holdLevel {
        enabled: !root.reduceMotion
        NumberAnimation { duration: root.notifCollapseDuration; easing.type: Easing.InOutSine }
    }
    readonly property real breathLevel: breath * holdLevel
    readonly property real breathRadius: breathLevel * 2 * s
    readonly property real breathGlow: holdLevel * (0.12 + breath * 0.18)
}
