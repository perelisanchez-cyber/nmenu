--[[
    ============================================================================
    nigMenu - Bosses Feature
    ============================================================================
    
    Boss/Angel auto-farm system with roblox_manager integration.
    
    BOSS FARM LOOP:
      1. Auto-farm teleports to active boss/angel
      2. Monitors boss HP via workspace detection
      3. When all targets dead â†’ sends POST /restart/<server> to roblox_manager
      4. Manager shuts down private server + relaunches ALL accounts
      5. Autoexec re-runs loader â†’ farm resumes automatically
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

-- Boss farm loop restart integration
Bosses.autoRestartOnKill = true   -- When all targets dead, auto-restart server via manager
Bosses.autoFarmOnJoin = false     -- Auto-start farm loop when menu loads (for autoexec)

-- ============================================================================
-- SERVER MANAGEMENT
-- ============================================================================

Bosses.servers = {
    { name = "Raid Server",  joinCode = "92098597466172680429134969286305", key = "raid" },
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
    
    serverKey = serverKey or Bosses.servers[Bosses.currentServerIndex].key or "farm"
    local jobId = game.JobId
    
    log("[RESTART] Server: " .. serverKey)
    log("[RESTART] JobId: " .. tostring(jobId))
    Bosses.status = "Restarting " .. serverKey .. "..."
    
    pcall(function()
        local HttpService = game:GetService("HttpService")
        local response = request({
            Url = Bosses.managerUrl .. "/restart/" .. serverKey,
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
end

-- Legacy alias for server_tab compatibility
function Bosses.restartCurrentServer(callback)
    local server = Bosses.servers[Bosses.currentServerIndex]
    Bosses.restartServer(server and server.key or "farm", callback)
end

-- Check if we're in a public server and force relaunch
Bosses.privateServerOnly = false
Bosses.forcedServerKey = "farm"

function Bosses.checkServerEnforcement()
    if not Bosses.privateServerOnly then return false end
    
    local privateServerId = game.PrivateServerId
    
    if not privateServerId or privateServerId == "" then
        local NM = getNM()
        local con = NM and NM.Features and NM.Features.console
        local function log(msg)
            if con then con.log(msg) else print(msg) end
        end
        
        log("SERVER ENFORCEMENT: In public server! Relaunching to " .. Bosses.forcedServerKey)
        Bosses.status = "Wrong server - relaunching..."
        
        pcall(function()
            local HttpService = game:GetService("HttpService")
            request({
                Url = Bosses.managerUrl .. "/restart/" .. Bosses.forcedServerKey,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode({ delay = 3 }),
            })
        end)
        
        return true
    end
    
    return false
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
    local now = workspace:GetServerTimeNow()
    
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

--[[
    Scans ALL events in EventManagerShared to find the next upcoming
    boss and angel spawn times. Uses the startTime/endTime attributes
    that the game's event system already tracks.
    
    Prints to console:
      - Currently active bosses/angels (with time remaining)
      - Next upcoming boss spawn (with countdown)
      - Next upcoming angel spawn (with countdown)
      - Full schedule of upcoming spawns within the next hour
]]
function Bosses.debugNextSpawn()
    local NM = getNM()
    local con = NM and NM.Features and NM.Features.console
    local function log(msg)
        if con then con.log(msg) else print(msg) end
    end
    if con then con.clear(); con.show() end
    
    local events = Bosses.getAllEvents()
    local now = workspace:GetServerTimeNow()
    
    log("====== NEXT SPAWN TIMES ======")
    log("Server time: " .. string.format("%.1f", now))
    log("")
    
    -- Categorize all events
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
            
            -- Determine type
            local isAngel = name:find("BossAngel_") ~= nil
            local isBoss = not isAngel and name:find("_BossEvent") ~= nil
            if not isAngel and not isBoss then return end
            
            -- Get a friendly name
            local friendly = name:gsub("_BossEvent", "")
            if isAngel then
                local worldNum = name:match("BossAngel_(%d+)")
                if worldNum then
                    local wn = tonumber(worldNum)
                    local data = Bosses.Data[wn]
                    friendly = "Angel W" .. worldNum .. (data and (" " .. data.spawn) or "")
                end
            else
                -- Map boss event name to world
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
                -- Currently active
                if isAngel then
                    table.insert(activeAngels, entry)
                else
                    table.insert(activeBosses, entry)
                end
            elseif startT and startT > now then
                -- Upcoming (future start time)
                if isAngel then
                    table.insert(upcomingAngels, entry)
                else
                    table.insert(upcomingBosses, entry)
                end
            end
        end)
    end
    
    -- Sort upcoming by startTime (soonest first)
    table.sort(upcomingBosses, function(a, b) return (a.startTime or 0) < (b.startTime or 0) end)
    table.sort(upcomingAngels, function(a, b) return (a.startTime or 0) < (b.startTime or 0) end)
    
    -- ================================================================
    -- ACTIVE RIGHT NOW
    -- ================================================================
    
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
    
    -- ================================================================
    -- NEXT SPAWNS
    -- ================================================================
    
    log("--- NEXT BOSS ---")
    if #upcomingBosses > 0 then
        local next = upcomingBosses[1]
        local countdown = next.startTime - now
        log(string.format("  >> %s", next.friendly))
        log(string.format("     Spawns in: %s", Bosses.formatTime(countdown)))
    else
        log("  No upcoming boss events found")
    end
    
    log("")
    
    log("--- NEXT ANGEL ---")
    if #upcomingAngels > 0 then
        local next = upcomingAngels[1]
        local countdown = next.startTime - now
        log(string.format("  >> %s", next.friendly))
        log(string.format("     Spawns in: %s", Bosses.formatTime(countdown)))
    else
        log("  No upcoming angel events found")
    end
    
    log("")
    
    -- ================================================================
    -- UPCOMING (next hour)
    -- ================================================================
    
    log("--- ALL UPCOMING (next 60 min) ---")
    
    local allUpcoming = {}
    for _, e in ipairs(upcomingBosses) do
        if e.startTime and (e.startTime - now) <= 3600 then
            e._type = "BOSS"
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
    
    -- Return useful data for programmatic use
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

function Bosses.teleportAndWait(worldNum, coords)
    local Config = getConfig()
    local Bridge = getBridge()
    if not Bridge or not Config then return false end
    local data = Bosses.Data[worldNum]
    if not data then return false end
    
    Bridge:FireServer("Teleport", "Spawn", data.spawn)
    task.wait(Bosses.travelTime)
    
    for attempt = 1, 3 do
        local char = Config.LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(coords)
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
    
    task.spawn(function()
        while Bosses.heartbeatRunning and Config and Config.State.running do
            Bosses.sendHeartbeat()
            task.wait(Bosses.heartbeatInterval)
        end
    end)
end

function Bosses.stopHeartbeat()
    Bosses.heartbeatRunning = false
end

-- ============================================================================
-- AUTO-FARM LOOP (with manager restart integration)
-- ============================================================================

function Bosses.buildTargetList(skipSet)
    local targets = {}
    skipSet = skipSet or {}
    
    for i = Bosses.farmMinWorld, Bosses.farmMaxWorld do
        local data = Bosses.Data[i]
        if not data then continue end
        
        if Bosses.farmBosses and not skipSet[i .. "_Boss"] then
            local active = Bosses.isBossActive(i)
            if active == true then
                table.insert(targets, {
                    world = i, type = "Boss",
                    eventName = data.bossEvent,
                    bossName = data.bossEvent:gsub("_BossEvent", ""),
                    coords = data.boss, spawn = data.spawn
                })
            end
        end
        
        if Bosses.farmAngels and not skipSet[i .. "_Angel"] then
            local active = Bosses.isAngelActive(i)
            if active == true then
                table.insert(targets, {
                    world = i, type = "Angel",
                    eventName = "BossAngel_" .. i .. "_BossEvent",
                    bossName = "Boss Angel",
                    coords = data.angel, spawn = data.spawn
                })
            end
        end
    end
    return targets
end

--[[
    Main farm loop with manager restart integration.
    
    FLOW:
    1. Scan for active bosses/angels via event system
    2. TP to first active target
    3. Wait for NPC to load in workspace
    4. Monitor HP until boss dies (NPC gone + event inactive)
    5. If autoRestartOnKill AND no more targets: POST /restart/<server>
       -> Manager shuts down server + relaunches all accounts
       -> Autoexec re-runs loader -> farm resumes on fresh server
    6. If more targets remain: move to next one normally
]]
function Bosses.startFarmLoop()
    local Config = getConfig()
    if not Config then return end
    
    Bosses.farmEnabled = true
    Bosses.kills = 0
    
    -- Start heartbeat so manager tracks our players
    Bosses.startHeartbeat()
    
    local DRIFT_RADIUS = 50
    local visited = {}
    
    local NM = getNM()
    local con = NM and NM.Features and NM.Features.console
    local function log(msg)
        if con then con.log(msg) else print("[BossFarm] " .. msg) end
    end
    
    task.spawn(function()
        -- Check server enforcement first
        if Bosses.checkServerEnforcement() then
            log("Server enforcement triggered - waiting for relaunch...")
            return
        end
        
        while Bosses.farmEnabled and Config.State.running do
            local targets = Bosses.buildTargetList(visited)
            
            if #targets == 0 then
                visited = {}
                Bosses.status = "Scanning for active targets..."
                Bosses.currentTarget = nil
                task.wait(2)
                continue
            end
            
            local target = targets[1]
            local targetKey = target.world .. "_" .. target.type
            
            if not Bosses.farmEnabled or not Config.State.running then break end
            
            Bosses.currentTarget = target
            Bosses.status = "TP -> W" .. target.world .. " " .. target.type .. " (" .. target.spawn .. ")"
            log("Teleporting to W" .. target.world .. " " .. target.type)
            
            local success = Bosses.teleportAndWait(target.world, target.coords)
            if not success then
                Bosses.status = "TP failed, retrying..."
                task.wait(2)
                continue
            end
            
            -- Grace period: wait for NPC to load
            Bosses.status = "Waiting for W" .. target.world .. " " .. target.type .. " to load..."
            local loadWait = 0
            local npcFound = false
            
            while Bosses.farmEnabled and Config.State.running and loadWait < 10 do
                local searchName = target.type == "Angel" and "Boss Angel" or target.bossName
                local npcModel = Bosses.findWorldBossNPC(searchName)
                if npcModel then npcFound = true; break end
                loadWait = loadWait + 1
                task.wait(1)
            end
            
            if not npcFound then
                local stillActive
                if target.type == "Boss" then stillActive = Bosses.isBossActive(target.world)
                else stillActive = Bosses.isAngelActive(target.world) end
                
                if stillActive ~= true then
                    visited[targetKey] = true
                    Bosses.status = "W" .. target.world .. " " .. target.type .. " already gone"
                    task.wait(2)
                    continue
                end
            end
            
            -- Main farming loop - stay until NPC is dead
            Bosses.status = "Farming W" .. target.world .. " " .. target.type
            local noNpcCount = 0
            local bossConfirmedDead = false
            
            while Bosses.farmEnabled and Config.State.running do
                local searchName = target.type == "Angel" and "Boss Angel" or target.bossName
                local npcModel, curHP, maxHP = Bosses.findWorldBossNPC(searchName)
                
                if npcModel and curHP > 0 then
                    noNpcCount = 0
                    Bosses.status = "W" .. target.world .. " " .. target.type .. " [HP: " .. curHP .. "/" .. maxHP .. "]"
                else
                    noNpcCount = noNpcCount + 1
                    if noNpcCount >= 3 then
                        local stillActive
                        if target.type == "Boss" then stillActive = Bosses.isBossActive(target.world)
                        else stillActive = Bosses.isAngelActive(target.world) end
                        
                        if stillActive ~= true then
                            Bosses.kills = Bosses.kills + 1
                            bossConfirmedDead = true
                            log("W" .. target.world .. " " .. target.type .. " DEAD! (kill #" .. Bosses.kills .. ")")
                            Bosses.status = target.type .. " dead! (" .. Bosses.kills .. " kills)"
                            visited[targetKey] = true
                            break
                        else
                            Bosses.status = "W" .. target.world .. " " .. target.type .. " - NPC missing, event active..."
                        end
                    end
                end
                
                -- Reposition if drifted
                pcall(function()
                    local hrp = Config.LocalPlayer.Character
                        and Config.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if hrp and (hrp.Position - target.coords).Magnitude > DRIFT_RADIUS then
                        hrp.CFrame = CFrame.new(target.coords)
                    end
                end)
                
                task.wait(1)
            end
            
            -- ==============================================================
            -- BOSS DIED - CHECK IF WE SHOULD RESTART SERVER
            -- ==============================================================
            if bossConfirmedDead and Bosses.autoRestartOnKill and Bosses.farmEnabled then
                local remainingTargets = Bosses.buildTargetList(visited)
                
                if #remainingTargets == 0 then
                    -- No more active targets -> restart server to respawn everything
                    log("All targets dead - RESTARTING SERVER!")
                    Bosses.status = "All dead -> Restarting server..."
                    task.wait(2)
                    
                    local server = Bosses.servers[Bosses.currentServerIndex]
                    Bosses.restartServer(server and server.key or "farm")
                    
                    -- Manager will kill our process and relaunch
                    -- Just wait here until we get killed
                    Bosses.status = "Waiting for relaunch..."
                    log("Waiting for manager to kill+relaunch...")
                    task.wait(60)
                    Bosses.farmEnabled = false
                    return
                else
                    log(#remainingTargets .. " more targets, continuing farm")
                end
            end
            
            task.wait(2)
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

function Bosses.checkAutoStart()
    if Bosses.autoFarmOnJoin then
        local NM = getNM()
        local con = NM and NM.Features and NM.Features.console
        local function log(msg)
            if con then con.log(msg) else print("[BossFarm] " .. msg) end
        end
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

