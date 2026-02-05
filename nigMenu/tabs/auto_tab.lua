--[[
    ============================================================================
    nigMenu - Auto Tab UI
    ============================================================================
    
    Creates the UI for:
    - Raid controls
    - Auto roll controls
]]

local AutoTab = {}

-- Get references
local NM = _G.nigMenu
local Config = NM.Config
local Utils = NM.Utils

local T = Config.Theme
local TS = Config.Services.TweenService

-- UI element storage
local raidButtons = {}
local autoRollToggles = {}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function AutoTab.init()
    local panel = Config.UI.Tabs['Auto']
    if not panel then return end
    
    local yOffset = 0
    
    -- ========================================================================
    -- RAIDS CARD
    -- ========================================================================
    
    local raidsCard = Utils.createCard(panel, nil, 210, yOffset)
    
    -- Icon
    Utils.createIcon(raidsCard, '⚔️', Color3.fromRGB(255, 80, 80), 40, UDim2.new(0, 12, 0, 10))
    
    -- Title
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 100, 0, 20),
        Position = UDim2.new(0, 60, 0, 12),
        BackgroundTransparency = 1,
        Text = 'RAIDS',
        TextColor3 = Color3.fromRGB(255, 80, 80),
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = raidsCard
    })
    
    -- Subtitle
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 180, 0, 14),
        Position = UDim2.new(0, 60, 0, 32),
        BackgroundTransparency = 1,
        Text = 'Join, leave, or loop raids',
        TextColor3 = T.TextMuted,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = raidsCard
    })
    
    -- Create raid rows
    for i, raidData in ipairs(Config.Constants.RAIDS) do
        local rowY = 56 + (i - 1) * 30
        
        local row = Utils.create('Frame', {
            Size = UDim2.new(1, -24, 0, 26),
            Position = UDim2.new(0, 12, 0, rowY),
            BackgroundColor3 = T.CardHover,
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0,
            Parent = raidsCard
        })
        Utils.addCorner(row, 4)
        
        -- Color dot
        local dot = Utils.create('Frame', {
            Size = UDim2.new(0, 8, 0, 8),
            Position = UDim2.new(0, 8, 0.5, -4),
            BackgroundColor3 = raidData.color,
            BorderSizePixel = 0,
            Parent = row
        })
        Utils.addCorner(dot, 4)
        
        -- Raid name
        Utils.create('TextLabel', {
            Size = UDim2.new(0, 80, 1, 0),
            Position = UDim2.new(0, 22, 0, 0),
            BackgroundTransparency = 1,
            Text = raidData.display,
            TextColor3 = T.Text,
            TextSize = 13,
            Font = Enum.Font.GothamMedium,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row
        })
        
        -- Buttons
        local raidName = raidData.name
        
        local joinBtn = Utils.createSmallButton(row, '▶ Join', -130, 2, 55, T.Success)
        local leaveBtn = Utils.createSmallButton(row, '✕ Leave', -70, 2, 55, T.Error)
        local loopBtn = Utils.createSmallButton(row, '🔄', -10, 2, 30, T.CardHover)
        
        -- Store references
        raidButtons[raidName] = {
            join = joinBtn,
            leave = leaveBtn,
            loop = loopBtn
        }
        
        -- Connect events
        joinBtn.MouseButton1Click:Connect(function()
            if NM.Features.raids then
                NM.Features.raids.join(raidName)
            end
        end)
        
        leaveBtn.MouseButton1Click:Connect(function()
            if NM.Features.raids then
                NM.Features.raids.leave(raidName)
            end
        end)
        
        loopBtn.MouseButton1Click:Connect(function()
            local isActive = not Config.Toggles.raidLoops[raidName]
            
            if NM.Features.raids then
                NM.Features.raids.setLoop(raidName, isActive)
            end
            
            loopBtn.BackgroundColor3 = isActive and T.Success or T.CardHover
            loopBtn.Text = isActive and 'STOP' or '🔄'
        end)
        
        -- Set initial state
        if Config.Toggles.raidLoops[raidName] then
            loopBtn.BackgroundColor3 = T.Success
            loopBtn.Text = 'STOP'
        end
    end
    
    yOffset = yOffset + 218
    
    -- ========================================================================
    -- AUTO ROLL CARD
    -- ========================================================================
    
    local autoRollCard = Utils.createCard(panel, nil, 220, yOffset)
    
    -- Icon
    Utils.createIcon(autoRollCard, '🎲', Color3.fromRGB(100, 200, 255), 40, UDim2.new(0, 12, 0, 10))
    
    -- Title
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 100, 0, 20),
        Position = UDim2.new(0, 60, 0, 12),
        BackgroundTransparency = 1,
        Text = 'AUTO ROLL',
        TextColor3 = Color3.fromRGB(100, 200, 255),
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = autoRollCard
    })
    
    -- Subtitle
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 120, 0, 14),
        Position = UDim2.new(0, 60, 0, 32),
        BackgroundTransparency = 1,
        Text = 'Auto-roll eggs on maps',
        TextColor3 = T.TextMuted,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = autoRollCard
    })
    
    -- Premium toggle
    local premiumToggleBg = Utils.create('Frame', {
        Size = UDim2.new(0, 90, 0, 26),
        Position = UDim2.new(1, -100, 0, 14),
        BackgroundColor3 = T.CardHover,
        BorderSizePixel = 0,
        Parent = autoRollCard
    })
    Utils.addCorner(premiumToggleBg, 6)
    Utils.addStroke(premiumToggleBg, T.Warning, 1)
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 20, 1, 0),
        Position = UDim2.new(0, 6, 0, 0),
        BackgroundTransparency = 1,
        Text = '⭐',
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        Parent = premiumToggleBg
    })
    
    local premiumLabel = Utils.create('TextLabel', {
        Size = UDim2.new(0, 55, 1, 0),
        Position = UDim2.new(0, 26, 0, 0),
        BackgroundTransparency = 1,
        Text = 'Premium',
        TextColor3 = T.TextDim,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = premiumToggleBg
    })
    
    local premiumToggleBtn = Utils.create('TextButton', {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = '',
        Parent = premiumToggleBg
    })
    
    premiumToggleBtn.MouseButton1Click:Connect(function()
        Config.State.usePremiumRolls = not Config.State.usePremiumRolls
        
        if Config.State.usePremiumRolls then
            Utils.tween(premiumToggleBg, 0.2, { BackgroundColor3 = T.Warning })
            premiumLabel.TextColor3 = Color3.new(1, 1, 1)
            premiumLabel.Text = 'Premium ✓'
        else
            Utils.tween(premiumToggleBg, 0.2, { BackgroundColor3 = T.CardHover })
            premiumLabel.TextColor3 = T.TextDim
            premiumLabel.Text = 'Premium'
        end
    end)
    
    -- Map list scroll
    local autoRollScroll = Utils.create('ScrollingFrame', {
        Size = UDim2.new(1, -16, 1, -60),
        Position = UDim2.new(0, 8, 0, 56),
        BackgroundTransparency = 1,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = T.Border,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Parent = autoRollCard
    })
    Config.UI.AutoRollScroll = autoRollScroll
    
    -- Get all maps and create rows
    local allMaps = Utils.getAllMaps()
    autoRollScroll.CanvasSize = UDim2.new(0, 0, 0, #allMaps * 32)
    
    for i, mapName in ipairs(allMaps) do
        -- Initialize toggle state
        if Config.Toggles.autoRollLoops[mapName] == nil then
            Config.Toggles.autoRollLoops[mapName] = false
        end
        
        local rowY = (i - 1) * 32
        
        local row = Utils.create('Frame', {
            Size = UDim2.new(1, -8, 0, 28),
            Position = UDim2.new(0, 0, 0, rowY),
            BackgroundColor3 = T.CardHover,
            BackgroundTransparency = 0.7,
            BorderSizePixel = 0,
            Parent = autoRollScroll
        })
        Utils.addCorner(row, 4)
        
        Utils.create('TextLabel', {
            Size = UDim2.new(1, -80, 1, 0),
            Position = UDim2.new(0, 8, 0, 0),
            BackgroundTransparency = 1,
            Text = '🗺️ ' .. mapName,
            TextColor3 = T.TextDim,
            TextSize = 13,
            Font = Enum.Font.GothamMedium,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = row
        })
        
        local toggleBtn = Utils.create('TextButton', {
            Size = UDim2.new(0, 65, 0, 22),
            Position = UDim2.new(1, -70, 0, 3),
            BackgroundColor3 = Config.Toggles.autoRollLoops[mapName] and T.Success or T.Accent,
            BorderSizePixel = 0,
            Text = Config.Toggles.autoRollLoops[mapName] and '⏹ Stop' or '▶ Start',
            TextColor3 = Color3.new(1, 1, 1),
            TextSize = 13,
            Font = Enum.Font.GothamBold,
            Parent = row
        })
        Utils.addCorner(toggleBtn, 4)
        
        autoRollToggles[mapName] = toggleBtn
        
        toggleBtn.MouseButton1Click:Connect(function()
            local isActive = not Config.Toggles.autoRollLoops[mapName]
            
            if NM.Features.autoroll then
                NM.Features.autoroll.setLoop(mapName, isActive)
            end
            
            Utils.tween(toggleBtn, 0.2, {
                BackgroundColor3 = isActive and T.Success or T.Accent
            })
            toggleBtn.Text = isActive and '⏹ Stop' or '▶ Start'
        end)
    end
    
    yOffset = yOffset + 228
    
    -- Set canvas size
    panel.CanvasSize = UDim2.new(0, 0, 0, yOffset)
end

-- ============================================================================
-- TAB SHOWN CALLBACK
-- ============================================================================

function AutoTab.onShow()
    -- Refresh any dynamic content when tab is shown
end

-- ============================================================================
-- RETURN MODULE
-- ============================================================================

return AutoTab
