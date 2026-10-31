.pragma library

// URLs are decoded once; literal absolute paths retain %, # and shell characters.
function localPath(value) {
    if (typeof value !== "string" || !value.length) return ""
    let path = value
    if (/^file:/i.test(path)) {
        const match = /^file:\/\/(?:localhost)?(\/[^?#]*)$/i.exec(path)
        if (!match) return ""
        try { path = decodeURIComponent(match[1]) } catch (_) { return "" }
    }
    if (path[0] !== "/" || path.indexOf("//") === 0 || /[\x00-\x1f\x7f]/.test(path)
            || path.endsWith("/") || path.split("/").some(p => p === "." || p === "..")) return ""
    return path
}
function name(path) { return path.slice(path.lastIndexOf("/") + 1) }
function openArguments(path) { return ["xdg-open", path] }
