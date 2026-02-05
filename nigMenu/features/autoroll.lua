--[[
    ============================================================================
    nigMenu - Auto Roll Feature
    ============================================================================
    
    Handles:
    - Auto-rolling eggs on maps
    - Premium roll option
]]

local AutoRoll = {}

-- Get references
local NM = _G.nigMenu
local Config = NM.Config
local Utils = NM.Utils

local Bridge = Config.Bridge

-- ============================================================================
-- AUTO ROLL ACTIONS
-- ============================================================================

--[[
    Perform a roll on a specific map
    @param mapName: The map name
    @param usePremium: Boolean for premium rolls
]]
function AutoRoll.roll(mapName, usePremium)
    if usePremium then
        Bridge:FireServer('Stars', 'RollByCoins', {
            Name = mapName,
            Count = 8
        })
    else
        Bridge:FireServer('Stars', 'Roll', {
            Map = mapName,
            Type = 'Multi'
        })
    end
end

--[[
    Toggle auto roll for a specific map
    @param mapName: The map name
    @param enabled: Boolean to enable/disable
]]
function AutoRoll.setLoop(mapName, enabled)
    Config.Toggles.autoRollLoops[mapName] = enabled
    
    if NM.Settings then
        NM.Settings.save()
    end
end

--[[
    Check if auto roll is active for a map
    @param mapName: The map name
    @return: Boolean
]]
function AutoRoll.isActive(mapName)
    return Config.Toggles.autoRollLoops[mapName] == true
end

-- ============================================================================
-- BACKGROUND LOOPS
-- ============================================================================

function AutoRoll.startLoops()
    -- Get all maps
    local allMaps = Utils.getAllMaps()
    
    -- Initialize toggle states for new maps
    for _, mapName in ipairs(allMaps) do
        if Config.Toggles.autoRollLoops[mapName] == nil then
            Config.Toggles.autoRollLoops[mapName] = false
        end
    end
    
    -- Start a loop for each map
    for _, mapName in ipairs(allMaps) do
        task.spawn(function()
            while Config.State.running do
                if Config.Toggles.autoRollLoops[mapName] then
                    pcall(function()
                        AutoRoll.roll(mapName, Config.State.usePremiumRolls)
                    end)
                end
                
                -- Different wait times for premium vs normal
                local waitTime = Config.State.usePremiumRolls and 0.5 or 0.1
                task.wait(waitTime)
            end
        end)
    end
end

-- ============================================================================
-- RETURN MODULE
-- ============================================================================

return AutoRoll
