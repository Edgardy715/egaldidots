const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const file = vm.createContext({});
vm.runInContext(fs.readFileSync('bar/body/BodyFile.js', 'utf8').replace(/^\.pragma.*$/gm, ''), file);
for (const path of ['/tmp/movie.mp4', '/tmp/a b # % " $(touch nope).mp4', '/tmp/áé.mp4']) {
    assert.equal(file.localPath(path), path);
    assert.deepEqual(Array.from(file.openArguments(path)), ['xdg-open', path]);
}
assert.equal(file.localPath('file:///tmp/a%20b%23%25.mp4'), '/tmp/a b#%.mp4');
assert.equal(file.localPath('file://localhost/tmp/a.mp4'), '/tmp/a.mp4');
for (const path of ['', null, 2, 'relative.mp4', 'https://host/a', 'file://remote/tmp/a',
    'file:/tmp/a', 'file:///tmp/%zz', 'file:///tmp/a?query', 'file:///tmp/a#fragment',
    '/tmp/a\0b', '/tmp/a\nb', '//remote/tmp/a', '/', '/tmp/', '/tmp/../secret',
    'file:///tmp/%2e%2e/secret', '/tmp/./a']) assert.equal(file.localPath(path), '', String(path));
assert.equal(file.name('/tmp/a b.mp4'), 'a b.mp4');
console.log('PASS: local file paths, URL decoding, remote/control/traversal rejection, literal argv');
