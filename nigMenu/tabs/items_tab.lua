--[[
    ============================================================================
    nigMenu - Items Tab UI (Roulette-based Rerollers)
    ============================================================================

    Auto-roll items (Eyes, Fruits, Curses, Genes, Quirks) using the roulette system.
    Rolls multiple options and picks the best rarity.
]]

local ItemsTab = {}

-- Services
local RS = game:GetService("ReplicatedStorage")

-- Lazy load references
local function getNM() return _G.nigMenu end
local function getConfig() return _G.nigMenu and _G.nigMenu.Config end
local function getUtils() return _G.nigMenu and _G.nigMenu.Utils end

-- State for each item type
local itemStates = {}

-- Bridge connection
local bridgeConnection = nil

-- Config
local ROLL_DELAY = 1.5
local PICK_DELAY = 0.5
local RESULT_TIMEOUT = 10

-- Rarity priority (higher = better)
local RARITY_PRIORITY = {
    Common = 1,
    Uncommon = 2,
    Rare = 3,
    Epic = 4,
    Legendary = 5,
    Mythical = 6,
    SSS = 7
}

-- Target rarity options for each item type
local TARGET_RARITIES = {"Legendary", "Mythical", "SSS"}

-- ============================================================================
-- HELPERS
-- ============================================================================

local function formatTime(seconds)
    local mins = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%d:%02d", mins, secs)
end

local function getRarityColor(rarity)
    local Config = getConfig()
    if Config and Config.AccessoryRarityColors then
        return Config.AccessoryRarityColors[rarity]
    end
    return Color3.fromRGB(180, 180, 180)
end

local function getItemRarity(itemName, itemType)
    local Utils = getUtils()
    if not Utils then return nil end

    local MS = Utils.getMetaService()
    if not MS or not MS.SharedModules then return nil end

    -- Try different module name patterns
    local moduleNames = {itemType .. 's', itemType, itemType:sub(1,1):upper() .. itemType:sub(2) .. 's'}

    for _, moduleName in ipairs(moduleNames) do
        if MS.SharedModules[moduleName] and MS.SharedModules[moduleName][itemName] then
            return MS.SharedModules[moduleName][itemName].Rarity
        end
    end

    return nil
end

local function getCurrentItem(accName)
    local Utils = getUtils()
    if not Utils then return nil end

    local MS = Utils.getMetaService()
    if not MS or not MS.Data then return nil end

    return MS.Data[accName]
end

-- ============================================================================
-- BRIDGE COMMUNICATION
-- ============================================================================

local function setupBridgeListener()
    if bridgeConnection then return end

    local Bridge = RS:FindFirstChild("Bridge")
    if not Bridge then
        warn("[Items] Bridge not found!")
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
                                local rouletteId = entry.rouletteId

                                -- Find which item type this belongs to
                                for accName, state in pairs(itemStates) do
                                    if state.rouletteId == rouletteId and entry.rewardList then
                                        state.currentRouletteId = entry.id
                                        state.pendingRewards = entry.rewardList
                                        state.waitingForResult = false
                                        print("[Items] Received " .. accName .. " roulette:", entry.id, "with", #entry.rewardList, "options")
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)

    print("[Items] Bridge listener setup complete")
end

local function doRoll(accConfig)
    local Bridge = RS:FindFirstChild("Bridge")
    if not Bridge then
        warn("[Items] Bridge not found!")
        return false
    end

    local payload = {
        typeName = accConfig.typeName,
        count = accConfig.rollCount or 5
    }

    local success, err = pcall(function()
        Bridge:FireServer("ItemSystem", "Buy", payload)
    end)

    if not success then
        warn("[Items] Roll failed:", err)
    end

    return success
end

local function doPick(rouletteId, slotIndex)
    local Bridge = RS:FindFirstChild("Bridge")
    if not Bridge then
        warn("[Items] Bridge not found!")
        return false
    end

    local success, err = pcall(function()
        Bridge:FireServer("RouletteServer", "Pick", {
            id = rouletteId,
            rewardIndex = slotIndex
        })
    end)

    if not success then
        warn("[Items] Pick failed:", err)
    end

    return success
end

-- ============================================================================
-- UI UPDATE
-- ============================================================================

local function updateItemUI(accName)
    local state = itemStates[accName]
    if not state then return end

    local Config = getConfig()
    local T = Config and Config.Theme
    if not T then return end

    -- Update status label
    if state.statusLabel and state.statusLabel.Parent then
        if state.isRolling then
            state.statusLabel.Text = "Rolling..."
            state.statusLabel.TextColor3 = Color3.fromRGB(80, 255, 80)
        else
            local current = getCurrentItem(accName)
            if current then
                state.statusLabel.Text = current
                local rarity = getItemRarity(current, accName)
                state.statusLabel.TextColor3 = getRarityColor(rarity) or T.TextDim
            else
                state.statusLabel.Text = "None"
                state.statusLabel.TextColor3 = T.TextMuted
            end
        end
    end

    -- Update roll count
    if state.rollsLabel and state.rollsLabel.Parent then
        state.rollsLabel.Text = "Rolls: " .. state.rollCount
    end

    -- Update time
    if state.timeLabel and state.timeLabel.Parent then
        if state.isRolling or state.rollCount > 0 then
            local elapsed = state.isRolling and (tick() - state.startTime) or 0
            state.timeLabel.Text = formatTime(elapsed)
        else
            state.timeLabel.Text = "0:00"
        end
    end

    -- Update button
    if state.rollBtn and state.rollBtn.Parent then
        if state.isRolling then
            state.rollBtn.Text = "STOP"
            state.rollBtn.BackgroundColor3 = T.Error
        else
            state.rollBtn.Text = "ROLL"
            state.rollBtn.BackgroundColor3 = state.color or T.Accent
        end
    end
end

-- ============================================================================
-- ROLLING LOGIC
-- ============================================================================

local function startRolling(accName, accConfig)
    local state = itemStates[accName]
    if not state then return end

    if state.isRolling then return end

    -- Setup bridge listener
    setupBridgeListener()

    local targetRarity = state.targetRarity or "Mythical"
    local targetPriority = RARITY_PRIORITY[targetRarity] or 6

    print("[Items] Starting " .. accName .. " roller")
    print("[Items] Target rarity:", targetRarity)
    print("[Items] Rolling", accConfig.rollCount or 5, "options per roll")

    state.isRolling = true
    state.rollCount = 0
    state.startTime = tick()

    updateItemUI(accName)

    task.spawn(function()
        local Config = getConfig()

        while state.isRolling and Config and Config.State.running do
            -- Reset state for this roll
            state.pendingRewards = nil
            state.currentRouletteId = nil
            state.waitingForResult = true

            state.rollCount = state.rollCount + 1
            print("[Items] " .. accName .. " Roll #" .. state.rollCount .. "...")

            -- Fire the roll
            if not doRoll(accConfig) then
                print("[Items] Roll failed, retrying...")
                task.wait(1)
                continue
            end

            -- Wait for roulette result
            local timeout = 0
            while state.waitingForResult or not state.pendingRewards do
                task.wait(0.1)
                timeout = timeout + 0.1
                if timeout > RESULT_TIMEOUT then
                    print("[Items] Timeout waiting for " .. accName .. " roll result")
                    break
                end
                if not state.isRolling then return end
            end

            if not state.pendingRewards then
                print("[Items] No rewards received, retrying...")
                task.wait(1)
                continue
            end

            -- Analyze all options - find target and track best available
            local targetSlot = nil
            local targetRarityFound = nil
            local bestSlot = nil
            local bestRarity = nil
            local bestPriority = 0

            print("[Items] Checking", #state.pendingRewards, "options (target: " .. targetRarity .. "+):")

            for idx, itemName in ipairs(state.pendingRewards) do
                local rarity = getItemRarity(itemName, accName) or "Common"
                local priority = RARITY_PRIORITY[rarity] or 0

                -- Track best available option
                if priority > bestPriority then
                    bestSlot = idx
                    bestRarity = rarity
                    bestPriority = priority
                end

                -- Check if this meets or exceeds target rarity
                local isTarget = priority >= targetPriority

                if isTarget then
                    -- Prefer higher rarity among targets
                    if not targetSlot or priority > (RARITY_PRIORITY[targetRarityFound] or 0) then
                        targetSlot = idx
                        targetRarityFound = rarity
                    end
                    print(string.format("  [%d] %s [%s] <<< TARGET", idx, itemName, rarity))
                else
                    print(string.format("  [%d] %s [%s]", idx, itemName, rarity))
                end
            end

            -- Check if we found target
            if targetSlot then
                local itemName = state.pendingRewards[targetSlot]

                task.wait(PICK_DELAY)
                doPick(state.currentRouletteId, targetSlot)

                local elapsed = tick() - state.startTime
                print("=====================================")
                print("SUCCESS! GOT " .. targetRarityFound .. "!")
                print("=====================================")
                print("Item:", itemName)
                print("Rarity:", targetRarityFound)
                print("Total Rolls:", state.rollCount)
                print("Time:", formatTime(elapsed))
                print("=====================================")

                -- Update status
                if state.statusLabel and state.statusLabel.Parent then
                    state.statusLabel.Text = "GOT " .. targetRarityFound .. "!"
                    state.statusLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
                end

                state.isRolling = false

                -- Save toggle state
                if Config.Toggles.accessoryRollLoops then
                    Config.Toggles.accessoryRollLoops[accName] = false
                end

                local NM = getNM()
                if NM and NM.Settings then
                    NM.Settings.save()
                end

                updateItemUI(accName)
                return
            else
                -- No target found - pick best available and continue
                print("[Items] No target found, picking best option (slot " .. bestSlot .. ", " .. bestRarity .. ") and continuing...")
                task.wait(PICK_DELAY)
                doPick(state.currentRouletteId, bestSlot)
                task.wait(ROLL_DELAY)
            end

            updateItemUI(accName)
        end

        state.isRolling = false
        updateItemUI(accName)
    end)
end

local function stopRolling(accName)
    local state = itemStates[accName]
    if not state then return end

    state.isRolling = false
    updateItemUI(accName)
end

-- ============================================================================
-- INIT
-- ============================================================================

function ItemsTab.init()
    local Config = getConfig()
    local Utils = getUtils()

    if not Config or not Utils then return end

    local panel = Config.UI.Tabs['Items']
    if not panel then return end

    local T = Config.Theme
    local yOffset = 0

    for _, acc in ipairs(Config.Constants.ACCESSORY_SYSTEMS) do
        local accName = acc.name

        -- Initialize state for this item type
        itemStates[accName] = {
            isRolling = false,
            rollCount = 0,
            startTime = 0,
            rouletteId = acc.rouletteId,
            pendingRewards = nil,
            currentRouletteId = nil,
            waitingForResult = false,
            color = acc.color,
            targetRarity = "Mythical",  -- Default target
            -- UI refs
            statusLabel = nil,
            rollsLabel = nil,
            timeLabel = nil,
            rollBtn = nil,
            targetBtns = {}
        }

        local state = itemStates[accName]

        -- Create card (taller to fit target buttons)
        local card = Utils.createCard(panel, nil, 130, yOffset)

        -- Icon
        Utils.createIcon(card, acc.icon, acc.color, 50, UDim2.new(0, 12, 0, 30))

        -- Title
        Utils.create('TextLabel', {
            Size = UDim2.new(0, 100, 0, 20),
            Position = UDim2.new(0, 72, 0, 8),
            BackgroundTransparency = 1,
            Text = acc.name:upper(),
            TextColor3 = acc.color,
            TextSize = 14,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = card
        })

        -- Current/Status label
        state.statusLabel = Utils.create('TextLabel', {
            Size = UDim2.new(0, 150, 0, 16),
            Position = UDim2.new(0, 72, 0, 26),
            BackgroundTransparency = 1,
            Text = 'Loading...',
            TextColor3 = T.TextDim,
            TextSize = 13,
            Font = Enum.Font.GothamMedium,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = card
        })

        -- Target rarity row
        Utils.create('TextLabel', {
            Size = UDim2.new(0, 50, 0, 14),
            Position = UDim2.new(0, 72, 0, 46),
            BackgroundTransparency = 1,
            Text = 'Target:',
            TextColor3 = T.TextMuted,
            TextSize = 11,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = card
        })

        -- Target rarity buttons (Legendary / Mythical / SSS)
        local targetBtnX = 115
        for i, rarity in ipairs(TARGET_RARITIES) do
            local isSelected = (rarity == state.targetRarity)
            local btnWidth = (rarity == "Legendary") and 60 or 45

            local btn = Utils.create('TextButton', {
                Size = UDim2.new(0, btnWidth, 0, 18),
                Position = UDim2.new(0, targetBtnX, 0, 44),
                BackgroundColor3 = isSelected and Color3.fromRGB(60, 160, 60) or T.CardHover,
                BorderSizePixel = 0,
                Text = rarity,
                TextColor3 = getRarityColor(rarity),
                TextSize = 10,
                Font = Enum.Font.GothamBold,
                Parent = card
            })
            Utils.addCorner(btn, 4)

            state.targetBtns[rarity] = btn

            btn.MouseButton1Click:Connect(function()
                state.targetRarity = rarity
                -- Update all button visuals
                for r, b in pairs(state.targetBtns) do
                    if r == rarity then
                        b.BackgroundColor3 = Color3.fromRGB(60, 160, 60)
                    else
                        b.BackgroundColor3 = T.CardHover
                    end
                end
            end)

            targetBtnX = targetBtnX + btnWidth + 4
        end

        -- Stats row
        state.rollsLabel = Utils.create('TextLabel', {
            Size = UDim2.new(0, 70, 0, 14),
            Position = UDim2.new(0, 72, 0, 68),
            BackgroundTransparency = 1,
            Text = 'Rolls: 0',
            TextColor3 = T.TextMuted,
            TextSize = 10,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = card
        })

        state.timeLabel = Utils.create('TextLabel', {
            Size = UDim2.new(0, 60, 0, 14),
            Position = UDim2.new(0, 145, 0, 68),
            BackgroundTransparency = 1,
            Text = '0:00',
            TextColor3 = T.TextMuted,
            TextSize = 10,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = card
        })

        -- Roll count indicator (shows how many options per roll)
        Utils.create('TextLabel', {
            Size = UDim2.new(0, 80, 0, 14),
            Position = UDim2.new(0, 72, 0, 86),
            BackgroundTransparency = 1,
            Text = 'x' .. (acc.rollCount or 5) .. ' per roll',
            TextColor3 = T.TextMuted,
            TextSize = 9,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = card
        })

        -- Roll button
        state.rollBtn = Utils.create('TextButton', {
            Size = UDim2.new(0, 70, 0, 60),
            Position = UDim2.new(1, -80, 0.5, -30),
            BackgroundColor3 = acc.color,
            BorderSizePixel = 0,
            Text = 'ROLL',
            TextColor3 = Color3.new(1, 1, 1),
            TextSize = 14,
            Font = Enum.Font.GothamBold,
            Parent = card
        })
        Utils.addCorner(state.rollBtn, 8)

        -- Button click handler
        local accConfig = acc
        state.rollBtn.MouseButton1Click:Connect(function()
            if state.isRolling then
                stopRolling(accName)
            else
                startRolling(accName, accConfig)
            end
        end)

        yOffset = yOffset + 138
    end

    -- Info card
    local infoCard = Utils.createCard(panel, nil, 50, yOffset)

    Utils.create('TextLabel', {
        Size = UDim2.new(1, -20, 0, 40),
        Position = UDim2.new(0, 12, 0, 6),
        BackgroundTransparency = 1,
        Text = 'Select target rarity (Legendary/Mythical/SSS), then click ROLL.\nRolls 5 options per attempt and picks target or better.',
        TextColor3 = T.TextMuted,
        TextSize = 10,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        Parent = infoCard
    })

    yOffset = yOffset + 58

    panel.CanvasSize = UDim2.new(0, 0, 0, yOffset)
end

function ItemsTab.onShow()
    -- Update all item states
    for accName, _ in pairs(itemStates) do
        updateItemUI(accName)
    end
end

function ItemsTab.cleanup()
    -- Disconnect bridge listener
    if bridgeConnection then
        bridgeConnection:Disconnect()
        bridgeConnection = nil
    end

    -- Stop all rolling
    for accName, state in pairs(itemStates) do
        state.isRolling = false
    end
end

return ItemsTab
