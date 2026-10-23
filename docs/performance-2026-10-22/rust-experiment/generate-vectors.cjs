const fs = require('node:fs');
const vm = require('node:vm');
const context = vm.createContext({});
vm.runInContext(fs.readFileSync(__dirname + '/Spectrum.js', 'utf8'), context);
const lines = ['', '0', '  0  ', 'NaN', 'Infinity', '-1', '65536', '0xff', '0b11', '0o17', '+2.5', '1e3', '1e-3', 'bad', '1 2', '\ufeff1\u00a02', '1\u00852', '0 '.repeat(24), Array.from({length:24}, (_,i)=>i*2800).join(' '), ['1','10','100','1000','10000','65535'].join(' '), '0\t65535\n0'];
let seed = 17;
const random = () => ((seed = (Math.imul(seed,1664525)+1013904223)>>>0)/2**32);
for(let j=0;j<60;j++) lines.push(Array.from({length:24},()=>Math.floor(random()*65536)).join(' '));
const parse = lines.map(line=>({line, count: line.trim() === '' ? 1 : line.trim().split(/\s+/).length, expected:context.parse(line,line.trim() === '' ? 1 : line.trim().split(/\s+/).length)}));
parse.push({line:'1 2', count:24, expected:null});
const advance = [];
let current = Array(24).fill(0);
for(let i=0;i<600;i++) {
  const target = i < 90 || i >= 180 && i < 300 ? parse[parse.length-61+i%60].expected : [];
  const dt = i%71 === 0 ? -.05 : i%31 === 0 ? .05 : 1/60;
  const expected = context.advance(current,target,dt);
  advance.push({current, target, dt, expected});
  current = expected;
}
fs.writeFileSync(__dirname+'/vectors.json',JSON.stringify({parse,advance},null,2)+'\n');
console.log(`${parse.length} parse + ${advance.length} advance vectors`);
