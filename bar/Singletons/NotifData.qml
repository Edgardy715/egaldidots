import QtQuick
import Quickshell
import Quickshell.Services.Notifications

/**
 * Isla · NotifData. Envoltorio por-notificación (molde caelestia NotifData.qml,
 * sin su infra Colours/Tokens). Espeja lo que NotifCard lee; mantiene un
 * expireTimer que OCULTA el toast (popup=false) sin tocar el historial, y
 * close() lo saca de Notifs.list + dismiss del objeto vivo. timeStr relativo
 * ("ahora"/"5m"/"2h"/"2d"). Para notifs restaurados de disco, notification=null
 * (display-only — las acciones no invocan, queda el texto). Cero springs, cero
 * CPU en reposo (timer parado cuando closed).
 *
 * Locks: una notif puede estar a la vez en el toast (popup) y en el centro
 * (historial) → dos delegates la miran. close() no destruye hasta que suelte el
 * último, para no descuartizar un delegate vivo.
 */
QtObject {
    id: notif

    // ---- estado / API pública que leen los delegates ----
    property bool popup
    property bool closed
    property var locks: new Set()
    property date time: new Date()
    property string timeStr: "ahora"

    // el objeto vivo del NotificationServer, o null si restaurado de disco
    property var notification: null
    property string notificationId: ""
    property string summary: ""
    property string body: ""
    property string appName: ""
    property string appIcon: ""
    property string image: ""
    property int urgency: NotificationUrgency.Normal
    property bool resident: false
    property bool hasActionIcons: false
    property var actions: []        // [{identifier, text, invoke}]
    property var hints: ({})
    property real expireTimeout: -1

    readonly property bool isCritical: urgency === NotificationUrgency.Critical
    /** ¿lleva <markup> en el body? lo decide NotifCard, exponemos aquí una vez. */
    readonly property bool bodyIsRich: /[<&]/.test(body)

    // re-filtrar popups/notClosed en Notifs cuando togglean popup/closed
    // (QML no re-evalúa bindings por cambios en items de la lista — hay que avisar).
    onPopupChanged: Notifs._bump()

    // ---- caducidad del TOAST (sólo oculta, no borra el historial) ----
    readonly property int expireInterval: {
        if (notif.expireTimeout > 0) return notif.expireTimeout
        if (notif.isCritical)        return 0          // sticky
        return notif.urgency === NotificationUrgency.Low ? 4000 : 6000
    }
    readonly property Timer expireTimer: Timer {
        running: notif.popup && notif.expireInterval > 0 && !notif.isCritical
        interval: notif.expireInterval
        repeat: false
        onTriggered: notif.popup = false
    }

    // ---- reloj relativo ----
    readonly property Timer timeStrTimer: Timer {
        running: !notif.closed
        repeat: true
        interval: 5000
        onTriggered: notif.updateTimeStr()
    }
    function updateTimeStr() {
        var diff = Date.now() - notif.time.getTime()
        var m = Math.floor(diff / 60000)
        if (m < 1) { notif.timeStr = "ahora"; notif.timeStrTimer.interval = 5000; return }
        var h = Math.floor(m / 60), d = Math.floor(h / 24)
        if (d > 0)      { notif.timeStr = d + "d"; notif.timeStrTimer.interval = 3600000 }
        else if (h > 0) { notif.timeStr = h + "h"; notif.timeStrTimer.interval = 300000 }
        else            { notif.timeStr = m + "m"; notif.timeStrTimer.interval = m < 10 ? 30000 : 60000 }
    }

    // ---- propagación en vivo del objeto real (no restaurados) ----
    // QtObject NO tiene default property → cada hijo va asignado a una prop con
    // nombre (mismo patrón que expireTimer/timeStrTimer). Espejo de caelestia.
    readonly property Connections conn: Connections {
        enabled: notif.notification !== null
        target: notif.notification
        ignoreUnknownSignals: true
        function onSummaryChanged()        { notif.summary     = notif.notification.summary }
        function onBodyChanged()           { notif.body        = notif.notification.body }
        function onAppIconChanged()        { notif.appIcon     = notif.notification.appIcon }
        function onAppNameChanged()        { notif.appName     = notif.notification.appName }
        function onImageChanged()          { notif.image       = notif.notification.image }
        function onUrgencyChanged()        { notif.urgency     = notif.notification.urgency }
        function onResidentChanged()       { notif.resident    = notif.notification.resident }
        function onHasActionIconsChanged() { notif.hasActionIcons = notif.notification.hasActionIcons }
        function onExpireTimeoutChanged()  { notif.expireTimeout  = notif.notification.expireTimeout }
        function onActionsChanged()        { notif._mirrorActions() }
        function onClosed(reason)          { notif.close() }
    }

    function _mirrorActions() {
        if (!notif.notification) return
        notif.actions = notif.notification.actions.map(function(a) {
            return { identifier: a.identifier, text: a.text, invoke: function() { a.invoke() } }
        })
    }

    // ---- locks (mantener viva mientras un delegate la mira) ----
    function lock(item)   { notif.locks.add(item) }
    function unlock(item) {
        notif.locks.delete(item)
        if (notif.closed) notif.close()
    }

    /** Quita la notif de la lista y libera. Respeta locks: si un delegate aún la
     *  mira (toast + centro comparten la notif), difiere _remove/destroy a unlock.
     *  Reentry-safe: `dismiss()` puede re-emitir `closed` → Connections.onClosed →
     *  close() otra vez. Desacoplamos: descartamos la ref viva ANTES de dismiss, así
     *  el re-trigger llega con notification=null y Connections.target=null lo ignora. */
    property bool _done: false
    function close() {
        if (notif._done) return
        notif.closed = true
        Notifs._bump()
        if (notif.locks.size > 0) return    // defer: unlock() del último delegate re-dispara
        notif._done = true
        var n = notif.notification
        if (n) notif.notification = null    // desconecta Connections (target=null) pre-dismiss
        Notifs._remove(notif)
        if (n) { try { n.dismiss() } catch (e) {} }
        notif.destroy()
    }

    /** snapshot persistible (sin closures — invoke se deja caer). */
    function _serialize() {
        return {
            notificationId: notif.notificationId,
            summary: notif.summary,
            body: notif.body,
            appIcon: notif.appIcon,
            appName: notif.appName,
            image: notif.image,
            urgency: notif.urgency,
            resident: notif.resident,
            hasActionIcons: notif.hasActionIcons,
            expireTimeout: notif.expireTimeout,
            time: notif.time.getTime(),
            actions: notif.actions.map(function(a) { return { identifier: a.identifier, text: a.text } })
        }
    }

    Component.onCompleted: {
        notif.updateTimeStr()
        if (!notif.notification) return     // restaurado de disco: todo ya viene de props
        notif.notificationId  = notif.notification.id
        notif.summary         = notif.notification.summary
        notif.body            = notif.notification.body
        notif.appIcon         = notif.notification.appIcon
        notif.appName         = notif.notification.appName
        notif.image           = notif.notification.image
        notif.urgency         = notif.notification.urgency
        notif.resident        = notif.notification.resident
        notif.hasActionIcons  = notif.notification.hasActionIcons
        notif.expireTimeout   = notif.notification.expireTimeout
        notif.hints           = notif.notification.hints
        notif._mirrorActions()
    }
}
