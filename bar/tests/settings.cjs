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
assert.equal(schema.sections.appearance.fontScale.label, 'Tamaño de texto');
assert.equal(schema.sections.appearance.reduceMotion.control, 'toggle');
assert.deepEqual(Array.from(schema.sections.appearance.reduceMotion.options), [false, true]);
assert.equal(schema.sections.paths.wallpaperDir.control, 'path');
assert.deepEqual(Array.from(schema.sections.paths.wallpaperDir.acceptedForms), ['absolute', '~', '~/relative']);
for (const [sectionName, sectionFields] of Object.entries(settings.fields)) {
    assert.ok(schema.sections[sectionName], `schema section ${sectionName}`);
    for (const [fieldName, field] of Object.entries(sectionFields)) {
        const exposed = schema.sections[sectionName][fieldName];
        assert.equal(typeof exposed.label, 'string', `${sectionName}.${fieldName} label`);
        assert.equal(typeof exposed.description, 'string', `${sectionName}.${fieldName} description`);
        assert.equal(typeof exposed.control, 'string', `${sectionName}.${fieldName} control`);
        assert.equal(typeof exposed.availability, 'string', `${sectionName}.${fieldName} availability`);
        assert.equal(exposed.default, field.path
            ? (context[field.base] + field.suffix)
            : field.default, `${sectionName}.${fieldName} default`);
        if (field.minimum !== undefined) assert.equal(exposed.minimum, field.minimum);
        if (field.maximum !== undefined) assert.equal(exposed.maximum, field.maximum);
    }
}
const catalog = settings.catalog(context);
assert.equal(catalog.version, settings.version);
assert.equal(catalog.availabilityIsLive, false);
assert.deepEqual(Array.from(catalog.sectionOrder, item => item.id), Object.keys(settings.fields));
assert.equal(catalog.requiredModules.length, 1);
assert.equal(catalog.requiredModules[0].id, 'pill');
assert.equal(catalog.requiredModules[0].configurable, false);
assert.deepEqual(Array.from(catalog.optionalModules, item => item.setting), [
    'modules.workspaceRail', 'modules.systemStatus', 'modules.apps',
    'modules.audio', 'modules.network', 'modules.battery'
]);
assert.equal(catalog.surfaces.length, 14);
assert.deepEqual(Array.from(catalog.surfaces, item => item.id).sort(),
    fs.readdirSync(__dirname + '/../surfaces').filter(file => file.endsWith('Surface.qml'))
        .map(file => file.slice(0, -11).toLowerCase()).sort(), 'catalog covers every routed surface');
assert.deepEqual(Array.from(catalog.surfaces, item => item.id), [
    'appearance', 'auth', 'calendar', 'clipboard', 'connectivity', 'launcher',
    'media', 'mixer', 'notifs', 'overview', 'session', 'utils', 'wallpaper', 'workspaces'
]);
assert.ok(catalog.surfaces.every(surface => surface.availability === 'routed'
    && Array.isArray(surface.dependsOn) && Array.isArray(surface.optionalDependsOn)));
const capabilityIds = new Set(catalog.capabilities.map(capability => capability.id));
const moduleSettingIds = new Set(catalog.optionalModules.map(module => module.setting));
for (const module of catalog.requiredModules) {
    for (const dependency of module.dependsOn) assert.ok(capabilityIds.has(dependency), `required module dependency ${dependency}`);
}
for (const module of catalog.optionalModules) {
    assert.ok(settings.fields.modules[module.id], `module setting ${module.id}`);
    assert.equal(module.setting, `modules.${module.id}`);
    for (const dependency of module.dependsOn) {
        assert.ok(capabilityIds.has(dependency) || moduleSettingIds.has(dependency), `module dependency ${dependency}`);
    }
    for (const dependency of module.visibleWhen || []) assert.ok(moduleSettingIds.has(dependency), `visibleWhen ${dependency}`);
    if (module.parentModule) assert.ok(catalog.optionalModules.some(parent => parent.id === module.parentModule), `parent module ${module.parentModule}`);
}
for (const surface of catalog.surfaces) {
    for (const dependency of [...surface.dependsOn, ...surface.optionalDependsOn]) {
        assert.ok(capabilityIds.has(dependency), `surface ${surface.id} dependency ${dependency}`);
    }
}
assert.ok(catalog.capabilities.some(capability => capability.id === 'upower.laptopBattery'
    && capability.availability === 'runtime-conditional'));
assert.equal(catalog.sections.appearance.pillBlur.availability, 'inactive');
assert.equal(catalog.sections.appearance.showGlyphs.availability, 'inactive');
assert.equal(catalog.sections.appearance.clockSeconds.availability, 'partial');
assert.ok(catalog.optionalModules.find(item => item.id === 'battery').dependsOn.includes('upower.laptopBattery'));
assert.equal(validate({}).effective.paths.userAvatar, '/home/test/.face');
assert.equal(validate({ profile: { displayName: 'Nombre' } }).effective.profile.displayName, 'Nombre');
assert.equal(validate({ profile: { displayName: 123 } }).ok, false);
assert.equal(validate({ paths: { userAvatar: 'relative.png' } }).ok, false);
for (const key of Object.keys(settings.fields.modules)) {
    assert.equal(validate({}).effective.modules[key], true);
    assert.equal(validate({ modules: { [key]: false } }).effective.modules[key], false);
    assert.equal(validate({ modules: { [key]: 'false' } }).ok, false);
}
assert.equal(validate(settings.merge({ modules: { audio: false } }, { modules: { network: false } })).effective.modules.audio, false);
console.log('PASS: settings defaults, legacy format, validation, paths, patch isolation, extension preservation');
