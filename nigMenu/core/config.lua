--[[
    ============================================================================
    nigMenu - Core Configuration
    ============================================================================
    
    Contains:
    - Theme colors
    - Constants
    - State variables
    - Rarity data
    
    NOTE: This module is self-contained and does NOT depend on other modules.
]]

local Config = {}

-- ============================================================================
-- SERVICES (cached for performance)
-- ============================================================================

Config.Services = {
    Players = game:GetService('Players'),
    ReplicatedStorage = game:GetService('ReplicatedStorage'),
    UserInputService = game:GetService('UserInputService'),
    TweenService = game:GetService('TweenService'),
    CoreGui = game:GetService('CoreGui'),
    Lighting = game:GetService('Lighting'),
    RunService = game:GetService('RunService'),
    HttpService = game:GetService('HttpService'),
    VirtualUser = game:GetService('VirtualUser')
}

-- ============================================================================
-- REFERENCES
-- ============================================================================

Config.LocalPlayer = Config.Services.Players.LocalPlayer

-- Bridge will be set after we confirm ReplicatedStorage is ready
Config.Bridge = nil
pcall(function()
    Config.Bridge = Config.Services.ReplicatedStorage:WaitForChild('Bridge', 10)
end)

-- ============================================================================
-- CONSTANTS
-- ============================================================================

Config.Constants = {
    AUTO_LEAVE_WAVE = 501,
    ENABLE_AUTO_LEAVE = true,
    VERSION = "1.0.26",
    
    -- Potion names
    POTIONS = {
        'Small Energy Potion',
        'Energy Potion',
        'Super Energy',
        'HW_Power_1',
        'Small Gems Potion',
        'Gems Potion',
        'Big Gems Potion',
        'HW_Souls_1',
        'Small Damage Potion',
        'Damage Potion',
        'Big Damage Potion',
        'HW_Damage_1',
        'Shiny Potion'
    },
    
    -- Raid definitions
    RAIDS = {
        { name = 'Raid',    display = 'Raid 1',    color = Color3.fromRGB(100, 200, 100) },
        { name = 'Raid_02', display = 'Raid 2',    color = Color3.fromRGB(100, 180, 255) },
        { name = 'Raid_03', display = 'Raid 3',    color = Color3.fromRGB(200, 150, 255) },
        { name = 'Raid_04', display = 'Raid 4',    color = Color3.fromRGB(255, 200, 100) },
        { name = 'Raid_HW', display = 'Halloween', color = Color3.fromRGB(255, 120, 50) }
    },
    
    -- Accessory systems (all use "ItemSystem" > "Buy" with typeName)
    ACCESSORY_SYSTEMS = {
        { name = 'Eye',   typeName = 'Eyes',   target = 'Omniscient Eye',   icon = '👁️', color = Color3.fromRGB(255, 100, 100) },
        { name = 'Fruit', typeName = 'Fruits', target = 'Singularity Fruit', icon = '🍎', color = Color3.fromRGB(100, 255, 100) },
        { name = 'Quirk', typeName = 'Quirks', target = 'Ascendant Quirk',   icon = '⚡', color = Color3.fromRGB(100, 150, 255) },
        { name = 'Gene',  typeName = 'Genes',  target = 'Progenitor Gene',   icon = '🧬', color = Color3.fromRGB(255, 200, 100) }
    },
    
    -- Prestige levels for pet merging
    PRESTIGE_DATA = {
        { name = 'Normal', color = Color3.fromRGB(180, 180, 180), icon = '' },
        { name = 'Shade',  color = Color3.fromRGB(130, 100, 200), icon = '⭐' },
        { name = 'Shiny',  color = Color3.fromRGB(255, 220, 100), icon = '⭐⭐' },
        { name = 'Dark',   color = Color3.fromRGB(80, 80, 120),   icon = '⭐⭐⭐' },
        { name = 'Darker', color = Color3.fromRGB(50, 0, 80),     icon = '⭐⭐⭐⭐' }
    },
    
    -- Merge requirements
    MERGE_REQUIREMENTS = {
        Normal = 2,
        Shade = 2,
        Shiny = 3,
        Dark = 4
    },
    
    MERGE_RESULT = {
        Normal = 'Shade',
        Shade = 'Shiny',
        Shiny = 'Dark',
        Dark = 'Darker'
    },
    
    -- Auto-buy items
    AUTO_BUY_ITEMS = {
        { name = 'AutoBuyNYPower',       productId = 'NY_Power_1' },
        { name = 'AutoBuyNYSouls',       productId = 'NY_Souls_1' },
        { name = 'AutoBuyNYDamage',      productId = 'NY_Damage_1' },
        { name = 'AutoBuyFruitTicket',   productId = 'Fruit Ticket' },
        { name = 'AutoBuyEyeCoin',       productId = 'Eye Coin' },
        { name = 'AutoBuyTitanInjection', productId = 'Titan Injection' }
    }
}

-- ============================================================================
-- THEME COLORS
-- ============================================================================

Config.Theme = {
    -- Backgrounds
    Bg = Color3.fromRGB(24, 24, 32),
    Sidebar = Color3.fromRGB(28, 28, 38),
    Content = Color3.fromRGB(32, 32, 42),
    Card = Color3.fromRGB(38, 38, 50),
    CardHover = Color3.fromRGB(48, 48, 62),
    
    -- Accent & Text
    Accent = Color3.fromRGB(90, 120, 255),
    Text = Color3.fromRGB(235, 235, 245),
    TextDim = Color3.fromRGB(150, 150, 170),
    TextMuted = Color3.fromRGB(100, 100, 120),
    
    -- Status colors
    Success = Color3.fromRGB(80, 200, 120),
    Error = Color3.fromRGB(220, 80, 80),
    Warning = Color3.fromRGB(240, 180, 60),
    
    -- Border
    Border = Color3.fromRGB(50, 50, 65)
}

-- ============================================================================
-- RARITY DATA
-- ============================================================================

Config.RarityOrder = {
    D = 10,
    C = 9,
    B = 8,
    A = 7,
    S = 6,
    SS = 5,
    Common = 4,
    Uncommon = 4,
    Rare = 3,
    Epic = 3,
    Legendary = 2,
    SSS = 1
}

Config.RarityColors = {
    D = Color3.fromRGB(150, 150, 150),
    C = Color3.fromRGB(100, 200, 100),
    B = Color3.fromRGB(180, 100, 255),
    A = Color3.fromRGB(100, 150, 255),
    S = Color3.fromRGB(255, 220, 80),
    SS = Color3.fromRGB(255, 80, 80),
    Common = Color3.fromRGB(180, 180, 180),
    Uncommon = Color3.fromRGB(80, 200, 80),
    Rare = Color3.fromRGB(80, 150, 255),
    Epic = Color3.fromRGB(180, 80, 255),
    Legendary = Color3.fromRGB(255, 180, 0),
    SSS = Color3.fromRGB(255, 80, 80)
}

Config.AccessoryRarityColors = {
    Common = Color3.fromRGB(180, 180, 180),
    Uncommon = Color3.fromRGB(100, 200, 100),
    Rare = Color3.fromRGB(100, 150, 255),
    Epic = Color3.fromRGB(180, 100, 255),
    Legendary = Color3.fromRGB(255, 200, 50),
    Mythical = Color3.fromRGB(255, 100, 100),
    SSS = Color3.fromRGB(255, 50, 50)
}

-- ============================================================================
-- STATE VARIABLES
-- ============================================================================

Config.State = {
    -- Menu state
    menuVisible = true,
    menuKeybind = Enum.KeyCode.RightControl,
    debugMode = false,
    running = true,
    listeningForKeybind = false,
    currentCoords = '',
    
    -- Current wave tracking
    currentWave = 0,
    
    -- Effect settings
    blurAmount = 0,
    darknessAmount = 0,
    
    -- Premium rolls toggle
    usePremiumRolls = false
}

-- ============================================================================
-- TOGGLE STATES (these get saved/loaded)
-- ============================================================================

Config.Toggles = {
    -- Raid loops
    raidLoops = {},
    
    -- Auto roll loops (per map)
    autoRollLoops = {},
    
    -- Upgrade loops
    generalUpgradeLoops = {},
    swordEnchantLoops = {},
    swordSplitLoops = {},
    
    -- Accessory roll loops
    accessoryRollLoops = {},
    
    -- Potion toggles
    potionToggles = {},
    
    -- Utility toggles
    utilityToggles = {
        AutoEquip = false,
        AutoAchievements = false,
        AutoRank = false,
        GrabDrops = false,
        AntiAFK = false,
        AutoAttacks = false,
        FasterEggOpening = false,
        SpamHatch = false,
        AutoBuyEpicRune = false,
        AutoUpgradeGenerals = false,
        AutoBuyNYPower = false,
        AutoBuyNYSouls = false,
        AutoBuyNYDamage = false,
        AutoBuyFruitTicket = false,
        AutoBuyEyeCoin = false,
        AutoBuyTitanInjection = false
    },
    
    -- Pet merger settings
    starAutoMergeSettings = {
        enabled = false,
        maxPrestige = "Darker"
    },
    
    -- Boss tab toggles (persisted across re-inject)
    bossToggles = nil
}

-- Initialize raid loops
for _, raid in ipairs(Config.Constants.RAIDS) do
    Config.Toggles.raidLoops[raid.name] = false
end

-- Initialize potion toggles
for _, potionName in ipairs(Config.Constants.POTIONS) do
    Config.Toggles.potionToggles[potionName] = false
end

-- Initialize accessory roll loops
for _, acc in ipairs(Config.Constants.ACCESSORY_SYSTEMS) do
    Config.Toggles.accessoryRollLoops[acc.name] = false
end

-- ============================================================================
-- UI REFERENCES (populated by ui.lua)
-- ============================================================================

Config.UI = {
    ScreenGui = nil,
    MainFrame = nil,
    Tabs = {},
    TabButtons = {},
    CurrentTab = nil,
    
    -- Scrolling frames for dynamic content
    GeneralsScroll = nil,
    SwordsScroll = nil,
    SplitterScroll = nil,
    AutoRollScroll = nil,
    
    -- Labels that need updating
    CoordLabel = nil,
    AccessoryLabels = {},
    SwordLevelLabels = {}
}

-- ============================================================================
-- SETTINGS FILE
-- ============================================================================

Config.SettingsFile = 'nigMenu_' .. Config.LocalPlayer.Name .. '.json'

-- ============================================================================
-- RETURN MODULE
-- ============================================================================

return Config
