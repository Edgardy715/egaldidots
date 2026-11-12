.pragma library

// Pure path/URL helpers for the file explorer. No filesystem access.

function toUrl(path) {
    // encodeURIComponent escapes # % ? space and control characters; "/" stays literal.
    return "file://" + String(path).split("/").map(part => encodeURIComponent(part)).join("/")
}

// FolderListModel decodes its folder URL twice (measured: single-encoded "#", "?" and
// "%xx" names list as empty/Null), so segments are percent-encoded twice for it only.
function toFolderUrl(path) {
    return "file://" + String(path).split("/").map(part => encodeURIComponent(encodeURIComponent(part))).join("/")
}

function fromUrl(url) {
    let text = String(url)
    if (text.indexOf("file://") === 0) text = text.slice(7)
    try { text = decodeURIComponent(text) } catch (error) { /* keep the raw text */ }
    while (text.length > 1 && text.charAt(text.length - 1) === "/") text = text.slice(0, -1)
    return text
}

function _trim(path) {
    let text = String(path)
    while (text.length > 1 && text.charAt(text.length - 1) === "/") text = text.slice(0, -1)
    return text
}

// Trailing slashes dropped; for absolute paths also "//" collapsed and "." / ".." segments resolved
// lexically ("/a/b/.." -> "/a", ".." above "/" stays at "/").
function normalize(path) {
    const text = _trim(path)
    if (text.charAt(0) !== "/") return text
    const out = []
    for (const part of text.split("/")) {
        if (part === "" || part === ".") continue
        if (part === "..") out.pop()
        else out.push(part)
    }
    return "/" + out.join("/")
}

function parent(path) {
    const text = _trim(path)
    const cut = text.lastIndexOf("/")
    return cut <= 0 ? "/" : text.slice(0, cut)
}

function segments(path) {
    const text = _trim(path)
    const result = [{ name: "/", path: "/" }]
    let current = ""
    for (const part of text.split("/")) {
        if (part === "") continue
        current += "/" + part
        result.push({ name: part, path: current })
    }
    return result
}

function nearestExisting(path, existsFn) {
    let current = _trim(path)
    while (current !== "/" && !existsFn(current)) current = parent(current)
    return current
}

// Lowercase and accent-insensitive key for type-to-filter matching.
function fold(text) {
    return String(text).normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase()
}
