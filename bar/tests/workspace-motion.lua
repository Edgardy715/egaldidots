local startup
local commands = {}
local pluginCalls = {}
local config
hl = {
    plugin = {},
    on = function(event, callback)
        assert(event == "hyprland.start")
        startup = callback
    end,
    exec_cmd = function(command)
        commands[#commands + 1] = command
    end,
    config = function(value) config = value end,
}

local motion = dofile(os.getenv("HOME") .. "/.config/hypr/modules/workspace_motion.lua")
assert(startup, "loader must be registered for compositor startup")
assert(#commands == 0, "config parse must not load a plugin")
assert(config == nil, "plugin options require a loaded plugin")

motion.overview("off")
motion.navigate("left")
motion.selectClick()
assert(#commands == 0, "missing plugin must leave IPC routing to the bind script")
startup()
assert(commands[1] == "/home/zdito/.config/quickshell/scripts/scrolloverview-load.sh")

hl.plugin.scrolloverview = {
    overview = function(action) pluginCalls[#pluginCalls + 1] = "overview:" .. action end,
    navigate = function(direction) pluginCalls[#pluginCalls + 1] = "navigate:" .. direction end,
    window = function(action) pluginCalls[#pluginCalls + 1] = "window:" .. action end,
}
commands = {}
config = nil
motion = dofile(os.getenv("HOME") .. "/.config/hypr/modules/workspace_motion.lua")
assert(#commands == 0, "plugin config reload must not load a plugin")
assert(config.plugin.scrolloverview.scale == 0.48)
assert(config.plugin.scrolloverview.layout == "vertical")
assert(config.plugin.scrolloverview.blur == false)
motion.overview("off")
motion.navigate("left")
motion.selectClick()
assert(table.concat(pluginCalls, ",") == "overview:off,navigate:left,overview:select,window:select,overview:off")
assert(#commands == 0, "loaded plugin must not spawn a command")
print("PASS: startup-only loader and stock manual navigation/selection")
