.pragma library

// Classify the application/service, never the track title or artist.
function describe(identity, desktopEntry, dbusName, url) {
    const app = [identity, desktopEntry, dbusName].join(" ").toLowerCase();
    const match = /^https?:\/\/([^\/:?#]+)(?::\d+)?(?:[\/?#]|$)/i.exec(String(url || ""));
    const host = match ? match[1].toLowerCase() : "";
    if (/(^|[ ._-])spotify([ ._-]|$)/.test(app) || host === "open.spotify.com")
        return { music: true, label: "Spotify", icon: "spotify", color: "#1DB954", glyph: "music_note" };
    if (/youtube[ ._-]*music|youtubemusic/.test(app) || host === "music.youtube.com")
        return { music: true, label: "YouTube Music", icon: "youtube-music", color: "#FF0033", glyph: "play_circle" };
    if (/apple[ ._-]*music|(^|[ ._-])cider([ ._-]|$)/.test(app) || host === "music.apple.com")
        return { music: true, label: "Apple Music", icon: "apple-music", color: "#FA243C", glyph: "music_note" };
    if (host === "youtube.com" || host === "www.youtube.com" || host === "youtu.be")
        return { music: false, label: "YouTube", icon: "youtube", color: "#FF0033", glyph: "smart_display" };
    const music = /(^|[ ._-])(rhythmbox|elisa|audacious|strawberry|clementine|lollypop|amberol|tauon)([ ._-]|$)/.test(app);
    return { music: music, label: identity || desktopEntry || "Multimedia", icon: desktopEntry || "", color: "", glyph: music ? "music_note" : "play_circle" };
}
