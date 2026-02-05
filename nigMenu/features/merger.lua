--[[
    ============================================================================
    nigMenu - Pet Merger Feature
    ============================================================================
    
    Handles:
    - Auto-merging pets to higher prestige tiers
    - Configurable max prestige level
]]

local Merger = {}

-- Get references
local NM = _G.nigMenu
local Config = NM.Config
local Utils = NM.Utils

local Bridge = Config.Bridge

-- Prestige order for comparison
local PRESTIGE_ORDER = { 'Normal', 'Shade', 'Shiny', 'Dark', 'Darker' }

-- ============================================================================
-- MERGER SETTINGS
-- ============================================================================

--[[
    Enable or disable auto merge
    @param enabled: Boolean
]]
function Merger.setEnabled(enabled)
    Config.Toggles.starAutoMergeSettings.enabled = enabled
    
    if NM.Settings then
        NM.Settings.save()
    end
end

--[[
    Check if auto merge is enabled
    @return: Boolean
]]
function Merger.isEnabled()
    return Config.Toggles.starAutoMergeSettings.enabled
end

--[[
    Set the maximum prestige level to merge to
    @param prestige: Prestige name (e.g., 'Darker')
]]
function Merger.setMaxPrestige(prestige)
    Config.Toggles.starAutoMergeSettings.maxPrestige = prestige
    
    if NM.Settings then
        NM.Settings.save()
    end
end

--[[
    Get the current max prestige setting
    @return: String
]]
function Merger.getMaxPrestige()
    return Config.Toggles.starAutoMergeSettings.maxPrestige
end

-- ============================================================================
-- MERGE LOGIC
-- ============================================================================

--[[
    Get the prestige level of a pet from its status
    @param status: The pet's status table
    @return: Prestige string
]]
local function getPrestigeLevel(status)
    if not status then
        return 'Normal'
    end
    
    if status.Darker then
        return 'Darker'
    elseif status.Dark then
        return 'Dark'
    elseif status.Shiny then
        return 'Shiny'
    elseif status.Shade then
        return 'Shade'
    end
    
    return 'Normal'
end

--[[
    Get the index of a prestige level
    @param prestige: Prestige name
    @return: Number (1-5)
]]
local function getPrestigeIndex(prestige)
    return table.find(PRESTIGE_ORDER, prestige) or 1
end

--[[
    Perform the pet merge operation
]]
function Merger.performMerge()
    if not Config.Toggles.starAutoMergeSettings.enabled then
        return
    end
    
    pcall(function()
        local MS = Utils.getMetaService()
        if not MS or not MS.Data or not MS.Data.Pets then
            return
        end
        
        local maxPrestige = Config.Toggles.starAutoMergeSettings.maxPrestige
        local maxIdx = getPrestigeIndex(maxPrestige)
        
        -- Group pets by name, rarity, and prestige
        local groups = {}
        
        for petID, petData in pairs(MS.Data.Pets) do
            -- Check if merge is still enabled
            if not Config.Toggles.starAutoMergeSettings.enabled then
                return
            end
            
            -- Get pet info
            local petInfo = MS.SharedModules 
                and MS.SharedModules.Pets 
                and MS.SharedModules.Pets[petData.Name]
            
            if not petInfo then
                continue
            end
            
            -- Get prestige level
            local prestige = getPrestigeLevel(petData.Status)
            local prestigeIdx = getPrestigeIndex(prestige)
            
            -- Skip if already at or above max prestige
            if prestigeIdx >= maxIdx then
                continue
            end
            
            -- Skip if pet is equipped
            if MS.Data.PetsEquipped and MS.Data.PetsEquipped[petID] then
                continue
            end
            
            -- Create group key
            local groupKey = petData.Name .. '|' .. (petInfo.Rarity or '?') .. '|' .. prestige
            
            if not groups[groupKey] then
                groups[groupKey] = {
                    name = petData.Name,
                    rarity = petInfo.Rarity,
                    prestige = prestige,
                    petIDs = {}
                }
            end
            
            table.insert(groups[groupKey].petIDs, petID)
        end
        
        -- Process each group
        for _, group in pairs(groups) do
            -- Check if merge is still enabled
            if not Config.Toggles.starAutoMergeSettings.enabled then
                return
            end
            
            local requirement = Config.Constants.MERGE_REQUIREMENTS[group.prestige]
            local resultType = Config.Constants.MERGE_RESULT[group.prestige]
            
            if not requirement or not resultType then
                continue
            end
            
            -- Check if we have enough pets to merge
            if #group.petIDs >= requirement then
                local mergeCount = math.floor(#group.petIDs / requirement)
                
                for i = 1, mergeCount do
                    -- Check if merge is still enabled
                    if not Config.Toggles.starAutoMergeSettings.enabled then
                        return
                    end
                    
                    -- Get pets for this merge
                    local toMerge = {}
                    for j = 0, requirement - 1 do
                        local idx = (i - 1) * requirement + 1 + j
                        table.insert(toMerge, group.petIDs[idx])
                    end
                    
                    -- Perform merge
                    Bridge:FireServer('Pets', 'SMachine', {
                        TabType = resultType,
                        PetIDs = toMerge,
                        Amount = 200
                    })
                    
                    task.wait(0.3)
                end
            end
        end
    end)
end

-- ============================================================================
-- BACKGROUND LOOPS
-- ============================================================================

function Merger.startLoops()
    task.spawn(function()
        while Config.State.running do
            if Config.Toggles.starAutoMergeSettings.enabled then
                Merger.performMerge()
            end
            
            task.wait(5)
        end
    end)
end

-- ============================================================================
-- RETURN MODULE
-- ============================================================================

return Merger
