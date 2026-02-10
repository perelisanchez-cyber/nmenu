--[[
    Boss Times Debug Script
    Run this standalone to dump all boss timing data for debugging
]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Create Debug UI
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

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = mainFrame

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 30)
titleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 8)
titleCorner.Parent = titleBar

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -60, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Boss Times Debug Console"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "Close"
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -30, 0, 0)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.Parent = titleBar
closeBtn.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)

-- Scroll frame for output
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "OutputScroll"
scrollFrame.Size = UDim2.new(1, -20, 1, -80)
scrollFrame.Position = UDim2.new(0, 10, 0, 40)
scrollFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 8
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 150)
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.Parent = mainFrame

local scrollCorner = Instance.new("UICorner")
scrollCorner.CornerRadius = UDim.new(0, 4)
scrollCorner.Parent = scrollFrame

local outputLabel = Instance.new("TextLabel")
outputLabel.Name = "Output"
outputLabel.Size = UDim2.new(1, -10, 0, 0)
outputLabel.Position = UDim2.new(0, 5, 0, 0)
outputLabel.BackgroundTransparency = 1
outputLabel.Text = ""
outputLabel.TextColor3 = Color3.fromRGB(200, 255, 200)
outputLabel.TextXAlignment = Enum.TextXAlignment.Left
outputLabel.TextYAlignment = Enum.TextYAlignment.Top
outputLabel.Font = Enum.Font.Code
outputLabel.TextSize = 12
outputLabel.TextWrapped = true
outputLabel.AutomaticSize = Enum.AutomaticSize.Y
outputLabel.RichText = true
outputLabel.Parent = scrollFrame

-- Refresh button
local refreshBtn = Instance.new("TextButton")
refreshBtn.Name = "Refresh"
refreshBtn.Size = UDim2.new(0, 100, 0, 30)
refreshBtn.Position = UDim2.new(0, 10, 1, -35)
refreshBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
refreshBtn.BorderSizePixel = 0
refreshBtn.Text = "Refresh"
refreshBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
refreshBtn.Font = Enum.Font.GothamBold
refreshBtn.TextSize = 14
refreshBtn.Parent = mainFrame

local refreshCorner = Instance.new("UICorner")
refreshCorner.CornerRadius = UDim.new(0, 4)
refreshCorner.Parent = refreshBtn

-- Copy button
local copyBtn = Instance.new("TextButton")
copyBtn.Name = "Copy"
copyBtn.Size = UDim2.new(0, 100, 0, 30)
copyBtn.Position = UDim2.new(0, 120, 1, -35)
copyBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 120)
copyBtn.BorderSizePixel = 0
copyBtn.Text = "Copy All"
copyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
copyBtn.Font = Enum.Font.GothamBold
copyBtn.TextSize = 14
copyBtn.Parent = mainFrame

local copyCorner = Instance.new("UICorner")
copyCorner.CornerRadius = UDim.new(0, 4)
copyCorner.Parent = copyBtn

-- Raw output storage for clipboard
local rawOutput = ""

-- Helper to add text
local function log(text, color)
    color = color or "rgb(200,255,200)"
    rawOutput = rawOutput .. text .. "\n"
    outputLabel.Text = outputLabel.Text .. string.format('<font color="%s">%s</font>\n', color, text)
end

local function logHeader(text)
    log("\n========== " .. text .. " ==========", "rgb(255,200,100)")
end

local function logError(text)
    log("[ERROR] " .. text, "rgb(255,100,100)")
end

local function logInfo(text)
    log(text, "rgb(150,200,255)")
end

local function logSuccess(text)
    log(text, "rgb(100,255,150)")
end

local function formatTime(seconds)
    if seconds <= 0 then
        return string.format("-%d:%02d (ACTIVE)", math.floor(-seconds / 60), math.floor(-seconds) % 60)
    else
        return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds) % 60)
    end
end

-- Main debug function
local function runDebug()
    rawOutput = ""
    outputLabel.Text = ""

    local serverTime = workspace:GetServerTimeNow()
    logHeader("BOSS TIMES DEBUG - " .. os.date("%Y-%m-%d %H:%M:%S"))
    log("Server Time: " .. tostring(serverTime))

    -- Try to load modules
    logHeader("LOADING MODULES")

    local WorldBossData, EventManagerShared

    -- Try WorldBossData
    local wbdPath = ReplicatedStorage:FindFirstChild("SharedModules") and
                    ReplicatedStorage.SharedModules:FindFirstChild("WorldBossData")
    if wbdPath then
        local success, result = pcall(function()
            return require(wbdPath)
        end)
        if success then
            WorldBossData = result
            logSuccess("WorldBossData loaded successfully")
        else
            logError("Failed to require WorldBossData: " .. tostring(result))
        end
    else
        logError("WorldBossData module not found at ReplicatedStorage.SharedModules.WorldBossData")
    end

    -- Try EventManagerShared
    local emsPath = ReplicatedStorage:FindFirstChild("SharedModules") and
                    ReplicatedStorage.SharedModules:FindFirstChild("EventManagerShared")
    if emsPath then
        local success, result = pcall(function()
            return require(emsPath)
        end)
        if success then
            EventManagerShared = result
            logSuccess("EventManagerShared loaded successfully")
        else
            logError("Failed to require EventManagerShared: " .. tostring(result))
        end
    else
        logError("EventManagerShared module not found")
    end

    -- Dump WorldBossData contents
    if WorldBossData then
        logHeader("WORLDBOSSDATA CONTENTS")
        for key, value in pairs(WorldBossData) do
            local valType = typeof(value)
            if valType == "function" then
                log("  [function] " .. key, "rgb(200,200,255)")
            elseif valType == "table" then
                log("  [table] " .. key .. " (" .. #value .. " entries if array)", "rgb(200,255,200)")
            else
                log("  " .. key .. " = " .. tostring(value), "rgb(255,255,200)")
            end
        end

        -- Check for BossConfigs
        if WorldBossData.BossConfigs then
            logHeader("BOSS CONFIGS")
            for bossName, config in pairs(WorldBossData.BossConfigs) do
                log("  " .. bossName .. ":", "rgb(255,200,150)")
                if typeof(config) == "table" then
                    for k, v in pairs(config) do
                        log("    " .. k .. " = " .. tostring(v))
                    end
                end
            end
        end

        -- Check eventSuffix
        if WorldBossData.eventSuffix then
            logInfo("eventSuffix = " .. tostring(WorldBossData.eventSuffix))
        end
    end

    -- Check Events folder
    logHeader("EVENTS FOLDER")
    local eventsFolder = emsPath and emsPath:FindFirstChild("Events")
    if eventsFolder then
        logSuccess("Events folder found")
        for _, child in ipairs(eventsFolder:GetChildren()) do
            log("  " .. child.Name .. " (" .. child.ClassName .. ")")
            if child:IsA("ValueBase") then
                log("    Value: " .. tostring(child.Value), "rgb(200,200,255)")
            end
            -- Check attributes
            for attrName, attrVal in pairs(child:GetAttributes()) do
                log("    [Attr] " .. attrName .. " = " .. tostring(attrVal), "rgb(255,255,150)")
            end
        end
    else
        logError("Events folder not found")
        -- Try alternate paths
        local altPath = ReplicatedStorage:FindFirstChild("SharedModules")
        if altPath then
            local ems = altPath:FindFirstChild("EventManagerShared")
            if ems then
                log("EventManagerShared instance found, children:")
                for _, c in ipairs(ems:GetChildren()) do
                    log("  " .. c.Name .. " (" .. c.ClassName .. ")")
                end
            end
        end
    end

    -- Check workspace boss folder
    logHeader("WORKSPACE BOSS FOLDER")
    local serverFolder = workspace:FindFirstChild("Server")
    local enemiesFolder = serverFolder and serverFolder:FindFirstChild("Enemies")
    local worldBossFolder = enemiesFolder and enemiesFolder:FindFirstChild("WorldBoss")

    if worldBossFolder then
        logSuccess("WorldBoss folder found at workspace.Server.Enemies.WorldBoss")
        for _, mapFolder in ipairs(worldBossFolder:GetChildren()) do
            log("\n  [MAP] " .. mapFolder.Name, "rgb(255,200,100)")
            for _, bossBlock in ipairs(mapFolder:GetChildren()) do
                if bossBlock:IsA("BasePart") then
                    log("    " .. bossBlock.Name, "rgb(200,255,200)")

                    -- Get all attributes
                    local attrs = bossBlock:GetAttributes()
                    for attrName, attrVal in pairs(attrs) do
                        log("      [Attr] " .. attrName .. " = " .. tostring(attrVal), "rgb(180,180,255)")
                    end

                    -- Try to get spawn time
                    if WorldBossData and WorldBossData.GetSpawnTime then
                        local success, spawnTime = pcall(function()
                            return WorldBossData.GetSpawnTime(bossBlock)
                        end)
                        if success then
                            local timeUntil = spawnTime - serverTime
                            log("      GetSpawnTime() = " .. tostring(spawnTime), "rgb(100,255,200)")
                            log("      Time until spawn: " .. formatTime(timeUntil), "rgb(100,255,200)")
                        else
                            logError("      GetSpawnTime failed: " .. tostring(spawnTime))
                        end
                    end

                    -- Try to get despawn time
                    if WorldBossData and WorldBossData.GetDespawnTime then
                        local success, despawnTime = pcall(function()
                            return WorldBossData.GetDespawnTime(bossBlock)
                        end)
                        if success then
                            local timeUntil = despawnTime - serverTime
                            log("      GetDespawnTime() = " .. tostring(despawnTime), "rgb(255,200,100)")
                            log("      Time until despawn: " .. formatTime(timeUntil), "rgb(255,200,100)")
                        else
                            logError("      GetDespawnTime failed: " .. tostring(despawnTime))
                        end
                    end

                    -- Try IsDied
                    if WorldBossData and WorldBossData.IsDied then
                        local success, isDied = pcall(function()
                            return WorldBossData.IsDied(bossBlock)
                        end)
                        if success then
                            if isDied then
                                log("      IsDied() = true (DEAD)", "rgb(255,100,100)")
                            else
                                log("      IsDied() = false (ALIVE)", "rgb(100,255,100)")
                            end
                        else
                            logError("      IsDied failed: " .. tostring(isDied))
                        end
                    end

                    -- Try to get event status
                    if EventManagerShared and EventManagerShared.GetEventStatus and WorldBossData then
                        local eventName = bossBlock.Name .. (WorldBossData.eventSuffix or "")
                        local success, eventStatus = pcall(function()
                            return EventManagerShared.GetEventStatus(eventName)
                        end)
                        if success and eventStatus then
                            log("      Event: " .. eventName, "rgb(200,150,255)")
                            log("        startTime = " .. tostring(eventStatus.startTime), "rgb(200,200,255)")
                            log("        endTime = " .. tostring(eventStatus.endTime), "rgb(200,200,255)")
                            if eventStatus.startTime then
                                log("        Time to start: " .. formatTime(eventStatus.startTime - serverTime))
                            end
                            if eventStatus.endTime then
                                log("        Time to end: " .. formatTime(eventStatus.endTime - serverTime))
                            end
                        elseif success then
                            log("      Event '" .. eventName .. "' returned nil", "rgb(255,200,100)")
                        else
                            logError("      GetEventStatus failed: " .. tostring(eventStatus))
                        end
                    end
                end
            end
        end
    else
        logError("WorldBoss folder not found!")
        log("Checking path:")
        log("  workspace.Server exists: " .. tostring(serverFolder ~= nil))
        log("  workspace.Server.Enemies exists: " .. tostring(enemiesFolder ~= nil))
    end

    -- List all events if EventManagerShared has them
    if EventManagerShared then
        logHeader("ALL EVENTS (if accessible)")
        if EventManagerShared.Events then
            for eventName, eventData in pairs(EventManagerShared.Events) do
                log("  " .. eventName, "rgb(200,200,255)")
                if typeof(eventData) == "table" then
                    for k, v in pairs(eventData) do
                        log("    " .. k .. " = " .. tostring(v))
                    end
                end
            end
        elseif EventManagerShared.GetAllEvents then
            local success, allEvents = pcall(EventManagerShared.GetAllEvents)
            if success and allEvents then
                for eventName, eventData in pairs(allEvents) do
                    log("  " .. eventName, "rgb(200,200,255)")
                end
            end
        else
            log("No Events table or GetAllEvents function found")
        end
    end

    logHeader("DEBUG COMPLETE")
    log("Copy this output and share it for debugging!")
end

-- Button handlers
refreshBtn.MouseButton1Click:Connect(runDebug)

copyBtn.MouseButton1Click:Connect(function()
    if setclipboard then
        setclipboard(rawOutput)
        copyBtn.Text = "Copied!"
        task.delay(1, function()
            copyBtn.Text = "Copy All"
        end)
    else
        logError("setclipboard not available in this executor")
    end
end)

-- Make draggable
local dragging, dragStart, startPos

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
    end
end)

titleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

-- Run on load
runDebug()

print("[BossDebug] Debug console loaded! Use the UI to refresh or copy output.")
