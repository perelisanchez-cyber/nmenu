--[[
    ============================================================================
    nigMenu - UI Framework
    ============================================================================
    
    Contains:
    - Main window creation
    - Tab system
    - Navigation
    - Intro animation
    - Visual effects (blur, darkness)
]]

local UI = {}

-- Get references
local NM = _G.nigMenu
local Config = NM.Config
local Utils = NM.Utils

local T = Config.Theme
local TS = Config.Services.TweenService
local UIS = Config.Services.UserInputService
local CoreGui = Config.Services.CoreGui
local Lighting = Config.Services.Lighting

-- ============================================================================
-- LOCAL REFERENCES
-- ============================================================================

local blurEffect
local darknessOverlay

-- ============================================================================
-- INTRO ANIMATION
-- ============================================================================

local function playIntroAnimation()
    task.spawn(function()
        local introGui = Utils.create('ScreenGui', {
            Name = 'nigMenuIntro',
            ResetOnSpawn = false,
            IgnoreGuiInset = true,
            DisplayOrder = 999,
            Parent = CoreGui
        })
        
        local base = Utils.create('Frame', {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Color3.fromRGB(18, 18, 24),
            BorderSizePixel = 0,
            Parent = introGui
        })
        
        local center = Utils.create('Frame', {
            Size = UDim2.new(0, 400, 0, 150),
            Position = UDim2.new(0.5, -200, 0.5, -75),
            BackgroundTransparency = 1,
            Parent = base
        })
        
        local line = Utils.create('Frame', {
            Size = UDim2.new(0, 0, 0, 2),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = T.Accent,
            BorderSizePixel = 0,
            Parent = center
        })
        
        local mainText = Utils.create('TextLabel', {
            Size = UDim2.new(1, 0, 0, 50),
            Position = UDim2.new(0, 0, 0.5, -25),
            BackgroundTransparency = 1,
            Text = 'nigMenu',
            TextColor3 = T.Text,
            TextSize = 42,
            TextTransparency = 1,
            Font = Enum.Font.GothamBold,
            Parent = center
        })
        
        local subText = Utils.create('TextLabel', {
            Size = UDim2.new(1, 0, 0, 20),
            Position = UDim2.new(0, 0, 0.5, 30),
            BackgroundTransparency = 1,
            Text = 'by nig',
            TextColor3 = T.TextDim,
            TextSize = 14,
            TextTransparency = 1,
            Font = Enum.Font.Gotham,
            Parent = center
        })
        
        -- Animate in
        TS:Create(line, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {
            Size = UDim2.new(0, 250, 0, 2)
        }):Play()
        
        task.wait(0.2)
        TS:Create(mainText, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
        
        task.wait(0.2)
        TS:Create(subText, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
        
        task.wait(1)
        
        -- Animate out
        TS:Create(line, TweenInfo.new(0.2), { Size = UDim2.new(0, 0, 0, 2) }):Play()
        TS:Create(mainText, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
        TS:Create(subText, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
        
        task.wait(0.3)
        TS:Create(base, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
        
        task.wait(0.25)
        introGui:Destroy()
    end)
end

-- ============================================================================
-- EFFECTS
-- ============================================================================

function UI.updateEffects()
    if blurEffect then
        blurEffect.Size = Config.UI.MainFrame.Visible and Config.State.blurAmount or 0
    end
    
    if darknessOverlay then
        local transparency = Config.UI.MainFrame.Visible 
            and (1 - (Config.State.darknessAmount / 100) * 0.85) 
            or 1
        darknessOverlay.BackgroundTransparency = transparency
    end
end

-- ============================================================================
-- NAVIGATION
-- ============================================================================

local function createNavButton(name, icon, order, parent)
    local btn = Utils.create('TextButton', {
        Name = name,
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
        Text = '',
        LayoutOrder = order,
        Parent = parent
    })
    Utils.addCorner(btn, 6)
    
    local iconLabel = Utils.create('TextLabel', {
        Size = UDim2.new(0, 30, 1, 0),
        Position = UDim2.new(0, 4, 0, 0),
        BackgroundTransparency = 1,
        Text = icon,
        TextSize = 16,
        Font = Enum.Font.GothamMedium,
        TextColor3 = T.TextDim,
        Parent = btn
    })
    
    local textLabel = Utils.create('TextLabel', {
        Size = UDim2.new(1, -38, 1, 0),
        Position = UDim2.new(0, 34, 0, 0),
        BackgroundTransparency = 1,
        Text = name,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        TextColor3 = T.TextDim,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = btn
    })
    
    local indicator = Utils.create('Frame', {
        Size = UDim2.new(0, 3, 0, 20),
        Position = UDim2.new(0, 0, 0.5, -10),
        BackgroundColor3 = T.Accent,
        BorderSizePixel = 0,
        Visible = false,
        Parent = btn
    })
    Utils.addCorner(indicator, 2)
    
    Config.UI.TabButtons[name] = {
        button = btn,
        icon = iconLabel,
        text = textLabel,
        indicator = indicator
    }
    
    btn.MouseButton1Click:Connect(function()
        UI.switchTab(name)
    end)
    
    return btn
end

local function createContentPanel(name, parent)
    local panel = Utils.create('ScrollingFrame', {
        Name = name .. 'Panel',
        Size = UDim2.new(1, -16, 1, -16),
        Position = UDim2.new(0, 8, 0, 8),
        BackgroundTransparency = 1,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = T.Border,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Visible = false,
        Parent = parent
    })
    
    Config.UI.Tabs[name] = panel
    return panel
end

function UI.switchTab(name)
    if Config.UI.CurrentTab == name then
        return
    end
    
    -- Update button states
    for tabName, elements in pairs(Config.UI.TabButtons) do
        local isActive = tabName == name
        
        elements.indicator.Visible = isActive
        elements.text.TextColor3 = isActive and T.Text or T.TextDim
        elements.icon.TextColor3 = isActive and T.Accent or T.TextDim
        elements.button.BackgroundTransparency = isActive and 0.9 or 1
        elements.button.BackgroundColor3 = T.Accent
    end
    
    -- Show/hide panels
    for tabName, panel in pairs(Config.UI.Tabs) do
        panel.Visible = tabName == name
    end
    
    Config.UI.CurrentTab = name
    
    -- Trigger tab-specific initialization
    -- Tabs are stored by name (e.g., "Auto", "Upgrades")
    local tabModule = NM.Tabs and NM.Tabs[name]
    if tabModule and tabModule.onShow then
        pcall(tabModule.onShow)
    end
end

-- ============================================================================
-- MAIN WINDOW
-- ============================================================================

function UI.createMainWindow()
    -- Destroy existing
    local existing = CoreGui:FindFirstChild('nigMenu')
    if existing then
        existing:Destroy()
    end
    
    -- Play intro
    playIntroAnimation()
    
    -- Create ScreenGui
    local screenGui = Utils.create('ScreenGui', {
        Name = 'nigMenu',
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        Parent = CoreGui
    })
    Config.UI.ScreenGui = screenGui
    
    -- Create blur effect
    blurEffect = Instance.new('BlurEffect', Lighting)
    blurEffect.Name = 'nigMenuBlur'
    blurEffect.Size = 0
    
    -- Create darkness overlay
    darknessOverlay = Utils.create('Frame', {
        Name = 'nigMenuDarkness',
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = -1,
        Parent = screenGui
    })
    
    -- Create main frame
    local mainFrame = Utils.create('Frame', {
        Name = 'Main',
        Size = UDim2.new(0, 750, 0, 480),
        Position = UDim2.new(0.5, -375, 0.5, -240),
        BackgroundColor3 = T.Bg,
        BorderSizePixel = 0,
        Active = true,
        Draggable = true,
        Visible = false,
        Parent = screenGui
    })
    Utils.addCorner(mainFrame, 8)
    Utils.addStroke(mainFrame, T.Border, 1)
    Config.UI.MainFrame = mainFrame
    
    -- Animate in after intro
    task.delay(2, function()
        mainFrame.Visible = true
        mainFrame.Size = UDim2.new(0, 0, 0, 0)
        mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
        
        TS:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 750, 0, 480),
            Position = UDim2.new(0.5, -375, 0.5, -240)
        }):Play()
        
        UI.updateEffects()
    end)
    
    -- ========================================================================
    -- TITLE BAR
    -- ========================================================================
    
    local titleBar = Utils.create('Frame', {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = T.Sidebar,
        BorderSizePixel = 0,
        Parent = mainFrame
    })
    Utils.addCorner(titleBar, 8)
    
    -- Bottom fill for title bar corners
    Utils.create('Frame', {
        Size = UDim2.new(1, 0, 0, 10),
        Position = UDim2.new(0, 0, 1, -10),
        BackgroundColor3 = T.Sidebar,
        BorderSizePixel = 0,
        Parent = titleBar
    })
    
    -- Title text
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 120, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = 'nigMenu',
        TextColor3 = T.Text,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = titleBar
    })
    
    -- Version text
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 40, 1, 0),
        Position = UDim2.new(0, 100, 0, 0),
        BackgroundTransparency = 1,
        Text = 'v' .. Config.Constants.VERSION,
        TextColor3 = T.TextMuted,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = titleBar
    })
    
    -- Coordinate display
    local coordLabel = Utils.create('TextLabel', {
        Size = UDim2.new(0, 200, 0, 20),
        Position = UDim2.new(0.5, -100, 0.5, -10),
        BackgroundTransparency = 1,
        Text = 'X: 0  Y: 0  Z: 0',
        TextColor3 = T.TextDim,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        Parent = titleBar
    })
    Config.UI.CoordLabel = coordLabel
    
    -- Coordinate copy button
    local coordBtn = Utils.create('TextButton', {
        Size = UDim2.new(0, 200, 0, 20),
        Position = UDim2.new(0.5, -100, 0.5, -10),
        BackgroundTransparency = 1,
        Text = '',
        Parent = titleBar
    })
    
    coordBtn.MouseButton1Click:Connect(function()
        pcall(function()
            setclipboard(Config.State.currentCoords)
        end)
    end)
    
    -- Close button
    local closeBtn = Utils.create('TextButton', {
        Size = UDim2.new(0, 36, 0, 36),
        Position = UDim2.new(1, -36, 0, 0),
        BackgroundTransparency = 1,
        Text = '×',
        TextColor3 = T.TextDim,
        TextSize = 24,
        Font = Enum.Font.GothamBold,
        Parent = titleBar
    })
    
    closeBtn.MouseEnter:Connect(function()
        closeBtn.TextColor3 = T.Error
    end)
    closeBtn.MouseLeave:Connect(function()
        closeBtn.TextColor3 = T.TextDim
    end)
    closeBtn.MouseButton1Click:Connect(function()
        Config.State.menuVisible = false
        mainFrame.Visible = false
        UI.updateEffects()
    end)
    
    -- Minimize button
    local minBtn = Utils.create('TextButton', {
        Size = UDim2.new(0, 36, 0, 36),
        Position = UDim2.new(1, -72, 0, 0),
        BackgroundTransparency = 1,
        Text = '−',
        TextColor3 = T.TextDim,
        TextSize = 20,
        Font = Enum.Font.GothamBold,
        Parent = titleBar
    })
    
    minBtn.MouseEnter:Connect(function()
        minBtn.TextColor3 = T.Warning
    end)
    minBtn.MouseLeave:Connect(function()
        minBtn.TextColor3 = T.TextDim
    end)
    minBtn.MouseButton1Click:Connect(function()
        Config.State.menuVisible = false
        mainFrame.Visible = false
        UI.updateEffects()
    end)
    
    -- ========================================================================
    -- SIDEBAR
    -- ========================================================================
    
    local sidebar = Utils.create('Frame', {
        Size = UDim2.new(0, 140, 1, -36),
        Position = UDim2.new(0, 0, 0, 36),
        BackgroundColor3 = T.Sidebar,
        BorderSizePixel = 0,
        Parent = mainFrame
    })
    Utils.addCorner(sidebar, 8)
    
    -- Top fill
    Utils.create('Frame', {
        Size = UDim2.new(1, 0, 0, 10),
        BackgroundColor3 = T.Sidebar,
        BorderSizePixel = 0,
        Parent = sidebar
    })
    
    -- Right fill
    Utils.create('Frame', {
        Size = UDim2.new(0, 10, 1, 0),
        Position = UDim2.new(1, -10, 0, 0),
        BackgroundColor3 = T.Sidebar,
        BorderSizePixel = 0,
        Parent = sidebar
    })
    
    -- Navigation container
    local navContainer = Utils.create('Frame', {
        Size = UDim2.new(1, -16, 1, -56),
        Position = UDim2.new(0, 8, 0, 8),
        BackgroundTransparency = 1,
        Parent = sidebar
    })
    
    Utils.create('UIListLayout', {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 4),
        Parent = navContainer
    })
    
    -- Credit text
    Utils.create('TextLabel', {
        Size = UDim2.new(1, -24, 0, 14),
        Position = UDim2.new(0, 28, 1, -28),
        BackgroundTransparency = 1,
        Text = 'by nig',
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextColor3 = T.Accent,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = sidebar
    })
    
    -- ========================================================================
    -- CONTENT AREA
    -- ========================================================================
    
    local contentArea = Utils.create('Frame', {
        Size = UDim2.new(1, -148, 1, -40),
        Position = UDim2.new(0, 144, 0, 38),
        BackgroundColor3 = T.Content,
        BorderSizePixel = 0,
        Parent = mainFrame
    })
    Utils.addCorner(contentArea, 6)
    
    -- ========================================================================
    -- CREATE TABS
    -- ========================================================================
    
    local tabData = {
        { 'Auto',     '⚡' },
        { 'Upgrades', '⚔' },
        { 'Items',    '🎒' },
        { 'Merger',   '⭐' },
        { 'Bosses',   '💀' },
        { 'ServerHopper', '🔄' },
        { 'Utils',    '🔧' },
        { 'Config',   '⚙' }
    }
    
    for i, data in ipairs(tabData) do
        createNavButton(data[1], data[2], i, navContainer)
        createContentPanel(data[1], contentArea)
    end
    
    -- ========================================================================
    -- KEYBIND HANDLER
    -- ========================================================================
    
    UIS.InputBegan:Connect(function(input, gameProcessed)
        if Config.State.listeningForKeybind and input.UserInputType == Enum.UserInputType.Keyboard then
            Config.State.menuKeybind = input.KeyCode
            Config.State.listeningForKeybind = false
            
            if NM.Settings then
                NM.Settings.save()
            end
            
        elseif not gameProcessed 
            and input.UserInputType == Enum.UserInputType.Keyboard 
            and input.KeyCode == Config.State.menuKeybind 
        then
            Config.State.menuVisible = not Config.State.menuVisible
            mainFrame.Visible = Config.State.menuVisible
            UI.updateEffects()
        end
    end)
    
    -- ========================================================================
    -- CHARACTER RESPAWN HANDLER
    -- ========================================================================
    
    Config.LocalPlayer.CharacterAdded:Connect(function(newChar)
        -- Update character reference if needed
    end)
    
    -- ========================================================================
    -- COORDINATE UPDATE LOOP
    -- ========================================================================
    
    task.spawn(function()
        while Config.State.running do
            local char = Config.LocalPlayer.Character
            local hrp = char and char:FindFirstChild('HumanoidRootPart')
            
            if hrp then
                local pos = hrp.Position
                coordLabel.Text = string.format('X: %.0f  Y: %.0f  Z: %.0f', pos.X, pos.Y, pos.Z)
                Config.State.currentCoords = string.format('%.1f, %.1f, %.1f', pos.X, pos.Y, pos.Z)
            end
            
            task.wait(0.1)
        end
    end)
    
    -- Default to Auto tab
    UI.switchTab('Auto')
end

-- ============================================================================
-- RETURN MODULE
-- ============================================================================

return UI
