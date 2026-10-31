.pragma library
.import "BodySprings.js" as Springs

function clamp(x,a,b) { return Math.max(a,Math.min(b,x)) }
function create(g) {
    const s={mode:'home',stored:false,armed:false,res:false,linked:true,broken:false,
        lastMove:-9,mouse:null,wanderAt:0,swallowAt:-9,seed:37,residueCount:0,
        chip:{x:g.cx,y:g.cy},spit:null,deliverTo:null}
    s.hx=Springs.create(g.cx,6,.62); s.hy=Springs.create(g.cy,6,.62)
    s.hr=Springs.create(11*g.baseH/38,10,.7)
    s.tx=Springs.create(g.cx,15,.9); s.ty=Springs.create(g.cy,15,.9)
    s.rx=Springs.create(g.cx,9,.8); s.ry=Springs.create(g.cy,9,.8)
    s.bulge=Springs.create(1,12,1)
    s.all=[s.hx,s.hy,s.hr,s.tx,s.ty,s.rx,s.ry,s.bulge]
    return s
}
function random(s) { s.seed=(1664525*s.seed+1013904223)>>>0; return s.seed/4294967296 }
function head(s,w,z) { s.hx.w=s.hy.w=w; s.hx.z=s.hy.z=z }
function release(s,t,g,b) {
    if (s.mode==='out') return
    const home=s.mode==='home', k=g.baseH/38
    s.mode='out';head(s,4.2,.62)
    if (home) {
        b.hh.v+=50*k;b.hw.v-=120*k
        s.linked=true;s.broken=false
        }
    s.hx.t=g.cx+(random(s)-.5)*60*k;s.hy.t=g.cy+110*k
    s.wanderAt=t+2.2
}
function callBack(s) { if (s.mode!=='home') { s.mode='return';head(s,5.5,.72) } }
function deliver(s,t,g,b,target) {
    if (!s.stored || s.mode!=='home') return
    release(s,t,g,b);s.mode='deliver';s.deliverTo=target || {x:g.cx-150*g.baseH/38,y:g.height-70*g.baseH/38}
    s.hx.t=s.deliverTo.x;s.hy.t=s.deliverTo.y
}
function pointerMoved(s,p,t) { s.mouse=p;if (p) s.lastMove=t }
function swallow(s,t,g,b,dragging) {
    if (s.mode!=='out' || !s.armed || s.stored || dragging
            || Math.hypot(s.hx.x-s.chip.x,s.hy.x-s.chip.y)>=22*g.baseH/38) return false
    s.armed=false;s.stored=true;s.swallowAt=t
    s.hr.t=15.5*g.baseH/38;s.hr.v+=40*g.baseH/38;b.glow.v+=2
    return true
}
// Destinos antes de la única integración compartida con el cuerpo.
function prepare(s,t,o,b) {
    const g=o.geometry,k=g.baseH/38
    s.spit=null
    s.bulge.t=s.mode==='home'?1:0
    if (s.mode==='home') { s.hx.t=g.cx;s.hy.t=g.cy;s.hr.t=11*k }
    else {
        s.hr.t=(s.stored?15.5:13)*k
        if (s.mode==='out') {
            if (s.armed && !s.stored) {
                head(s,o.itemDragging?5.2:4.4,.62);s.hx.t=s.chip.x;s.hy.t=s.chip.y
                swallow(s,t,g,b,o.itemDragging)
            } else if (s.mouse && t-s.lastMove<1.6) {
                const dx=s.hx.x-s.mouse.x,dy=s.hy.x-s.mouse.y,d=Math.hypot(dx,dy)||1
                head(s,3.6,.62)
                s.hx.t=clamp(s.mouse.x+dx/d*54*k,30*k,g.width-30*k)
                s.hy.t=clamp(s.mouse.y+dy/d*54*k,g.cy+64*k,g.height-26*k)
                s.wanderAt=t+2.5
            } else if (t>s.wanderAt && !o.reduce) {
                head(s,2.6,.62);s.hx.t=40*k+random(s)*Math.max(0,g.width-80*k)
                s.hy.t=g.cy+80*k+random(s)*Math.max(0,g.height-g.cy-120*k)
                s.wanderAt=t+3+random(s)*2.5
            }
            if (s.stored && t-s.swallowAt>.75) callBack(s)
        }
        if (s.mode==='return') { s.hx.t=g.cx;s.hy.t=g.cy }
    }
    const speed=Math.hypot(s.hx.v,s.hy.v),lag=Math.min(1,16*k/(speed*.05+1e-3))
    s.tx.t=s.hx.x-s.hx.v*.05*lag;s.ty.t=s.hy.x-s.hy.v*.05*lag
    if (s.stored && s.mode==='home') { if(o.widen!==false)b.hw.t=132*k;b.glow.t=.12 }
    if (o.reduce) s.res=false
}
// Eventos geométricos después de integrar; nunca encoge la cabeza para capturarla.
function finish(s,t,o,b) {
    const g=o.geometry,k=g.baseH/38,cx=g.cx+b.ox.x,cy=g.cy+b.oy.x
    if (s.mode==='return' && Math.hypot(s.hx.x-cx,s.hy.x-cy)<b.hh.x-s.hr.x*.4) {
        s.mode='home';s.res=false
        if (!o.reduce) { b.hw.v+=230*k;b.hh.v+=40*k;if(s.stored)b.glow.v+=2 }
    }
    if (s.mode==='deliver' && Math.hypot(s.hx.x-s.hx.t,s.hy.x-s.hy.t)<6*k
            && Math.hypot(s.hx.v,s.hy.v)<40*k) {
        s.spit={x:clamp(s.hx.x+46*k,50*k,g.width-50*k),y:clamp(s.hy.x+28*k,30*k,g.height-24*k)}
        s.chip=s.spit;s.stored=false;s.armed=false;s.mode='out';s.wanderAt=t+2.5
        if (!o.reduce) {s.hr.v-=60*k;b.glow.v+=1.5}
    }
    const nx=clamp(s.hx.x,cx-b.hw.x+b.hh.x,cx+b.hw.x-b.hh.x)
    const dx=s.hx.x-nx,dy=s.hy.x-cy,dist=Math.hypot(dx,dy)||1,gap=dist-b.hh.x-s.hr.x
    if (s.linked && gap>=24*k && (s.mode==='out'||s.mode==='deliver')) {
        s.linked=false
        if (!s.broken && !o.reduce) {
            s.rx.x=nx+dx/dist*(b.hh.x+9*k);s.ry.x=cy+dy/dist*(b.hh.x+9*k)
            s.rx.v=dx/dist*60*k;s.ry.v=dy/dist*60*k
            s.rx.t=nx;s.ry.t=cy;s.res=true;s.residueCount++
        }
        s.broken=true
    } else if (!s.linked && gap<8*k && s.mode==='return') s.linked=true
    if (s.res && Math.hypot(s.rx.x-s.rx.t,s.ry.x-s.ry.t)<b.hh.x-6*k) s.res=false
    if (o.reduce) { s.res=false;Springs.snap(s.all) }
    // La latencia de la cola no puede separar las dos esferas de la lágrima.
    const tailX=s.tx.x-s.hx.x,tailY=s.ty.x-s.hy.x
    const tailScale=Math.min(1,16*k/(Math.hypot(tailX,tailY)||1))
    const active=s.mode==='home'?0:1
    return {mode:s.mode,stored:s.stored,label:s.stored && s.mode==='home' && b.hw.x>124*k,
        drop0:[s.hx.x,s.hy.x,s.hr.x,active],drop1:[s.hx.x+tailX*tailScale,s.hy.x+tailY*tailScale,s.hr.x*.72,active],
        drop2:[s.rx.x,s.ry.x,4.2*k,s.res?1:0],drop3:[0,0,0,0],
        bulge:Math.max(0,s.bulge.x),spit:s.spit,
        needsFrames:!o.reduce && (s.mode!=='home' || s.res || !Springs.settled(s.all))}
}
// Entrada pura para pruebas: el motor QML usa prepare/finish con su misma lista.
function update(s,dt,t,o,b) {
    prepare(s,t,o,b)
    if(o.reduce) Springs.snap(s.all); else Springs.stepAll(s.all,dt)
    return finish(s,t,o,b)
}
