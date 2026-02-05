--[[
    ============================================================================
    nigMenu - Server Hopper Tab
    ============================================================================
    
    Manage private servers, restart via local proxy, hop between servers.
]]

local ServerTab = {}

local function getNM() return _G.nigMenu end
local function getConfig() return _G.nigMenu and _G.nigMenu.Config end
local function getUtils() return _G.nigMenu and _G.nigMenu.Utils end

local serverListFrame, serverCountLabel, statusLabel

-- ============================================================================
-- REBUILD SERVER LIST
-- ============================================================================

local function rebuildServerList()
    local Config = getConfig()
    local Utils = getUtils()
    local NM = getNM()
    local bosses = NM and NM.Features and NM.Features.bosses
    
    if not serverListFrame or not bosses or not Config or not Utils then return end
    
    local T = Config.Theme
    
    for _, child in ipairs(serverListFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    local rowHeight = 42
    
    for idx, server in ipairs(bosses.servers) do
        local shortCode = server.joinCode:sub(1, 10) .. "..." .. server.joinCode:sub(-6)
        local isCurrent = (bosses.currentServerIndex == idx)
        
        local row = Utils.create('Frame', {
            Size = UDim2.new(1, -8, 0, rowHeight),
            Position = UDim2.new(0, 4, 0, (idx - 1) * (rowHeight + 4)),
            BackgroundColor3 = isCurrent and Color3.fromRGB(35, 45, 35) or T.Card,
            BorderSizePixel = 0,
            Parent = serverListFrame
        })
        Utils.addCorner(row, 6)
        
        Utils.create('TextLabel', {
            Size = UDim2.new(0, 20, 1, 0),
            Position = UDim2.new(0, 6, 0, 0),
            BackgroundTransparency = 1,
            Text = isCurrent and "🟢" or "⚫",
            TextSize = 12,
            Font = Enum.Font.Gotham,
            Parent = row
        })
        
        Utils.create('TextLabel', {
            Size = UDim2.new(0, 140, 0, 16),
            Position = UDim2.new(0, 28, 0, 3),
            BackgroundTransparency = 1,
            Text = server.name or ('Server ' .. idx),
            TextColor3 = isCurrent and Color3.fromRGB(80, 255, 80) or T.Text,
            TextSize = 13,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row
        })
        
        Utils.create('TextLabel', {
            Size = UDim2.new(0, 160, 0, 14),
            Position = UDim2.new(0, 28, 0, 20),
            BackgroundTransparency = 1,
            Text = shortCode,
            TextColor3 = T.TextMuted,
            TextSize = 10,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row
        })
        
        local restartBtn = Utils.create('TextButton', {
            Size = UDim2.new(0, 58, 0, 28),
            Position = UDim2.new(1, -134, 0.5, -14),
            BackgroundColor3 = Color3.fromRGB(180, 100, 40),
            BorderSizePixel = 0,
            Text = '🔄 Reset',
            TextColor3 = Color3.new(1, 1, 1),
            TextSize = 11,
            Font = Enum.Font.GothamBold,
            Parent = row
        })
        Utils.addCorner(restartBtn, 4)
        
        restartBtn.MouseEnter:Connect(function() restartBtn.BackgroundColor3 = Color3.fromRGB(220, 130, 50) end)
        restartBtn.MouseLeave:Connect(function() restartBtn.BackgroundColor3 = Color3.fromRGB(180, 100, 40) end)
        
        local rIdx = idx
        restartBtn.MouseButton1Click:Connect(function()
            if not bosses then return end
            restartBtn.Text = '...'
            restartBtn.BackgroundColor3 = Color3.fromRGB(120, 80, 30)
            if statusLabel then
                statusLabel.Text = "Restarting " .. (server.name or "Server " .. rIdx) .. "..."
                statusLabel.TextColor3 = Color3.fromRGB(255, 180, 80)
            end
            bosses.currentServerIndex = rIdx
            task.spawn(function()
                bosses.restartCurrentServer(function()
                    task.delay(2, function()
                        restartBtn.Text = '🔄 Reset'
                        restartBtn.BackgroundColor3 = Color3.fromRGB(180, 100, 40)
                    end)
                end)
            end)
        end)
        
        local joinBtn = Utils.create('TextButton', {
            Size = UDim2.new(0, 44, 0, 28),
            Position = UDim2.new(1, -72, 0.5, -14),
            BackgroundColor3 = Color3.fromRGB(60, 120, 180),
            BorderSizePixel = 0,
            Text = '→ Join',
            TextColor3 = Color3.new(1, 1, 1),
            TextSize = 11,
            Font = Enum.Font.GothamBold,
            Parent = row
        })
        Utils.addCorner(joinBtn, 4)
        
        joinBtn.MouseEnter:Connect(function() joinBtn.BackgroundColor3 = Color3.fromRGB(80, 150, 220) end)
        joinBtn.MouseLeave:Connect(function() joinBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 180) end)
        
        local sIdx = idx
        joinBtn.MouseButton1Click:Connect(function()
            if not bosses then return end
            joinBtn.Text = '...'
            if statusLabel then
                statusLabel.Text = "Joining " .. (server.name or "Server " .. sIdx) .. "..."
                statusLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
            end
            bosses.hopToServer(sIdx)
        end)
        
        local copyBtn = Utils.create('TextButton', {
            Size = UDim2.new(0, 24, 0, 28),
            Position = UDim2.new(1, -24, 0.5, -14),
            BackgroundColor3 = T.CardHover,
            BorderSizePixel = 0,
            Text = '📋',
            TextSize = 12,
            Font = Enum.Font.Gotham,
            Parent = row
        })
        Utils.addCorner(copyBtn, 4)
        
        local jCode = server.joinCode
        copyBtn.MouseButton1Click:Connect(function()
            pcall(function()
                if setclipboard then
                    setclipboard(jCode)
                    copyBtn.Text = '✓'
                    task.delay(1, function() copyBtn.Text = '📋' end)
                end
            end)
        end)
    end
    
    local totalHeight = #bosses.servers * (rowHeight + 4)
    serverListFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
    
    if serverCountLabel then
        serverCountLabel.Text = #bosses.servers .. " servers"
    end
end

-- ============================================================================
-- INIT
-- ============================================================================

function ServerTab.init()
    local Config = getConfig()
    local Utils = getUtils()
    local NM = getNM()
    
    if not Config or not Utils then return end
    
    local panel = Config.UI.Tabs['ServerHopper']
    if not panel then return end
    
    local T = Config.Theme
    local yOffset = 0
    local bosses = NM and NM.Features and NM.Features.bosses
    
    -- ========================================================================
    -- HEADER CARD
    -- ========================================================================
    
    local headerCard = Utils.createCard(panel, nil, 130, yOffset)
    
    Utils.create('TextLabel', {
        Size = UDim2.new(1, -20, 0, 20),
        Position = UDim2.new(0, 12, 0, 8),
        BackgroundTransparency = 1,
        Text = '🔄  Server Manager',
        TextColor3 = T.Text,
        TextSize = 15,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = headerCard
    })
    
    statusLabel = Utils.create('TextLabel', {
        Size = UDim2.new(1, -100, 0, 14),
        Position = UDim2.new(0, 12, 0, 30),
        BackgroundTransparency = 1,
        Text = 'Ready',
        TextColor3 = T.TextMuted,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = headerCard
    })
    
    serverCountLabel = Utils.create('TextLabel', {
        Size = UDim2.new(0, 80, 0, 14),
        Position = UDim2.new(1, -92, 0, 30),
        BackgroundTransparency = 1,
        Text = (bosses and #bosses.servers or 0) .. " servers",
        TextColor3 = T.TextDim,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = headerCard
    })
    
    local restartCurrentBtn = Utils.create('TextButton', {
        Size = UDim2.new(1, -24, 0, 30),
        Position = UDim2.new(0, 12, 0, 52),
        BackgroundColor3 = Color3.fromRGB(180, 80, 30),
        BorderSizePixel = 0,
        Text = '🔄  RESTART SERVER (via Manager)',
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        Parent = headerCard
    })
    Utils.addCorner(restartCurrentBtn, 6)
    
    restartCurrentBtn.MouseEnter:Connect(function() restartCurrentBtn.BackgroundColor3 = Color3.fromRGB(220, 100, 40) end)
    restartCurrentBtn.MouseLeave:Connect(function() restartCurrentBtn.BackgroundColor3 = Color3.fromRGB(180, 80, 30) end)
    
    restartCurrentBtn.MouseButton1Click:Connect(function()
        if not bosses then return end
        restartCurrentBtn.Text = '🔄  Restarting...'
        restartCurrentBtn.BackgroundColor3 = Color3.fromRGB(120, 60, 20)
        task.spawn(function()
            bosses.restartCurrentServer(function()
                task.delay(3, function()
                    restartCurrentBtn.Text = '🔄  RESTART SERVER (via Manager)'
                    restartCurrentBtn.BackgroundColor3 = Color3.fromRGB(180, 80, 30)
                end)
            end)
        end)
    end)
    
    local testBtn = Utils.create('TextButton', {
        Size = UDim2.new(1, -24, 0, 24),
        Position = UDim2.new(0, 12, 0, 88),
        BackgroundColor3 = T.CardHover,
        BorderSizePixel = 0,
        Text = '🔍  Debug (Manager Status + Teleport Data)',
        TextColor3 = T.TextMuted,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        Parent = headerCard
    })
    Utils.addCorner(testBtn, 4)
    
    testBtn.MouseButton1Click:Connect(function()
        if not bosses or #bosses.servers == 0 then return end
        testBtn.Text = '🔍  Testing...'
        task.spawn(function()
            bosses.debugServerHop(1)
            task.delay(1, function()
                testBtn.Text = '🔍  Debug (Manager Status + Teleport Data)'
            end)
        end)
    end)
    
    yOffset = yOffset + 138
    
    -- ========================================================================
    -- INFO CARD
    -- ========================================================================
    
    local infoCard = Utils.createCard(panel, nil, 72, yOffset)
    
    Utils.create('TextLabel', {
        Size = UDim2.new(1, -20, 0, 60),
        Position = UDim2.new(0, 12, 0, 6),
        BackgroundTransparency = 1,
        Text = '💡 Restart shuts down server → boss respawns on rejoin.\nRequires roblox_manager.py on your PC (localhost:8080).\nManager relaunches all accounts automatically.',
        TextColor3 = T.TextDim,
        TextSize = 10,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        Parent = infoCard
    })
    
    yOffset = yOffset + 80
    
    -- ========================================================================
    -- SERVER LIST
    -- ========================================================================
    
    Utils.create('TextLabel', {
        Size = UDim2.new(1, 0, 0, 20),
        Position = UDim2.new(0, 4, 0, yOffset),
        BackgroundTransparency = 1,
        Text = 'YOUR SERVERS',
        TextColor3 = T.TextDim,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = panel
    })
    yOffset = yOffset + 24
    
    serverListFrame = Utils.create('ScrollingFrame', {
        Size = UDim2.new(1, 0, 0, 200),
        Position = UDim2.new(0, 0, 0, yOffset),
        BackgroundColor3 = T.CardHover,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = T.TextDim,
        Parent = panel
    })
    Utils.addCorner(serverListFrame, 8)
    
    yOffset = yOffset + 208
    
    rebuildServerList()
    
    panel.CanvasSize = UDim2.new(0, 0, 0, yOffset + 8)
end

function ServerTab.onShow()
    rebuildServerList()
end

return ServerTab
