--[[
    ============================================================================
    nigMenu - GitHub Loader
    ============================================================================
    
    One-liner to run the entire menu from GitHub:
    
    loadstring(game:HttpGet("https://raw.githubusercontent.com/perelisanchez-cyber/nmenu/main/github_loader.lua"))()
    
    Repo structure:
      nmenu/                    (repo root)
        github_loader.lua       (this file)
        nigMenu/
          core/config.lua, utils.lua, settings.lua, ui.lua
          features/console.lua, bosses.lua, raids.lua, ...
          tabs/auto_tab.lua, bosses_tab.lua, ...
]]

local RAW_BASE = "https://raw.githubusercontent.com/perelisanchez-cyber/nmenu/claude/github-integration-exploration-DKPUS/nigMenu/"

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

local function fetch(path)
    local url = RAW_BASE .. path .. "?cb=" .. tostring(tick())
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
        warn("[nigMenu] ✗ Failed to fetch: " .. path)
        warn("[nigMenu]   URL: " .. url)
        return nil
    end

    local fn, err = loadstring(source)
    if not fn then
        warn("[nigMenu] ✗ Syntax error in " .. path .. ": " .. tostring(err))
        return nil
    end

    local success, result = pcall(fn)
    if not success then
        warn("[nigMenu] ✗ Runtime error in " .. path .. ": " .. tostring(result))
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

-- Quick game-ready check (no fixed delay)
if not game:IsLoaded() then
    game.Loaded:Wait()
end

_G.nigMenu = {}
local NM = _G.nigMenu

-- ============================================================================
-- CORE (nigMenu/core/)
-- ============================================================================

NM.Config = fetch("core/config.lua")
if not NM.Config then error("[nigMenu] Config failed — check repo is public and file exists at nigMenu/core/config.lua") end
print("[nigMenu] ✓ Config")

NM.Utils = fetch("core/utils.lua")
if not NM.Utils then error("[nigMenu] Utils failed") end
print("[nigMenu] ✓ Utils")

NM.Settings = fetch("core/settings.lua")
print("[nigMenu] " .. (NM.Settings and "✓" or "⚠") .. " Settings")

NM.UI = fetch("core/ui.lua")
if not NM.UI then error("[nigMenu] UI failed") end
print("[nigMenu] ✓ UI")

-- ============================================================================
-- FEATURES (nigMenu/features/) - PARALLEL LOADING
-- ============================================================================

NM.Features = {}

local featureNames = {
    "console", "raids", "autoroll", "generals", "swords",
    "splitter", "accessories", "merger", "utilities", "autobuy", "bosses"
}

local featuresPending = #featureNames
local featuresLoaded = {}

print("[nigMenu] Loading " .. #featureNames .. " features in parallel...")

for _, name in ipairs(featureNames) do
    task.spawn(function()
        local m = fetch("features/" .. name .. ".lua")
        if m then
            NM.Features[name] = m
            featuresLoaded[name] = true
        end
        featuresPending = featuresPending - 1
    end)
end

-- Wait for all features to complete
while featuresPending > 0 do
    task.wait(0.05)
end

-- Print results
for _, name in ipairs(featureNames) do
    if featuresLoaded[name] then
        print("[nigMenu] ✓ " .. name)
    else
        print("[nigMenu] ⚠ " .. name .. " (skipped)")
    end
end

-- ============================================================================
-- TABS (nigMenu/tabs/) - PARALLEL LOADING
-- ============================================================================

NM.Tabs = {}

local tabList = {
    { f = "auto_tab.lua",      n = "Auto" },
    { f = "upgrades_tab.lua",  n = "Upgrades" },
    { f = "generals_tab.lua",  n = "Generals" },
    { f = "swords_tab.lua",    n = "Swords" },
    { f = "items_tab.lua",     n = "Items" },
    { f = "merger_tab.lua",    n = "Merger" },
    { f = "bosses_tab.lua",    n = "Bosses" },
    { f = "utils_tab.lua",     n = "Utils" },
    { f = "config_tab.lua",    n = "Config" },
    { f = "changelog_tab.lua", n = "Changelog" },
}

local tabsPending = #tabList
local tabsLoaded = {}

print("[nigMenu] Loading " .. #tabList .. " tabs in parallel...")

for _, t in ipairs(tabList) do
    task.spawn(function()
        local m = fetch("tabs/" .. t.f)
        if m then
            NM.Tabs[t.n] = m
            tabsLoaded[t.n] = true
        end
        tabsPending = tabsPending - 1
    end)
end

-- Wait for all tabs to complete
while tabsPending > 0 do
    task.wait(0.05)
end

-- Print results
for _, t in ipairs(tabList) do
    if tabsLoaded[t.n] then
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

-- Always start heartbeat so the manager watchdog knows we're alive
-- (safe to call even if farm starts it later — startHeartbeat guards against duplicates)
if NM.Features.bosses and NM.Features.bosses.startHeartbeat then
    pcall(NM.Features.bosses.startHeartbeat)
    print("[nigMenu] ✓ Heartbeat started")
end

print("[nigMenu] ============================================")
print("[nigMenu] nigMenu LOADED (GitHub)")
print("[nigMenu] Toggle: " .. (NM.Config.State.menuKeybind and NM.Config.State.menuKeybind.Name or "RightControl"))
print("[nigMenu] ============================================")
