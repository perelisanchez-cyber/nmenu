--[[
    ============================================================================
    nigMenu - Bosses Tab UI
    ============================================================================
    
    Controls for the boss/angel auto-farm loop plus manual TP buttons.
    - Start/Stop auto-farm
    - Toggle bosses/angels
    - World range selection
    - Dwell time config
    - Live status display
    - Manual TP buttons per world
    - Per-world spawn timers inline
    - Persistent toggle states via Settings
]]

local BossesTab = {}

-- Lazy load references
local function getNM() return _G.nigMenu end
local function getConfig() return _G.nigMenu and _G.nigMenu.Config end
local function getUtils() return _G.nigMenu and _G.nigMenu.Utils end

-- UI references for live updates
local statusLabel = nil
local killsLabel = nil
local playersLabel = nil
local statusUpdateRunning = false

-- Per-world timer labels: worldTimerLabels[worldNum] = TextLabel
local worldTimerLabels = {}

-- Spawn Timers card labels
local bossTimerLabel = nil
local angelTimerLabel = nil

-- ============================================================================
-- SETTINGS PERSISTENCE HELPERS
-- ============================================================================

local function saveBossSettings()
    local NM = getNM()
    if NM and NM.Settings then
        NM.Settings.save()
    end
end

-- ============================================================================
-- STATUS UPDATE LOOP
-- ============================================================================

local function startStatusLoop()
    if statusUpdateRunning then return end
    statusUpdateRunning = true
    
    local Config = getConfig()
    local NM = getNM()
    
    task.spawn(function()
        while Config and Config.State.running and statusUpdateRunning do
            local bosses = NM and NM.Features and NM.Features.bosses
            if bosses and statusLabel and statusLabel.Parent then
                statusLabel.Text = bosses.status or "Idle"
                
                if bosses.farmEnabled then
                    statusLabel.TextColor3 = Color3.fromRGB(80, 255, 80)
                else
                    statusLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
                end
            end
            
            if bosses and killsLabel and killsLabel.Parent then
                killsLabel.Text = "Visited: " .. tostring(bosses.kills)
            end
            
            -- Update player/missing info
            if bosses and playersLabel and playersLabel.Parent then
                local playerCount = #bosses.getPlayerList()
                local missingCount = #(bosses.lastHeartbeatMissing or {})
                
                if missingCount > 0 then
                    playersLabel.Text = playerCount .. " in server | " .. missingCount .. " missing!"
                    playersLabel.TextColor3 = Color3.fromRGB(255, 100, 80)
                else
                    playersLabel.Text = playerCount .. " in server"
                    playersLabel.TextColor3 = Color3.fromRGB(120, 200, 120)
                end
            end
            
            -- ============================================================
            -- SPAWN TIMERS CARD + PER-WORLD TIMER UPDATES (event system)
            -- ============================================================
            if bosses then
                local T = Config.Theme
                local now = nil
                pcall(function() now = os.time() end)
                
                -- Track the soonest upcoming boss/angel for the top card
                local nextBossTime = nil
                local nextBossName = nil
                local activeBossName = nil
                local nextAngelTime = nil
                local nextAngelName = nil
                local activeAngelName = nil
                
                for worldNum, lbl in pairs(worldTimerLabels) do
                    if not lbl or not lbl.Parent then continue end
                    
                    pcall(function()
                        local bossActive, bossInfo = bosses.isBossActive(worldNum)
                        local angelActive, angelInfo = bosses.isAngelActive(worldNum)
                        local data = bosses.Data[worldNum]
                        local wName = data and data.spawn or ("W" .. worldNum)
                        
                        local bStr = "--:--"
                        local aStr = "--:--"
                        
                        -- Boss timer
                        if bossActive == true then
                            bStr = "ALIVE"
                            if not activeBossName then
                                activeBossName = wName
                            end
                        elseif bossInfo and bossInfo.startTime and now then
                            local remaining = bossInfo.startTime - now
                            if remaining > 0 then
                                bStr = bosses.formatTime(remaining)
                                if not nextBossTime or remaining < nextBossTime then
                                    nextBossTime = remaining
                                    nextBossName = wName
                                end
                            else
                                bStr = "ALIVE"
                                if not activeBossName then activeBossName = wName end
                            end
                        end
                        
                        -- Angel timer
                        if angelActive == true then
                            aStr = "ALIVE"
                            if not activeAngelName then
                                activeAngelName = wName
                            end
                        elseif angelInfo and angelInfo.startTime and now then
                            local remaining = angelInfo.startTime - now
                            if remaining > 0 then
                                aStr = bosses.formatTime(remaining)
                                if not nextAngelTime or remaining < nextAngelTime then
                                    nextAngelTime = remaining
                                    nextAngelName = wName
                                end
                            else
                                aStr = "ALIVE"
                                if not activeAngelName then activeAngelName = wName end
                            end
                        end
                        
                        lbl.Text = "\xF0\x9F\x92\x80 " .. bStr .. "  \xF0\x9F\x91\xBC " .. aStr
                        
                        -- Green if either is alive, muted otherwise
                        if bossActive == true or angelActive == true then
                            lbl.TextColor3 = Color3.fromRGB(80, 255, 80)
                        else
                            lbl.TextColor3 = Color3.fromRGB(130, 130, 140)
                        end
                    end)
                end
                
                -- Update the SPAWN TIMERS card labels
                if bossTimerLabel and bossTimerLabel.Parent then
                    if activeBossName then
                        bossTimerLabel.Text = "ACTIVE — " .. activeBossName
                        bossTimerLabel.TextColor3 = Color3.fromRGB(80, 255, 80)
                    elseif nextBossTime and nextBossName then
                        bossTimerLabel.Text = bosses.formatTime(nextBossTime) .. " — " .. nextBossName
                        bossTimerLabel.TextColor3 = T.Text
                    else
                        bossTimerLabel.Text = "No upcoming bosses"
                        bossTimerLabel.TextColor3 = T.TextMuted
                    end
                end
                
                if angelTimerLabel and angelTimerLabel.Parent then
                    if activeAngelName then
                        angelTimerLabel.Text = "ACTIVE — " .. activeAngelName
                        angelTimerLabel.TextColor3 = Color3.fromRGB(80, 255, 80)
                    elseif nextAngelTime and nextAngelName then
                        angelTimerLabel.Text = bosses.formatTime(nextAngelTime) .. " — " .. nextAngelName
                        angelTimerLabel.TextColor3 = T.Text
                    else
                        angelTimerLabel.Text = "No upcoming angels"
                        angelTimerLabel.TextColor3 = T.TextMuted
                    end
                end
            end
            
            task.wait(0.5)
        end
    end)
end

-- ============================================================================
-- INIT
-- ============================================================================

function BossesTab.init()
    local Config = getConfig()
    local Utils = getUtils()
    local NM = getNM()
    
    if not Config or not Utils then return end
    
    local panel = Config.UI.Tabs['Bosses']
    if not panel then return end
    
    local T = Config.Theme
    local yOffset = 0
    local bosses = NM and NM.Features and NM.Features.bosses
    
    -- Load saved boss toggle states from Config.Toggles
    local savedToggles = Config.Toggles.bossToggles
    if bosses and savedToggles then
        if savedToggles.farmBosses ~= nil then bosses.farmBosses = savedToggles.farmBosses end
        if savedToggles.farmAngels ~= nil then bosses.farmAngels = savedToggles.farmAngels end
        if savedToggles.farmMinWorld ~= nil then bosses.farmMinWorld = savedToggles.farmMinWorld end
        if savedToggles.farmMaxWorld ~= nil then bosses.farmMaxWorld = savedToggles.farmMaxWorld end
        if savedToggles.autoRestartOnKill ~= nil then bosses.autoRestartOnKill = savedToggles.autoRestartOnKill end
        if savedToggles.autoFarmOnJoin ~= nil then bosses.autoFarmOnJoin = savedToggles.autoFarmOnJoin end
    end
    
    -- Helper: update Config.Toggles.bossToggles and save
    local function persistBossToggles()
        if not bosses then return end
        Config.Toggles.bossToggles = {
            farmEnabled = bosses.farmEnabled,
            farmBosses = bosses.farmBosses,
            farmAngels = bosses.farmAngels,
            farmMinWorld = bosses.farmMinWorld,
            farmMaxWorld = bosses.farmMaxWorld,
            autoRestartOnKill = bosses.autoRestartOnKill,
            autoFarmOnJoin = bosses.autoFarmOnJoin,
        }
        saveBossSettings()
    end
    
    -- ========================================================================
    -- FARM CONTROLS CARD
    -- ========================================================================
    
    local controlCard = Utils.createCard(panel, nil, 186, yOffset)
    
    Utils.createIcon(controlCard, '💀', Color3.fromRGB(255, 80, 80), 40, UDim2.new(0, 12, 0, 10))
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 200, 0, 20),
        Position = UDim2.new(0, 60, 0, 10),
        BackgroundTransparency = 1,
        Text = 'BOSS AUTO-FARM',
        TextColor3 = Color3.fromRGB(255, 80, 80),
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = controlCard
    })
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 250, 0, 14),
        Position = UDim2.new(0, 60, 0, 30),
        BackgroundTransparency = 1,
        Text = 'Cycles through worlds farming bosses & angels',
        TextColor3 = T.TextMuted,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = controlCard
    })
    
    -- START / STOP button
    local farmBtn = Utils.create('TextButton', {
        Size = UDim2.new(1, -24, 0, 32),
        Position = UDim2.new(0, 12, 0, 52),
        BackgroundColor3 = Color3.fromRGB(60, 160, 60),
        BorderSizePixel = 0,
        Text = '▶  START FARM',
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 15,
        Font = Enum.Font.GothamBold,
        Parent = controlCard
    })
    Utils.addCorner(farmBtn, 6)
    
    farmBtn.MouseButton1Click:Connect(function()
        if not bosses then return end

        if bosses.farmEnabled then
            bosses.stopFarmLoop()
            farmBtn.Text = '▶  START FARM'
            farmBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 60)
        else
            bosses.startFarmLoop()
            farmBtn.Text = '⏹  STOP FARM'
            farmBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
        end
        persistBossToggles()
    end)

    -- Resume farm if it was enabled before re-inject
    if bosses and savedToggles and savedToggles.farmEnabled then
        bosses.startFarmLoop()
        farmBtn.Text = '⏹  STOP FARM'
        farmBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    end
    
    -- Status line
    statusLabel = Utils.create('TextLabel', {
        Size = UDim2.new(1, -24, 0, 16),
        Position = UDim2.new(0, 12, 0, 90),
        BackgroundTransparency = 1,
        Text = 'Idle',
        TextColor3 = T.TextMuted,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = controlCard
    })
    
    -- Kills counter
    killsLabel = Utils.create('TextLabel', {
        Size = UDim2.new(0, 100, 0, 16),
        Position = UDim2.new(1, -112, 0, 90),
        BackgroundTransparency = 1,
        Text = 'Visited: 0',
        TextColor3 = T.TextDim,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = controlCard
    })
    
    -- Players in server
    playersLabel = Utils.create('TextLabel', {
        Size = UDim2.new(1, -24, 0, 14),
        Position = UDim2.new(0, 12, 0, 108),
        BackgroundTransparency = 1,
        Text = '',
        TextColor3 = T.TextDim,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = controlCard
    })
    
    -- ====================================================================
    -- OPTIONS ROW: Bosses / Angels toggles
    -- ====================================================================
    
    local optY = 114
    
    -- Farm Bosses toggle
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 50, 0, 20),
        Position = UDim2.new(0, 12, 0, optY),
        BackgroundTransparency = 1,
        Text = 'Bosses',
        TextColor3 = T.TextDim,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = controlCard
    })
    
    local bossToggle = Utils.create('TextButton', {
        Size = UDim2.new(0, 36, 0, 18),
        Position = UDim2.new(0, 65, 0, optY + 1),
        BackgroundColor3 = (bosses and bosses.farmBosses) and Color3.fromRGB(60, 160, 60) or T.CardHover,
        BorderSizePixel = 0,
        Text = (bosses and bosses.farmBosses) and 'ON' or 'OFF',
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        Parent = controlCard
    })
    Utils.addCorner(bossToggle, 4)
    
    bossToggle.MouseButton1Click:Connect(function()
        if not bosses then return end
        bosses.farmBosses = not bosses.farmBosses
        bossToggle.Text = bosses.farmBosses and 'ON' or 'OFF'
        bossToggle.BackgroundColor3 = bosses.farmBosses and Color3.fromRGB(60, 160, 60) or T.CardHover
        persistBossToggles()
    end)
    
    -- Farm Angels toggle
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 50, 0, 20),
        Position = UDim2.new(0, 115, 0, optY),
        BackgroundTransparency = 1,
        Text = 'Angels',
        TextColor3 = T.TextDim,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = controlCard
    })
    
    local angelToggle = Utils.create('TextButton', {
        Size = UDim2.new(0, 36, 0, 18),
        Position = UDim2.new(0, 168, 0, optY + 1),
        BackgroundColor3 = (bosses and bosses.farmAngels) and Color3.fromRGB(60, 160, 60) or T.CardHover,
        BorderSizePixel = 0,
        Text = (bosses and bosses.farmAngels) and 'ON' or 'OFF',
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        Parent = controlCard
    })
    Utils.addCorner(angelToggle, 4)
    
    angelToggle.MouseButton1Click:Connect(function()
        if not bosses then return end
        bosses.farmAngels = not bosses.farmAngels
        angelToggle.Text = bosses.farmAngels and 'ON' or 'OFF'
        angelToggle.BackgroundColor3 = bosses.farmAngels and Color3.fromRGB(60, 160, 60) or T.CardHover
        persistBossToggles()
    end)
    
    -- ====================================================================
    -- WORLD RANGE ROW
    -- ====================================================================
    
    local rangeY = optY + 28
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 50, 0, 20),
        Position = UDim2.new(0, 12, 0, rangeY),
        BackgroundTransparency = 1,
        Text = 'Worlds',
        TextColor3 = T.TextDim,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = controlCard
    })
    
    local minBox = Utils.create('TextBox', {
        Size = UDim2.new(0, 30, 0, 18),
        Position = UDim2.new(0, 65, 0, rangeY + 1),
        BackgroundColor3 = T.CardHover,
        BorderSizePixel = 0,
        Text = tostring(bosses and bosses.farmMinWorld or 1),
        TextColor3 = T.Text,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        ClearTextOnFocus = false,
        Parent = controlCard
    })
    Utils.addCorner(minBox, 4)
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 20, 0, 20),
        Position = UDim2.new(0, 98, 0, rangeY),
        BackgroundTransparency = 1,
        Text = 'to',
        TextColor3 = T.TextMuted,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        Parent = controlCard
    })
    
    local maxBox = Utils.create('TextBox', {
        Size = UDim2.new(0, 30, 0, 18),
        Position = UDim2.new(0, 118, 0, rangeY + 1),
        BackgroundColor3 = T.CardHover,
        BorderSizePixel = 0,
        Text = tostring(bosses and bosses.farmMaxWorld or 30),
        TextColor3 = T.Text,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        ClearTextOnFocus = false,
        Parent = controlCard
    })
    Utils.addCorner(maxBox, 4)
    
    minBox.FocusLost:Connect(function()
        if not bosses then return end
        local val = tonumber(minBox.Text)
        if val and val >= 1 and val <= 30 then
            bosses.farmMinWorld = val
        else
            minBox.Text = tostring(bosses.farmMinWorld)
        end
        persistBossToggles()
    end)
    
    maxBox.FocusLost:Connect(function()
        if not bosses then return end
        local val = tonumber(maxBox.Text)
        if val and val >= 1 and val <= 30 then
            bosses.farmMaxWorld = val
        else
            maxBox.Text = tostring(bosses.farmMaxWorld)
        end
        persistBossToggles()
    end)
    
    -- Debug events button
    local debugBtn = Utils.create('TextButton', {
        Size = UDim2.new(0, 80, 0, 18),
        Position = UDim2.new(0, 220, 0, rangeY + 1),
        BackgroundColor3 = T.CardHover,
        BorderSizePixel = 0,
        Text = '🔍 Events',
        TextColor3 = T.TextMuted,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        Parent = controlCard
    })
    Utils.addCorner(debugBtn, 4)
    
    debugBtn.MouseButton1Click:Connect(function()
        if bosses then bosses.debugEvents() end
    end)
    
    -- Next Spawn button
    local spawnBtn = Utils.create('TextButton', {
        Size = UDim2.new(0, 90, 0, 18),
        Position = UDim2.new(0, 305, 0, rangeY + 1),
        BackgroundColor3 = T.CardHover,
        BorderSizePixel = 0,
        Text = 'Next Spawn',
        TextColor3 = T.TextMuted,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        Parent = controlCard
    })
    Utils.addCorner(spawnBtn, 4)
    
    spawnBtn.MouseButton1Click:Connect(function()
        if bosses then bosses.debugNextSpawn() end
    end)
    
    yOffset = yOffset + 194
    
    -- ========================================================================
    -- MANAGER INTEGRATION CARD
    -- ========================================================================
    
    local managerCard = Utils.createCard(panel, nil, 120, yOffset)
    
    Utils.createIcon(managerCard, '🔄', Color3.fromRGB(255, 180, 40), 30, UDim2.new(0, 12, 0, 8))
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 200, 0, 16),
        Position = UDim2.new(0, 50, 0, 8),
        BackgroundTransparency = 1,
        Text = 'MANAGER INTEGRATION',
        TextColor3 = Color3.fromRGB(255, 180, 40),
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = managerCard
    })
    
    Utils.create('TextLabel', {
        Size = UDim2.new(1, -60, 0, 12),
        Position = UDim2.new(0, 50, 0, 24),
        BackgroundTransparency = 1,
        Text = 'Auto-restart server when boss dies (requires roblox_manager.py)',
        TextColor3 = T.TextDim,
        TextSize = 10,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = managerCard
    })
    
    -- Auto-Restart toggle
    local restartY = 44
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 90, 0, 18),
        Position = UDim2.new(0, 12, 0, restartY),
        BackgroundTransparency = 1,
        Text = 'Auto-Restart',
        TextColor3 = T.TextDim,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = managerCard
    })
    
    local autoRestartToggle = Utils.create('TextButton', {
        Size = UDim2.new(0, 36, 0, 18),
        Position = UDim2.new(0, 105, 0, restartY),
        BackgroundColor3 = (bosses and bosses.autoRestartOnKill) and Color3.fromRGB(60, 160, 60) or T.CardHover,
        BorderSizePixel = 0,
        Text = (bosses and bosses.autoRestartOnKill) and 'ON' or 'OFF',
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        Parent = managerCard
    })
    Utils.addCorner(autoRestartToggle, 4)
    
    autoRestartToggle.MouseButton1Click:Connect(function()
        if not bosses then return end
        bosses.autoRestartOnKill = not bosses.autoRestartOnKill
        autoRestartToggle.Text = bosses.autoRestartOnKill and 'ON' or 'OFF'
        autoRestartToggle.BackgroundColor3 = bosses.autoRestartOnKill and Color3.fromRGB(60, 160, 60) or T.CardHover
        persistBossToggles()
    end)
    
    -- Auto-Farm-On-Join toggle
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 90, 0, 18),
        Position = UDim2.new(0, 160, 0, restartY),
        BackgroundTransparency = 1,
        Text = 'Auto-Start',
        TextColor3 = T.TextDim,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = managerCard
    })
    
    local autoFarmToggle = Utils.create('TextButton', {
        Size = UDim2.new(0, 36, 0, 18),
        Position = UDim2.new(0, 240, 0, restartY),
        BackgroundColor3 = (bosses and bosses.autoFarmOnJoin) and Color3.fromRGB(60, 160, 60) or T.CardHover,
        BorderSizePixel = 0,
        Text = (bosses and bosses.autoFarmOnJoin) and 'ON' or 'OFF',
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        Parent = managerCard
    })
    Utils.addCorner(autoFarmToggle, 4)
    
    autoFarmToggle.MouseButton1Click:Connect(function()
        if not bosses then return end
        bosses.autoFarmOnJoin = not bosses.autoFarmOnJoin
        autoFarmToggle.Text = bosses.autoFarmOnJoin and 'ON' or 'OFF'
        autoFarmToggle.BackgroundColor3 = bosses.autoFarmOnJoin and Color3.fromRGB(60, 160, 60) or T.CardHover
        persistBossToggles()
    end)
    
    -- Manual Restart Server button
    local manualRestartBtn = Utils.create('TextButton', {
        Size = UDim2.new(1, -24, 0, 26),
        Position = UDim2.new(0, 12, 0, 70),
        BackgroundColor3 = Color3.fromRGB(180, 80, 30),
        BorderSizePixel = 0,
        Text = '🔄  RESTART SERVER NOW',
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        Parent = managerCard
    })
    Utils.addCorner(manualRestartBtn, 5)
    
    manualRestartBtn.MouseEnter:Connect(function() manualRestartBtn.BackgroundColor3 = Color3.fromRGB(220, 100, 40) end)
    manualRestartBtn.MouseLeave:Connect(function() manualRestartBtn.BackgroundColor3 = Color3.fromRGB(180, 80, 30) end)
    
    manualRestartBtn.MouseButton1Click:Connect(function()
        if not bosses then return end
        manualRestartBtn.Text = '🔄  Restarting...'
        manualRestartBtn.BackgroundColor3 = Color3.fromRGB(120, 60, 20)
        task.spawn(function()
            bosses.restartCurrentServer(function()
                task.delay(3, function()
                    manualRestartBtn.Text = '🔄  RESTART SERVER NOW'
                    manualRestartBtn.BackgroundColor3 = Color3.fromRGB(180, 80, 30)
                end)
            end)
        end)
    end)
    
    -- Manager URL label
    Utils.create('TextLabel', {
        Size = UDim2.new(1, -24, 0, 12),
        Position = UDim2.new(0, 12, 0, 100),
        BackgroundTransparency = 1,
        Text = 'Manager: ' .. (bosses and bosses.managerUrl or "http://localhost:8080"),
        TextColor3 = T.TextDim,
        TextSize = 9,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = managerCard
    })
    
    yOffset = yOffset + 128
    
    -- ========================================================================
    -- SPAWN TIMERS CARD (now uses event system, not billboard)
    -- ========================================================================
    
    local timerCard = Utils.createCard(panel, nil, 70, yOffset)
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 100, 0, 16),
        Position = UDim2.new(0, 12, 0, 6),
        BackgroundTransparency = 1,
        Text = 'SPAWN TIMERS',
        TextColor3 = T.TextMuted,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = timerCard
    })
    
    -- Boss timer row
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 50, 0, 16),
        Position = UDim2.new(0, 12, 0, 26),
        BackgroundTransparency = 1,
        Text = '💀 Boss:',
        TextColor3 = Color3.fromRGB(255, 100, 100),
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = timerCard
    })
    
    bossTimerLabel = Utils.create('TextLabel', {
        Size = UDim2.new(1, -80, 0, 16),
        Position = UDim2.new(0, 68, 0, 26),
        BackgroundTransparency = 1,
        Text = '...',
        TextColor3 = T.Text,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = timerCard
    })
    
    -- Angel timer row
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 50, 0, 16),
        Position = UDim2.new(0, 12, 0, 46),
        BackgroundTransparency = 1,
        Text = '👼 Angel:',
        TextColor3 = Color3.fromRGB(80, 160, 255),
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = timerCard
    })
    
    angelTimerLabel = Utils.create('TextLabel', {
        Size = UDim2.new(1, -80, 0, 16),
        Position = UDim2.new(0, 68, 0, 46),
        BackgroundTransparency = 1,
        Text = '...',
        TextColor3 = T.Text,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = timerCard
    })
    
    yOffset = yOffset + 78
    
    -- ========================================================================
    -- MANUAL TP LIST
    -- ========================================================================
    
    local listHeader = Utils.createCard(panel, nil, 28, yOffset)
    listHeader.BackgroundColor3 = T.CardHover
    
    Utils.create('TextLabel', {
        Size = UDim2.new(1, -16, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
        BackgroundTransparency = 1,
        Text = 'MANUAL TELEPORT',
        TextColor3 = T.TextMuted,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = listHeader
    })
    
    yOffset = yOffset + 34
    
    -- ========================================================================
    -- WORLD ROWS (with inline spawn timers)
    -- ========================================================================
    
    local bossData = bosses and bosses.Data
    if not bossData then return end
    
    local rowHeight = 32
    
    -- Reset world timer labels for fresh build
    worldTimerLabels = {}
    
    for i, data in ipairs(bossData) do
        local worldNum = data.world
        
        local row = Utils.create('Frame', {
            Size = UDim2.new(1, 0, 0, rowHeight),
            Position = UDim2.new(0, 0, 0, yOffset),
            BackgroundColor3 = (i % 2 == 0) and T.Card or T.CardHover,
            BackgroundTransparency = (i % 2 == 0) and 0 or 0.5,
            BorderSizePixel = 0,
            Parent = panel
        })
        Utils.addCorner(row, 4)
        
        -- Color by tier
        local worldColor = T.TextDim
        if worldNum >= 25 then
            worldColor = Color3.fromRGB(255, 80, 80)
        elseif worldNum >= 16 then
            worldColor = Color3.fromRGB(255, 180, 0)
        elseif worldNum >= 7 then
            worldColor = Color3.fromRGB(100, 180, 255)
        end
        
        -- World name (narrower to fit inline timers)
        Utils.create('TextLabel', {
            Size = UDim2.new(0, 120, 1, 0),
            Position = UDim2.new(0, 8, 0, 0),
            BackgroundTransparency = 1,
            Text = worldNum .. '. ' .. data.spawn,
            TextColor3 = worldColor,
            TextSize = 13,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = row
        })
        
        -- Inline spawn timer: 💀 X:XX  👼 X:XX
        local timerLbl = Utils.create('TextLabel', {
            Size = UDim2.new(0, 160, 1, 0),
            Position = UDim2.new(0, 130, 0, 0),
            BackgroundTransparency = 1,
            Text = '\xF0\x9F\x92\x80 --:--  \xF0\x9F\x91\xBC --:--',
            TextColor3 = T.TextMuted,
            TextSize = 10,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = row
        })
        
        worldTimerLabels[worldNum] = timerLbl
        
        -- Boss button
        local bossBtn = Utils.create('TextButton', {
            Size = UDim2.new(0, 60, 0, 22),
            Position = UDim2.new(1, -132, 0.5, -11),
            BackgroundColor3 = Color3.fromRGB(180, 60, 60),
            BorderSizePixel = 0,
            Text = '💀 Boss',
            TextColor3 = Color3.new(1, 1, 1),
            TextSize = 12,
            Font = Enum.Font.GothamBold,
            Parent = row
        })
        Utils.addCorner(bossBtn, 4)
        
        -- Angel button
        local angelBtn = Utils.create('TextButton', {
            Size = UDim2.new(0, 64, 0, 22),
            Position = UDim2.new(1, -66, 0.5, -11),
            BackgroundColor3 = Color3.fromRGB(60, 120, 180),
            BorderSizePixel = 0,
            Text = '👼 Angel',
            TextColor3 = Color3.new(1, 1, 1),
            TextSize = 12,
            Font = Enum.Font.GothamBold,
            Parent = row
        })
        Utils.addCorner(angelBtn, 4)
        
        -- Hover
        bossBtn.MouseEnter:Connect(function() bossBtn.BackgroundColor3 = Color3.fromRGB(220, 80, 80) end)
        bossBtn.MouseLeave:Connect(function() bossBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60) end)
        angelBtn.MouseEnter:Connect(function() angelBtn.BackgroundColor3 = Color3.fromRGB(80, 150, 220) end)
        angelBtn.MouseLeave:Connect(function() angelBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 180) end)
        
        -- Clicks (manual TP runs in background, doesn't block UI)
        local wn = worldNum
        bossBtn.MouseButton1Click:Connect(function()
            if bosses then
                task.spawn(function() bosses.goToBoss(wn) end)
            end
        end)
        angelBtn.MouseButton1Click:Connect(function()
            if bosses then
                task.spawn(function() bosses.goToAngel(wn) end)
            end
        end)
        
        yOffset = yOffset + rowHeight + 2
    end
    
    panel.CanvasSize = UDim2.new(0, 0, 0, yOffset + 8)
end

function BossesTab.onShow()
    startStatusLoop()
end

return BossesTab
