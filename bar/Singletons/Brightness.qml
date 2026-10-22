pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Isla · Brightness. Brillo de backlight interno (laptop) via sysfs
 * /sys/class/backlight/<dev>/{brightness,max_brightness}. Estado reactivo + IPC
 * `island.brightness.*` para keybinds (Super+F2/F3). Emite `brightnessChanged`
 * que el OSD de la pill escucha para feedback visual.
 *
 * Inspirado en caelestia/services/Brightness.qml, simplificado: solo backlight
 * interno (DDC para monitors externos vendría después). Sin brightnessctl —
 * escribimos sysfs directo (el user necesita estar en grupo `video` o `backlight`,
 * o via udev rule; fallback inferior: pkexec sh -c echo …).
 *
 * Uso desde keybinds:
 *   bind = SUPER+F3, exec, qs -c bar ipc call island.brightness up ""
 *   bind = SUPER+F2, exec, qs -c bar ipc call island.brightness down ""
 *   bind = $mainMod+F3, exec, qs -c bar ipc call island.brightness step 10
 *   bind = , code:233, exec, qs -c bar ipc call island.brightness up "" # mon_brightness_up
 *   bind = , code:232, exec, qs -c bar ipc call island.brightness down "" # mon_brightness_down
 *
 * Si no hay backlight disponible (desktop), available=false y todo es no-op.
 */
Singleton {
    id: root

    // ---- estado ----
    property bool available: false
    property string device: ""            // primer /sys/class/backlight/<dev> que tenga max>0
    property int maxBrightness: 0
    property int rawBrightness: 0
    readonly property real percent: maxBrightness > 0
        ? Math.round(rawBrightness * 1000 / maxBrightness) / 10  // 0..100 con 1 decimal
        : 0
    /** Última mutación ledó a escritura real? (false si el write falló) */
    property bool lastWriteOk: true
    property bool _writing: false
    property int _targetRaw: -1
    property int _writeRevision: 0

    signal brightnessChanged(real percent)
    signal writeFailed()

    Component.onCompleted: detect()

    /** detección synchrone-ish: lee /sys/class/backlight via ls + cat */
    function detect(): void {
        detectProc.running = true
    }

    function refresh(): void {
        if (!available || _writing || readProc.running) return
        readProc.revision = _writeRevision
        readProc.command = ["cat", "/sys/class/backlight/" + device + "/actual_brightness"]
        readProc.running = true
    }

    function setPercent(p: real): void {
        if (!available || maxBrightness <= 0) return
        var clamped = Math.max(0, Math.min(100, p))
        var raw = Math.round(clamped * maxBrightness / 100)
        writeRaw(raw)
    }

    function stepPercent(amount: real): void {
        const base = _writing && maxBrightness > 0 ? _targetRaw * 100 / maxBrightness : percent
        setPercent(base + amount)
    }
    function increase(): void { stepPercent(10) }
    function decrease(): void { stepPercent(-10) }

    /** Escribe al sysfs. Intento 1: directo (usuario en grupo video/backlight).
     *  Fallback: pkexec sh -c (requiere polkit rule) o brightnessctl si está. */
    function writeRaw(raw: int): void {
        if (!available || device.length === 0) return
        _targetRaw = raw
        _writeRevision++
        if (!_writing) startWrite()
    }

    function startWrite(): void {
        _writing = true
        writeProc.pendingValue = _targetRaw
        writeProc.command = ["sh", "-c", "echo " + _targetRaw + " > /sys/class/backlight/" + device + "/brightness"]
        writeProc.running = true
    }

    function finishWrite(value: int, success: bool): void {
        if (success) {
            rawBrightness = value
            lastWriteOk = true
            brightnessChanged(percent)
            if (_targetRaw !== value) {
                startWrite()
                return
            }
            _targetRaw = -1
            _writing = false
        } else {
            // A denied authorization ends this burst instead of prompting again.
            _targetRaw = -1
            _writing = false
            lastWriteOk = false
            writeFailed()
            refresh()
        }
    }

    // ---- process ----

    Process {
        id: detectProc
        command: ["sh", "-c",
            "for d in /sys/class/backlight/*/; do dev=$(basename $d); max=$(cat ${d}max_brightness 2>/dev/null); " +
            "if [ -n \"$max\" ] && [ \"$max\" -gt 0 ]; then echo \"$dev $max\"; break; fi; done"]
        stdout: StdioCollector {
            id: detectColl
            onStreamFinished: {
                var out = (detectColl.text || "").trim()
                if (out.length === 0) {
                    root.available = false
                    return
                }
                var parts = out.split(/\s+/)
                if (parts.length >= 2 && parseInt(parts[1], 10) > 0) {
                    root.device = parts[0]
                    root.maxBrightness = parseInt(parts[1], 10)
                    root.available = true
                    root.refresh()
                }
            }
        }
    }

    Process {
        id: readProc
        property int revision: 0
        stdout: StdioCollector {
            id: readColl
            onStreamFinished: {
                if (root._writing || readProc.revision !== root._writeRevision) return
                var v = parseInt((readColl.text || "0").trim(), 10)
                if (!isNaN(v) && v !== root.rawBrightness) {
                    root.rawBrightness = v
                    root.brightnessChanged(root.percent)
                }
            }
        }
    }

    Process {
        id: writeProc
        property int pendingValue: -1
        stdout: StdioCollector { id: writeErrColl }

        onExited: code => {
            if (code === 0) {
                root.finishWrite(pendingValue, true)
                return
            }
            // fallback: pkexec con echo directo. requiere polkit rule
            // /etc/polkit-1/rules.d/50-brightness.rules (allow subject in group video)
            fallbackProc.command = ["sh", "-c",
                "pkexec sh -c 'echo " + root._targetRaw + " > /sys/class/backlight/" + root.device + "/brightness'"]
            fallbackProc.pendingValue = root._targetRaw
            fallbackProc.running = true
        }
    }

    Process {
        id: fallbackProc
        property int pendingValue: -1
        onExited: code => root.finishWrite(pendingValue, code === 0)
    }

    // ---- IPC: adjuntado al target "island.brightness" para keybinds separados ----
    IpcHandler {
        target: "island.brightness"
        function get(): real { return root.percent }
        function setV(p: real): void { root.setPercent(p) }
        function up(): void { root.increase() }
        function down(): void { root.decrease() }
        function step(amount: real): void { root.stepPercent(amount) }
        function isAvailable(): bool { return root.available }
    }
}
