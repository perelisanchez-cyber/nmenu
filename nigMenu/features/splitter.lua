--[[
    ============================================================================
    nigMenu - Sword Splitter Feature
    ============================================================================
    
    Handles:
    - Splitting swords for dust
    - Auto-split functionality
]]

local Splitter = {}

-- Lazy load references
local function getNM() return _G.nigMenu end
local function getConfig() return _G.nigMenu and _G.nigMenu.Config end
local function getUtils() return _G.nigMenu and _G.nigMenu.Utils end
local function getBridge() 
    local Config = getConfig()
    return Config and Config.Bridge 
end

-- ============================================================================
-- SPLITTER ACTIONS
-- ============================================================================

function Splitter.split(swordName, amount)
    local Bridge = getBridge()
    if Bridge then
        Bridge:FireServer('Wsplit', 'Split', {
            CurrentSword = swordName,
            Amount = amount or 1
        })
    end
end

function Splitter.setAutoLoop(swordName, enabled)
    local Config = getConfig()
    local NM = getNM()
    
    if Config then
        Config.Toggles.swordSplitLoops[swordName] = enabled
    end
    
    if NM and NM.Settings then
        NM.Settings.save()
    end
    
    if enabled then
        Splitter.startSingleLoop(swordName)
    end
end

function Splitter.isAutoActive(swordName)
    local Config = getConfig()
    return Config and Config.Toggles.swordSplitLoops[swordName] == true
end

-- ============================================================================
-- DATA RETRIEVAL
-- ============================================================================

function Splitter.getCount(swordName)
    local Utils = getUtils()
    if not Utils then return 0 end
    
    local MS = Utils.getMetaService()
    if not MS or not MS.Data then return 0 end
    
    -- Try both possible locations
    local counts = MS.Data['Weapon Counts'] or MS.Data.WeaponCounts
    if counts and counts[swordName] then
        return counts[swordName]
    end
    
    return 0
end

function Splitter.getAll()
    local list = {}
    local Utils = getUtils()
    local Config = getConfig()
    
    if not Utils then return list end
    
    local MS = Utils.getMetaService()
    if not MS or not MS.Data then return list end
    
    local counts = MS.Data['Weapon Counts'] or MS.Data.WeaponCounts
    if not counts then return list end
    
    for swordName, count in pairs(counts) do
        if count > 0 then
            local rarity = Utils.getSwordRarity(MS, swordName) or 'D'
            
            table.insert(list, {
                name = swordName,
                count = count,
                rarity = rarity
            })
        end
    end
    
    -- Sort by rarity (SSS first), then by count, then by name
    local rarityOrder = Config and Config.RarityOrder or {}
    table.sort(list, function(a, b)
        local aOrder = rarityOrder[a.rarity] or 99
        local bOrder = rarityOrder[b.rarity] or 99
        if aOrder ~= bOrder then
            return aOrder < bOrder
        end
        if a.count ~= b.count then
            return a.count > b.count
        end
        return a.name < b.name
    end)
    
    return list
end

-- ============================================================================
-- BACKGROUND LOOPS
-- ============================================================================

function Splitter.startSingleLoop(swordName)
    local Config = getConfig()
    
    task.spawn(function()
        while Config and Config.Toggles.swordSplitLoops[swordName] and Config.State.running do
            local count = Splitter.getCount(swordName)
            
            -- Keep 1, split the rest
            if count > 1 then
                Splitter.split(swordName, count - 1)
            end
            
            task.wait(2)
        end
    end)
end

function Splitter.startLoops()
    local Config = getConfig()
    if not Config then return end
    
    -- Start any split loops that were saved as active
    for swordName, active in pairs(Config.Toggles.swordSplitLoops) do
        if active then
            Splitter.startSingleLoop(swordName)
        end
    end
end

-- ============================================================================
-- RETURN MODULE
-- ============================================================================

return Splitter
