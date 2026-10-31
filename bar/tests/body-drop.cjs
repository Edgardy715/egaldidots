const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
function load(name,context={}) {vm.createContext(context);vm.runInContext(fs.readFileSync(`bar/body/${name}.js`,'utf8').replace(/^\.(pragma|import).*$/gm,''),context);return context}
const S=load('BodySprings'),D=load('BodyDropBrain',{Springs:S});
const g={cx:320,cy:90,baseH:38,width:640,height:360};
function fixture() {return {s:D.create(g),b:{hw:S.create(110,11,.6),hh:S.create(19,12,.55),glow:S.create(0,5,1),ox:{x:0},oy:{x:0}},t:0}}
function step(f,dt=1/240,extra={}) {f.t+=dt;return D.update(f.s,dt,f.t,{geometry:g,reduce:false,itemDragging:false,...extra},f.b)}
function run(f,seconds,extra={}) {let r;for(let i=0;i<seconds*240;i++)r=step(f,1/240,extra);return r}
let f=fixture();D.release(f.s,0,g,f.b);assert.equal(f.s.mode,'out');run(f,.35);D.callBack(f.s);run(f,3);assert.equal(f.s.mode,'home');assert(Math.abs(f.s.hr.x-11)<.1);
f=fixture();D.release(f.s,0,g,f.b);run(f,.05);const x=f.s.hx.x,y=f.s.hy.x,v=f.s.hy.v;D.callBack(f.s);assert.equal(f.s.hy.v,v);assert.equal(f.s.hy.x,y);step(f,1/60);assert(Math.hypot(f.s.hx.x-x,f.s.hy.x-y)<2);
f=fixture();f.s.mode='out';f.s.hx.v=400;D.prepare(f.s,0,{geometry:g,reduce:false},f.b);assert((f.s.tx.t-f.s.hx.x)*f.s.hx.v<0);
f=fixture();D.release(f.s,0,g,f.b);f.s.hx.x=g.cx;f.s.hy.x=g.cy+70;D.finish(f.s,0,{geometry:g,reduce:false},f.b);
for(const gap of [23,25,23,25,24,25]) {f.s.hy.x=g.cy+19+f.s.hr.x+gap;D.finish(f.s,0,{geometry:g,reduce:false},f.b)}
assert.equal(f.s.residueCount,1);run(f,1.4);assert.equal(f.s.res,false);
f=fixture();D.release(f.s,0,g,f.b);f.s.armed=true;f.s.chip={x:f.s.hx.x+23,y:f.s.hy.x};assert(!D.swallow(f.s,0,g,f.b,false));f.s.chip={x:f.s.hx.x,y:f.s.hy.x};assert(!D.swallow(f.s,0,g,f.b,true));assert(D.swallow(f.s,0,g,f.b,false));assert(f.s.stored);
f=fixture();D.release(f.s,0,g,f.b);run(f,1);D.callBack(f.s);const radius=f.s.hr.x;
for(let i=0;i<720 && f.s.mode!=='home';i++){step(f);if(f.s.mode!=='home')assert(f.s.hr.x>=radius*.9)}assert.equal(f.s.mode,'home');
f=fixture();D.release(f.s,0,g,f.b);const target=f.s.hx.t;run(f,5,{reduce:true});assert.equal(f.s.hx.t,target);assert.equal(f.s.res,false);assert(f.s.all.every(s=>s.x===s.t && s.v===0));
const positions=[30,60,144].map(hz=>{const q=fixture();D.release(q.s,0,g,q.b);for(let i=0;i<hz;i++)step(q,1/hz);return q.s.hy.x});assert(Math.max(...positions)-Math.min(...positions)<1,positions.join(','));
f=fixture();D.release(f.s,0,g,f.b);run(f,.4);D.callBack(f.s);step(f);const before=[f.s.hx.x,f.s.hy.x,f.s.hx.v,f.s.hy.v];D.release(f.s,f.t,g,f.b);assert.equal(f.s.hy.t,g.cy+110);assert.deepEqual([f.s.hx.x,f.s.hy.x,f.s.hx.v,f.s.hy.v],before);
f=fixture();f.s.stored=true;D.deliver(f.s,0,g,f.b,{x:200,y:250});let spit;for(let i=0;i<720;i++){const r=step(f);if(r.spit)spit=r.spit}assert(spit);assert(!f.s.stored);assert.equal(f.s.mode,'out');
f=fixture();D.release(f.s,0,g,f.b);for(let i=0;i<300;i++){const r=step(f);assert(Math.hypot(r.drop0[0]-r.drop1[0],r.drop0[1]-r.drop1[1])<=16.001)}
f=fixture();for(let exit=0;exit<3;exit++){const count=f.s.residueCount;D.release(f.s,f.t,g,f.b);run(f,.6);assert(f.s.residueCount-count<=1);D.callBack(f.s);run(f,3);assert.equal(f.s.mode,'home')}
console.log('PASS: gota a–i; salida/regreso, interrupción, lágrima, cuello, residuo, captura, volumen, reduce, frecuencias y entrega');
