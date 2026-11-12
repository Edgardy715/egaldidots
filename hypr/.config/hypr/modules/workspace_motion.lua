local M = {}

-- ScrollOverview reloads config when it registers itself. Spawn the loader
-- after compositor startup, never from inside configuration evaluation.
hl.on("hyprland.start", function()
    hl.exec_cmd(require("modules.isla").script("scrolloverview-load.sh"))
end)

if hl.plugin.scrolloverview then
    hl.config({
        plugin = {
            scrolloverview = {
                scale = 0.48,
                layout = "vertical",
                blur = false,
                cross_monitor_drag = false,
            },
        },
    })
end

function M.overview(action)
    local overview = hl.plugin.scrolloverview
    if overview and overview.overview then overview.overview(action) end
end

function M.navigate(direction)
    local overview = hl.plugin.scrolloverview
    if overview and overview.navigate then overview.navigate(direction) end
end

function M.selectClick()
    local overview = hl.plugin.scrolloverview
    if not overview then return end
    overview.overview("select")
    overview.window("select")
    overview.overview("off")
end

return M
