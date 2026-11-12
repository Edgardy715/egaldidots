pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../fluid" as Fluid
import "../Singletons"
import "LaunchFlight.js" as LF

/**
 * Isla · LaunchFlight. Las apps nacen de la isla (docs/apps-nacen-2026-11-06).
 *
 * Al lanzar una app el icono de la fila elegida queda dentro de una gota que
 * brota del cuerpo de la pill (mismo cuello, histéresis 1.02 / 1.30 y microgota
 * residual que las gotas laterales) y vuela, con un único muelle 2D
 * (Motion.launchFlight), hasta el centro del área de trabajo. Cuando Hyprland
 * emite el `openwindow` que casa con la app, el destino se retargetea al
 * rectángulo real de la ventana conservando posición y velocidad; la gota se
 * ensancha en vidrio con el radio de ventana y se desvanece (Motion.launchFade).
 * Sin ventana en 6 s, o si nace en otro monitor/workspace oculto, vuelve a la
 * isla (o al indicador de workspace) y es tragada.
 *
 * Es una hoja: la composición le da geometría del cuerpo, área de trabajo y
 * ajustes; no captura entrada (sin áreas de ratón ni manejadores; la máscara de la ventana
 * no cambia) y en reposo no tiene escena, temporizadores ni conexiones activas.
 * Las pruebas avanzan a mano con `manualStep` + `step(dt)` y alimentan eventos con
 * `ingestRaw` / `ingestWindow`.
 */
Item {
    id: root

    // ---- composición ----
    property real s: 1
    property string monitorName: ""
    property bool fullscreen: false
    // Cuerpo de la pill (coordenadas de este Item) y su radio.
    property real bodyX: 0
    property real bodyY: 0
    property real bodyW: 0
    property real bodyH: 0
    property real bodyRadius: 0
    // Destino provisional: centro del área de trabajo del monitor.
    property rect workArea: Qt.rect(0, 0, width, height)
    // Indicador de workspace de la barra (ancho 0 = no existe) y workspace visible.
    property rect workspaceTarget: Qt.rect(0, 0, 0, 0)
    property int visibleWorkspaceId: -1
    // decoration:rounding de Hyprland (se lee una vez con `hyprctl getoption`).
    property real windowRounding: 10
    property bool readRounding: true
    property bool manualStep: false
    // function(address) -> {address, cls, pid, x, y, w, h, monitor, workspaceId} | null
    property var geometryProvider: lookupWindow
    // Dirección de la ventana activa al lanzar (para no confundir el regreso del foco).
    property var activeAddressProvider: currentActiveAddress

    readonly property bool settingOn: Config._effective.motion ? Config._effective.motion.appLaunchFlight !== false : true
    readonly property bool allowed: settingOn && !Flags.reduceMotion && !fullscreen && bodyW > 0

    // ---- estado ----
    // idle | brote | vuelo | espera | llegando | regreso | absorbiendo
    property string phase: "idle"
    // center | window | indicator | island
    property string destination: "center"
    property string returnReason: ""
    property real px: 0
    property real py: 0
    property real vx: 0
    property real vy: 0
    property real tx: 0
    property real ty: 0
    property real dropSize: 40
    property bool bond: false
    property real elapsed: 0           // ms desde begin()
    property real arriveMs: 0
    property real absorbMs: 0
    property real residualMs: -1
    property real residualX: 0
    property real residualY: 0
    property var launch: null
    property string windowAddress: ""
    property string matchSource: ""
    property var windowInfo: null
    property real matchedAt: -1
    property real geometryAt: -1
    property string startActive: ""
    property rect arriveFrom: Qt.rect(0, 0, 0, 0)
    property real coverMs: 0           // tiempo que el vidrio ha cubierto la ventana
    property real holdInterval: 0
    property bool roundingRead: false

    readonly property bool active: phase !== "idle"
    readonly property bool frameActive: phase !== "idle" && phase !== "espera" || residualMs >= 0
    readonly property real dropRadius: dropSize / 2
    readonly property rect windowRect: windowInfo ? Qt.rect(windowInfo.x, windowInfo.y, windowInfo.w, windowInfo.h) : Qt.rect(0, 0, 0, 0)
    readonly property bool windowKnown: windowInfo !== null && windowRect.width > 0

    readonly property real capRadius: Math.min(bodyRadius, bodyH / 2)
    readonly property real bodyDistance: LF.sdRoundBox(px, py, bodyX, bodyY, bodyW, bodyH, bodyRadius)
    readonly property real stretch: LF.stretchOf(bodyDistance, capRadius, dropRadius)
    readonly property real neckWaistValue: LF.neckWaist(stretch)
    readonly property real neckBlend: (10 + 22 * neckWaistValue / 0.42) * s
    readonly property real edgeExposure: bond ? 1 - neckWaistValue / 0.42 : 1

    // ---- geometría del vidrio (animada por la llegada) ----
    readonly property real fade: Math.max(1, Motion.launchFade)
    readonly property real arriveU: phase === "llegando" ? LF.clamp((arriveMs - 0.35 * fade) / (0.5 * fade), 0, 1) : 0
    readonly property real widen: 1 - Math.pow(1 - arriveU, 3)
    readonly property real absorbU: phase === "absorbiendo" ? LF.clamp(absorbMs / Math.max(1, Motion.launchAbsorb), 0, 1) : 0
    readonly property real glassScale: destination === "indicator" && phase === "absorbiendo" ? 1 - 0.3 * absorbU : 1
    // Levantamiento: la placa crece un 10 % al salir de la fila (ease-out, 200 ms) y queda así en vuelo.
    readonly property real liftScale: phase === "llegando" ? 1 : 1 + 0.1 * (1 - Math.pow(1 - LF.clamp(elapsed / 200, 0, 1), 3))
    readonly property real glassW: phase === "llegando" ? arriveFrom.width + (windowRect.width - arriveFrom.width) * widen : dropSize * glassScale * liftScale
    readonly property real glassH: phase === "llegando" ? arriveFrom.height + (windowRect.height - arriveFrom.height) * widen : dropSize * glassScale * liftScale
    readonly property real glassX: phase === "llegando" ? arriveFrom.x + (windowRect.x - arriveFrom.x) * widen : px - glassW / 2
    readonly property real glassY: phase === "llegando" ? arriveFrom.y + (windowRect.y - arriveFrom.y) * widen : py - glassH / 2
    // La placa es un squircle como la celda del lanzador, no un círculo: la forma de origen se conserva.
    readonly property real glassRadius: phase === "llegando"
        ? dropSize * 0.3 + (Math.max(0, windowRounding) - dropSize * 0.3) * widen
        : Math.min(glassW, glassH) * 0.3
    readonly property real glassOpacity: {
        if (phase === "llegando") {
            // Se disuelve durante toda la expansión: sin meseta gris sobre la ventana real.
            const t = LF.clamp((arriveMs - 0.05 * fade) / (0.6 * fade), 0, 1)
            return 1 - t * t * (3 - 2 * t)
        }
        return phase === "absorbiendo" ? 1 - absorbU * absorbU * (3 - 2 * absorbU) : 1
    }
    readonly property real iconOpacity: phase === "llegando" ? 1 - LF.clamp(arriveMs / (0.35 * fade), 0, 1)
        : phase === "absorbiendo" ? glassOpacity : 1
    readonly property bool covering: phase === "llegando" && glassOpacity > 0.01 && arriveU > 0
    readonly property bool overlapsBody: glassX < bodyX + bodyW && glassX + glassW > bodyX
        && glassY < bodyY + bodyH && glassY + glassH > bodyY

    // PillMaterial se lee más opaco al crecer; cada extremo del cuello copia su cuerpo.
    function readingExposure(height) { return Math.max(0, Math.min(1, (height / s - 38) / 58)) }
    function glassAlpha(exposure) { return Flags.glassAlpha + (1 - Flags.glassAlpha) * (0.15 + 0.25 * exposure) }
    readonly property real bodyExposure: readingExposure(bodyH)
    readonly property real dropExposure: readingExposure(glassH)

    visible: active || residualMs >= 0
    onAllowedChanged: if (!allowed && phase !== "idle") finish()

    // ---- API ----
    function begin(info) {
        if (!allowed || !info || !isFinite(info.originX) || !isFinite(info.originY)) return false
        if (phase !== "idle") finish()
        launch = info
        dropSize = Math.max(40 * s, (info.size || 40 * s) * 1.25)
        px = info.originX; py = info.originY; vx = 0; vy = 0
        tx = workArea.x + workArea.width / 2
        ty = workArea.y + workArea.height / 2
        destination = "center"
        windowAddress = ""; matchSource = ""; windowInfo = null
        matchedAt = -1; geometryAt = -1; returnReason = ""
        elapsed = 0; arriveMs = 0; absorbMs = 0; coverMs = 0; residualMs = -1
        bond = true
        startActive = LF.normAddress(activeAddressProvider())
        phase = "brote"
        if (readRounding && !roundingRead) { roundingRead = true; roundingProcess.running = true }
        return true
    }

    function cancel() { if (phase !== "idle") finish() }

    function finish() {
        phase = "idle"
        destination = "center"
        bond = false
        residualMs = -1
        launch = null
        windowInfo = null
        windowAddress = ""
        vx = 0; vy = 0
        holdInterval = 0
    }

    function matchWindow(address, source) {
        windowAddress = address
        matchSource = source
        windowInfo = null
        matchedAt = elapsed
        geometryAt = -1
        tryGeometry()
    }

    function tryGeometry() {
        if (!windowAddress || windowInfo) return
        const info = geometryProvider ? geometryProvider(windowAddress) : null
        if (info) ingestWindow(info)
    }

    /** Eventos crudos de Hyprland (openwindow, activewindowv2). */
    function ingestRaw(name, data) {
        if (phase !== "brote" && phase !== "vuelo" && phase !== "espera") return
        if (name === "openwindow") {
            const w = LF.parseOpenWindow(data)
            if (!w) return
            if (!LF.matches(launch.candidates, w.cls)) return
            if (windowAddress === w.address) return
            matchWindow(w.address, "open")
        } else if (name === "activewindowv2") {
            // App ya abierta: Hyprland sólo enfoca. Se ignora el primer instante (el foco
            // vuelve a la ventana anterior al cerrar el launcher) y la ventana que ya
            // estaba activa al lanzar.
            if (windowAddress || elapsed < 120) return
            const addr = LF.normAddress(data)
            if (!addr || addr === startActive) return
            const info = geometryProvider ? geometryProvider(addr) : null
            if (info && (LF.matches(launch.candidates, info.cls) || launch.pid && info.pid === launch.pid)) {
                matchWindow(addr, "focus")
            }
        }
    }

    /** Geometría real de la ventana casada, relativa a este Item. */
    function ingestWindow(info) {
        if (!info || phase === "idle" || phase === "llegando" || phase === "absorbiendo" || phase === "regreso") return
        if (windowAddress && info.address && LF.normAddress(info.address) !== windowAddress) return
        if (!(info.w > 0 && info.h > 0)) return
        windowInfo = info
        geometryAt = elapsed
        if (info.monitor && monitorName && info.monitor !== monitorName) { startReturn("monitor"); return }
        if (visibleWorkspaceId >= 0 && info.workspaceId !== undefined && info.workspaceId !== visibleWorkspaceId) {
            if (workspaceTarget.width > 0) { destination = "indicator"; wake() }
            else startReturn("workspace")
            return
        }
        destination = "window"
        wake()
    }

    function wake() {
        updateTarget()
        if (phase === "espera") { phase = "vuelo"; holdInterval = 0 }
    }

    function startReturn(reason) {
        if (phase !== "brote" && phase !== "vuelo" && phase !== "espera") return
        returnReason = reason
        destination = "island"
        windowInfo = null
        bond = stretch < 1.30
        phase = "regreso"
        holdInterval = 0
        updateTarget()
    }

    function startArrive() {
        // Desde la placa tal como se ve (con su levantamiento), para no saltar al empezar.
        arriveFrom = Qt.rect(glassX, glassY, glassW, glassH)
        arriveMs = 0
        coverMs = 0
        bond = false
        vx = 0; vy = 0
        phase = "llegando"
    }

    function breakBond() {
        bond = false
        const cx = LF.clamp(px, bodyX, bodyX + bodyW), cy = LF.clamp(py, bodyY, bodyY + bodyH)
        const dx = px - cx, dy = py - cy, len = Math.max(1, Math.hypot(dx, dy))
        residualX = cx + dx / len * 3 * s
        residualY = cy + dy / len * 3 * s
        residualMs = 0
        phase = "vuelo"
    }

    function updateTarget() {
        if (destination === "window" && windowKnown) {
            tx = windowRect.x + windowRect.width / 2; ty = windowRect.y + windowRect.height / 2
        } else if (destination === "indicator") {
            tx = workspaceTarget.x + workspaceTarget.width / 2; ty = workspaceTarget.y + workspaceTarget.height / 2
        } else if (destination === "island") {
            tx = bodyX + bodyW / 2; ty = bodyY + bodyH / 2
        } else {
            tx = workArea.x + workArea.width / 2; ty = workArea.y + workArea.height / 2
        }
    }

    /** Avanza `dt` segundos. Determinista: las pruebas lo llaman a mano. */
    function step(dt) {
        if (!isFinite(dt) || dt <= 0) return
        if (phase === "idle" && residualMs < 0) return
        const ms = dt * 1000
        if (residualMs >= 0) {
            residualMs += ms
            if (residualMs >= Motion.launchResidue) residualMs = -1
        }
        if (phase === "idle") return
        elapsed += ms

        if (phase === "llegando") {
            arriveMs += ms
            coverMs += ms
            if (arriveMs >= fade) finish()
            return
        }
        if (phase === "absorbiendo") {
            absorbMs += ms
            if (absorbMs >= Math.max(1, Motion.launchAbsorb) || Flags.reduceMotion) finish()
            return
        }

        updateTarget()
        const sdt = Math.min(dt, 1) / Math.max(0.1, Flags.motionScale)
        const r = LF.springStep(px, py, vx, vy, tx, ty, Motion.launchFlight.omega, Motion.launchFlight.zeta, sdt)
        px = r[0]; py = r[1]; vx = r[2]; vy = r[3]
        const speed = Math.hypot(vx, vy)
        const dist = Math.hypot(tx - px, ty - py)
        const settled = dist < 0.6 * s && speed < 12 * s

        if (phase === "brote") {
            if (stretch >= 1.30) breakBond()
        }
        if (phase === "regreso") {
            // Histéresis de regreso: vuelve a unirse bajo 1.30; el casquete absorbe el resto.
            if (!bond && stretch < 1.30) bond = true
            if (bodyDistance <= -dropRadius * 0.35 || settled) {
                phase = "absorbiendo"; absorbMs = 0; bond = false
            }
            return
        }

        // Plazos: sin ventana en 6 s, o sin geometría 1.5 s después del casado.
        if (!windowAddress && elapsed >= Motion.launchWait) { startReturn("timeout"); return }
        if (windowAddress && !windowInfo && elapsed - matchedAt >= Motion.launchGeometryWait) {
            startReturn("geometry"); return
        }

        if (phase === "vuelo" || phase === "brote") {
            if (destination === "window" && windowKnown && phase === "vuelo") {
                const arriveR = Math.max(40 * s, 0.15 * Math.min(windowRect.width, windowRect.height))
                if (dist < arriveR || elapsed - geometryAt > 900) { startArrive(); return }
            } else if (destination === "indicator" && phase === "vuelo" && dist < 14 * s) {
                phase = "absorbiendo"; absorbMs = 0; return
            }
            if (phase === "vuelo" && destination === "center" && !windowAddress && settled) {
                phase = "espera"
                holdInterval = Math.max(1, Motion.launchWait - elapsed)
            }
        }
    }

    // ---- fuentes vivas (sólo mientras hay un vuelo) ----
    Connections {
        target: Hyprland
        enabled: root.active
        function onRawEvent(event) { root.ingestRaw("" + event.name, "" + event.data) }
    }
    FrameAnimation {
        running: root.frameActive && !root.manualStep
        onTriggered: root.step(frameTime)
    }
    // Espera quieta en el destino provisional: sin cuadros, un solo plazo.
    Timer {
        objectName: "launchHoldTimer"
        running: root.phase === "espera" && !root.manualStep
        interval: Math.max(1, root.holdInterval)
        repeat: false
        onTriggered: root.step(interval / 1000)
    }
    // Hyprland rellena lastIpcObject de la ventana nueva tras refreshToplevels().
    Timer {
        objectName: "launchGeometryTimer"
        running: root.active && root.windowAddress.length > 0 && !root.windowInfo && !root.manualStep
        interval: 30
        repeat: true
        onTriggered: {
            Hyprland.refreshToplevels()
            root.tryGeometry()
        }
    }
    Process {
        id: roundingProcess
        command: ["hyprctl", "getoption", "decoration:rounding", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const v = JSON.parse(text)
                    const n = v.int !== undefined ? v.int : v.float
                    if (isFinite(n) && n >= 0) root.windowRounding = n
                } catch (e) {}
            }
        }
    }

    function currentActiveAddress() {
        const t = Hyprland.activeToplevel
        return t ? "" + t.address : ""
    }

    function monitorOrigin() {
        const list = Hyprland.monitors ? Hyprland.monitors.values : []
        for (let i = 0; i < list.length; ++i) {
            if (list[i].name !== root.monitorName) continue
            const o = list[i].lastIpcObject
            return { x: o && o.x !== undefined ? o.x : 0, y: o && o.y !== undefined ? o.y : 0 }
        }
        return { x: 0, y: 0 }
    }

    /** Proveedor por defecto: Hyprland.toplevels + lastIpcObject (coordenadas relativas al monitor). */
    function lookupWindow(address) {
        const want = LF.normAddress(address)
        const list = Hyprland.toplevels ? Hyprland.toplevels.values : []
        for (let i = 0; i < list.length; ++i) {
            const t = list[i]
            if (LF.normAddress(t.address) !== want) continue
            const o = t.lastIpcObject
            if (!o || !o.at || !o.size || !(o.size[0] > 0)) return null
            const m = monitorOrigin()
            return {
                address: want, cls: String(o.class || ""), pid: o.pid || 0,
                x: o.at[0] - m.x, y: o.at[1] - m.y, w: o.size[0], h: o.size[1],
                monitor: t.monitor ? t.monitor.name : "",
                workspaceId: o.workspace ? o.workspace.id : (t.workspace ? t.workspace.id : -1),
                floating: !!o.floating
            }
        }
        return null
    }

    // ---- dibujo: sólo existe durante el vuelo ----
    Loader {
        objectName: "launchNeckLoader"
        anchors.fill: parent
        active: root.active && root.bond
        sourceComponent: Fluid.FluidNeck {
            objectName: "launchNeck"
            z: 0
            visible: root.neckBlend > 0.5
            bodyLeft: root.bodyX; bodyTop: root.bodyY
            bodyWidth: root.bodyW; bodyHeight: root.bodyH
            bodyCorner: root.bodyRadius
            dropLeft: root.glassX; dropTop: root.glassY
            dropWidth: root.glassW; dropHeight: root.glassH
            dropCorner: root.glassRadius
            blend: root.neckBlend
            readonly property real bodyAlpha: root.glassAlpha(root.bodyExposure)
            readonly property real dropAlpha: root.glassAlpha(root.dropExposure)
            bodyColor0: Qt.alpha(Theme.cardTop, Math.min(1, bodyAlpha + 0.08 * root.bodyExposure))
            bodyColor1: Qt.alpha(Theme.cardBot, bodyAlpha)
            bodyColor2: Qt.alpha(Qt.darker(Theme.cardBot, 1 + 0.16 * root.bodyExposure), Math.min(1, bodyAlpha + 0.04 * root.bodyExposure))
            dropColor0: Qt.alpha(Theme.cardTop, Math.min(1, dropAlpha + 0.08 * root.dropExposure))
            dropColor1: Qt.alpha(Theme.cardBot, dropAlpha)
            dropColor2: Qt.alpha(Qt.darker(Theme.cardBot, 1 + 0.16 * root.dropExposure), Math.min(1, dropAlpha + 0.04 * root.dropExposure))
            accent: Theme.accent
            bodyBand: 0.028 * 0.62 * (1 - 0.65 * root.bodyExposure)
            bodyBandHeight: Math.max(30 * root.s, 0.22 * root.bodyH)
            dropBand: 0.075 * 0.88 * (1 - 0.65 * root.dropExposure)
            dropBandHeight: Math.max(30 * root.s, 0.22 * root.glassH)
        }
    }

    Item {
        id: glass
        objectName: "launchGlass"
        z: 1
        x: root.glassX; y: root.glassY; width: root.glassW; height: root.glassH
        visible: root.active
        opacity: root.glassOpacity
        // La parte dentro de la pill se recorta (el vidrio translúcido no oculta nada).
        layer.enabled: root.overlapsBody && root.phase !== "llegando" && root.destination !== "indicator"
        layer.smooth: true
        layer.effect: ShaderEffect {
            readonly property real bodyLeft: root.bodyX - glass.x
            readonly property real bodyWidth: root.bodyW
            readonly property size itemSize: Qt.size(glass.width, glass.height)
            readonly property vector4d bodyBox: Qt.vector4d(bodyLeft + bodyWidth / 2,
                root.bodyY - glass.y + root.bodyH / 2, bodyWidth / 2, root.bodyH / 2)
            readonly property real bodyRadius: Math.min(root.bodyRadius, bodyWidth / 2, root.bodyH / 2)
            readonly property real bodyAlpha: root.glassAlpha(root.bodyExposure)
            fragmentShader: Qt.resolvedUrl("../fluid/shaders/fluid_cut.frag.qsb")
        }

        Rectangle {
            id: body
            anchors.fill: parent
            radius: root.glassRadius
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(Theme.cardTop, Math.min(1, root.glassAlpha(root.dropExposure) + 0.08 * root.dropExposure)) }
                GradientStop { position: 0.55; color: Qt.alpha(Theme.cardBot, root.glassAlpha(root.dropExposure)) }
                GradientStop { position: 1; color: Qt.alpha(Qt.darker(Theme.cardBot, 1 + 0.16 * root.dropExposure), Math.min(1, root.glassAlpha(root.dropExposure) + 0.04 * root.dropExposure)) }
            }
            border.width: Theme.borderHairline
            border.color: Qt.alpha(Theme.foreground, Theme.alphaHair * root.edgeExposure)
        }
        Image {
            objectName: "launchIcon"
            anchors.centerIn: parent
            width: root.dropSize * 0.8; height: width
            sourceSize: Qt.size(width * 2, height * 2)
            source: root.launch ? root.launch.icon : ""
            asynchronous: true
            fillMode: Image.PreserveAspectFit
            opacity: root.iconOpacity
        }
    }

    // Microgota que deja el cuello al romper (regla 4).
    Rectangle {
        objectName: "launchResidue"
        readonly property real p: root.residualMs < 0 ? 1 : root.residualMs / Math.max(1, Motion.launchResidue)
        visible: root.residualMs >= 0
        width: 6 * root.s * (1 - 0.5 * p); height: width; radius: width / 2
        x: root.residualX - width / 2; y: root.residualY - height / 2
        opacity: 1 - p
        color: Qt.alpha(Theme.cardBot, root.glassAlpha(root.bodyExposure))
        z: 1
    }
}
