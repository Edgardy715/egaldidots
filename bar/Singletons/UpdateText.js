.pragma library
// Friendly copy for update codes emitted by scripts/system-updates.py. Technical
// detail stays in the bridge's `detail` field; people only see these sentences.

function checkError(code) {
    switch (code) {
    case "network": return qsTr("Sin conexión con los servidores. Comprueba tu red y vuelve a intentarlo.")
    case "busy": return qsTr("Hay otra instalación de paquetes en curso. Espera a que termine y vuelve a comprobar.")
    case "timeout": return qsTr("Los servidores tardan demasiado en responder. Inténtalo de nuevo más tarde.")
    case "auth": return qsTr("No se concedió el permiso necesario.")
    default: return qsTr("No se pudo consultar esta fuente. Inténtalo de nuevo más tarde.")
    }
}

function checkPill(code) {
    return code === "network" ? qsTr("Sin conexión") : code === "busy" ? qsTr("Ocupado") : qsTr("No disponible")
}

// Shell (Git) states that pause updates on purpose: neutral, never an error.
function blocked(status) {
    const dirty = status.dirty && status.blocked !== "dirty"
        ? " " + qsTr("También hay cambios sin guardar.") : ""
    switch (status.blocked) {
    case "dirty": return qsTr("Hay cambios locales sin guardar en Git. Azog no los sobrescribe; guárdalos antes de actualizar.")
    case "ahead": return (status.ahead === 1 ? qsTr("Tu copia tiene un cambio propio que aún no está en el remoto.")
        : qsTr("Tu copia tiene %1 cambios propios que aún no están en el remoto.").arg(status.ahead || 0))
        + " " + qsTr("Azog espera para no mezclarlos.") + dirty
    case "no-upstream": return qsTr("Esta rama no sigue ninguna rama remota, así que no hay de dónde actualizar.") + dirty
    case "detached": return qsTr("Git no está en ninguna rama. Vuelve a una rama para recibir novedades.") + dirty
    default: return ""
    }
}

function blockedPill(status) {
    return status.blocked === "dirty" || status.blocked === "ahead" ? qsTr("Cambios locales") : qsTr("Sin rama remota")
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
    case "auth": return qsTr("Esperando tu permiso…")
    case "sync": return qsTr("Consultando los repositorios…")
    case "download": return counted ? qsTr("Descargando %1 de %2").arg(p.done).arg(p.total) : qsTr("Descargando…")
    case "build": return p.package ? qsTr("Compilando %1…").arg(p.package) : qsTr("Compilando…")
    case "verify": return qsTr("Comprobando los paquetes…")
    case "snapshot": return qsTr("Creando punto de restauración…")
    case "install": return counted ? qsTr("Instalando %1 de %2").arg(p.done).arg(p.total) : qsTr("Instalando…")
    case "finish": return qsTr("Terminando…")
    default: return qsTr("Preparando…")
    }
}

// Past the commit point a cancel is refused and power loss is the real risk.
function committed(progress) {
    return !!progress && ["snapshot", "install", "finish"].includes(progress.phase)
}

function outcome(result, source) {
    const r = result || {}
    if (r.result === "success") {
        if (source === "shell") return qsTr("Azog está al día. Se recargará para aplicar los cambios.")
        return r.reboot ? qsTr("Actualización completada. Reinicia cuando puedas para usar el nuevo sistema.")
            : qsTr("Actualización completada.")
    }
    if (r.result === "cancelled")
        return r.code === "auth" ? qsTr("No se concedió el permiso. No se ha cambiado nada.")
            : qsTr("Actualización cancelada. No se ha cambiado nada.")
    const restore = r.snapshot ? " " + qsTr("Si algo falla al arrancar, elige el punto de restauración %1 en el menú de inicio.").arg(r.snapshot) : ""
    switch (r.code) {
    case "partial": return qsTr("La actualización se interrumpió a mitad. Vuelve a intentarlo para completarla.") + restore
    case "network": return qsTr("Se perdió la conexión durante la descarga. No se ha cambiado nada; vuelve a intentarlo.")
    case "busy": return qsTr("Hay otra instalación de paquetes en curso. Espera a que termine y vuelve a intentarlo.")
    case "disk": return qsTr("No hay espacio suficiente en el disco. Libera espacio y vuelve a intentarlo.")
    case "conflict": return qsTr("Algunos paquetes necesitan una revisión manual. No se ha cambiado nada.")
    case "signature": return qsTr("Un paquete no superó la verificación de seguridad. No se ha instalado nada.")
    case "blocked": return qsTr("Azog no puede actualizarse ahora: revisa el estado de Git.")
    default: return qsTr("No se pudo completar la actualización.") + restore
    }
}
