const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const context = {};
vm.createContext(context);
vm.runInContext(fs.readFileSync('bar/components/LyricsData.js', 'utf8').replace('.pragma library', ''), context);
const synced = context.decode({syncedLyrics:'[ar:QA]\n[00:02.50][00:05.000]Primera línea\n[00:09]\n[00:61]Inválida'});
assert.equal(synced.status, 'ready');
assert.equal(synced.lines.length, 3);
assert.equal(synced.lines[0].time, 2.5);
assert.equal(synced.lines[1].time, 5);
assert.equal(synced.lines[2].text, '♪');
assert.equal(context.indexAt(synced.lines, 0), -1);
assert.equal(context.indexAt(synced.lines, 2.5), 0);
assert.equal(context.indexAt(synced.lines, 6), 1);
assert.equal(context.indexAt(synced.lines, 20), 2);
assert.equal(context.indexAt(synced.lines, NaN), -1);
const plain = context.decode({plainLyrics:'Texto de prueba\nSegunda línea'});
assert.equal(plain.synced, false);
assert.equal(context.indexAt(plain.lines, 5), -1);
assert.equal(context.decode({instrumental:true}).status, 'instrumental');
assert.equal(context.decode({}).status, 'empty');
assert.throws(() => context.decode(null));
assert.throws(() => context.decode({syncedLyrics:'x'.repeat(100001)}));
assert.throws(() => context.decode({plainLyrics:'x\n'.repeat(2001)}));
const candidates = [
    {trackName:'HOY AQUÍ (Live)', artistName:'Rauw Alejandro', duration:188, albumName:'PLAYA SATURNO'},
    {trackName:'HOY AQUÍ', artistName:'Otro artista', duration:188, albumName:'PLAYA SATURNO'},
    {trackName:'HOY AQUÍ', artistName:'Rauw Alejandro', duration:220, albumName:'PLAYA SATURNO'},
    {trackName:'HOY AQUI', artistName:'Rauw Alejandro', duration:189, albumName:'PLAYA SATURNO', syncedLyrics:'[00:01]Sí'}
];
assert.equal(context.bestMatch(candidates, 'HOY AQUÍ', 'Rauw Alejandro', 'PLAYA SATURNO', 188).duration, 189);
assert.equal(context.bestMatch(candidates.slice(0, 3), 'HOY AQUÍ', 'Rauw Alejandro', 'PLAYA SATURNO', 188), null);
assert.equal(context.bestMatch([
    {trackName:'HOY AQUÍ', artistName:'Rauw Alejandro', duration:188, albumName:'PLAYA SATURNO', instrumental:true},
    {trackName:'HOY AQUÍ', artistName:'Rauw Alejandro', duration:189, albumName:'Otro álbum', syncedLyrics:'[00:01]Sí'}
], 'HOY AQUÍ', 'Rauw Alejandro', 'PLAYA SATURNO', 188).duration, 189);
assert.throws(() => context.bestMatch({}, 'a', 'b', '', 0));
console.log('PASS: lyrics timestamps, multiple tags, blank/invalid lines, seek/backtrack, plain, instrumental and bounds');
