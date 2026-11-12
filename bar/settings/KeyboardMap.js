.pragma library

// Physical keyboard model shared by the shortcut explorer and the manager.
// A key is {sym, label, w}; sym is the Hyprland key name it produces on the
// active layout (lower-cased for matching), label what is printed on it.
// Only layouts we can name exactly get printed legends; unknown layouts keep
// letters and punctuation blank so the board never lies about where a key is.

var MODS = ["SUPER", "CTRL", "ALT", "SHIFT"]
var MOD_LABEL = {SUPER: "Super", CTRL: "Ctrl", ALT: "Alt", SHIFT: "Shift"}

function k(sym, label, w) { return {sym: sym, label: label === undefined ? sym : label, w: w || 1} }
function letters(s) { return s.split("").map(c => k(c.toLowerCase(), c)) }
function gap(w) { return {gap: true, w: w} }

const fnRow = [k("escape", "Esc"), gap(1)].concat(
    [1, 2, 3, 4].map(n => k("f" + n, "F" + n)), [gap(0.5)],
    [5, 6, 7, 8].map(n => k("f" + n, "F" + n)), [gap(0.5)],
    [9, 10, 11, 12].map(n => k("f" + n, "F" + n)))
const navTop = [k("print", "Impr"), k("scroll_lock", "Bloq"), k("pause", "Pausa")]
const nav1 = [k("insert", "Ins"), k("home", "Inicio"), k("prior", "RePág")]
const nav2 = [k("delete", "Supr"), k("end", "Fin"), k("next", "AvPág")]
const navBlank = [gap(3)]
const arrowsUp = [gap(1), k("up", "↑"), gap(1)]
const arrows = [k("left", "←"), k("down", "↓"), k("right", "→")]
const digits = "1234567890".split("").map(c => k(c, c))
// Right Alt is AltGr (a level shift, not ALT) on ISO layouts.
function bottom(iso) {
    return [k("@CTRL", "Ctrl", 1.25), k("@SUPER", "Super", 1.25), k("@ALT", "Alt", 1.25),
        k("space", "Espacio", 6.25), iso ? k("iso_level3_shift", "AltGr", 1.25) : k("@ALT", "Alt", 1.25),
        k("@SUPER", "Super", 1.25), k("menu", "Menú", 1.25), k("@CTRL", "Ctrl", 1.25)]
}

// Variable keys per layout: [sym, label] at each physical punctuation slot.
const legends = {
    us: {grave: ["grave", "`"], minus: ["minus", "-"], equal: ["equal", "="], lbracket: ["bracketleft", "["],
         rbracket: ["bracketright", "]"], backslash: ["backslash", "\\"], semicolon: ["semicolon", ";"],
         apostrophe: ["apostrophe", "'"], comma: ["comma", ","], period: ["period", "."], slash: ["slash", "/"]},
    es: {grave: ["masculine", "º"], minus: ["apostrophe", "'"], equal: ["exclamdown", "¡"], lbracket: ["dead_grave", "`"],
         rbracket: ["plus", "+"], backslash: ["ccedilla", "Ç"], semicolon: ["ntilde", "Ñ"],
         apostrophe: ["dead_acute", "´"], comma: ["comma", ","], period: ["period", "."], slash: ["minus", "-"], less: ["less", "<"]}
}

function slot(layout, name) {
    const table = legends[layout]
    if (!table || !table[name]) return {sym: "", label: "", w: 1, blank: true}
    return k(table[name][0], table[name][1])
}
function blankLetters(row, known) { return known ? row : row.map(key => ({sym: "", label: "", w: key.w, blank: true})) }

// Rows of [main block keys, navigation cluster keys]. ANSI for us, ISO for es.
function rows(layout) {
    const known = !!legends[layout]
    const iso = layout === "es"
    const s = name => slot(layout, name)
    const enter = k("return", "Intro", iso ? 1.5 : 2.25)
    return [
        {main: fnRow, nav: navTop, top: true},
        {main: [s("grave")].concat(blankLetters(digits, known), [s("minus"), s("equal"), k("backspace", "⌫", 2)]), nav: nav1},
        {main: [k("tab", "Tab", 1.5)].concat(blankLetters(letters("QWERTYUIOP"), known), [s("lbracket"), s("rbracket")],
            iso ? [enter] : [Object.assign(s("backslash"), {w: 1.5})]), nav: nav2},
        {main: [k("caps_lock", "Bloq Mayús", 1.75)].concat(blankLetters(letters("ASDFGHJKL"), known), [s("semicolon"), s("apostrophe")],
            iso ? [s("backslash"), k("return", "", 1.25)] : [enter]), nav: navBlank},
        {main: (iso ? [k("@SHIFT", "Shift", 1.25), s("less")] : [k("@SHIFT", "Shift", 2.25)])
            .concat(blankLetters(letters("ZXCVBNM"), known), [s("comma"), s("period"), s("slash"), k("@SHIFT", "Shift", 2.75)]), nav: arrowsUp},
        {main: bottom(iso), nav: arrows}
    ]
}

function modOf(key) { return key.sym.charAt(0) === "@" ? key.sym.slice(1) : "" }

function parts(keys) { return String(keys || "").split("+").map(p => p.trim()).filter(p => p.length > 0) }
function split(keys) {
    const p = parts(keys)
    const mods = p.slice(0, -1).map(m => m.toUpperCase()).filter(m => MODS.indexOf(m) >= 0)
    return {mods: MODS.filter(m => mods.indexOf(m) >= 0), key: (p[p.length - 1] || "").toLowerCase()}
}
function sameMods(a, b) { return a.length === b.length && a.every(m => b.indexOf(m) >= 0) }

// Main-map binds (enabled) reachable with exactly `mods`, indexed by key sym.
function index(binds, mods) {
    const out = {}
    for (const b of binds) {
        if (!b.enabled || b.submap) continue
        const parsed = split(b.key)
        if (!parsed.key || !sameMods(parsed.mods, mods)) continue
        if (!out[parsed.key]) out[parsed.key] = []
        out[parsed.key].push(b)
    }
    return out
}

function readable(keys) {
    return parts(keys).map(p => {
        const up = p.toUpperCase()
        if (MOD_LABEL[up]) return MOD_LABEL[up]
        if (/^mouse:272$/.test(p)) return "Clic izq."
        if (/^mouse:273$/.test(p)) return "Clic der."
        if (p === "mouse_down") return "Rueda ↓"
        if (p === "mouse_up") return "Rueda ↑"
        const low = p.toLowerCase()
        const named = {left: "←", right: "→", up: "↑", down: "↓", return: "Intro", kp_enter: "Intro (num)", space: "Espacio",
            tab: "Tab", escape: "Esc", backspace: "⌫", print: "Impr"}
        if (named[low]) return named[low]
        if (/^XF86/.test(p)) return p.replace(/^XF86/, "").replace(/([a-z])([A-Z])/g, "$1 $2")
        return p.length === 1 ? p.toUpperCase() : p
    })
}

function matches(b, query) {
    const q = String(query || "").trim().toLowerCase()
    if (!q) return true
    const hay = [b.label, b.group, b.key, readable(b.key).join(" "), b.cmd || "", b.dispatcher || "", b.submap || ""].join(" ").toLowerCase()
    return q.split(/\s+/).every(t => hay.indexOf(t) >= 0)
}

function source(b) {
    if (b.external) return b.submap ? "Configuración · submapa " + b.submap : "Configuración de Hyprland"
    if (b.custom) return "Personalizado"
    return b.overridden ? "Azog · modificado" : "Azog"
}
