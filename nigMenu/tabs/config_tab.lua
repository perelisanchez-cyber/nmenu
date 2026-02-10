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

-- Boss Times Debug Console (inline loader)
local function loadBossTimesDebug()
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    -- Remove existing if open
    local existing = playerGui:FindFirstChild("BossDebugConsole")
    if existing then existing:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "BossDebugConsole"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 500, 0, 400)
    mainFrame.Position = UDim2.new(0.5, -250, 0.5, -200)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)

    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 8)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Boss Times Debug Console"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.Parent = titleBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -30, 0, 0)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.Parent = titleBar
    closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy() end)

    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, -20, 1, -80)
    scrollFrame.Position = UDim2.new(0, 10, 0, 40)
    scrollFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 8
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrollFrame.Parent = mainFrame
    Instance.new("UICorner", scrollFrame).CornerRadius = UDim.new(0, 4)

    local outputLabel = Instance.new("TextLabel")
    outputLabel.Size = UDim2.new(1, -10, 0, 0)
    outputLabel.Position = UDim2.new(0, 5, 0, 0)
    outputLabel.BackgroundTransparency = 1
    outputLabel.Text = ""
    outputLabel.TextColor3 = Color3.fromRGB(200, 255, 200)
    outputLabel.TextXAlignment = Enum.TextXAlignment.Left
    outputLabel.TextYAlignment = Enum.TextYAlignment.Top
    outputLabel.Font = Enum.Font.Code
    outputLabel.TextSize = 11
    outputLabel.TextWrapped = true
    outputLabel.AutomaticSize = Enum.AutomaticSize.Y
    outputLabel.RichText = true
    outputLabel.Parent = scrollFrame

    local refreshBtn = Instance.new("TextButton")
    refreshBtn.Size = UDim2.new(0, 100, 0, 30)
    refreshBtn.Position = UDim2.new(0, 10, 1, -35)
    refreshBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
    refreshBtn.BorderSizePixel = 0
    refreshBtn.Text = "Refresh"
    refreshBtn.TextColor3 = Color3.new(1, 1, 1)
    refreshBtn.Font = Enum.Font.GothamBold
    refreshBtn.TextSize = 14
    refreshBtn.Parent = mainFrame
    Instance.new("UICorner", refreshBtn).CornerRadius = UDim.new(0, 4)

    local copyBtn = Instance.new("TextButton")
    copyBtn.Size = UDim2.new(0, 100, 0, 30)
    copyBtn.Position = UDim2.new(0, 120, 1, -35)
    copyBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 120)
    copyBtn.BorderSizePixel = 0
    copyBtn.Text = "Copy All"
    copyBtn.TextColor3 = Color3.new(1, 1, 1)
    copyBtn.Font = Enum.Font.GothamBold
    copyBtn.TextSize = 14
    copyBtn.Parent = mainFrame
    Instance.new("UICorner", copyBtn).CornerRadius = UDim.new(0, 4)

    local rawOutput = ""

    local function log(text, color)
        color = color or "rgb(200,255,200)"
        rawOutput = rawOutput .. text .. "\n"
        outputLabel.Text = outputLabel.Text .. string.format('<font color="%s">%s</font>\n', color, text)
    end

    local function formatTime(seconds)
        if seconds <= 0 then
            return string.format("-%d:%02d (ACTIVE)", math.floor(-seconds / 60), math.floor(-seconds) % 60)
        end
        return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds) % 60)
    end

    local function runDebug()
        rawOutput = ""
        outputLabel.Text = ""
        local serverTime = workspace:GetServerTimeNow()

        log("========== BOSS TIMES DEBUG ==========", "rgb(255,200,100)")
        log("Server Time: " .. tostring(serverTime))

        local WorldBossData, EventManagerShared
        local wbdPath = ReplicatedStorage:FindFirstChild("SharedModules") and ReplicatedStorage.SharedModules:FindFirstChild("WorldBossData")
        if wbdPath then
            local ok, res = pcall(require, wbdPath)
            if ok then WorldBossData = res; log("[OK] WorldBossData loaded", "rgb(100,255,150)")
            else log("[ERR] WorldBossData: " .. tostring(res), "rgb(255,100,100)") end
        else log("[ERR] WorldBossData not found", "rgb(255,100,100)") end

        local emsPath = ReplicatedStorage:FindFirstChild("SharedModules") and ReplicatedStorage.SharedModules:FindFirstChild("EventManagerShared")
        if emsPath then
            local ok, res = pcall(require, emsPath)
            if ok then EventManagerShared = res; log("[OK] EventManagerShared loaded", "rgb(100,255,150)")
            else log("[ERR] EventManagerShared: " .. tostring(res), "rgb(255,100,100)") end
        end

        if WorldBossData then
            log("\n--- WorldBossData Keys ---", "rgb(255,200,100)")
            for k, v in pairs(WorldBossData) do
                log("  " .. k .. " (" .. typeof(v) .. ")", "rgb(200,200,255)")
            end
            if WorldBossData.eventSuffix then
                log("  eventSuffix = " .. tostring(WorldBossData.eventSuffix), "rgb(255,255,150)")
            end
        end

        local wbFolder = workspace:FindFirstChild("Server") and workspace.Server:FindFirstChild("Enemies") and workspace.Server.Enemies:FindFirstChild("WorldBoss")
        if wbFolder then
            log("\n--- Boss Blocks ---", "rgb(255,200,100)")
            for _, mapFolder in ipairs(wbFolder:GetChildren()) do
                log("[MAP] " .. mapFolder.Name, "rgb(255,200,150)")
                for _, boss in ipairs(mapFolder:GetChildren()) do
                    if boss:IsA("BasePart") then
                        log("  " .. boss.Name, "rgb(200,255,200)")
                        for attr, val in pairs(boss:GetAttributes()) do
                            log("    [Attr] " .. attr .. " = " .. tostring(val), "rgb(180,180,255)")
                        end
                        if WorldBossData then
                            if WorldBossData.GetSpawnTime then
                                local ok, st = pcall(WorldBossData.GetSpawnTime, boss)
                                if ok then log("    GetSpawnTime = " .. tostring(st) .. " (in " .. formatTime(st - serverTime) .. ")", "rgb(100,255,200)")
                                else log("    GetSpawnTime ERR: " .. tostring(st), "rgb(255,100,100)") end
                            end
                            if WorldBossData.GetDespawnTime then
                                local ok, dt = pcall(WorldBossData.GetDespawnTime, boss)
                                if ok then log("    GetDespawnTime = " .. tostring(dt) .. " (in " .. formatTime(dt - serverTime) .. ")", "rgb(255,200,100)")
                                else log("    GetDespawnTime ERR: " .. tostring(dt), "rgb(255,100,100)") end
                            end
                            if WorldBossData.IsDied then
                                local ok, died = pcall(WorldBossData.IsDied, boss)
                                if ok then
                                    local col = died and "rgb(255,100,100)" or "rgb(100,255,100)"
                                    log("    IsDied = " .. tostring(died), col)
                                end
                            end
                            if EventManagerShared and EventManagerShared.GetEventStatus then
                                local evtName = boss.Name .. (WorldBossData.eventSuffix or "")
                                local ok, status = pcall(EventManagerShared.GetEventStatus, evtName)
                                if ok and status then
                                    log("    Event: " .. evtName, "rgb(200,150,255)")
                                    log("      startTime = " .. tostring(status.startTime), "rgb(200,200,255)")
                                    log("      endTime = " .. tostring(status.endTime), "rgb(200,200,255)")
                                elseif ok then
                                    log("    Event '" .. evtName .. "' = nil", "rgb(255,200,100)")
                                end
                            end
                        end
                    end
                end
            end
        else
            log("[ERR] WorldBoss folder not found at workspace.Server.Enemies.WorldBoss", "rgb(255,100,100)")
        end

        log("\n========== DEBUG COMPLETE ==========", "rgb(255,200,100)")
    end

    refreshBtn.MouseButton1Click:Connect(runDebug)
    copyBtn.MouseButton1Click:Connect(function()
        if setclipboard then
            setclipboard(rawOutput)
            copyBtn.Text = "Copied!"
            task.delay(1, function() copyBtn.Text = "Copy All" end)
        end
    end)

    -- Dragging
    local dragging, dragStart, startPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = input.Position; startPos = mainFrame.Position
        end
    end)
    titleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    runDebug()
end

function ConfigTab.init()
    local panel = Config.UI.Tabs['Config']
    if not panel then return end
    
    local yOffset = 0
    
    -- ========================================================================
    -- SETTINGS CARD
    -- ========================================================================
    
    local settingsCard = Utils.createCard(panel, nil, 230, yOffset)
    
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

        -- Show/hide debug tools
        if debugToolsRow then
            debugToolsRow.Visible = Config.State.debugMode
        end

        if NM.Settings then
            NM.Settings.save()
        end
    end)

    -- Debug Tools row (only visible when debug mode is on)
    local debugToolsRow = Utils.create('Frame', {
        Size = UDim2.new(1, -24, 0, 36),
        Position = UDim2.new(0, 12, 0, 142),
        BackgroundColor3 = T.CardHover,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        Visible = Config.State.debugMode,
        Parent = settingsCard
    })
    Utils.addCorner(debugToolsRow, 6)

    Utils.create('TextLabel', {
        Size = UDim2.new(0, 24, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = '🔍',
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        Parent = debugToolsRow
    })

    Utils.create('TextLabel', {
        Size = UDim2.new(0, 100, 1, 0),
        Position = UDim2.new(0, 38, 0, 0),
        BackgroundTransparency = 1,
        Text = 'Debug Tools',
        TextColor3 = T.TextDim,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = debugToolsRow
    })

    local bossTimesBtn = Utils.create('TextButton', {
        Size = UDim2.new(0, 90, 0, 26),
        Position = UDim2.new(1, -100, 0.5, -13),
        BackgroundColor3 = T.Warning,
        BorderSizePixel = 0,
        Text = 'Boss Times',
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        Parent = debugToolsRow
    })
    Utils.addCorner(bossTimesBtn, 6)

    bossTimesBtn.MouseButton1Click:Connect(function()
        -- Load and run the boss times debug script
        if NM.Features and NM.Features.BossTimesDebug then
            NM.Features.BossTimesDebug.open()
        else
            -- Fallback: load inline
            loadBossTimesDebug()
        end
    end)

    -- Wave auto-leave row (moved down to accommodate debug tools)
    local waveRow = Utils.create('Frame', {
        Size = UDim2.new(1, -24, 0, 36),
        Position = UDim2.new(0, 12, 0, 184),
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
    
    yOffset = yOffset + 238

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
