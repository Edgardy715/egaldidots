const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const apps = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../pets/PetApps.js'), 'utf8').replace(/^\.pragma library\s*/, ''), apps);
for (const id of ['kitty', 'foot', 'Alacritty', 'org.wezfurlong.wezterm', 'com.mitchellh.ghostty',
    'code', 'code-oss', 'codium', 'dev.zed.Zed', 'neovide', 'jetbrains-idea', 'JETBRAINS-PYCHARM']) {
    assert.equal(apps.isCoding(id), true, id);
    assert.equal(apps.isCoding(id.toUpperCase()), true, id.toUpperCase());
}
for (const id of ['', null, undefined, 'Chatgpt', 'firefox', 'decode', 'kitty-other', 'myjetbrains-idea'])
    assert.equal(apps.isCoding(id), false, String(id));
console.log('PASS: exact case-insensitive coding app IDs and JetBrains prefix');
