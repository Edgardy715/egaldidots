const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const context = {};
vm.createContext(context);
vm.runInContext(fs.readFileSync('bar/components/Calculator.js', 'utf8').replace('.pragma library', ''), context);
for (const [expression, expected] of [
    ['2+2', '4'], ['asin(0)', '0'], ['acos(1)', '0'], ['atan(0)', '0'],
    ['sin(pi/2)', '1'], ['cos(π)', '-1'], ['sqrt(9)+abs(-2)', '5'],
    ['ln(e)', '1'], ['exp(1)', '2.7182818285'], ['1e3 + .5', '1000.5'],
    ['2^3^2', '512'], ['2**3', '8'], ['2^-2', '0.25'], ['-2^2', '-4'],
    ['floor(2.9)+ceil(2.1)', '5'], ['round(2.6)', '3'], ['6÷2×3', '9'],
    ['10%3', '1'], [' SIN ( 0 ) ', '0']
]) assert.equal(context.evaluate(expression), expected, expression);
for (const expression of [
    'Qt.quit()', 'Quickshell.execDetached(1)', 'sin.constructor(1)',
    'Math.sin(0)', 'root.open', 'alert(1)', 'constructor(1)', '1//2', '1/*2*/',
    '1;2', '1,2', 'sin(0,1)', '1=2', '[1]', '0x10', 'e++', '1 2', '2pi',
    '', ' ', 'sin', 'sqrt(', '1/0', 'sqrt(-1)', '1e999', '('.repeat(513)
]) assert.equal(context.evaluate(expression), null, expression);
console.log('PASS: calculator arithmetic, inverse functions, precedence, bounds and rejection of QML/JavaScript input');
