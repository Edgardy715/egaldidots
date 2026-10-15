const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const palette = {};
vm.createContext(palette);
vm.runInContext(fs.readFileSync(__dirname + '/../Singletons/Palette.js', 'utf8').replace(/^\.pragma library\s*/, ''), palette);
const data = {version:1,generator:'matugen',mode:'dark',wallpaper:'/wall with spaces.png',colors:palette.fallback};
assert.equal(palette.parse(JSON.stringify(data)).colors.primary, palette.fallback.primary);
for (const invalid of ['{', '{}', JSON.stringify({...data,version:2}), JSON.stringify({...data,generator:'wal'}),
    JSON.stringify({...data,mode:'unknown'}), JSON.stringify({...data,colors:{...data.colors,primary:'red'}}),
    JSON.stringify({...data,colors:{...data.colors,on_surface:null}})]) assert.throws(() => palette.parse(invalid));
const lum = hex => {
    const channels = [1,3,5].map(i => parseInt(hex.slice(i,i+2),16)/255).map(v => v<=.04045?v/12.92:((v+.055)/1.055)**2.4);
    return channels[0]*.2126+channels[1]*.7152+channels[2]*.0722;
};
const contrast = (a,b) => (Math.max(lum(a),lum(b))+.05)/(Math.min(lum(a),lum(b))+.05);
for (const [fg,bg] of [['on_surface','surface'],['on_surface_variant','surface_container_high'],['on_primary','primary'],['on_primary_container','primary_container'],['on_error','error'],['on_error_container','error_container']]) {
    assert.ok(contrast(data.colors[fg],data.colors[bg])>=4.5, `${fg}/${bg}`);
}
console.log('PASS: palette schema, malformed/incomplete rejection and semantic contrast');
