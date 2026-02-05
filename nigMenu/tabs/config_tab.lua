--[[
    ============================================================================
    nigMenu - Config Tab UI
    ============================================================================
    
    Creates the UI for menu settings and visual effects
]]

local ConfigTab = {}

local NM = _G.nigMenu
local Config = NM.Config
local Utils = NM.Utils
local T = Config.Theme
local TS = Config.Services.TweenService
local UIS = Config.Services.UserInputService

-- UI references for sliders
local blurDrag, darkDrag = false, false

function ConfigTab.init()
    local panel = Config.UI.Tabs['Config']
    if not panel then return end
    
    local yOffset = 0
    
    -- ========================================================================
    -- SETTINGS CARD
    -- ========================================================================
    
    local settingsCard = Utils.createCard(panel, nil, 180, yOffset)
    
    Utils.createIcon(settingsCard, '⚙️', Color3.fromRGB(150, 150, 200), 40, UDim2.new(0, 12, 0, 10))
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 100, 0, 20),
        Position = UDim2.new(0, 60, 0, 12),
        BackgroundTransparency = 1,
        Text = 'SETTINGS',
        TextColor3 = Color3.fromRGB(150, 150, 200),
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = settingsCard
    })
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 180, 0, 14),
        Position = UDim2.new(0, 60, 0, 32),
        BackgroundTransparency = 1,
        Text = 'Menu configuration',
        TextColor3 = T.TextMuted,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = settingsCard
    })
    
    -- Keybind row
    local keybindRow = Utils.create('Frame', {
        Size = UDim2.new(1, -24, 0, 36),
        Position = UDim2.new(0, 12, 0, 58),
        BackgroundColor3 = T.CardHover,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        Parent = settingsCard
    })
    Utils.addCorner(keybindRow, 6)
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 24, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = '⌨️',
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        Parent = keybindRow
    })
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 120, 1, 0),
        Position = UDim2.new(0, 38, 0, 0),
        BackgroundTransparency = 1,
        Text = 'Menu Toggle Key',
        TextColor3 = T.TextDim,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = keybindRow
    })
    
    local keybindBtn = Utils.create('TextButton', {
        Size = UDim2.new(0, 90, 0, 26),
        Position = UDim2.new(1, -100, 0.5, -13),
        BackgroundColor3 = T.Accent,
        BorderSizePixel = 0,
        Text = Config.State.menuKeybind.Name,
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        Parent = keybindRow
    })
    Utils.addCorner(keybindBtn, 6)
    
    keybindBtn.MouseButton1Click:Connect(function()
        keybindBtn.Text = '...'
        keybindBtn.BackgroundColor3 = T.Accent
        Config.State.listeningForKeybind = true
        
        -- Wait for key press
        local connection
        connection = UIS.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Keyboard then
                Config.State.menuKeybind = input.KeyCode
                keybindBtn.Text = input.KeyCode.Name
                keybindBtn.BackgroundColor3 = T.CardHover
                Config.State.listeningForKeybind = false
                
                if NM.Settings then
                    NM.Settings.save()
                end
                
                connection:Disconnect()
            end
        end)
    end)
    
    -- Debug row
    local debugRow = Utils.create('Frame', {
        Size = UDim2.new(1, -24, 0, 36),
        Position = UDim2.new(0, 12, 0, 100),
        BackgroundColor3 = T.CardHover,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        Parent = settingsCard
    })
    Utils.addCorner(debugRow, 6)
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 24, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = '🐛',
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        Parent = debugRow
    })
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 100, 1, 0),
        Position = UDim2.new(0, 38, 0, 0),
        BackgroundTransparency = 1,
        Text = 'Debug Mode',
        TextColor3 = T.TextDim,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = debugRow
    })
    
    local debugToggleBg = Utils.create('Frame', {
        Size = UDim2.new(0, 50, 0, 26),
        Position = UDim2.new(1, -60, 0.5, -13),
        BackgroundColor3 = Config.State.debugMode and T.Success or T.CardHover,
        BorderSizePixel = 0,
        Parent = debugRow
    })
    Utils.addCorner(debugToggleBg, 13)
    
    local debugToggleCircle = Utils.create('Frame', {
        Size = UDim2.new(0, 22, 0, 22),
        Position = Config.State.debugMode and UDim2.new(1, -24, 0.5, -11) or UDim2.new(0, 2, 0.5, -11),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Parent = debugToggleBg
    })
    Utils.addCorner(debugToggleCircle, 11)
    
    local debugToggleBtn = Utils.create('TextButton', {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = '',
        Parent = debugRow
    })
    
    debugToggleBtn.MouseButton1Click:Connect(function()
        Config.State.debugMode = not Config.State.debugMode
        
        TS:Create(debugToggleBg, TweenInfo.new(0.2), {
            BackgroundColor3 = Config.State.debugMode and T.Success or T.CardHover
        }):Play()
        
        TS:Create(debugToggleCircle, TweenInfo.new(0.2), {
            Position = Config.State.debugMode and UDim2.new(1, -24, 0.5, -11) or UDim2.new(0, 2, 0.5, -11)
        }):Play()
        
        if NM.Settings then
            NM.Settings.save()
        end
    end)
    
    -- Wave auto-leave row
    local waveRow = Utils.create('Frame', {
        Size = UDim2.new(1, -24, 0, 36),
        Position = UDim2.new(0, 12, 0, 142),
        BackgroundColor3 = T.CardHover,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        Parent = settingsCard
    })
    Utils.addCorner(waveRow, 6)
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 24, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = '🌊',
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        Parent = waveRow
    })
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 130, 1, 0),
        Position = UDim2.new(0, 38, 0, 0),
        BackgroundTransparency = 1,
        Text = 'Auto-Leave at Wave',
        TextColor3 = T.TextDim,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = waveRow
    })
    
    local waveInputBg = Utils.create('Frame', {
        Size = UDim2.new(0, 70, 0, 26),
        Position = UDim2.new(1, -80, 0.5, -13),
        BackgroundColor3 = T.Card,
        BorderSizePixel = 0,
        Parent = waveRow
    })
    Utils.addCorner(waveInputBg, 6)
    Utils.addStroke(waveInputBg, T.Accent, 1)
    
    local waveInput = Utils.create('TextBox', {
        Size = UDim2.new(1, -10, 1, 0),
        Position = UDim2.new(0, 5, 0, 0),
        BackgroundTransparency = 1,
        Text = tostring(Config.Constants.AUTO_LEAVE_WAVE),
        TextColor3 = T.Accent,
        PlaceholderText = '501',
        PlaceholderColor3 = T.TextMuted,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        ClearTextOnFocus = false,
        Parent = waveInputBg
    })
    
    waveInput.FocusLost:Connect(function()
        local num = tonumber(waveInput.Text)
        if num and num > 0 then
            Config.Constants.AUTO_LEAVE_WAVE = math.floor(num)
            waveInput.Text = tostring(Config.Constants.AUTO_LEAVE_WAVE)
            
            if NM.Settings then
                NM.Settings.save()
            end
        else
            waveInput.Text = tostring(Config.Constants.AUTO_LEAVE_WAVE)
        end
    end)
    
    yOffset = yOffset + 188
    
    -- ========================================================================
    -- EFFECTS CARD
    -- ========================================================================
    
    local effectsCard = Utils.createCard(panel, nil, 170, yOffset)
    
    Utils.createIcon(effectsCard, '✨', Color3.fromRGB(100, 180, 255), 40, UDim2.new(0, 12, 0, 10))
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 100, 0, 20),
        Position = UDim2.new(0, 60, 0, 12),
        BackgroundTransparency = 1,
        Text = 'UI EFFECTS',
        TextColor3 = Color3.fromRGB(100, 180, 255),
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = effectsCard
    })
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 180, 0, 14),
        Position = UDim2.new(0, 60, 0, 32),
        BackgroundTransparency = 1,
        Text = 'Visual customization',
        TextColor3 = T.TextMuted,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = effectsCard
    })
    
    -- Blur slider
    local blurRow = Utils.create('Frame', {
        Size = UDim2.new(1, -24, 0, 50),
        Position = UDim2.new(0, 12, 0, 56),
        BackgroundTransparency = 1,
        Parent = effectsCard
    })
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 24, 0, 20),
        BackgroundTransparency = 1,
        Text = '🔵',
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        Parent = blurRow
    })
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 100, 0, 20),
        Position = UDim2.new(0, 26, 0, 0),
        BackgroundTransparency = 1,
        Text = 'Background Blur',
        TextColor3 = T.TextDim,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = blurRow
    })
    
    local blurValLbl = Utils.create('TextLabel', {
        Size = UDim2.new(0, 30, 0, 20),
        Position = UDim2.new(1, -30, 0, 0),
        BackgroundTransparency = 1,
        Text = tostring(Config.State.blurAmount),
        TextColor3 = T.Accent,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = blurRow
    })
    
    local blurBg = Utils.create('Frame', {
        Size = UDim2.new(1, 0, 0, 10),
        Position = UDim2.new(0, 0, 0, 26),
        BackgroundColor3 = T.CardHover,
        BorderSizePixel = 0,
        Parent = blurRow
    })
    Utils.addCorner(blurBg, 5)
    
    local blurFill = Utils.create('Frame', {
        Size = UDim2.new(Config.State.blurAmount / 24, 0, 1, 0),
        BackgroundColor3 = T.Accent,
        BorderSizePixel = 0,
        Parent = blurBg
    })
    Utils.addCorner(blurFill, 5)
    
    local blurKnob = Utils.create('Frame', {
        Size = UDim2.new(0, 18, 0, 18),
        Position = UDim2.new(Config.State.blurAmount / 24, -9, 0.5, -9),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Parent = blurBg
    })
    Utils.addCorner(blurKnob, 9)
    Utils.addStroke(blurKnob, T.Accent, 2)
    
    local blurSliderBtn = Utils.create('TextButton', {
        Size = UDim2.new(1, 20, 1, 20),
        Position = UDim2.new(0, -10, 0, -10),
        BackgroundTransparency = 1,
        Text = '',
        Parent = blurBg
    })
    
    -- Darkness slider
    local darkRow = Utils.create('Frame', {
        Size = UDim2.new(1, -24, 0, 50),
        Position = UDim2.new(0, 12, 0, 110),
        BackgroundTransparency = 1,
        Parent = effectsCard
    })
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 24, 0, 20),
        BackgroundTransparency = 1,
        Text = '⬛',
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        Parent = darkRow
    })
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 120, 0, 20),
        Position = UDim2.new(0, 26, 0, 0),
        BackgroundTransparency = 1,
        Text = 'Background Darkness',
        TextColor3 = T.TextDim,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = darkRow
    })
    
    local darkValLbl = Utils.create('TextLabel', {
        Size = UDim2.new(0, 35, 0, 20),
        Position = UDim2.new(1, -35, 0, 0),
        BackgroundTransparency = 1,
        Text = Config.State.darknessAmount .. '%',
        TextColor3 = T.Accent,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = darkRow
    })
    
    local darkBg = Utils.create('Frame', {
        Size = UDim2.new(1, 0, 0, 10),
        Position = UDim2.new(0, 0, 0, 26),
        BackgroundColor3 = T.CardHover,
        BorderSizePixel = 0,
        Parent = darkRow
    })
    Utils.addCorner(darkBg, 5)
    
    local darkFill = Utils.create('Frame', {
        Size = UDim2.new(Config.State.darknessAmount / 100, 0, 1, 0),
        BackgroundColor3 = T.Accent,
        BorderSizePixel = 0,
        Parent = darkBg
    })
    Utils.addCorner(darkFill, 5)
    
    local darkKnob = Utils.create('Frame', {
        Size = UDim2.new(0, 18, 0, 18),
        Position = UDim2.new(Config.State.darknessAmount / 100, -9, 0.5, -9),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Parent = darkBg
    })
    Utils.addCorner(darkKnob, 9)
    Utils.addStroke(darkKnob, T.Accent, 2)
    
    local darkSliderBtn = Utils.create('TextButton', {
        Size = UDim2.new(1, 20, 1, 20),
        Position = UDim2.new(0, -10, 0, -10),
        BackgroundTransparency = 1,
        Text = '',
        Parent = darkBg
    })
    
    -- Slider drag handlers
    blurSliderBtn.MouseButton1Down:Connect(function()
        blurDrag = true
    end)
    
    darkSliderBtn.MouseButton1Down:Connect(function()
        darkDrag = true
    end)
    
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            blurDrag = false
            darkDrag = false
        end
    end)
    
    UIS.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            if blurDrag then
                local rel = math.clamp(
                    (input.Position.X - blurBg.AbsolutePosition.X) / blurBg.AbsoluteSize.X,
                    0, 1
                )
                
                Config.State.blurAmount = math.floor(rel * 24)
                blurValLbl.Text = tostring(Config.State.blurAmount)
                blurFill.Size = UDim2.new(rel, 0, 1, 0)
                blurKnob.Position = UDim2.new(rel, -9, 0.5, -9)
                
                if NM.UI and NM.UI.updateEffects then
                    NM.UI.updateEffects()
                end
                
                if NM.Settings then
                    NM.Settings.save()
                end
            end
            
            if darkDrag then
                local rel = math.clamp(
                    (input.Position.X - darkBg.AbsolutePosition.X) / darkBg.AbsoluteSize.X,
                    0, 1
                )
                
                Config.State.darknessAmount = math.floor(rel * 100)
                darkValLbl.Text = Config.State.darknessAmount .. '%'
                darkFill.Size = UDim2.new(rel, 0, 1, 0)
                darkKnob.Position = UDim2.new(rel, -9, 0.5, -9)
                
                if NM.UI and NM.UI.updateEffects then
                    NM.UI.updateEffects()
                end
                
                if NM.Settings then
                    NM.Settings.save()
                end
            end
        end
    end)
    
    yOffset = yOffset + 178
    
    panel.CanvasSize = UDim2.new(0, 0, 0, yOffset)
end

function ConfigTab.onShow()
    -- Nothing special needed
end

return ConfigTab
