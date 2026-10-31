const fs=require('node:fs'), vm=require('node:vm'), assert=require('node:assert/strict');
function load(name,context={}) {
    vm.createContext(context);
    vm.runInContext(fs.readFileSync(`bar/body/${name}.js`,'utf8').replace(/^\.(pragma|import).*$/gm,''),context);
    return context;
}
const S=load('BodySprings'), B=load('BodyBrain',{Springs:S}), L=load('BodyLight');
const opts={breathe:false,reduce:false,music:false};
function run(s,seconds,t=0,extra={}) { let r; for(let i=1;i<=Math.round(seconds*240);i++) r=B.update(s,1/240,t+i/240,{...opts,...extra}); return r; }
let spring=S.create(0,11,.6); spring.t=10;
for(let t=0;t<2.9;t+=1/240) S.stepAll([spring],1/240);
assert(S.settled([spring]));
spring=S.create(0,11,.6); spring.t=10; S.stepAll([spring],.05);
const x=spring.x,v=spring.v; spring.t=-5; assert.equal(spring.v,v); assert.equal(spring.x,x);
S.stepAll([spring],1/240); assert(Math.abs(spring.x-x)<1);
const positions=[30,60,144,240].map(hz=>{const s=S.create(0,11,.6);s.t=10;for(let i=0;i<hz;i++)S.stepAll([s],1/hz);return s.x});
assert(Math.max(...positions)-Math.min(...positions)<.05,positions.join(','));
spring=S.create(0,11,.6);spring.t=10;S.stepAll([spring],.5);assert(Math.abs(spring.x)<20);
let s=B.create({baseW:220,baseH:38}); let r=B.update(s,.05,9.01,opts); assert.equal(r.mood,'dormida');
B.pointerMoved(s,{x:150,y:0},9.1); assert(s.hw.v>0);assert.equal(B.update(s,0,9.1,opts).mood,'curiosa');
s=B.create({baseW:220,baseH:38});
assert(!B.tapped(s,{x:500,y:0},0));
for(const t of [.1,.5,1])assert(B.tapped(s,{x:0,y:0},t));
assert.equal(B.update(s,0,1.1,opts).mood,'contenta');assert.equal(B.update(s,0,5.49,opts).mood,'contenta');
assert.equal(B.update(s,0,5.51,opts).mood,'curiosa');
r=B.update(s,.05,5.6,{...opts,reduce:true});assert(s.all.every(s=>s.x===s.t && s.v===0));assert.equal(r.needsFrames,false);
s=B.create({baseW:220,baseH:38});B.setMood(s,'curiosa',0);B.pointerMoved(s,{x:150,y:0},0);
r=run(s,4);assert(r.bulge[0]>s.cx);
const core=Math.max(s.cx+s.ox.x-s.hw.x+s.hh.x,Math.min(s.cx+s.ox.x+s.hw.x-s.hh.x,s.ax.x));
assert(core<=s.cx+s.ox.x+s.hw.x-s.hh.x);assert(r.bulge[0]-core<=s.hh.x-r.bulge[2]+s.lean.x+.01);
B.pointerMoved(s,null,4);r=run(s,5,4);assert(r.bulge[2]<.02);
assert(L.light(6).warm>L.light(12).warm);assert(L.light(20).warm>L.light(12).warm);
assert(L.light(2).night>.5);assert(L.light(12).spec>L.light(2).spec);assert(L.light(6).L[0]*L.light(20).L[0]<0);
s=B.create({baseW:220,baseH:38}); r=run(s,7,0,{breathe:true});assert.equal(r.needsFrames,false,'reposo pasa a Timer');
r=B.update(s,.05,7,{...opts,music:true,beatEnvelope:1});assert(s.hw.t>=150);assert(s.glow.t>=.5);
console.log('PASS: body a–i; muelles, interrupción, dt, sueño, toques, reduce, brote, luz, reposo y música');

// Production respiration respects the explicit amplitude cap, including sleep.
s=B.create({baseW:220,baseH:38}); B.setMood(s,"dormida",0);
for(let t=0;t<20;t+=.05) { B.update(s,0,t,{...opts,breathe:true,maxBreathAmplitude:1.1}); assert(Math.abs(s.hw.t-(110-6))<=1.100001); }

// Attention starts at the pointer, and the bud never flips while the pointer rests on the body.
s=B.create({baseW:220,baseH:38}); B.setMood(s,'curiosa',0); run(s,1);
B.pointerMoved(s,{x:-60,y:2},1); B.update(s,1/240,1+1/240,opts);
assert(Math.abs(s.ax.x+60)<.5,'la atención nace en el puntero: '+s.ax.x);
let previous=null;
for(let i=2;i<=720;i++) {
    r=B.update(s,1/240,1+i/240,opts);
    if(previous) assert(Math.hypot(r.bulge[0]-previous[0],r.bulge[1]-previous[1])<1.5,'brote continuo en t='+i);
    previous=r.bulge.slice();
}
assert(Math.hypot(r.bulge[0]-s.ax.x,r.bulge[1]-s.cy-s.oy.x)<s.hh.x,'con el puntero dentro el brote queda en el núcleo');
console.log('PASS: atención sin viaje inicial y brote estable con el puntero sobre el cuerpo');

// Hover in/out over the body: the bud never pops in or out, and inside the core it stays absent.
s=B.create({baseW:110,baseH:30}); B.setMood(s,'curiosa',0); run(s,1);
let last=null, maxStep=0;
const track=(t0,seconds)=>{ for(let i=1;i<=Math.round(seconds*240);i++) {
    r=B.update(s,1/240,t0+i/240,opts);
    const size=r.bulge[2]*r.bulge[3];
    if(last!==null) maxStep=Math.max(maxStep,Math.abs(size-last));
    last=size;
} };
B.pointerMoved(s,{x:-8,y:3},1); track(1,1.5);
assert(r.bulge[3]<.01,'dentro del núcleo no hay brote: '+r.bulge[3]);
B.pointerMoved(s,{x:-62,y:-14},2.5); track(2.5,1.5);
assert(r.bulge[3]>.3,'en la esquina el brote se inclina: '+r.bulge[3]);
B.pointerMoved(s,null,4); track(4,3);
assert(r.bulge[3]===0 && r.bulge[2]===0,'el brote se absorbe por completo');
assert(maxStep<.5,'el brote crece y se absorbe sin saltos: '+maxStep);
console.log('PASS: hover sin bulto interior y absorción continua del brote');
