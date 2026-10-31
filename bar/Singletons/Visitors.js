.pragma library

// Iris' small visitors. A visitor is a scene of IslandCompanion: a shape that crosses
// the 30x26 face slot while the eyes follow it. Only data and pure functions live here,
// so the face, the mischief policy and Iris' memory share one description.
//
// x(p), y(p): the path in face units for progress p in 0..1 (the face multiplies by its
// scale). halo/haloAlpha: diameter and strength of the soft glow, 0 for none. w/h: the
// core; ring > 0 draws it as an outline of that width. color: a Theme role. flutter:
// degrees of wing tremor. pop: the scene ends with a burst and a blink.
// weight: share of the rare mischief slot that used to be the firefly's alone.
// when(date): whether the moment suits the clock; a visitor never arrives out of season.
var table = {
    firefly: {
        label: "luciérnaga", duration: 2600, weight: 3,
        x: p => 3 + 24 * p, y: p => 5 - 2 * Math.sin(p * Math.PI * 2),
        halo: 6, haloAlpha: 0.18, w: 2, h: 2, ring: 0, color: "accentStrong", flutter: 0, pop: false,
        when: date => true
    },
    moth: {
        label: "polilla", duration: 3200, weight: 3,
        x: p => 15 + 11 * Math.sin(p * Math.PI * 2) + 0.8 * Math.sin(p * Math.PI * 6),
        y: p => 13 - 8.5 * Math.cos(p * Math.PI * 2) + 1.2 * Math.sin(p * Math.PI * 10),
        halo: 5, haloAlpha: 0.16, w: 3, h: 1.8, ring: 0, color: "accentSoft", flutter: 28, pop: false,
        when: date => date.getHours() >= 23 || date.getHours() < 6
    },
    raindrop: {
        label: "gota", duration: 1800, weight: 1.5,
        x: p => 15, y: p => 2 + 22 * p,
        halo: 0, haloAlpha: 0, w: 1.6, h: 2.8, ring: 0, color: "accentAlt", flutter: 0, pop: false,
        when: date => true
    },
    bubble: {
        label: "burbuja", duration: 2200, weight: 1.5,
        x: p => 6 + 1.2 * Math.sin(p * Math.PI * 3), y: p => 21 - 17 * p,
        halo: 0, haloAlpha: 0, w: 4.4, h: 4.4, ring: 0.7, color: "accentSoft", flutter: 0, pop: true,
        when: date => true
    },
    snowflake: {
        label: "copo", duration: 3600, weight: 3,
        x: p => 26.3 + 1.2 * Math.sin(p * Math.PI * 4), y: p => 3 + 20 * p,
        halo: 4, haloAlpha: 0.14, w: 2, h: 2, ring: 0, color: "foreground", flutter: 0, pop: false,
        when: date => date.getMonth() === 11
    }
}

var kinds = Object.keys(table)

function has(kind) { return Object.prototype.hasOwnProperty.call(table, kind) }

// Chooses among the visitors that suit `date`; u in 0..1 is the roll already available.
function pick(date, u) {
    const open = kinds.filter(kind => table[kind].when(date))
    let at = u * open.reduce((sum, kind) => sum + table[kind].weight, 0)
    return open.find(kind => (at -= table[kind].weight) < 0) || "firefly"
}

// Sightings as stored: known kinds only, whole counts 1..99.
function sanitize(raw) {
    const result = {}
    for (const kind of kinds) {
        const count = Math.max(0, Math.min(99, Math.round(Number(raw && raw[kind])) || 0))
        if (count > 0) result[kind] = count
    }
    return result
}

// "luciérnaga 3 · polilla 1", or "" when nothing has been seen.
function summary(sightings) {
    return kinds.filter(kind => sightings[kind] > 0).map(kind => table[kind].label + " " + sightings[kind]).join(" · ")
}
