pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Isla · Cava. Visualizador de audio REAL (cava, no procedural). Corre:
 *
 *   cava -p <cfg> | stdbuf -o0 od -An -tu1 -w24 -v
 *
 * cava emite raw 24 bytes/frame (data_bits=8 mono) a stdout; `od` los vuelve
 * ASCII (24 decimales/línea, `-v` para NO colapsar frames repetidos en `*`);
 * `stdbuf -o0` fuerza flush por línea (sin él, od bufferiza y llegan ráfagas).
 * `SplitParser("\n")` trocea cada frame → `parseFrame` normaliza 8-bit 0..255 a
 * 0..1 con lerp rise-fast/fall-slow (el "bar-fall" clásico de los viz).
 *
 * Por qué no binario directo: Quickshell.Io expone parsers de TEXTO (SplitParser
 * emite QString); el raw 8-bit de cava tiene byte 10 (newline) como valor de
 * barra válido → cortes al azar, y bytes ≥128 rompen UTF-8. ASCII vía `od` es
 * determinista, sin bytes nulos.
 *
 * Arranque perezoso: los consumidores activos controlan `wanted` → cero CPU si
 * nadie lo pide. Graceful degrade: si cava no
 * está o crashea → `available=false`, `values` queda en ceros y la surface cae a
 * un ring calma uniforme (sigue 100% funcional, sólo sin viz vivo).
 */
Singleton {
    id: root

    /** prende/apaga el proceso de cava (lo pide el MediaSurface). */
    property bool wanted: false

    // Una surface por monitor puede pedir CAVA. Un booleano directo haría que
    // cerrar una surface apagara el stream de otra, por eso contamos consumidores.
    property var consumers: ({})

    function setConsumer(id, active) {
        var next = Object.assign({}, root.consumers)
        if (active) next[id] = true
        else delete next[id]
        root.consumers = next
        root.wanted = Object.keys(next).length > 0
    }

    /** cava está instalado; `hasFrame` indica si el stream entrega datos. */
    property bool available: false

    /** nº de barras (= cava `bars`). */
    readonly property int bars: 24

    /** array plano 0..1, normalizado + lerp. Lectura para la surface. */
    property var values: (function () {
        var a = []
        for (var i = 0; i < root.bars; i++) a.push(0)
        return a
    })()

    /** path del config cava (escrito por mí en .cava/config, al lado del bar). */
    readonly property string cfgPath: Quickshell.env("HOME") + "/.config/quickshell/bar/.cava/config"

    // estado interno lerp (no exponer)
    property var prev: (function () {
        var a = []
        for (var i = 0; i < root.bars; i++) a.push(0)
        return a
    })()

    property bool hasFrame: false

    // ---- probe: ¿cava está instalado? ----
    // Al cargar el singleton Y de forma perezosa: si algo pide el viz (wanted=true)
    // pero el probe inicial dijo "no hay cava" (p.ej. lo instalaron tras el boot),
    // re-probea. Así instalar cava a mitad de sesión se levanta solo, sin reload.
    Process {
        id: probe
        command: ["sh", "-c", "command -v cava >/dev/null 2>&1"]
        Component.onCompleted: probe.running = true
        onExited: (code) => root.available = (code === 0)
    }
    onWantedChanged: if (root.wanted && !root.available) probe.running = true

    // ---- stream principal ----
    // Regenera el config CADA lanzamiento con el monitor del sink default actual
    // (robusto a cambiar headset↔altavoces) y arranca cava unbuffered. Puntos clave:
    //   - `raw_target = /dev/stdout` (NO "stdout" — eso crea un fifo LITERAL "stdout",
    //     archivo aparte, y el audio nunca llega al stream).
    //   - `source = <default-sink>.monitor` (NO `auto` — auto agarra el micrófono,
    //     silencio; queremos lo que suena por la salida).
    //   - `stdbuf -o0 cava` fuerza flush por frame (sin él, cava block-bufferiza el
    //     binario → los frames llegan en ráfagas cada ~3s en vez de a 60fps).
    Process {
        id: stream
        running: root.wanted && root.available
        command: [
            "sh", "-c",
            "set -eu; trap 'pkill -P $$ 2>/dev/null || true' TERM INT EXIT; sink=$(pactl get-default-sink 2>/dev/null || true); [ -n \"$sink\" ] || exit 1; src=\"$sink.monitor\"; mkdir -p \"$(dirname \"" + root.cfgPath + "\")\"; printf '%s\\n' '[general]' 'bars = 24' 'framerate = 30' '' '[input]' 'method = pulse' \"source = $src\" '' '[output]' 'method = raw' 'raw_target = /dev/stdout' 'data_bits = 8' 'channels = mono' '' '[smoothing]' 'noise_reduction = 88' '' '[color]' 'gradient = 0' > \"" + root.cfgPath + "\"; stdbuf -o0 cava -p \"" + root.cfgPath + "\" </dev/null | stdbuf -o0 od -An -tu1 -w24 -v & wait"
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => root.parseFrame(line)
        }
        // onErrorOccurred NO es asignable en Quickshell.Io.Process (slot protegido).
        // `available` la decide el `probe` (¿cava instalado?), NO el stream. Un clean
        // stop (qs SIGTERMs el sh al cerrar media) sale code≠0 (128+15) —enojénlo NO
        // sería "cava se rompió". Sin esta trampa, cada cierre limpio envenenaría
        // available=false y cava no reviviría al re-abrir. Un crash mid-run se auto-
        // cura solo: values queda stal y el próximo ciclo wanted (off→on) re-arranca.
        onStarted: {
            root.hasFrame = false
            root.prev = (function () { var a = []; for (var i = 0; i < root.bars; i++) a.push(0); return a })()
            root.values = root.prev
        }
        onExited: (code) => {
            root.hasFrame = false
            root.prev = (function () { var a = []; for (var i = 0; i < root.bars; i++) a.push(0); return a })()
            root.values = root.prev
        }
    }

    /**
     * Normaliza una línea ASCII de `od` (24 decimales 0..255) → array 0..1,
     * aplicando lerp rise-fast (0.6) / fall-slow (0.16) sobre el array previo.
     * Rise/fall asimétrico = el "caída" de barras de los viz serios.
     */
    function parseFrame(line) {
        // cava arranca emitiendo un OSC title (`\033]0;cava\7`) a stdout — no es audio.
        // Salta cualquier línea que empiece con escape; el primer frame real llega luego.
        if (line.length > 0 && line.charCodeAt(0) === 27) return
        var parts = line.trim().split(/\s+/).filter(function (t) { return t.length > 0 })
        if (parts.length !== root.bars) return
        var out = []
        for (var i = 0; i < root.bars; i++) {
            var raw = Number(parts[i])
            if (!isFinite(raw) || raw < 0 || raw > 255) return
            var target = Math.max(0, Math.min(1, raw / 255))
            var p = root.prev[i] || 0
            // sube rápido, baja lento
            var next = target >= p ? (p * 0.4 + target * 0.6) : (p * 0.84 + target * 0.16)
            root.prev[i] = next
            out.push(next)
        }
        root.values = out
        root.hasFrame = true
    }

    /** apaga todo (se llama implícitamente al cerrar QS; útil para hot-reload). */
    function stop() { root.wanted = false }
}
