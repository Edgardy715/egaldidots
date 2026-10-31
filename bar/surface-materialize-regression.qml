import QtQuick
import Quickshell
import "Singletons"
import "components"

// QT_QPA_PLATFORM=offscreen quickshell -p bar/surface-materialize-regression.qml
// Spring geometry (PillMorphMotion driven by hand with step(dt)) and the content
// that materializes (PillSurfaceHost). Offscreen proves numbers, not the look.
ShellRoot {
    id: shell
    property int failures: 0
    function check(ok, message) {
        if (!ok) { failures++; console.error("FAIL", message) }
        else console.log("ok  ", message)
    }
    function fin() {
        if (failures > 0) { console.error("FAIL: surface-materialize-regression (" + failures + ")"); Qt.exit(1) }
        else { console.log("PASS: spring geometry, retarget, notification/workspace paths, materialization"); Qt.quit() }
    }

    Item {
        width: 1920; height: 1080
        PillMorphMotion {
            id: m
            manualStep: true
            s: 1; restW: 150; coreH: 38
            targetW: 150; targetH: 38; targetRadius: 19
            morphDuration: Motion.morph; notifCollapseDuration: Motion.notifCollapse
        }
        PillMorphMotion {
            id: notif
            s: 1; restW: 150; coreH: 38
            targetW: 150; targetH: 38; targetRadius: 19
            morphDuration: Motion.morph; notifCollapseDuration: Motion.notifCollapse
        }
        PillMorphMotion {
            id: ws
            s: 1; restW: 150; coreH: 38
            targetW: 150; targetH: 38; targetRadius: 19
            morphDuration: Motion.morph; notifCollapseDuration: Motion.notifCollapse
        }
        PillMorphMotion {
            id: red
            s: 1; restW: 150; coreH: 38
            targetW: 150; targetH: 38; targetRadius: 19
            reduceMotion: true
            morphDuration: Motion.morph; notifCollapseDuration: Motion.notifCollapse
        }
        Pill { id: pill; s: 1; screenName: "surface-materialize" }
    }

    // Integra `ms` milisegundos a 1/240 s y devuelve las trazas.
    function run(ms, onStep) {
        const dt = 1 / 240, n = Math.round(ms / 1000 / dt), tr = { t: [], w: [], h: [], vw: [] }
        for (let i = 1; i <= n; ++i) {
            m.step(dt)
            tr.t.push(i * dt); tr.w.push(m.width); tr.h.push(m.height); tr.vw.push(m.velW)
            if (onStep) onStep(i, tr)
        }
        return tr
    }
    function stats(arr, t, x0, T) {
        const dir = T > x0 ? 1 : -1, span = Math.abs(T - x0)
        let over = 0, t90 = -1, settle = 0
        for (let i = 0; i < arr.length; ++i) {
            over = Math.max(over, (arr[i] - T) * dir / span)
            if (t90 < 0 && (arr[i] - x0) * dir >= 0.9 * span) t90 = t[i]
            if (Math.abs(arr[i] - T) >= 0.5) settle = t[i]
        }
        return { over: over, t90: t90, settle: settle }
    }

    Timer {
        interval: 50; running: true
        onTriggered: {
            // ---- abrir: rest -> calendario 660x470 ----
            m.surfaceName = "calendar"; m.surfaceOpen = true
            m.targetW = 660; m.targetH = 470; m.targetRadius = 36
            check(m.springOn && m.integrating, "opening from rest hands geometry to the spring (not a smoothed animation)")
            const open = run(1500)
            const sw = stats(open.w, open.t, 150, 660), sh = stats(open.h, open.t, 38, 470)
            console.log("open W", JSON.stringify(sw), "H", JSON.stringify(sh))
            check(sw.over >= 0.02 && sw.over <= 0.04, "open width overshoot 2-4 % of travel (" + (sw.over * 100).toFixed(2) + " %)")
            check(sh.over >= 0.02 && sh.over <= 0.04, "open height overshoot 2-4 % of travel (" + (sh.over * 100).toFixed(2) + " %)")
            check(sw.t90 >= 0.22 && sw.t90 <= 0.30, "open width reaches 90 % at 220-300 ms (" + (sw.t90 * 1000).toFixed(0) + " ms)")
            check(sh.t90 - sw.t90 >= 0.02 && sh.t90 - sw.t90 <= 0.08, "height is softer: 90 % about 40 ms after width (+" + ((sh.t90 - sw.t90) * 1000).toFixed(0) + " ms)")
            check(sw.settle <= 0.65 && sh.settle <= 0.65, "open settles within 0.5 px by 650 ms (" + (sw.settle * 1000).toFixed(0) + "/" + (sh.settle * 1000).toFixed(0) + " ms)")
            check(m.width === 660 && m.height === 470 && !m.integrating, "open ends exactly on target and stops integrating")
            check(m.contentHeld && m.contentProgress === 1, "overshoot keeps the content revealed (growth clamps at 1)")
            check(m.closeness === 1, "closeness is 1 once settled")

            // ---- redimensionar dentro de la surface (contentHeld) ----
            m.targetH = 620
            run(5)
            check(m.kindH === "resize", "same-surface height change latches the resize kind")
            const rz = run(1200)
            const sr = stats(rz.h, rz.t, 470, 620)
            console.log("resize H", JSON.stringify(sr))
            check(sr.over <= 0.005, "resize oscillates at most 0.5 % (" + (sr.over * 100).toFixed(3) + " %)")
            check(m.height === 620 && m.contentHeld, "resize ends on target with the content held")
            m.targetH = 470; run(1200)

            // ---- retarget a mitad de vuelo: A -> B sin saltos ----
            m.surfaceName = "mixer"; m.targetW = 760; m.targetH = 600
            let w0 = 0, v0 = 0, maxJump = 0, maxDv = 0
            run(120)
            w0 = m.width; v0 = m.velW
            const pre = { w: m.springW, v: m.velW, h: m.springH, vh: m.velH }
            m.targetW = 560; m.targetH = 380
            check(m.springW === pre.w && m.velW === pre.v && m.springH === pre.h && m.velH === pre.vh,
                  "retarget mid-flight keeps position and velocity")
            let prevW = m.width, prevV = m.velW
            run(1000, (i, tr) => {
                maxJump = Math.max(maxJump, Math.abs(m.width - prevW))
                maxDv = Math.max(maxDv, Math.abs(m.velW - prevV))
                prevW = m.width; prevV = m.velW
            })
            check(maxJump < 10, "no position jump after retarget (max step " + maxJump.toFixed(2) + " px)")
            // Un subpaso de aceleración del muelle (omega^2 * recorrido * h ~ 240 px/s), no un salto.
            check(maxDv < 300, "velocity stays continuous after retarget (max step " + maxDv.toFixed(1) + " px/s)")
            check(m.width === 560 && m.height === 380, "retargeted spring settles exactly on the new target")

            // ---- cerrar al reposo ----
            m.surfaceOpen = false; m.surfaceName = ""
            m.targetW = 150; m.targetH = 38; m.targetRadius = 19
            run(5)
            check(m.kindW === "close" && m.kindH === "close", "return to rest latches the close kind")
            let minW = 1e9, minH = 1e9, minCloseness = 1, seenClosing = false
            const cl = run(1200, () => {
                minW = Math.min(minW, m.width); minH = Math.min(minH, m.height)
                if (m.width < 300) minCloseness = Math.min(minCloseness, m.closeness)
            })
            const sc = stats(cl.w, cl.t, 560, 150), sch = stats(cl.h, cl.t, 380, 38)
            console.log("close W", JSON.stringify(sc), "H", JSON.stringify(sch), "min", minW, minH)
            check(minW >= 150 - 0.3, "close width never undershoots the rest pill (min " + minW.toFixed(2) + ")")
            check(minH >= 38 - 0.012 * (380 - 38), "close height recoil stays under 1.2 % (min " + minH.toFixed(2) + ")")
            check(m.width === 150 && m.height === 38 && !m.springOn, "close lands exactly on rest and hands back to the plain path")
            check(m.closeness === 1, "closeness 1 at rest")

            shell.realtime()
        }
    }

    // ---- rutas que no cambian: notificación, aviso de workspace, movimiento reducido ----
    property real notifT0: 0
    property var notifTrace: []
    property var wsTrace: []
    function realtime() {
        notif.notifAnimating = true
        notif.targetW = 260
        check(!notif.springOn, "notification path does not use the spring")
        ws.workspaceAnimating = true
        ws.targetW = 190
        check(!ws.springOn, "workspace notice does not use the spring")
        check(ws.width === 190, "workspace notice width keeps its direct (non-animated) resolution")
        red.surfaceName = "calendar"; red.surfaceOpen = true; red.targetW = 660; red.targetH = 470
        check(!red.springOn && Math.abs(red.width - 660) < 0.01 && Math.abs(red.height - 470) < 0.01,
              "reduced motion jumps directly to the target")
        notifT0 = Date.now()
        sampler.start()
    }
    Timer {
        id: sampler
        interval: 10; repeat: true
        onTriggered: {
            const t = Date.now() - shell.notifT0
            shell.notifTrace.push([t, notif.width])
            if (t >= 600) {
                stop()
                const tr = shell.notifTrace
                let over = 0, mid = -1, reach = -1
                for (const [tt, w] of tr) {
                    over = Math.max(over, w - 260)
                    if (mid < 0 && tt >= Motion.notifCollapse / 2) mid = w
                    if (reach < 0 && Math.abs(w - 260) < 1) reach = tt
                }
                console.log("notif width: mid", mid.toFixed(1), "reach", reach, "ms over", over.toFixed(2))
                shell.check(over < 0.5, "notification width does not overshoot (" + over.toFixed(2) + " px)")
                shell.check(mid > 160 && mid < 255, "notification width is mid-flight at half its duration (" + mid.toFixed(1) + ")")
                shell.check(reach > 0 && reach <= Motion.notifCollapse + 150, "notification width arrives about its own duration (" + reach + " ms)")
                shell.materialize()
            }
        }
    }

    // ---- contenido que se materializa (Pill + PillSurfaceHost) ----
    property bool sawLayer: false
    property real minScale: 1
    property real maxScaleSeen: 0
    function hostOf() {
        let host = pill.surfaceItem
        while (host && host.displayedSurface === undefined) host = host.parent
        return host
    }
    function materialize() {
        pill.surface = "calendar"
        matSampler.t0 = Date.now(); matSampler.start()
    }
    Timer {
        id: matSampler
        property real t0: 0
        interval: 8; repeat: true
        onTriggered: {
            const host = shell.hostOf()
            const t = Date.now() - t0
            if (host && host.displayedSurface === "calendar") {
                if (host.contentLayerActive) shell.sawLayer = true
                shell.minScale = Math.min(shell.minScale, host.contentScale)
                if (host.contentScale <= 1.0001) shell.maxScaleSeen = Math.max(shell.maxScaleSeen, host.contentScale)
            }
            if (t >= 1700) {
                stop()
                shell.check(!!host, "host exists after opening")
                shell.check(shell.sawLayer, "layer was active while the content materialized")
                shell.check(shell.minScale >= 0.939 && shell.minScale < 0.99, "content scale starts near 0.94 (min " + shell.minScale.toFixed(3) + ")")
                shell.check(host && host.matP === 1 && host.contentScale === 1, "scale reaches exactly 1 once revealed")
                shell.check(host && !host.contentLayerActive && !host.materializing, "layer is off at rest (blur 0)")
                pill.surface = "mixer"
                swapSampler.start()
            }
        }
    }
    property bool sawRetire: false
    Timer {
        id: swapSampler
        property real t0: Date.now()
        interval: 8; repeat: true
        onTriggered: {
            const host = shell.hostOf()
            if (host && host.matQ < 0.999) {
                shell.sawRetire = true
                shell.check(host.contentLayerActive, "outgoing surface is blurred on a layer while it retires")
                shell.check(host.contentScale <= 1 && host.contentScale >= 0.96, "outgoing scale stays in 0.97-1")
                stop()
                swapEnd.start()
            }
        }
    }
    Timer {
        id: swapEnd
        interval: 1500
        onTriggered: {
            const host = shell.hostOf()
            shell.check(host && host.displayedSurface === "mixer" && host.contentScale === 1 && !host.contentLayerActive,
                        "after A->B the incoming surface rests at scale 1 with the layer off")
            pill.surface = ""
            closeEnd.start()
        }
    }
    Timer {
        id: closeEnd
        interval: 1500
        onTriggered: {
            shell.check(!pill.surfaceItem, "closed surface unloads")
            shell.check(Math.abs(pill.width - pill.targetW) < 0.01, "pill settles on the rest width")
            shell.fin()
        }
    }
}
