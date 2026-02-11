--[[
    ============================================================================
    nigMenu - Bosses Feature
    ============================================================================
    
    Boss/Angel auto-farm system with roblox_manager integration.
    
    BOSS FARM LOOP:
      1. Auto-farm teleports to active boss/angel
      2. Monitors boss HP via workspace detection
      3. When all targets dead → sends POST /restart/<server> to roblox_manager
      4. Manager shuts down private server + relaunches ALL accounts
      5. Autoexec re-runs loader → farm resumes automatically
      6. Loop repeats infinitely
    
    Event naming from EventManagerShared:
      Bosses:  "{BossName}_BossEvent"  (e.g. "Red Knight_BossEvent")
      Angels:  "BossAngel_{WorldNum}_BossEvent"  (e.g. "BossAngel_1_BossEvent")
]]

local Bosses = {}

local function getNM() return _G.nigMenu end
local function getConfig() return _G.nigMenu and _G.nigMenu.Config end
local function getBridge()
    local Config = getConfig()
    return Config and Config.Bridge
end

-- ============================================================================
-- STATE
-- ============================================================================

Bosses.farmEnabled = false
Bosses.farmBosses = true
Bosses.farmAngels = true
Bosses.farmMinWorld = 1
Bosses.farmMaxWorld = 30
Bosses.travelTime = 4
Bosses.currentTarget = nil
Bosses.status = "Idle"
Bosses.kills = 0
Bosses.staleTargets = {}  -- {["world_type"] = expireTime} - tracks stale targets to avoid re-teleporting

-- Boss farm loop restart integration
Bosses.autoRestartOnKill = true   -- When all targets dead, auto-restart server via manager
Bosses.autoFarmOnJoin = false     -- Auto-start farm loop when menu loads (for autoexec)

-- ============================================================================
-- SERVER MANAGEMENT
-- ============================================================================

Bosses.servers = {
    { name = "Farm Server",  joinCode = "78782432814231717861076663443421", key = "farm" },
    { name = "Raid Server",  joinCode = "92098597466172680429134969286305", key = "raid" },
    { name = "Server 3",     joinCode = "29171578797016047998164784678510", key = "server3" },
}
Bosses.currentServerIndex = 1
Bosses.loaderCode = ""
Bosses.managerUrl = "http://localhost:8080"
Bosses.hopMethod = "G"

--[[
    Send restart command to roblox_manager.py
    POST /restart/<serverKey> with {gameId: game.JobId, delay: 5}
    
    This tells the manager to:
    1. Shutdown the private server (using Roblox API)
    2. Wait delay seconds
    3. Kill all existing Roblox processes
    4. Relaunch ALL accounts into the same server
    
    The autoexec will re-run the loader -> farm resumes automatically
]]
function Bosses.restartServer(serverKey, callback)
    local NM = getNM()
    local con = NM and NM.Features and NM.Features.console
    local function log(msg)
        if con then con.log(msg) else print(msg) end
    end

    local currentServer = Bosses.servers[Bosses.currentServerIndex]
    serverKey = serverKey or (currentServer and currentServer.key) or Bosses.forcedServerKey
    local jobId = game.JobId

    log("[RESTART] Sending restart request...")
    log("[RESTART] Server: " .. tostring(serverKey))
    log("[RESTART] forcedServerKey: " .. tostring(Bosses.forcedServerKey))
    log("[RESTART] managerUrl: " .. tostring(Bosses.managerUrl))
    log("[RESTART] JobId: " .. tostring(jobId))
    Bosses.status = "Restarting " .. tostring(serverKey) .. "..."

    -- Check if request function exists
    if not request then
        log("[RESTART] ERROR: 'request' function not available in this executor!")
        Bosses.status = "Restart failed - no HTTP support"
        if callback then callback(nil) end
        return
    end

    local success, err = pcall(function()
        local HttpService = game:GetService("HttpService")
        local url = Bosses.managerUrl .. "/restart/" .. tostring(serverKey)
        log("[RESTART] URL: " .. url)

        local response = request({
            Url = url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({
                gameId = jobId,
                delay = 5,
            }),
        })

        if response and response.StatusCode == 200 then
            log("[RESTART] Manager accepted! Server shutting down...")
            log("[RESTART] All accounts relaunching in ~5s")
            Bosses.status = "Server restarting - relaunching all accounts..."
        else
            log("[RESTART] Manager error: " .. tostring(response and response.StatusCode))
            log("[RESTART] Body: " .. tostring(response and response.Body))
            Bosses.status = "Restart failed - is manager running?"
        end

        if callback then callback(response) end
    end)

    if not success then
        log("[RESTART] ERROR: " .. tostring(err))
        Bosses.status = "Restart failed - " .. tostring(err)
        if callback then callback(nil) end
    end
end

-- Legacy alias for server_tab compatibility
function Bosses.restartCurrentServer(callback)
    local server = Bosses.servers[Bosses.currentServerIndex]
    Bosses.restartServer(server and server.key or Bosses.forcedServerKey, callback)
end

-- Check if we're in the correct private server and force relaunch if not
Bosses.privateServerOnly = true
Bosses.forcedServerKey = "farm"

Bosses._enforcementTriggered = false

function Bosses.checkServerEnforcement()
    if not Bosses.privateServerOnly then return false end

    -- Guard: only allow enforcement once per session to prevent restart loops
    if Bosses._enforcementTriggered then return false end

    local NM = getNM()
    local con = NM and NM.Features and NM.Features.console
    local function log(msg)
        if con then con.log(msg) else print(msg) end
    end

    local username = ""
    pcall(function() username = game:GetService("Players").LocalPlayer.Name end)
    if username == "" then
        log("SERVER ENFORCEMENT: Can't get username, skipping")
        return false
    end

    --[[
        Ask the manager: "did you launch me to the correct server?"
        The manager tracks PIDs, server keys, and launch times.
        This is more reliable than game.PrivateServerId which is empty on many executors.
    ]]
    local managerOk = false
    local managerReason = "no_response"

    for attempt = 1, 3 do
        Bosses.status = "Verifying server with manager... (" .. attempt .. "/3)"
        log("SERVER ENFORCEMENT: Querying manager verify-launch (attempt " .. attempt .. "/3)")

        local success, result = pcall(function()
            local HttpService = game:GetService("HttpService")
            local response = request({
                Url = Bosses.managerUrl .. "/verify-launch/" .. HttpService:UrlEncode(username),
                Method = "GET",
            })
            if response and response.StatusCode == 200 then
                return HttpService:JSONDecode(response.Body)
            end
            return nil
        end)

        if success and result then
            if result.ok then
                log("SERVER ENFORCEMENT: Manager confirms OK — server=" .. tostring(result.server_key) .. ", pid_alive=" .. tostring(result.pid_alive))
                managerOk = true
                break
            else
                managerReason = result.reason or ("server_key=" .. tostring(result.server_key) .. " expected=" .. tostring(result.expected_server))
                log("SERVER ENFORCEMENT: Manager says NOT OK — " .. managerReason)
            end
        else
            log("SERVER ENFORCEMENT: Manager unreachable, retrying...")
            task.wait(3)
        end
    end

    if managerOk then
        return false -- all good, we're in the right server
    end

    -- Manager says we're NOT in the right place (or unreachable)
    Bosses._enforcementTriggered = true -- prevent re-triggering

    log("SERVER ENFORCEMENT: Failed! Reason: " .. managerReason .. " — restarting THIS account -> " .. Bosses.forcedServerKey)
    Bosses.status = "Wrong server - relaunching this account..."

    pcall(function()
        local HttpService = game:GetService("HttpService")
        -- Use single-account restart: POST /restart/<username>/<server>
        -- This only kills THIS account's process, not all accounts
        local url = Bosses.managerUrl .. "/restart/" .. HttpService:UrlEncode(username) .. "/" .. Bosses.forcedServerKey
        request({
            Url = url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({ delay = 5 }),
        })
    end)

    return true
end

function Bosses.hopToServer(index)
    local Config = getConfig()
    if not Config then return end
    if index < 1 or index > #Bosses.servers then return end
    
    Bosses.currentServerIndex = index
    local server = Bosses.servers[index]
    local placeId = game.PlaceId
    
    Bosses.status = "Hopping to " .. (server.name or "Server " .. index)
    
    local NM = getNM()
    local con = NM and NM.Features and NM.Features.console
    local function log(msg)
        if con then con.log(msg) else print(msg) end
    end
    
    pcall(function()
        if queue_on_teleport and Bosses.loaderCode and Bosses.loaderCode ~= "" then
            queue_on_teleport(Bosses.loaderCode)
        end
    end)
    
    local method = Bosses.hopMethod or "G"
    local success = false
    
    if not success and (method == "G" or method == "all") then
        log("Method G: TeleportToPrivateServer")
        pcall(function()
            local TS = game:GetService("TeleportService")
            TS:TeleportToPrivateServer(placeId, server.joinCode, {Config.LocalPlayer})
            success = true
        end)
    end
    
    if not success and (method == "A" or method == "all") then
        log("Method A: TeleportAsync + ReservedServerAccessCode")
        pcall(function()
            local TS = game:GetService("TeleportService")
            local opts = Instance.new("TeleportOptions")
            opts.ReservedServerAccessCode = server.joinCode
            TS:TeleportAsync(placeId, {Config.LocalPlayer}, opts)
            success = true
        end)
    end
    
    if not success then
        pcall(function()
            if setclipboard then
                setclipboard(server.joinCode)
                log("JoinCode copied to clipboard.")
            end
        end)
    end
end

function Bosses.hopToNextServer()
    local nextIdx = Bosses.currentServerIndex + 1
    if nextIdx > #Bosses.servers then nextIdx = 1 end
    Bosses.hopToServer(nextIdx)
end

function Bosses.debugServerHop(index)
    local NM = getNM()
    local con = NM and NM.Features and NM.Features.console
    local function log(msg)
        if con then con.log(msg) else print(msg) end
    end
    if con then con.clear(); con.show() end
    
    index = index or 1
    if index > #Bosses.servers then
        log("No server at index " .. index)
        return
    end
    
    local server = Bosses.servers[index]
    log("====== SERVER DEBUG v6 ======")
    log("Target: " .. (server.name or "Server " .. index))
    log("JoinCode: " .. server.joinCode)
    log("Key: " .. server.key)
    log("PlaceId: " .. tostring(game.PlaceId))
    log("JobId: " .. tostring(game.JobId))
    log("PrivateServerId: " .. tostring(game.PrivateServerId))
    log("autoRestartOnKill: " .. tostring(Bosses.autoRestartOnKill))
    log("autoFarmOnJoin: " .. tostring(Bosses.autoFarmOnJoin))
    log("")
    
    log("--- Manager Status ---")
    pcall(function()
        local response = request({
            Url = Bosses.managerUrl .. "/status",
            Method = "GET",
        })
        if response and response.StatusCode == 200 then
            log("Manager: ONLINE")
            log("Response: " .. tostring(response.Body):sub(1, 300))
        else
            log("Manager: OFFLINE or error " .. tostring(response and response.StatusCode))
        end
    end)
    log("")
    
    log("--- Teleport Data ---")
    pcall(function()
        local TS = game:GetService("TeleportService")
        local data = TS:GetLocalPlayerTeleportData()
        if data then
            for k, v in pairs(data) do
                log("  " .. tostring(k) .. " = " .. tostring(v))
            end
        else
            log("  No teleport data")
        end
    end)
    log("")
    log("====== END ======")
end

-- ============================================================================
-- BOSS DATA
-- ============================================================================

Bosses.Data = {
    { world = 1,  spawn = "Sacred Forest",        bossEvent = "RainHard_BossEvent",         boss = Vector3.new(1340.9, 161.7, -314.7),       angel = Vector3.new(1454.6, 160.8, -129.2) },
    { world = 2,  spawn = "Goblins Caves",       bossEvent = "Shaman_BossEvent",           boss = Vector3.new(26059.3, 115.6, 6472.7),      angel = Vector3.new(25973.1, 130.5, 6560.8) },
    { world = 3,  spawn = "Lost Temple",          bossEvent = "Whiteshiki_BossEvent",       boss = Vector3.new(150.7, 144.5, 4553.5),        angel = Vector3.new(130.6, 143.3, 4650.2) },
    { world = 4,  spawn = "Sands",                bossEvent = "Nyxarion_BossEvent",         boss = Vector3.new(25830.3, 146.7, 13254.3),     angel = Vector3.new(25756.9, 145.8, 13367.8) },
    { world = 5,  spawn = "Subway",               bossEvent = "Raze_BossEvent",             boss = Vector3.new(-7578.6, 77.5, 304.5),        angel = Vector3.new(-7538.5, 97.6, 510.0) },
    { world = 6,  spawn = "City",                  bossEvent = "Keeper_BossEvent",           boss = Vector3.new(560.5, -231.8, -9887.5),      angel = Vector3.new(1039.5, -232.5, -9711.3) },
    { world = 7,  spawn = "Anthill",               bossEvent = "Small Inferno_BossEvent",    boss = Vector3.new(-2365.3, 6.8, 27287.6),       angel = Vector3.new(-2381.9, 7.3, 27420.7) },
    { world = 8,  spawn = "Fiery World",           bossEvent = "Erydos_BossEvent",           boss = Vector3.new(-53726.0, 4.8, 141.5),        angel = Vector3.new(-53683.0, 6.3, 515.7) },
    { world = 9,  spawn = "Mines",                 bossEvent = "Posyros_BossEvent",          boss = Vector3.new(7320.4, 168.5, 3818.3),       angel = Vector3.new(7790.0, 167.8, 3671.8) },
    { world = 10, spawn = "Shadow Castle",         bossEvent = "Nira_BossEvent",             boss = Vector3.new(20940.7, 140.2, 3856.5),      angel = Vector3.new(20940.7, 140.2, 3856.5) },
    { world = 11, spawn = "Frozen Forest",         bossEvent = "Enru_BossEvent",             boss = Vector3.new(10486.0, 159.4, -11806.7),    angel = Vector3.new(10554.4, 157.9, -12091.9) },
    { world = 12, spawn = "Orc Sanctuary",         bossEvent = "Ifrit_BossEvent",            boss = Vector3.new(21233.7, 449.0, -59115.3),    angel = Vector3.new(21921.6, 463.6, -59414.7) },
    { world = 13, spawn = "Demonic World",         bossEvent = "Blakaru_BossEvent",          boss = Vector3.new(-17465.6, 24.3, -3149.1),     angel = Vector3.new(-17336.3, 4.9, -2760.4) },
    { world = 14, spawn = "Ant Island",            bossEvent = "Aureon_BossEvent",           boss = Vector3.new(381.9, 10.1, 13494.2),        angel = Vector3.new(717.3, 6.3, 13297.8) },
    { world = 15, spawn = "Volcano",               bossEvent = "White Deity_BossEvent",      boss = Vector3.new(-12632.4, 158.6, -3225.6),    angel = Vector3.new(-12533.3, 159.0, -3376.5) },
    { world = 16, spawn = "Gloomridge",            bossEvent = "Krampus_BossEvent",          boss = Vector3.new(-20441.6, 912.6, 13633.3),    angel = Vector3.new(-20777.2, 907.4, 13450.4) },
    { world = 17, spawn = "Murimu Village",        bossEvent = "Steam Giant_BossEvent",      boss = Vector3.new(-13819.6, 934.9, 11735.0),    angel = Vector3.new(-13876.3, 932.6, 11835.0) },
    { world = 18, spawn = "Cairo",                bossEvent = "World Legend_BossEvent",     boss = Vector3.new(-3085.9, 933.3, 36204.0),     angel = Vector3.new(-2682.1, 932.6, 36726.7) },
    { world = 19, spawn = "Divine Garden",         bossEvent = "Shark Tooth_BossEvent",      boss = Vector3.new(-18642.8, 933.6, 22127.3),    angel = Vector3.new(-18422.7, 933.3, 22336.3) },
    { world = 20, spawn = "Spirit",                bossEvent = "Small Alchemist_BossEvent",  boss = Vector3.new(-17349.1, 1009.5, 18164.5),   angel = Vector3.new(-17394.2, 1008.6, 17975.1) },
    { world = 21, spawn = "Shantytown",            bossEvent = "Strong_BossEvent",           boss = Vector3.new(-24868.3, 1012.0, 36681.2),   angel = Vector3.new(-24931.3, 1011.3, 36444.5) },
    { world = 22, spawn = "Fireworkers",           bossEvent = "Goblin King_BossEvent",      boss = Vector3.new(-21862.6, 1011.3, 19020.4),   angel = Vector3.new(-21826.3, 1011.3, 18857.3) },
    { world = 23, spawn = "Sayan Valley",             bossEvent = "Red Knight_BossEvent",       boss = Vector3.new(-28163.3, 1010.8, 13778.6),   angel = Vector3.new(-28178.2, 1011.1, 13606.7) },
    { world = 24, spawn = "Grand Sea",         bossEvent = "Bomas_BossEvent",            boss = Vector3.new(-40929.8, 1012.2, 13590.6),   angel = Vector3.new(-40955.4, 1006.9, 13445.5) },
    { world = 25, spawn = "Ninja Village",     bossEvent = "Sands Titan_BossEvent",      boss = Vector3.new(-25462.9, 1489.0, 5265.2),    angel = Vector3.new(-25013.4, 1410.1, 5462.5) },
    { world = 26, spawn = "Swordsman Village",           bossEvent = "Kasak_BossEvent",            boss = Vector3.new(-15913.6, 395.0, 13650.8),    angel = Vector3.new(-16134.1, 394.1, 13812.1) },
    { world = 27, spawn = "Walled City",    bossEvent = "No Punch_BossEvent",         boss = Vector3.new(10463.6, 20.2, -32548.5),     angel = Vector3.new(10293.1, 19.3, -32444.9) },
    { world = 28, spawn = "Superhuman Academy",        bossEvent = "Buryry_BossEvent",           boss = Vector3.new(9789.4, 20.2, -36021.8),      angel = Vector3.new(9924.8, 19.3, -36588.5) },
    { world = 29, spawn = "Shield Kingdom",          bossEvent = "Cerberus_BossEvent",         boss = Vector3.new(-25437.0, 1448.7, 653.6),     angel = Vector3.new(-25245.8, 1493.0, 682.4) },
    { world = 30, spawn = "Alchemy City",          bossEvent = "Ogre_BossEvent",             boss = Vector3.new(-23289.7, 1399.7, -3520.9),   angel = Vector3.new(-24201.1, 1400.2, -4002.1) },
}

-- ============================================================================
-- EVENT SYSTEM
-- ============================================================================

local eventsFolder = nil

function Bosses.getEventsFolder()
    if eventsFolder and eventsFolder.Parent then return eventsFolder end
    pcall(function()
        local SM = game:GetService("ReplicatedStorage"):FindFirstChild("SharedModules")
        if SM then
            local EM = SM:FindFirstChild("EventManagerShared")
            if EM then
                eventsFolder = EM:FindFirstChild("Events")
            end
        end
    end)
    return eventsFolder
end

function Bosses.getAllEvents()
    local folder = Bosses.getEventsFolder()
    if not folder then return {} end
    local events = {}
    pcall(function() events = folder:GetChildren() end)
    return events
end

function Bosses.getEventStatus(eventName)
    local folder = Bosses.getEventsFolder()
    if not folder then return nil, nil end
    
    local result = nil
    pcall(function()
        local event = folder:FindFirstChild(eventName)
        if event then
            result = {
                isActive = event.Value,
                startTime = event:GetAttribute("startTime"),
                endTime = event:GetAttribute("endTime"),
                name = eventName
            }
        end
    end)
    
    if result then
        return result.isActive == true, result
    end
    return nil, nil
end

function Bosses.isBossActive(worldNum)
    local data = Bosses.Data[worldNum]
    if not data then return nil, nil end
    return Bosses.getEventStatus(data.bossEvent)
end

function Bosses.isAngelActive(worldNum)
    return Bosses.getEventStatus("BossAngel_" .. worldNum .. "_BossEvent")
end

-- ============================================================================
-- UTILITIES
-- ============================================================================

function Bosses.formatTime(seconds)
    if not seconds then return "?" end
    if seconds <= 0 then return "0:00" end
    seconds = math.floor(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, s)
    else
        return string.format("%d:%02d", m, s)
    end
end

function Bosses.debugEvents()
    local NM = getNM()
    local con = NM and NM.Features and NM.Features.console
    local function log(msg)
        if con then con.log(msg) else print(msg) end
    end
    if con then con.clear(); con.show() end
    
    local events = Bosses.getAllEvents()
    local now = os.time()

    log("====== EVENT MANAGER DUMP ======")
    log("Server time: " .. string.format("%.1f", now))
    log("Events found: " .. #events)
    log("")
    
    for _, event in ipairs(events) do
        pcall(function()
            local startT = event:GetAttribute("startTime")
            local endT = event:GetAttribute("endTime")
            local active = event.Value
            local startDelta = startT and (startT - now) or nil
            local endDelta = endT and (endT - now) or nil
            local startStr = startDelta and Bosses.formatTime(math.abs(startDelta)) or "?"
            local endStr = endDelta and Bosses.formatTime(math.abs(endDelta)) or "?"
            if startDelta and startDelta < 0 then startStr = "-" .. startStr .. " ago" end
            if endDelta and endDelta < 0 then endStr = "-" .. endStr .. " ago" end
            log(string.format("%-35s Active: %-5s | Start: %s | End: %s",
                event.Name, tostring(active), startStr, endStr))
        end)
    end
    
    log("")
    log("====== WORLD MAPPING ======")
    for _, data in ipairs(Bosses.Data) do
        local bActive = Bosses.isBossActive(data.world)
        local aActive = Bosses.isAngelActive(data.world)
        local bStr = bActive == true and "ACTIVE" or bActive == false and "inactive" or "???"
        local aStr = aActive == true and "ACTIVE" or aActive == false and "inactive" or "???"
        log(string.format("W%-2d %-20s Boss(%s): %-8s | Angel: %-8s",
            data.world, data.spawn, data.bossEvent:gsub("_BossEvent", ""), bStr, aStr))
    end
    log("")
    log("====== END ======")
    return events
end

-- ============================================================================
-- NEXT SPAWN PREDICTION
-- ============================================================================

function Bosses.debugNextSpawn()
    local NM = getNM()
    local con = NM and NM.Features and NM.Features.console
    local function log(msg)
        if con then con.log(msg) else print(msg) end
    end
    if con then con.clear(); con.show() end
    
    local events = Bosses.getAllEvents()
    local now = os.time()

    log("====== NEXT SPAWN TIMES ======")
    log("Server time: " .. string.format("%.1f", now))
    log("")
    
    local activeBosses = {}
    local activeAngels = {}
    local upcomingBosses = {}
    local upcomingAngels = {}
    
    for _, event in ipairs(events) do
        pcall(function()
            local name = event.Name
            local isActive = event.Value
            local startT = event:GetAttribute("startTime")
            local endT = event:GetAttribute("endTime")
            
            local isAngel = name:find("BossAngel_") ~= nil
            local isBoss = not isAngel and name:find("_BossEvent") ~= nil
            if not isAngel and not isBoss then return end
            
            local friendly = name:gsub("_BossEvent", "")
            if isAngel then
                local worldNum = name:match("BossAngel_(%d+)")
                if worldNum then
                    local wn = tonumber(worldNum)
                    local data = Bosses.Data[wn]
                    friendly = "Angel W" .. worldNum .. (data and (" " .. data.spawn) or "")
                end
            else
                for _, data in ipairs(Bosses.Data) do
                    if data.bossEvent == name then
                        friendly = friendly .. " (W" .. data.world .. " " .. data.spawn .. ")"
                        break
                    end
                end
            end
            
            local entry = {
                name = name,
                friendly = friendly,
                isActive = isActive,
                startTime = startT,
                endTime = endT,
                isAngel = isAngel,
            }
            
            if isActive then
                if isAngel then
                    table.insert(activeAngels, entry)
                else
                    table.insert(activeBosses, entry)
                end
            elseif startT and startT > now then
                if isAngel then
                    table.insert(upcomingAngels, entry)
                else
                    table.insert(upcomingBosses, entry)
                end
            end
        end)
    end
    
    table.sort(upcomingBosses, function(a, b) return (a.startTime or 0) < (b.startTime or 0) end)
    table.sort(upcomingAngels, function(a, b) return (a.startTime or 0) < (b.startTime or 0) end)
    
    log("--- ACTIVE NOW ---")
    if #activeBosses == 0 and #activeAngels == 0 then
        log("  (none)")
    end
    for _, e in ipairs(activeBosses) do
        local remaining = e.endTime and (e.endTime - now) or nil
        local remStr = remaining and Bosses.formatTime(remaining) or "?"
        log(string.format("  BOSS  %-40s ends in %s", e.friendly, remStr))
    end
    for _, e in ipairs(activeAngels) do
        local remaining = e.endTime and (e.endTime - now) or nil
        local remStr = remaining and Bosses.formatTime(remaining) or "?"
        log(string.format("  ANGEL %-40s ends in %s", e.friendly, remStr))
    end
    log("")
    
    log("--- NEXT BOSS ---")
    if #upcomingBosses > 0 then
        local nxt = upcomingBosses[1]
        local countdown = nxt.startTime - now
        log(string.format("  >> %s", nxt.friendly))
        log(string.format("     Spawns in: %s", Bosses.formatTime(countdown)))
    else
        log("  No upcoming boss events found")
    end
    log("")
    
    log("--- NEXT ANGEL ---")
    if #upcomingAngels > 0 then
        local nxt = upcomingAngels[1]
        local countdown = nxt.startTime - now
        log(string.format("  >> %s", nxt.friendly))
        log(string.format("     Spawns in: %s", Bosses.formatTime(countdown)))
    else
        log("  No upcoming angel events found")
    end
    log("")
    
    log("--- ALL UPCOMING (next 60 min) ---")
    local allUpcoming = {}
    for _, e in ipairs(upcomingBosses) do
        if e.startTime and (e.startTime - now) <= 3600 then
            e._type = "BOSS "
            table.insert(allUpcoming, e)
        end
    end
    for _, e in ipairs(upcomingAngels) do
        if e.startTime and (e.startTime - now) <= 3600 then
            e._type = "ANGEL"
            table.insert(allUpcoming, e)
        end
    end
    table.sort(allUpcoming, function(a, b) return (a.startTime or 0) < (b.startTime or 0) end)
    if #allUpcoming == 0 then
        log("  (none within 60 min)")
    else
        for _, e in ipairs(allUpcoming) do
            local countdown = e.startTime - now
            log(string.format("  %s  %-40s in %s", e._type, e.friendly, Bosses.formatTime(countdown)))
        end
    end
    log("")
    log("====== END ======")
    
    return {
        activeBosses = activeBosses,
        activeAngels = activeAngels,
        nextBoss = upcomingBosses[1],
        nextAngel = upcomingAngels[1],
    }
end

-- ============================================================================
-- WORKSPACE DETECTION
-- ============================================================================

local function getWorldBossFolder()
    local folder = nil
    pcall(function() folder = workspace.Client.Enemies.WorldBoss end)
    return folder
end

local function parseHP(billboardGui)
    local cur, max = 0, 0
    pcall(function()
        for _, desc in ipairs(billboardGui:GetDescendants()) do
            if desc:IsA("TextLabel") and desc.Name == "Amount" then
                local text = desc.Text
                local c, m = text:match("([%d,]+)/([%d,]+)")
                if c and m then
                    cur = tonumber(c:gsub(",", "")) or 0
                    max = tonumber(m:gsub(",", "")) or 0
                    return
                end
            end
        end
    end)
    return cur, max
end

function Bosses.findWorldBossNPC(searchName)
    local folder = getWorldBossFolder()
    if not folder then return nil, 0, 0 end
    local searchL = searchName:lower()
    local foundModel, foundHP, foundMaxHP = nil, 0, 0
    pcall(function()
        for _, uuidModel in ipairs(folder:GetChildren()) do
            for _, desc in ipairs(uuidModel:GetDescendants()) do
                if desc:IsA("BillboardGui") then
                    local enemyLabel = nil
                    for _, child in ipairs(desc:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Name == "EnemyName" then
                            enemyLabel = child
                            break
                        end
                    end
                    if enemyLabel and enemyLabel.Text:lower():find(searchL) then
                        local hp, maxhp = parseHP(desc)
                        foundModel = uuidModel
                        foundHP = hp
                        foundMaxHP = maxhp
                        return
                    end
                end
            end
        end
    end)
    return foundModel, foundHP, foundMaxHP
end

function Bosses.isAngelAlive()
    local model, hp, maxhp = Bosses.findWorldBossNPC("Boss Angel")
    return model ~= nil and hp > 0, hp, maxhp
end

function Bosses.isBossAlive(worldNum)
    local data = Bosses.Data[worldNum]
    if not data then return false, 0, 0 end
    local bossName = data.bossEvent:gsub("_BossEvent", "")
    local model, hp, maxhp = Bosses.findWorldBossNPC(bossName)
    return model ~= nil and hp > 0, hp, maxhp
end

function Bosses.findAnyAliveTarget()
    local folder = getWorldBossFolder()
    if not folder then return nil, 0, 0, nil end
    local resultType, resultHP, resultMax, resultModel = nil, 0, 0, nil
    pcall(function()
        for _, uuidModel in ipairs(folder:GetChildren()) do
            for _, desc in ipairs(uuidModel:GetDescendants()) do
                if desc:IsA("BillboardGui") then
                    local enemyLabel = nil
                    for _, child in ipairs(desc:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Name == "EnemyName" then
                            enemyLabel = child
                            break
                        end
                    end
                    if enemyLabel then
                        local hp, maxhp = parseHP(desc)
                        if hp > 0 then
                            local nameL = enemyLabel.Text:lower()
                            resultType = nameL:find("angel") and "Angel" or "Boss"
                            resultHP = hp
                            resultMax = maxhp
                            resultModel = uuidModel
                            return
                        end
                    end
                end
            end
        end
    end)
    return resultType, resultHP, resultMax, resultModel
end

-- ============================================================================
-- TELEPORT
-- ============================================================================

Bosses.TP_Z_OFFSET = 5  -- offset so we don't spawn directly under the boss

function Bosses.teleportAndWait(worldNum, coords)
    local Config = getConfig()
    local Bridge = getBridge()
    if not Bridge or not Config then return false end
    local data = Bosses.Data[worldNum]
    if not data then return false end

    local offsetCoords = coords + Vector3.new(0, 0, Bosses.TP_Z_OFFSET)

    Bridge:FireServer("Teleport", "Spawn", data.spawn)
    task.wait(Bosses.travelTime)

    for attempt = 1, 3 do
        local char = Config.LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(offsetCoords)
            return true
        end
        task.wait(1)
    end
    return false
end

function Bosses.goToBoss(worldNum)
    local data = Bosses.Data[worldNum]
    if data then Bosses.teleportAndWait(worldNum, data.boss) end
end

function Bosses.goToAngel(worldNum)
    local data = Bosses.Data[worldNum]
    if data then Bosses.teleportAndWait(worldNum, data.angel) end
end

-- ============================================================================
-- HEARTBEAT (report players to manager)
-- ============================================================================
-- Sends POST /heartbeat to manager every 15s with:
--   - This account's username
--   - All players in the server
--   - Current JobId and server key
-- Manager uses this to verify all accounts are in the same server

Bosses.heartbeatRunning = false
Bosses.heartbeatInterval = 15
Bosses.lastHeartbeatMissing = {}  -- accounts the manager says are missing

function Bosses.getPlayerList()
    local players = {}
    pcall(function()
        for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
            table.insert(players, player.Name)
        end
    end)
    return players
end

function Bosses.getMyUsername()
    local name = ""
    pcall(function()
        name = game:GetService("Players").LocalPlayer.Name
    end)
    return name
end

function Bosses.sendHeartbeat()
    local Config = getConfig()
    if not Config then return end
    
    local server = Bosses.servers[Bosses.currentServerIndex]
    local serverKey = server and server.key or "unknown"
    
    pcall(function()
        local HttpService = game:GetService("HttpService")
        local response = request({
            Url = Bosses.managerUrl .. "/heartbeat",
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({
                username = Bosses.getMyUsername(),
                players = Bosses.getPlayerList(),
                jobId = game.JobId,
                server = serverKey,
                placeId = game.PlaceId,
            }),
        })
        
        if response and response.StatusCode == 200 then
            local data = HttpService:JSONDecode(response.Body)
            Bosses.lastHeartbeatMissing = data.missing or {}
        end
    end)
end

function Bosses.startHeartbeat()
    if Bosses.heartbeatRunning then return end
    Bosses.heartbeatRunning = true

    local Config = getConfig()

    -- Send initial heartbeat immediately (before loop)
    -- This ensures manager knows we're alive even if loop has issues
    Bosses.sendHeartbeat()

    task.spawn(function()
        while Bosses.heartbeatRunning and Config and Config.State.running do
            task.wait(Bosses.heartbeatInterval)
            Bosses.sendHeartbeat()
        end
    end)
end

function Bosses.stopHeartbeat()
    Bosses.heartbeatRunning = false
end

-- ============================================================================
-- SERVER-SIDE BOSS DETECTION (GLOBAL - all worlds)
-- ============================================================================
--[[
    workspace.Server.Enemies.WorldBoss contains BaseParts for ALL worlds.
    Structure: WorldBoss / <MapName> / <BossPartName>
    Each BasePart has attributes: Health, MaxHealth, Died, spawnTime, despawnTime, ID
    The game itself uses workspace:GetServerTimeNow() to compare against spawnTime.
    This is FAR more reliable than the event system BoolValues.
]]

local function getServerBossFolder()
    local folder = nil
    pcall(function() folder = workspace.Server.Enemies.WorldBoss end)
    return folder
end

-- Lookup tables: map name → world data, boss name → world data
local spawnToData = {}
local bossNameToData = {}
for _, data in ipairs(Bosses.Data) do
    spawnToData[data.spawn] = data
    bossNameToData[data.bossEvent:gsub("_BossEvent", "")] = data
end

function Bosses.scanServerFolder()
    local serverFolder = getServerBossFolder()
    if not serverFolder then return {} end

    local targets = {}
    local now = nil
    pcall(function() now = workspace:GetServerTimeNow() end)
    if not now then now = os.time() end

    pcall(function()
        for _, mapFolder in ipairs(serverFolder:GetChildren()) do
            local data = spawnToData[mapFolder.Name]
            if not data then continue end
            if data.world < Bosses.farmMinWorld or data.world > Bosses.farmMaxWorld then continue end

            for _, part in ipairs(mapFolder:GetChildren()) do
                if not part:IsA("BasePart") then continue end

                local health = part:GetAttribute("Health") or 0
                local died = part:GetAttribute("Died")
                local spawnTime = part:GetAttribute("spawnTime")

                -- Skip if dead or not yet spawned
                if health <= 0 or died then continue end
                if spawnTime and spawnTime > now then continue end

                local maxHealth = part:GetAttribute("MaxHealth") or health
                local isAngel = part.Name:find("BossAngel") ~= nil

                if isAngel and Bosses.farmAngels then
                    table.insert(targets, {
                        world = data.world, type = "Angel",
                        bossName = "Boss Angel",
                        coords = data.angel, spawn = data.spawn,
                        serverPart = part,
                        health = health, maxHealth = maxHealth,
                    })
                elseif not isAngel and Bosses.farmBosses then
                    table.insert(targets, {
                        world = data.world, type = "Boss",
                        bossName = data.bossEvent:gsub("_BossEvent", ""),
                        coords = data.boss, spawn = data.spawn,
                        serverPart = part,
                        health = health, maxHealth = maxHealth,
                    })
                end
            end
        end
    end)

    table.sort(targets, function(a, b) return a.world < b.world end)
    return targets
end

-- ============================================================================
-- BOSS SPAWN SCHEDULE (Hard-coded PST times)
-- All times are in PST (UTC-8). Server time is UTC.
-- ============================================================================

-- Convert hours:minutes to seconds since midnight
local function hm(h, m) return h * 3600 + (m or 0) * 60 end

-- Regular Bosses: 5 minute duration (300 seconds)
-- Angel Bosses: 10 minute duration (600 seconds)
local BOSS_DURATION = 300
local ANGEL_DURATION = 600

-- Hard-coded spawn schedule in PST (seconds since midnight)
-- Each boss has an array of spawn times that repeat daily
local BOSS_SCHEDULE = {
    -- World 1-6: 5 spawns per day, starting 3:00 PM, every 4-5 hours
    [1]  = { name = "Strong",         type = "Boss",  spawns = {hm(15,0), hm(19,0), hm(0,0), hm(5,0), hm(10,0)} },
    [2]  = { name = "Goblin King",    type = "Boss",  spawns = {hm(15,10), hm(19,10), hm(0,10), hm(5,10), hm(10,10)} },
    [3]  = { name = "Bomas",          type = "Boss",  spawns = {hm(15,20), hm(19,20), hm(0,20), hm(5,20), hm(10,20)} },
    [4]  = { name = "Sands Titan",    type = "Boss",  spawns = {hm(15,30), hm(19,30), hm(0,30), hm(5,30), hm(10,30)} },
    [5]  = { name = "Kasak",          type = "Boss",  spawns = {hm(15,40), hm(19,40), hm(0,40), hm(5,40), hm(10,40)} },
    [6]  = { name = "No Punch",       type = "Boss",  spawns = {hm(15,50), hm(19,50), hm(0,50), hm(5,50), hm(10,50)} },
    -- World 7-12: 4 spawns per day (no 3-4 PM spawn)
    [7]  = { name = "Buryry",         type = "Boss",  spawns = {hm(20,0), hm(1,0), hm(6,0), hm(11,0)} },
    [8]  = { name = "Cerberus",       type = "Boss",  spawns = {hm(20,10), hm(1,10), hm(6,10), hm(11,10)} },
    [9]  = { name = "Ogre",           type = "Boss",  spawns = {hm(20,20), hm(1,20), hm(6,20), hm(11,20)} },
    [10] = { name = "Red Knight",     type = "Boss",  spawns = {hm(20,30), hm(1,30), hm(6,30), hm(11,30)} },
    [11] = { name = "RainHard",       type = "Boss",  spawns = {hm(20,40), hm(1,40), hm(6,40), hm(11,40)} },
    [12] = { name = "Shaman",         type = "Boss",  spawns = {hm(20,50), hm(1,50), hm(6,50), hm(11,50)} },
    -- World 13-18: 5 spawns
    [13] = { name = "Whiteshiki",     type = "Boss",  spawns = {hm(16,0), hm(21,0), hm(2,0), hm(7,0), hm(11,50)} },
    [14] = { name = "Raze",           type = "Boss",  spawns = {hm(16,10), hm(21,10), hm(2,10), hm(7,10), hm(12,10)} },
    [15] = { name = "Nyxarion",       type = "Boss",  spawns = {hm(16,20), hm(21,20), hm(2,20), hm(7,20), hm(12,20)} },
    [16] = { name = "Keeper",         type = "Boss",  spawns = {hm(16,30), hm(21,30), hm(2,30), hm(7,30), hm(12,30)} },
    [17] = { name = "Small Inferno",  type = "Boss",  spawns = {hm(16,40), hm(21,40), hm(2,40), hm(7,40), hm(12,40)} },
    [18] = { name = "Erydos",         type = "Boss",  spawns = {hm(16,50), hm(21,50), hm(2,50), hm(7,50), hm(12,50)} },
    -- World 19-24: 5 spawns
    [19] = { name = "Posyros",        type = "Boss",  spawns = {hm(17,0), hm(22,0), hm(3,0), hm(8,0), hm(13,0)} },
    [20] = { name = "Nira",           type = "Boss",  spawns = {hm(17,10), hm(22,10), hm(3,10), hm(8,10), hm(13,10)} },
    [21] = { name = "Enru",           type = "Boss",  spawns = {hm(17,20), hm(22,20), hm(3,20), hm(8,20), hm(13,20)} },
    [22] = { name = "Ifrit",          type = "Boss",  spawns = {hm(17,30), hm(22,30), hm(3,30), hm(8,30), hm(13,30)} },
    [23] = { name = "Blakaru",        type = "Boss",  spawns = {hm(17,40), hm(22,40), hm(3,40), hm(8,40), hm(13,40)} },
    [24] = { name = "Aureon",         type = "Boss",  spawns = {hm(17,50), hm(22,50), hm(3,50), hm(8,50), hm(13,50)} },
    -- World 25-30: 5 spawns
    [25] = { name = "White Deity",    type = "Boss",  spawns = {hm(18,0), hm(23,0), hm(4,0), hm(9,0), hm(14,0)} },
    [26] = { name = "Krampus",        type = "Boss",  spawns = {hm(18,10), hm(23,10), hm(4,10), hm(9,10), hm(14,10)} },
    [27] = { name = "Steam Giant",    type = "Boss",  spawns = {hm(18,20), hm(23,20), hm(4,20), hm(9,20), hm(14,20)} },
    [28] = { name = "World Legend",   type = "Boss",  spawns = {hm(18,30), hm(23,30), hm(4,30), hm(9,30), hm(14,30)} },
    [29] = { name = "Shark Tooth",    type = "Boss",  spawns = {hm(18,40), hm(23,40), hm(4,40), hm(9,40), hm(14,40)} },
    [30] = { name = "Small Alchemist",type = "Boss",  spawns = {hm(18,50), hm(23,50), hm(4,50), hm(9,50), hm(14,50)} },
}

-- Angel schedule (separate table, same world numbers)
local ANGEL_SCHEDULE = {
    [1]  = { name = "BossAngel_1",  spawns = {hm(11,30), hm(20,30), hm(4,0)} },
    [2]  = { name = "BossAngel_2",  spawns = {hm(11,45), hm(20,45), hm(4,15)} },
    [3]  = { name = "BossAngel_3",  spawns = {hm(12,0), hm(21,0), hm(4,30)} },
    [4]  = { name = "BossAngel_4",  spawns = {hm(12,15), hm(21,15), hm(4,45)} },
    [5]  = { name = "BossAngel_5",  spawns = {hm(12,30), hm(21,30), hm(5,0)} },
    [6]  = { name = "BossAngel_6",  spawns = {hm(12,45), hm(21,45), hm(5,15)} },
    [7]  = { name = "BossAngel_7",  spawns = {hm(13,0), hm(22,0), hm(5,30)} },
    [8]  = { name = "BossAngel_8",  spawns = {hm(13,15), hm(22,15), hm(5,45)} },
    [9]  = { name = "BossAngel_9",  spawns = {hm(13,30), hm(22,30), hm(6,0)} },
    [10] = { name = "BossAngel_10", spawns = {hm(13,45), hm(22,45), hm(6,15)} },
    [11] = { name = "BossAngel_11", spawns = {hm(14,0), hm(23,0), hm(6,30)} },
    [12] = { name = "BossAngel_12", spawns = {hm(14,15), hm(23,15), hm(6,45)} },
    -- World 13-18: 4 spawns
    [13] = { name = "BossAngel_13", spawns = {hm(14,30), hm(16,0), hm(23,30), hm(7,0)} },
    [14] = { name = "BossAngel_14", spawns = {hm(14,45), hm(16,15), hm(23,45), hm(7,15)} },
    [15] = { name = "BossAngel_15", spawns = {hm(15,0), hm(16,30), hm(0,0), hm(7,30)} },
    [16] = { name = "BossAngel_16", spawns = {hm(15,15), hm(16,45), hm(0,15), hm(7,45)} },
    [17] = { name = "BossAngel_17", spawns = {hm(15,30), hm(17,0), hm(0,30), hm(8,0)} },
    [18] = { name = "BossAngel_18", spawns = {hm(15,45), hm(17,15), hm(0,45), hm(8,15)} },
    -- World 19-30: 3 spawns
    [19] = { name = "BossAngel_19", spawns = {hm(17,30), hm(1,0), hm(8,30)} },
    [20] = { name = "BossAngel_20", spawns = {hm(17,45), hm(1,15), hm(8,45)} },
    [21] = { name = "BossAngel_21", spawns = {hm(18,0), hm(1,30), hm(9,0)} },
    [22] = { name = "BossAngel_22", spawns = {hm(18,15), hm(1,45), hm(9,15)} },
    [23] = { name = "BossAngel_23", spawns = {hm(18,30), hm(2,0), hm(9,30)} },
    [24] = { name = "BossAngel_24", spawns = {hm(18,45), hm(2,15), hm(9,45)} },
    [25] = { name = "BossAngel_25", spawns = {hm(19,0), hm(2,30), hm(10,0)} },
    [26] = { name = "BossAngel_26", spawns = {hm(19,15), hm(2,45), hm(10,15)} },
    [27] = { name = "BossAngel_27", spawns = {hm(19,30), hm(3,0), hm(10,30)} },
    [28] = { name = "BossAngel_28", spawns = {hm(19,45), hm(3,15), hm(10,45)} },
    [29] = { name = "BossAngel_29", spawns = {hm(20,0), hm(3,30), hm(11,0)} },
    [30] = { name = "BossAngel_30", spawns = {hm(20,15), hm(3,45), hm(11,15)} },
}

-- Get current PST time (seconds since midnight PST)
local function getPSTSeconds()
    local now = workspace:GetServerTimeNow()
    -- PST = UTC - 8 hours, then mod 86400 to get seconds since midnight
    return (now - 8 * 3600) % 86400
end

-- Check if a boss is currently active given PST seconds and spawn times
local function isActiveNow(pstSeconds, spawnTimes, duration)
    for _, spawnTime in ipairs(spawnTimes) do
        local endTime = spawnTime + duration
        -- Handle midnight wrap (e.g., spawn at 23:50, ends at 00:00)
        if endTime >= 86400 then
            -- Spawn wraps past midnight
            if pstSeconds >= spawnTime or pstSeconds < (endTime % 86400) then
                return true, duration - ((pstSeconds - spawnTime) % 86400)
            end
        else
            if pstSeconds >= spawnTime and pstSeconds < endTime then
                return true, endTime - pstSeconds
            end
        end
    end
    return false, nil
end

-- Get time until next spawn
local function getTimeUntilSpawn(pstSeconds, spawnTimes)
    local minWait = 86400 -- max 24 hours
    for _, spawnTime in ipairs(spawnTimes) do
        local wait
        if spawnTime > pstSeconds then
            wait = spawnTime - pstSeconds
        else
            wait = (86400 - pstSeconds) + spawnTime -- wrap to next day
        end
        if wait < minWait then
            minWait = wait
        end
    end
    return minWait
end

-- Get spawn times for a specific world (replaces calibration-based getWorldSpawnTimes)
function Bosses.getWorldSpawnTimes(worldNum)
    local data = Bosses.Data[worldNum]
    if not data then return nil, nil end

    local pstSeconds = getPSTSeconds()
    local bossInfo = nil
    local angelInfo = nil

    -- Check regular boss
    local bossSchedule = BOSS_SCHEDULE[worldNum]
    if bossSchedule then
        local isActive, timeLeft = isActiveNow(pstSeconds, bossSchedule.spawns, BOSS_DURATION)
        if isActive then
            bossInfo = {
                isActive = true,
                timeRemaining = timeLeft,
                name = bossSchedule.name
            }
        else
            local timeUntil = getTimeUntilSpawn(pstSeconds, bossSchedule.spawns)
            bossInfo = {
                isActive = false,
                timeRemaining = timeUntil,
                name = bossSchedule.name
            }
        end
    end

    -- Check angel boss
    local angelSchedule = ANGEL_SCHEDULE[worldNum]
    if angelSchedule then
        local isActive, timeLeft = isActiveNow(pstSeconds, angelSchedule.spawns, ANGEL_DURATION)
        if isActive then
            angelInfo = {
                isActive = true,
                timeRemaining = timeLeft,
                name = angelSchedule.name
            }
        else
            local timeUntil = getTimeUntilSpawn(pstSeconds, angelSchedule.spawns)
            angelInfo = {
                isActive = false,
                timeRemaining = timeUntil,
                name = angelSchedule.name
            }
        end
    end

    return bossInfo, angelInfo
end

-- Get all currently active bosses (for farm loop)
function Bosses.getActiveFromSchedule()
    local pstSeconds = getPSTSeconds()
    local active = {}

    for worldNum = 1, 30 do
        local data = Bosses.Data[worldNum]
        if not data then continue end
        if worldNum < Bosses.farmMinWorld or worldNum > Bosses.farmMaxWorld then continue end

        -- Check regular boss
        if Bosses.farmBosses then
            local bossSchedule = BOSS_SCHEDULE[worldNum]
            if bossSchedule then
                local isActive, timeLeft = isActiveNow(pstSeconds, bossSchedule.spawns, BOSS_DURATION)
                if isActive then
                    table.insert(active, {
                        world = worldNum,
                        type = "Boss",
                        bossName = bossSchedule.name,
                        coords = data.boss,
                        spawn = data.spawn,
                        timeLeft = timeLeft
                    })
                end
            end
        end

        -- Check angel boss
        if Bosses.farmAngels then
            local angelSchedule = ANGEL_SCHEDULE[worldNum]
            if angelSchedule then
                local isActive, timeLeft = isActiveNow(pstSeconds, angelSchedule.spawns, ANGEL_DURATION)
                if isActive then
                    table.insert(active, {
                        world = worldNum,
                        type = "Angel",
                        bossName = angelSchedule.name,
                        coords = data.angel,
                        spawn = data.spawn,
                        timeLeft = timeLeft
                    })
                end
            end
        end
    end

    -- Sort by world number
    table.sort(active, function(a, b) return a.world < b.world end)
    return active
end

-- Format PST time for display (e.g., "3:00p")
local function formatPST(pstSeconds)
    local hour24 = math.floor(pstSeconds / 3600)
    local min = math.floor((pstSeconds % 3600) / 60)
    local hour12 = ((hour24 - 1) % 12) + 1
    if hour12 == 0 then hour12 = 12 end
    local ampm = hour24 >= 12 and "p" or "a"
    return string.format("%d:%02d%s", hour12, min, ampm)
end

-- Check if timers are calibrated (always true now with hard-coded schedule)
function Bosses.isTimerCalibrated()
    return true
end

-- Recalibrate (no-op with hard-coded schedule, but kept for compatibility)
function Bosses.recalibrateTimers()
    print("[Bosses] Using hard-coded PST schedule (no calibration needed)")
    return true
end

-- Format time nicely
local function formatTimeRemaining(seconds)
    if seconds <= 0 then return "NOW" end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    if h > 0 then
        return string.format("%dh %02dm %02ds", h, m, s)
    else
        return string.format("%dm %02ds", m, s)
    end
end


function Bosses.debugBossSpawnTimes()
    --[[
        Show all boss spawn times using the hard-coded PST schedule.
        Opens console and shows formatted output.
    ]]
    local NM = getNM()
    local con = NM and NM.Features and NM.Features.console
    local function log(msg)
        if con then con.log(msg) else print("[BossDebug] " .. msg) end
    end

    if con then con.clear(); con.show() end

    local pstSeconds = getPSTSeconds()
    local pstTime = formatPST(pstSeconds)

    log("====== BOSS SPAWN TIMES (PST Schedule) ======")
    log("Current PST: " .. pstTime)
    log("")

    local allBosses = {}

    -- Add all regular bosses
    for worldNum = 1, 30 do
        local data = Bosses.Data[worldNum]
        local schedule = BOSS_SCHEDULE[worldNum]
        if data and schedule then
            local isActive, timeLeft = isActiveNow(pstSeconds, schedule.spawns, BOSS_DURATION)
            local timeUntil = isActive and timeLeft or getTimeUntilSpawn(pstSeconds, schedule.spawns)

            table.insert(allBosses, {
                world = worldNum,
                name = schedule.name,
                displayName = schedule.name,
                map = data.spawn,
                isAngel = false,
                active = isActive,
                timeRemaining = timeUntil,
                coords = data.boss,
                type = "Boss"
            })
        end
    end

    -- Add all angel bosses
    for worldNum = 1, 30 do
        local data = Bosses.Data[worldNum]
        local schedule = ANGEL_SCHEDULE[worldNum]
        if data and schedule then
            local isActive, timeLeft = isActiveNow(pstSeconds, schedule.spawns, ANGEL_DURATION)
            local timeUntil = isActive and timeLeft or getTimeUntilSpawn(pstSeconds, schedule.spawns)

            table.insert(allBosses, {
                world = worldNum,
                name = schedule.name,
                displayName = "Angel " .. worldNum,
                map = data.spawn,
                isAngel = true,
                active = isActive,
                timeRemaining = timeUntil,
                coords = data.angel,
                type = "Angel"
            })
        end
    end

    -- Sort: active first (by time remaining), then by time until spawn
    table.sort(allBosses, function(a, b)
        if a.active and not b.active then return true end
        if not a.active and b.active then return false end
        return a.timeRemaining < b.timeRemaining
    end)

    local activeCount, soonCount, laterCount = 0, 0, 0

    for _, boss in ipairs(allBosses) do
        local icon, timeStr

        if boss.active then
            activeCount = activeCount + 1
            icon = "🟢"
            timeStr = "ACTIVE - " .. formatTimeRemaining(boss.timeRemaining) .. " left"
        elseif boss.timeRemaining <= 1800 then -- 30 mins
            soonCount = soonCount + 1
            icon = "🟡"
            timeStr = "Spawns in: " .. formatTimeRemaining(boss.timeRemaining)
        else
            laterCount = laterCount + 1
            icon = "⚪"
            timeStr = "Spawns in: " .. formatTimeRemaining(boss.timeRemaining)
        end

        local typeStr = boss.isAngel and "[Angel]" or "[Boss]"
        log(string.format("%s %s W%d %s @ %s | %s", icon, typeStr, boss.world, boss.displayName, boss.map, timeStr))
    end

    log("")
    log(string.format("Summary: %d Active | %d Soon (<30m) | %d Later", activeCount, soonCount, laterCount))
    log("Schedule: Hard-coded PST times")
    log("====== END ======")

    -- Store for potential teleport use
    Bosses._debugBossList = allBosses
    return allBosses
end

function Bosses.teleportToDebugBoss(index)
    --[[
        Teleport to a boss from the debug list by index.
    ]]
    if not Bosses._debugBossList or #Bosses._debugBossList == 0 then
        print("[BossDebug] No boss list - run debugBossSpawnTimes first")
        return false
    end

    local boss = Bosses._debugBossList[index]
    if not boss then
        print("[BossDebug] Invalid index: " .. tostring(index))
        return false
    end

    local Config = getConfig()
    if not Config then return false end

    local success = Bosses.teleportAndWait(boss.world, boss.coords)
    if success then
        print(string.format("[BossDebug] Teleported to W%d %s: %s", boss.world, boss.type, boss.name))
    end
    return success
end

-- ============================================================================
-- AUTO-FARM LOOP (with manager restart integration)
-- ============================================================================

function Bosses.buildTargetList()
    --[[
        Scan workspace.Client.Enemies.WorldBoss for alive NPC models.
        Only finds NPCs in the player's CURRENT world (workspace is local).
        Returns confirmed-alive targets within [farmMinWorld..farmMaxWorld].
    ]]
    local folder = getWorldBossFolder()
    if not folder then return {} end

    -- Boss name (lowercase) → world data lookup
    local bossLookup = {}
    for _, data in ipairs(Bosses.Data) do
        local name = data.bossEvent:gsub("_BossEvent", ""):lower()
        bossLookup[name] = data
    end

    local targets = {}

    pcall(function()
        for _, model in ipairs(folder:GetChildren()) do
            for _, desc in ipairs(model:GetDescendants()) do
                if desc:IsA("BillboardGui") then
                    local nameLabel = nil
                    for _, child in ipairs(desc:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Name == "EnemyName" then
                            nameLabel = child
                            break
                        end
                    end
                    if nameLabel then
                        local hp, maxhp = parseHP(desc)
                        if hp > 0 then
                            local nameL = nameLabel.Text:lower()

                            if nameL:find("angel") then
                                if Bosses.farmAngels then
                                    local pos = nil
                                    pcall(function()
                                        if model.PrimaryPart then
                                            pos = model.PrimaryPart.Position
                                        else
                                            pos = model:GetPivot().Position
                                        end
                                    end)
                                    if pos then
                                        local best, bestDist = nil, math.huge
                                        for _, d in ipairs(Bosses.Data) do
                                            local dist = (pos - d.angel).Magnitude
                                            if dist < bestDist then
                                                bestDist = dist
                                                best = d
                                            end
                                        end
                                        if best and best.world >= Bosses.farmMinWorld and best.world <= Bosses.farmMaxWorld then
                                            table.insert(targets, {
                                                world = best.world, type = "Angel",
                                                bossName = "Boss Angel",
                                                coords = best.angel, spawn = best.spawn,
                                            })
                                        end
                                    end
                                end
                            else
                                if Bosses.farmBosses then
                                    for key, data in pairs(bossLookup) do
                                        if nameL:find(key) then
                                            if data.world >= Bosses.farmMinWorld and data.world <= Bosses.farmMaxWorld then
                                                table.insert(targets, {
                                                    world = data.world, type = "Boss",
                                                    bossName = data.bossEvent:gsub("_BossEvent", ""),
                                                    coords = data.boss, spawn = data.spawn,
                                                })
                                            end
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)

    table.sort(targets, function(a, b) return a.world < b.world end)
    return targets
end

function Bosses.getEventTargets()
    --[[
        Fallback: use the event system to find which worlds MIGHT have
        active bosses/angels. These are hints — the NPC must still be
        verified after teleporting. Skips worlds we already checked.
    ]]
    local targets = {}
    for i = Bosses.farmMinWorld, Bosses.farmMaxWorld do
        local data = Bosses.Data[i]
        if not data then continue end

        if Bosses.farmBosses then
            local active = Bosses.isBossActive(i)
            if active == true then
                table.insert(targets, {
                    world = i, type = "Boss",
                    bossName = data.bossEvent:gsub("_BossEvent", ""),
                    coords = data.boss, spawn = data.spawn,
                })
            end
        end

        if Bosses.farmAngels then
            local active = Bosses.isAngelActive(i)
            if active == true then
                table.insert(targets, {
                    world = i, type = "Angel",
                    bossName = "Boss Angel",
                    coords = data.angel, spawn = data.spawn,
                })
            end
        end
    end
    return targets
end

--[[
    Main farm loop — server-side detection.

    FLOW:
    1. Scan workspace.Server.Enemies.WorldBoss for alive bosses (GLOBAL, all worlds)
       - Each BasePart has Health, MaxHealth, Died, spawnTime attributes
       - Uses workspace:GetServerTimeNow() to check if spawned
    2. If targets found → teleport to each, farm using server-side health tracking
    3. If server folder empty → fall back to events as hints, verify after TP
    4. After kills + autoRestartOnKill + nothing left → restart server
]]
function Bosses.startFarmLoop()
    local Config = getConfig()
    if not Config then return end

    Bosses.farmEnabled = true
    Bosses.kills = 0
    Bosses.staleTargets = {}  -- Clear stale targets on fresh start

    Bosses.startHeartbeat()

    local DRIFT_RADIUS = 50

    local NM = getNM()
    local con = NM and NM.Features and NM.Features.console
    local function log(msg)
        if con then con.log(msg) else print("[BossFarm] " .. msg) end
    end

    -- Farm a target using server-side Health attribute tracking
    local function farmTarget(target)
        Bosses.currentTarget = target
        log("Farming W" .. target.world .. " " .. target.type .. ": " .. target.bossName)

        while Bosses.farmEnabled and Config.State.running do
            -- Read health directly from server part attributes (ground truth)
            local health, maxHealth, died = 0, 0, false
            local partValid = false
            pcall(function()
                if target.serverPart and target.serverPart.Parent then
                    health = target.serverPart:GetAttribute("Health") or 0
                    maxHealth = target.serverPart:GetAttribute("MaxHealth") or 0
                    died = target.serverPart:GetAttribute("Died") or false
                    partValid = true
                end
            end)

            if not partValid or health <= 0 or died then
                Bosses.kills = Bosses.kills + 1
                log("W" .. target.world .. " " .. target.type .. " DEAD! (kill #" .. Bosses.kills .. ")")
                Bosses.status = target.type .. " dead! (" .. Bosses.kills .. " kills)"
                return true -- killed
            end

            Bosses.status = "W" .. target.world .. " " .. target.type .. " [HP: " .. health .. "/" .. maxHealth .. "]"

            -- Stay near target coords (with Z offset)
            pcall(function()
                local offsetCoords = target.coords + Vector3.new(0, 0, Bosses.TP_Z_OFFSET)
                local hrp = Config.LocalPlayer.Character
                    and Config.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrp and (hrp.Position - offsetCoords).Magnitude > DRIFT_RADIUS then
                    hrp.CFrame = CFrame.new(offsetCoords)
                end
            end)

            task.wait(1)
        end
        return false -- farm stopped
    end

    task.spawn(function()
        if Bosses.checkServerEnforcement() then
            log("Server enforcement triggered - waiting for relaunch...")
            return
        end

        while Bosses.farmEnabled and Config.State.running do
            Bosses.status = "Checking spawn schedule..."
            Bosses.currentTarget = nil

            -- ============================================================
            -- STEP 1: Use hard-coded PST schedule to find active bosses
            -- This works immediately without needing to visit boss maps first
            -- ============================================================
            local scheduleTargets = Bosses.getActiveFromSchedule()

            if #scheduleTargets > 0 then
                log("Schedule: " .. #scheduleTargets .. " active spawn(s)")
                for _, target in ipairs(scheduleTargets) do
                    if not Bosses.farmEnabled or not Config.State.running then break end

                    -- Check if this target is on stale cooldown
                    local staleKey = target.world .. "_" .. target.type
                    local now = os.time()
                    if Bosses.staleTargets[staleKey] and Bosses.staleTargets[staleKey] > now then
                        log("W" .. target.world .. " " .. target.type .. " on stale cooldown, skipping")
                        task.wait(0.5)
                        continue
                    end

                    -- Teleport to the target's world
                    Bosses.status = "TP -> W" .. target.world .. " " .. target.type .. " (" .. target.spawn .. ")"
                    log("Teleporting to W" .. target.world .. " " .. target.type .. " (" .. math.floor(target.timeLeft or 0) .. "s left)")

                    local success = Bosses.teleportAndWait(target.world, target.coords)
                    if success then
                        -- Wait and verify boss exists locally (up to 15 seconds)
                        local foundLocally = false
                        local localTarget = nil
                        for attempt = 1, 5 do
                            task.wait(3)  -- Check every 3 seconds (5 attempts = 15 seconds total)
                            local localTargets = Bosses.buildTargetList()
                            for _, lt in ipairs(localTargets) do
                                if lt.world == target.world and lt.type == target.type then
                                    foundLocally = true
                                    localTarget = lt
                                    break
                                end
                            end
                            if foundLocally then break end
                            if attempt < 5 then
                                log("W" .. target.world .. " " .. target.type .. " not found locally, waiting... (" .. attempt .. "/5)")
                            end
                        end

                        if not foundLocally then
                            log("W" .. target.world .. " " .. target.type .. " not found after 15s (already dead, marking stale)")
                            Bosses.staleTargets[staleKey] = now + 60  -- 60 second cooldown for dead bosses
                        else
                            -- Found the boss alive! Check server folder for health tracking
                            local serverTargets = Bosses.scanServerFolder()
                            local serverTarget = nil
                            for _, st in ipairs(serverTargets) do
                                if st.world == target.world and st.type == target.type then
                                    serverTarget = st
                                    break
                                end
                            end

                            if serverTarget and serverTarget.health and serverTarget.health > 0 then
                                -- Use server target for accurate health tracking
                                farmTarget(serverTarget)
                                Bosses.staleTargets[staleKey] = nil
                            elseif localTarget then
                                -- Fallback: farm using local target (less accurate health)
                                log("Using local target (no server health data)")
                                -- Create a pseudo-target for farming
                                local pseudoTarget = {
                                    world = target.world,
                                    type = target.type,
                                    bossName = target.bossName,
                                    coords = target.coords,
                                    spawn = target.spawn,
                                }
                                -- For pseudo-targets, we need different death detection
                                Bosses.currentTarget = pseudoTarget
                                log("Farming W" .. pseudoTarget.world .. " " .. pseudoTarget.type .. ": " .. pseudoTarget.bossName)

                                -- Simple farm loop checking local targets
                                while Bosses.farmEnabled and Config.State.running do
                                    local stillAlive = false
                                    local currentTargets = Bosses.buildTargetList()
                                    for _, ct in ipairs(currentTargets) do
                                        if ct.world == target.world and ct.type == target.type then
                                            stillAlive = true
                                            break
                                        end
                                    end

                                    if not stillAlive then
                                        Bosses.kills = Bosses.kills + 1
                                        log("W" .. target.world .. " " .. target.type .. " DEAD! (kill #" .. Bosses.kills .. ")")
                                        Bosses.status = target.type .. " dead! (" .. Bosses.kills .. " kills)"
                                        break
                                    end

                                    Bosses.status = "W" .. target.world .. " " .. target.type .. " [farming...]"

                                    -- Stay near target coords
                                    pcall(function()
                                        local offsetCoords = target.coords + Vector3.new(0, 0, Bosses.TP_Z_OFFSET)
                                        local hrp = Config.LocalPlayer.Character
                                            and Config.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                                        if hrp and (hrp.Position - offsetCoords).Magnitude > DRIFT_RADIUS then
                                            hrp.CFrame = CFrame.new(offsetCoords)
                                        end
                                    end)

                                    task.wait(1)
                                end
                                Bosses.staleTargets[staleKey] = nil
                            else
                                log("W" .. target.world .. " " .. target.type .. " died before farming could start")
                            end
                        end
                    else
                        log("TP to W" .. target.world .. " failed")
                    end
                    task.wait(2)
                end
            else
                -- No bosses active according to schedule
                Bosses.status = "No active spawns, waiting..."
                log("Schedule: no active spawns")
                task.wait(10)  -- Check again in 10 seconds
                continue
            end

            if not Bosses.farmEnabled or not Config.State.running then break end

            -- ============================================================
            -- RESTART CHECK
            -- Uses scanServerFolder() only (ground truth from server attributes)
            -- getEventTargets() is not reliable for death detection (events lag)
            -- ============================================================
            if Bosses.kills > 0 and Bosses.autoRestartOnKill then
                local remaining = Bosses.scanServerFolder()
                log("[RESTART CHECK] kills=" .. Bosses.kills .. ", remaining=" .. #remaining)
                if #remaining > 0 then
                    -- Log what's still alive
                    for _, r in ipairs(remaining) do
                        log("[RESTART CHECK] Still alive: W" .. r.world .. " " .. r.type .. " HP=" .. (r.health or "?"))
                    end
                end
                if #remaining == 0 then
                    log("All targets dead (kills=" .. Bosses.kills .. ") - RESTARTING SERVER!")
                    Bosses.status = "All dead -> Restarting server..."
                    task.wait(2)

                    -- Use forcedServerKey (from manager per-account default) instead of hardcoded "farm"
                    Bosses.restartServer(Bosses.forcedServerKey)

                    Bosses.status = "Waiting for relaunch..."
                    log("Waiting for manager to kill+relaunch...")
                    task.wait(60)
                    Bosses.farmEnabled = false
                    return
                end
            end

            task.wait(3)
        end

        Bosses.status = "Idle"
        Bosses.currentTarget = nil
    end)
end

function Bosses.stopFarmLoop()
    Bosses.farmEnabled = false
    Bosses.heartbeatRunning = false
    Bosses.status = "Stopping..."
end

-- ============================================================================
-- AUTO-START ON JOIN (for autoexec loop)
-- ============================================================================

function Bosses.fetchMyServer()
    --[[
        Query the manager for this account's assigned default server.
        GET /my-server/<username> → { server_key, server_name, link_code }
        Updates Bosses.forcedServerKey so enforcement uses the right server.
    ]]
    local NM = getNM()
    local con = NM and NM.Features and NM.Features.console
    local function log(msg)
        if con then con.log(msg) else print(msg) end
    end

    local Config = getConfig()
    if not Config then
        log("[FETCH-SERVER] No config, skipping")
        return
    end

    local username = ""
    pcall(function() username = game:GetService("Players").LocalPlayer.Name end)
    if username == "" then
        log("[FETCH-SERVER] Could not get username")
        return
    end

    log("[FETCH-SERVER] Querying manager for: " .. username)

    local success, err = pcall(function()
        local HttpService = game:GetService("HttpService")
        local url = Bosses.managerUrl .. "/my-server/" .. HttpService:UrlEncode(username)
        log("[FETCH-SERVER] URL: " .. url)

        local response = request({
            Url = url,
            Method = "GET",
        })
        if response and response.StatusCode == 200 then
            local data = HttpService:JSONDecode(response.Body)
            log("[FETCH-SERVER] Response: server_key=" .. tostring(data.server_key) .. ", name=" .. tostring(data.server_name))

            if data.server_key and data.server_key ~= "" then
                Bosses.forcedServerKey = data.server_key
                log("[FETCH-SERVER] Set forcedServerKey = " .. data.server_key)

                -- Also update the servers list if we got a link_code we don't have
                local found = false
                for _, s in ipairs(Bosses.servers) do
                    if s.key == data.server_key then
                        found = true
                        break
                    end
                end
                if not found and data.link_code ~= "" then
                    table.insert(Bosses.servers, {
                        name = data.server_name ~= "" and data.server_name or data.server_key,
                        joinCode = data.link_code,
                        key = data.server_key,
                    })
                    log("[FETCH-SERVER] Added server to list: " .. data.server_key)
                end
            else
                log("[FETCH-SERVER] No server_key in response, keeping default: " .. Bosses.forcedServerKey)
            end
        else
            log("[FETCH-SERVER] Request failed: " .. tostring(response and response.StatusCode))
        end
    end)

    if not success then
        log("[FETCH-SERVER] ERROR: " .. tostring(err))
    end
end

function Bosses.checkAutoStart()
    local NM = getNM()
    local con = NM and NM.Features and NM.Features.console
    local function log(msg)
        if con then con.log(msg) else print("[BossFarm] " .. msg) end
    end

    -- Wait a moment for game services to fully initialize
    log("Waiting for game to fully load...")
    task.wait(5)

    -- Query manager for this account's assigned default server
    log("Querying manager for default server...")
    Bosses.fetchMyServer()
    log("Default server: " .. Bosses.forcedServerKey)

    -- Always enforce correct server at boot (before starting farm)
    if Bosses.privateServerOnly then
        log("Checking server enforcement...")
        if Bosses.checkServerEnforcement() then
            log("Wrong server detected - relaunching via manager")
            return  -- don't start farm, we're leaving this server
        end
        log("Server OK (private)")
    end

    if Bosses.autoFarmOnJoin then
        log("autoFarmOnJoin enabled - starting farm in 5s...")
        Bosses.status = "Auto-starting farm in 5s..."
        task.delay(5, function()
            if not Bosses.farmEnabled then
                log("Auto-starting boss farm loop!")
                Bosses.startFarmLoop()
            end
        end)
    end
end

return Bosses
