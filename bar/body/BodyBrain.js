.pragma library
.import "BodySprings.js" as Springs

function clamp(x,a,b) { return Math.max(a,Math.min(b,x)) }
function smooth(a,b,x) { const t=clamp((x-a)/(b-a),0,1); return t*t*(3-2*t) }
function create(opts) {
    const s={cx:0,cy:0,baseW:opts.baseW,baseH:opts.baseH,mood:'auto',mouse:null,
        lastMove:0,asleep:false,taps:[],happyUntil:0,jiggleAt:0,lastBeat:-1}
    s.hw=Springs.create(s.baseW/2,11,.6); s.hh=Springs.create(s.baseH/2,12,.55)
    for (const key of ['ox','oy']) s[key]=Springs.create(0,8,.75)
    s.lean=Springs.create(0,9,.62); s.glow=Springs.create(0,5,1)
    s.dim=Springs.create(0,2.2,1); s.fA=Springs.create(0,6,1)
    for (const key of ['ax','ay']) s[key]=Springs.create(0,7,1)
    s.all=['hw','hh','ox','oy','lean','glow','dim','fA','ax','ay'].map(key=>s[key])
    return s
}
function setGeometry(s,g) { s.cx=g.cx; s.cy=g.cy; s.baseW=g.baseW; s.baseH=g.baseH }
function wake(s) { s.asleep=false; const g=s.calm?.4:1; s.hw.v+=520*g*s.baseH/38; s.hh.v-=30*g*s.baseH/38 }
function pointerMoved(s,p,t) {
    s.mouse=p
    if (!p) return
    if (s.asleep && s.mood==='auto' && Math.hypot(p.x-s.cx,p.y-s.cy)<260*s.baseH/38) wake(s)
    s.lastMove=t
}
function tapped(s,p,t) {
    const x=clamp(p.x,s.cx+s.ox.x-s.hw.x+s.hh.x,s.cx+s.ox.x+s.hw.x-s.hh.x)
    if (Math.hypot(p.x-x,p.y-s.cy-s.oy.x)>=s.hh.x+10*s.baseH/38) return false
    s.lastMove=t
    if (s.asleep) { wake(s); return true }
    const k=s.baseH/38
    s.hh.v-=110*k; s.hw.v+=300*k; s.glow.v+=3
    s.taps=s.taps.filter(at=>t-at<1.3); s.taps.push(t)
    if (s.taps.length>=3) { s.happyUntil=t+4.5; s.taps=[] }
    return true
}
function setMood(s,m,t) { s.mood=m; s.asleep=false; s.lastMove=t }
function update(s,dt,t,opts) {
    const k=s.baseH/38, reduce=!!opts.reduce
    s.calm=!!opts.calmHover
    let mood=s.mood
    if (mood==='auto') {
        if (!s.asleep && t-s.lastMove>9) s.asleep=true
        mood=s.asleep?'dormida':(t<s.happyUntil?'contenta':'curiosa')
    }
    const sleep=mood==='dormida'
    if (s.mouse && !sleep) {
        // La atención nace donde está el puntero, no viaja desde la última posición.
        if (s.fA.t===0 && s.fA.x<.02) { s.ax.x=s.mouse.x; s.ay.x=s.mouse.y; s.ax.v=s.ay.v=0 }
        s.ax.t=s.mouse.x; s.ay.t=s.mouse.y; s.fA.t=1
    } else s.fA.t=0
    const per=sleep?1.9:1, amp=reduce || !opts.breathe?0:(sleep?2.6:1.1)*k
    const br=Math.sin(t*2*Math.PI/(4.3*per))+.45*Math.sin(t*2*Math.PI/(6.7*per)+1.3)
    let px=clamp(s.ax.x,s.cx+s.ox.x-s.hw.x+s.hh.x,s.cx+s.ox.x+s.hw.x-s.hh.x), py=s.cy+s.oy.x
    let dx=s.ax.x-px,dy=s.ay.x-py
    const dist=Math.hypot(dx,dy)||1, span=Math.max(dist,s.hh.x); dx/=span; dy/=span
    const f=s.fA.x*smooth(320*k,30*k,dist)
    let tw=s.baseW/2,th=s.baseH/2,tox=0,toy=0,tl=0,gt=0,dm=0
    // Sobre la pill la atención se nota como un leve despertar del borde, no como un bulto.
    if (mood==='curiosa') {
        // calmHover (Agua): el puntero sólo enciende el borde; sin lóbulo ni empuje hacia un lado.
        if (opts.calmHover) { gt=f*.1 }
        else { tl=f*11*k; tox=dx*f*6*k; toy=dy*f*3*k; th+=f*1.5*k; gt=f*.1 }
    }
    else if (mood==='timida') { tox=-dx*f*14*k; toy=-Math.max(dy,0)*f*4*k; tw-=(4+f*18)*k; th-=(1+f*2)*k }
    else if (sleep) { th=14.5*k; tw-=6*k; toy=3*k; dm=1 }
    else if (mood==='contenta') {
        tl=f*6*k; gt=.3
        if (t>s.jiggleAt && !reduce) { s.jiggleAt=t+1.35; s.hh.v+=60*k; s.hw.v-=170*k; s.glow.v+=2.4 }
    }
    if (opts.music) {
        tw+=40*k; th+=4*k
        const beat=60/104, pulse=Math.floor(t/beat), ph=t%beat
        const external=opts.beatEnvelope!==undefined && opts.beatEnvelope>=0
        const env=external?clamp(opts.beatEnvelope,0,1):Math.exp(-ph/.16)
        if (!reduce && (external ? env>.8 && !(s.previousEnv>.8) : pulse!==s.lastBeat)) {
            s.hh.v+=14*k; s.hw.v+=26*k
        }
        s.previousEnv=env; s.lastBeat=pulse; gt=.18+.32*env
    } else { s.lastBeat=-1; s.previousEnv=0 }
    const breath=opts.maxBreathAmplitude>=0?clamp(br*amp,-opts.maxBreathAmplitude,opts.maxBreathAmplitude):br*amp
    s.hw.t=tw+breath; s.hh.t=th+breath*.45
    s.ox.t=tox; s.oy.t=toy; s.lean.t=tl; s.glow.t=gt; s.dim.t=dm
    if (reduce) Springs.snap(s.all); else Springs.stepAll(s.all,dt)
    for (const spring of s.all) {
        if (Math.abs(spring.x-spring.t)<.00001 && Math.abs(spring.v)<.0001) { spring.x=spring.t; spring.v=0 }
    }
    // El núcleo se recalcula tras integrar: el brote nunca parte de una geometría anterior.
    px=clamp(s.ax.x,s.cx+s.ox.x-s.hw.x+s.hh.x,s.cx+s.ox.x+s.hw.x-s.hh.x); py=s.cy+s.oy.x
    dx=s.ax.x-px; dy=s.ay.x-py
    // Dentro del cuerpo la dirección no se normaliza: el brote vuelve al núcleo sin voltearse.
    const reachDist=Math.hypot(dx,dy), distance=Math.max(reachDist,s.hh.x); dx/=distance; dy/=distance
    const r=s.hh.x*.62, reach=(s.hh.x-r+s.lean.x)*smooth(0,2*k,s.lean.x)
    // Peso continuo: el brote nace y se absorbe sin saltos. Con el puntero dentro
    // del núcleo no hay nada hacia donde brotar, y la unión suave sólo lo hincharía.
    const bw=smooth(0,2*k,s.lean.x)*smooth(.9*s.hh.x,1.3*s.hh.x,reachDist)
    return {pill:[s.cx+s.ox.x,s.cy+s.oy.x,Math.max(s.hw.x,s.hh.x),s.hh.x],
        bulge:[px+dx*reach,py+dy*reach,bw>.001?r*bw:0,bw>.001?bw:0], glow:Math.max(0,s.glow.x),
        night:.5*s.dim.x,spec:.8-.5*s.dim.x,mood:mood,
        needsFrames:!reduce && (!s.all.every(spring => {
            const breathing=opts.breathe && (spring===s.hw || spring===s.hh)
            return Math.abs(spring.x-spring.t)<(breathing?3.5*k:.02)
                && Math.abs(spring.v)<(breathing?6*k:.2)
        }) || mood==='contenta' || s.fA.t!==0 || Math.abs(s.fA.x)>.00001 || !!opts.music)}
}
