-- lua ~/.config/hypr/tests/monitors.lua
local base = os.getenv("HOME") .. "/.config/hypr/modules/"
local realPopen, realOpen = io.popen, io.open
local names = { "card0", "card0-DP-3", "card1", "card1-eDP-2" }
io.popen = function()
    return { lines = function() local i = 0; return function() i = i + 1; return names[i] end end, close = function() end }
end
io.open = function(path, mode)
    if path:match("/sys/class/drm/") then
        return { read = function() return "connected" end, close = function() end }
    end
    return realOpen(path, mode)
end
local events, rules, env = {}, {}, {}
local monitors = { { name = "DP-3" } }
hl = {
    monitor = function(rule) rules[#rules + 1] = rule end,
    on = function(event, callback) events[event] = callback end,
    get_monitors = function() return monitors end,
    env = function(key, value) env[key] = value end,
}
dofile(base .. "monitors.lua")
assert(rules[1].output == "" and rules[1].mode == "highrr")
events["hyprland.start"]()
assert(rules[#rules].output == "eDP-2" and rules[#rules].disabled == true)
local count = #rules
events["monitor.added"]()
assert(#rules == count, "same topology must not reapply rules")
monitors = {}
events["monitor.removed"]()
assert(rules[#rules].output == "eDP-2" and rules[#rules].disabled == false)
monitors = { { name = "eDP-2" }, { name = "HDMI-A-2" } }
events["monitor.added"]()
assert(rules[#rules].disabled == true, "any external disables internal")
dofile(base .. "envVars.lua")
assert(env.AQ_DRM_DEVICES == "/dev/dri/card0:/dev/dri/card1", "external GPU first, both retained")
names = { "card4", "card4-eDP-3", "card7", "card7-DP-8" }
dofile(base .. "envVars.lua")
assert(env.AQ_DRM_DEVICES == "/dev/dri/card7:/dev/dri/card4", "GPU numbering may change")
io.popen, io.open = realPopen, realOpen
print("PASS: hotplug, laptop fallback, unchanged topology and dynamic GPU order")
