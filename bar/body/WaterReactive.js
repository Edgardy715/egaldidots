.pragma library
// Material vivo: pure rules for the water reacting to content. No services, no clocks;
// PillBody feeds these with Theme colours, Cava frames and OSD deltas.

var maxTint = 0.12          // tint share of the material, never above
var contrastFloor = 7       // AAA for normal text; the baseline wins when it is lower
var rippleMs = 450
var bassAttack = 0.040      // s
var bassRelease = 0.220     // s
var bassMax = 0.08          // +-8 % of the specular brightness
var tintRelaxMs = 1200

function clamp(x, a, b) { return Math.max(a, Math.min(b, x)) }
function lin(c) { return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4) }
function luminance(c) { return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b) }
function contrast(a, b) {
    var x = luminance(a), y = luminance(b)
    return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05)
}
function mix(a, b, m) { return { r: a.r + (b.r - a.r) * m, g: a.g + (b.g - a.g) * m, b: a.b + (b.b - a.b) * m } }

// Largest mix <= maxTint whose worst glass face keeps min(baseline, contrastFloor)
// against the text ink. faces are the opaque Theme cardTop/cardBot surfaces.
function tintAmount(tint, faces, ink) {
    if (!tint || !faces || !faces.length) return 0
    var worst = function (m) {
        var w = Infinity
        for (var i = 0; i < faces.length; ++i) w = Math.min(w, contrast(ink, mix(faces[i], tint, m)))
        return w
    }
    var need = Math.min(worst(0), contrastFloor)
    var best = 0
    for (var step = 1; step <= 24; ++step) {
        var m = maxTint * step / 24
        if (worst(m) + 1e-9 < need) break
        best = m
    }
    return best
}

// OSD delta (0..1 progress units) -> ripple amplitude in 0..1; proportional, bounded.
function rippleAmp(delta) {
    var a = Math.min(1, Math.abs(delta) * 10)
    return a < 0.05 ? 0 : a
}
// Shape of the decay shared with body.frag: ring amplitude at progress t (0..1).
function rippleEnvelope(amp, t) { var k = 1 - clamp(t, 0, 1); return amp * k * k }
// A new press restarts from the amplitude still visible; waves never stack.
function rippleRestart(currentAmp, delta) { return Math.min(1, currentAmp + rippleAmp(delta)) }

function bassStep(env, target, dt) {
    if (!isFinite(dt) || dt <= 0) return env
    var tau = target > env ? bassAttack : bassRelease
    var next = env + (target - env) * (1 - Math.exp(-dt / tau))
    return next < 0.01 && target <= 0 ? 0 : clamp(next, 0, 1)
}
function bassGain(env) { return 1 + bassMax * clamp(env, 0, 1) }
