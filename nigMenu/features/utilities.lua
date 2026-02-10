--[[
    ============================================================================
    nigMenu - Utilities Feature
    ============================================================================
    
    Handles:
    - Auto Equip Best Pets
    - Auto Achievements
    - Auto Rank Up
    - Grab Drops
    - Anti-AFK
    - Auto Attacks
    - Faster Egg Opening
    - Spam Hatch
]]

local Utilities = {}

-- Get references
local NM = _G.nigMenu
local Config = NM.Config
local Utils = NM.Utils

local Bridge = Config.Bridge
local RS = Config.Services.RunService
local VirtualUser = Config.Services.VirtualUser

-- ============================================================================
-- TOGGLE HELPERS
-- ============================================================================

--[[
    Set a utility toggle
    @param name: Toggle name
    @param enabled: Boolean
]]
function Utilities.setToggle(name, enabled)
    Config.Toggles.utilityToggles[name] = enabled
    
    if NM.Settings then
        NM.Settings.save()
    end
end

--[[
    Get a utility toggle state
    @param name: Toggle name
    @return: Boolean
]]
function Utilities.isEnabled(name)
    return Config.Toggles.utilityToggles[name] == true
end

-- ============================================================================
-- AUTO EQUIP BEST
-- ============================================================================

local function autoEquipLoop()
    task.spawn(function()
        while Config.State.running do
            if Config.Toggles.utilityToggles.AutoEquip then
                pcall(function()
                    Bridge:FireServer('Pets', 'Best')
                end)
            end
            task.wait(5)
        end
    end)
end

-- ============================================================================
-- AUTO RANK UP
-- ============================================================================

local function autoRankLoop()
    task.spawn(function()
        while Config.State.running do
            if Config.Toggles.utilityToggles.AutoRank then
                pcall(function()
                    local MS = Utils.getMetaService()
                    if not MS or not MS.Data then return end
                    
                    local nextRank = MS.Data.Rank + 1
                    
                    if MS.Data.Energy 
                        and MS.SharedModules 
                        and MS.SharedModules.Ranks 
                        and MS.SharedModules.Ranks[nextRank] 
                    then
                        local price = MS.SharedModules.Ranks[nextRank].Price
                        local required = MS.Utils and MS.Utils.Number and MS.Utils.Number:Unformat(price)
                        
                        if required and MS.Data.Energy >= required then
                            Bridge:FireServer('RankUp', 'Evolve')
                        end
                    end
                end)
            end
            task.wait(5)
        end
    end)
end

-- ============================================================================
-- AUTO UPGRADE GENERALS (Utility version - upgrades all)
-- ============================================================================

local function autoUpgradeGeneralsLoop()
    task.spawn(function()
        while Config.State.running do
            if Config.Toggles.utilityToggles.AutoUpgradeGenerals then
                pcall(function()
                    local MS = Utils.getMetaService()
                    if MS and MS.Data and MS.Data.Generals then
                        for uuid, _ in pairs(MS.Data.Generals) do
                            Bridge:FireServer('Generals', 'Upgrade', uuid)
                        end
                    end
                end)
            end
            task.wait(0.5)
        end
    end)
end

-- ============================================================================
-- AUTO ACHIEVEMENTS
-- ============================================================================

local function autoAchievementsLoop()
    task.spawn(function()
        while Config.State.running do
            if Config.Toggles.utilityToggles.AutoAchievements then
                pcall(function()
                    local LP = Config.LocalPlayer
                    local items = LP.PlayerGui:FindFirstChild('UI')
                        and LP.PlayerGui.UI:FindFirstChild('Frames')
                        and LP.PlayerGui.UI.Frames:FindFirstChild('Achievements')
                    
                    if items then
                        items = items:FindFirstChild('NewMain')
                            and items.NewMain:FindFirstChild('body')
                            and items.NewMain.body:FindFirstChild('items')
                    end
                    
                    if items then
                        for _, v in pairs(items:GetChildren()) do
                            if v:IsA('ImageLabel') then
                                -- Skip if already claimed
                                if v:FindFirstChild('claimed') and v.claimed.Visible then
                                    continue
                                end
                                
                                -- Check if progress is complete
                                if v:FindFirstChild('backFill') 
                                    and v.backFill:FindFirstChild('progress') 
                                then
                                    local current, total = Utils.parseNumbers(v.backFill.progress.Text)
                                    if current and total and current < total then
                                        continue
                                    end
                                end
                                
                                -- Claim achievement
                                Bridge:FireServer('Achievements', 'Claim', v.Name)
                                task.wait(0.5)
                            end
                        end
                    end
                end)
            end
            task.wait(2)
        end
    end)
end

-- ============================================================================
-- GRAB DROPS
-- ============================================================================

local function setupGrabDrops()
    task.spawn(function()
        local debris = workspace:FindFirstChild('Debris')
        
        if debris then
            debris.ChildAdded:Connect(function(part)
                if Config.Toggles.utilityToggles.GrabDrops 
                    and part:IsA('Part') 
                    and part:FindFirstChild('UID') 
                then
                    pcall(function()
                        Bridge:FireServer('Drops', 'Collect', part.Name)
                        part:Destroy()
                    end)
                end
            end)
        end
    end)
end

-- ============================================================================
-- ANTI-AFK
-- ============================================================================

local function setupAntiAFK()
    Config.LocalPlayer.Idled:Connect(function()
        if Config.Toggles.utilityToggles.AntiAFK then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end
    end)
end

-- ============================================================================
-- AUTO ATTACKS
-- ============================================================================

local function setupAutoAttacks()
    task.spawn(function()
        local MS = Utils.getMetaService()
        if not MS then return end
        
        RS.Heartbeat:Connect(function()
            if Config.Toggles.utilityToggles.AutoAttacks 
                and MS.Cache 
                and MS.Cache.ProximityEnemy 
                and MS.Cache.ProximityEnemy.Enemy 
            then
                pcall(function()
                    MS.Bridge:Fire('Attack', 'Click', MS.Cache.ProximityEnemy)
                end)
            end
        end)
    end)
end

-- ============================================================================
-- FASTER EGG OPENING
-- ============================================================================

local function setupFasterEggOpening()
    task.spawn(function()
        pcall(function()
            local LP = Config.LocalPlayer
            local stars = require(LP.PlayerScripts.MetaService.Client.Stars)
            local originalStarOpen = stars.StarOpen

            stars.StarOpen = function(petData)
                if not Config.Toggles.utilityToggles.FasterEggOpening then
                    return originalStarOpen(petData)
                end

                -- Try to speed up by using hookfunction if available (some executors)
                local hooked = false
                local originalWait = task.wait

                pcall(function()
                    if hookfunction then
                        local fastWait = function(duration)
                            if duration and duration > 0.1 then
                                return originalWait(0.02)
                            end
                            return originalWait(duration)
                        end
                        hookfunction(task.wait, fastWait)
                        hooked = true
                    end
                end)

                local result = originalStarOpen(petData)

                -- Restore if we hooked
                if hooked then
                    pcall(function()
                        hookfunction(task.wait, originalWait)
                    end)
                end

                return result
            end
        end)
    end)
end

-- ============================================================================
-- SPAM HATCH
-- ============================================================================

local function setupSpamHatch()
    task.spawn(function()
        local MS = Utils.getMetaService()
        if not MS then return end
        
        RS.Heartbeat:Connect(function()
            if Config.Toggles.utilityToggles.SpamHatch 
                and MS.Cache.Star 
                and not MS.LocalPlayer:GetAttribute('StarOpening') 
            then
                pcall(function()
                    for i = 1, 3 do
                        MS.Bridge:Fire('Stars', 'Roll', {
                            Map = MS.Cache.Star.Parent.Parent.Name,
                            Type = 'Multi'
                        })
                    end
                end)
            end
        end)
    end)
end

-- ============================================================================
-- START ALL LOOPS
-- ============================================================================

function Utilities.startLoops()
    autoEquipLoop()
    autoRankLoop()
    autoUpgradeGeneralsLoop()
    autoAchievementsLoop()
    
    setupGrabDrops()
    setupAntiAFK()
    setupAutoAttacks()
    setupFasterEggOpening()
    setupSpamHatch()
end

-- ============================================================================
-- RETURN MODULE
-- ============================================================================

return Utilities
