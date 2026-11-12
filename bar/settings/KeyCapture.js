.pragma library

// Qt key event -> Hyprland "MODS + key" string, or "" while only modifiers are held.
const named = {
    [Qt.Key_Return]: "Return", [Qt.Key_Enter]: "Return", [Qt.Key_Tab]: "Tab", [Qt.Key_Backtab]: "Tab",
    [Qt.Key_Space]: "space", [Qt.Key_Backspace]: "BackSpace", [Qt.Key_Delete]: "Delete",
    [Qt.Key_Insert]: "Insert", [Qt.Key_Home]: "Home", [Qt.Key_End]: "End",
    [Qt.Key_PageUp]: "Prior", [Qt.Key_PageDown]: "Next", [Qt.Key_Print]: "Print",
    [Qt.Key_Left]: "left", [Qt.Key_Right]: "right", [Qt.Key_Up]: "up", [Qt.Key_Down]: "down",
    [Qt.Key_Minus]: "minus", [Qt.Key_Equal]: "equal", [Qt.Key_Comma]: "comma", [Qt.Key_Period]: "period",
    [Qt.Key_Slash]: "slash", [Qt.Key_Semicolon]: "semicolon", [Qt.Key_Apostrophe]: "apostrophe",
    [Qt.Key_QuoteLeft]: "grave", [Qt.Key_BracketLeft]: "bracketleft", [Qt.Key_BracketRight]: "bracketright",
    [Qt.Key_Backslash]: "backslash"
}
const modifierKeys = [Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R,
    Qt.Key_AltGr, Qt.Key_CapsLock, Qt.Key_NumLock, Qt.Key_Hyper_L, Qt.Key_Hyper_R]

function keyName(key, scanCode) {
    if (key >= Qt.Key_A && key <= Qt.Key_Z) return String.fromCharCode(key)
    // Number row by physical position (xkb codes 10..19), so Shift+1 stays "1" on any layout.
    if (scanCode >= 10 && scanCode <= 19) return String((scanCode - 9) % 10)
    if (key >= Qt.Key_0 && key <= Qt.Key_9) return String.fromCharCode(key)
    if (key >= Qt.Key_F1 && key <= Qt.Key_F24) return "F" + (key - Qt.Key_F1 + 1)
    if (named[key]) return named[key]
    return scanCode > 0 ? "code:" + scanCode : ""
}

function fromEvent(key, modifiers, scanCode) {
    if (modifierKeys.indexOf(key) >= 0) return ""
    const name = keyName(key, scanCode)
    if (!name) return ""
    return mods(modifiers).concat([name]).join(" + ")
}

// Held modifiers, in canonical order; `key` adds the modifier being pressed.
function mods(modifiers, key) {
    const own = key === Qt.Key_Meta || key === Qt.Key_Super_L || key === Qt.Key_Super_R ? "SUPER"
        : key === Qt.Key_Control ? "CTRL" : key === Qt.Key_Alt ? "ALT" : key === Qt.Key_Shift ? "SHIFT" : ""
    const out = []
    if (modifiers & Qt.MetaModifier || own === "SUPER") out.push("SUPER")
    if (modifiers & Qt.ControlModifier || own === "CTRL") out.push("CTRL")
    if (modifiers & Qt.AltModifier || own === "ALT") out.push("ALT")
    if (modifiers & Qt.ShiftModifier || own === "SHIFT") out.push("SHIFT")
    return out
}

function parts(keys) { return String(keys || "").split("+").map(p => p.trim()).filter(p => p.length > 0) }
function editable(entry) { return !/mouse|XF86/.test(entry.default) }
function groups(binds) {
    const order = [], map = {}
    for (const b of binds) {
        if (!map[b.group]) { map[b.group] = []; order.push(b.group) }
        map[b.group].push(b)
    }
    return order.map(name => ({name: name, binds: map[name]}))
}
