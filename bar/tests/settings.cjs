const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const settings = {};
vm.createContext(settings);
vm.runInContext(fs.readFileSync(__dirname + '/../Singletons/Settings.js', 'utf8').replace(/^\.pragma library\s*/, ''), settings);
const context = { home: '/home/test', configHome: '/config', cacheHome: '/cache' };
const validate = doc => settings.validate(doc, context);
assert.equal(validate({}).effective.appearance.glassAlpha, 0.34);
assert.equal(validate({}).effective.paths.walColorsFile, '/cache/wal/colors.json');
assert.equal(validate({ paths: { wallpaperDir: '~/Pictures' } }).effective.paths.wallpaperDir, '/home/test/Pictures');
assert.equal(validate(JSON.parse(fs.readFileSync(__dirname + '/../shell.json.example'))).ok, true);
for (const doc of [null, [], 'text', { version: 2 }, { appearance: [] }, { appearance: null },
    { appearance: { glassAlpha: -1 } }, { appearance: { motionScale: 100 } },
    { appearance: { fontScale: NaN } }, { appearance: { uiScale: Infinity } },
    { appearance: { reduceMotion: 'true' } }, { appearance: { fontFamily: '' } },
    { paths: { wallpaperDir: 'relative' } }, { paths: { wallpaperDir: '/bad\0path' } }]) {
    assert.equal(validate(doc).ok, false, JSON.stringify(doc));
}
const original = { appearance: { time12h: false, extension: 42 }, extra: { keep: true } };
const next = settings.merge(original, { appearance: { fontScale: 1.2 } });
assert.equal(next.appearance.time12h, false);
assert.equal(next.appearance.extension, 42);
assert.equal(next.extra.keep, true);
assert.equal(next.version, 1);
assert.equal(original.appearance.fontScale, undefined);
assert.equal(validate(next).ok, true);
assert.throws(() => settings.merge(original, JSON.parse('{"__proto__":{"polluted":true}}')));
assert.throws(() => settings.merge(original, { appearance: JSON.parse('{"__proto__":{}}') }));
const schema = settings.schema(context);
assert.equal(schema.sections.appearance.fontScale.minimum, 0.75);
assert.equal(schema.sections.paths.wallpaperDir.default, '/home/test/Wallpapers');
console.log('PASS: settings defaults, legacy format, validation, paths, patch isolation, extension preservation');
