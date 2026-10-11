.pragma library

function isChild(key) {
    return ["apps", "audio", "network", "battery"].indexOf(key) !== -1
}

function selected(modules, key) {
    return !!modules[key] && (!isChild(key) || !!modules.systemStatus)
}

function patch(key, value) {
    const modules = { [key]: value }
    if (isChild(key) && value) modules.systemStatus = true
    return { modules: modules }
}
