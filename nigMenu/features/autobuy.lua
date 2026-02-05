--[[
    ============================================================================
    nigMenu - Auto Buy Feature
    ============================================================================
    
    Handles:
    - Auto-buying Epic Rune
    - Auto-buying event shop items (NY Power, NY Souls, etc.)
]]

local AutoBuy = {}

-- Get references
local NM = _G.nigMenu
local Config = NM.Config
local Utils = NM.Utils

local Bridge = Config.Bridge
local RS = Config.Services.ReplicatedStorage

-- ============================================================================
-- TOGGLE HELPERS
-- ============================================================================

--[[
    Set an auto buy toggle
    @param name: Toggle name
    @param enabled: Boolean
]]
function AutoBuy.setToggle(name, enabled)
    Config.Toggles.utilityToggles[name] = enabled
    
    if NM.Settings then
        NM.Settings.save()
    end
end

--[[
    Get an auto buy toggle state
    @param name: Toggle name
    @return: Boolean
]]
function AutoBuy.isEnabled(name)
    return Config.Toggles.utilityToggles[name] == true
end

-- ============================================================================
-- AUTO BUY EPIC RUNE
-- ============================================================================

local function autoBuyEpicRuneLoop()
    task.spawn(function()
        while Config.State.running do
            if Config.Toggles.utilityToggles.AutoBuyEpicRune then
                pcall(function()
                    local shopModule = RS:FindFirstChild('SharedModules')
                        and RS.SharedModules:FindFirstChild('Shop')
                    
                    if shopModule then
                        local remoteEvent = shopModule:FindFirstChild('RemoteEvent')
                        if remoteEvent then
                            remoteEvent:FireServer('PurchaseProduct', 'epic_rune_3')
                        end
                    end
                end)
            end
            task.wait(0.0001) -- Very fast loop for rune buying
        end
    end)
end

-- ============================================================================
-- AUTO BUY EVENT SHOP ITEMS
-- ============================================================================

local function createEventShopLoop(toggleName, productId)
    task.spawn(function()
        while Config.State.running do
            if Config.Toggles.utilityToggles[toggleName] then
                pcall(function()
                    Bridge:FireServer('EventShopsServer', 'Purchase', {
                        shopId = 'Christmas2025',
                        productId = productId
                    })
                end)
            end
            task.wait(0.01)
        end
    end)
end

-- ============================================================================
-- START ALL LOOPS
-- ============================================================================

function AutoBuy.startLoops()
    -- Epic Rune loop
    autoBuyEpicRuneLoop()
    
    -- Event shop loops
    for _, item in ipairs(Config.Constants.AUTO_BUY_ITEMS) do
        createEventShopLoop(item.name, item.productId)
    end
end

-- ============================================================================
-- RETURN MODULE
-- ============================================================================

return AutoBuy
