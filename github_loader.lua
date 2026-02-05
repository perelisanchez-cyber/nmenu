--[[
    ============================================================================
    nigMenu - GitHub Loader
    ============================================================================
    
    One-liner to run the entire menu from GitHub:
    
    loadstring(game:HttpGet("https://raw.githubusercontent.com/perelisanchez-cyber/nmenu/main/github_loader.lua"))()
    
    Repo structure (flat — all .lua files at the root):
      nmenu/
        github_loader.lua
        config.lua
        utils.lua
        settings.lua
        ui.lua
        console.lua
        raids.lua
        bosses.lua
        ...
]]

local REPO_BASE = "https://raw.githubusercontent.com/perelisanchez-cyber/nmenu/main/"

-- ============================================================================
-- SINGLE INSTANCE CHECK
-- ============================================================================

if _G.nigMenu then
    print("[nigMenu] Previous instance detected, cleaning up...")

    if _G.nigMenu.Config and _G.nigMenu.Config.State then
        _G.nigMenu.Config.State.running = false
    end

    pcall(function()
        if _G.nigMenu.Config and _G.nigMenu.Config.UI and _G.nigMenu.Config.UI.ScreenGui then
            _G.nigMenu.Config.UI.ScreenGui:Destroy()
        end
    end)

    pcall(function()
        local CoreGui = game:GetService("CoreGui")
        local existing = CoreGui:FindFirstChild("nigMenu")
        if existing then existing:Destroy() end
        local consoleGui = CoreGui:FindFirstChild("nigMenuConsole")
        if consoleGui then consoleGui:Destroy() end
    end)

    _G.nigMenu = nil
    task.wait(0.5)
    print("[nigMenu] Old instance terminated")
end

-- ============================================================================
-- GITHUB FETCH + EXECUTE
-- ============================================================================

local function fetch(filename)
    local url = REPO_BASE .. filename
    local ok, source = pcall(game.HttpGet, game, url)

    -- Fallback for executors that don't support game:HttpGet
    if not ok or not source or source == "" or source:find("404: Not Found") then
        local requestFn = request or http_request or (syn and syn.request)
        if requestFn then
            ok, source = pcall(function()
                local r = requestFn({ Url = url, Method = "GET" })
                return r and r.StatusCode == 200 and r.Body or nil
            end)
        end
    end

    if not ok or not source or source == "" then
        warn("[nigMenu] ✗ Failed to fetch: " .. filename)
        return nil
    end

    local fn, err = loadstring(source)
    if not fn then
        warn("[nigMenu] ✗ Syntax error in " .. filename .. ": " .. tostring(err))
        return nil
    end

    local success, result = pcall(fn)
    if not success then
        warn("[nigMenu] ✗ Runtime error in " .. filename .. ": " .. tostring(result))
        return nil
    end

    return result
end

-- ============================================================================
-- BOOT
-- ============================================================================

print("[nigMenu] ============================================")
print("[nigMenu] Loading from GitHub...")
print("[nigMenu] ============================================")

task.wait(3)

_G.nigMenu = {}
local NM = _G.nigMenu

-- ============================================================================
-- CORE MODULES (all at repo root)
-- ============================================================================

NM.Config = fetch("config.lua")
if not NM.Config then error("[nigMenu] Config failed — check repo is public and file exists") end
print("[nigMenu] ✓ Config")

NM.Utils = fetch("utils.lua")
if not NM.Utils then error("[nigMenu] Utils failed") end
print("[nigMenu] ✓ Utils")

NM.Settings = fetch("settings.lua")
print("[nigMenu] " .. (NM.Settings and "✓" or "⚠") .. " Settings")

NM.UI = fetch("ui.lua")
if not NM.UI then error("[nigMenu] UI failed") end
print("[nigMenu] ✓ UI")

-- ============================================================================
-- FEATURE MODULES (all at repo root)
-- ============================================================================

NM.Features = {}

for _, name in ipairs({
    "console", "raids", "autoroll", "generals", "swords",
    "splitter", "accessories", "merger", "utilities", "autobuy", "bosses"
}) do
    local m = fetch(name .. ".lua")
    if m then
        NM.Features[name] = m
        print("[nigMenu] ✓ " .. name)
    else
        print("[nigMenu] ⚠ " .. name .. " (skipped)")
    end
end

-- ============================================================================
-- TAB MODULES (all at repo root)
-- ============================================================================

NM.Tabs = {}

for _, t in ipairs({
    { f = "auto_tab.lua",     n = "Auto" },
    { f = "upgrades_tab.lua", n = "Upgrades" },
    { f = "items_tab.lua",    n = "Items" },
    { f = "merger_tab.lua",   n = "Merger" },
    { f = "bosses_tab.lua",   n = "Bosses" },
    { f = "server_tab.lua",   n = "ServerHopper" },
    { f = "utils_tab.lua",    n = "Utils" },
    { f = "config_tab.lua",   n = "Config" },
}) do
    local m = fetch(t.f)
    if m then
        NM.Tabs[t.n] = m
        print("[nigMenu] ✓ " .. t.n .. " tab")
    else
        print("[nigMenu] ⚠ " .. t.n .. " tab (skipped)")
    end
end

-- ============================================================================
-- INITIALIZE
-- ============================================================================

if NM.Settings and NM.Settings.load then pcall(NM.Settings.load) end

if NM.UI and NM.UI.createMainWindow then
    local ok, err = pcall(NM.UI.createMainWindow)
    if not ok then warn("[nigMenu] UI error: " .. tostring(err)) end
end

for _, tab in pairs(NM.Tabs) do
    if tab.init then pcall(tab.init) end
end

for _, feat in pairs(NM.Features) do
    if feat.startLoops then pcall(feat.startLoops) end
end

if NM.Features.bosses and NM.Features.bosses.checkAutoStart then
    pcall(NM.Features.bosses.checkAutoStart)
end

print("[nigMenu] ============================================")
print("[nigMenu] nigMenu LOADED (GitHub)")
print("[nigMenu] Toggle: " .. (NM.Config.State.menuKeybind and NM.Config.State.menuKeybind.Name or "RightControl"))
print("[nigMenu] ============================================")
