import QtQuick
import "../Singletons"

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

    // ---- geometría: muelle físico para surfaces; SmoothedAnimation para el resto ----
    // Abrir, cambiar y cerrar surfaces integran un muelle retargeteable que conserva
    // la velocidad (Motion.surfaceSpring). Las notificaciones, el aviso de workspace y
    // el movimiento reducido mantienen su ruta anterior (Behavior + SmoothedAnimation).
    property var spring: Motion.surfaceSpring
    readonly property real clampedW: Math.min(targetW, 2000 * s)
    readonly property real clampedH: Math.min(targetH, 2000 * s)
    property real springW: clampedW
    property real springH: clampedH
    property real velW: 0
    property real velH: 0
    property bool integrating: false
    // Dirección latcheada del último retarget (signo del recorrido); closeness la usa
    // para no penalizar el rebase.
    property int dirW: 1
    property int dirH: 1
    property real spanW: 1
    property real spanH: 1
    property var paramsW: spring.open.w
    property var paramsH: spring.open.h
    // El tipo (open/resize/close) se decide en el primer paso tras el retarget, cuando
    // los destinos y el estado de la surface ya se evaluaron todos.
    property bool kindDirtyW: false
    property bool kindDirtyH: false
    property string kindW: "open"
    property string kindH: "open"
    property real latchedW: clampedW
    property real latchedH: clampedH
    // La altura decide si manda el muelle: el aviso de workspace sólo cambia el ancho.
    readonly property bool springOn: !reduceMotion && !notifAnimating
        && (surfaceOpen || integrating || targetH > coreH + 1 || springH > coreH + 1)
    readonly property real timeScale: Math.max(0.05, Flags.motionScale)

    width: springOn ? springW : clampedW
    height: springOn ? springH : clampedH
    property real radius: targetRadius
    Behavior on width {
        enabled: !root.reduceMotion && !root.springOn
            && (!root.workspaceAnimating || root.surfaceOpen || root.notifAnimating)
        SmoothedAnimation { duration: root.duration; velocity: -1 }
    }
    Behavior on height {
        enabled: !root.reduceMotion && !root.springOn
        SmoothedAnimation { duration: root.duration; velocity: -1 }
    }
    Behavior on radius {
        enabled: !root.reduceMotion
        SmoothedAnimation { duration: root.duration; velocity: -1 }
    }
    // Fuera del muelle el muelle sigue al valor real para tomar el relevo sin salto.
    onWidthChanged: if (!springOn) { springW = width; velW = 0 }
    onHeightChanged: if (!springOn) { springH = height; velH = 0 }

    function atRest(w, h) { return Math.abs(w - restW) < 1 && Math.abs(h - coreH) < 1 }
    function kindFor() {
        if (atRest(targetW, targetH)) return "close"
        if (surfaceOpen && contentHeld) return "resize"
        return "open"
    }
    // Fija inicio/dirección/parámetros del tramo; la posición y la velocidad actuales se conservan.
    function retarget() {
        var changed = false
        if (clampedW !== latchedW) {
            latchedW = clampedW
            var dw = clampedW - width
            dirW = dw >= 0 ? 1 : -1
            spanW = Math.max(Math.abs(dw), 8 * s)
            kindDirtyW = true
            changed = true
        }
        if (clampedH !== latchedH) {
            latchedH = clampedH
            var dh = clampedH - height
            dirH = dh >= 0 ? 1 : -1
            spanH = Math.max(Math.abs(dh), 8 * s)
            kindDirtyH = true
            changed = true
        }
        if (changed && springOn && !integrating) integrating = true
    }
    function accel(x, v, target, p, dir, span) {
        var e = x - target
        var band = Math.max(p.band * span, s)
        var b = Math.max(0, Math.min(1, e * dir / band))
        var k = b * b * (3 - 2 * b)
        var w = p.omega + (p.omegaFar - p.omega) * k
        var z = p.zeta + (p.zetaFar - p.zeta) * k
        return -w * w * e - 2 * z * w * v
    }
    // Recupera cuadros tardíos con subpasos estables. Dos segundos de tiempo del
    // muelle bastan para asentar los perfiles actuales y acotan una suspensión larga.
    function step(dt) {
        if (!isFinite(dt) || dt <= 0) return
        dt = Math.min(dt / timeScale, 2)
        if (kindDirtyW) { kindW = kindFor(); paramsW = spring[kindW].w; kindDirtyW = false }
        if (kindDirtyH) { kindH = kindFor(); paramsH = spring[kindH].h; kindDirtyH = false }
        var n = Math.max(1, Math.ceil(dt * 240))
        var h = dt / n
        var tw = clampedW, th = clampedH
        var x = springW, y = springH, vx = velW, vy = velH
        for (var i = 0; i < n; ++i) {
            vx += accel(x, vx, tw, paramsW, dirW, spanW) * h
            x += vx * h
            vy += accel(y, vy, th, paramsH, dirH, spanH) * h
            y += vy * h
        }
        var d = Motion.surfaceSettleDistance * s, sp = Motion.surfaceSettleSpeed * s
        if (Math.abs(x - tw) < d && Math.abs(vx) < sp) { x = tw; vx = 0 }
        if (Math.abs(y - th) < d && Math.abs(vy) < sp) { y = th; vy = 0 }
        // Publica sólo el estado del cuadro, no cada subpaso del integrador.
        velW = vx; velH = vy; springW = x; springH = y
        if (springW === tw && springH === th) integrating = false
    }
    // Las pruebas avanzan el muelle a mano con step(dt) para ser deterministas.
    property bool manualStep: false
    FrameAnimation {
        running: root.integrating && root.springOn && !root.manualStep
        onTriggered: root.step(frameTime)
    }
    onClampedWChanged: retarget()
    onClampedHChanged: retarget()
    onSpringOnChanged: if (springOn) {
        retarget()
        if (springW !== clampedW || springH !== clampedH) integrating = true
    }
    // Una vez en reposo el muelle ya no manda; si se pierde el relevo, nunca se queda a medias.
    onReduceMotionChanged: if (reduceMotion) { integrating = false; springW = clampedW; springH = clampedH; velW = 0; velH = 0 }

    // Rebasar el destino cuenta como llegado: el contenido de reposo no debe atenuarse
    // por un retroceso de menos de ~1 % del muelle.
    readonly property real closeness: {
        var dw = Math.max(0.0001, targetW)
        var dh = Math.max(0.0001, targetH)
        var ew = (width - targetW) * dirW > 0 ? 0 : Math.abs(width - targetW)
        var eh = (height - targetH) * dirH > 0 ? 0 : Math.abs(height - targetH)
        var d = Math.max(ew / dw, eh / dh)
        return Math.max(0, 1 - d)
    }
    // Retorno del contenido de reposo: mide el error contra el recorrido del muelle, no
    // contra el tamaño de destino (42 px de alto dejaban el reloj fuera hasta los últimos
    // píxeles del rebote, ~170 ms de pill vacía). Entra en el último 28 % del recorrido.
    readonly property real restReturn: {
        if (!springOn) return Math.pow(closeness, 1.2)
        var ew = (width - targetW) * dirW > 0 ? 0 : Math.abs(width - targetW)
        var eh = (height - targetH) * dirH > 0 ? 0 : Math.abs(height - targetH)
        var d = Math.max(ew / Math.max(spanW, 1), eh / Math.max(spanH, 1))
        return Math.max(0, Math.min(1, (1 - d - 0.72) / 0.28))
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
    // Abrir revela entre 12 % y 40 % del crecimiento (Motion.openContent*); cerrar (destino = reposo) retira
    // el contenido antes, entre 90 % y 60 %, para que no cruce la pill que se contrae.
    readonly property bool closingToRest: !notifAnimating && atRest(targetW, targetH)
    readonly property real growthProgress: closingToRest
        ? Math.max(0, Math.min(1, (surfaceGrowth - Motion.closeContentFull)
                                  / (Motion.closeContentStart - Motion.closeContentFull)))
        : Math.max(0, Math.min(1, (surfaceGrowth - Motion.openContentStart) / Motion.openContentSpan))
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
        NumberAnimation { from: 0; to: 1; duration: 1400; easing.type: Motion.easeBreathe }
        NumberAnimation { from: 1; to: 0; duration: 1400; easing.type: Motion.easeBreathe }
    }
    // Entrada/salida continua del hold: sin ella el borde aparecía a 0.20,
    // desaparecía desde ~0.38 y el radio saltaba 2*s al iniciar collapse-out.
    property real holdLevel: notifHolding ? 1 : 0
    Behavior on holdLevel {
        enabled: !root.reduceMotion
        NumberAnimation { duration: root.notifCollapseDuration; easing.type: Motion.easeBreathe }
    }
    readonly property real breathLevel: breath * holdLevel
    readonly property real breathRadius: breathLevel * 2 * s
    readonly property real breathGlow: holdLevel * (0.12 + breath * 0.18)
}
