.pragma library

// Approximate type of a file from its extension. Pure lookup: no mime database, no per-item process.

const _kinds = {}
function _add(kind, list) { for (const ext of list.split(" ")) _kinds[ext] = kind }
_add("image", "png jpg jpeg gif webp bmp svg avif tif tiff ico jxl heic")
_add("video", "mp4 mkv webm mov avi m4v wmv flv mpg mpeg ogv 3gp")
_add("audio", "mp3 flac ogg oga opus wav m4a aac wma aiff")
_add("pdf", "pdf")
_add("archive", "zip tar gz tgz xz bz2 zst 7z rar iso deb rpm")
_add("code", "qml js mjs ts tsx jsx json py rs c h cpp hpp cc go java kt sh fish lua css html xml yml yaml toml ini conf cmake sql nix")
_add("text", "txt md log csv rst tex doc docx odt rtf")

const _icons = {
    dir: "folder", image: "image", video: "movie", audio: "audio_file", pdf: "picture_as_pdf",
    archive: "folder_zip", code: "code", text: "description", file: "draft"
}

function kindOf(name, isDir) {
    if (isDir) return "dir"
    const text = String(name)
    const dot = text.lastIndexOf(".")
    if (dot <= 0) return "file"
    return _kinds[text.slice(dot + 1).toLowerCase()] || "file"
}

function iconOf(kind) { return _icons[kind] || "draft" }

function formatSize(bytes) {
    const n = Number(bytes)
    if (!(n >= 0)) return ""
    if (n < 1024) return n + " B"
    const units = ["KiB", "MiB", "GiB", "TiB"]
    let value = n / 1024, i = 0
    while (value >= 1024 && i < units.length - 1) { value /= 1024; i++ }
    return (value >= 10 ? Math.round(value) : Math.round(value * 10) / 10) + " " + units[i]
}
