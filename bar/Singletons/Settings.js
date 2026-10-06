.pragma library

// The settings contract is independent of QML services and filesystem access.
// Keep defaults, editor metadata and validation together so clients can discover
// the same rules that the running shell applies.
var version = 1
var fields = {
    appearance: {
        glassAlpha: { type: "number", default: 0.34, minimum: 0.15, maximum: 1, label: "Opacidad del vidrio", control: "number", description: "Ajusta la opacidad del material de vidrio." },
        pillBlur: { type: "boolean", default: false, label: "Desenfoque de la pill", control: "toggle", options: [false, true], availability: "inactive", description: "Se conserva en la configuración, pero no tiene consumidor activo." },
        topGap: { type: "number", default: 1, minimum: 0, label: "Separación superior", control: "number", description: "Multiplicador del espacio entre Isla y el borde superior." },
        appGap: { type: "number", default: 1, minimum: 0, label: "Separación del área de aplicaciones", control: "number", description: "Multiplicador del espacio reservado junto a la barra de aplicaciones." },
        uiScale: { type: "number", default: 1, minimum: 0.25, label: "Escala de interfaz", control: "number", description: "Escala la interfaz respecto a la altura del monitor." },
        fontScale: { type: "number", default: 1, minimum: 0.75, maximum: 1.75, label: "Tamaño de texto", control: "number", description: "Escala los tamaños tipográficos del shell." },
        spacingScale: { type: "number", default: 1, minimum: 0.75, maximum: 1.5, label: "Escala de espaciado", control: "number", description: "Escala los espacios y márgenes del tema." },
        radiusScale: { type: "number", default: 1, minimum: 0.75, maximum: 1.5, label: "Escala de redondez", control: "number", description: "Escala los radios del tema." },
        motionScale: { type: "number", default: 1, minimum: 0.25, maximum: 2, label: "Escala de movimiento", control: "number", description: "Escala las duraciones y propiedades de movimiento." },
        fontFamily: { type: "string", default: "Google Sans Flex", minLength: 1, label: "Familia tipográfica", control: "text", description: "Nombre de una familia instalada; no se enumera ni valida la fuente instalada." },
        fontMonoFamily: { type: "string", default: "JetBrainsMono Nerd Font", minLength: 1, label: "Familia monoespaciada", control: "text", description: "Nombre de una familia instalada para texto monoespaciado." },
        fontDisplayFamily: { type: "string", default: "Rubik", minLength: 1, label: "Familia de títulos", control: "text", description: "Nombre de una familia instalada para texto de display." },
        fontMediaFamily: { type: "string", default: "Inter", minLength: 1, label: "Familia multimedia", control: "text", description: "Nombre de una familia instalada para vistas multimedia y de sesión." },
        reduceMotion: { type: "boolean", default: false, label: "Reducir movimiento", control: "toggle", options: [false, true], description: "Reduce o desactiva animaciones compatibles con esta opción." },
        time12h: { type: "boolean", default: true, label: "Reloj de 12 horas", control: "toggle", options: [false, true], description: "Afecta el calendario y la pantalla de bloqueo; el reloj compacto de la pill conserva formato de 12 horas." },
        clockSeconds: { type: "boolean", default: false, label: "Actualizar reloj cada segundo", control: "toggle", options: [false, true], availability: "partial", description: "Actualiza el dato del reloj cada segundo; la presentación visible actual no muestra segundos." },
        showGlyphs: { type: "boolean", default: true, label: "Mostrar glifos", control: "toggle", options: [false, true], availability: "inactive", description: "Se conserva en la configuración, pero no tiene consumidor activo." }
    },
    modules: {
        workspaceRail: { type: "boolean", default: true, label: "Espacios de trabajo", control: "toggle", options: [false, true], description: "Muestra el rail de navegación de workspaces." },
        systemStatus: { type: "boolean", default: true, label: "Contenedor de estado", control: "toggle", options: [false, true], description: "Habilita el contenedor derecho cuando tiene algún indicador o lista de apps." },
        apps: { type: "boolean", default: true, label: "Aplicaciones activas", control: "toggle", options: [false, true], description: "Muestra aplicaciones del workspace activo cuando las hay." },
        audio: { type: "boolean", default: true, label: "Audio", control: "toggle", options: [false, true], description: "Muestra el acceso al mezclador; sin salida PipeWire presenta el estado sin audio." },
        network: { type: "boolean", default: true, label: "Red", control: "toggle", options: [false, true], description: "Muestra el indicador Wi-Fi conectado o desconectado." },
        battery: { type: "boolean", default: true, label: "Batería", control: "toggle", options: [false, true], availability: "conditional", description: "Solo se muestra cuando UPower informa una batería de laptop presente." },
        animateChanges: { type: "boolean", default: true, label: "Animar cambios de módulos", control: "toggle", options: [false, true], description: "Anima la entrada y retirada de módulos; no desactiva el resto de animaciones." }
    },
    profile: {
        displayName: { type: "string", default: "", minLength: 0, label: "Nombre visible", control: "text", description: "Nombre mostrado en la vista de sesión; vacío usa el nombre de la sesión." }
    },
    paths: {
        userAvatar: { type: "string", path: true, base: "home", suffix: "/.face", label: "Avatar", control: "path", description: "Ruta de la imagen de usuario para sesión y bloqueo." },
        walColorsFile: { type: "string", path: true, base: "cacheHome", suffix: "/wal/colors.json", label: "Archivo de colores", control: "path", description: "Archivo de colores que consume la paleta de Isla." },
        wallpaperDir: { type: "string", path: true, base: "home", suffix: "/Wallpapers", label: "Carpeta de wallpapers", control: "path", description: "Carpeta de origen del selector de wallpapers." },
        wallpaperCacheDir: { type: "string", path: true, base: "cacheHome", suffix: "/quickshell/wallpapers", label: "Caché de wallpapers", control: "path", description: "Carpeta para miniaturas generadas por el selector." },
        wallpaperApplyScript: { type: "string", path: true, base: "configHome", suffix: "/hypr/scripts/apply-wallpaper.sh", label: "Script de wallpaper", control: "path", description: "Script ejecutado para aplicar el wallpaper seleccionado." }
    }
}

function isObject(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value)
}

function copy(value) { return JSON.parse(JSON.stringify(value)) }

function schema(context) {
    var result = { version: version, sections: copy(fields) }
    Object.keys(result.sections).forEach(function(section) {
        Object.keys(result.sections[section]).forEach(function(key) {
            var field = result.sections[section][key]
            field.availability = field.availability || "available"
            if (section === "modules") {
                var moduleInfo = optionalModules.find(function(module) { return module.id === key })
                if (moduleInfo) {
                    ["parentModule", "availability", "dependencyMode", "visibleWhen", "dependsOn"]
                        .forEach(function(name) {
                            if (moduleInfo[name] !== undefined) field[name] = copy(moduleInfo[name])
                        })
                }
            }
            if (section === "paths") {
                field.default = context[field.base] + field.suffix
                field.acceptedForms = ["absolute", "~", "~/relative"]
                delete field.base
                delete field.suffix
            }
        })
    })
    return result
}

var sectionCatalog = [
    { id: "appearance", label: "Apariencia", description: "Escala, tipografía, color y movimiento." },
    { id: "modules", label: "Módulos de la barra", description: "Entradas laterales opcionales y sus controles." },
    { id: "profile", label: "Perfil", description: "Datos de presentación de la sesión." },
    { id: "paths", label: "Rutas", description: "Archivos y carpetas que consumen servicios del shell." }
]

var requiredModules = [
    { id: "pill", label: "Isla principal", configurable: false, required: true,
      availability: "always", dependsOn: ["quickshell", "wayland-layer-shell"] }
]

var optionalModules = [
    { id: "workspaceRail", setting: "modules.workspaceRail", label: "Espacios de trabajo",
      configurable: true, availability: "supported", dependsOn: ["hyprland.workspaces"] },
    { id: "systemStatus", setting: "modules.systemStatus", label: "Contenedor de estado",
      configurable: true, availability: "when-any-child-enabled-and-content-fits",
      dependencyMode: "any", visibleWhen: ["modules.apps", "modules.audio", "modules.network", "modules.battery"],
      dependsOn: ["modules.apps", "modules.audio", "modules.network", "modules.battery"] },
    { id: "apps", setting: "modules.apps", label: "Aplicaciones activas",
      configurable: true, parentModule: "systemStatus", availability: "when-present", dependsOn: ["hyprland.toplevels", "desktop-entries"] },
    { id: "audio", setting: "modules.audio", label: "Audio",
      configurable: true, parentModule: "systemStatus", availability: "supported-with-fallback", dependsOn: ["pipewire.defaultAudioSink"] },
    { id: "network", setting: "modules.network", label: "Red",
      configurable: true, parentModule: "systemStatus", availability: "supported-with-fallback", dependsOn: ["nmcli.wifi"] },
    { id: "battery", setting: "modules.battery", label: "Batería",
      configurable: true, parentModule: "systemStatus", availability: "when-present", dependsOn: ["upower.laptopBattery"] }
]

// This is an inventory of routed surfaces and service requirements, not a live
// probe. `availability` describes runtime behavior; capabilities below identify
// which existing consumer performs a check when the project has one.
var surfaces = [
    { id: "appearance", label: "Apariencia", availability: "routed", dependsOn: ["settings.config"], optionalDependsOn: [] },
    { id: "auth", label: "Autenticación", availability: "routed", dependsOn: ["quickshell.polkit", "isla-sudo-askpass"], optionalDependsOn: [] },
    { id: "calendar", label: "Calendario", availability: "routed", dependsOn: ["system-clock"], optionalDependsOn: ["curl", "weather.wttr.in"] },
    { id: "clipboard", label: "Portapapeles", availability: "routed", dependsOn: ["cliphist"], optionalDependsOn: ["wl-copy", "magick"] },
    { id: "connectivity", label: "Conectividad", availability: "routed", dependsOn: ["nmcli.wifi"], optionalDependsOn: ["quickshell.bluetooth.defaultAdapter"] },
    { id: "launcher", label: "Lanzador", availability: "routed", dependsOn: ["desktop-entries", "quickshell.execDetached"], optionalDependsOn: [] },
    { id: "media", label: "Multimedia", availability: "routed", dependsOn: [], optionalDependsOn: ["mpris.players", "cava"] },
    { id: "mixer", label: "Mezclador", availability: "routed", dependsOn: [], optionalDependsOn: ["pipewire.defaultAudioSink"] },
    { id: "notifs", label: "Notificaciones", availability: "routed", dependsOn: ["quickshell.notification-server"], optionalDependsOn: [] },
    { id: "overview", label: "Vista general", availability: "routed", dependsOn: ["hyprland.monitors", "hyprland.workspaces", "hyprland.toplevels"], optionalDependsOn: [] },
    { id: "session", label: "Sesión y energía", availability: "routed", dependsOn: ["island.session"], optionalDependsOn: ["island.lockscreen", "hyprctl", "systemctl"] },
    { id: "utils", label: "Controles rápidos", availability: "routed", dependsOn: [], optionalDependsOn: ["systemd-inhibit", "sysfs.backlight", "powerprofilesctl"] },
    { id: "wallpaper", label: "Wallpapers", availability: "routed", dependsOn: ["wallpaper.directory"], optionalDependsOn: ["wallpaper.apply-script", "magick", "mpris.players"] },
    { id: "workspaces", label: "Espacios de trabajo", availability: "routed", dependsOn: ["hyprland.workspaces"], optionalDependsOn: [] }
]

var capabilities = [
    { id: "hyprland.monitors", label: "Monitores Hyprland", availability: "runtime", detectedBy: "IslandOverlay" },
    { id: "hyprland.workspaces", label: "Workspaces Hyprland", availability: "runtime", detectedBy: "WorkspaceModel" },
    { id: "hyprland.toplevels", label: "Ventanas Hyprland", availability: "runtime", detectedBy: "TopSystemStatus / WinMap" },
    { id: "pipewire.defaultAudioSink", label: "Salida PipeWire", availability: "runtime", detectedBy: "MixerAdapter / TopSystemStatus", fallback: "El mezclador permanece disponible sin sink." },
    { id: "nmcli.wifi", label: "Wi-Fi vía nmcli", availability: "runtime", detectedBy: "Nmcli", fallback: "La vista muestra el estado desconectado cuando Wi-Fi está apagado." },
    { id: "quickshell.bluetooth.defaultAdapter", label: "Adaptador Bluetooth", availability: "runtime", detectedBy: "ConnectivityAdapter", fallback: "La pestaña Bluetooth no puede operar sin adaptador." },
    { id: "upower.laptopBattery", label: "Batería de laptop", availability: "runtime-conditional", detectedBy: "TopSystemStatus.hasBattery", condition: "UPower displayDevice ready, isLaptopBattery e isPresent" },
    { id: "sysfs.backlight", label: "Backlight interno", availability: "runtime-conditional", detectedBy: "Brightness.available", condition: "Se detecta un dispositivo en /sys/class/backlight." },
    { id: "mpris.players", label: "Reproductores MPRIS", availability: "runtime-conditional", detectedBy: "Players.list" },
    { id: "cava", label: "Visualizador CAVA", availability: "runtime-conditional", detectedBy: "Cava.available" },
    { id: "quickshell.notification-server", label: "Servidor de notificaciones", availability: "runtime", detectedBy: "Notifs NotificationServer" },
    { id: "desktop-entries", label: "Entradas de aplicaciones", availability: "runtime", detectedBy: "DesktopEntries" },
    { id: "cliphist", label: "Historial del portapapeles", availability: "external-unprobed", detectedBy: "ClipboardController Process" },
    { id: "wl-copy", label: "Copia Wayland", availability: "external-unprobed", detectedBy: "ClipboardController Process" },
    { id: "magick", label: "ImageMagick", availability: "external-unprobed", detectedBy: "ClipboardPreviewAdapter / Wallpapers" },
    { id: "curl", label: "Cliente HTTP", availability: "external-unprobed", detectedBy: "CalendarData Process" },
    { id: "weather.wttr.in", label: "Servicio de clima", availability: "network-conditional", detectedBy: "CalendarData curl request" },
    { id: "systemd-inhibit", label: "Inhibición de reposo", availability: "external-unprobed", detectedBy: "KeepAwake Process" },
    { id: "powerprofilesctl", label: "Perfiles de energía", availability: "external-unprobed", detectedBy: "QuickControlsAdapter profileReader" },
    { id: "wallpaper.apply-script", label: "Aplicador de wallpaper", availability: "path-configured-unprobed", detectedBy: "Wallpapers.applyScript" },
    { id: "wallpaper.directory", label: "Carpeta de wallpapers", availability: "path-configured-unprobed", detectedBy: "Wallpapers.wallDir" },
    { id: "island.lockscreen", label: "Bloqueador de Isla", availability: "path-configured-unprobed", detectedBy: "Session.lockCmd / quickshell-lockscreen wrapper" },
    { id: "hyprctl", label: "Control Hyprland", availability: "external-unprobed", detectedBy: "Session.logoutCmd / WorkspaceModel" },
    { id: "systemctl", label: "Acciones de energía systemd", availability: "external-unprobed", detectedBy: "Session shutdown/reboot/suspend/hibernate commands" },
    { id: "quickshell.execDetached", label: "Lanzamiento de procesos", availability: "runtime", detectedBy: "Quickshell.execDetached" },
    { id: "system-clock", label: "Reloj del sistema", availability: "runtime", detectedBy: "Qt Date" },
    { id: "settings.config", label: "Configuración del shell", availability: "runtime", detectedBy: "Config" },
    { id: "quickshell.polkit", label: "Agente Polkit", availability: "runtime-conditional", detectedBy: "Auth.registered / Auth.agent" },
    { id: "isla-sudo-askpass", label: "Canal askpass local", availability: "runtime-conditional", detectedBy: "Auth sudo askpass socket" },
    { id: "island.session", label: "Acciones de sesión", availability: "runtime", detectedBy: "Session singleton IPC" },
    { id: "quickshell", label: "Quickshell", availability: "runtime", detectedBy: "Shell process" },
    { id: "wayland-layer-shell", label: "Capa Wayland", availability: "runtime", detectedBy: "WlrLayershell windows" }
]

function catalog(context) {
    return {
        version: version,
        availabilityIsLive: false,
        sections: schema(context).sections,
        sectionOrder: copy(sectionCatalog),
        requiredModules: copy(requiredModules),
        optionalModules: copy(optionalModules),
        surfaces: copy(surfaces),
        capabilities: copy(capabilities)
    }
}

function defaults(context) {
    var result = { version: version }
    var sections = schema(context).sections
    Object.keys(sections).forEach(function(section) {
        result[section] = {}
        Object.keys(sections[section]).forEach(function(key) {
            result[section][key] = sections[section][key].default
        })
    })
    return result
}

// Unknown keys survive round trips. Known invalid values reject the complete
// document rather than partially applying changes to the live scene.
function validate(document, context) {
    var errors = []
    var effective = defaults(context)
    if (!isObject(document)) return { ok: false, errors: ["Settings must be an object"] }
    if (document.version !== undefined && document.version !== version)
        errors.push("Unsupported settings version: " + document.version)
    Object.keys(fields).forEach(function(section) {
        if (document[section] === undefined) return
        if (!isObject(document[section])) {
            errors.push(section + " must be an object")
            return
        }
        Object.keys(fields[section]).forEach(function(key) {
            var value = document[section][key]
            if (value === undefined) return
            var rule = fields[section][key]
            var name = section + "." + key
            if (typeof value !== rule.type || (rule.type === "number" && !isFinite(value))) {
                errors.push(name + " must be " + rule.type)
                return
            }
            if ((rule.minimum !== undefined && value < rule.minimum)
                || (rule.maximum !== undefined && value > rule.maximum)) {
                errors.push(name + " is outside its allowed range")
                return
            }
            if (rule.type === "string" && ((value.trim().length < (rule.minLength === undefined ? 1 : rule.minLength)) || value.indexOf("\u0000") !== -1)) {
                errors.push(name + " has an invalid length or contains NUL")
                return
            }
            if (rule.path) {
                value = value === "~" ? context.home
                    : value.indexOf("~/") === 0 ? context.home + value.slice(1) : value
                if (value.charAt(0) !== "/") {
                    errors.push(name + " must be an absolute path or start with ~/")
                    return
                }
            }
            effective[section][key] = value
        })
    })
    return { ok: errors.length === 0, errors: errors, effective: effective }
}

// A patch merges one section at a time; it never replaces another section or
// silently drops extensions written by another tool.
function merge(document, patch) {
    if (!isObject(patch)) throw new Error("Patch must be an object")
    var result = copy(document)
    Object.keys(patch).forEach(function(key) {
        if (key === "__proto__" || key === "constructor" || key === "prototype")
            throw new Error("Reserved settings key")
        if (isObject(patch[key]) && isObject(result[key])) {
            Object.keys(patch[key]).forEach(function(name) {
                if (name === "__proto__" || name === "constructor" || name === "prototype")
                    throw new Error("Reserved settings key")
                result[key][name] = copy(patch[key][name])
            })
        } else result[key] = copy(patch[key])
    })
    result.version = patch.version === undefined ? version : patch.version
    return result
}
