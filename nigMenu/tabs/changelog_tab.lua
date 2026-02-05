--[[
    ============================================================================
    nigMenu - Changelog Tab UI
    ============================================================================

    Displays version history so you can track what was added, removed,
    optimized, or fixed across updates.
]]

local ChangelogTab = {}

local function getNM() return _G.nigMenu end
local function getConfig() return _G.nigMenu and _G.nigMenu.Config end
local function getUtils() return _G.nigMenu and _G.nigMenu.Utils end

-- ============================================================================
-- CHANGELOG DATA (newest first)
-- ============================================================================

local changelog = {
    {
        version = "1.0.5",
        date = "2026-02-05",
        entries = {
            { type = "changed", text = "Farm loop now scans worlds for actual NPCs instead of trusting event system" },
            { type = "optimized", text = "Removed event-based targeting — teleport, check workspace, farm if NPC exists" },
            { type = "added", text = "Farm button state persists across re-inject (auto-resumes on reload)" },
            { type = "added", text = "Kill confirmation is now purely NPC-based (gone for 5s = dead)" },
        }
    },
    {
        version = "1.0.4",
        date = "2026-02-05",
        entries = {
            { type = "fixed", text = "Farm loop no longer TPs to bosses whose event is active but NPC never loads" },
            { type = "fixed", text = "Farm loop no longer gets stuck forever on 'NPC missing, event active' (20s timeout)" },
        }
    },
    {
        version = "1.0.3",
        date = "2026-02-05",
        entries = {
            { type = "changed", text = "GitHub loader now pulls from dev branch" },
            { type = "added", text = "Changelog tab included in github_loader.lua" },
        }
    },
    {
        version = "1.0.2",
        date = "2026-02-05",
        entries = {
            { type = "added", text = "Changelog tab to track version history" },
        }
    },
    {
        version = "1.0.1",
        date = "2026-02-05",
        entries = {
            { type = "fixed", text = "Boss spawn timers showing wrong countdown (hours off)" },
            { type = "fixed", text = "Switched time source from GetServerTimeNow to os.time()" },
            { type = "fixed", text = "Inline timer labels too narrow, truncating hour values" },
        }
    },
    {
        version = "1.0.0",
        date = "2026-02-04",
        entries = {
            { type = "added", text = "Initial release" },
            { type = "added", text = "Auto-farm, raids, auto-roll, upgrades, swords, accessories" },
            { type = "added", text = "Boss/Angel auto-farm with 30-world support" },
            { type = "added", text = "Manager integration for server restarts" },
            { type = "added", text = "Pet merger, utilities, server hopper" },
            { type = "added", text = "Settings persistence across re-inject" },
        }
    },
}

-- ============================================================================
-- TAG COLORS
-- ============================================================================

local tagColors = {
    added     = Color3.fromRGB(80, 200, 120),
    fixed     = Color3.fromRGB(100, 160, 255),
    changed   = Color3.fromRGB(240, 180, 60),
    removed   = Color3.fromRGB(220, 80, 80),
    optimized = Color3.fromRGB(180, 120, 255),
}

local tagLabels = {
    added     = "NEW",
    fixed     = "FIX",
    changed   = "CHG",
    removed   = "DEL",
    optimized = "OPT",
}

-- ============================================================================
-- INIT
-- ============================================================================

function ChangelogTab.init()
    local Config = getConfig()
    local Utils = getUtils()
    if not Config or not Utils then return end

    local panel = Config.UI.Tabs['Changelog']
    if not panel then return end

    local T = Config.Theme
    local yOffset = 0

    -- ========================================================================
    -- HEADER CARD
    -- ========================================================================

    local headerCard = Utils.createCard(panel, nil, 52, yOffset)

    Utils.createIcon(headerCard, '\xF0\x9F\x93\x9D', Color3.fromRGB(180, 160, 255), 34, UDim2.new(0, 12, 0, 8))

    Utils.create('TextLabel', {
        Size = UDim2.new(0, 200, 0, 18),
        Position = UDim2.new(0, 54, 0, 8),
        BackgroundTransparency = 1,
        Text = 'CHANGELOG',
        TextColor3 = Color3.fromRGB(180, 160, 255),
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = headerCard
    })

    Utils.create('TextLabel', {
        Size = UDim2.new(1, -60, 0, 12),
        Position = UDim2.new(0, 54, 0, 28),
        BackgroundTransparency = 1,
        Text = 'nigMenu v' .. Config.Constants.VERSION .. ' — version history',
        TextColor3 = T.TextMuted,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = headerCard
    })

    yOffset = yOffset + 60

    -- ========================================================================
    -- VERSION ENTRIES
    -- ========================================================================

    for _, release in ipairs(changelog) do
        local entryCount = #release.entries
        local cardHeight = 32 + (entryCount * 20)

        local card = Utils.createCard(panel, nil, cardHeight, yOffset)

        -- Version + date header
        local isCurrent = release.version == Config.Constants.VERSION

        Utils.create('TextLabel', {
            Size = UDim2.new(0, 120, 0, 18),
            Position = UDim2.new(0, 12, 0, 6),
            BackgroundTransparency = 1,
            Text = 'v' .. release.version,
            TextColor3 = isCurrent and Color3.fromRGB(80, 255, 80) or T.Text,
            TextSize = 14,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = card
        })

        if isCurrent then
            Utils.create('TextLabel', {
                Size = UDim2.new(0, 60, 0, 14),
                Position = UDim2.new(0, 70, 0, 8),
                BackgroundTransparency = 1,
                Text = '(current)',
                TextColor3 = Color3.fromRGB(80, 255, 80),
                TextSize = 10,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = card
            })
        end

        Utils.create('TextLabel', {
            Size = UDim2.new(0, 80, 0, 14),
            Position = UDim2.new(1, -92, 0, 8),
            BackgroundTransparency = 1,
            Text = release.date,
            TextColor3 = T.TextDim,
            TextSize = 10,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Right,
            Parent = card
        })

        -- Entry rows
        for j, entry in ipairs(release.entries) do
            local entryY = 28 + ((j - 1) * 20)
            local color = tagColors[entry.type] or T.TextDim
            local label = tagLabels[entry.type] or "???"

            -- Tag badge
            local badge = Utils.create('TextLabel', {
                Size = UDim2.new(0, 30, 0, 14),
                Position = UDim2.new(0, 12, 0, entryY),
                BackgroundColor3 = color,
                BackgroundTransparency = 0.8,
                Text = label,
                TextColor3 = color,
                TextSize = 9,
                Font = Enum.Font.GothamBold,
                Parent = card
            })
            Utils.addCorner(badge, 3)

            -- Entry text
            Utils.create('TextLabel', {
                Size = UDim2.new(1, -60, 0, 14),
                Position = UDim2.new(0, 48, 0, entryY),
                BackgroundTransparency = 1,
                Text = entry.text,
                TextColor3 = T.TextDim,
                TextSize = 11,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = card
            })
        end

        yOffset = yOffset + cardHeight + 8
    end

    panel.CanvasSize = UDim2.new(0, 0, 0, yOffset + 8)
end

return ChangelogTab
