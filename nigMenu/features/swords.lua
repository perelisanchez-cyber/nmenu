--[[
    ============================================================================
    nigMenu - Swords Feature
    ============================================================================
    
    Handles:
    - Auto-enchanting swords
    - Getting sword data
    - Rainbow text for SSS rarity
]]

local Swords = {}

-- Lazy load references
local function getNM() return _G.nigMenu end
local function getConfig() return _G.nigMenu and _G.nigMenu.Config end
local function getUtils() return _G.nigMenu and _G.nigMenu.Utils end
local function getBridge() 
    local Config = getConfig()
    return Config and Config.Bridge 
end

-- Storage for rainbow loops
local rainbowLoops = {}

-- ============================================================================
-- SWORD ACTIONS
-- ============================================================================

function Swords.enchant(swordName)
    local Bridge = getBridge()
    if Bridge then
        Bridge:FireServer('EnchantWeapon', 'ScrollTry10', {
            CurrentSword = swordName,
            IsCraftButton10 = true,
            CrystalCost = 50
        })
    end
end

function Swords.setLoop(swordName, enabled)
    local Config = getConfig()
    local NM = getNM()
    
    if Config then
        Config.Toggles.swordEnchantLoops[swordName] = enabled
    end
    
    if NM and NM.Settings then
        NM.Settings.save()
    end
    
    if enabled then
        Swords.startSingleLoop(swordName)
    end
end

function Swords.isActive(swordName)
    local Config = getConfig()
    return Config and Config.Toggles.swordEnchantLoops[swordName] == true
end

-- ============================================================================
-- DATA RETRIEVAL
-- ============================================================================

function Swords.getAll()
    local list = {}
    local Utils = getUtils()
    local Config = getConfig()
    
    if not Utils then return list end
    
    local MS = Utils.getMetaService()
    if not MS or not MS.Data then return list end
    
    -- Use same path as splitter - Weapon Counts
    local swordCounts = MS.Data['Weapon Counts'] or MS.Data.WeaponCounts
    if not swordCounts then return list end
    
    for swordName, count in pairs(swordCounts) do
        if count and count > 0 then
            local rarity = Utils.getSwordRarity(MS, swordName)
            local level = 0
            
            -- Get enchant level from WeaponMultipliers
            if MS.Data.WeaponMultipliers and MS.Data.WeaponMultipliers[swordName] then
                level = MS.Data.WeaponMultipliers[swordName]
            end
            
            table.insert(list, {
                name = swordName,
                rarity = rarity or 'D',
                level = level
            })
        end
    end
    
    -- Sort by rarity (SSS first), then by name
    local rarityOrder = Config and Config.RarityOrder or {}
    table.sort(list, function(a, b)
        local aOrder = rarityOrder[a.rarity] or 99
        local bOrder = rarityOrder[b.rarity] or 99
        if aOrder ~= bOrder then
            return aOrder < bOrder
        end
        return a.name < b.name
    end)
    
    return list
end

function Swords.getRarityColor(rarity)
    local Config = getConfig()
    if Config and Config.RarityColors then
        return Config.RarityColors[rarity] or Config.Theme.Text
    end
    return Color3.fromRGB(235, 235, 245)
end

function Swords.getRarityFont(rarity)
    if rarity == 'SSS' or rarity == 'SS' or rarity == 'S' then
        return Enum.Font.GothamBold
    end
    return Enum.Font.Gotham
end

-- ============================================================================
-- RAINBOW EFFECT
-- ============================================================================

function Swords.startRainbow(swordName, label)
    if rainbowLoops[swordName] then return end
    
    local Config = getConfig()
    rainbowLoops[swordName] = true
    
    task.spawn(function()
        local h = 0
        while rainbowLoops[swordName] and Config and Config.State.running do
            if label and label.Parent then
                h = (h + 0.01) % 1
                label.TextColor3 = Color3.fromHSV(h, 1, 1)
            else
                rainbowLoops[swordName] = nil
                break
            end
            task.wait(0.05)
        end
    end)
end

function Swords.stopRainbow(swordName)
    rainbowLoops[swordName] = nil
end

function Swords.stopAllRainbows()
    for swordName, _ in pairs(rainbowLoops) do
        rainbowLoops[swordName] = nil
    end
end

-- ============================================================================
-- LEVEL UPDATE LOOP
-- ============================================================================

function Swords.startLevelUpdateLoop()
    local Config = getConfig()
    local Utils = getUtils()
    
    task.spawn(function()
        while Config and Config.State.running do
            task.wait(0.5)
            
            local MS = Utils and Utils.getMetaService()
            if not MS or not MS.Data then continue end
            
            if Config.UI.SwordLevelLabels then
                for swordName, data in pairs(Config.UI.SwordLevelLabels) do
                    local level = 0
                    if MS.Data.WeaponMultipliers and MS.Data.WeaponMultipliers[swordName] then
                        level = MS.Data.WeaponMultipliers[swordName]
                    end
                    
                    if data.label and data.label.Parent then
                        data.label.Text = swordName .. ' (+' .. level .. ')'
                    end
                end
            end
        end
    end)
end

-- ============================================================================
-- BACKGROUND LOOPS
-- ============================================================================

function Swords.startSingleLoop(swordName)
    local Config = getConfig()
    
    task.spawn(function()
        while Config and Config.Toggles.swordEnchantLoops[swordName] and Config.State.running do
            Swords.enchant(swordName)
            task.wait(0.1)
        end
    end)
end

function Swords.startLoops()
    local Config = getConfig()
    if not Config then return end
    
    -- Start any sword enchant loops that were saved as active
    for swordName, active in pairs(Config.Toggles.swordEnchantLoops) do
        if active then
            Swords.startSingleLoop(swordName)
        end
    end
    
    -- Start the level update loop
    Swords.startLevelUpdateLoop()
end

-- ============================================================================
-- RETURN MODULE
-- ============================================================================

return Swords
