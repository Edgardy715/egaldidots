-- Reads ~/.config/hypr/binds.user.json (written by Isla settings). Never raises:
-- a missing or invalid file simply means "no overrides".
local M = {}

local function decode(text)
    local pos = 1
    local function skip() pos = text:find("%S", pos) or #text + 1 end
    local value
    local function str()
        local out, i = {}, pos + 1
        while true do
            local c = text:sub(i, i)
            if c == "" then error("unterminated string") end
            if c == '"' then pos = i + 1; return table.concat(out) end
            if c == "\\" then
                local n = text:sub(i + 1, i + 1)
                local map = { n = "\n", t = "\t", r = "\r", b = "\b", f = "\f" }
                if n == "u" then out[#out + 1] = utf8.char(tonumber(text:sub(i + 2, i + 5), 16)); i = i + 6
                else out[#out + 1] = map[n] or n; i = i + 2 end
            else out[#out + 1] = c; i = i + 1 end
        end
    end
    function value()
        skip()
        local c = text:sub(pos, pos)
        if c == "{" then
            local t = {}; pos = pos + 1; skip()
            if text:sub(pos, pos) == "}" then pos = pos + 1; return t end
            while true do
                skip(); local k = str(); skip()
                assert(text:sub(pos, pos) == ":"); pos = pos + 1
                t[k] = value(); skip()
                local d = text:sub(pos, pos); pos = pos + 1
                if d == "}" then return t end
                assert(d == ",")
            end
        elseif c == "[" then
            local t = {}; pos = pos + 1; skip()
            if text:sub(pos, pos) == "]" then pos = pos + 1; return t end
            while true do
                t[#t + 1] = value(); skip()
                local d = text:sub(pos, pos); pos = pos + 1
                if d == "]" then return t end
                assert(d == ",")
            end
        elseif c == '"' then return str()
        else
            local lit = text:match("^[%w%.%+%-]+", pos)
            assert(lit, "bad json"); pos = pos + #lit
            if lit == "true" then return true elseif lit == "false" then return false
            elseif lit == "null" then return nil end
            return tonumber(lit)
        end
    end
    return value()
end

-- Whole document: { binds = {...}, custom = {...} }.
function M.loadAll(path)
    local ok, result = pcall(function()
        local f = assert(io.open(path, "r"))
        local text = f:read("a"); f:close()
        local data = decode(text)
        assert(type(data) == "table" and type(data.binds) == "table")
        return data
    end)
    return ok and result or {}
end

function M.load(path)
    local ok, result = pcall(function()
        local f = assert(io.open(path, "r"))
        local text = f:read("a"); f:close()
        local data = decode(text)
        assert(type(data) == "table" and type(data.binds) == "table")
        return data.binds
    end)
    return ok and result or {}
end

return M
