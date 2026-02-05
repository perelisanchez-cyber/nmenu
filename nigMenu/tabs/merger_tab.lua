--[[
    ============================================================================
    nigMenu - Merger Tab UI
    ============================================================================
    
    Creates the UI for pet auto-merge settings
]]

local MergerTab = {}

local NM = _G.nigMenu
local Config = NM.Config
local Utils = NM.Utils
local T = Config.Theme
local TS = Config.Services.TweenService

-- UI references
local statusDot, statusLabel

function MergerTab.init()
    local panel = Config.UI.Tabs['Merger']
    if not panel then return end
    
    local yOffset = 0
    
    -- Main merge card
    local mergeCard = Utils.createCard(panel, nil, 160, yOffset)
    
    Utils.createIcon(mergeCard, '🔮', Color3.fromRGB(180, 100, 255), 60, UDim2.new(0, 15, 0, 20))
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 200, 0, 22),
        Position = UDim2.new(0, 85, 0, 20),
        BackgroundTransparency = 1,
        Text = 'PET AUTO-MERGE',
        TextColor3 = Color3.fromRGB(180, 100, 255),
        TextSize = 16,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = mergeCard
    })
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 250, 0, 16),
        Position = UDim2.new(0, 85, 0, 44),
        BackgroundTransparency = 1,
        Text = 'Automatically merge pets to higher tiers',
        TextColor3 = T.TextMuted,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = mergeCard
    })
    
    -- Toggle container
    local toggleBg = Utils.create('Frame', {
        Size = UDim2.new(0, 200, 0, 36),
        Position = UDim2.new(0, 85, 0, 70),
        BackgroundColor3 = T.CardHover,
        BorderSizePixel = 0,
        Parent = mergeCard
    })
    Utils.addCorner(toggleBg, 8)
    
    Utils.create('TextLabel', {
        Size = UDim2.new(0, 100, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = 'Enabled',
        TextColor3 = T.TextDim,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = toggleBg
    })
    
    local isEnabled = Config.Toggles.starAutoMergeSettings.enabled
    
    local mergeToggleBg = Utils.create('Frame', {
        Size = UDim2.new(0, 50, 0, 26),
        Position = UDim2.new(1, -58, 0.5, -13),
        BackgroundColor3 = isEnabled and T.Success or T.CardHover,
        BorderSizePixel = 0,
        Parent = toggleBg
    })
    Utils.addCorner(mergeToggleBg, 13)
    
    local mergeToggleCircle = Utils.create('Frame', {
        Size = UDim2.new(0, 22, 0, 22),
        Position = isEnabled and UDim2.new(1, -24, 0.5, -11) or UDim2.new(0, 2, 0.5, -11),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Parent = mergeToggleBg
    })
    Utils.addCorner(mergeToggleCircle, 11)
    
    local mergeToggleBtn = Utils.create('TextButton', {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = '',
        Parent = toggleBg
    })
    
    mergeToggleBtn.MouseButton1Click:Connect(function()
        local nowEnabled = not Config.Toggles.starAutoMergeSettings.enabled
        
        if NM.Features.merger then
            NM.Features.merger.setEnabled(nowEnabled)
        end
        
        TS:Create(mergeToggleBg, TweenInfo.new(0.2), {
            BackgroundColor3 = nowEnabled and T.Success or T.CardHover
        }):Play()
        
        TS:Create(mergeToggleCircle, TweenInfo.new(0.2), {
            Position = nowEnabled and UDim2.new(1, -24, 0.5, -11) or UDim2.new(0, 2, 0.5, -11)
        }):Play()
    end)
    
    -- Status indicator
    statusDot = Utils.create('Frame', {
        Size = UDim2.new(0, 8, 0, 8),
        Position = UDim2.new(0, 88, 0, 115),
        BackgroundColor3 = isEnabled and T.Success or T.TextMuted,
        BorderSizePixel = 0,
        Parent = mergeCard
    })
    Utils.addCorner(statusDot, 4)
    
    statusLabel = Utils.create('TextLabel', {
        Size = UDim2.new(0, 150, 0, 14),
        Position = UDim2.new(0, 102, 0, 112),
        BackgroundTransparency = 1,
        Text = isEnabled and 'Running...' or 'Disabled',
        TextColor3 = isEnabled and T.Success or T.TextMuted,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = mergeCard
    })
    
    -- Status update loop
    task.spawn(function()
        while Config.State.running do
            if statusDot and statusLabel then
                local enabled = Config.Toggles.starAutoMergeSettings.enabled
                statusDot.BackgroundColor3 = enabled and T.Success or T.TextMuted
                statusLabel.Text = enabled and 'Running...' or 'Disabled'
                statusLabel.TextColor3 = enabled and T.Success or T.TextMuted
            end
            task.wait(1)
        end
    end)
    
    yOffset = yOffset + 168
    
    -- Prestige selection card
    local prestigeCard = Utils.createCard(panel, nil, 220, yOffset)
    
    Utils.create('TextLabel', {
        Size = UDim2.new(1, -20, 0, 20),
        Position = UDim2.new(0, 12, 0, 12),
        BackgroundTransparency = 1,
        Text = 'MAX PRESTIGE LEVEL',
        TextColor3 = T.Text,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = prestigeCard
    })
    
    Utils.create('TextLabel', {
        Size = UDim2.new(1, -20, 0, 14),
        Position = UDim2.new(0, 12, 0, 32),
        BackgroundTransparency = 1,
        Text = 'Pets will be merged up to this tier',
        TextColor3 = T.TextMuted,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = prestigeCard
    })
    
    local prestigeRows = {}
    
    for i, pdata in ipairs(Config.Constants.PRESTIGE_DATA) do
        local rowY = 52 + (i - 1) * 32
        local isSelected = Config.Toggles.starAutoMergeSettings.maxPrestige == pdata.name
        
        local prow = Utils.create('Frame', {
            Size = UDim2.new(1, -24, 0, 28),
            Position = UDim2.new(0, 12, 0, rowY),
            BackgroundColor3 = isSelected and pdata.color or T.CardHover,
            BackgroundTransparency = isSelected and 0.7 or 0,
            BorderSizePixel = 0,
            Parent = prestigeCard
        })
        Utils.addCorner(prow, 6)
        
        if isSelected then
            Utils.addStroke(prow, pdata.color, 2)
        end
        
        Utils.create('TextLabel', {
            Size = UDim2.new(0, 60, 1, 0),
            Position = UDim2.new(0, 8, 0, 0),
            BackgroundTransparency = 1,
            Text = pdata.icon,
            TextColor3 = Color3.fromRGB(255, 200, 80),
            TextSize = 13,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = prow
        })
        
        local nameLabel = Utils.create('TextLabel', {
            Size = UDim2.new(0, 80, 1, 0),
            Position = UDim2.new(0, 70, 0, 0),
            BackgroundTransparency = 1,
            Text = pdata.name,
            TextColor3 = isSelected and Color3.new(1, 1, 1) or T.TextDim,
            TextSize = 13,
            Font = isSelected and Enum.Font.GothamBold or Enum.Font.GothamMedium,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = prow
        })
        
        local checkLabel = Utils.create('TextLabel', {
            Size = UDim2.new(0, 24, 1, 0),
            Position = UDim2.new(1, -32, 0, 0),
            BackgroundTransparency = 1,
            Text = isSelected and '✓' or '',
            TextColor3 = Color3.new(1, 1, 1),
            TextSize = 14,
            Font = Enum.Font.GothamBold,
            Parent = prow
        })
        
        prestigeRows[pdata.name] = {
            row = prow,
            nameLabel = nameLabel,
            checkLabel = checkLabel,
            data = pdata
        }
        
        local pbtn = Utils.create('TextButton', {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = '',
            Parent = prow
        })
        
        local prestigeName = pdata.name
        local prestigeColor = pdata.color
        
        pbtn.MouseButton1Click:Connect(function()
            if NM.Features.merger then
                NM.Features.merger.setMaxPrestige(prestigeName)
            end
            
            -- Update all rows
            for name, rowData in pairs(prestigeRows) do
                local isSel = name == prestigeName
                
                rowData.row.BackgroundTransparency = isSel and 0.7 or 0
                rowData.row.BackgroundColor3 = isSel and rowData.data.color or T.CardHover
                rowData.nameLabel.TextColor3 = isSel and Color3.new(1, 1, 1) or T.TextDim
                rowData.nameLabel.Font = isSel and Enum.Font.GothamBold or Enum.Font.GothamMedium
                rowData.checkLabel.Text = isSel and '✓' or ''
                
                -- Update stroke
                local stroke = rowData.row:FindFirstChildOfClass('UIStroke')
                if stroke then stroke:Destroy() end
                if isSel then
                    Utils.addStroke(rowData.row, rowData.data.color, 2)
                end
            end
        end)
    end
    
    yOffset = yOffset + 228
    panel.CanvasSize = UDim2.new(0, 0, 0, yOffset)
end

function MergerTab.onShow()
    -- Nothing special needed
end

return MergerTab
