--[[
    ============================================================================
    nigMenu - Utils Tab UI
    ============================================================================
    
    Creates the UI for utilities, auto-buy, and potion toggles
]]

local UtilsTab = {}

local NM = _G.nigMenu
local Config = NM.Config
local Utils = NM.Utils
local T = Config.Theme
local TS = Config.Services.TweenService

function UtilsTab.init()
    local panel = Config.UI.Tabs['Utils']
    if not panel then return end
    
    local yOffset = 0
    
    -- ========================================================================
    -- UTILITIES CARD
    -- ========================================================================
    
    local utilityCard = Utils.createCard(panel, nil, 280, yOffset)
    
    Utils.createIcon(utilityCard, '🔧', Color3.fromRGB(100, 200, 150), 40, UDim2.new(0, 12, 0, 10))
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 100, 0, 20),
        Position = UDim2.new(0, 60, 0, 12),
        BackgroundTransparency = 1,
        Text = 'UTILITIES',
        TextColor3 = Color3.fromRGB(100, 200, 150),
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = utilityCard
    })
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 180, 0, 14),
        Position = UDim2.new(0, 60, 0, 32),
        BackgroundTransparency = 1,
        Text = 'Automation & QoL features',
        TextColor3 = T.TextMuted,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = utilityCard
    })
    
    local utilityData = {
        { name = 'AutoEquip',        display = 'Auto Equip Best',  icon = '🏆' },
        { name = 'AutoAchievements', display = 'Auto Achievements', icon = '🏅' },
        { name = 'AutoRank',         display = 'Auto Rank Up',     icon = '📈' },
        { name = 'GrabDrops',        display = 'Grab Drops',       icon = '💎' },
        { name = 'AntiAFK',          display = 'Anti-AFK',         icon = '🛡️' },
        { name = 'AutoAttacks',      display = 'Auto Attacks',     icon = '⚡' },
        { name = 'FasterEggOpening', display = 'Faster Egg Open',  icon = '🥚' },
        { name = 'SpamHatch',        display = 'Spam Hatch',       icon = '🐣' }
    }
    
    for i, ud in ipairs(utilityData) do
        local rowY = 56 + (i - 1) * 27
        
        local row = Utils.create('Frame', {
            Size = UDim2.new(1, -24, 0, 24),
            Position = UDim2.new(0, 12, 0, rowY),
            BackgroundColor3 = T.CardHover,
            BackgroundTransparency = 0.6,
            BorderSizePixel = 0,
            Parent = utilityCard
        })
        Utils.addCorner(row, 4)
        
        Utils.create('TextLabel', {
            Size = UDim2.new(0, 24, 1, 0),
            Position = UDim2.new(0, 6, 0, 0),
            BackgroundTransparency = 1,
            Text = ud.icon,
            TextSize = 13,
            Font = Enum.Font.GothamBold,
            Parent = row
        })
        
        Utils.create('TextLabel', {
            Size = UDim2.new(1, -90, 1, 0),
            Position = UDim2.new(0, 32, 0, 0),
            BackgroundTransparency = 1,
            Text = ud.display,
            TextColor3 = T.TextDim,
            TextSize = 13,
            Font = Enum.Font.GothamMedium,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row
        })
        
        local toggleName = ud.name
        local isEnabled = Config.Toggles.utilityToggles[toggleName]
        
        local toggleBg = Utils.create('Frame', {
            Size = UDim2.new(0, 44, 0, 20),
            Position = UDim2.new(1, -50, 0.5, -10),
            BackgroundColor3 = isEnabled and T.Success or T.CardHover,
            BorderSizePixel = 0,
            Parent = row
        })
        Utils.addCorner(toggleBg, 10)
        
        local toggleCircle = Utils.create('Frame', {
            Size = UDim2.new(0, 16, 0, 16),
            Position = isEnabled and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            Parent = toggleBg
        })
        Utils.addCorner(toggleCircle, 8)
        
        local toggleBtn = Utils.create('TextButton', {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = '',
            Parent = row
        })
        
        toggleBtn.MouseButton1Click:Connect(function()
            local nowEnabled = not Config.Toggles.utilityToggles[toggleName]
            Config.Toggles.utilityToggles[toggleName] = nowEnabled
            
            if NM.Settings then
                NM.Settings.save()
            end
            
            TS:Create(toggleBg, TweenInfo.new(0.2), {
                BackgroundColor3 = nowEnabled and T.Success or T.CardHover
            }):Play()
            
            TS:Create(toggleCircle, TweenInfo.new(0.2), {
                Position = nowEnabled and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
            }):Play()
        end)
    end
    
    yOffset = yOffset + 288
    
    -- ========================================================================
    -- AUTO BUY CARD
    -- ========================================================================
    
    local buyCard = Utils.createCard(panel, nil, 240, yOffset)
    
    Utils.createIcon(buyCard, '🛒', Color3.fromRGB(255, 200, 80), 40, UDim2.new(0, 12, 0, 10))
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 100, 0, 20),
        Position = UDim2.new(0, 60, 0, 12),
        BackgroundTransparency = 1,
        Text = 'AUTO BUY',
        TextColor3 = Color3.fromRGB(255, 200, 80),
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = buyCard
    })
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 180, 0, 14),
        Position = UDim2.new(0, 60, 0, 32),
        BackgroundTransparency = 1,
        Text = 'Auto-purchase items',
        TextColor3 = T.TextMuted,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = buyCard
    })
    
    local buyData = {
        { name = 'AutoBuyEpicRune',       display = 'Epic Rune 3',      icon = '🔮' },
        { name = 'AutoUpgradeGenerals',   display = 'Upgrade Generals', icon = '⚔️' },
        { name = 'AutoBuyNYPower',        display = 'NY Power',         icon = '💪' },
        { name = 'AutoBuyNYSouls',        display = 'NY Souls',         icon = '👻' },
        { name = 'AutoBuyNYDamage',       display = 'NY Damage',        icon = '💥' },
        { name = 'AutoBuyFruitTicket',    display = 'Fruit Ticket',     icon = '🎫' },
        { name = 'AutoBuyEyeCoin',        display = 'Eye Coin',         icon = '👁️' },
        { name = 'AutoBuyTitanInjection', display = 'Titan Injection',  icon = '💉' }
    }
    
    for i, bd in ipairs(buyData) do
        local rowY = 56 + (i - 1) * 22
        
        local row = Utils.create('Frame', {
            Size = UDim2.new(1, -24, 0, 20),
            Position = UDim2.new(0, 12, 0, rowY),
            BackgroundTransparency = 1,
            Parent = buyCard
        })
        
        Utils.create('TextLabel', {
            Size = UDim2.new(0, 20, 1, 0),
            BackgroundTransparency = 1,
            Text = bd.icon,
            TextSize = 13,
            Font = Enum.Font.GothamBold,
            Parent = row
        })
        
        Utils.create('TextLabel', {
            Size = UDim2.new(1, -70, 1, 0),
            Position = UDim2.new(0, 22, 0, 0),
            BackgroundTransparency = 1,
            Text = bd.display,
            TextColor3 = T.TextDim,
            TextSize = 13,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row
        })
        
        local toggleName = bd.name
        local isEnabled = Config.Toggles.utilityToggles[toggleName]
        
        local toggleBg = Utils.create('Frame', {
            Size = UDim2.new(0, 36, 0, 16),
            Position = UDim2.new(1, -40, 0.5, -8),
            BackgroundColor3 = isEnabled and T.Success or T.CardHover,
            BorderSizePixel = 0,
            Parent = row
        })
        Utils.addCorner(toggleBg, 8)
        
        local toggleCircle = Utils.create('Frame', {
            Size = UDim2.new(0, 12, 0, 12),
            Position = isEnabled and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            Parent = toggleBg
        })
        Utils.addCorner(toggleCircle, 6)
        
        local toggleBtn = Utils.create('TextButton', {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = '',
            Parent = row
        })
        
        toggleBtn.MouseButton1Click:Connect(function()
            local nowEnabled = not Config.Toggles.utilityToggles[toggleName]
            Config.Toggles.utilityToggles[toggleName] = nowEnabled
            
            if NM.Settings then
                NM.Settings.save()
            end
            
            TS:Create(toggleBg, TweenInfo.new(0.2), {
                BackgroundColor3 = nowEnabled and T.Success or T.CardHover
            }):Play()
            
            TS:Create(toggleCircle, TweenInfo.new(0.2), {
                Position = nowEnabled and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
            }):Play()
        end)
    end
    
    yOffset = yOffset + 248
    
    -- ========================================================================
    -- POTION CARD
    -- ========================================================================
    
    local potionCard = Utils.createCard(panel, nil, 220, yOffset)
    
    Utils.createIcon(potionCard, '🧪', Color3.fromRGB(200, 100, 255), 40, UDim2.new(0, 12, 0, 10))
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 120, 0, 20),
        Position = UDim2.new(0, 60, 0, 12),
        BackgroundTransparency = 1,
        Text = 'POTION PAUSE',
        TextColor3 = Color3.fromRGB(200, 100, 255),
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = potionCard
    })
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 180, 0, 14),
        Position = UDim2.new(0, 60, 0, 32),
        BackgroundTransparency = 1,
        Text = 'Pause potion effects',
        TextColor3 = T.TextMuted,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = potionCard
    })
    
    local potionScroll = Utils.create('ScrollingFrame', {
        Size = UDim2.new(1, -16, 1, -60),
        Position = UDim2.new(0, 8, 0, 56),
        BackgroundTransparency = 1,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = T.Border,
        CanvasSize = UDim2.new(0, 0, 0, #Config.Constants.POTIONS * 24),
        Parent = potionCard
    })
    
    for i, potionName in ipairs(Config.Constants.POTIONS) do
        local rowY = (i - 1) * 24
        
        local row = Utils.create('Frame', {
            Size = UDim2.new(1, -8, 0, 22),
            Position = UDim2.new(0, 0, 0, rowY),
            BackgroundTransparency = 1,
            Parent = potionScroll
        })
        
        Utils.create('TextLabel', {
            Size = UDim2.new(1, -50, 1, 0),
            Position = UDim2.new(0, 4, 0, 0),
            BackgroundTransparency = 1,
            Text = '🧴 ' .. potionName,
            TextColor3 = T.TextDim,
            TextSize = 13,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = row
        })
        
        local pn = potionName
        local isEnabled = Config.Toggles.potionToggles[pn]
        
        local toggleBg = Utils.create('Frame', {
            Size = UDim2.new(0, 32, 0, 14),
            Position = UDim2.new(1, -36, 0.5, -7),
            BackgroundColor3 = isEnabled and T.Success or T.CardHover,
            BorderSizePixel = 0,
            Parent = row
        })
        Utils.addCorner(toggleBg, 7)
        
        local toggleCircle = Utils.create('Frame', {
            Size = UDim2.new(0, 10, 0, 10),
            Position = isEnabled and UDim2.new(1, -12, 0.5, -5) or UDim2.new(0, 2, 0.5, -5),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            Parent = toggleBg
        })
        Utils.addCorner(toggleCircle, 5)
        
        local toggleBtn = Utils.create('TextButton', {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = '',
            Parent = row
        })
        
        toggleBtn.MouseButton1Click:Connect(function()
            local nowEnabled = not Config.Toggles.potionToggles[pn]
            Config.Toggles.potionToggles[pn] = nowEnabled
            
            if NM.Settings then
                NM.Settings.save()
            end
            
            TS:Create(toggleBg, TweenInfo.new(0.2), {
                BackgroundColor3 = nowEnabled and T.Success or T.CardHover
            }):Play()
            
            TS:Create(toggleCircle, TweenInfo.new(0.2), {
                Position = nowEnabled and UDim2.new(1, -12, 0.5, -5) or UDim2.new(0, 2, 0.5, -5)
            }):Play()
        end)
    end
    
    yOffset = yOffset + 228
    
    panel.CanvasSize = UDim2.new(0, 0, 0, yOffset)
end

function UtilsTab.onShow()
    -- Nothing special needed
end

return UtilsTab
