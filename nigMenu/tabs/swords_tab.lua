--[[
    ============================================================================
    nigMenu - Swords Tab UI
    ============================================================================

    All sword-related features in one place:
    - Sword Enchanting (auto-enchant)
    - Sword Trait Re-roller (roulette-based, 5 options)
    - Sword Splitter (split for dust)
]]

local SwordsTab = {}

-- Services
local RS = game:GetService("ReplicatedStorage")

-- Lazy load references
local function getNM() return _G.nigMenu end
local function getConfig() return _G.nigMenu and _G.nigMenu.Config end
local function getUtils() return _G.nigMenu and _G.nigMenu.Utils end

-- ============================================================================
-- TRAIT REROLLER STATE
-- ============================================================================

local selectedSwordName = nil
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
local rerollerStatusLabel = nil
local rerollerRollsLabel = nil
local rerollerTimeLabel = nil
local rerollerCurrentLabel = nil
local rerollerStartStopBtn = nil
local swordsList = {}

-- TraitsService reference
local TraitsService = nil

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
-- TRAIT REROLLER HELPERS
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

local function getRarityFromId(traitId)
    local prefix = traitId:match("^(%a+)_")
    return prefix or "?"
end

local function formatTime(seconds)
    local mins = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%d:%02d", mins, secs)
end

-- ============================================================================
-- BRIDGE COMMUNICATION FOR REROLLER
-- ============================================================================

local function setupBridgeListener()
    if bridgeConnection then return end

    local Bridge = RS:FindFirstChild("Bridge")
    if not Bridge then
        warn("[Swords] Bridge not found!")
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
                                if entry.rouletteId == "SwordTraits" and entry.rewardList then
                                    currentRouletteId = entry.id
                                    pendingRewards = entry.rewardList
                                    waitingForResult = false
                                    print("[Swords] Received roulette:", currentRouletteId, "with", #pendingRewards, "options")
                                end
                            end
                        end
                    end
                end
            end
        end
    end)

    print("[Swords] Bridge listener setup complete")
end

local function doRoll(swordName)
    local Bridge = RS:FindFirstChild("Bridge")
    if not Bridge then
        warn("[Swords] Bridge not found!")
        return false
    end

    local payload = {
        swordName = swordName,
        count = ROLL_COUNT
    }

    local success, err = pcall(function()
        Bridge:FireServer("Traits", "RollSwordTrait", payload)
    end)

    if not success then
        warn("[Swords] Roll failed:", err)
    end

    return success
end

local function doPick(rouletteId, slotIndex)
    local Bridge = RS:FindFirstChild("Bridge")
    if not Bridge then
        warn("[Swords] Bridge not found!")
        return false
    end

    local success, err = pcall(function()
        Bridge:FireServer("RouletteServer", "Pick", {
            id = rouletteId,
            rewardIndex = slotIndex
        })
    end)

    if not success then
        warn("[Swords] Pick failed:", err)
    end

    return success
end

-- ============================================================================
-- REROLLER UI UPDATE
-- ============================================================================

local function updateRerollerUI()
    local Config = getConfig()
    local T = Config and Config.Theme

    if rerollerStatusLabel and rerollerStatusLabel.Parent then
        if isRolling then
            rerollerStatusLabel.Text = "Rolling..."
            rerollerStatusLabel.TextColor3 = Color3.fromRGB(80, 255, 80)
        else
            rerollerStatusLabel.Text = selectedSwordName and ("Selected: " .. selectedSwordName) or "Select a sword"
            rerollerStatusLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
        end
    end

    if rerollerRollsLabel and rerollerRollsLabel.Parent then
        rerollerRollsLabel.Text = "Rolls: " .. rollCount
    end

    if rerollerTimeLabel and rerollerTimeLabel.Parent then
        if isRolling or rollCount > 0 then
            local elapsed = isRolling and (tick() - startTime) or (rollCount > 0 and (tick() - startTime) or 0)
            rerollerTimeLabel.Text = "Time: " .. formatTime(elapsed)
        else
            rerollerTimeLabel.Text = "Time: 0:00"
        end
    end

    if rerollerStartStopBtn and rerollerStartStopBtn.Parent then
        if isRolling then
            rerollerStartStopBtn.Text = "STOP"
            rerollerStartStopBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
        else
            rerollerStartStopBtn.Text = "START"
            rerollerStartStopBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 60)
        end
    end
end

local function selectSword(name, btn)
    local Config = getConfig()
    local T = Config and Config.Theme

    if selectedSwordName == name then
        selectedSwordName = nil
    else
        selectedSwordName = name
    end

    for _, info in pairs(swordsList) do
        if info.btn and info.btn.Parent then
            if info.name == selectedSwordName then
                info.btn.BackgroundColor3 = Color3.fromRGB(60, 160, 60)
                info.btn.Text = "Selected"
            else
                info.btn.BackgroundColor3 = T and T.CardHover or Color3.fromRGB(50, 50, 60)
                info.btn.Text = "Select"
            end
        end
    end

    updateRerollerUI()
end

-- ============================================================================
-- REROLLER ROLLING LOGIC
-- ============================================================================

local function startRolling()
    if not selectedSwordName then
        print("[Swords] No sword selected!")
        return
    end

    setupBridgeListener()

    print("[Swords] Starting trait roller for:", selectedSwordName)
    print("[Swords] Target rarity:", targetRarity)

    isRolling = true
    rollCount = 0
    startTime = tick()
    rarityCount = { D = 0, C = 0, B = 0, A = 0, S = 0, SS = 0 }

    updateRerollerUI()

    task.spawn(function()
        local Config = getConfig()

        while isRolling and Config and Config.State.running do
            pendingRewards = nil
            currentRouletteId = nil
            waitingForResult = true

            rollCount = rollCount + 1
            print("[Swords] Roll #" .. rollCount .. "...")

            if not doRoll(selectedSwordName) then
                print("[Swords] Roll failed, retrying...")
                task.wait(1)
                continue
            end

            local timeout = 0
            while waitingForResult or not pendingRewards do
                task.wait(0.1)
                timeout = timeout + 0.1
                if timeout > RESULT_TIMEOUT then
                    print("[Swords] Timeout waiting for roll result")
                    break
                end
                if not isRolling then return end
            end

            if not pendingRewards then
                print("[Swords] No rewards received, retrying...")
                task.wait(1)
                continue
            end

            -- Check all options for target rarity and track best available
            local targetSlot = nil
            local targetRarityFound = nil
            local bestSlot = nil
            local bestRarity = nil
            local bestPriority = 0

            for idx, traitId in ipairs(pendingRewards) do
                local name, rarity, desc = decodeTrait(traitId)
                local rarityPrefix = getRarityFromId(traitId)
                local priority = RARITY_PRIORITY[rarityPrefix] or 0

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
                end
            end

            if targetSlot then
                -- Found target - pick it and stop!
                local name, rarity, _ = decodeTrait(pendingRewards[targetSlot])
                print("[Swords] PICKING SLOT", targetSlot, ":", name, "[" .. rarity .. "]")

                task.wait(PICK_DELAY)
                doPick(currentRouletteId, targetSlot)

                local elapsed = tick() - startTime
                print("=====================================")
                print("SUCCESS! GOT " .. targetRarityFound .. " TIER!")
                print("Trait:", name)
                print("Total Rolls:", rollCount)
                print("Time:", formatTime(elapsed))
                print("=====================================")

                if rerollerStatusLabel and rerollerStatusLabel.Parent then
                    rerollerStatusLabel.Text = "FOUND " .. targetRarityFound .. "!"
                    rerollerStatusLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
                end

                isRolling = false
                updateRerollerUI()
                return
            else
                -- No target found - pick best available and continue
                print("[Swords] No S/SS found, picking best option (slot " .. bestSlot .. ", " .. bestRarity .. ") and continuing...")
                task.wait(PICK_DELAY)
                doPick(currentRouletteId, bestSlot)
                task.wait(ROLL_DELAY)
            end

            updateRerollerUI()
        end

        isRolling = false
        updateRerollerUI()
    end)
end

local function stopRolling()
    isRolling = false
    updateRerollerUI()
end

-- ============================================================================
-- BUILD SECTIONS
-- ============================================================================

local function buildEnchantsSection(parent, yOffset)
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
        Text = 'Auto-enchant swords',
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

local function buildRerollerSection(parent, yOffset)
    local Utils = getUtils()
    local Config = getConfig()
    if not Utils or not Config then return nil, 0 end

    local T = Config.Theme
    local card = Utils.createCard(parent, nil, 200, yOffset)

    Utils.createIcon(card, '🎲', Color3.fromRGB(200, 100, 255), 40, UDim2.new(0, 12, 0, 10))

    Utils.create('TextLabel', {
        Size = UDim2.new(0, 200, 0, 20),
        Position = UDim2.new(0, 60, 0, 10),
        BackgroundTransparency = 1,
        Text = 'SWORD TRAIT REROLLER',
        TextColor3 = Color3.fromRGB(200, 100, 255),
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card
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
        Parent = card
    })

    rerollerStatusLabel = Utils.create('TextLabel', {
        Size = UDim2.new(1, -24, 0, 16),
        Position = UDim2.new(0, 12, 0, 52),
        BackgroundTransparency = 1,
        Text = 'Select a sword below',
        TextColor3 = T.TextMuted,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card
    })

    -- Target Rarity Row
    local targetY = 76

    Utils.create('TextLabel', {
        Size = UDim2.new(0, 100, 0, 20),
        Position = UDim2.new(0, 12, 0, targetY),
        BackgroundTransparency = 1,
        Text = 'Target:',
        TextColor3 = T.TextDim,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card
    })

    local sBtn = Utils.create('TextButton', {
        Size = UDim2.new(0, 40, 0, 20),
        Position = UDim2.new(0, 70, 0, targetY),
        BackgroundColor3 = T.CardHover,
        BorderSizePixel = 0,
        Text = 'S',
        TextColor3 = Color3.fromRGB(255, 200, 50),
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        Parent = card
    })
    Utils.addCorner(sBtn, 4)

    local ssBtn = Utils.create('TextButton', {
        Size = UDim2.new(0, 40, 0, 20),
        Position = UDim2.new(0, 115, 0, targetY),
        BackgroundColor3 = Color3.fromRGB(60, 160, 60),
        BorderSizePixel = 0,
        Text = 'SS',
        TextColor3 = Color3.fromRGB(255, 80, 80),
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        Parent = card
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

    -- Stats Row
    rerollerRollsLabel = Utils.create('TextLabel', {
        Size = UDim2.new(0, 80, 0, 14),
        Position = UDim2.new(0, 170, 0, targetY + 3),
        BackgroundTransparency = 1,
        Text = 'Rolls: 0',
        TextColor3 = T.TextDim,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card
    })

    rerollerTimeLabel = Utils.create('TextLabel', {
        Size = UDim2.new(0, 80, 0, 14),
        Position = UDim2.new(0, 250, 0, targetY + 3),
        BackgroundTransparency = 1,
        Text = 'Time: 0:00',
        TextColor3 = T.TextDim,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card
    })

    -- Sword selection scroll
    local scroll = Utils.create('ScrollingFrame', {
        Size = UDim2.new(1, -24, 0, 60),
        Position = UDim2.new(0, 12, 0, 100),
        BackgroundColor3 = T.BgCard,
        BackgroundTransparency = 0.5,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = T.Border,
        CanvasSize = UDim2.new(0, 0, 0, 10),
        Parent = card
    })
    Utils.addCorner(scroll, 4)
    Config.UI.SwordRerollerScroll = scroll

    -- Start/Stop Button
    rerollerStartStopBtn = Utils.create('TextButton', {
        Size = UDim2.new(1, -24, 0, 28),
        Position = UDim2.new(0, 12, 0, 166),
        BackgroundColor3 = Color3.fromRGB(60, 160, 60),
        BorderSizePixel = 0,
        Text = 'START',
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        Parent = card
    })
    Utils.addCorner(rerollerStartStopBtn, 6)

    rerollerStartStopBtn.MouseButton1Click:Connect(function()
        if isRolling then
            stopRolling()
        else
            startRolling()
        end
    end)

    return card, 208
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

local function populateEnchants()
    local Config = getConfig()
    local Utils = getUtils()
    local NM = getNM()

    if not Config or not Utils then return end

    local scroll = Config.UI.SwordsScroll
    if not scroll then return end

    local T = Config.Theme

    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA('Frame') or child:IsA('TextLabel') then
            child:Destroy()
        end
    end

    if NM and NM.Features and NM.Features.swords then
        NM.Features.swords.stopAllRainbows()
    end

    Config.UI.SwordLevelLabels = {}

    local swords = {}
    if NM and NM.Features and NM.Features.swords then
        swords = NM.Features.swords.getAll()
    end

    if #swords == 0 then
        Utils.create('TextLabel', {
            Size = UDim2.new(1, -16, 0, 100),
            Position = UDim2.new(0, 8, 0, 0),
            BackgroundTransparency = 1,
            Text = 'No swords found',
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

local function populateRerollerSwords()
    local Config = getConfig()
    local Utils = getUtils()
    local NM = getNM()

    if not Config or not Utils then return end

    local scroll = Config.UI.SwordRerollerScroll
    if not scroll then return end

    local T = Config.Theme

    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA('Frame') or child:IsA('TextLabel') or child:IsA('UICorner') then
            if not child:IsA('UICorner') then
                child:Destroy()
            end
        end
    end

    swordsList = {}

    local swords = {}
    if NM and NM.Features and NM.Features.swords then
        swords = NM.Features.swords.getAll()
    end

    if #swords == 0 then
        Utils.create('TextLabel', {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = 'No swords',
            TextColor3 = T.TextMuted,
            TextSize = 12,
            Font = Enum.Font.Gotham,
            Parent = scroll
        })
        return
    end

    scroll.CanvasSize = UDim2.new(0, 0, 0, #swords * 24)

    for i, sword in ipairs(swords) do
        local row = Utils.create('Frame', {
            Size = UDim2.new(1, -8, 0, 22),
            Position = UDim2.new(0, 4, 0, (i - 1) * 24),
            BackgroundTransparency = 1,
            Parent = scroll
        })

        local color = Config.RarityColors[sword.rarity] or T.Text

        Utils.create('TextLabel', {
            Size = UDim2.new(1, -70, 1, 0),
            BackgroundTransparency = 1,
            Text = sword.name,
            TextColor3 = color,
            TextSize = 11,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row
        })

        local isSelected = selectedSwordName == sword.name
        local btn = Utils.createSmallButton(row, isSelected and 'Selected' or 'Select', -4, 2, 60, isSelected and Color3.fromRGB(60, 160, 60) or T.CardHover)
        btn.TextSize = 10

        local swordName = sword.name
        table.insert(swordsList, { name = swordName, btn = btn })

        btn.MouseButton1Click:Connect(function()
            selectSword(swordName, btn)
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

    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA('Frame') or child:IsA('TextLabel') then
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

function SwordsTab.init()
    local Config = getConfig()
    if not Config then return end

    local panel = Config.UI.Tabs['Swords']
    if not panel then return end

    local yOffset = 0

    local _, h1 = buildEnchantsSection(panel, yOffset)
    yOffset = yOffset + (h1 or 0)

    local _, h2 = buildRerollerSection(panel, yOffset)
    yOffset = yOffset + (h2 or 0)

    local _, h3 = buildSplitterSection(panel, yOffset)
    yOffset = yOffset + (h3 or 0)

    panel.CanvasSize = UDim2.new(0, 0, 0, yOffset)
end

function SwordsTab.onShow()
    local Config = getConfig()
    if not Config then return end

    local panel = Config.UI.Tabs['Swords']
    if not panel then return end

    isLoading = true
    showLoading(panel)

    task.spawn(function()
        task.wait(0.3)

        populateEnchants()
        populateRerollerSwords()
        populateSplitter()

        hasLoaded = true
        hideLoading()
    end)
end

function SwordsTab.refresh()
    hasLoaded = false
    SwordsTab.onShow()
end

function SwordsTab.cleanup()
    if bridgeConnection then
        bridgeConnection:Disconnect()
        bridgeConnection = nil
    end
    isRolling = false
end

return SwordsTab
