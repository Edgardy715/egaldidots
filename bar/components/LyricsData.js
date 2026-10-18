.pragma library

function normalized(value) {
    return String(value || "").normalize("NFKD").replace(/[\u0300-\u036f]/g, "")
        .toLowerCase().replace(/[^\p{L}\p{N}]+/gu, " ").trim().replace(/\s+/g, " ")
}

function bestMatch(records, title, artist, album, duration) {
    if (!Array.isArray(records)) throw new Error("Invalid lyrics search")
    const wantedTitle = normalized(title), wantedArtist = normalized(artist)
    const wantedAlbum = normalized(album)
    const knownDuration = isFinite(duration) && duration >= 1 && duration <= 3600
    let best = null, bestScore = -Infinity
    for (const record of records.slice(0, 20)) {
        if (!record || normalized(record.trackName || record.name) !== wantedTitle ||
                normalized(record.artistName) !== wantedArtist) continue
        const seconds = Number(record.duration)
        if (knownDuration && (!isFinite(seconds) || Math.abs(seconds - duration) > 5)) continue
        const delta = knownDuration ? Math.abs(seconds - duration) : 0
        const hasSynced = typeof record.syncedLyrics === "string" && !!record.syncedLyrics.trim()
        const hasPlain = typeof record.plainLyrics === "string" && !!record.plainLyrics.trim()
        const score = (hasSynced ? 100 : hasPlain ? 50 : 0) +
            (wantedAlbum && normalized(record.albumName) === wantedAlbum ? 10 : 0) - delta
        if (score > bestScore) { best = record; bestScore = score }
    }
    return best
}

function decode(record) {
    if (!record || typeof record !== "object" || Array.isArray(record)) throw new Error("Invalid lyrics record")
    if (record.instrumental === true) return {status: "instrumental", synced: false, lines: []}
    const lrc = typeof record.syncedLyrics === "string" ? record.syncedLyrics : ""
    const plain = typeof record.plainLyrics === "string" ? record.plainLyrics : ""
    if (lrc.length > 100000 || plain.length > 100000) throw new Error("Lyrics too large")
    const lines = []
    for (const raw of lrc.split(/\r?\n/)) {
        if (!/^\[\d{1,3}:\d{2}/.test(raw)) continue
        const tags = /\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]/g
        const text = raw.replace(/^(?:\[\d{1,3}:\d{2}(?:[.:]\d{1,3})?\])+\s*/, "").trim()
        let match
        while ((match = tags.exec(raw)) !== null) {
            if (Number(match[2]) >= 60) continue
            const time = Number(match[1]) * 60 + Number(match[2]) + Number("0." + (match[3] || "0"))
            lines.push({time: time, text: text || "♪"})
            if (lines.length > 2000) throw new Error("Too many lyric lines")
        }
    }
    if (lines.length) {
        lines.sort((a, b) => a.time - b.time)
        return {status: "ready", synced: true, lines: lines}
    }
    if (plain.trim()) {
        const rows = plain.split(/\r?\n/).map(text => ({time: -1, text: text}))
        if (rows.length > 2000) throw new Error("Too many lyric lines")
        return {status: "ready", synced: false, lines: rows}
    }
    return {status: "empty", synced: false, lines: []}
}

function indexAt(lines, position) {
    if (!lines.length || lines[0].time < 0 || !isFinite(position)) return -1
    let low = 0, high = lines.length - 1, found = -1
    while (low <= high) {
        const middle = Math.floor((low + high) / 2)
        if (lines[middle].time <= position) { found = middle; low = middle + 1 }
        else high = middle - 1
    }
    return found
}
