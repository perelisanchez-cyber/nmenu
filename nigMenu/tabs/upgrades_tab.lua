--[[
    ============================================================================
    nigMenu - Upgrades Tab UI
    ============================================================================
    
    Creates the UI for:
    - Generals upgrades
    - Sword enchanting
    - Sword splitting
]]

local UpgradesTab = {}

-- Lazy load references
local function getNM() return _G.nigMenu end
local function getConfig() return _G.nigMenu and _G.nigMenu.Config end
local function getUtils() return _G.nigMenu and _G.nigMenu.Utils end

-- Loading state
local isLoading = false
local hasLoaded = false
local loadingOverlay, loadingSpinner

-- ============================================================================
-- LOADING OVERLAY
-- ============================================================================

local function showLoading(panel)
    if loadingOverlay then return end
    
    local Utils = getUtils()
    local Config = getConfig()
    if not Utils or not Config then return end
    
    local T = Config.Theme
    
    loadingOverlay = Utils.create('Frame', {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = T.Bg,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        ZIndex = 10,
        Parent = panel
    })
    
    loadingSpinner = Utils.create('TextLabel', {
        Size = UDim2.new(1, 0, 0, 40),
        Position = UDim2.new(0, 0, 0.5, -20),
        BackgroundTransparency = 1,
        Text = '◐ Loading...',
        TextColor3 = T.Accent,
        TextSize = 18,
        Font = Enum.Font.GothamBold,
        ZIndex = 11,
        Parent = loadingOverlay
    })
    
    task.spawn(function()
        local chars = { '◐', '◓', '◑', '◒' }
        local i = 1
        while isLoading and loadingSpinner and loadingSpinner.Parent do
            loadingSpinner.Text = chars[i] .. ' Loading...'
            i = (i % 4) + 1
            task.wait(0.1)
        end
    end)
end

local function hideLoading()
    isLoading = false
    if loadingOverlay then
        loadingOverlay:Destroy()
        loadingOverlay = nil
        loadingSpinner = nil
    end
end

-- ============================================================================
-- BUILD SECTIONS
-- ============================================================================

local function buildGeneralsSection(parent, yOffset)
    local Utils = getUtils()
    local Config = getConfig()
    if not Utils or not Config then return nil, 0 end
    
    local T = Config.Theme
    local card = Utils.createCard(parent, nil, 200, yOffset)
    
    Utils.createIcon(card, '⚔️', Color3.fromRGB(255, 180, 60), 40, UDim2.new(0, 12, 0, 10))
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 150, 0, 20),
        Position = UDim2.new(0, 60, 0, 12),
        BackgroundTransparency = 1,
        Text = 'GENERALS',
        TextColor3 = Color3.fromRGB(255, 180, 60),
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card
    })
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 150, 0, 14),
        Position = UDim2.new(0, 60, 0, 32),
        BackgroundTransparency = 1,
        Text = 'Auto-upgrade your generals',
        TextColor3 = T.TextMuted,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card
    })
    
    local scroll = Utils.create('ScrollingFrame', {
        Size = UDim2.new(1, -16, 1, -60),
        Position = UDim2.new(0, 8, 0, 56),
        BackgroundTransparency = 1,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = T.Border,
        CanvasSize = UDim2.new(0, 0, 0, 10),
        Parent = card
    })
    Config.UI.GeneralsScroll = scroll
    
    return card, 208
end

local function buildSwordsSection(parent, yOffset)
    local Utils = getUtils()
    local Config = getConfig()
    if not Utils or not Config then return nil, 0 end
    
    local T = Config.Theme
    local card = Utils.createCard(parent, nil, 220, yOffset)
    
    Utils.createIcon(card, '🗡️', Color3.fromRGB(100, 180, 255), 40, UDim2.new(0, 12, 0, 10))
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 150, 0, 20),
        Position = UDim2.new(0, 60, 0, 12),
        BackgroundTransparency = 1,
        Text = 'SWORD ENCHANTS',
        TextColor3 = Color3.fromRGB(100, 180, 255),
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card
    })
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 180, 0, 14),
        Position = UDim2.new(0, 60, 0, 32),
        BackgroundTransparency = 1,
        Text = 'Enchant swords automatically',
        TextColor3 = T.TextMuted,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card
    })
    
    local scroll = Utils.create('ScrollingFrame', {
        Size = UDim2.new(1, -16, 1, -60),
        Position = UDim2.new(0, 8, 0, 56),
        BackgroundTransparency = 1,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = T.Border,
        CanvasSize = UDim2.new(0, 0, 0, 10),
        Parent = card
    })
    Config.UI.SwordsScroll = scroll
    
    return card, 228
end

local function buildSplitterSection(parent, yOffset)
    local Utils = getUtils()
    local Config = getConfig()
    if not Utils or not Config then return nil, 0 end
    
    local T = Config.Theme
    local card = Utils.createCard(parent, nil, 220, yOffset)
    
    Utils.createIcon(card, '✂️', Color3.fromRGB(255, 100, 100), 40, UDim2.new(0, 12, 0, 10))
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 150, 0, 20),
        Position = UDim2.new(0, 60, 0, 12),
        BackgroundTransparency = 1,
        Text = 'SWORD SPLITTER',
        TextColor3 = Color3.fromRGB(255, 100, 100),
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card
    })
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 180, 0, 14),
        Position = UDim2.new(0, 60, 0, 32),
        BackgroundTransparency = 1,
        Text = 'Split swords for dust',
        TextColor3 = T.TextMuted,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card
    })
    
    local scroll = Utils.create('ScrollingFrame', {
        Size = UDim2.new(1, -16, 1, -60),
        Position = UDim2.new(0, 8, 0, 56),
        BackgroundTransparency = 1,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = T.Border,
        CanvasSize = UDim2.new(0, 0, 0, 10),
        Parent = card
    })
    Config.UI.SplitterScroll = scroll
    
    return card, 228
end

-- ============================================================================
-- POPULATE FUNCTIONS
-- ============================================================================

local function populateGenerals()
    local Config = getConfig()
    local Utils = getUtils()
    local NM = getNM()
    
    if not Config or not Utils then 
        print("[nigMenu] populateGenerals: Config or Utils missing")
        return 
    end
    
    local scroll = Config.UI.GeneralsScroll
    if not scroll then 
        print("[nigMenu] populateGenerals: GeneralsScroll not found")
        return 
    end
    
    local T = Config.Theme
    
    -- Clear existing
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA('Frame') or child:IsA('TextLabel') then
            child:Destroy()
        end
    end
    
    local generals = {}
    if NM and NM.Features and NM.Features.generals then
        generals = NM.Features.generals.getAll()
        print("[nigMenu] populateGenerals: Got " .. #generals .. " generals")
    else
        print("[nigMenu] populateGenerals: generals feature not loaded")
    end
    
    if #generals == 0 then
        Utils.create('TextLabel', {
            Size = UDim2.new(1, -16, 0, 100),
            Position = UDim2.new(0, 8, 0, 0),
            BackgroundTransparency = 1,
            Text = 'No generals found\n\nMake sure you have generals\nin this game.',
            TextColor3 = T.TextMuted,
            TextSize = 13,
            Font = Enum.Font.Gotham,
            TextWrapped = true,
            Parent = scroll
        })
        return
    end
    
    scroll.CanvasSize = UDim2.new(0, 0, 0, #generals * 28)
    
    for i, general in ipairs(generals) do
        local row = Utils.create('Frame', {
            Size = UDim2.new(1, -8, 0, 26),
            Position = UDim2.new(0, 0, 0, (i - 1) * 28),
            BackgroundTransparency = 1,
            Parent = scroll
        })
        
        Utils.create('TextLabel', {
            Size = UDim2.new(1, -80, 1, 0),
            BackgroundTransparency = 1,
            Text = general.name .. ' (Lv.' .. general.level .. ')',
            TextColor3 = T.TextDim,
            TextSize = 13,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row
        })
        
        local isActive = Config.Toggles.generalUpgradeLoops[general.uuid]
        local btn = Utils.createSmallButton(row, isActive and 'Stop' or 'Loop', -10, 2, 70, isActive and T.Success or T.CardHover)
        
        local uuid = general.uuid
        btn.MouseButton1Click:Connect(function()
            local nowActive = not Config.Toggles.generalUpgradeLoops[uuid]
            if NM.Features.generals then
                NM.Features.generals.setLoop(uuid, nowActive)
            end
            btn.BackgroundColor3 = nowActive and T.Success or T.CardHover
            btn.Text = nowActive and 'Stop' or 'Loop'
        end)
    end
end

local function populateSwords()
    local Config = getConfig()
    local Utils = getUtils()
    local NM = getNM()
    
    if not Config or not Utils then 
        print("[nigMenu] populateSwords: Config or Utils missing")
        return 
    end
    
    local scroll = Config.UI.SwordsScroll
    if not scroll then 
        print("[nigMenu] populateSwords: SwordsScroll not found")
        return 
    end
    
    local T = Config.Theme
    
    -- Clear existing
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA('Frame') or child:IsA('TextLabel') then
            child:Destroy()
        end
    end
    
    -- Stop rainbow loops
    if NM and NM.Features and NM.Features.swords then
        NM.Features.swords.stopAllRainbows()
    end
    
    Config.UI.SwordLevelLabels = {}
    
    local swords = {}
    if NM and NM.Features and NM.Features.swords then
        swords = NM.Features.swords.getAll()
        print("[nigMenu] populateSwords: Got " .. #swords .. " swords")
    else
        print("[nigMenu] populateSwords: swords feature not loaded")
    end
    
    if #swords == 0 then
        Utils.create('TextLabel', {
            Size = UDim2.new(1, -16, 0, 100),
            Position = UDim2.new(0, 8, 0, 0),
            BackgroundTransparency = 1,
            Text = 'No swords found\n\nMake sure you have swords\nin this game.',
            TextColor3 = T.TextMuted,
            TextSize = 13,
            Font = Enum.Font.Gotham,
            TextWrapped = true,
            Parent = scroll
        })
        return
    end
    
    scroll.CanvasSize = UDim2.new(0, 0, 0, #swords * 28)
    
    for i, sword in ipairs(swords) do
        local row = Utils.create('Frame', {
            Size = UDim2.new(1, -8, 0, 26),
            Position = UDim2.new(0, 0, 0, (i - 1) * 28),
            BackgroundTransparency = 1,
            Parent = scroll
        })
        
        local color = NM.Features.swords.getRarityColor(sword.rarity)
        local font = NM.Features.swords.getRarityFont(sword.rarity)
        
        local label = Utils.create('TextLabel', {
            Name = sword.name,
            Size = UDim2.new(1, -80, 1, 0),
            BackgroundTransparency = 1,
            Text = sword.name .. ' (+' .. sword.level .. ')',
            TextColor3 = color,
            TextSize = 13,
            Font = font,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row
        })
        
        Config.UI.SwordLevelLabels[sword.name] = {
            label = label,
            baseColor = color,
            rarity = sword.rarity
        }
        
        -- Rainbow effect for SSS
        if sword.rarity == 'SSS' then
            NM.Features.swords.startRainbow(sword.name, label)
        end
        
        local isActive = Config.Toggles.swordEnchantLoops[sword.name]
        local btn = Utils.createSmallButton(row, isActive and 'Stop' or 'Enchant', -10, 2, 70, isActive and T.Success or T.Accent)
        
        local swordName = sword.name
        btn.MouseButton1Click:Connect(function()
            local nowActive = not Config.Toggles.swordEnchantLoops[swordName]
            if NM.Features.swords then
                NM.Features.swords.setLoop(swordName, nowActive)
            end
            btn.BackgroundColor3 = nowActive and T.Success or T.Accent
            btn.Text = nowActive and 'Stop' or 'Enchant'
        end)
    end
end

local function populateSplitter()
    local Config = getConfig()
    local Utils = getUtils()
    local NM = getNM()
    
    if not Config or not Utils then return end
    
    local scroll = Config.UI.SplitterScroll
    if not scroll then return end
    
    local T = Config.Theme
    
    -- Clear existing
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA('Frame') then
            child:Destroy()
        end
    end
    
    local swords = {}
    if NM and NM.Features and NM.Features.splitter then
        swords = NM.Features.splitter.getAll()
    end
    
    if #swords == 0 then
        Utils.create('TextLabel', {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1,
            Text = 'No swords to split',
            TextColor3 = T.TextMuted,
            TextSize = 13,
            Font = Enum.Font.Gotham,
            Parent = scroll
        })
        return
    end
    
    scroll.CanvasSize = UDim2.new(0, 0, 0, #swords * 28)
    
    for i, sword in ipairs(swords) do
        local row = Utils.create('Frame', {
            Size = UDim2.new(1, -8, 0, 26),
            Position = UDim2.new(0, 0, 0, (i - 1) * 28),
            BackgroundTransparency = 1,
            Parent = scroll
        })
        
        local color = Config.RarityColors[sword.rarity] or T.Text
        local font = sword.rarity == 'SSS' and Enum.Font.GothamBold or Enum.Font.Gotham
        
        local label = Utils.create('TextLabel', {
            Size = UDim2.new(1, -140, 1, 0),
            BackgroundTransparency = 1,
            Text = sword.name .. ' (x' .. sword.count .. ')',
            TextColor3 = color,
            TextSize = 13,
            Font = font,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row
        })
        
        -- Rainbow for SSS
        if sword.rarity == 'SSS' then
            task.spawn(function()
                local h = 0
                while label and label.Parent and Config.State.running do
                    h = (h + 0.01) % 1
                    label.TextColor3 = Color3.fromHSV(h, 1, 1)
                    task.wait(0.05)
                end
            end)
        end
        
        local swordName = sword.name
        local isAutoActive = NM.Features.splitter and NM.Features.splitter.isAutoActive(swordName)
        
        local autoBtn = Utils.createSmallButton(row, isAutoActive and 'Auto:ON' or 'Auto', -80, 2, 65, isAutoActive and T.Success or T.Warning)
        local splitBtn = Utils.createSmallButton(row, 'Split', -10, 2, 65, sword.count > 1 and T.Accent or T.CardHover)
        
        splitBtn.MouseButton1Click:Connect(function()
            if NM.Features.splitter then
                NM.Features.splitter.split(swordName, 1)
            end
            task.delay(0.5, populateSplitter)
        end)
        
        autoBtn.MouseButton1Click:Connect(function()
            local nowActive = not (NM.Features.splitter and NM.Features.splitter.isAutoActive(swordName))
            if NM.Features.splitter then
                NM.Features.splitter.setAutoLoop(swordName, nowActive)
            end
            autoBtn.BackgroundColor3 = nowActive and T.Success or T.Warning
            autoBtn.Text = nowActive and 'Auto:ON' or 'Auto'
        end)
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function UpgradesTab.init()
    local Config = getConfig()
    if not Config then return end
    
    local panel = Config.UI.Tabs['Upgrades']
    if not panel then return end
    
    local yOffset = 0
    
    local _, h1 = buildGeneralsSection(panel, yOffset)
    yOffset = yOffset + (h1 or 0)
    
    local _, h2 = buildSwordsSection(panel, yOffset)
    yOffset = yOffset + (h2 or 0)
    
    local _, h3 = buildSplitterSection(panel, yOffset)
    yOffset = yOffset + (h3 or 0)
    
    panel.CanvasSize = UDim2.new(0, 0, 0, yOffset)
end

function UpgradesTab.onShow()
    print("[nigMenu] UpgradesTab.onShow called, hasLoaded=" .. tostring(hasLoaded))
    
    local Config = getConfig()
    if not Config then 
        print("[nigMenu] UpgradesTab.onShow: Config not available")
        return 
    end
    
    local panel = Config.UI.Tabs['Upgrades']
    if not panel then 
        print("[nigMenu] UpgradesTab.onShow: Upgrades panel not found")
        return 
    end
    
    -- Always populate on show (removed hasLoaded check for now)
    isLoading = true
    showLoading(panel)
    
    task.spawn(function()
        task.wait(0.3)
        
        print("[nigMenu] UpgradesTab: Populating content...")
        populateGenerals()
        populateSwords()
        populateSplitter()
        print("[nigMenu] UpgradesTab: Population complete")
        
        hasLoaded = true
        hideLoading()
    end)
end

function UpgradesTab.refresh()
    hasLoaded = false
    UpgradesTab.onShow()
end

return UpgradesTab
