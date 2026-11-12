pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

/** Adaptador de NotificationServer para notificaciones, cola de popups, persistencia e IPC "notifctl".
 * Inspirado en caelestia services/Notifs.qml.
 */
Singleton {
    id: root

    property var list: []
    readonly property var notClosed: { void root.listVersion; return root.list.filter(function(n) { return !n.closed }) }
    readonly property var popups:   { void root.listVersion; return root.list.filter(function(n) { return n.popup }) }
    readonly property int count: notClosed.length

    /**
     * activePopup: la notif que la pill está mostrando AHORA (morph Dynamic Island).
     * Una a la vez. La cola es lógica: cuando la pill termina su ciclo (colapso→
     * retorno), pill.qml avisa via advancePopup() y saca la que Terminó de la cola.
     * Si hay más en popups, la siguiente se asigna y la pill arranca otro ciclo.
     * null cuando no hay nada activo (pill en reposo).
     */
    property var activePopup: null
    property var activityTrackers: ({})
    function activityNotification(notif) {
        if (!Activities.notification(notif)) return false
        if (!activityTrackers[notif.id])
            activityTrackers[notif.id] = activityTracker.createObject(root, {notification: notif, finish: root.activityClosed})
        return true
    }

    function activityClosed(id) {
        Activities.dispatch({op: "end", id: "notification:" + id, state: "done"})
        delete activityTrackers[id]
    }

    /**
     * Avanza la cola: la pill llama esto al terminar su ciclo morph de la notif
     * activa. Quita el popup de activePopup (popup=false) y si hay más en la cola,
     * asigna la siguiente a activePopup (la pill detecta el cambio y arranca el
     * ciclo de la nueva). Si no hay más, activePopup=null → pill vuelve a reposo.
     */
    function advancePopup(shown) {
        const completed = shown
        if (completed) {
            completed.popup = false
            if (completed.ephemeral) Qt.callLater(function() { completed.close() })
        }
        if (root.activePopup && root.activePopup !== completed && root.activePopup.popup) return
        root.activePopup = root._nextPopup()
    }

    /** Siguiente toast por orden de llegada (list guarda la más nueva primero); una crítica se adelanta. */
    function _nextPopup() {
        const queue = root.popups
        let next = null
        for (let i = queue.length - 1; i >= 0; --i) {
            if (queue[i].isCritical) return queue[i]
            if (!next) next = queue[i]
        }
        return next
    }

    /**
     * Cuando llega una notif nueva (popup=true) y no hay activePopup, la asigna
     * inmediatamente. Si ya hay una activa, esperará en la cola (popups) y se
     * asignará cuando advancePopup() la promocione.
     */
    function _maybePromote() {
        const critical = root.popups.find(n => n.isCritical)
        if (critical && root.activePopup && !root.activePopup.isCritical) {
            root.activePopup = root._nextPopup()
        } else if ((!root.activePopup || !root.activePopup.popup || root.activePopup.closed) && root.popups.length > 0) {
            root.activePopup = root._nextPopup()
        } else if (root.activePopup && root.popups.length === 0) {
            // la activa ya expiró/cerró y no hay más → null
            root.activePopup = null
        }
    }

    /** DND persistido. Ahoga toasts (las entradas igual entran al centro). */
    property bool dnd: false
    /** True mientras el centro (surface "notifs") está abierto — shell.qml lo fija. */
    property bool centerOpen: false
    /** flag "ready" tras carga/restauración, para no persistir antes de leer disco. */
    property bool loaded: false
    property bool stateReady: false
    property bool pendingSave: false

    /** Fuerza el re-filtrado: QML no observa cambios de propiedades dentro de los objetos de list. */
    property int listVersion: 0
    function _bump() {
        root.listVersion++
        // _maybePromote se pospone para salir de cualquier evaluación de binding
        // vigente (evita "Binding loop for property notClosed/popups").
        Qt.callLater(root._maybePromote)
    }

    /** quita una NotifData de la lista (la llama NotifData.close tras soltar locks). */
    function _remove(item) {
        root.list = root.list.filter(function(n) { return n !== item })
        root._bump()
    }

    /** Pausa anidable del toast: conserva el tiempo restante del timer actual. */
    function pauseExpiration(notif) {
        if (!notif || !notif.expireTimer || notif.expireInterval <= 0 || notif.isCritical) return
        if (notif._expirationPauseDepth === undefined) {
            notif._expirationPauseDepth = 0
            notif._expirationRemaining = 0
        }
        if (notif._expirationPauseDepth++ > 0) return
        const timer = notif.expireTimer
        notif._expirationRemaining = timer.running
                ? Math.max(0, notif._expirationInterval - (Date.now() - notif._expirationStartedAt)) : 0
        notif._expirationPaused = true
        timer.stop()
    }

    function resumeExpiration(notif) {
        if (!notif || !notif._expirationPauseDepth) return
        if (--notif._expirationPauseDepth > 0) return
        const remaining = notif._expirationRemaining
        notif._expirationPaused = false
        if (notif.popup && !notif.closed && remaining >= 0) {
            notif.expireTimer.interval = Math.max(1, remaining)
            notif.expireTimer.restart()
        }
    }

    /** Lleva la notificación al principio del orden visible del centro. */
    function promote(notif) {
        if (!notif || notif.closed) return
        const index = root.list.indexOf(notif)
        if (index < 0) return
        if (index > 0) root.list = [notif].concat(root.list.filter(function(n) { return n !== notif }))
        root._bump()
    }

    function dismissGesture(notif) {
        if (notif && !notif.closed) notif.close()
    }

    // ---- path de estado (XDG) ----
    readonly property string stateBase: {
        var x = Quickshell.env("XDG_STATE_HOME")
        return (x && x.length > 0) ? x : (Quickshell.env("HOME") + "/.local/state")
    }
    readonly property string stateDir: stateBase + "/quickshell"
    readonly property string stateFile: stateDir + "/notifs.json"

    function shouldShowPopup() {
        return !root.dnd && !root.centerOpen
    }

    function toggleDnd() { root.dnd = !root.dnd; root._persistSoon() }

    function postLocal(summary, body, actions, localId) {
        const item = notifComp.createObject(root, {
            popup: root.shouldShowPopup(), summary: summary, body: body,
            appName: "Azog", appIcon: "system-software-update", notificationId: localId || "",
            actions: actions || []
        })
        root.list = [item].concat(root.list)
        root._bump()
    }

    /** Quita todo el historial visible en una sola operación. */
    function clearAll() {
        var ns = root.notClosed.slice()
        for (var i = 0; i < ns.length; i++) ns[i].close()
    }

    /** al abrir el centro: oculta toasts en pantalla (no los cierra del historial). */
    function clearToasts() {
        for (var i = 0; i < root.list.length; i++) root.list[i].popup = false
    }

    onListChanged: if (root.loaded) _persistSoon()
    onDndChanged: if (root.loaded) _persistSoon()

    // ---- persistencia ----
    function _persistSoon() {
        root.pendingSave = true
        if (root.stateReady) saveTimer.restart()
    }
    Timer {
        id: saveTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (!root.loaded || !root.stateReady || !root.pendingSave) return
            storage.setText(JSON.stringify({
                dnd: root.dnd,
                notifs: root.notClosed.map(function(n) { return n._serialize() })
            }))
            root.pendingSave = false
        }
    }

    // ---- servidor D-Bus ----
    NotificationServer {
        id: server
        keepOnReload: false
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        imageSupported: true
        persistenceSupported: true
        onNotification: function(notif) {
            notif.tracked = true
            if (root.activityNotification(notif)) return
            var d = notifComp.createObject(root, {
                popup: root.shouldShowPopup(),
                notification: notif,
                notificationId: notif.id,
                summary: notif.summary,
                body: notif.body,
                appIcon: notif.appIcon,
                appName: notif.appName,
                image: notif.image,
                urgency: notif.urgency,
                resident: notif.resident,
                ephemeral: notif.transient,
                hasActionIcons: notif.hasActionIcons,
                expireTimeout: notif.expireTimeout,
                hints: notif.hints
            })
            // Sin toast (DND / centro abierto) un aviso efímero no deja rastro.
            if (d.ephemeral && !d.popup) { d.close(); return }
            root.list = [d].concat(root.list)
            root._bump()   // promote a activePopup si no hay una activa
        }
    }

    Component {
        id: activityTracker
        QtObject {
            id: tracker
            required property var notification
            required property var finish
            property Connections changes: Connections {
                target: tracker.notification
                function onHintsChanged() { Activities.notification(tracker.notification) }
                function onSummaryChanged() { Activities.notification(tracker.notification) }
                function onBodyChanged() { Activities.notification(tracker.notification) }
                function onClosed(reason) {
                    tracker.finish(tracker.notification.id)
                    tracker.destroy()
                }
            }
        }
    }

    FileView {
        id: storage
        printErrors: false
        watchChanges: false
        // path completo; el dir lo crea el Process de abajo
        path: root.stateFile
        onLoaded: {
            try {
                var data = JSON.parse(storage.text())
                if (data && data.dnd) root.dnd = true
                var arr = (data && data.notifs) ? data.notifs : []
                var rebuilt = []
                for (var i = 0; i < arr.length; i++) {
                    var s = arr[i]
                    var props = {
                        popup: false,                 // no re-toastear tras reload
                        notification: null,           // display-only
                        notificationId: s.notificationId || s.id || "",
                        summary: s.summary || "",
                        body: s.body || "",
                        appIcon: s.appIcon || "",
                        appName: s.appName || "",
                        image: s.image || "",
                        urgency: s.urgency !== undefined ? s.urgency : NotificationUrgency.Normal,
                        resident: !!s.resident,
                        hasActionIcons: !!s.hasActionIcons,
                        expireTimeout: s.expireTimeout !== undefined ? s.expireTimeout : -1,
                        time: new Date(s.time || Date.now()),
                        actions: _restoreActionsText(s.actions, s.notificationId || s.id, s.appName)
                    }
                    rebuilt.push(notifComp.createObject(root, props))
                }
                rebuilt.sort(function(a, b) { return b.time.getTime() - a.time.getTime() })
                const live = root.list.filter(n => n.notification !== null)
                root.list = live.concat(rebuilt)
                if (live.length) root._persistSoon()
            } catch (e) { /* archivo corrupto→ arrancar vacío */ }
            root.loaded = true
        }
        onLoadFailed: function(err) {
            if (err === FileViewError.FileNotFound) {
                root.loaded = true
                root._persistSoon()
            }
        }
        function _restoreActionsText(a, notificationId, appName) {
            if (!a) return []
            return a.map(function(x) {
                const localUpdate = appName === "Azog" && notificationId === "isla:updates" && x.identifier === "updates"
                return { identifier: x.identifier || "", text: x.text || "",
                    invoke: function() { if (localUpdate) SystemUpdates.open() } }
            })
        }
    }

    // crea el dir de estado si no existe (one-shot)
    Process {
        running: true
        command: ["mkdir", "-p", root.stateDir]
        onExited: code => {
            root.stateReady = code === 0
            if (root.stateReady && root.pendingSave) saveTimer.restart()
        }
    }

    // ---- IPC para scripting (reemplaza swaync-client) ----
    // count()/popupCount() son además el sondeo E2E: un notify-send que los haga
    // subir = la cadena NotificationServer→NotifData→Notifs.list está viva.
    IpcHandler {
        target: "notifctl"
        function clear(): void { root.clearAll() }
        function dismissAll(): void { root.clearAll() }
        function dnd(): bool { return root.dnd }
        function toggleDnd(): void { root.toggleDnd() }
        function enableDnd(): void { root.dnd = true; root._persistSoon() }
        function disableDnd(): void { root.dnd = false; root._persistSoon() }
        function count(): int { void root.listVersion; return root.notClosed.length }
        function popupCount(): int { void root.listVersion; return root.popups.length }
    }

    Component {
        id: notifComp
        NotifData {
            id: notifData
            property int _expirationPauseDepth: 0
            property int _expirationRemaining: 0
            property bool _expirationPaused: false
            property double _expirationStartedAt: Date.now()
            property int _expirationInterval: expireInterval
            readonly property Connections expirationTimerState: Connections {
                target: notifData.expireTimer
                function onRunningChanged() {
                    if (notifData.expireTimer.running && !notifData._expirationPaused) {
                        notifData._expirationStartedAt = Date.now()
                        notifData._expirationInterval = notifData.expireTimer.interval
                        notifData._expirationRemaining = notifData._expirationInterval
                    } else if (!notifData.expireTimer.running && !notifData._expirationPaused) {
                        notifData.expireTimer.interval = notifData.expireInterval
                    }
                }
                function onTriggered() { notifData.expireTimer.interval = notifData.expireInterval }
            }
        }
    }
}
