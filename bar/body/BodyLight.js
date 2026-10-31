.pragma library
function clamp(x, a, b) { return Math.max(a, Math.min(b, x)) }
function smooth(e0, e1, x) { const t = clamp((x-e0)/(e1-e0),0,1); return t*t*(3-2*t) }
function light(h) {
    h = ((h % 24) + 24) % 24
    const day = smooth(5.4,6.8,h)*(1-smooth(19.2,20.6,h))
    let a
    if (h>=6 && h<=20) a=Math.PI*(1-(h-6)/14)
    else { const hn=h<6?h+24:h; a=Math.PI*(1-(hn-20)/10) }
    return { L: [Math.cos(a),-Math.max(Math.sin(a),.12)],
        warm: day*Math.pow(1-Math.sin(clamp(a,0,Math.PI)),1.6),
        night: .62*(1-day), spec: .25+.6*day, day: day }
}
