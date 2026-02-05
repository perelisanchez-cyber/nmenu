--[[
    ============================================================================
    nigMenu - Generals Feature
    ============================================================================
    
    Handles:
    - Auto-upgrading generals
    - Getting general data
]]

local Generals = {}

-- Lazy load references to avoid circular dependency
local function getNM() return _G.nigMenu end
local function getConfig() return _G.nigMenu and _G.nigMenu.Config end
local function getUtils() return _G.nigMenu and _G.nigMenu.Utils end
local function getBridge() 
    local Config = getConfig()
    return Config and Config.Bridge 
end

-- ============================================================================
-- GENERAL ACTIONS
-- ============================================================================

--[[
    Upgrade a specific general
    @param uuid: The general's UUID
]]
function Generals.upgrade(uuid)
    local Bridge = getBridge()
    if Bridge then
        Bridge:FireServer('Generals', 'Upgrade', uuid)
    end
end

--[[
    Toggle auto upgrade for a specific general
    @param uuid: The general's UUID
    @param enabled: Boolean to enable/disable
]]
function Generals.setLoop(uuid, enabled)
    local Config = getConfig()
    local NM = getNM()
    
    if Config then
        Config.Toggles.generalUpgradeLoops[uuid] = enabled
    end
    
    if NM and NM.Settings then
        NM.Settings.save()
    end
    
    if enabled then
        Generals.startSingleLoop(uuid)
    end
end

--[[
    Check if auto upgrade is active for a general
    @param uuid: The general's UUID
    @return: Boolean
]]
function Generals.isActive(uuid)
    local Config = getConfig()
    return Config and Config.Toggles.generalUpgradeLoops[uuid] == true
end

-- ============================================================================
-- DATA RETRIEVAL
-- ============================================================================

--[[
    Get list of all generals with their data
    @return: Table of generals sorted by name
]]
function Generals.getAll()
    local list = {}
    local Utils = getUtils()
    
    if not Utils then 
        print("[nigMenu] Generals.getAll: Utils not available")
        return list 
    end
    
    local MS = Utils.getMetaService()
    if not MS then
        print("[nigMenu] Generals.getAll: MetaService not found")
        return list
    end
    
    if not MS.Data then
        print("[nigMenu] Generals.getAll: MS.Data is nil")
        return list
    end
    
    if not MS.Data.Generals then
        print("[nigMenu] Generals.getAll: MS.Data.Generals is nil")
        -- Print available keys in MS.Data for debugging
        local keys = {}
        for k, _ in pairs(MS.Data) do
            table.insert(keys, k)
        end
        print("[nigMenu] Generals.getAll: Available MS.Data keys: " .. table.concat(keys, ", "))
        return list
    end
    
    for uuid, data in pairs(MS.Data.Generals) do
        table.insert(list, {
            uuid = uuid,
            name = data.Name or 'Unknown',
            level = (data.LevelSystem and data.LevelSystem.Level) or 0
        })
    end
    
    print("[nigMenu] Generals.getAll: Found " .. #list .. " generals")
    
    -- Sort by name
    table.sort(list, function(a, b)
        return a.name < b.name
    end)
    
    return list
end

-- ============================================================================
-- BACKGROUND LOOPS
-- ============================================================================

function Generals.startSingleLoop(uuid)
    task.spawn(function()
        local Config = getConfig()
        while Config and Config.Toggles.generalUpgradeLoops[uuid] and Config.State.running do
            Generals.upgrade(uuid)
            task.wait(0.05)
        end
    end)
end

function Generals.startLoops()
    local Config = getConfig()
    if not Config then return end
    
    -- Start any general upgrade loops that were saved as active
    for uuid, active in pairs(Config.Toggles.generalUpgradeLoops) do
        if active then
            Generals.startSingleLoop(uuid)
        end
    end
end

-- ============================================================================
-- RETURN MODULE
-- ============================================================================

return Generals
