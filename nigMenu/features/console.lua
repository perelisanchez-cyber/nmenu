--[[
    ============================================================================
    nigMenu - Debug Console
    ============================================================================
    
    Floating window with copyable, scrollable text output.
    Draggable, resizable.
]]

local Console = {}

local function getConfig() return _G.nigMenu and _G.nigMenu.Config end

local gui = nil
local mainFrame = nil
local textBox = nil
local lines = {}
local MAX_LINES = 300
local isVisible = false

-- ============================================================================
-- CREATE UI
-- ============================================================================

local function ensureUI()
    if gui and gui.Parent then return end
    
    local Config = getConfig()
    if not Config then return end
    
    local CoreGui = Config.Services.CoreGui
    local UIS = game:GetService("UserInputService")
    
    gui = Instance.new("ScreenGui")
    gui.Name = "nigMenuConsole"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 100
    gui.Parent = CoreGui
    
    -- Main frame
    mainFrame = Instance.new("Frame")
    mainFrame.Name = "Console"
    mainFrame.Size = UDim2.new(0, 550, 0, 400)
    mainFrame.Position = UDim2.new(0.5, -275, 0.5, -200)
    mainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    mainFrame.BorderSizePixel = 0
    mainFrame.Visible = false
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = gui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 60, 80)
    stroke.Thickness = 1
    stroke.Parent = mainFrame
    
    -- ================================================================
    -- TITLE BAR (draggable)
    -- ================================================================
    
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = titleBar
    
    -- Fill bottom corners of title bar
    local titleFill = Instance.new("Frame")
    titleFill.Size = UDim2.new(1, 0, 0, 10)
    titleFill.Position = UDim2.new(0, 0, 1, -10)
    titleFill.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
    titleFill.BorderSizePixel = 0
    titleFill.Parent = titleBar
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -180, 1, 0)
    titleLabel.Position = UDim2.new(0, 10, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "📋 Debug Console"
    titleLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
    titleLabel.TextSize = 13
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar
    
    -- Copy button
    local copyBtn = Instance.new("TextButton")
    copyBtn.Size = UDim2.new(0, 50, 0, 20)
    copyBtn.Position = UDim2.new(1, -170, 0, 5)
    copyBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 180)
    copyBtn.BorderSizePixel = 0
    copyBtn.Text = "Copy"
    copyBtn.TextColor3 = Color3.new(1, 1, 1)
    copyBtn.TextSize = 12
    copyBtn.Font = Enum.Font.GothamBold
    copyBtn.Parent = titleBar
    Instance.new("UICorner", copyBtn).CornerRadius = UDim.new(0, 4)
    
    copyBtn.MouseButton1Click:Connect(function()
        local text = table.concat(lines, "\n")
        pcall(function()
            if setclipboard then
                setclipboard(text)
            elseif toclipboard then
                toclipboard(text)
            end
        end)
        copyBtn.Text = "✓"
        task.delay(1.5, function()
            if copyBtn and copyBtn.Parent then copyBtn.Text = "Copy" end
        end)
    end)
    
    -- Clear button
    local clearBtn = Instance.new("TextButton")
    clearBtn.Size = UDim2.new(0, 45, 0, 20)
    clearBtn.Position = UDim2.new(1, -115, 0, 5)
    clearBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
    clearBtn.BorderSizePixel = 0
    clearBtn.Text = "Clear"
    clearBtn.TextColor3 = Color3.new(1, 1, 1)
    clearBtn.TextSize = 12
    clearBtn.Font = Enum.Font.GothamBold
    clearBtn.Parent = titleBar
    Instance.new("UICorner", clearBtn).CornerRadius = UDim.new(0, 4)
    
    clearBtn.MouseButton1Click:Connect(function()
        Console.clear()
    end)
    
    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 50, 0, 20)
    closeBtn.Position = UDim2.new(1, -60, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(160, 50, 50)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "Close"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.TextSize = 12
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = titleBar
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)
    
    closeBtn.MouseButton1Click:Connect(function()
        Console.hide()
    end)
    
    -- Drag logic
    local dragging = false
    local dragStart, startPos
    
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
        end
    end)
    
    titleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    UIS.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    -- ================================================================
    -- SCROLLING TEXT AREA
    -- ================================================================
    
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, -8, 1, -38)
    scrollFrame.Position = UDim2.new(0, 4, 0, 34)
    scrollFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 8
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.Parent = mainFrame
    Instance.new("UICorner", scrollFrame).CornerRadius = UDim.new(0, 4)
    
    -- TextBox for selectable/copyable text
    textBox = Instance.new("TextBox")
    textBox.Size = UDim2.new(1, -16, 0, 20)
    textBox.Position = UDim2.new(0, 8, 0, 4)
    textBox.BackgroundTransparency = 1
    textBox.Text = ""
    textBox.TextColor3 = Color3.fromRGB(180, 220, 180)
    textBox.TextSize = 12
    textBox.Font = Enum.Font.Code
    textBox.TextXAlignment = Enum.TextXAlignment.Left
    textBox.TextYAlignment = Enum.TextYAlignment.Top
    textBox.TextWrapped = true
    textBox.MultiLine = true
    textBox.ClearTextOnFocus = false
    textBox.AutomaticSize = Enum.AutomaticSize.Y
    textBox.Parent = scrollFrame
    
    -- Update canvas size when text changes
    textBox:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, textBox.AbsoluteSize.Y + 12)
    end)
    
    -- ================================================================
    -- RESIZE HANDLE (bottom-right corner)
    -- ================================================================
    
    local resizeHandle = Instance.new("TextButton")
    resizeHandle.Size = UDim2.new(0, 18, 0, 18)
    resizeHandle.Position = UDim2.new(1, -18, 1, -18)
    resizeHandle.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    resizeHandle.BorderSizePixel = 0
    resizeHandle.Text = "⤡"
    resizeHandle.TextColor3 = Color3.fromRGB(120, 120, 150)
    resizeHandle.TextSize = 12
    resizeHandle.Font = Enum.Font.GothamBold
    resizeHandle.ZIndex = 10
    resizeHandle.Parent = mainFrame
    Instance.new("UICorner", resizeHandle).CornerRadius = UDim.new(0, 4)
    
    local resizing = false
    local resizeStart, startSize
    
    resizeHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            resizing = true
            resizeStart = input.Position
            startSize = mainFrame.Size
        end
    end)
    
    resizeHandle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            resizing = false
        end
    end)
    
    UIS.InputChanged:Connect(function(input)
        if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - resizeStart
            local newW = math.max(300, startSize.X.Offset + delta.X)
            local newH = math.max(150, startSize.Y.Offset + delta.Y)
            mainFrame.Size = UDim2.new(0, newW, 0, newH)
        end
    end)
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function Console.log(text)
    table.insert(lines, tostring(text))
    while #lines > MAX_LINES do
        table.remove(lines, 1)
    end
    
    print(tostring(text))
    
    if textBox and textBox.Parent then
        textBox.Text = table.concat(lines, "\n")
    end
end

function Console.clear()
    lines = {}
    if textBox and textBox.Parent then
        textBox.Text = ""
    end
end

function Console.show()
    ensureUI()
    if mainFrame then
        mainFrame.Visible = true
        isVisible = true
    end
    -- Refresh text in case lines were added while hidden
    if textBox and #lines > 0 then
        textBox.Text = table.concat(lines, "\n")
    end
end

function Console.hide()
    if mainFrame then
        mainFrame.Visible = false
        isVisible = false
    end
end

function Console.toggle()
    if isVisible then Console.hide() else Console.show() end
end

function Console.destroy()
    if gui then gui:Destroy(); gui = nil; mainFrame = nil; textBox = nil end
end

return Console
