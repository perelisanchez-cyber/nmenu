--[[
    ============================================================================
    nigMenu - Raids Feature
    ============================================================================
    
    Handles:
    - Joining raids
    - Leaving raids
    - Auto-loop raids
    - Auto-leave at wave threshold
]]

local Raids = {}

-- Get references
local NM = _G.nigMenu
local Config = NM.Config
local Utils = NM.Utils

local Bridge = Config.Bridge

-- ============================================================================
-- RAID ACTIONS
-- ============================================================================

--[[
    Join a specific raid
    @param raidName: The raid identifier (e.g., 'Raid', 'Raid_02', etc.)
]]
function Raids.join(raidName)
    Bridge:FireServer('Enemies', 'Bridge', {
        Module = 'RaidSystemServer',
        FunctionName = 'Start',
        Args = raidName
    })
end

--[[
    Leave a specific raid
    @param raidName: The raid identifier
]]
function Raids.leave(raidName)
    Bridge:FireServer('Enemies', 'Bridge', {
        Module = 'RaidSystemServer',
        FunctionName = 'Leave',
        Args = raidName
    })
end

--[[
    Toggle raid loop for a specific raid
    @param raidName: The raid identifier
    @param enabled: Boolean to enable/disable
]]
function Raids.setLoop(raidName, enabled)
    Config.Toggles.raidLoops[raidName] = enabled
    
    if NM.Settings then
        NM.Settings.save()
    end
    
    if enabled then
        Raids.startLoop(raidName)
    end
end

-- ============================================================================
-- RAID LOOP
-- ============================================================================

function Raids.startLoop(raidName)
    task.spawn(function()
        while Config.Toggles.raidLoops[raidName] and Config.State.running do
            -- Check if should auto-leave (for certain raids)
            if (raidName == 'Raid_HW' or raidName == 'Raid_04') 
                and Config.Constants.ENABLE_AUTO_LEAVE 
                and Utils.isInRaid(raidName) 
            then
                local wave = Utils.getCurrentRaidWave()
                
                if wave and wave >= Config.Constants.AUTO_LEAVE_WAVE then
                    Raids.leave(raidName)
                    task.wait(3)
                    Config.State.currentWave = 0
                    _G.CurrentWave = 0
                end
            end
            
            -- Join if not in raid
            if not Utils.isInRaid(raidName) then
                Raids.join(raidName)
                task.wait(5)
            else
                task.wait(2)
            end
        end
    end)
end

-- ============================================================================
-- START BACKGROUND LOOPS
-- ============================================================================

function Raids.startLoops()
    -- Start any raid loops that were saved as active
    for raidName, active in pairs(Config.Toggles.raidLoops) do
        if active then
            Raids.startLoop(raidName)
        end
    end
end

-- ============================================================================
-- RETURN MODULE
-- ============================================================================

return Raids
