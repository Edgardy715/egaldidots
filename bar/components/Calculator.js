.pragma library

function evaluate(input) {
    if (typeof input !== "string" || input.length > 512) return null;
    var source = input.trim();
    var tokens = [];
    var lexer = /\s*(?:(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?|[a-z]+|π|\*\*|[+\-*/%^×÷(),])/gi;
    var offset = 0;
    var match;
    while ((match = lexer.exec(source)) !== null) {
        if (match.index !== offset) return null;
        tokens.push(match[0].trim().toLowerCase());
        offset = lexer.lastIndex;
    }
    if (offset !== source.length || tokens.length === 0) return null;
    var functions = {
        sqrt: Math.sqrt, sin: Math.sin, cos: Math.cos, tan: Math.tan,
        asin: Math.asin, acos: Math.acos, atan: Math.atan,
        log: Math.log, ln: Math.log, exp: Math.exp, abs: Math.abs,
        floor: Math.floor, ceil: Math.ceil, round: Math.round
    };
    var index = 0;
    function primary() {
        var token = tokens[index++];
        if (token === "(") {
            var grouped = sum();
            if (tokens[index++] !== ")") throw new Error("Missing closing parenthesis");
            return grouped;
        }
        if (token === "pi" || token === "π") return Math.PI;
        if (token === "e") return Math.E;
        if (Object.prototype.hasOwnProperty.call(functions, token)) {
            if (tokens[index++] !== "(") throw new Error("Missing function argument");
            var argument = sum();
            if (tokens[index++] !== ")") throw new Error("Missing closing parenthesis");
            return functions[token](argument);
        }
        if (token === undefined || !/^(?:\d|\.)/.test(token)) throw new Error("Invalid value");
        return Number(token);
    }
    function power() {
        var value = primary();
        if (tokens[index] === "^" || tokens[index] === "**") {
            index++;
            value = Math.pow(value, unary());
        }
        return value;
    }
    function unary() {
        if (tokens[index] === "+") { index++; return unary(); }
        if (tokens[index] === "-") { index++; return -unary(); }
        return power();
    }
    function product() {
        var value = unary();
        while (["*", "/", "%", "×", "÷"].indexOf(tokens[index]) !== -1) {
            var operator = tokens[index++];
            var right = unary();
            if (operator === "*" || operator === "×") value *= right;
            else if (operator === "%") value %= right;
            else value /= right;
        }
        return value;
    }
    function sum() {
        var value = product();
        while (tokens[index] === "+" || tokens[index] === "-") {
            var operator = tokens[index++];
            var right = product();
            value = operator === "+" ? value + right : value - right;
        }
        return value;
    }
    try {
        var result = sum();
        if (index !== tokens.length || !isFinite(result)) return null;
        return Number.isInteger(result) ? String(result) : Number(result.toFixed(10)).toString();
    } catch (error) {
        return null;
    }
}
