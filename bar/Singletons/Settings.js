.pragma library

// The settings contract is independent of QML services and filesystem access.
// Keep defaults, editor metadata and validation together so clients can discover
// the same rules that the running shell applies.
var version = 1
var fields = {
    appearance: {
        glassAlpha: { type: "number", default: 0.34, minimum: 0.15, maximum: 1 },
        pillBlur: { type: "boolean", default: false },
        topGap: { type: "number", default: 1, minimum: 0 },
        appGap: { type: "number", default: 1, minimum: 0 },
        uiScale: { type: "number", default: 1, minimum: 0.25 },
        fontScale: { type: "number", default: 1, minimum: 0.75, maximum: 1.75 },
        spacingScale: { type: "number", default: 1, minimum: 0.75, maximum: 1.5 },
        radiusScale: { type: "number", default: 1, minimum: 0.75, maximum: 1.5 },
        motionScale: { type: "number", default: 1, minimum: 0.25, maximum: 2 },
        fontFamily: { type: "string", default: "Google Sans Flex", minLength: 1 },
        fontMonoFamily: { type: "string", default: "JetBrainsMono Nerd Font", minLength: 1 },
        fontDisplayFamily: { type: "string", default: "Rubik", minLength: 1 },
        fontMediaFamily: { type: "string", default: "Inter", minLength: 1 },
        reduceMotion: { type: "boolean", default: false },
        time12h: { type: "boolean", default: true },
        clockSeconds: { type: "boolean", default: false },
        showGlyphs: { type: "boolean", default: true }
    },
    profile: {
        displayName: { type: "string", default: "", minLength: 0 }
    },
    paths: {
        userAvatar: { type: "string", path: true, base: "home", suffix: "/.face" },
        walColorsFile: { type: "string", path: true, base: "cacheHome", suffix: "/wal/colors.json" },
        wallpaperDir: { type: "string", path: true, base: "home", suffix: "/Wallpapers" },
        wallpaperCacheDir: { type: "string", path: true, base: "cacheHome", suffix: "/quickshell/wallpapers" },
        wallpaperApplyScript: { type: "string", path: true, base: "configHome", suffix: "/hypr/scripts/apply-wallpaper.sh" }
    }
}

function isObject(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value)
}

function copy(value) { return JSON.parse(JSON.stringify(value)) }

function schema(context) {
    var result = { version: version, sections: copy(fields) }
    Object.keys(result.sections.paths).forEach(function(key) {
        var field = result.sections.paths[key]
        field.default = context[field.base] + field.suffix
        delete field.base
        delete field.suffix
    })
    return result
}

function defaults(context) {
    var result = { version: version }
    var sections = schema(context).sections
    Object.keys(sections).forEach(function(section) {
        result[section] = {}
        Object.keys(sections[section]).forEach(function(key) {
            result[section][key] = sections[section][key].default
        })
    })
    return result
}

// Unknown keys survive round trips. Known invalid values reject the complete
// document rather than partially applying changes to the live scene.
function validate(document, context) {
    var errors = []
    var effective = defaults(context)
    if (!isObject(document)) return { ok: false, errors: ["Settings must be an object"] }
    if (document.version !== undefined && document.version !== version)
        errors.push("Unsupported settings version: " + document.version)
    Object.keys(fields).forEach(function(section) {
        if (document[section] === undefined) return
        if (!isObject(document[section])) {
            errors.push(section + " must be an object")
            return
        }
        Object.keys(fields[section]).forEach(function(key) {
            var value = document[section][key]
            if (value === undefined) return
            var rule = fields[section][key]
            var name = section + "." + key
            if (typeof value !== rule.type || (rule.type === "number" && !isFinite(value))) {
                errors.push(name + " must be " + rule.type)
                return
            }
            if ((rule.minimum !== undefined && value < rule.minimum)
                || (rule.maximum !== undefined && value > rule.maximum)) {
                errors.push(name + " is outside its allowed range")
                return
            }
            if (rule.type === "string" && ((value.trim().length < (rule.minLength === undefined ? 1 : rule.minLength)) || value.indexOf("\u0000") !== -1)) {
                errors.push(name + " has an invalid length or contains NUL")
                return
            }
            if (rule.path) {
                value = value === "~" ? context.home
                    : value.indexOf("~/") === 0 ? context.home + value.slice(1) : value
                if (value.charAt(0) !== "/") {
                    errors.push(name + " must be an absolute path or start with ~/")
                    return
                }
            }
            effective[section][key] = value
        })
    })
    return { ok: errors.length === 0, errors: errors, effective: effective }
}

// A patch merges one section at a time; it never replaces another section or
// silently drops extensions written by another tool.
function merge(document, patch) {
    if (!isObject(patch)) throw new Error("Patch must be an object")
    var result = copy(document)
    Object.keys(patch).forEach(function(key) {
        if (key === "__proto__" || key === "constructor" || key === "prototype")
            throw new Error("Reserved settings key")
        if (isObject(patch[key]) && isObject(result[key])) {
            Object.keys(patch[key]).forEach(function(name) {
                if (name === "__proto__" || name === "constructor" || name === "prototype")
                    throw new Error("Reserved settings key")
                result[key][name] = copy(patch[key][name])
            })
        } else result[key] = copy(patch[key])
    })
    result.version = patch.version === undefined ? version : patch.version
    return result
}
