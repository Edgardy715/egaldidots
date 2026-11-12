.pragma library
// Friendly copy for update codes emitted by scripts/system-updates.py. Technical
// detail stays in the bridge's `detail` field; people only see these sentences.

// Library scope cannot see the I18n singleton; it injects its translator here.
var tr = function(source) { return source }
function setTranslator(fn) { tr = fn }

function checkError(code) {
    switch (code) {
    case "network": return tr("Sin conexión con los servidores. Comprueba tu red y vuelve a intentarlo.")
    case "busy": return tr("Hay otra instalación de paquetes en curso. Espera a que termine y vuelve a comprobar.")
    case "timeout": return tr("Los servidores tardan demasiado en responder. Inténtalo de nuevo más tarde.")
    case "auth": return tr("No se concedió el permiso necesario.")
    default: return tr("No se pudo consultar esta fuente. Inténtalo de nuevo más tarde.")
    }
}

function checkPill(code) {
    return code === "network" ? tr("Sin conexión") : code === "busy" ? tr("Ocupado") : tr("No disponible")
}

// Shell (Git) states that pause updates on purpose: neutral, never an error.
function blocked(status) {
    const dirty = status.dirty && status.blocked !== "dirty"
        ? " " + tr("También hay cambios sin guardar.") : ""
    switch (status.blocked) {
    case "dirty": return tr("Hay cambios locales sin guardar en Git. Azog no los sobrescribe; guárdalos antes de actualizar.")
    case "ahead": return (status.ahead === 1 ? tr("Tu copia tiene un cambio propio que aún no está en el remoto.")
        : tr("Tu copia tiene %1 cambios propios que aún no están en el remoto.").arg(status.ahead || 0))
        + " " + tr("Azog espera para no mezclarlos.") + dirty
    case "no-upstream": return tr("Esta rama no sigue ninguna rama remota, así que no hay de dónde actualizar.") + dirty
    case "detached": return tr("Git no está en ninguna rama. Vuelve a una rama para recibir novedades.") + dirty
    default: return ""
    }
}

function blockedPill(status) {
    return status.blocked === "dirty" || status.blocked === "ahead" ? tr("Cambios locales") : tr("Sin rama remota")
}

// Progress fraction for the determinate ring, or -1 while the step has no count.
function fraction(progress) {
    if (!progress) return -1
    const share = progress.total > 0 ? Math.min(1, progress.done / progress.total) : 0
    switch (progress.phase) {
    case "sync": return 0.03
    case "download": return progress.total > 0 ? 0.05 + 0.4 * share : -1
    case "verify": return 0.47
    case "snapshot": return 0.5
    case "install": return progress.total > 0 ? 0.52 + 0.43 * share : -1
    case "finish": return 0.97
    default: return -1
    }
}

function phase(progress) {
    const p = progress || {}
    const counted = p.total > 0 && p.done > 0
    switch (p.phase) {
    case "auth": return tr("Esperando tu permiso…")
    case "sync": return tr("Consultando los repositorios…")
    case "download": return counted ? tr("Descargando %1 de %2").arg(p.done).arg(p.total) : tr("Descargando…")
    case "build": return p.package ? tr("Compilando %1…").arg(p.package) : tr("Compilando…")
    case "verify": return tr("Comprobando los paquetes…")
    case "snapshot": return tr("Creando punto de restauración…")
    case "install": return counted ? tr("Instalando %1 de %2").arg(p.done).arg(p.total) : tr("Instalando…")
    case "finish": return tr("Terminando…")
    default: return tr("Preparando…")
    }
}

// Past the commit point a cancel is refused and power loss is the real risk.
function committed(progress) {
    return !!progress && ["snapshot", "install", "finish"].includes(progress.phase)
}

function outcome(result, source) {
    const r = result || {}
    if (r.result === "success") {
        if (source === "shell") return tr("Azog está al día. Se recargará para aplicar los cambios.")
        return r.reboot ? tr("Actualización completada. Reinicia cuando puedas para usar el nuevo sistema.")
            : tr("Actualización completada.")
    }
    if (r.result === "cancelled")
        return r.code === "auth" ? tr("No se concedió el permiso. No se ha cambiado nada.")
            : tr("Actualización cancelada. No se ha cambiado nada.")
    const restore = r.snapshot ? " " + tr("Si algo falla al arrancar, elige el punto de restauración %1 en el menú de inicio.").arg(r.snapshot) : ""
    switch (r.code) {
    case "partial": return tr("La actualización se interrumpió a mitad. Vuelve a intentarlo para completarla.") + restore
    case "network": return tr("Se perdió la conexión durante la descarga. No se ha cambiado nada; vuelve a intentarlo.")
    case "busy": return tr("Hay otra instalación de paquetes en curso. Espera a que termine y vuelve a intentarlo.")
    case "disk": return tr("No hay espacio suficiente en el disco. Libera espacio y vuelve a intentarlo.")
    case "conflict": return tr("Algunos paquetes necesitan una revisión manual. No se ha cambiado nada.")
    case "signature": return tr("Un paquete no superó la verificación de seguridad. No se ha instalado nada.")
    case "blocked": return tr("Azog no puede actualizarse ahora: revisa el estado de Git.")
    default: return tr("No se pudo completar la actualización.") + restore
    }
}
