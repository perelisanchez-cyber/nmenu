--[[
    ============================================================================
    nigMenu - Settings Manager
    ============================================================================
    
    Handles saving and loading of user settings to a JSON file.
]]

local Settings = {}

-- Get references
local NM = _G.nigMenu
local Config = NM.Config
local HttpService = Config.Services.HttpService

-- ============================================================================
-- SAVE SETTINGS
-- ============================================================================

function Settings.save()
    -- Check if executor supports file writing
    if not writefile then
        return false
    end
    
    local success = pcall(function()
        local data = {
            -- Menu settings
            debugMode = Config.State.debugMode,
            menuKeybind = Config.State.menuKeybind.Name,
            autoLeaveWave = Config.Constants.AUTO_LEAVE_WAVE,
            
            -- Effect settings
            blurAmount = Config.State.blurAmount,
            darknessAmount = Config.State.darknessAmount,
            
            -- Toggle states
            raidLoops = Config.Toggles.raidLoops,
            autoRollLoops = Config.Toggles.autoRollLoops,
            generalUpgradeLoops = Config.Toggles.generalUpgradeLoops,
            swordEnchantLoops = Config.Toggles.swordEnchantLoops,
            swordSplitLoops = Config.Toggles.swordSplitLoops,
            accessoryRollLoops = Config.Toggles.accessoryRollLoops,
            utilityToggles = Config.Toggles.utilityToggles,
            potionToggles = Config.Toggles.potionToggles,
            starAutoMergeSettings = Config.Toggles.starAutoMergeSettings,
            
            -- Boss farm settings (persists farm state across re-inject)
            bossToggles = Config.Toggles.bossToggles
        }
        
        local json = HttpService:JSONEncode(data)
        writefile(Config.SettingsFile, json)
    end)
    
    return success
end

-- ============================================================================
-- LOAD SETTINGS
-- ============================================================================

function Settings.load()
    -- Check if executor supports file reading
    if not isfile or not readfile then
        return nil
    end
    
    -- Check if settings file exists
    if not isfile(Config.SettingsFile) then
        return nil
    end
    
    local success, data = pcall(function()
        local json = readfile(Config.SettingsFile)
        return HttpService:JSONDecode(json)
    end)
    
    if not success or not data then
        return nil
    end
    
    -- Apply loaded settings
    
    -- Menu keybind
    if data.menuKeybind then
        pcall(function()
            Config.State.menuKeybind = Enum.KeyCode[data.menuKeybind]
        end)
    end
    
    -- Debug mode
    if data.debugMode ~= nil then
        Config.State.debugMode = data.debugMode
    end
    
    -- Auto leave wave
    if data.autoLeaveWave then
        Config.Constants.AUTO_LEAVE_WAVE = data.autoLeaveWave
    end
    
    -- Effect settings
    if data.blurAmount then
        Config.State.blurAmount = data.blurAmount
    end
    if data.darknessAmount then
        Config.State.darknessAmount = data.darknessAmount
    end
    
    -- Raid loops
    if data.raidLoops then
        for key, value in pairs(data.raidLoops) do
            if Config.Toggles.raidLoops[key] ~= nil then
                Config.Toggles.raidLoops[key] = value
            end
        end
    end
    
    -- Auto roll loops
    if data.autoRollLoops then
        for key, value in pairs(data.autoRollLoops) do
            Config.Toggles.autoRollLoops[key] = value
        end
    end
    
    -- General upgrade loops
    if data.generalUpgradeLoops then
        for key, value in pairs(data.generalUpgradeLoops) do
            Config.Toggles.generalUpgradeLoops[key] = value
        end
    end
    
    -- Sword enchant loops
    if data.swordEnchantLoops then
        for key, value in pairs(data.swordEnchantLoops) do
            Config.Toggles.swordEnchantLoops[key] = value
        end
    end
    
    -- Sword split loops
    if data.swordSplitLoops then
        for key, value in pairs(data.swordSplitLoops) do
            Config.Toggles.swordSplitLoops[key] = value
        end
    end
    
    -- Accessory roll loops
    if data.accessoryRollLoops then
        for key, value in pairs(data.accessoryRollLoops) do
            Config.Toggles.accessoryRollLoops[key] = value
        end
    end
    
    -- Utility toggles
    if data.utilityToggles then
        for key, value in pairs(data.utilityToggles) do
            if Config.Toggles.utilityToggles[key] ~= nil then
                Config.Toggles.utilityToggles[key] = value
            end
        end
    end
    
    -- Potion toggles
    if data.potionToggles then
        for key, value in pairs(data.potionToggles) do
            if Config.Toggles.potionToggles[key] ~= nil then
                Config.Toggles.potionToggles[key] = value
            end
        end
    end
    
    -- Star auto merge settings
    if data.starAutoMergeSettings then
        Config.Toggles.starAutoMergeSettings = data.starAutoMergeSettings
    end
    
    -- Boss farm toggles (includes farmEnabled for resume across re-inject)
    if data.bossToggles then
        Config.Toggles.bossToggles = data.bossToggles
    end
    
    return data
end

-- ============================================================================
-- RETURN MODULE
-- ============================================================================

return Settings
