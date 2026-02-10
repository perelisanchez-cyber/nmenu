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
        version = "1.0.27",
        date = "2026-02-10",
        entries = {
            { type = "added", text = "Roulette-based item rerollers — Eyes, Fruits, Genes, Quirks now roll multiple options and pick best" },
            { type = "added", text = "Curses reroller added to Items tab" },
            { type = "changed", text = "Items tab completely rewritten to use roulette system (roll 5, pick best rarity)" },
            { type = "changed", text = "Each item type shows roll count, elapsed time, and current status" },
        }
    },
    {
        version = "1.0.26",
        date = "2026-02-10",
        entries = {
            { type = "added", text = "New Swords tab — combines Enchants, Trait Re-roller, and Splitter in one place" },
            { type = "added", text = "Sword Trait Re-roller — roulette-based, rolls 5 options and picks best S/SS trait" },
            { type = "changed", text = "Upgrades tab now only shows Generals upgrades — sword features moved to Swords tab" },
        }
    },
    {
        version = "1.0.25",
        date = "2026-02-10",
        entries = {
            { type = "added", text = "Roulette-based trait roller — rolls 5 options and picks best S/SS trait automatically" },
            { type = "added", text = "Bridge.OnClientEvent listener to capture roulette results in real-time" },
            { type = "added", text = "RouletteServer.Pick integration to select optimal trait from options" },
        }
    },
    {
        version = "1.0.24",
        date = "2026-02-10",
        entries = {
            { type = "fixed", text = "Trait roller no longer breaks all UI — removed aggressive module patching from hideRouletteUI" },
        }
    },
    {
        version = "1.0.23",
        date = "2026-02-10",
        entries = {
            { type = "fixed", text = "Trait roller now uses correct payload format — passes {generalId, count} table to FireServer" },
        }
    },
    {
        version = "1.0.22",
        date = "2026-02-10",
        entries = {
            { type = "fixed", text = "Generals tab selection toggle — clicking selected general now properly deselects it" },
            { type = "fixed", text = "Current trait label now updates in real-time during rolling" },
            { type = "fixed", text = "Bridge fallback for trait rolling — directly accesses ReplicatedStorage.Bridge if needed" },
            { type = "added", text = "Debug output for trait roller to troubleshoot rolling issues" },
        }
    },
    {
        version = "1.0.21",
        date = "2026-02-10",
        entries = {
            { type = "added", text = "Generals tab — auto-roll traits until target rarity (S or SS) is achieved" },
            { type = "added", text = "Trait roller hides roulette UI during rolling for faster performance" },
            { type = "added", text = "Boss Times debug console in Config tab (visible when debug mode enabled)" },
            { type = "fixed", text = "Heartbeat requirement toggle now properly respected by orphan cleanup" },
            { type = "removed", text = "ServerHopper tab removed (functionality available in Bosses tab)" },
            { type = "removed", text = "Times button removed from Bosses tab (moved to Config debug tools)" },
        }
    },
    {
        version = "1.0.20",
        date = "2026-02-10",
        entries = {
            { type = "fixed", text = "Parallel launch still double-launching — increased stagger to 3s, added pre-launch running check" },
        }
    },
    {
        version = "1.0.19",
        date = "2026-02-10",
        entries = {
            { type = "added", text = "View Boss Times button — shows all boss spawn timers sorted by time remaining" },
            { type = "added", text = "Debug console shows alive (green), spawning (yellow), dead (red) bosses with countdown" },
        }
    },
    {
        version = "1.0.18",
        date = "2026-02-10",
        entries = {
            { type = "fixed", text = "Parallel launch double-launching same account — added currently_launching tracking set" },
        }
    },
    {
        version = "1.0.17",
        date = "2026-02-10",
        entries = {
            { type = "added", text = "Profile selection popup at startup (Unlock/Shake) with separate data files and server configs" },
            { type = "added", text = "Kill All & Reset button — forcefully kills all Roblox processes and re-acquires mutex" },
            { type = "added", text = "Stale target cooldown — marks boss locations as stale for 30s if model not found after 15s" },
            { type = "changed", text = "Parallel instance launching — accounts launch simultaneously with 0.5s stagger (was 5s sequential)" },
            { type = "changed", text = "Smarter health checks — skips full status check if heartbeat < 10s old" },
            { type = "changed", text = "Faster window restore — polls every 0.3s instead of 1s for quicker positioning" },
            { type = "fixed", text = "Boss-only farm not restarting — removed event check (events lag behind actual kills)" },
            { type = "fixed", text = "Teleporting to non-existent bosses — now verifies client-side model exists after TP" },
            { type = "fixed", text = "Readonly table error in FasterEggOpening — now uses hookfunction with pcall fallback" },
        }
    },
    {
        version = "1.0.16",
        date = "2026-02-06",
        entries = {
            { type = "fixed", text = "Boss farm restart now uses per-account default server (forcedServerKey) instead of hardcoded 'farm'" },
            { type = "fixed", text = "Buddy's accounts will now restart to their own server after all bosses are killed" },
        }
    },
    {
        version = "1.0.15",
        date = "2026-02-05",
        entries = {
            { type = "added", text = "Per-launch health check — kills Roblox process if no heartbeat received within 120s of launch" },
            { type = "fixed", text = "Processes stuck on loading screen are now auto-killed instead of piling up as zombies" },
        }
    },
    {
        version = "1.0.14",
        date = "2026-02-05",
        entries = {
            { type = "fixed", text = "Watchdog rejoin now respects per-account default server instead of using global server for all accounts" },
            { type = "fixed", text = "restart_and_rejoin also respects per-account default server" },
        }
    },
    {
        version = "1.0.13",
        date = "2026-02-05",
        entries = {
            { type = "added", text = "Orphan process cleanup — kills zombie Roblox windows not tracked by healthy instances" },
            { type = "changed", text = "Watchdog runs orphan cleanup every 3rd check cycle to prevent process buildup" },
            { type = "changed", text = "Watchdog rejoin kills orphan processes before relaunching to clear stuck-on-loading windows" },
            { type = "fixed", text = "Processes stuck on loading screen (PID=0) now get cleaned up instead of piling up" },
        }
    },
    {
        version = "1.0.12",
        date = "2026-02-05",
        entries = {
            { type = "fixed", text = "Server enforcement no longer uses game.PrivateServerId (always empty on this executor)" },
            { type = "changed", text = "Enforcement now queries manager GET /verify-launch/<user> — manager confirms PID alive + correct server" },
            { type = "added", text = "Manager endpoint GET /verify-launch/<username> checks tracked PID, server_key, and expected server" },
        }
    },
    {
        version = "1.0.11",
        date = "2026-02-05",
        entries = {
            { type = "fixed", text = "Server enforcement restart loop — no longer kills ALL Roblox processes" },
            { type = "changed", text = "Enforcement uses single-account restart (POST /restart/<user>/<server>) instead of full restart" },
            { type = "changed", text = "Manager single-account restart only kills that account's tracked PID, not all processes" },
            { type = "added", text = "One-shot guard: enforcement can only trigger once per session to prevent loops" },
            { type = "added", text = "5s initial wait in checkAutoStart for game services to fully initialize" },
        }
    },
    {
        version = "1.0.10",
        date = "2026-02-05",
        entries = {
            { type = "added", text = "Per-account default server — each user can set their own server in the manager" },
            { type = "added", text = "Lua queries GET /my-server/<username> at boot to get assigned server" },
            { type = "changed", text = "Manager restart now launches each account to their own default server" },
            { type = "changed", text = "Manager verify/re-relaunch also respects per-account server assignment" },
        }
    },
    {
        version = "1.0.9",
        date = "2026-02-05",
        entries = {
            { type = "fixed", text = "Server enforcement enabled by default — accounts in public servers auto-relaunch via manager" },
            { type = "added", text = "Boot-time server check runs before farm starts (via checkAutoStart)" },
            { type = "fixed", text = "TP to boss/angel now adds +5 Z offset so you don't spawn directly under the NPC" },
        }
    },
    {
        version = "1.0.8",
        date = "2026-02-05",
        entries = {
            { type = "fixed", text = "Farm now uses workspace.Server.Enemies.WorldBoss (server-side, GLOBAL across all worlds)" },
            { type = "changed", text = "Detection reads Health/Died/spawnTime attributes directly from server parts — no more BillboardGui parsing" },
            { type = "changed", text = "Health tracking during farm uses server attributes (ground truth) instead of client-side NPC models" },
            { type = "added", text = "Event system kept as fallback only if server folder returns empty" },
            { type = "optimized", text = "No more unreliable event BoolValues as primary detection — server parts are authoritative" },
        }
    },
    {
        version = "1.0.7",
        date = "2026-02-05",
        entries = {
            { type = "fixed", text = "Farm loop now uses hybrid detection: workspace scan + event fallback" },
            { type = "changed", text = "Workspace scan checks current world instantly for alive NPCs" },
            { type = "changed", text = "Events used as fallback hints for remote worlds, verified after TP" },
            { type = "added", text = "60s cooldown on event-hinted worlds where NPC wasn't found (prevents re-visiting)" },
        }
    },
    {
        version = "1.0.6",
        date = "2026-02-05",
        entries = {
            { type = "optimized", text = "Farm scans WorldBoss folder remotely instead of teleporting to every world" },
            { type = "changed", text = "buildTargetList now reads workspace NPC models + HP to find alive targets" },
            { type = "changed", text = "Angels detected by matching NPC position to known world coords" },
            { type = "changed", text = "Only teleports when a boss/angel is confirmed alive — no blind scanning" },
        }
    },
    {
        version = "1.0.5",
        date = "2026-02-05",
        entries = {
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
