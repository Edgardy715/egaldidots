import QtQuick

// Notification timing and surface suspension; no queue or rendering ownership.
QtObject {
    id: root
    property bool surfaceOpen: false
    property int collapseDuration: 0
    property int expandDuration: 0
    property int holdDuration: 0
    property int restoreDuration: 0
    property var activeNotif: null
    property bool notifAnimating: false
    property bool surfaceNotifSuspended: false
    property real surfaceReveal: 1
    signal advanceRequested()

    // ---- State machine: morph notif Dynamic Island ----
    // Ciclo: rest -> collapse(circle) -> expand(notif pill) -> hold(1-2s) -> collapse(circle) -> return(rest)
    // La geometría conserva velocidad al cambiar de destino (SmoothedAnimation).
    // El content gate usa morphCloseness: restContent opacity ~closeness al rest target,
    // notifContent opacity ~closeness al notif pill target (SOLO visible cuando está cerca
    // del tamaño final — el contenido nunca se "corta" durante la transformación).
    //
    // Estados: "idle" | "collapse-in" | "circle" | "expand" | "hold" | "collapse-out" | "return"
    property string notifState: "idle"

    property var popup: null
    onPopupChanged: {
        if (popup) {
            // Si había una restauración pendiente y entra otra notificación,
            // mantenemos la surface fuera hasta que termine toda la secuencia.
            surfaceRestoreTimer.stop()
            // Llega una nueva notif (o se reasigna la actual). Si estamos en idle
            // → ciclo normal. Si ya estamos mostrando otra → forzar la salida y
            // promover esta (la pill termina collapse-out y al volver a idle
            // el binding popup will re-evaluate; si root.advanceRequested() asigna la
            // siguiente, esta misma función entrará por la rama idle).
            // Bug #3: la rama anterior ignoraba !popup durante collapse-in/expand,
            // dejando la pill atascada en tamaño intermedio si la notif se cerraba.
            // Bug #4: la rama anterior solo actuaba si popup && idle, así que una
            // notif que llegaba mientras había otra activa quedaba esperando en
            // cola sin feedback visual. Ahora: si popup cambia y es distinta a la
            // activa (o no había activa), promovemos de inmediato.
            if (notifState === "idle") {
                root.activeNotif = popup
                root.notifAnimating = true
                root._notifToCircleIn()
            } else if (root.activeNotif !== popup) {
                // swap: termina la actual rápido y promueve la nueva
                root._notifToCircleOut()
            }
        } else if (!popup && notifState !== "idle") {
            // la notif expiró o fue cerrada — avance de cola
            if (notifState === "hold" || notifState === "expand" || notifState === "collapse-in")
                root._notifToCircleOut()
            // si ya está en collapse-out/return, dejar terminar
        }
    }

    function _notifToCircleIn() {
        if (surfaceOpen) {
            surfaceReveal = 0
            surfaceNotifSuspended = true
        }
        notifState = "collapse-in"
        // target = circle (morph continuo)
        // dejar que se asiente cerca del círculo antes de expandir
        notifHoldIn.restart()
    }
    property Timer notifHoldInObject: Timer {
        id: notifHoldIn
        interval: root.collapseDuration
        repeat: false
        onTriggered: {
            if (root.notifState === "collapse-in") {
                root.notifState = "expand"
                // target = notif pill (morph de circle -> notif)
                notifExpandTimer.restart()
            }
        }
    }
    property Timer notifExpandTimerObject: Timer {
        id: notifExpandTimer
        interval: root.expandDuration
        repeat: false
        onTriggered: {
            if (root.notifState === "expand") {
                root.notifState = "hold"
                // hold 1-2s
                notifHoldTimer.restart()
            }
        }
    }
    property Timer notifHoldTimerObject: Timer {
        id: notifHoldTimer
        interval: root.holdDuration
        repeat: false
        onTriggered: {
            if (root.notifState === "hold") {
                root._notifToCircleOut()
            }
        }
    }
    function _notifToCircleOut() {
        surfaceRestoreTimer.stop()
        notifState = "collapse-out"
        // target = circle (morph de notif -> circle)
        notifCollapseOutTimer.restart()
    }
    property Timer notifCollapseOutTimerObject: Timer {
        id: notifCollapseOutTimer
        interval: root.collapseDuration
        repeat: false
        onTriggered: {
            if (root.notifState === "collapse-out") {
                root.notifState = "return"
                // target = rest (morph de circle -> rest)
                notifReturnTimer.restart()
            }
        }
    }
    property Timer notifReturnTimerObject: Timer {
        id: notifReturnTimer
        interval: root.expandDuration
        repeat: false
        onTriggered: {
            if (root.notifState === "return") {
                root.notifState = "idle"
                root.notifAnimating = false
                root.activeNotif = null
                if (root.surfaceOpen) surfaceRestoreTimer.restart()
                // avanzar la cola — si hay más popups, se asigna la siguiente
                root.advanceRequested()
            }
        }
    }
    property Timer surfaceRestoreTimerObject: Timer {
        id: surfaceRestoreTimer
        // El target vuelve primero al tamaño de reposo y luego a la surface.
        // Esperamos a que ese segundo morph se asiente antes de revelar el
        // contenido para evitar cualquier frame mezclado.
        interval: root.restoreDuration
        repeat: false
        onTriggered: {
            if (root.notifAnimating || root.activeNotif || !root.surfaceOpen) return
            root.surfaceReveal = 0
            root.surfaceNotifSuspended = false
            root.surfaceReveal = 1
        }
    }

    onSurfaceOpenChanged: {
        if (!surfaceOpen) {
            surfaceRestoreTimer.stop()
            surfaceNotifSuspended = false
            surfaceReveal = 1
        } else if (notifAnimating) {
            surfaceReveal = 0
            surfaceNotifSuspended = true
        }
    }

}
