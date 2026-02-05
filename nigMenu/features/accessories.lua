--[[
    ============================================================================
    nigMenu - Accessories Feature
    ============================================================================
    
    Handles:
    - Auto-rolling for accessories (Eye, Fruit, Quirk, Gene)
    - Stopping when target is reached
]]

local Accessories = {}

-- Get references
local NM = _G.nigMenu
local Config = NM.Config
local Utils = NM.Utils

local Bridge = Config.Bridge

-- Roll counters for UI display
local rollCounters = {}

-- ============================================================================
-- ACCESSORY ACTIONS
-- ============================================================================

--[[
    Roll for a specific accessory
    @param typeName: The type name (e.g., 'Eyes', 'Fruits', 'Quirks', 'Genes')
]]
function Accessories.roll(typeName)
    Bridge:FireServer('ItemSystem', 'Buy', {
        typeName = typeName,
        count = 1
    })
end

--[[
    Toggle auto roll for a specific accessory
    @param accessoryName: The accessory name (e.g., 'Eye')
    @param enabled: Boolean to enable/disable
]]
function Accessories.setLoop(accessoryName, enabled)
    Config.Toggles.accessoryRollLoops[accessoryName] = enabled
    
    if NM.Settings then
        NM.Settings.save()
    end
    
    if enabled then
        -- Reset counter
        rollCounters[accessoryName] = 0
        
        -- Find the accessory config and start loop
        for _, acc in ipairs(Config.Constants.ACCESSORY_SYSTEMS) do
            if acc.name == accessoryName then
                Accessories.startSingleLoop(acc)
                break
            end
        end
    end
end

--[[
    Check if auto roll is active for an accessory
    @param accessoryName: The accessory name
    @return: Boolean
]]
function Accessories.isActive(accessoryName)
    return Config.Toggles.accessoryRollLoops[accessoryName] == true
end

--[[
    Get the roll counter for an accessory
    @param accessoryName: The accessory name
    @return: Number
]]
function Accessories.getRollCount(accessoryName)
    return rollCounters[accessoryName] or 0
end

-- ============================================================================
-- DATA RETRIEVAL
-- ============================================================================

--[[
    Get the current accessory for a type
    @param accessoryName: The accessory type (e.g., 'Eye')
    @return: String or nil
]]
function Accessories.getCurrent(accessoryName)
    local MS = Utils.getMetaService()
    if not MS or not MS.Data then
        return nil
    end
    
    return MS.Data[accessoryName]
end

--[[
    Get the rarity of an accessory
    @param accessoryName: The accessory type (e.g., 'Eye')
    @param itemName: The specific item name
    @return: Rarity string or nil
]]
function Accessories.getRarity(accessoryName, itemName)
    local MS = Utils.getMetaService()
    if not MS or not MS.SharedModules then
        return nil
    end
    
    local moduleName = accessoryName .. 's' -- e.g., 'Eyes', 'Fruits'
    if MS.SharedModules[moduleName] and MS.SharedModules[moduleName][itemName] then
        return MS.SharedModules[moduleName][itemName].Rarity
    end
    
    return nil
end

--[[
    Check if current accessory matches target
    @param accessoryName: The accessory type
    @param target: The target item name
    @return: Boolean
]]
function Accessories.hasTarget(accessoryName, target)
    local current = Accessories.getCurrent(accessoryName)
    return current == target
end

-- ============================================================================
-- BACKGROUND LOOPS
-- ============================================================================

function Accessories.startSingleLoop(accessoryConfig)
    local name = accessoryConfig.name
    local typeName = accessoryConfig.typeName
    local target = accessoryConfig.target
    
    task.spawn(function()
        while Config.Toggles.accessoryRollLoops[name] and Config.State.running do
            pcall(function()
                local current = Accessories.getCurrent(name)
                
                -- Check if we got the target
                if current == target then
                    Config.Toggles.accessoryRollLoops[name] = false
                    Utils.dprint(name .. ' target reached: ' .. target)
                    
                    if NM.Settings then
                        NM.Settings.save()
                    end
                    return
                end
                
                -- Roll
                Accessories.roll(typeName)
                rollCounters[name] = (rollCounters[name] or 0) + 1
            end)
            
            task.wait(2)
        end
    end)
end

function Accessories.startLoops()
    -- Start any accessory roll loops that were saved as active
    for _, acc in ipairs(Config.Constants.ACCESSORY_SYSTEMS) do
        if Config.Toggles.accessoryRollLoops[acc.name] then
            rollCounters[acc.name] = 0
            Accessories.startSingleLoop(acc)
        end
    end
    
    -- Start label update loop
    Accessories.startLabelUpdateLoop()
end

-- ============================================================================
-- UI LABEL UPDATE
-- ============================================================================

function Accessories.startLabelUpdateLoop()
    task.spawn(function()
        task.wait(3) -- Initial delay
        
        while Config.State.running do
            Accessories.updateLabels()
            task.wait(5)
        end
    end)
end

function Accessories.updateLabels()
    if not Config.UI.AccessoryLabels then
        return
    end
    
    pcall(function()
        for _, acc in ipairs(Config.Constants.ACCESSORY_SYSTEMS) do
            local label = Config.UI.AccessoryLabels[acc.name]
            
            if label then
                local current = Accessories.getCurrent(acc.name)
                
                if current then
                    -- Check if target
                    if current == acc.target then
                        label.Text = current
                        label.TextColor3 = Config.Theme.Success
                        label.Font = Enum.Font.GothamBold
                    else
                        -- Show with roll count if rolling
                        local rollCount = rollCounters[acc.name]
                        if Config.Toggles.accessoryRollLoops[acc.name] and rollCount then
                            label.Text = current .. ' (' .. rollCount .. ' rolls)'
                        else
                            label.Text = current
                        end
                        
                        -- Set color based on rarity
                        local rarity = Accessories.getRarity(acc.name, current)
                        label.TextColor3 = Config.AccessoryRarityColors[rarity] or Config.Theme.TextDim
                        label.Font = Enum.Font.GothamMedium
                    end
                else
                    label.Text = 'None'
                    label.TextColor3 = Config.Theme.TextDim
                end
            end
        end
    end)
end

-- ============================================================================
-- RETURN MODULE
-- ============================================================================

return Accessories
