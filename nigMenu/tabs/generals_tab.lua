--[[
    ============================================================================
    nigMenu - Generals Tab UI (Trait Re-roller)
    ============================================================================

    Auto-roll general traits until target rarity (S or SS) is achieved.
    Uses roulette system - rolls 5 options and picks the best one.
]]

local GeneralsTab = {}

-- Services
local RS = game:GetService("ReplicatedStorage")

-- Lazy load references
local function getNM() return _G.nigMenu end
local function getConfig() return _G.nigMenu and _G.nigMenu.Config end
local function getUtils() return _G.nigMenu and _G.nigMenu.Utils end

-- State
local selectedGeneralUUID = nil
local selectedGeneralName = nil
local targetRarity = "SS"
local isRolling = false

-- Roulette state
local pendingRewards = nil
local currentRouletteId = nil
local waitingForResult = false
local bridgeConnection = nil

-- Stats
local rollCount = 0
local startTime = 0
local rarityCount = { D = 0, C = 0, B = 0, A = 0, S = 0, SS = 0 }

-- Config
local ROLL_COUNT = 5
local ROLL_DELAY = 1.5
local PICK_DELAY = 0.5
local RESULT_TIMEOUT = 10

-- Rarity priority (higher = better)
local RARITY_PRIORITY = { D = 1, C = 2, B = 3, A = 4, S = 5, SS = 6 }

-- UI Labels
local statusLabel = nil
local rollsLabel = nil
local timeLabel = nil
local currentTraitLabel = nil
local distributionLabel = nil
local startStopBtn = nil
local generalsList = {}

-- TraitsService reference
local TraitsService = nil

-- ============================================================================
-- HELPERS
-- ============================================================================

local function loadTraitsService()
    if TraitsService then return true end

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

-- Decode trait from ID
local function decodeTrait(traitId)
    if not loadTraitsService() then return traitId, "?", "" end

    local ok, trait = pcall(function() return TraitsService.GetTraitById(traitId) end)
    if ok and trait then
        local name = pcall(function() return trait:GetName() end) and trait:GetName() or "?"
        local rarity = pcall(function() return trait:GetRarity() end) and trait:GetRarity() or "?"
        local desc = pcall(function() return trait:GetDescription() end) and trait:GetDescription() or ""
        return name, rarity, desc
    end
    return traitId, "?", ""
end

-- Extract rarity prefix from trait ID (e.g., SS_Damage -> SS)
local function getRarityFromId(traitId)
    local prefix = traitId:match("^(%a+)_")
    return prefix or "?"
end

-- ============================================================================
-- BRIDGE COMMUNICATION
-- ============================================================================

local function setupBridgeListener()
    if bridgeConnection then return end

    local Bridge = RS:FindFirstChild("Bridge")
    if not Bridge then
        warn("[Generals] Bridge not found!")
        return
    end

    bridgeConnection = Bridge.OnClientEvent:Connect(function(...)
        local args = {...}
        for _, arg in ipairs(args) do
            if type(arg) == "table" then
                for _, msg in ipairs(arg) do
                    if type(msg) == "table" and msg.moduleName == "SpinRoulette" and msg.functionName == "CreateByServer" then
                        if type(msg.info) == "table" then
                            for _, entry in ipairs(msg.info) do
                                if entry.rouletteId == "GeneralTraits" and entry.rewardList then
                                    currentRouletteId = entry.id
                                    pendingRewards = entry.rewardList
                                    waitingForResult = false
                                    print("[Generals] Received roulette:", currentRouletteId, "with", #pendingRewards, "options")
                                end
                            end
                        end
                    end
                end
            end
        end
    end)

    print("[Generals] Bridge listener setup complete")
end

local function doRoll(uuid)
    local Bridge = RS:FindFirstChild("Bridge")
    if not Bridge then
        warn("[Generals] Bridge not found!")
        return false
    end

    local payload = {
        generalId = uuid,
        count = ROLL_COUNT
    }

    local success, err = pcall(function()
        Bridge:FireServer("Traits", "RollGeneralTrait", payload)
    end)

    if not success then
        warn("[Generals] Roll failed:", err)
    end

    return success
end

local function doPick(rouletteId, slotIndex)
    local Bridge = RS:FindFirstChild("Bridge")
    if not Bridge then
        warn("[Generals] Bridge not found!")
        return false
    end

    local success, err = pcall(function()
        Bridge:FireServer("RouletteServer", "Pick", {
            id = rouletteId,
            rewardIndex = slotIndex
        })
    end)

    if not success then
        warn("[Generals] Pick failed:", err)
    end

    return success
end

-- ============================================================================
-- UI HELPERS
-- ============================================================================

local function formatTime(seconds)
    local mins = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%d:%02d", mins, secs)
end

local function getDistributionString()
    local parts = {}
    for _, r in ipairs({"D", "C", "B", "A", "S", "SS"}) do
        if rarityCount[r] > 0 then
            local pct = (rarityCount[r] / math.max(rollCount, 1)) * 100
            table.insert(parts, string.format("%s:%d (%.1f%%)", r, rarityCount[r], pct))
        end
    end
    return table.concat(parts, "  ")
end

local function updateUI()
    local Config = getConfig()

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

-- ============================================================================
-- ROLLING LOGIC
-- ============================================================================

local function startRolling()
    if not selectedGeneralUUID then
        print("[Generals] No general selected!")
        return
    end

    -- Setup bridge listener
    setupBridgeListener()

    print("[Generals] Starting trait roller for:", selectedGeneralName)
    print("[Generals] Target rarity:", targetRarity)
    print("[Generals] Rolling", ROLL_COUNT, "options per roll")

    isRolling = true
    rollCount = 0
    startTime = tick()
    rarityCount = { D = 0, C = 0, B = 0, A = 0, S = 0, SS = 0 }

    updateUI()

    task.spawn(function()
        local Config = getConfig()

        while isRolling and Config and Config.State.running do
            -- Reset state for this roll
            pendingRewards = nil
            currentRouletteId = nil
            waitingForResult = true

            rollCount = rollCount + 1
            print("[Generals] Roll #" .. rollCount .. "...")

            -- Fire the roll
            if not doRoll(selectedGeneralUUID) then
                print("[Generals] Roll failed, retrying...")
                task.wait(1)
                continue
            end

            -- Wait for roulette result
            local timeout = 0
            while waitingForResult or not pendingRewards do
                task.wait(0.1)
                timeout = timeout + 0.1
                if timeout > RESULT_TIMEOUT then
                    print("[Generals] Timeout waiting for roll result")
                    break
                end
                if not isRolling then return end
            end

            if not pendingRewards then
                print("[Generals] No rewards received, retrying...")
                task.wait(1)
                continue
            end

            -- Check all options for target rarity and track best available
            local targetSlot = nil
            local targetRarityFound = nil
            local bestSlot = nil
            local bestRarity = nil
            local bestPriority = 0

            print("[Generals] Checking", #pendingRewards, "options:")

            for idx, traitId in ipairs(pendingRewards) do
                local name, rarity, desc = decodeTrait(traitId)
                local rarityPrefix = getRarityFromId(traitId)
                local priority = RARITY_PRIORITY[rarityPrefix] or 0

                -- Track stats
                if rarityCount[rarityPrefix] then
                    rarityCount[rarityPrefix] = rarityCount[rarityPrefix] + 1
                end

                -- Track best available option
                if priority > bestPriority then
                    bestSlot = idx
                    bestRarity = rarityPrefix
                    bestPriority = priority
                end

                -- Check if this is our target
                local isTarget = false
                if targetRarity == "SS" and rarityPrefix == "SS" then
                    isTarget = true
                elseif targetRarity == "S" and (rarityPrefix == "S" or rarityPrefix == "SS") then
                    isTarget = true
                end

                if isTarget then
                    -- Prefer SS over S for target
                    if not targetSlot then
                        targetSlot = idx
                        targetRarityFound = rarityPrefix
                    elseif rarityPrefix == "SS" and targetRarityFound ~= "SS" then
                        targetSlot = idx
                        targetRarityFound = rarityPrefix
                    end
                    print(string.format("  [%d] %s [%s] <<< TARGET", idx, name, rarity))
                else
                    print(string.format("  [%d] %s [%s]", idx, name, rarity))
                end
            end

            if targetSlot then
                -- Found target - pick it and stop!
                local name, rarity, _ = decodeTrait(pendingRewards[targetSlot])
                print("[Generals] PICKING SLOT", targetSlot, ":", name, "[" .. rarity .. "]")

                task.wait(PICK_DELAY)
                doPick(currentRouletteId, targetSlot)

                local elapsed = tick() - startTime
                print("=====================================")
                print("SUCCESS! GOT " .. targetRarityFound .. " TIER!")
                print("=====================================")
                print("Trait:", name)
                print("Rarity:", rarity)
                print("Total Rolls:", rollCount)
                print("Time:", formatTime(elapsed))
                print("=====================================")

                -- Update status
                if statusLabel and statusLabel.Parent then
                    statusLabel.Text = "FOUND " .. targetRarityFound .. "!"
                    statusLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
                end

                isRolling = false
                updateUI()
                return
            else
                -- No target found - pick best available and continue
                print("[Generals] No S/SS found, picking best option (slot " .. bestSlot .. ", " .. bestRarity .. ") and continuing...")
                task.wait(PICK_DELAY)
                doPick(currentRouletteId, bestSlot)
                task.wait(ROLL_DELAY)
            end

            updateUI()
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
        Text = 'Rolls 5 options, picks best S/SS trait',
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
        Text = 'Rolls 5 traits per attempt and picks best one.\nS target accepts both S and SS traits.\nSS target only accepts SS traits.',
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

function GeneralsTab.cleanup()
    -- Disconnect bridge listener
    if bridgeConnection then
        bridgeConnection:Disconnect()
        bridgeConnection = nil
    end
    isRolling = false
end

return GeneralsTab
