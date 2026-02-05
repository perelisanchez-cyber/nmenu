--[[
    ============================================================================
    nigMenu - Utility Functions
    ============================================================================
    
    Contains:
    - Instance creation helpers
    - UI component builders
    - Game data helpers
    - Debug printing
]]

local Utils = {}

-- ============================================================================
-- HELPER TO GET CONFIG (lazy load to avoid circular dependency)
-- ============================================================================

local function getConfig()
    return _G.nigMenu and _G.nigMenu.Config
end

local function getTheme()
    local Config = getConfig()
    return Config and Config.Theme
end

-- ============================================================================
-- DEBUG PRINTING
-- ============================================================================

function Utils.dprint(message)
    local Config = getConfig()
    if Config and Config.State.debugMode then
        print('[nigMenu] ' .. tostring(message))
    end
end

-- ============================================================================
-- INSTANCE CREATION
-- ============================================================================

--[[
    Create a new instance with properties
    
    @param className: The class of instance to create
    @param properties: Table of property names and values
    @return: The created instance
]]
function Utils.create(className, properties)
    local instance = Instance.new(className)
    
    for key, value in pairs(properties) do
        if key ~= 'Parent' then
            instance[key] = value
        end
    end
    
    -- Set parent last to avoid property errors
    if properties.Parent then
        instance.Parent = properties.Parent
    end
    
    return instance
end

--[[
    Add a UICorner to a frame
    
    @param parent: The frame to add the corner to
    @param radius: Corner radius in pixels (default: 6)
    @return: The UICorner instance
]]
function Utils.addCorner(parent, radius)
    return Utils.create('UICorner', {
        CornerRadius = UDim.new(0, radius or 6),
        Parent = parent
    })
end

--[[
    Add a UIStroke to a frame
    
    @param parent: The frame to add the stroke to
    @param color: Stroke color (default: Theme.Border)
    @param thickness: Stroke thickness (default: 1)
    @return: The UIStroke instance
]]
function Utils.addStroke(parent, color, thickness)
    local T = getTheme()
    return Utils.create('UIStroke', {
        Color = color or (T and T.Border) or Color3.fromRGB(50, 50, 65),
        Thickness = thickness or 1,
        Parent = parent
    })
end

-- ============================================================================
-- UI COMPONENT BUILDERS
-- ============================================================================

--[[
    Create a card container
    
    @param parent: Parent frame
    @param title: Optional title text
    @param height: Card height in pixels
    @param yPos: Y position offset
    @return: The card frame
]]
function Utils.createCard(parent, title, height, yPos)
    local T = getTheme()
    
    local card = Utils.create('Frame', {
        Size = UDim2.new(1, 0, 0, height),
        Position = UDim2.new(0, 0, 0, yPos),
        BackgroundColor3 = T and T.Card or Color3.fromRGB(38, 38, 50),
        BorderSizePixel = 0,
        Parent = parent
    })
    Utils.addCorner(card, 6)
    
    if title then
        Utils.create('TextLabel', {
            Size = UDim2.new(1, -16, 0, 24),
            Position = UDim2.new(0, 12, 0, 8),
            BackgroundTransparency = 1,
            Text = title,
            TextColor3 = T and T.Text or Color3.fromRGB(235, 235, 245),
            TextSize = 13,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = card
        })
    end
    
    return card
end

--[[
    Create a toggle switch
    
    @param parent: Parent frame
    @param text: Label text
    @param yPos: Y position offset
    @param initialState: Initial toggle state
    @param callback: Function to call when toggled
    @return: Table with container and setState function
]]
function Utils.createToggle(parent, text, yPos, initialState, callback)
    local T = getTheme()
    local Config = getConfig()
    local TS = Config and Config.Services.TweenService or game:GetService('TweenService')
    
    local container = Utils.create('Frame', {
        Size = UDim2.new(1, -16, 0, 26),
        Position = UDim2.new(0, 8, 0, yPos),
        BackgroundTransparency = 1,
        Parent = parent
    })
    
    Utils.create('TextLabel', {
        Size = UDim2.new(1, -50, 1, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = T and T.TextDim or Color3.fromRGB(150, 150, 170),
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = container
    })
    
    local successColor = T and T.Success or Color3.fromRGB(80, 200, 120)
    local hoverColor = T and T.CardHover or Color3.fromRGB(48, 48, 62)
    
    local bg = Utils.create('Frame', {
        Size = UDim2.new(0, 40, 0, 20),
        Position = UDim2.new(1, -40, 0.5, -10),
        BackgroundColor3 = initialState and successColor or hoverColor,
        BorderSizePixel = 0,
        Parent = container
    })
    Utils.addCorner(bg, 10)
    
    local circle = Utils.create('Frame', {
        Size = UDim2.new(0, 16, 0, 16),
        Position = initialState and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Parent = bg
    })
    Utils.addCorner(circle, 8)
    
    local state = initialState
    
    local btn = Utils.create('TextButton', {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = '',
        Parent = container
    })
    
    btn.MouseButton1Click:Connect(function()
        state = not state
        Utils.dprint(text .. ' ' .. (state and 'ENABLED' or 'DISABLED'))
        
        TS:Create(bg, TweenInfo.new(0.2), {
            BackgroundColor3 = state and successColor or hoverColor
        }):Play()
        
        TS:Create(circle, TweenInfo.new(0.2), {
            Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        }):Play()
        
        if callback then
            callback(state)
        end
    end)
    
    return {
        container = container,
        setState = function(newState)
            state = newState
            bg.BackgroundColor3 = state and successColor or hoverColor
            circle.Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        end,
        getState = function()
            return state
        end
    }
end

--[[
    Create a small button
    
    @param parent: Parent frame
    @param text: Button text
    @param xPos: X position (negative = from right edge)
    @param yPos: Y position offset
    @param width: Button width (default: 55)
    @param color: Background color (default: Theme.CardHover)
    @param callback: Function to call when clicked
    @return: The button instance
]]
function Utils.createSmallButton(parent, text, xPos, yPos, width, color, callback)
    local T = getTheme()
    local buttonWidth = width or 55
    local position
    
    if xPos < 0 then
        position = UDim2.new(1, xPos - buttonWidth, 0, yPos)
    else
        position = UDim2.new(0, xPos, 0, yPos)
    end
    
    local defaultColor = color or (T and T.CardHover) or Color3.fromRGB(48, 48, 62)
    local accentColor = T and T.Accent or Color3.fromRGB(90, 120, 255)
    
    local btn = Utils.create('TextButton', {
        Size = UDim2.new(0, buttonWidth, 0, 22),
        Position = position,
        BackgroundColor3 = defaultColor,
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = T and T.Text or Color3.fromRGB(235, 235, 245),
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        Parent = parent
    })
    Utils.addCorner(btn, 4)
    
    btn.MouseEnter:Connect(function()
        btn.BackgroundColor3 = accentColor
    end)
    
    btn.MouseLeave:Connect(function()
        btn.BackgroundColor3 = defaultColor
    end)
    
    if callback then
        btn.MouseButton1Click:Connect(callback)
    end
    
    return btn
end

--[[
    Create an icon with a circular background
    
    @param parent: Parent frame
    @param icon: Emoji/text icon
    @param color: Background color
    @param size: Icon size (default: 40)
    @param position: Position UDim2
    @return: The icon background frame
]]
function Utils.createIcon(parent, icon, color, size, position)
    local T = getTheme()
    size = size or 40
    
    local iconBg = Utils.create('Frame', {
        Size = UDim2.new(0, size, 0, size),
        Position = position,
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = parent
    })
    Utils.addCorner(iconBg, size / 2)
    
    local innerCircle = Utils.create('Frame', {
        Size = UDim2.new(1, -4, 1, -4),
        Position = UDim2.new(0, 2, 0, 2),
        BackgroundColor3 = T and T.Card or Color3.fromRGB(38, 38, 50),
        BorderSizePixel = 0,
        Parent = iconBg
    })
    Utils.addCorner(innerCircle, (size - 4) / 2)
    
    Utils.create('TextLabel', {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = icon,
        TextSize = math.floor(size * 0.5),
        Font = Enum.Font.GothamBold,
        Parent = iconBg
    })
    
    return iconBg
end

-- ============================================================================
-- GAME DATA HELPERS
-- ============================================================================

--[[
    Get all map names (excluding raids)
    @return: Sorted table of map names
]]
function Utils.getAllMaps()
    local Config = getConfig()
    local maps = {}
    local seen = {}
    
    local RS = Config and Config.Services.ReplicatedStorage or game:GetService('ReplicatedStorage')
    local mapsFolder = RS:FindFirstChild('Maps') or RS:WaitForChild('Maps', 10)
    
    if mapsFolder then
        local raidNames = {
            Raid = true,
            Raid_02 = true,
            Raid_03 = true,
            Raid_04 = true,
            Raid_HW = true
        }
        
        for _, mapObj in ipairs(mapsFolder:GetChildren()) do
            if not raidNames[mapObj.Name] and not seen[mapObj.Name] then
                table.insert(maps, mapObj.Name)
                seen[mapObj.Name] = true
            end
        end
    end
    
    table.sort(maps)
    return maps
end

--[[
    Get current raid wave from UI
    @return: Wave number or nil
]]
function Utils.getCurrentRaidWave()
    local Config = getConfig()
    if not Config then return nil end
    
    local success, text = pcall(function()
        return Config.LocalPlayer.PlayerGui.UI.HUD.RaidInfoBoard.waveValue.Text
    end)
    
    if success and text then
        local wave = tonumber(string.match(tostring(text), '(%d+)'))
        if wave then
            Config.State.currentWave = wave
            _G.CurrentWave = wave
            return wave
        end
    end
    
    return nil
end

--[[
    Get MetaService module
    @return: MetaService module or nil
]]
function Utils.getMetaService()
    local Config = getConfig()
    if not Config then return nil end
    
    local success, MS = pcall(function()
        return require(Config.LocalPlayer.PlayerScripts:WaitForChild('MetaService', 5))
    end)
    
    return success and MS or nil
end

--[[
    Get sword rarity from MetaService
    
    @param MS: MetaService module
    @param swordName: Name of the sword
    @return: Rarity string or nil
]]
function Utils.getSwordRarity(MS, swordName)
    if MS.SharedModules 
        and MS.SharedModules.Swords 
        and MS.SharedModules.Swords[swordName] 
    then
        return MS.SharedModules.Swords[swordName].Rarity
    end
    return nil
end

--[[
    Check if player is in a raid
    
    @param raidName: Name of the raid
    @return: Boolean
]]
function Utils.isInRaid(raidName)
    local Config = getConfig()
    if not Config then return false end
    
    local maps = workspace:FindFirstChild('Maps') or workspace:FindFirstChild('Map')
    if not maps then return false end
    
    local raidMap = maps:FindFirstChild(raidName)
    if not raidMap then return false end
    
    local hrp = Config.LocalPlayer.Character 
        and Config.LocalPlayer.Character:FindFirstChild('HumanoidRootPart')
    
    if not hrp then return false end
    
    local distance = (hrp.Position - raidMap:GetPivot().Position).Magnitude
    return distance < 500
end

-- ============================================================================
-- ANIMATION HELPERS
-- ============================================================================

--[[
    Tween an instance's properties
    
    @param instance: The instance to animate
    @param duration: Animation duration
    @param properties: Table of properties to animate
    @param easingStyle: Optional easing style
    @param easingDirection: Optional easing direction
]]
function Utils.tween(instance, duration, properties, easingStyle, easingDirection)
    local TS = game:GetService('TweenService')
    
    local tweenInfo = TweenInfo.new(
        duration,
        easingStyle or Enum.EasingStyle.Quad,
        easingDirection or Enum.EasingDirection.Out
    )
    
    TS:Create(instance, tweenInfo, properties):Play()
end

-- ============================================================================
-- STRING HELPERS
-- ============================================================================

--[[
    Parse numbers from a string (e.g., "5/10" -> 5, 10)
    
    @param text: String to parse
    @return: Two numbers or nil
]]
function Utils.parseNumbers(text)
    local numbers = {}
    for num in string.gmatch(text, '%d+') do
        table.insert(numbers, tonumber(num))
    end
    return numbers[1], numbers[2]
end

-- ============================================================================
-- RETURN MODULE
-- ============================================================================

return Utils
