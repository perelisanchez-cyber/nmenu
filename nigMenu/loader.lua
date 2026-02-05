--[[
    ============================================================================
    nigMenu v1.0 - Modular Loader
    ============================================================================
    
    This is the main entry point. Execute this file to load the entire menu.
    
    Usage:
    loadstring(readfile("nigMenu/loader.lua"))()
    
    Or if nigMenu folder is elsewhere:
    _G.nigMenuPath = "path/to/nigMenu/"
    loadstring(readfile(_G.nigMenuPath .. "loader.lua"))()
]]

-- ============================================================================
-- SINGLE INSTANCE CHECK - Kill old instance before starting new one
-- ============================================================================

if _G.nigMenu then
    print("[nigMenu] Previous instance detected, cleaning up...")
    
    -- Stop all loops by setting running to false
    if _G.nigMenu.Config and _G.nigMenu.Config.State then
        _G.nigMenu.Config.State.running = false
    end
    
    -- Destroy the UI
    if _G.nigMenu.Config and _G.nigMenu.Config.UI and _G.nigMenu.Config.UI.ScreenGui then
        pcall(function()
            _G.nigMenu.Config.UI.ScreenGui:Destroy()
        end)
    end
    
    -- Also try to find and destroy by name in CoreGui
    pcall(function()
        local CoreGui = game:GetService('CoreGui')
        local existing = CoreGui:FindFirstChild('nigMenu')
        if existing then
            existing:Destroy()
        end
        -- Also destroy console window
        local consoleGui = CoreGui:FindFirstChild('nigMenuConsole')
        if consoleGui then
            consoleGui:Destroy()
        end
    end)
    
    -- Clear the global
    _G.nigMenu = nil
    
    -- Small wait for loops to terminate
    task.wait(0.5)
    
    print("[nigMenu] Old instance terminated")
end

-- ============================================================================
-- PATH DETECTION
-- ============================================================================

-- Allow custom path override
local BASE_PATH = _G.nigMenuPath or "nigMenu/"

-- Ensure path ends with /
if not BASE_PATH:match("/$") then
    BASE_PATH = BASE_PATH .. "/"
end

print("[nigMenu] Base path: " .. BASE_PATH)

-- ============================================================================
-- EXECUTOR COMPATIBILITY CHECK
-- ============================================================================

if not isfile then
    error("[nigMenu] Your executor doesn't support isfile() - cannot load modular version")
end

if not readfile then
    error("[nigMenu] Your executor doesn't support readfile() - cannot load modular version")
end

if not loadstring then
    error("[nigMenu] Your executor doesn't support loadstring() - cannot load modular version")
end

-- ============================================================================
-- DEBUG: List available files
-- ============================================================================

local function listFiles()
    if listfiles then
        print("[nigMenu] Checking for files in workspace...")
        local success, files = pcall(function()
            return listfiles("")
        end)
        if success then
            for _, f in ipairs(files) do
                if f:match("nigMenu") or f:match("nig") then
                    print("[nigMenu] Found: " .. f)
                end
            end
        end
    end
end

-- ============================================================================
-- MODULE LOADER
-- ============================================================================

local function loadModule(relativePath)
    local fullPath = BASE_PATH .. relativePath
    
    -- Check if file exists
    if not isfile(fullPath) then
        warn("[nigMenu] Module not found: " .. fullPath)
        
        -- Try alternate paths
        local altPaths = {
            relativePath,  -- Try without base path
            "nigMenu/" .. relativePath,
            "scripts/nigMenu/" .. relativePath,
            "workspace/nigMenu/" .. relativePath
        }
        
        for _, altPath in ipairs(altPaths) do
            if isfile(altPath) then
                fullPath = altPath
                print("[nigMenu] Found at alternate path: " .. altPath)
                break
            end
        end
        
        if not isfile(fullPath) then
            listFiles()
            return nil
        end
    end
    
    -- Load the module
    local success, result = pcall(function()
        local content = readfile(fullPath)
        local fn, err = loadstring(content)
        if not fn then
            error("Syntax error: " .. tostring(err))
        end
        return fn()
    end)
    
    if success then
        return result
    else
        warn("[nigMenu] Failed to load: " .. relativePath)
        warn("[nigMenu] Error: " .. tostring(result))
        return nil
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

print("[nigMenu] ============================================")
print("[nigMenu] Starting nigMenu Loader v1.0")
print("[nigMenu] ============================================")

-- Small delay for game to be ready
if task and task.wait then
    task.wait(3)
elseif wait then
    wait(3)
end

-- Initialize global table FIRST
_G.nigMenu = {}
local NM = _G.nigMenu

-- ============================================================================
-- LOAD CORE MODULES
-- ============================================================================

print("[nigMenu] Loading core modules...")

-- 1. Config (no dependencies)
NM.Config = loadModule("core/config.lua")
if not NM.Config then
    error("[nigMenu] Failed to load config - cannot continue\n\nMake sure the nigMenu folder is in your executor's workspace folder.\n\nExpected structure:\n  workspace/\n    nigMenu/\n      loader.lua\n      core/\n        config.lua\n        utils.lua\n        ...\n      features/\n        ...\n      tabs/\n        ...")
end
print("[nigMenu] ✓ Config loaded")

-- 2. Utils (depends on Config via _G.nigMenu)
NM.Utils = loadModule("core/utils.lua")
if not NM.Utils then
    error("[nigMenu] Failed to load utils - cannot continue")
end
print("[nigMenu] ✓ Utils loaded")

-- 3. Settings (save/load)
NM.Settings = loadModule("core/settings.lua")
if NM.Settings then
    print("[nigMenu] ✓ Settings loaded")
else
    print("[nigMenu] ⚠ Settings not loaded (optional)")
end

-- 4. UI Framework
NM.UI = loadModule("core/ui.lua")
if not NM.UI then
    error("[nigMenu] Failed to load UI - cannot continue")
end
print("[nigMenu] ✓ UI loaded")

-- ============================================================================
-- LOAD FEATURE MODULES
-- ============================================================================

print("[nigMenu] Loading features...")

NM.Features = {}

local featureModules = {
    "console",
    "raids",
    "autoroll", 
    "generals",
    "swords",
    "splitter",
    "accessories",
    "merger",
    "utilities",
    "autobuy",
    "bosses"
}

for _, name in ipairs(featureModules) do
    local module = loadModule("features/" .. name .. ".lua")
    if module then
        NM.Features[name] = module
        print("[nigMenu] ✓ " .. name)
    else
        print("[nigMenu] ⚠ " .. name .. " (skipped)")
    end
end

-- ============================================================================
-- LOAD TAB MODULES
-- ============================================================================

print("[nigMenu] Loading tabs...")

NM.Tabs = {}

local tabModules = {
    { file = "auto_tab.lua", name = "Auto" },
    { file = "upgrades_tab.lua", name = "Upgrades" },
    { file = "items_tab.lua", name = "Items" },
    { file = "merger_tab.lua", name = "Merger" },
    { file = "bosses_tab.lua", name = "Bosses" },
    { file = "server_tab.lua", name = "ServerHopper" },
    { file = "utils_tab.lua", name = "Utils" },
    { file = "config_tab.lua", name = "Config" },
    { file = "changelog_tab.lua", name = "Changelog" }
}

for _, tab in ipairs(tabModules) do
    local module = loadModule("tabs/" .. tab.file)
    if module then
        NM.Tabs[tab.name] = module
        print("[nigMenu] ✓ " .. tab.name .. " tab")
    else
        print("[nigMenu] ⚠ " .. tab.name .. " tab (skipped)")
    end
end

-- ============================================================================
-- INITIALIZE EVERYTHING
-- ============================================================================

print("[nigMenu] Initializing...")

-- Load saved settings
if NM.Settings and NM.Settings.load then
    pcall(NM.Settings.load)
end

-- Create main window
if NM.UI and NM.UI.createMainWindow then
    local success, err = pcall(NM.UI.createMainWindow)
    if not success then
        warn("[nigMenu] UI creation error: " .. tostring(err))
    end
end

-- Initialize tabs
for tabName, tabModule in pairs(NM.Tabs) do
    if tabModule.init then
        pcall(tabModule.init)
    end
end

-- Start feature loops
for featureName, featureModule in pairs(NM.Features) do
    if featureModule.startLoops then
        pcall(featureModule.startLoops)
    end
end

-- Check if boss farm should auto-start (for autoexec relaunch loop)
if NM.Features.bosses and NM.Features.bosses.checkAutoStart then
    pcall(NM.Features.bosses.checkAutoStart)
end

-- ============================================================================
-- DONE
-- ============================================================================

print("[nigMenu] ============================================")
print("[nigMenu] nigMenu v1.0 LOADED!")
print("[nigMenu] Toggle: " .. (NM.Config.State.menuKeybind and NM.Config.State.menuKeybind.Name or "RightControl"))
print("[nigMenu] ============================================")
