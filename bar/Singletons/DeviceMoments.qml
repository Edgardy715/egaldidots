pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire

/**
 * Isla · DeviceMoments. Momentos breves de dispositivo: Bluetooth (tarjeta),
 * corriente (rayo + porcentaje en la pill), almacenamiento USB (tarjeta con
 * Abrir/Expulsar) y puntos de privacidad de micrófono/cámara.
 *
 * El singleton es cola y política; las fuentes vivas (Quickshell.Bluetooth,
 * UPower, Pipewire, el monitor de udisks) sólo alimentan funciones puras de
 * ingestión (`btConnected`, `ingestPower`, `ingestStorage`, `ingestPrivacy`) que
 * las pruebas llaman con datos simulados. La composición (IslandOverlay) fija
 * `context` y muestra `card`/`powerShown`/`dots`; los componentes hoja reciben
 * datos por propiedades.
 *
 * Reposo silencioso: ningún Timer repetitivo ni FrameAnimation. Los Timers son
 * de un disparo y sólo corren mientras hay un momento (o una transición de
 * privacidad). El único proceso nuevo es el monitor de udisks, sólo si
 * `devices.storage`; no hay sondeo.
 */
Singleton {
    id: root

    // ---- ajustes ----
    readonly property var settings: Config._effective.devices
    readonly property bool enabled: settings.enabled
    readonly property bool bluetoothEnabled: enabled && settings.bluetooth
    readonly property bool powerEnabled: enabled && settings.power
    readonly property bool storageEnabled: enabled && settings.storage
    readonly property bool privacyEnabled: enabled && settings.privacyDots

    // ---- contexto de la composición (monitor con foco) ----
    // surfaceOpen: hay una surface abierta; fullscreen: ventana a pantalla
    // completa; gesture: gesto de arrastre en curso; notification: notificación
    // visible; dnd: no molestar.
    property var context: ({ surfaceOpen: false, fullscreen: false, gesture: false, notification: false, dnd: false })
    onContextChanged: if (pending.length) drainTimer.restart()

    readonly property real lowBatteryLevel: 0.15
    readonly property int privacyHysteresis: 400
    readonly property int pendingLimit: 3
    readonly property int pendingLifetime: 8000

    signal noticeRequested(string text, string kind)
    signal surfaceRequested(string surface)

    // ---- decisión pura ----
    // kind: btConnect | btDisconnect | lowBattery | power | storage
    // Devuelve: drop | defer | notice | card | power
    function featureOn(kind) {
        if (kind === "btConnect" || kind === "btDisconnect" || kind === "lowBattery") return bluetoothEnabled
        if (kind === "power") return powerEnabled
        if (kind === "storage") return storageEnabled
        return false
    }
    function decide(kind) {
        if (!featureOn(kind)) return "drop"
        const c = context || {}
        if (c.gesture) return "defer"
        // La batería baja de un dispositivo conectado se avisa siempre, incluso
        // con pantalla completa o No molestar; es un aviso mínimo, sin tarjeta.
        if (kind === "lowBattery") return "notice"
        if (c.fullscreen || c.dnd) return "drop"
        if (c.notification) return "defer"
        if (c.surfaceOpen) return "notice"
        if (kind === "btDisconnect") return "notice"
        if (kind === "power") return "power"
        return "card"
    }

    // ---- estado del momento activo ----
    property var card: null            // { id, kind, icon, name, device, size, mountPoint, ... }
    property bool cardOpen: false
    property bool cardHovered: false
    property string cardState: "idle"  // idle | ejecting | ejected | error
    property string cardError: ""
    property bool powerShown: false
    property bool powerPlugged: false
    property int powerPercent: 0
    property var pending: []
    readonly property bool busy: cardOpen || powerShown || returning
    // El tragado de la gota necesita su tiempo antes del siguiente momento.
    property bool returning: false
    readonly property int returnTime: 450
    readonly property int cardTime: card && card.kind === "storage" ? 7000 : 3500
    readonly property int powerTime: 2000

    function now() { return Date.now() }

    // Un momento llega aquí; decide entre mostrarlo, avisar, diferirlo o descartarlo.
    function submit(moment) {
        if (!moment || !moment.kind) return "drop"
        const verdict = decide(moment.kind)
        if (verdict === "drop") return verdict
        if (verdict === "notice") { notify(moment); return verdict }
        if (verdict === "defer" || busy) { enqueue(moment); return "defer" }
        present(moment, verdict)
        return verdict
    }
    function noticeText(moment) {
        if (moment.notice) return moment.notice
        const name = moment.name || ""
        if (moment.kind === "btDisconnect") return I18n.tr("%1 desconectado").arg(name)
        if (moment.kind === "lowBattery") return I18n.tr("Batería baja: %1").arg(name + " " + Math.round((moment.level || 0) * 100) + "%")
        if (moment.kind === "power")
            return moment.plugged ? I18n.tr("Cargando · %1%").arg(moment.percent) : I18n.tr("Con batería · %1%").arg(moment.percent)
        return I18n.tr("%1 conectado").arg(name)
    }
    function notify(moment) {
        noticeRequested(noticeText(moment), moment.kind === "lowBattery" ? "attention" : moment.kind === "btDisconnect" ? "cancel" : "connected")
    }
    function enqueue(moment) {
        const list = pending.filter(m => m.id !== moment.id || m.kind !== moment.kind)
        moment.queuedAt = now()
        if (moment.kind === "lowBattery") list.unshift(moment); else list.push(moment)
        while (list.length > pendingLimit) list.pop()
        pending = list
        drainTimer.restart()
    }
    function drain() {
        if (!pending.length) return
        const fresh = pending.filter(m => now() - m.queuedAt <= pendingLifetime)
        pending = fresh
        if (!fresh.length) return
        const first = fresh[0]
        const verdict = decide(first.kind)
        if (verdict === "defer" || (busy && verdict !== "notice" && verdict !== "drop")) {
            drainTimer.restart()
            return
        }
        pending = fresh.slice(1)
        if (verdict === "notice") notify(first)
        else if (verdict !== "drop") present(first, verdict)
        if (pending.length) drainTimer.restart()
    }
    Timer { id: drainTimer; interval: root.returnTime; repeat: false; onTriggered: root.drain() }

    function present(moment, verdict) {
        returning = false
        returnTimer.stop()
        if (verdict === "power") {
            powerPlugged = !!moment.plugged
            powerPercent = Math.round(moment.percent || 0)
            powerShown = true
            return
        }
        cardHovered = false
        cardError = ""
        cardState = "idle"
        card = moment
        cardOpen = true
    }
    // El motor tarda en tragar la gota; hasta entonces no entra otro momento.
    function beginReturn() {
        returning = true
        returnTimer.restart()
    }
    Timer { id: returnTimer; interval: root.returnTime; repeat: false
        onTriggered: { root.returning = false; if (root.pending.length) root.drain() } }

    function dismissCard() {
        if (!cardOpen) return
        cardOpen = false
        cardHovered = false
        beginReturn()
    }
    function dismissPower() {
        if (!powerShown) return
        powerShown = false
        beginReturn()
    }
    // Un aviso de mayor prioridad (notificación) retira la tarjeta sin eco.
    function interrupt() {
        if (cardOpen && cardState !== "ejecting") dismissCard()
        if (powerShown) dismissPower()
    }
    Timer {
        id: cardTimer
        interval: root.cardState === "error" ? 5000 : root.cardState === "ejected" ? 1400 : root.cardTime
        running: root.cardOpen && !root.cardHovered && root.cardState !== "ejecting"
        repeat: false
        onTriggered: root.dismissCard()
    }
    Timer {
        id: powerTimer
        interval: root.powerTime
        running: root.powerShown
        repeat: false
        onTriggered: root.dismissPower()
    }

    // ---- Bluetooth ----
    function deviceKind(icon) {
        const name = String(icon || "").toLowerCase()
        if (name.indexOf("headphone") >= 0 || name.indexOf("headset") >= 0) return "headphones"
        if (name.indexOf("speaker") >= 0 || name.indexOf("audio-card") >= 0 || name.indexOf("audio-input") >= 0) return "speaker"
        if (name.indexOf("gaming") >= 0 || name.indexOf("gamepad") >= 0 || name.indexOf("joystick") >= 0) return "gamepad"
        if (name.indexOf("keyboard") >= 0) return "keyboard"
        if (name.indexOf("mouse") >= 0 || name.indexOf("tablet") >= 0) return "mouse"
        if (name.indexOf("audio") >= 0) return "speaker"
        return ""
    }
    readonly property var kindGlyphs: ({ headphones: "headphones", speaker: "speaker", gamepad: "sports_esports", keyboard: "keyboard", mouse: "mouse" })
    function deviceName(device) { return device ? (device.deviceName || device.name || "") : "" }
    // Lista de baterías: el backend actual da una; si ofreciera `batteries`
    // ([{label, level}]) se muestran todas.
    function batteriesOf(device) {
        if (!device) return []
        if (Array.isArray(device.batteries) && device.batteries.length)
            return device.batteries.filter(b => b && isFinite(b.level)).map(b => ({ label: String(b.label || ""), level: Math.max(0, Math.min(1, b.level)) }))
        if (device.batteryAvailable && isFinite(device.battery)) return [{ label: "", level: Math.max(0, Math.min(1, device.battery)) }]
        return []
    }
    property var btWarned: ({})
    function btKey(device) { return device ? String(device.address || device.name || "") : "" }
    // Una transición de `connected` en un dispositivo ya conocido.
    function btConnected(device, connected) {
        if (!bluetoothEnabled || !device) return "drop"
        const kind = deviceKind(device.icon)
        if (!kind) return "drop"
        const key = btKey(device)
        const warned = Object.assign({}, btWarned)
        delete warned[key]
        btWarned = warned
        if (!connected) return submit({ kind: "btDisconnect", id: key, name: deviceName(device) })
        const verdict = submit({ kind: "btConnect", id: key, name: deviceName(device), device: device, deviceKind: kind })
        btBattery(device)
        return verdict
    }
    // Batería baja: una vez por conexión.
    function btBattery(device) {
        if (!bluetoothEnabled || !device || !device.connected || !deviceKind(device.icon)) return false
        const key = btKey(device)
        if (btWarned[key]) return false
        const low = batteriesOf(device).filter(b => b.level < lowBatteryLevel)
        if (!low.length) return false
        const warned = Object.assign({}, btWarned)
        warned[key] = true
        btWarned = warned
        submit({ kind: "lowBattery", id: key, name: deviceName(device), level: low[0].level })
        return true
    }
    Instantiator {
        model: root.bluetoothEnabled ? Bluetooth.devices : null
        delegate: QtObject {
            id: watch
            required property var modelData
            property bool connected: modelData.connected
            property real battery: modelData.battery
            property bool batteryAvailable: modelData.batteryAvailable
            // La conexión inicial es la línea base, no un evento.
            property bool known: false
            onConnectedChanged: if (known) root.btConnected(modelData, connected)
            onBatteryChanged: if (known) root.btBattery(modelData)
            onBatteryAvailableChanged: if (known) root.btBattery(modelData)
            Component.onCompleted: known = true
        }
    }

    // ---- corriente ----
    property bool powerKnown: false
    property bool pluggedNow: false
    property real percentOverride: -1
    readonly property var batteryDevice: {
        const d = UPower.displayDevice
        return d && d.ready && d.isLaptopBattery && d.isPresent ? d : null
    }
    readonly property int livePercent: percentOverride >= 0 ? Math.round(percentOverride)
        : batteryDevice ? Math.round(batteryDevice.percentage * 100) : 0
    onLivePercentChanged: if (powerShown) powerPercent = livePercent
    function ingestPower(plugged, percent) {
        if (!powerEnabled) return "drop"
        if (plugged === pluggedNow) return "drop"
        pluggedNow = plugged
        if (percent !== undefined) percentOverride = percent
        return submit({ kind: "power", id: "power", plugged: plugged, percent: livePercent })
    }
    readonly property bool upowerOnBattery: UPower.onBattery
    onUpowerOnBatteryChanged: if (powerKnown && batteryDevice) ingestPower(!upowerOnBattery)
    // ¿El momento de corriente reemplaza al chip de batería existente?
    function ownsPowerTransition() { return powerEnabled && decide("power") !== "drop" }

    // ---- almacenamiento USB ----
    property var storageSeen: ({})
    property string storageError: ""
    property var runner: null           // (argv, done(code, stderr)) para pruebas
    property var executed: []           // registro de órdenes lanzadas (diagnóstico)
    function sizeText(bytes) {
        if (!isFinite(bytes) || bytes <= 0) return ""
        const units = ["B", "KB", "MB", "GB", "TB"]
        let value = bytes, index = 0
        while (value >= 1000 && index < units.length - 1) { value /= 1000; index++ }
        return (value >= 100 || index === 0 ? Math.round(value) : value.toFixed(1)) + " " + units[index]
    }
    function ingestStorage(line) {
        if (!storageEnabled || typeof line !== "string" || line.length > 8192) return "drop"
        let message
        try { message = JSON.parse(line) } catch (_) { return "drop" }
        if (!message || typeof message !== "object") return "drop"
        if (message.event === "error") { storageError = String(message.message || ""); return "error" }
        if (typeof message.id !== "string") return "drop"
        if (message.event === "removed") {
            const seen = Object.assign({}, storageSeen)
            delete seen[message.id]
            storageSeen = seen
            pending = pending.filter(m => m.id !== message.id)
            if (card && card.id === message.id && cardState !== "ejecting") dismissCard()
            return "removed"
        }
        if (message.event !== "mounted" || typeof message.mountPoint !== "string" || !message.mountPoint.length) return "drop"
        if (storageSeen[message.id]) return "drop"
        const seen = Object.assign({}, storageSeen)
        seen[message.id] = true
        storageSeen = seen
        return submit({ kind: "storage", id: message.id, name: String(message.name || "USB").slice(0, 80),
            size: Number(message.size) || 0, sizeLabel: sizeText(Number(message.size) || 0),
            mountPoint: message.mountPoint, device: String(message.device || ""), drive: String(message.drive || "") })
    }
    function execute(argv, done) {
        executed = executed.concat([argv])
        if (runner) { runner(argv, done); return }
        const p = runComp.createObject(root, { command: argv, done: done })
        if (p) p.running = true
        else done(-1, "")
    }
    Component {
        id: runComp
        Process {
            id: proc
            property var done
            stderr: StdioCollector { id: errors }
            onExited: code => { const callback = done; const text = errors.text; proc.destroy(); callback(code, text) }
        }
    }
    function openMount() {
        if (!card || card.kind !== "storage") return false
        execute(["xdg-open", card.mountPoint], () => {})
        dismissCard()
        return true
    }
    // unmount y después power-off de la unidad; un fallo deja un error amable.
    function eject() {
        if (!card || card.kind !== "storage" || cardState === "ejecting") return false
        const moment = card
        cardState = "ejecting"
        cardError = ""
        const fail = () => {
            if (card !== moment) return
            cardState = "error"
            cardError = I18n.tr("No se pudo expulsar. Inténtalo de nuevo.")
        }
        execute(["udisksctl", "unmount", "-b", moment.device], (code) => {
            if (card !== moment) return
            if (code !== 0) { fail(); return }
            if (!moment.drive) { cardState = "ejected"; return }
            execute(["udisksctl", "power-off", "-b", moment.drive], (powerCode) => {
                if (card !== moment) return
                if (powerCode !== 0) fail(); else cardState = "ejected"
            })
        })
        return true
    }
    Process {
        id: monitor
        command: ["python3", Quickshell.shellDir + "/scripts/isla-device-storage"]
        running: root.storageEnabled && !root.runner
        stdout: SplitParser { onRead: line => root.ingestStorage(line) }
    }

    // ---- intención de apertura (consumida una vez por la surface) ----
    property string connectivityMode: ""
    property string mixerPage: ""
    property double intentAt: 0
    function consumeIntent(name) {
        const value = name === "connectivity" ? connectivityMode : mixerPage
        const fresh = value.length && now() - intentAt < 4000
        if (name === "connectivity") connectivityMode = ""; else mixerPage = ""
        return fresh ? value : ""
    }
    // Clic en la tarjeta de Bluetooth: Conectividad, pestaña Bluetooth.
    function activateCard() {
        if (!card) return
        if (card.kind === "bluetooth" || card.kind === "btConnect") {
            connectivityMode = "bluetooth"
            intentAt = now()
            surfaceRequested("connectivity")
            dismissCard()
        }
    }
    // Clic en un punto de privacidad: Sonido, página de entrada.
    function activatePrivacy() {
        if (!micActive) return
        mixerPage = "input"
        intentAt = now()
        surfaceRequested("mixer")
    }

    // ---- privacidad de micrófono y cámara ----
    // Histéresis simétrica: un estado sólo cambia si se mantiene 400 ms, así un
    // enlace breve no hace parpadear el punto. Dos Timers de un disparo.
    property bool rawMic: false
    property bool rawCam: false
    property bool micActive: false
    property bool camActive: false
    property string micApp: ""
    property string camApp: ""
    function ingestPrivacy(streams) {
        if (!privacyEnabled) { rawMic = false; rawCam = false; return }
        const list = Array.isArray(streams) ? streams : []
        const mic = list.filter(s => s && s.kind === "mic")
        const cam = list.filter(s => s && s.kind === "camera")
        if (mic.length) micApp = mic.map(s => s.app).filter(Boolean).filter((v, i, a) => a.indexOf(v) === i).join(", ")
        if (cam.length) camApp = cam.map(s => s.app).filter(Boolean).filter((v, i, a) => a.indexOf(v) === i).join(", ")
        rawMic = mic.length > 0
        rawCam = cam.length > 0
    }
    onRawMicChanged: micTimer.restart()
    onRawCamChanged: camTimer.restart()
    onPrivacyEnabledChanged: if (!privacyEnabled) { rawMic = false; rawCam = false; micActive = false; camActive = false }
    Timer { id: micTimer; interval: root.privacyHysteresis; repeat: false; onTriggered: root.micActive = root.rawMic }
    Timer { id: camTimer; interval: root.privacyHysteresis; repeat: false; onTriggered: root.camActive = root.rawCam }

    // Fuente viva: enlaces activos de Pipewire. Se ignoran las lecturas de la
    // propia shell (medidores).
    readonly property var linkGroups: root.privacyEnabled ? Pipewire.linkGroups.values : []
    readonly property var linkedNodes: {
        const nodes = []
        for (const group of root.linkGroups) {
            if (group && group.source) nodes.push(group.source)
            if (group && group.target) nodes.push(group.target)
        }
        return nodes
    }
    PwObjectTracker { objects: root.linkedNodes }
    PwObjectTracker { objects: root.linkGroups }
    function appName(node) {
        if (!node) return ""
        const p = node.properties || {}
        return p["application.name"] || p["application.process.binary"] || node.nickname || node.description || node.name || ""
    }
    readonly property var liveStreams: {
        const result = []
        for (const group of root.linkGroups) {
            if (!group || group.state !== PwLinkState.Active || !group.source || !group.target) continue
            const source = group.source, target = group.target
            const app = root.appName(target)
            const bin = (target.properties || {})["application.process.binary"] || ""
            if (/quickshell|isla|cava|peak|parec|pw-cat|pw-record/i.test(app + " " + bin)) continue
            // Los monitores de salida (medidores de la propia shell) no son un micrófono.
            if (/\.monitor$/.test(source.name || "") || source.isSink) continue
            // Cámara real: v4l2/libcamera o rol Camera; un flujo de captura de pantalla no lo es.
            const sp = source.properties || {}
            const isCamera = sp["media.role"] === "Camera" || sp["device.api"] === "v4l2" || sp["device.api"] === "libcamera"
                || /^(v4l2|libcamera)/.test(source.name || "")
            if (source.type === PwNodeType.VideoSource && isCamera) result.push({ kind: "camera", app: app })
            else if (source.type === PwNodeType.AudioSource && target.type === PwNodeType.AudioInStream)
                result.push({ kind: "mic", app: app })
        }
        return result
    }
    onLiveStreamsChanged: if (privacyEnabled) ingestPrivacy(liveStreams)

    Component.onCompleted: {
        pluggedNow = !UPower.onBattery
        powerKnown = true
    }
}
