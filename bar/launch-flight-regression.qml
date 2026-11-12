import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "components"
import "components/LaunchFlight.js" as LF
import "Singletons"

// Las apps nacen de la isla: motor de vuelo con eventos de Hyprland simulados y
// tiempo controlado (manualStep). No toca Hyprland ni lanza apps. IslandOverlay no se
// puede instanciar offscreen; su cableado se comprueba por texto y con qmllint.
ShellRoot {
    id: suite
    settings.watchFiles: false
    property int exitCode: 0
    Timer { id: finish; interval: 100; onTriggered: Qt.exit(suite.exitCode) }

    function srcPath(rel) { return Quickshell.shellPath(rel) }
    FileView { id: surfaceSrc; path: suite.srcPath("surfaces/LauncherSurface.qml"); blockLoading: true }
    FileView { id: flightSrc; path: suite.srcPath("components/LaunchFlight.qml"); blockLoading: true }
    FileView { id: overlaySrc; path: suite.srcPath("windows/IslandOverlay.qml"); blockLoading: true }

    Window {
        id: win
        visible: true
        width: 1000; height: 700
        property var windows: ({})
        property string active: "aaa"
        function lookup(address) { return win.windows[LF.normAddress(address)] || null }
        function current() { return win.active }

        LaunchFlight {
            id: flight
            objectName: "testFlight"
            width: 1000; height: 700
            s: 1
            monitorName: "DP-1"
            bodyX: 400; bodyY: 20; bodyW: 200; bodyH: 40; bodyRadius: 20
            workArea: Qt.rect(0, 40, 1000, 660)
            workspaceTarget: Qt.rect(100, 20, 80, 30)
            visibleWorkspaceId: 1
            readRounding: false
            windowRounding: 12
            manualStep: true
            geometryProvider: win.lookup
            activeAddressProvider: win.current
        }
        SignalSpy { id: announced; target: Apps; signalName: "launchAnnounced" }

        TestCase {
            id: tc
            name: "LaunchFlight"
            when: Config.loaded

            function info(extra) {
                const base = { originX: 500, originY: 40, size: 40, icon: "", candidates: ["firefox"], pid: 0 }
                for (const k in extra) base[k] = extra[k]
                return base
            }
            function reset() {
                flight.cancel()
                flight.manualStep = true
                flight.fullscreen = false
                flight.monitorName = "DP-1"
                flight.visibleWorkspaceId = 1
                flight.workspaceTarget = Qt.rect(100, 20, 80, 30)
                win.windows = ({})
                win.active = "aaa"
                Config.update({ appearance: { reduceMotion: false }, motion: { appLaunchFlight: true } })
                announced.clear()
            }
            function advance(ms) {
                for (let t = 0; t < ms; t += 8) flight.step(0.008)
            }
            function until(pred, limitMs) {
                for (let t = 0; t < limitMs; t += 8) {
                    if (pred()) return true
                    flight.step(0.008)
                }
                return pred()
            }
            function openEvent(addr, cls) { return addr + ",1," + cls + ",Titulo, con coma" }
            function winInfo(addr, extra) {
                const w = { address: addr, cls: "firefox", pid: 7, x: 300, y: 200, w: 400, h: 300, monitor: "DP-1", workspaceId: 1 }
                for (const k in extra) w[k] = extra[k]
                return w
            }

            function test_all() {
                try {
                    reset()

                    // ---- regla de casado ----
                    const entry = { id: "org.mozilla.firefox.desktop", startupClass: "Firefox", command: ["env", "FOO=1", "/usr/bin/firefox", "%u"], name: "Firefox Web Browser" }
                    const cands = LF.candidates(entry)
                    verify(cands.indexOf("firefox") >= 0 && cands.indexOf("orgmozillafirefox") >= 0, "candidatos: " + JSON.stringify(cands))
                    verify(LF.matches(cands, "firefox") && LF.matches(cands, "Firefox") && !LF.matches(cands, "kitty"))
                    const ow = LF.parseOpenWindow("0xABC123,2,firefox,Pestana, con coma")
                    compare(ow.address, "abc123"); compare(ow.workspace, "2"); compare(ow.cls, "firefox"); compare(ow.title, "Pestana, con coma")
                    verify(LF.parseOpenWindow("solo,dos") === null)
                    console.log("PASS: regla de casado (StartupWMClass, id, binario del Exec, nombre) y parseo de openwindow con comas")

                    // ---- 1. sin retraso: el comando va antes que el anuncio, en el mismo handler ----
                    const surface = "" + surfaceSrc.text()
                    const iLaunch = surface.indexOf("controller.launch(app)")
                    const iAnnounce = surface.indexOf("Apps.announceLaunch(app")
                    verify(iLaunch >= 0 && iAnnounce > iLaunch, "launch precede al anuncio")
                    const between = surface.substring(iLaunch, iAnnounce)
                    verify(!/Timer|callLater|interval|Animation|wait/.test(between), "nada diferido entre ambos: " + between)
                    announced.clear()
                    Apps.announceLaunch({ id: "x.desktop", name: "X", icon: "", startupClass: "XCls" }, { x: 500, y: 40, size: 40 })
                    compare(announced.count, 1, "el anuncio es síncrono")
                    compare(announced.signalArguments[0][0].originX, 500)
                    verify(announced.signalArguments[0][0].candidates.indexOf("xcls") >= 0)
                    Apps.announceLaunch({ id: "y.desktop" }, null)
                    compare(announced.count, 1, "sin origen no hay vuelo")
                    verify(flight.begin(info({})), "begin responde en el mismo tick")
                    compare(flight.phase, "brote")
                    compare(flight.elapsed, 0)
                    console.log("PASS: 1 launch() precede a announceLaunch() sin diferidos; anuncio y begin() son síncronos (cero retraso añadido)")

                    // ---- 2. secuencia brote -> rotura -> vuelo -> retarget -> llegada -> fin ----
                    flight.cancel()
                    verify(flight.begin(info({})))
                    const seen = {}
                    let bondSeen = false, residualSeen = false, minStretch = 9, maxStretchBonded = 0
                    for (let i = 0; i < 200 && flight.phase === "brote"; ++i) {
                        flight.step(0.008)
                        if (flight.bond) { bondSeen = true; maxStretchBonded = Math.max(maxStretchBonded, flight.stretch) }
                    }
                    verify(bondSeen, "el cuello existe mientras la gota está unida")
                    verify(maxStretchBonded < 1.30 + 0.5, "la unión se mantiene por debajo de 1.30 (+ un paso)")
                    compare(flight.bond, false, "rompió el cuello")
                    verify(flight.residualMs >= 0, "deja microgota residual")
                    residualSeen = true
                    compare(flight.phase, "vuelo")
                    // ya vuela hacia el centro del área de trabajo
                    advance(200)
                    verify(flight.vy > 0, "vuela hacia abajo")
                    compare(flight.tx, 500); compare(flight.ty, 370)
                    verify(flight.residualMs < 0 || flight.residualMs < Motion.launchResidue, "el residuo es transitorio")
                    advance(Motion.launchResidue + 50)
                    compare(flight.residualMs, -1, "el residuo termina")

                    // no casa: otra clase
                    flight.ingestRaw("openwindow", openEvent("0xdead", "kitty"))
                    compare(flight.windowAddress, "", "una clase ajena no casa")
                    win.windows = ({ "beef01": winInfo("beef01", {}) })
                    const px0 = flight.px, py0 = flight.py, vx0 = flight.vx, vy0 = flight.vy
                    flight.ingestRaw("openwindow", openEvent("0xBEEF01", "firefox"))
                    compare(flight.windowAddress, "beef01")
                    compare(flight.destination, "window")
                    verify(Math.abs(flight.px - px0) <= 1 && Math.abs(flight.py - py0) <= 1, "retarget conserva la posición")
                    verify(Math.abs(flight.vx - vx0) <= 0.1 * Math.max(1, Math.abs(vx0)) && Math.abs(flight.vy - vy0) <= 0.1 * Math.max(1, Math.abs(vy0)), "retarget conserva la velocidad")
                    compare(flight.tx, 500); compare(flight.ty, 350)
                    const vyBefore = flight.vy
                    flight.step(0.008)
                    verify(Math.abs(flight.py - py0) <= Math.abs(vyBefore) * 0.008 + 3, "sin salto tras el retarget")
                    verify(until(function () { return flight.phase === "llegando" }, 3000), "llega a la ventana")
                    let coverStart = flight.elapsed
                    verify(until(function () { return flight.phase === "idle" }, 600), "la llegada termina")
                    verify(flight.coverMs <= Motion.launchCoverMax, "cobertura " + flight.coverMs)
                    compare(flight.visible, false)
                    console.log("PASS: brote con cuello -> rotura con residuo -> vuelo -> retarget al openwindow (posición ±1, velocidad ±10 %) -> llegada -> fin")

                    // ---- 4. la llegada nunca cubre más de 220 ms (también con motionScale grande) ----
                    reset()
                    win.windows = ({ "c0ffee": winInfo("c0ffee", {}) })
                    flight.begin(info({}))
                    flight.ingestRaw("openwindow", openEvent("0xc0ffee", "firefox"))
                    until(function () { return flight.phase === "llegando" }, 4000)
                    let frames = 0, maxOpacityAfter = 0
                    const arrivalStart = flight.arriveMs
                    while (flight.phase === "llegando" && frames < 100) {
                        flight.step(0.004); frames++
                        if (flight.arriveMs > 220) maxOpacityAfter = Math.max(maxOpacityAfter, flight.glassOpacity)
                    }
                    compare(flight.phase, "idle")
                    verify(flight.coverMs <= 220 && flight.coverMs > 0, "coverMs=" + flight.coverMs)
                    compare(maxOpacityAfter, 0, "a 220 ms ya no hay vidrio")
                    compare(Motion.launchFade <= 200, true)
                    // rectángulo final = ventana, radio de ventana de Hyprland
                    reset()
                    flight.begin(info({}))
                    win.windows = ({ "c0ffee": winInfo("c0ffee", {}) })
                    flight.ingestRaw("openwindow", openEvent("0xc0ffee", "firefox"))
                    until(function () { return flight.phase === "llegando" }, 4000)
                    while (flight.phase === "llegando" && flight.arriveMs < Motion.launchFade * 0.9) flight.step(0.002)
                    verify(Math.abs(flight.glassX - 300) < 40 && Math.abs(flight.glassW - 400) < 40, "el vidrio coincide con la ventana")
                    compare(flight.windowRounding, 12)
                    console.log("PASS: 4 la llegada cubre como máximo " + Motion.launchFade + " ms (< 220), vidrio = rectángulo de la ventana con decoration:rounding")

                    // ---- 3a. sin ventana en 6 s: vuelve y es tragada ----
                    reset()
                    flight.begin(info({}))
                    verify(until(function () { return flight.phase === "espera" }, 5000), "espera quieta en el destino provisional")
                    verify(flight.phase !== "regreso")
                    verify(until(function () { return flight.elapsed >= 5900 }, 6000))
                    compare(flight.phase, "espera", "antes de 6 s sigue esperando")
                    verify(flight.elapsed < 6000)
                    advance(300)
                    compare(flight.destination, "island")
                    verify(flight.phase === "regreso" || flight.phase === "absorbiendo", "vuelve: " + flight.phase)
                    verify(until(function () { return flight.phase === "absorbiendo" || flight.phase === "idle" }, 5000), "es tragada")
                    verify(until(function () { return flight.phase === "idle" }, 1000))
                    compare(flight.returnReason, "timeout")
                    // un openwindow tardío no revive el vuelo
                    flight.ingestRaw("openwindow", openEvent("0xlate", "firefox"))
                    compare(flight.phase, "idle")
                    console.log("PASS: 3 sin ventana en 6 s -> espera, vuelve a la isla y es tragada; un openwindow tardío se ignora")

                    // ---- 3b. ventana existente enfocada: viaja a ella ----
                    reset()
                    flight.begin(info({}))
                    win.windows = ({ "feed02": winInfo("feed02", { x: 100, y: 120, w: 500, h: 400 }) })
                    advance(40)
                    flight.ingestRaw("activewindowv2", "aaa")
                    compare(flight.windowAddress, "", "el foco inicial no casa")
                    advance(200)
                    flight.ingestRaw("activewindowv2", "feed02")
                    compare(flight.windowAddress, "feed02")
                    compare(flight.matchSource, "focus")
                    compare(flight.destination, "window")
                    verify(until(function () { return flight.phase === "llegando" }, 4000))
                    verify(until(function () { return flight.phase === "idle" }, 600))
                    // la ventana activa de otra clase no casa
                    reset()
                    flight.begin(info({}))
                    win.windows = ({ "feed03": winInfo("feed03", { cls: "kitty" }) })
                    advance(300)
                    flight.ingestRaw("activewindowv2", "feed03")
                    compare(flight.windowAddress, "")
                    console.log("PASS: 3 ventana existente enfocada -> la gota viaja a ella y llega; foco inicial y clases ajenas no casan")

                    // ---- 3c. workspace oculto -> indicador (o isla); otro monitor -> isla ----
                    reset()
                    flight.begin(info({}))
                    win.windows = ({ "a1": winInfo("a1", { workspaceId: 3 }) })
                    flight.ingestRaw("openwindow", openEvent("0xa1", "firefox"))
                    compare(flight.destination, "indicator")
                    advance(16)
                    compare(flight.tx, 140); compare(flight.ty, 35)
                    verify(until(function () { return flight.phase === "absorbiendo" || flight.phase === "idle" }, 6000), "llega al indicador")
                    verify(until(function () { return flight.phase === "idle" }, 1000))
                    reset()
                    flight.workspaceTarget = Qt.rect(0, 0, 0, 0)
                    flight.begin(info({}))
                    win.windows = ({ "a2": winInfo("a2", { workspaceId: 3 }) })
                    flight.ingestRaw("openwindow", openEvent("0xa2", "firefox"))
                    compare(flight.destination, "island")
                    compare(flight.returnReason, "workspace")
                    verify(until(function () { return flight.phase === "idle" }, 8000), "sin indicador vuelve a la isla")
                    reset()
                    flight.begin(info({}))
                    win.windows = ({ "a3": winInfo("a3", { monitor: "DP-2" }) })
                    flight.ingestRaw("openwindow", openEvent("0xa3", "firefox"))
                    compare(flight.destination, "island")
                    compare(flight.returnReason, "monitor")
                    verify(until(function () { return flight.phase === "idle" }, 8000), "otro monitor: vuelve y es tragada")
                    // geometría que nunca llega -> vuelve
                    reset()
                    flight.begin(info({}))
                    flight.ingestRaw("openwindow", openEvent("0xa4", "firefox"))
                    compare(flight.windowAddress, "a4")
                    advance(1700)
                    compare(flight.returnReason, "geometry")
                    verify(until(function () { return flight.phase === "idle" }, 8000))
                    console.log("PASS: 3 workspace oculto -> indicador (sin indicador: isla); otro monitor -> isla; geometría que no llega -> isla")

                    // ---- 5. sin vuelo: reduceMotion, ajuste apagado, pantalla completa ----
                    reset()
                    Config.update({ appearance: { reduceMotion: true } })
                    compare(flight.begin(info({})), false); compare(flight.phase, "idle")
                    Config.update({ appearance: { reduceMotion: false } })
                    Config.update({ motion: { appLaunchFlight: false } })
                    compare(flight.begin(info({})), false); compare(flight.phase, "idle")
                    Config.update({ motion: { appLaunchFlight: true } })
                    flight.fullscreen = true
                    compare(flight.begin(info({})), false); compare(flight.phase, "idle")
                    flight.fullscreen = false
                    verify(flight.begin(info({})), "con todo habilitado vuela")
                    // desactivar a media animación la cancela
                    Config.update({ motion: { appLaunchFlight: false } })
                    compare(flight.phase, "idle", "apagar el ajuste a media animación la cancela")
                    Config.update({ motion: { appLaunchFlight: true } })
                    console.log("PASS: 5 reduceMotion, motion.appLaunchFlight=false y pantalla completa no vuelan; apagar el ajuste cancela el vuelo en curso")

                    // ---- 6. reposo silencioso y región de entrada intacta ----
                    reset()
                    compare(flight.active, false); compare(flight.frameActive, false); compare(flight.visible, false)
                    const loader = flight.children.filter(function (c) { return c.objectName === "launchNeckLoader" })[0]
                    verify(loader, "loader del cuello")
                    compare(loader.active, false, "sin escena en reposo")
                    flight.begin(info({}))
                    compare(flight.frameActive, true, "durante el vuelo hay cuadros")
                    compare(loader.active, true)
                    advance(2000)
                    verify(flight.phase === "espera", "esperando: " + flight.phase)
                    compare(flight.frameActive, false, "esperando en el destino no hay cuadros")
                    flight.cancel()
                    compare(flight.frameActive, false); compare(loader.active, false)
                    const flightText = "" + flightSrc.text()
                    verify(!/MouseArea|TapHandler|HoverHandler|DragHandler|WheelHandler|Region\b/.test(flightText), "LaunchFlight no captura entrada")
                    const overlayText = "" + overlaySrc.text()
                    const maskStart = overlayText.indexOf("mask:"), maskEnd = overlayText.indexOf("FocusScope {")
                    verify(maskStart > 0 && maskEnd > maskStart)
                    verify(overlayText.substring(maskStart, maskEnd).indexOf("launchFlight") < 0, "la máscara no menciona la gota")
                    verify(/Apps[\s\S]{0,40}onLaunchAnnounced[\s\S]{0,80}launcherOpen/.test(overlayText), "el vuelo sólo nace con el launcher abierto")
                    console.log("PASS: 6 reposo sin escena ni cuadros (Loader inactivo), espera sin cuadros, sin manejadores de entrada y máscara de IslandOverlay sin cambios")
                } catch (error) {
                    console.error("FAIL: LaunchFlight", error, error.stack)
                    suite.exitCode = 1
                }
                finish.start()
            }
        }
    }
}
