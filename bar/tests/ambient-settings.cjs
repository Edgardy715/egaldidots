const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const settings = {};
vm.createContext(settings);
vm.runInContext(fs.readFileSync(__dirname + '/../Singletons/Settings.js', 'utf8').replace(/^\.pragma library\s*/, ''), settings);
const validate = doc => settings.validate(doc, {home:'/tmp', configHome:'/tmp', cacheHome:'/tmp'});
assert.equal(validate({}).effective.appearance.ambientFps, 60);
for (const ambientFps of [30, 60, 120, 240])
    assert.equal(validate({appearance:{ambientFps}}).effective.appearance.ambientFps, ambientFps);
for (const ambientFps of [29, 241, NaN, Infinity, '60', null])
    assert.equal(validate({appearance:{ambientFps}}).ok, false);
console.log('PASS: frecuencia ambiental validada y default 60 Hz');
