-- focusbm.lua - Hammerspoon integration for focusbm
-- Usage: local focusbm = require("focusbm")

local M = {}

-- Path to focusbm binary
M.binPath = "/usr/local/bin/focusbm"

-- Alternative paths for Apple Silicon
local altPaths = {
    "/opt/homebrew/bin/focusbm",
    "/usr/local/bin/focusbm",
}

-- Find the binary
local function findBinary()
    for _, path in ipairs(altPaths) do
        if hs.fs.attributes(path) then
            return path
        end
    end
    return M.binPath
end

-- Run focusbm command
local function run(args)
    local bin = findBinary()
    local cmd = bin .. " " .. args
    local output, status = hs.execute(cmd)
    return output, status
end

-- Parse fzf output
local function parseBookmarks()
    local raw = run("list --format=fzf")
    if not raw or raw == "" then return {} end
    local items = {}
    for line in raw:gmatch("[^\n]+") do
        local id, label = line:match("^([^\t]+)\t(.+)$")
        if id then
            table.insert(items, { text = id, subText = label, id = id })
        end
    end
    return items
end

-- Restore a bookmark by ID
function M.restore(id)
    local _, status = run('restore "' .. id .. '"')
    if status then
        hs.notify.new({ title = "focusbm", informativeText = "Restored: " .. id }):send()
    else
        hs.notify.new({ title = "focusbm", informativeText = "Failed to restore: " .. id }):send()
    end
end

-- Open chooser with all bookmarks
function M.chooser()
    local choices = parseBookmarks()
    if #choices == 0 then
        hs.alert.show("focusbm: no bookmarks found")
        return
    end

    local chooser = hs.chooser.new(function(choice)
        if choice then
            M.restore(choice.id)
        end
    end)
    chooser:choices(choices)
    chooser:show()
end

-- Bind hotkey to restore specific bookmark
function M.bindHotkey(mods, key, bookmarkId)
    hs.hotkey.bind(mods, key, function()
        M.restore(bookmarkId)
    end)
end

-- Bind hotkey to open chooser
function M.bindChooser(mods, key)
    hs.hotkey.bind(mods, key, function()
        M.chooser()
    end)
end

return M
