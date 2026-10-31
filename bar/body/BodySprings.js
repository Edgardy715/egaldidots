.pragma library

function create(x, w, z) { return { x: x, v: 0, t: x, w: w, z: z } }
function stepOne(s, h) {
    const a = -2 * s.z * s.w * s.v - s.w * s.w * (s.x - s.t)
    s.v += a * h
    s.x += s.v * h
}
function stepAll(list, dt) {
    dt = Math.max(0, Math.min(0.05, dt))
    const n = Math.max(1, Math.ceil(dt * 240)), h = dt / n
    for (let i = 0; i < n; ++i) for (const s of list) stepOne(s, h)
}
function snap(list) { for (const s of list) { s.x = s.t; s.v = 0 } }
function settled(list, ex, ev) {
    ex = ex === undefined ? 0.02 : ex
    ev = ev === undefined ? 0.2 : ev
    return list.every(s => Math.abs(s.x - s.t) < ex && Math.abs(s.v) < ev)
}
