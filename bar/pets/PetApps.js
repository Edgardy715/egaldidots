.pragma library

var codingApps = ["kitty", "foot", "alacritty", "org.wezfurlong.wezterm",
    "com.mitchellh.ghostty", "code", "code-oss", "codium", "dev.zed.zed", "neovide"]

function isCoding(appId) {
    const id = String(appId || "").toLowerCase()
    return codingApps.indexOf(id) >= 0 || id.indexOf("jetbrains-") === 0
}
