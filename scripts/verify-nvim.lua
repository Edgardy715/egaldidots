-- Validate installed plugin checkouts against the shipped lockfile, without
-- starting Neovim's UI or downloading anything.
local config = vim.fn.stdpath("config")
local lock = vim.json.decode(table.concat(vim.fn.readfile(config .. "/lazy-lock.json"), "\n"))
local root = vim.fn.stdpath("data") .. "/lazy/"
for name, spec in pairs(lock) do
  local directory = root .. name
  if vim.fn.isdirectory(directory) ~= 1 then
    io.stderr:write("Missing Neovim plugin: " .. name .. "\n")
    vim.cmd("cquit 1")
  end
  local actual = vim.fn.system({ "git", "-C", directory, "rev-parse", "HEAD" }):gsub("%s+$", "")
  if vim.v.shell_error ~= 0 or actual ~= spec.commit then
    io.stderr:write("Neovim plugin differs from lazy-lock.json: " .. name .. "\n")
    vim.cmd("cquit 1")
  end
end
print("Neovim plugin lock verified")
