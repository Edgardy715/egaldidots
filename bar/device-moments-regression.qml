import QtQuick
import QtTest
import Quickshell
import "components"
import "settings"
import "Singletons"

// Momentos de dispositivo: política, cola, Bluetooth, corriente, USB y privacidad
// con datos simulados. No toca Bluetooth, UPower, Pipewire ni discos reales.
ShellRoot {
    id: suite
    settings.watchFiles: false
    property int exitCode: 0
    property var runs: []
    property var codes: ({})
    Timer { id: finish; interval: 100; onTriggered: Qt.exit(suite.exitCode) }
    Window {
        visible: true
        width: 600; height: 400
        EdotsWindow { id: edots; visible: false; width: 1000; height: 700 }
        PrivacyDots { id: dots; x: 20; y: 20; micActive: false; camActive: false }
        DevicePowerMoment { id: powerMoment; x: 100; y: 20; width: 100; height: 20 }
        DeviceMomentCard { id: cardView; x: 20; y: 80 }
        SignalSpy { id: notices; target: DeviceMoments; signalName: "noticeRequested" }
        SignalSpy { id: surfaces; target: DeviceMoments; signalName: "surfaceRequested" }
        TestCase {
            id: tc
            name: "DeviceMoments"
            when: Config.loaded

            function fake(address, icon, battery) {
                return { address: address, name: address + "-n", deviceName: "Dev " + address, icon: icon,
                    connected: true, battery: battery === undefined ? 0 : battery, batteryAvailable: battery !== undefined }
            }
            function reset() {
                DeviceMoments.cardOpen = false; DeviceMoments.card = null; DeviceMoments.powerShown = false
                DeviceMoments.pending = []; DeviceMoments.returning = false; DeviceMoments.cardHovered = false
                DeviceMoments.cardState = "idle"; DeviceMoments.btWarned = ({}); DeviceMoments.storageSeen = ({})
                DeviceMoments.context = { surfaceOpen: false, fullscreen: false, gesture: false, notification: false, dnd: false }
                notices.clear(); surfaces.clear()
                wait(30)
            }
            function noticeText(i) { return notices.signalArguments[i][0] }
            function mounted(id, name) {
                return JSON.stringify({ event: "mounted", id: id, name: name, size: 31914983424, mountPoint: "/run/media/u/" + name,
                    device: "/dev/sd" + id + "1", drive: "/dev/sd" + id })
            }

            function test_devices() {
                try {
                    Config.update({ appearance: { reduceMotion: true } })
                    DeviceMoments.runner = function(argv, done) {
                        suite.runs = suite.runs.concat([argv])
                        const code = suite.codes[argv[0] + " " + argv[1]]
                        done(code === undefined ? 0 : code, code ? "fallo" : "")
                    }
                    wait(50)
                    DeviceMoments.pluggedNow = false

                    // ---- 6. ajustes ----
                    const fx = Config._effective.devices
                    compare(fx.enabled, true); compare(fx.bluetooth, true); compare(fx.power, true)
                    compare(fx.storage, true); compare(fx.privacyDots, true)
                    verify(!Config.update({ devices: { bluetooth: "si" } }).ok)
                    compare(Config._effective.devices.bluetooth, true)
                    verify(Config.update({ devices: { storage: false } }).ok)
                    compare(DeviceMoments.ingestStorage(mounted("a", "X")), "drop")
                    verify(Config.update({ devices: { storage: true } }).ok)
                    console.log("PASS: devices.* defaults true, validated, storage toggle honoured")

                    // ---- 1. Bluetooth ----
                    reset()
                    const buds = fake("AA", "audio-headphones", 0.8)
                    compare(DeviceMoments.btConnected(buds, true), "card")
                    verify(DeviceMoments.cardOpen)
                    compare(DeviceMoments.card.kind, "btConnect"); compare(DeviceMoments.card.deviceKind, "headphones")
                    compare(DeviceMoments.card.name, "Dev AA")
                    compare(DeviceMoments.batteriesOf(buds).length, 1)
                    compare(DeviceMoments.batteriesOf(buds)[0].level, 0.8)
                    compare(DeviceMoments.batteriesOf(fake("AB", "input-mouse")).length, 0)
                    const multi = fake("AC", "audio-headphones", 0.5)
                    multi.batteries = [{ label: "L", level: 0.6 }, { label: "R", level: 0.4 }, { label: "Caja", level: 2 }]
                    compare(DeviceMoments.batteriesOf(multi).length, 3); compare(DeviceMoments.batteriesOf(multi)[2].level, 1)
                    // hover pausa los 3,5 s
                    DeviceMoments.cardHovered = true
                    wait(3800); verify(DeviceMoments.cardOpen, "hover pausa la tarjeta")
                    DeviceMoments.cardHovered = false
                    tryCompare(DeviceMoments, "cardOpen", false, 4500)
                    // tarjeta sola: 3,5 s
                    reset()
                    const t0 = Date.now()
                    DeviceMoments.btConnected(fake("AD", "input-keyboard"), true)
                    tryCompare(DeviceMoments, "cardOpen", false, 4500)
                    const dt = Date.now() - t0
                    verify(dt >= 3300 && dt <= 4300, "tarjeta ~3,5 s, fue " + dt)
                    // tipos admitidos y descartados
                    reset()
                    for (const icon of ["audio-headphones", "audio-speakers", "input-gaming", "input-keyboard", "input-mouse"]) {
                        reset(); compare(DeviceMoments.btConnected(fake("T" + icon, icon), true), "card", icon)
                    }
                    reset(); compare(DeviceMoments.btConnected(fake("PH", "phone"), true), "drop")
                    // desconexión: aviso mínimo, sin tarjeta
                    reset()
                    compare(DeviceMoments.btConnected(fake("AA", "audio-headphones", 0.8), false), "notice")
                    verify(!DeviceMoments.cardOpen); compare(notices.count, 1)
                    compare(noticeText(0), I18n.tr("%1 desconectado").arg("Dev AA"))
                    // batería baja: una vez por conexión
                    reset()
                    const low = fake("LB", "audio-headphones", 0.1)
                    DeviceMoments.btConnected(low, true)
                    compare(notices.count, 1); verify(noticeText(0).indexOf("10") >= 0)
                    verify(!DeviceMoments.btBattery(low)); compare(notices.count, 1)
                    DeviceMoments.btConnected(low, false)
                    DeviceMoments.btConnected(low, true)
                    compare(notices.count, 3, "reconectar vuelve a avisar (desconexión + baja)")
                    verify(!DeviceMoments.btBattery(fake("OK", "audio-headphones", 0.5)))
                    Config.update({ devices: { bluetooth: false } })
                    compare(DeviceMoments.btConnected(fake("Z", "audio-headphones"), true), "drop")
                    Config.update({ devices: { bluetooth: true } })
                    console.log("PASS: bluetooth connect card 3.5s with hover pause, batteries, disconnect notice, low battery once per connection")

                    // ---- 2. corriente ----
                    reset()
                    DeviceMoments.pluggedNow = false
                    const p0 = Date.now()
                    compare(DeviceMoments.ingestPower(true, 55), "power")
                    verify(DeviceMoments.powerShown); verify(DeviceMoments.powerPlugged); compare(DeviceMoments.powerPercent, 55)
                    compare(DeviceMoments.ingestPower(true, 55), "drop", "sin cambio no repite")
                    verify(!DeviceMoments.cardOpen, "sin tarjeta")
                    powerMoment.shown = true; powerMoment.charging = true; powerMoment.percent = 55
                    verify(powerMoment.exposure === 1)
                    tryCompare(DeviceMoments, "powerShown", false, 3000)
                    const pdt = Date.now() - p0
                    verify(pdt >= 1800 && pdt <= 2600, "momento de corriente ~2 s, fue " + pdt)
                    powerMoment.shown = false
                    wait(520)
                    compare(DeviceMoments.ingestPower(false, 54), "power")
                    verify(!DeviceMoments.powerPlugged); compare(DeviceMoments.powerPercent, 54)
                    DeviceMoments.dismissPower(); wait(520)
                    // con surface abierta: aviso mínimo; pantalla completa: nada
                    DeviceMoments.context = { surfaceOpen: true, fullscreen: false, gesture: false, notification: false, dnd: false }
                    compare(DeviceMoments.ingestPower(true, 56), "notice")
                    compare(noticeText(0), I18n.tr("Cargando · %1%").arg(56))
                    DeviceMoments.context = { surfaceOpen: false, fullscreen: true, gesture: false, notification: false, dnd: false }
                    verify(!DeviceMoments.ownsPowerTransition())
                    compare(DeviceMoments.ingestPower(false, 55), "drop")
                    DeviceMoments.context = { surfaceOpen: false, fullscreen: false, gesture: false, notification: false, dnd: false }
                    verify(DeviceMoments.ownsPowerTransition())
                    Config.update({ devices: { power: false } })
                    verify(!DeviceMoments.ownsPowerTransition())
                    Config.update({ devices: { power: true } })
                    console.log("PASS: power plug bolt+percentage 2s, unplug percentage only, no card, notice/fullscreen/disabled paths")

                    // ---- 3. USB ----
                    reset()
                    compare(DeviceMoments.ingestStorage("{roto"), "drop")
                    compare(DeviceMoments.ingestStorage("[]"), "drop")
                    compare(DeviceMoments.ingestStorage("x".repeat(9000)), "drop")
                    compare(DeviceMoments.ingestStorage('{"event":"error","message":"sin udisks"}'), "error")
                    compare(DeviceMoments.ingestStorage(mounted("a", "LLAVE")), "card")
                    compare(DeviceMoments.card.kind, "storage"); compare(DeviceMoments.card.name, "LLAVE")
                    verify(DeviceMoments.card.sizeLabel.length > 0)
                    compare(DeviceMoments.ingestStorage(mounted("a", "LLAVE")), "drop", "duplicado")
                    suite.runs = []
                    verify(DeviceMoments.openMount())
                    compare(suite.runs.length, 1); compare(suite.runs[0][0], "xdg-open"); compare(suite.runs[0][1], "/run/media/u/LLAVE")
                    verify(!DeviceMoments.cardOpen)
                    // expulsar bien
                    reset(); suite.runs = []; suite.codes = ({})
                    DeviceMoments.ingestStorage(mounted("b", "DISCO"))
                    verify(DeviceMoments.eject())
                    compare(suite.runs.length, 2)
                    compare(suite.runs[0].join(" "), "udisksctl unmount -b /dev/sdb1")
                    compare(suite.runs[1].join(" "), "udisksctl power-off -b /dev/sdb")
                    compare(DeviceMoments.cardState, "ejected")
                    // fallo al desmontar
                    reset(); suite.runs = []; suite.codes = ({ "udisksctl unmount": 1 })
                    DeviceMoments.ingestStorage(mounted("c", "OCUPADO"))
                    DeviceMoments.eject()
                    compare(suite.runs.length, 1); compare(DeviceMoments.cardState, "error")
                    compare(DeviceMoments.cardError, I18n.tr("No se pudo expulsar. Inténtalo de nuevo."))
                    // fallo al apagar
                    reset(); suite.runs = []; suite.codes = ({ "udisksctl power-off": 1 })
                    DeviceMoments.ingestStorage(mounted("d", "APAGAR"))
                    DeviceMoments.eject()
                    compare(suite.runs.length, 2); compare(DeviceMoments.cardState, "error")
                    suite.codes = ({})
                    // extracción física retira la tarjeta
                    reset()
                    DeviceMoments.ingestStorage(mounted("e", "FUERA"))
                    DeviceMoments.ingestStorage(JSON.stringify({ event: "removed", id: "e" }))
                    verify(!DeviceMoments.cardOpen)
                    // la tarjeta hoja refleja los estados
                    cardView.kind = "storage"; cardView.title = "LLAVE"; cardView.subtitle = "29,7 GB"
                    cardView.ejectState = "ejecting"; wait(30)
                    cardView.ejectState = "error"; cardView.errorText = "x"; wait(30)
                    verify(findChild(cardView, "deviceCardAction-eject") !== null)
                    verify(findChild(cardView, "deviceCardAction-open") !== null)
                    console.log("PASS: udisks lines -> card, open via xdg-open, eject unmount+power-off, friendly errors, removal")

                    // ---- 4. privacidad ----
                    reset()
                    DeviceMoments.ingestPrivacy([{ kind: "mic", app: "Discord" }])
                    verify(!DeviceMoments.micActive); wait(200); verify(!DeviceMoments.micActive, "histéresis de entrada")
                    tryCompare(DeviceMoments, "micActive", true, 800)
                    compare(DeviceMoments.micApp, "Discord"); verify(!DeviceMoments.camActive)
                    DeviceMoments.ingestPrivacy([{ kind: "mic", app: "Discord" }, { kind: "camera", app: "Zoom" }])
                    tryCompare(DeviceMoments, "camActive", true, 800); compare(DeviceMoments.camApp, "Zoom")
                    dots.micActive = true; dots.camActive = true; dots.micApp = "Discord"; dots.camApp = "Zoom"
                    wait(60); verify(dots.visible)
                    DeviceMoments.ingestPrivacy([{ kind: "camera", app: "Zoom" }])
                    wait(200); verify(DeviceMoments.micActive, "histéresis de salida")
                    tryCompare(DeviceMoments, "micActive", false, 800); verify(DeviceMoments.camActive)
                    DeviceMoments.ingestPrivacy([])
                    tryCompare(DeviceMoments, "camActive", false, 800)
                    // enlace breve: nunca enciende
                    DeviceMoments.ingestPrivacy([{ kind: "mic", app: "Blip" }]); wait(120)
                    DeviceMoments.ingestPrivacy([]); wait(700)
                    verify(!DeviceMoments.micActive, "un enlace de 120 ms no parpadea")
                    // clic en el punto: Sonido, página de entrada
                    DeviceMoments.ingestPrivacy([{ kind: "mic", app: "Discord" }]); tryCompare(DeviceMoments, "micActive", true, 800)
                    surfaces.clear(); DeviceMoments.activatePrivacy()
                    compare(surfaces.count, 1); compare(surfaces.signalArguments[0][0], "mixer")
                    compare(DeviceMoments.consumeIntent("mixer"), "input"); compare(DeviceMoments.consumeIntent("mixer"), "")
                    Config.update({ devices: { privacyDots: false } })
                    verify(!DeviceMoments.micActive)
                    DeviceMoments.ingestPrivacy([{ kind: "mic", app: "Discord" }]); wait(600)
                    verify(!DeviceMoments.micActive, "privacyDots=false no enciende")
                    Config.update({ devices: { privacyDots: true } })
                    DeviceMoments.ingestPrivacy([]); wait(500)
                    console.log("PASS: privacy dots with 400 ms hysteresis, app names, short-link filter, click opens mixer input page, setting off")

                    // ---- 5. cola y prioridad ----
                    reset()
                    compare(DeviceMoments.btConnected(fake("Q1", "audio-headphones"), true), "card")
                    compare(DeviceMoments.ingestStorage(mounted("q", "SEGUNDO")), "defer")
                    compare(DeviceMoments.pending.length, 1, "un momento a la vez")
                    DeviceMoments.dismissCard()
                    tryCompare(DeviceMoments, "cardOpen", true, 2500)
                    compare(DeviceMoments.card.name, "SEGUNDO")
                    // la cola está acotada
                    reset(); DeviceMoments.btConnected(fake("Q2", "audio-headphones"), true)
                    for (let i = 0; i < 6; i++) DeviceMoments.ingestStorage(mounted("n" + i, "N" + i))
                    verify(DeviceMoments.pending.length <= DeviceMoments.pendingLimit)
                    // surface abierta -> aviso mínimo
                    reset()
                    DeviceMoments.context = { surfaceOpen: true, fullscreen: false, gesture: false, notification: false, dnd: false }
                    compare(DeviceMoments.btConnected(fake("S1", "audio-headphones"), true), "notice")
                    verify(!DeviceMoments.cardOpen); compare(notices.count, 1)
                    compare(noticeText(0), I18n.tr("%1 conectado").arg("Dev S1"))
                    // pantalla completa: nada salvo batería baja
                    reset()
                    DeviceMoments.context = { surfaceOpen: false, fullscreen: true, gesture: false, notification: false, dnd: false }
                    compare(DeviceMoments.btConnected(fake("F1", "audio-headphones"), true), "drop")
                    compare(DeviceMoments.btConnected(fake("F1", "audio-headphones"), false), "drop")
                    compare(DeviceMoments.ingestStorage(mounted("f", "FS")), "drop")
                    compare(notices.count, 0)
                    DeviceMoments.btConnected(fake("F2", "audio-headphones", 0.05), true)
                    compare(notices.count, 1, "batería baja pasa en pantalla completa")
                    // DND: nada salvo batería baja
                    reset()
                    DeviceMoments.context = { surfaceOpen: false, fullscreen: false, gesture: false, notification: false, dnd: true }
                    compare(DeviceMoments.btConnected(fake("D1", "audio-headphones"), true), "drop")
                    compare(DeviceMoments.ingestPower(true, 60) , "drop")
                    DeviceMoments.pluggedNow = false
                    DeviceMoments.btConnected(fake("D2", "audio-headphones", 0.05), true)
                    compare(notices.count, 1)
                    // gesto en curso: se difiere y se muestra al terminar
                    reset()
                    DeviceMoments.context = { surfaceOpen: false, fullscreen: false, gesture: true, notification: false, dnd: false }
                    compare(DeviceMoments.btConnected(fake("G1", "audio-headphones"), true), "defer")
                    verify(!DeviceMoments.cardOpen)
                    DeviceMoments.context = { surfaceOpen: false, fullscreen: false, gesture: false, notification: false, dnd: false }
                    tryCompare(DeviceMoments, "cardOpen", true, 1500)
                    // notificación visible: se difiere y la tarjeta cede
                    reset()
                    DeviceMoments.btConnected(fake("N1", "audio-headphones"), true)
                    DeviceMoments.interrupt()
                    verify(!DeviceMoments.cardOpen)
                    // caducidad de la cola
                    reset()
                    DeviceMoments.context = { surfaceOpen: false, fullscreen: false, gesture: true, notification: false, dnd: false }
                    DeviceMoments.pending = [{ kind: "btConnect", id: "old", name: "Old", queuedAt: Date.now() - 20000 }]
                    DeviceMoments.drain()
                    compare(DeviceMoments.pending.length, 0, "los momentos caducados se descartan")
                    reset()
                    Config.update({ devices: { enabled: false } })
                    compare(DeviceMoments.btConnected(fake("X", "audio-headphones"), true), "drop")
                    compare(DeviceMoments.ingestPower(true, 1), "drop")
                    Config.update({ devices: { enabled: true } })
                    console.log("PASS: queue one-at-a-time, bounded, expiry, surface-open notice, fullscreen, DND, gesture deferral, notification yield, master switch")

                    // ---- 7. reposo silencioso ----
                    reset(); wait(100)
                    verify(!DeviceMoments.busy)
                    verify(!DeviceMoments.cardOpen && !DeviceMoments.powerShown)
                    console.log("PASS: idle state after moments has no open card/power moment (timers are single-shot)")
                } catch (error) {
                    console.error("FAIL: DeviceMoments", error, error.stack)
                    suite.exitCode = 1
                }
                finish.start()
            }
        }
    }
}
