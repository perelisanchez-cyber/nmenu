--[[
    ============================================================================
    nigMenu - Items Tab UI
    ============================================================================
    
    Creates the UI for accessory rolling (Eye, Fruit, Quirk, Gene)
]]

local ItemsTab = {}

local NM = _G.nigMenu
local Config = NM.Config
local Utils = NM.Utils
local T = Config.Theme
local TS = Config.Services.TweenService

function ItemsTab.init()
    local panel = Config.UI.Tabs['Items']
    if not panel then return end
    
    local yOffset = 0
    
    for _, acc in ipairs(Config.Constants.ACCESSORY_SYSTEMS) do
        local card = Utils.createCard(panel, nil, 100, yOffset)
        
        -- Icon
        Utils.createIcon(card, acc.icon, acc.color, 50, UDim2.new(0, 12, 0, 25))
        
        -- Title
        Utils.create('TextLabel', {
            Size = UDim2.new(0, 100, 0, 20),
            Position = UDim2.new(0, 72, 0, 12),
            BackgroundTransparency = 1,
            Text = acc.name:upper(),
            TextColor3 = acc.color,
            TextSize = 14,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = card
        })
        
        -- Current label
        Utils.create('TextLabel', {
            Size = UDim2.new(0, 50, 0, 16),
            Position = UDim2.new(0, 72, 0, 34),
            BackgroundTransparency = 1,
            Text = 'Current:',
            TextColor3 = T.TextMuted,
            TextSize = 13,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = card
        })
        
        local currLbl = Utils.create('TextLabel', {
            Size = UDim2.new(0, 120, 0, 16),
            Position = UDim2.new(0, 122, 0, 34),
            BackgroundTransparency = 1,
            Text = 'Loading...',
            TextColor3 = T.TextDim,
            TextSize = 13,
            Font = Enum.Font.GothamMedium,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = card
        })
        Config.UI.AccessoryLabels[acc.name] = currLbl
        
        -- Target label
        Utils.create('TextLabel', {
            Size = UDim2.new(0, 50, 0, 16),
            Position = UDim2.new(0, 72, 0, 52),
            BackgroundTransparency = 1,
            Text = 'Target:',
            TextColor3 = T.TextMuted,
            TextSize = 13,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = card
        })
        
        Utils.create('TextLabel', {
            Size = UDim2.new(0, 140, 0, 16),
            Position = UDim2.new(0, 122, 0, 52),
            BackgroundTransparency = 1,
            Text = '🎯 ' .. acc.target,
            TextColor3 = T.Success,
            TextSize = 13,
            Font = Enum.Font.GothamMedium,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = card
        })
        
        -- Progress bar
        local progBg = Utils.create('Frame', {
            Size = UDim2.new(0, 120, 0, 6),
            Position = UDim2.new(0, 72, 0, 74),
            BackgroundColor3 = T.CardHover,
            BorderSizePixel = 0,
            Parent = card
        })
        Utils.addCorner(progBg, 3)
        
        local progFill = Utils.create('Frame', {
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundColor3 = acc.color,
            BorderSizePixel = 0,
            Parent = progBg
        })
        Utils.addCorner(progFill, 3)
        
        -- Roll button
        local isActive = Config.Toggles.accessoryRollLoops[acc.name]
        local rollBtn = Utils.create('TextButton', {
            Size = UDim2.new(0, 80, 0, 36),
            Position = UDim2.new(1, -90, 0.5, -18),
            BackgroundColor3 = isActive and T.Success or acc.color,
            BorderSizePixel = 0,
            Text = isActive and '⏹ Stop' or '🎲 Roll',
            TextColor3 = Color3.new(1, 1, 1),
            TextSize = 13,
            Font = Enum.Font.GothamBold,
            Parent = card
        })
        Utils.addCorner(rollBtn, 8)
        
        local accName = acc.name
        local accColor = acc.color
        
        rollBtn.MouseButton1Click:Connect(function()
            local nowActive = not Config.Toggles.accessoryRollLoops[accName]
            
            if NM.Features.accessories then
                NM.Features.accessories.setLoop(accName, nowActive)
            end
            
            rollBtn.BackgroundColor3 = nowActive and T.Success or accColor
            rollBtn.Text = nowActive and '⏹ Stop' or '🎲 Roll'
            
            if not nowActive then
                TS:Create(progFill, TweenInfo.new(0.2), { Size = UDim2.new(0, 0, 1, 0) }):Play()
            end
        end)
        
        yOffset = yOffset + 108
    end
    
    panel.CanvasSize = UDim2.new(0, 0, 0, yOffset)
end

function ItemsTab.onShow()
    if NM.Features.accessories then
        NM.Features.accessories.updateLabels()
    end
end

return ItemsTab
