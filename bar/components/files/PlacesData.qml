import QtQuick
import Quickshell
import Quickshell.Io

// Sidebar data for the file explorer: XDG user folders that exist and block devices from lsblk.
// Names are Spanish source strings; the view translates them. Parsing is exposed as pure
// functions and the raw outputs are plain properties, so tests inject text without touching the
// system. Refresh runs on demand, and every 30 s only while `active` (set by the composition).
Item {
    id: root
    visible: false

    property bool active: false
    property string homeDir: Quickshell.env("HOME") || ""
    property string configHome: ""        // XDG_CONFIG_HOME override (tests); "" keeps the session's
    property string userDirsOutput: ""    // lines "KEY=/abs/path", only folders that exist
    property string lsblkOutput: ""       // lsblk -J output

    readonly property var places: parsePlaces(userDirsOutput)
    readonly property var drives: parseDrives(lsblkOutput)

    readonly property var _xdg: [
        ["DESKTOP", "Escritorio", "desktop_windows"], ["DOCUMENTS", "Documentos", "description"],
        ["DOWNLOAD", "Descargas", "download"], ["MUSIC", "Música", "music_note"],
        ["PICTURES", "Imágenes", "image"], ["VIDEOS", "Vídeos", "movie"]
    ]

    function parsePlaces(text) {
        const found = {}
        for (const line of String(text || "").split("\n")) {
            const cut = line.indexOf("=")
            if (cut <= 0) continue
            const path = line.slice(cut + 1)
            if (path.length > 0 && path.charAt(0) === "/") found[line.slice(0, cut)] = path
        }
        const result = []
        if (found.HOME) result.push({ name: "Inicio", path: found.HOME, icon: "home" })
        for (const entry of _xdg)
            if (found[entry[0]] && found[entry[0]] !== found.HOME)
                result.push({ name: entry[1], path: found[entry[0]], icon: entry[2] })
        return result
    }

    function _flag(value) { return value === true || value === 1 || value === "1" || value === "true" }

    function _under(path, base) { return path === base || path.indexOf(base + "/") === 0 }
    // MOUNTPOINTS (array, btrfs subvolumes mount several times) with MOUNTPOINT as fallback:
    // "/" wins, otherwise the shortest real mountpoint; "[SWAP]" and friends are kept for the caller to drop.
    function _mountOf(node) {
        const all = []
        if (Array.isArray(node.mountpoints)) for (const m of node.mountpoints) if (typeof m === "string" && m.length > 0) all.push(m)
        if (all.length === 0 && typeof node.mountpoint === "string" && node.mountpoint.length > 0) all.push(node.mountpoint)
        if (all.length === 0) return ""
        if (all.indexOf("/") >= 0) return "/"
        const real = all.filter(m => m.charAt(0) === "/")
        if (real.length === 0) return all[0]
        return real.reduce((best, m) => m.length < best.length ? m : best)
    }

    // Mounted partitions are listed (without boot/swap plumbing); unmounted ones only when removable.
    function parseDrives(json) {
        let data
        try { data = JSON.parse(String(json || "")) } catch (error) { return [] }
        if (!data || !Array.isArray(data.blockdevices)) return []
        const result = []
        const walk = (node, removable) => {
            if (!node || typeof node !== "object") return
            const rm = removable || _flag(node.rm)
            const kids = Array.isArray(node.children) ? node.children : []
            for (const child of kids) walk(child, rm)
            if (kids.length > 0 || node.type === "loop") return
            if (node.type === "rom" || /^0(\.0+)?[BK]?$/.test(String(node.size || "").trim())) return
            const mount = _mountOf(node)
            if (mount.length > 0 && (mount.charAt(0) !== "/" || _under(mount, "/boot") || _under(mount, "/efi"))) return
            if (mount.length === 0 && !rm) return
            const label = node.label ? String(node.label) : ""
            result.push({ name: label || String(node.name || ""), path: mount, mounted: mount.length > 0, size: String(node.size || "") })
        }
        for (const node of data.blockdevices) walk(node, false)
        return result
    }

    function refresh() { refreshPlaces(); refreshDrives() }
    function refreshPlaces() { if (!placesProc.running) placesProc.running = true }
    function refreshDrives() { if (!lsblkProc.running) lsblkProc.running = true }

    onActiveChanged: if (active) refresh()

    Timer {
        interval: 30000
        repeat: true
        running: root.active
        onTriggered: root.refresh()
    }

    Process {
        id: placesProc
        environment: root.configHome.length > 0 ? ({ XDG_CONFIG_HOME: root.configHome, HOME: root.homeDir }) : ({ HOME: root.homeDir })
        command: ["sh", "-c", `
            h=$HOME
            [ -d "$h" ] && printf 'HOME=%s\\n' "$h"
            for k in DESKTOP DOCUMENTS DOWNLOAD MUSIC PICTURES VIDEOS; do
                p=$(xdg-user-dir "$k" 2>/dev/null)
                [ -n "$p" ] && [ -d "$p" ] && printf '%s=%s\\n' "$k" "$p"
            done
            exit 0`]
        stdout: StdioCollector { onStreamFinished: root.userDirsOutput = text }
    }
    Process {
        id: lsblkProc
        command: ["lsblk", "-J", "-o", "NAME,LABEL,MOUNTPOINTS,SIZE,RM,TYPE"]
        stdout: StdioCollector { onStreamFinished: root.lsblkOutput = text }
    }
}
