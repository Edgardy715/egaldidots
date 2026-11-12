.pragma library

// Isla · ayudantes puros del vuelo de apps (sin estado ni QML).

/** Normaliza una clase/id para comparar: minúsculas, sin ".desktop", sin separadores. */
function norm(text) {
    return String(text || "").toLowerCase().replace(/\.desktop$/, "").replace(/[\s._-]+/g, "")
}

/**
 * Nombres con los que una ventana de esta app puede aparecer en Hyprland.
 * Regla (en orden de confianza): StartupWMClass, id del .desktop (completo y su
 * último segmento DNS inverso), binario del Exec y nombre visible. PID: el
 * DesktopEntry.execute() de Quickshell no devuelve el PID del proceso lanzado,
 * y el evento openwindow no lo trae; si un llamador lo conoce, `launch.pid` se
 * compara con info.pid del proveedor de geometría.
 */
function candidates(entry) {
    const out = []
    function add(v) {
        const n = norm(v)
        if (n.length > 1 && out.indexOf(n) < 0) out.push(n)
    }
    if (!entry) return out
    add(entry.startupClass)
    const id = String(entry.id || "").replace(/\.desktop$/, "")
    add(id)
    const dots = id.split(".")
    if (dots.length > 2) add(dots[dots.length - 1])
    const cmd = entry.command && entry.command.length ? entry.command : String(entry.execString || "").split(/\s+/)
    for (let i = 0; i < cmd.length; ++i) {
        const tok = String(cmd[i] || "")
        if (!tok || tok === "env" || tok.indexOf("=") > 0 || tok.charAt(0) === "%" || tok.charAt(0) === "-") continue
        add(tok.split("/").pop())
        break
    }
    add(entry.name)
    return out
}

/** ¿La clase de la ventana corresponde a alguno de los candidatos del lanzamiento? */
function matches(list, windowClass) {
    const c = norm(windowClass)
    if (!c || !list) return false
    for (let i = 0; i < list.length; ++i) if (list[i] === c) return true
    return false
}

/** `openwindow>>ADDRESS,WORKSPACE,CLASS,TITLE`; el título puede contener comas. */
function parseOpenWindow(data) {
    const parts = String(data || "").split(",")
    if (parts.length < 3) return null
    return { address: normAddress(parts[0]), workspace: parts[1], cls: parts[2], title: parts.slice(3).join(",") }
}

function normAddress(a) {
    return String(a || "").toLowerCase().replace(/^0x/, "")
}

function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }

/** Distancia con signo de un punto a un rectángulo redondeado (negativa dentro). */
function sdRoundBox(px, py, x, y, w, h, r) {
    const rr = Math.max(0, Math.min(r, w / 2, h / 2))
    const qx = Math.abs(px - (x + w / 2)) - (w / 2 - rr)
    const qy = Math.abs(py - (y + h / 2)) - (h / 2 - rr)
    return Math.hypot(Math.max(qx, 0), Math.max(qy, 0)) + Math.min(Math.max(qx, qy), 0) - rr
}

/** Tensión del cuello: 1 al tocar, 1.30 al romper (misma geometría que FluidCompanion). */
function stretchOf(d, capRadius, dropRadius) {
    return Math.max(0, (d + capRadius) / Math.max(1, capRadius + dropRadius))
}

function neckWaist(stretch) {
    const t = clamp((stretch - 1.02) / (1.30 - 1.02), 0, 1)
    return 0.42 * (1 - t * t * (3 - 2 * t))
}

/** Un paso del muelle 2D amortiguado (subpasos a 240 Hz). Devuelve [x, y, vx, vy]. */
function springStep(x, y, vx, vy, tx, ty, omega, zeta, dt) {
    const n = Math.max(1, Math.ceil(dt * 240)), h = dt / n
    for (let i = 0; i < n; ++i) {
        vx += (-omega * omega * (x - tx) - 2 * zeta * omega * vx) * h
        vy += (-omega * omega * (y - ty) - 2 * zeta * omega * vy) * h
        x += vx * h
        y += vy * h
    }
    return [x, y, vx, vy]
}
