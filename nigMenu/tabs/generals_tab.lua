--[[
    ============================================================================
    nigMenu - Generals Tab UI (Trait Re-roller)
    ============================================================================

    Auto-roll general traits until target rarity (S or SS) is achieved.
    - Select a general
    - Select target rarity
    - Start/Stop rolling
    - View stats and progress
]]

local GeneralsTab = {}

-- Lazy load references
local function getNM() return _G.nigMenu end
local function getConfig() return _G.nigMenu and _G.nigMenu.Config end
local function getUtils() return _G.nigMenu and _G.nigMenu.Utils end
local function getBridge()
    local Config = getConfig()
    return Config and Config.Bridge
end

-- UI references
local selectedGeneralUUID = nil
local selectedGeneralName = nil
local targetRarity = "SS"
local isRolling = false

-- Stats
local rollCount = 0
local startTime = 0
local rarityCount = { D = 0, C = 0, B = 0, A = 0, S = 0, SS = 0 }

-- UI Labels
local statusLabel = nil
local rollsLabel = nil
local timeLabel = nil
local currentTraitLabel = nil
local distributionLabel = nil
local startStopBtn = nil
local generalsList = {}

-- TraitsService reference (loaded at runtime)
local TraitsService = nil

-- ============================================================================
-- HELPERS
-- ============================================================================

local function loadTraitsService()
    if TraitsService then return true end

    local RS = game:GetService("ReplicatedStorage")
    local sm = RS:FindFirstChild("SharedModules")
    if sm then
        local ts = sm:FindFirstChild("TraitsService")
        if ts then
            local success, result = pcall(function()
                return require(ts)
            end)
            if success then
                TraitsService = result
                return true
            end
        end
    end
    return false
end

local function getMetaService()
    local Utils = getUtils()
    return Utils and Utils.getMetaService()
end

local function getCurrentTrait(uuid)
    if not loadTraitsService() then return nil, nil, nil end

    local MS = getMetaService()
    if not MS or not MS.Data or not MS.Data.Generals then return nil, nil, nil end

    local generalData = MS.Data.Generals[uuid]
    if not generalData then return nil, nil, nil end

    if generalData.Traits and generalData.Traits[1] then
        local traitId = generalData.Traits[1]
        local trait = TraitsService.GetTraitById(traitId)
        if trait then
            return trait:GetRarity(), trait:GetName(), traitId
        end
    end

    return nil, nil, nil
end

local function rollTrait(uuid)
    local payload = {
        generalId = uuid,
        count = 1
    }

    print("[Generals] rollTrait called with UUID:", uuid)
    print("[Generals] Payload:", game:GetService("HttpService"):JSONEncode(payload))

    -- Always use direct ReplicatedStorage.Bridge access
    local RS = game:GetService("ReplicatedStorage")
    local Bridge = RS:WaitForChild("Bridge", 5)

    if Bridge then
        print("[Generals] Bridge found:", tostring(Bridge))
        print("[Generals] Firing: Traits, RollGeneralTrait, payload...")

        local success, err = pcall(function()
            Bridge:FireServer("Traits", "RollGeneralTrait", payload)
        end)

        if success then
            print("[Generals] FireServer call succeeded!")
        else
            warn("[Generals] FireServer FAILED:", tostring(err))
        end
    else
        warn("[Generals] Bridge NOT FOUND in ReplicatedStorage!")

        -- List what's in ReplicatedStorage for debugging
        print("[Generals] ReplicatedStorage children:")
        for _, child in ipairs(RS:GetChildren()) do
            print("  -", child.Name, "(" .. child.ClassName .. ")")
        end
    end
end

local function hideRouletteUI()
    -- Only hide the roulette popup, don't modify any modules
    pcall(function()
        local player = game:GetService("Players").LocalPlayer
        local rouletteGui = player.PlayerGui:FindFirstChild("RouletteRoll")
        if rouletteGui then
            rouletteGui.Enabled = false
        end
    end)
end

local function formatTime(seconds)
    local mins = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%d:%02d", mins, secs)
end

local function getDistributionString()
    local parts = {}
    for _, r in ipairs({"D", "C", "B", "A", "S", "SS"}) do
        if rarityCount[r] > 0 then
            local pct = (rarityCount[r] / rollCount) * 100
            table.insert(parts, string.format("%s:%d (%.1f%%)", r, rarityCount[r], pct))
        end
    end
    return table.concat(parts, "  ")
end

local function updateUI()
    if statusLabel and statusLabel.Parent then
        if isRolling then
            statusLabel.Text = "Rolling..."
            statusLabel.TextColor3 = Color3.fromRGB(80, 255, 80)
        else
            statusLabel.Text = selectedGeneralName and ("Selected: " .. selectedGeneralName) or "Select a general"
            statusLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
        end
    end

    if rollsLabel and rollsLabel.Parent then
        rollsLabel.Text = "Rolls: " .. rollCount
    end

    if timeLabel and timeLabel.Parent then
        if isRolling or rollCount > 0 then
            local elapsed = isRolling and (tick() - startTime) or (rollCount > 0 and (tick() - startTime) or 0)
            timeLabel.Text = "Time: " .. formatTime(elapsed)
        else
            timeLabel.Text = "Time: 0:00"
        end
    end

    if currentTraitLabel and currentTraitLabel.Parent and selectedGeneralUUID then
        local rarity, name, _ = getCurrentTrait(selectedGeneralUUID)
        if rarity and name then
            currentTraitLabel.Text = "Current: " .. rarity .. " - " .. name

            -- Color based on rarity
            local colors = {
                D = Color3.fromRGB(150, 150, 150),
                C = Color3.fromRGB(100, 200, 100),
                B = Color3.fromRGB(100, 150, 255),
                A = Color3.fromRGB(200, 100, 255),
                S = Color3.fromRGB(255, 200, 50),
                SS = Color3.fromRGB(255, 80, 80)
            }
            currentTraitLabel.TextColor3 = colors[rarity] or Color3.fromRGB(200, 200, 200)
        else
            currentTraitLabel.Text = "Current: Unknown"
            currentTraitLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        end
    end

    if distributionLabel and distributionLabel.Parent then
        distributionLabel.Text = getDistributionString()
    end

    if startStopBtn and startStopBtn.Parent then
        if isRolling then
            startStopBtn.Text = "STOP"
            startStopBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
        else
            startStopBtn.Text = "START"
            startStopBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 60)
        end
    end
end

local function selectGeneral(uuid, name, btn)
    local Config = getConfig()
    local T = Config and Config.Theme

    -- Toggle: if clicking already selected general, deselect it
    if selectedGeneralUUID == uuid then
        selectedGeneralUUID = nil
        selectedGeneralName = nil
    else
        selectedGeneralUUID = uuid
        selectedGeneralName = name
    end

    -- Update button visual states
    for _, info in pairs(generalsList) do
        if info.btn and info.btn.Parent then
            if info.uuid == selectedGeneralUUID then
                info.btn.BackgroundColor3 = Color3.fromRGB(60, 160, 60)
                info.btn.Text = "Selected"
            else
                info.btn.BackgroundColor3 = T and T.CardHover or Color3.fromRGB(50, 50, 60)
                info.btn.Text = "Select"
            end
        end
    end

    updateUI()
end

local function startRolling()
    if not selectedGeneralUUID then
        print("[Generals] No general selected!")
        return
    end

    print("[Generals] Starting trait roller for UUID: " .. selectedGeneralUUID)
    print("[Generals] Target rarity: " .. targetRarity)

    isRolling = true
    rollCount = 0
    startTime = tick()
    rarityCount = { D = 0, C = 0, B = 0, A = 0, S = 0, SS = 0 }

    hideRouletteUI()
    updateUI()

    task.spawn(function()
        local Config = getConfig()

        print("[Generals] Rolling loop started...")

        while isRolling and Config and Config.State.running do
            -- Roll the trait
            print("[Generals] Rolling #" .. (rollCount + 1) .. "...")
            rollTrait(selectedGeneralUUID)
            rollCount = rollCount + 1

            -- Wait for server response
            task.wait(1)

            -- Hide UI again in case it re-appeared
            hideRouletteUI()

            -- Check the result
            local rarity, name, _ = getCurrentTrait(selectedGeneralUUID)

            if rarity and name then
                rarityCount[rarity] = (rarityCount[rarity] or 0) + 1

                -- Directly update the current trait label with fresh data
                if currentTraitLabel and currentTraitLabel.Parent then
                    currentTraitLabel.Text = "Current: " .. rarity .. " - " .. name
                    local colors = {
                        D = Color3.fromRGB(150, 150, 150),
                        C = Color3.fromRGB(100, 200, 100),
                        B = Color3.fromRGB(100, 150, 255),
                        A = Color3.fromRGB(200, 100, 255),
                        S = Color3.fromRGB(255, 200, 50),
                        SS = Color3.fromRGB(255, 80, 80)
                    }
                    currentTraitLabel.TextColor3 = colors[rarity] or Color3.fromRGB(200, 200, 200)
                end

                -- Check if we hit target
                local hitTarget = false
                if targetRarity == "SS" and rarity == "SS" then
                    hitTarget = true
                elseif targetRarity == "S" and (rarity == "S" or rarity == "SS") then
                    hitTarget = true
                end

                if hitTarget then
                    local elapsed = tick() - startTime
                    isRolling = false

                    print("=====================================")
                    print("SUCCESS! GOT " .. rarity .. " TIER!")
                    print("=====================================")
                    print("Trait:", name)
                    print("Rarity:", rarity)
                    print("Total Rolls:", rollCount)
                    print("Time:", formatTime(elapsed))
                    print("=====================================")
                end

                -- Progress update every 25 rolls
                if rollCount % 25 == 0 then
                    local elapsed = tick() - startTime
                    local rps = rollCount / elapsed
                    print(string.format("[Generals] %d rolls | %.1f rolls/sec | Current: %s-%s",
                        rollCount, rps, rarity, name))
                end
            else
                -- If we couldn't read the trait, show that
                if currentTraitLabel and currentTraitLabel.Parent then
                    currentTraitLabel.Text = "Current: Reading..."
                    currentTraitLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
                end
            end

            updateUI()
            task.wait(0.1)
        end

        isRolling = false
        updateUI()
    end)
end

local function stopRolling()
    isRolling = false
    updateUI()
end

-- ============================================================================
-- INIT
-- ============================================================================

function GeneralsTab.init()
    local Config = getConfig()
    local Utils = getUtils()
    local NM = getNM()

    if not Config or not Utils then return end

    local panel = Config.UI.Tabs['Generals']
    if not panel then return end

    local T = Config.Theme
    local yOffset = 0

    -- ========================================================================
    -- TRAIT REROLLER CARD
    -- ========================================================================

    local mainCard = Utils.createCard(panel, nil, 200, yOffset)

    Utils.createIcon(mainCard, '🎲', Color3.fromRGB(200, 100, 255), 40, UDim2.new(0, 12, 0, 10))

    Utils.create('TextLabel', {
        Size = UDim2.new(0, 200, 0, 20),
        Position = UDim2.new(0, 60, 0, 10),
        BackgroundTransparency = 1,
        Text = 'TRAIT REROLLER',
        TextColor3 = Color3.fromRGB(200, 100, 255),
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = mainCard
    })

    Utils.create('TextLabel', {
        Size = UDim2.new(0, 300, 0, 14),
        Position = UDim2.new(0, 60, 0, 30),
        BackgroundTransparency = 1,
        Text = 'Auto-roll traits until target rarity is achieved',
        TextColor3 = T.TextMuted,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = mainCard
    })

    -- Status line
    statusLabel = Utils.create('TextLabel', {
        Size = UDim2.new(1, -24, 0, 16),
        Position = UDim2.new(0, 12, 0, 52),
        BackgroundTransparency = 1,
        Text = 'Select a general',
        TextColor3 = T.TextMuted,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = mainCard
    })

    -- Current trait display
    currentTraitLabel = Utils.create('TextLabel', {
        Size = UDim2.new(1, -24, 0, 16),
        Position = UDim2.new(0, 12, 0, 70),
        BackgroundTransparency = 1,
        Text = 'Current: --',
        TextColor3 = T.TextDim,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = mainCard
    })

    -- TARGET RARITY ROW
    local targetY = 94

    Utils.create('TextLabel', {
        Size = UDim2.new(0, 100, 0, 20),
        Position = UDim2.new(0, 12, 0, targetY),
        BackgroundTransparency = 1,
        Text = 'Target Rarity:',
        TextColor3 = T.TextDim,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = mainCard
    })

    -- S Button
    local sBtn = Utils.create('TextButton', {
        Size = UDim2.new(0, 50, 0, 22),
        Position = UDim2.new(0, 115, 0, targetY - 1),
        BackgroundColor3 = T.CardHover,
        BorderSizePixel = 0,
        Text = 'S',
        TextColor3 = Color3.fromRGB(255, 200, 50),
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        Parent = mainCard
    })
    Utils.addCorner(sBtn, 4)

    -- SS Button
    local ssBtn = Utils.create('TextButton', {
        Size = UDim2.new(0, 50, 0, 22),
        Position = UDim2.new(0, 170, 0, targetY - 1),
        BackgroundColor3 = Color3.fromRGB(60, 160, 60),
        BorderSizePixel = 0,
        Text = 'SS',
        TextColor3 = Color3.fromRGB(255, 80, 80),
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        Parent = mainCard
    })
    Utils.addCorner(ssBtn, 4)

    sBtn.MouseButton1Click:Connect(function()
        targetRarity = "S"
        sBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 60)
        ssBtn.BackgroundColor3 = T.CardHover
    end)

    ssBtn.MouseButton1Click:Connect(function()
        targetRarity = "SS"
        ssBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 60)
        sBtn.BackgroundColor3 = T.CardHover
    end)

    -- STATS ROW
    local statsY = 122

    rollsLabel = Utils.create('TextLabel', {
        Size = UDim2.new(0, 100, 0, 16),
        Position = UDim2.new(0, 12, 0, statsY),
        BackgroundTransparency = 1,
        Text = 'Rolls: 0',
        TextColor3 = T.TextDim,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = mainCard
    })

    timeLabel = Utils.create('TextLabel', {
        Size = UDim2.new(0, 100, 0, 16),
        Position = UDim2.new(0, 120, 0, statsY),
        BackgroundTransparency = 1,
        Text = 'Time: 0:00',
        TextColor3 = T.TextDim,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = mainCard
    })

    -- Distribution label
    distributionLabel = Utils.create('TextLabel', {
        Size = UDim2.new(1, -24, 0, 14),
        Position = UDim2.new(0, 12, 0, statsY + 20),
        BackgroundTransparency = 1,
        Text = '',
        TextColor3 = T.TextMuted,
        TextSize = 10,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = mainCard
    })

    -- START/STOP Button
    startStopBtn = Utils.create('TextButton', {
        Size = UDim2.new(1, -24, 0, 32),
        Position = UDim2.new(0, 12, 0, 162),
        BackgroundColor3 = Color3.fromRGB(60, 160, 60),
        BorderSizePixel = 0,
        Text = 'START',
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 15,
        Font = Enum.Font.GothamBold,
        Parent = mainCard
    })
    Utils.addCorner(startStopBtn, 6)

    startStopBtn.MouseButton1Click:Connect(function()
        if isRolling then
            stopRolling()
        else
            startRolling()
        end
    end)

    yOffset = yOffset + 208

    -- ========================================================================
    -- GENERALS LIST CARD
    -- ========================================================================

    local listCard = Utils.createCard(panel, nil, 220, yOffset)

    Utils.create('TextLabel', {
        Size = UDim2.new(0, 200, 0, 16),
        Position = UDim2.new(0, 12, 0, 8),
        BackgroundTransparency = 1,
        Text = 'SELECT GENERAL',
        TextColor3 = T.TextMuted,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = listCard
    })

    local scroll = Utils.create('ScrollingFrame', {
        Size = UDim2.new(1, -16, 1, -32),
        Position = UDim2.new(0, 8, 0, 28),
        BackgroundTransparency = 1,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = T.Border,
        CanvasSize = UDim2.new(0, 0, 0, 10),
        Parent = listCard
    })

    -- Populate generals
    local generals = {}
    if NM and NM.Features and NM.Features.generals then
        generals = NM.Features.generals.getAll()
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
    else
        scroll.CanvasSize = UDim2.new(0, 0, 0, #generals * 30)
        generalsList = {}

        for i, general in ipairs(generals) do
            local row = Utils.create('Frame', {
                Size = UDim2.new(1, -8, 0, 28),
                Position = UDim2.new(0, 0, 0, (i - 1) * 30),
                BackgroundTransparency = 1,
                Parent = scroll
            })

            -- Name label
            Utils.create('TextLabel', {
                Size = UDim2.new(1, -80, 1, 0),
                BackgroundTransparency = 1,
                Text = general.name .. ' (Lv.' .. general.level .. ')',
                TextColor3 = T.Text,
                TextSize = 13,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = row
            })

            -- Select button
            local btn = Utils.createSmallButton(row, 'Select', -10, 4, 70, T.CardHover)

            local uuid = general.uuid
            local name = general.name

            table.insert(generalsList, { uuid = uuid, btn = btn })

            btn.MouseButton1Click:Connect(function()
                selectGeneral(uuid, name, btn)
            end)
        end
    end

    yOffset = yOffset + 228

    -- ========================================================================
    -- INFO CARD
    -- ========================================================================

    local infoCard = Utils.createCard(panel, nil, 60, yOffset)

    Utils.create('TextLabel', {
        Size = UDim2.new(1, -20, 0, 50),
        Position = UDim2.new(0, 12, 0, 6),
        BackgroundTransparency = 1,
        Text = 'Rolls traits rapidly until target rarity achieved.\nS target accepts both S and SS traits.\nSS target only accepts SS traits.',
        TextColor3 = T.TextDim,
        TextSize = 10,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        Parent = infoCard
    })

    yOffset = yOffset + 68

    panel.CanvasSize = UDim2.new(0, 0, 0, yOffset + 8)
end

function GeneralsTab.onShow()
    updateUI()

    -- Refresh current trait display
    if selectedGeneralUUID then
        local rarity, name, _ = getCurrentTrait(selectedGeneralUUID)
        if currentTraitLabel and currentTraitLabel.Parent and rarity and name then
            currentTraitLabel.Text = "Current: " .. rarity .. " - " .. name
        end
    end
end

return GeneralsTab
