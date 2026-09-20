pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

/**
 * Isla · Notifs. Reemplaza total swaync. Posee el bus org.freedesktop.Notifications
 * via NotificationServer (antes lo evitábamos por conflicto D-Bus con swaync — swaync
 * mascarado+detenido ahora libera el nombre). Molde caelestia services/Notifs.qml:
 *
 *  - list[] de NotifData (vivos del server + restaurados de disco). notClosed y
 *    popups se re-filtran al cambiar listVersion (bumped por NotifData en popup/closed
 *    toggle — QML no re-evalúa bindings por cambios en items, hay que avisarle).
 *  - shouldShowPopup(): !dnd && !centerOpen. El centro abierto ahoga toasts (no
 *    duplicar), DND ahoga todos.
 *  - Persistencia a ~/.local/state/quickshell/notifs.json ({dnd, notifs:[]}) via
 *    FileView, debounced 1s al cambiar list. Restaura al cargar (popup:false — no
 *    re-toastea).
 *  - IpcHandler "notifctl" para scripting (reemplaza swaync-client -d/-C).
 *
 * Cero springs. Cero CPU en reposo (sin timers del servicio; cada NotifData tiene
 * el suyo sólo mientras viva).
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

    /**
     * Avanza la cola: la pill llama esto al terminar su ciclo morph de la notif
     * activa. Quita el popup de activePopup (popup=false) y si hay más en la cola,
     * asigna la siguiente a activePopup (la pill detecta el cambio y arranca el
     * ciclo de la nueva). Si no hay más, activePopup=null → pill vuelve a reposo.
     */
    function advancePopup() {
        if (root.activePopup) {
            root.activePopup.popup = false
        }
        var next = root.popups.length > 0 ? root.popups[0] : null
        root.activePopup = next
    }

    /**
     * Cuando llega una notif nueva (popup=true) y no hay activePopup, la asigna
     * inmediatamente. Si ya hay una activa, esperará en la cola (popups) y se
     * asignará cuando advancePopup() la promocione.
     */
    function _maybePromote() {
        if (!root.activePopup && root.popups.length > 0) {
            root.activePopup = root.popups[0]
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

    /** bump de versión para que notClosed/popups re-filtren al togglear items. */
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

    /** Quita todo el historial visible en una sola operación. */
    function clearAll() {
        var ns = root.notClosed.slice()
        for (var i = 0; i < ns.length; i++) ns[i].close()
    }

    /** al abrir el centro: oculta toasts en pantalla (no los cierra del historial). */
    function clearToasts() {
        for (var i = 0; i < root.list.length; i++) root.list[i].popup = false
    }

    onListChanged: if (root.loaded) saveTimer.restart()
    onDndChanged: if (root.loaded) saveTimer.restart()

    // ---- persistencia ----
    function _persistSoon() { saveTimer.restart() }
    Timer {
        id: saveTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (!root.loaded) return
            storage.setText(JSON.stringify({
                dnd: root.dnd,
                notifs: root.notClosed.map(function(n) { return n._serialize() })
            }))
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
                hasActionIcons: notif.hasActionIcons,
                expireTimeout: notif.expireTimeout,
                hints: notif.hints
            })
            root.list = [d].concat(root.list)
            root._bump()   // promote a activePopup si no hay una activa
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
                        actions: _restoreActionsText(s.actions)
                    }
                    rebuilt.push(notifComp.createObject(root, props))
                }
                rebuilt.sort(function(a, b) { return b.time.getTime() - a.time.getTime() })
                root.list = rebuilt
            } catch (e) { /* archivo corrupto→ arrancar vacío */ }
            root.loaded = true
        }
        onLoadFailed: function(err) {
            root.loaded = true
            if (err === FileViewError.FileNotFound)
                storage.setText(JSON.stringify({ dnd: false, notifs: [] }))
        }
        function _restoreActionsText(a) {
            if (!a) return []
            return a.map(function(x) { return { identifier: x.identifier || "", text: x.text || "", invoke: function() {} } })
        }
    }

    // crea el dir de estado si no existe (one-shot)
    Process {
        running: true
        command: ["mkdir", "-p", root.stateDir]
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
        NotifData {}
    }
}
