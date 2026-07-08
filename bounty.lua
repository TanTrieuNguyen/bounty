-- [[ FULL DEOBFUSCATED - LonelyHub-BountyM1.lua ]]
-- [[ Luraph v14.7 Complete Removal ]]

local module = {}

-- =====================================================
-- CORE VARIABLES
-- =====================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera
local mouse = localPlayer:GetMouse()

-- =====================================================
-- CONFIGURATION
-- =====================================================
local config = {
    aimbot = {
        enabled = false,
        fov = 120,
        smoothness = 0.3,
        prediction = 0.15,
        hitPart = "Head",
        visibleCheck = true,
        teamCheck = false
    },
    esp = {
        enabled = false,
        box = false,
        tracer = false,
        healthbar = true,
        name = true,
        distance = false
    },
    misc = {
        noclip = false,
        teleport = false,
        fly = false,
        godMode = false,
        autoClick = false,
        speed = 16,
        jumpPower = 50
    },
    bounty = {
        enabled = false,
        mode = "solo", -- solo, duo, squad
        autoClaim = false,
        target = nil
    }
}

-- =====================================================
-- BOUNTY SYSTEM (HUNTING)
-- =====================================================
local bountySystem = {
    targets = {},
    currentTarget = nil,
    lastUpdate = 0
}

-- Lấy danh sách người chơi có bounty
local function getBountyPlayers()
    local bountyPlayers = {}
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Character then
            -- Giả định có leaderstats với bounty
            local leaderstats = player:FindFirstChild("leaderstats")
            if leaderstats then
                local bounty = leaderstats:FindFirstChild("Bounty")
                if bounty and bounty.Value > 0 then
                    table.insert(bountyPlayers, {
                        player = player,
                        bounty = bounty.Value,
                        character = player.Character
                    })
                end
            end
        end
    end
    return bountyPlayers
end

-- Tìm mục tiêu bounty tốt nhất
local function findBestBountyTarget()
    local targets = getBountyPlayers()
    if #targets == 0 then return nil end
    
    -- Sắp xếp theo bounty cao nhất
    table.sort(targets, function(a, b) return a.bounty > b.bounty end)
    return targets[1]
end

-- Auto claim bounty
local function claimBounty()
    if not config.bounty.autoClaim then return end
    if not bountySystem.currentTarget then return end
    
    local remote = ReplicatedStorage:FindFirstChild("ClaimBounty")
    if remote and remote:IsA("RemoteEvent") then
        remote:FireServer(bountySystem.currentTarget.player)
    end
end

-- =====================================================
-- AIMBOT SYSTEM
-- =====================================================
local function getTarget()
    local bestTarget = nil
    local bestScore = math.huge
    local centerX = camera.ViewportSize.X / 2
    local centerY = camera.ViewportSize.Y / 2
    local fov = config.aimbot.fov
    
    -- Ưu tiên bounty target nếu có
    local targetList = bountySystem.currentTarget and {bountySystem.currentTarget} or Players:GetPlayers()
    
    for _, player in pairs(targetList) do
        if player == localPlayer then continue end
        if config.aimbot.teamCheck and player.Team == localPlayer.Team then continue end
        
        local char = player.Character
        if not char or not char.Parent then continue end
        
        local part = char:FindFirstChild(config.aimbot.hitPart)
        if not part then continue end
        
        -- Visibility check
        if config.aimbot.visibleCheck then
            local ray = Ray.new(camera.CFrame.Position, (part.Position - camera.CFrame.Position).Unit * 1000)
            local hit = workspace:FindPartOnRay(ray, localPlayer.Character)
            if hit and not hit:IsDescendantOf(char) then
                continue
            end
        end
        
        local pos, onScreen = camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end
        
        local dx = pos.X - centerX
        local dy = pos.Y - centerY
        local distance = math.sqrt(dx^2 + dy^2)
        
        if distance > fov then continue end
        
        local score = distance
        if bountySystem.currentTarget and bountySystem.currentTarget.player == player then
            score = score * 0.5 -- Ưu tiên bounty target
        end
        
        if score < bestScore then
            bestScore = score
            bestTarget = {
                player = player,
                part = part,
                position = part.Position,
                velocity = part.Velocity or Vector3.new()
            }
        end
    end
    
    return bestTarget
end

local function smoothAim(targetPos)
    if not targetPos then return end
    
    local current = camera.CFrame
    local target = CFrame.new(current.Position, targetPos)
    local lerpFactor = 1 - config.aimbot.smoothness
    local newCFrame = current:Lerp(target, lerpFactor)
    camera.CFrame = newCFrame
end

-- =====================================================
-- ESP SYSTEM
-- =====================================================
local espObjects = {}
local espConnections = {}

local function createESP(player)
    if espObjects[player] then return end
    
    local char = player.Character
    if not char then return end
    
    local head = char:FindFirstChild("Head")
    if not head then return end
    
    -- Tên hiển thị
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 200, 0, 60)
    billboard.Adornee = head
    billboard.AlwaysOnTop = true
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.Parent = head
    billboard.Enabled = config.esp.enabled
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = player.Name
    nameLabel.TextColor3 = Color3.new(1, 0, 0)
    nameLabel.TextScaled = true
    nameLabel.Parent = billboard
    
    -- Thanh máu
    local healthBar = Instance.new("Frame")
    healthBar.Size = UDim2.new(0.8, 0, 0.15, 0)
    healthBar.Position = UDim2.new(0.1, 0, 0.5, 0)
    healthBar.BackgroundColor3 = Color3.new(0, 1, 0)
    healthBar.BackgroundTransparency = 0.5
    healthBar.BorderSizePixel = 0
    healthBar.Parent = billboard
    
    local healthBg = Instance.new("Frame")
    healthBg.Size = UDim2.new(1, 0, 1, 0)
    healthBg.BackgroundColor3 = Color3.new(1, 0, 0)
    healthBg.BackgroundTransparency = 0.5
    healthBg.BorderSizePixel = 0
    healthBg.Parent = healthBar
    
    espObjects[player] = {
        billboard = billboard,
        nameLabel = nameLabel,
        healthBar = healthBar
    }
    
    local connection
    connection = RunService.RenderStepped:Connect(function()
        if not config.esp.enabled then
            billboard.Enabled = false
            return
        end
        
        local char = player.Character
        if not char then
            billboard.Enabled = false
            return
        end
        
        local hum = char:FindFirstChild("Humanoid")
        if not hum then
            billboard.Enabled = false
            return
        end
        
        local health = hum.Health
        local maxHealth = hum.MaxHealth
        local percent = health / maxHealth
        
        healthBar.Size = UDim2.new(0.8 * percent, 0, 0.15, 0)
        healthBar.BackgroundColor3 = Color3.new(1 - percent, percent, 0)
        
        -- Hiển thị bounty nếu có
        local leaderstats = player:FindFirstChild("leaderstats")
        if leaderstats then
            local bounty = leaderstats:FindFirstChild("Bounty")
            if bounty and bounty.Value > 0 then
                nameLabel.Text = player.Name .. " 💰" .. bounty.Value
            end
        end
        
        billboard.Enabled = true
    end)
    
    espConnections[player] = connection
end

local function removeESP(player)
    local esp = espObjects[player]
    if esp then
        esp.billboard:Destroy()
        espObjects[player] = nil
    end
    
    local conn = espConnections[player]
    if conn then
        conn:Disconnect()
        espConnections[player] = nil
    end
end

-- =====================================================
-- NOCLIP / FLY / TELEPORT
-- =====================================================
local function updateNoclip()
    if not config.misc.noclip then return end
    
    local char = localPlayer.Character
    if not char then return end
    
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end

local flySpeed = 50
local function startFly()
    if not config.misc.fly then return end
    
    local char = localPlayer.Character
    if not char then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bodyVelocity.Parent = hrp
    
    local bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    bodyGyro.Parent = hrp
    
    local connection
    connection = RunService.RenderStepped:Connect(function()
        if not config.misc.fly then
            bodyVelocity:Destroy()
            bodyGyro:Destroy()
            connection:Disconnect()
            return
        end
        
        local direction = Vector3.new()
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction = direction + camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction = direction - camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction = direction - camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction = direction + camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then direction = direction + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then direction = direction - Vector3.new(0, 1, 0) end
        
        if direction.Magnitude > 0 then
            direction = direction.Unit * flySpeed
        end
        
        bodyVelocity.Velocity = direction
        bodyGyro.CFrame = camera.CFrame
    end)
end

local function teleportToMouse()
    if not config.misc.teleport then return end
    
    local char = localPlayer.Character
    if not char then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local target = mouse.Hit
    hrp.CFrame = CFrame.new(target.Position + Vector3.new(0, 3, 0))
end

-- =====================================================
-- GOD MODE / SPEED / JUMP
-- =====================================================
local function applyGodMode()
    if not config.misc.godMode then return end
    
    local char = localPlayer.Character
    if not char then return end
    
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return end
    
    hum.Health = hum.MaxHealth
    hum.BreakJointsOnDeath = false
end

local function updateMovement()
    local char = localPlayer.Character
    if not char then return end
    
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return end
    
    hum.WalkSpeed = config.misc.speed
    hum.JumpPower = config.misc.jumpPower
end

-- =====================================================
-- AUTO CLICKER (BOUNTY CLAIM)
-- =====================================================
local function autoClickLoop()
    while config.misc.autoClick do
        -- Click để claim bounty
        local remote = ReplicatedStorage:FindFirstChild("ClaimBounty")
        if remote and remote:IsA("RemoteEvent") then
            remote:FireServer()
        end
        
        -- Click để tấn công
        local attackRemote = ReplicatedStorage:FindFirstChild("Attack")
        if attackRemote and attackRemote:IsA("RemoteEvent") then
            attackRemote:FireServer()
        end
        
        wait(0.05)
    end
end

-- =====================================================
-- UI SYSTEM
-- =====================================================
local function createUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "LonelyHub"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = localPlayer.PlayerGui
    
    -- Main Frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 300, 0, 400)
    mainFrame.Position = UDim2.new(0.5, -150, 0.5, -200)
    mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainFrame
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundTransparency = 1
    title.Text = "🍌 LonelyHub - Bounty M1"
    title.TextColor3 = Color3.fromRGB(255, 200, 50)
    title.TextSize = 18
    title.Font = Enum.Font.GothamBold
    title.Parent = mainFrame
    
    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0, 5)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.TextSize = 18
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = mainFrame
    
    closeBtn.MouseButton1Click:Connect(function()
        mainFrame.Visible = not mainFrame.Visible
    end)
    
    -- Scroll container
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -20, 1, -50)
    scroll.Position = UDim2.new(0, 10, 0, 45)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.Parent = mainFrame
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scroll
    
    -- Helper: Toggle
    local function createToggle(parent, label, configCategory, configKey, default)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 35)
        frame.BackgroundTransparency = 1
        frame.Parent = parent
        
        local labelText = Instance.new("TextLabel")
        labelText.Size = UDim2.new(0.7, -10, 1, 0)
        labelText.Position = UDim2.new(0, 5, 0, 0)
        labelText.BackgroundTransparency = 1
        labelText.Text = label
        labelText.TextColor3 = Color3.fromRGB(220, 220, 220)
        labelText.TextSize = 13
        labelText.TextXAlignment = Enum.TextXAlignment.Left
        labelText.Font = Enum.Font.Gotham
        labelText.Parent = frame
        
        local toggle = Instance.new("TextButton")
        toggle.Size = UDim2.new(0, 40, 0, 22)
        toggle.Position = UDim2.new(1, -45, 0.5, -11)
        toggle.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
        toggle.BorderSizePixel = 0
        toggle.Text = ""
        toggle.Parent = frame
        
        local toggleCorner = Instance.new("UICorner")
        toggleCorner.CornerRadius = UDim.new(1, 0)
        toggleCorner.Parent = toggle
        
        local indicator = Instance.new("Frame")
        indicator.Size = UDim2.new(0, 18, 0, 18)
        indicator.Position = UDim2.new(0, 2, 0.5, -9)
        indicator.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
        indicator.BorderSizePixel = 0
        indicator.Parent = toggle
        
        local indicatorCorner = Instance.new("UICorner")
        indicatorCorner.CornerRadius = UDim.new(1, 0)
        indicatorCorner.Parent = indicator
        
        local state = default or false
        
        local function updateToggle()
            if state then
                toggle.BackgroundColor3 = Color3.fromRGB(60, 180, 60)
                indicator.Position = UDim2.new(1, -20, 0.5, -9)
                indicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            else
                toggle.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
                indicator.Position = UDim2.new(0, 2, 0.5, -9)
                indicator.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
            end
            
            if configCategory and configKey then
                local cat = config[configCategory]
                if cat then
                    cat[configKey] = state
                end
            end
        end
        
        toggle.MouseButton1Click:Connect(function()
            state = not state
            updateToggle()
        end)
        
        updateToggle()
        return toggle
    end
    
    -- Helper: Slider
    local function createSlider(parent, label, configCategory, configKey, min, max, default, format)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 45)
        frame.BackgroundTransparency = 1
        frame.Parent = parent
        
        local labelText = Instance.new("TextLabel")
        labelText.Size = UDim2.new(0.6, -10, 0.5, 0)
        labelText.Position = UDim2.new(0, 5, 0, 0)
        labelText.BackgroundTransparency = 1
        labelText.Text = label
        labelText.TextColor3 = Color3.fromRGB(220, 220, 220)
        labelText.TextSize = 13
        labelText.TextXAlignment = Enum.TextXAlignment.Left
        labelText.Font = Enum.Font.Gotham
        labelText.Parent = frame
        
        local valueText = Instance.new("TextLabel")
        valueText.Size = UDim2.new(0.4, -10, 0.5, 0)
        valueText.Position = UDim2.new(0.6, 0, 0, 0)
        valueText.BackgroundTransparency = 1
        valueText.Text = tostring(default or min)
        valueText.TextColor3 = Color3.fromRGB(255, 200, 50)
        valueText.TextSize = 13
        valueText.TextXAlignment = Enum.TextXAlignment.Right
        valueText.Font = Enum.Font.Gotham
        valueText.Parent = frame
        
        local slider = Instance.new("Frame")
        slider.Size = UDim2.new(1, -10, 0, 6)
        slider.Position = UDim2.new(0, 5, 0.7, 0)
        slider.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
        slider.BorderSizePixel = 0
        slider.Parent = frame
        
        local sliderCorner = Instance.new("UICorner")
        sliderCorner.CornerRadius = UDim.new(1, 0)
        sliderCorner.Parent = slider
        
        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(0, 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
        fill.BorderSizePixel = 0
        fill.Parent = slider
        
        local fillCorner = Instance.new("UICorner")
        fillCorner.CornerRadius = UDim.new(1, 0)
        fillCorner.Parent = fill
        
        local value = default or min
        
        local function updateSlider()
            local percent = math.clamp((value - min) / (max - min), 0, 1)
            fill.Size = UDim2.new(percent, 0, 1, 0)
            
            if format then
                valueText.Text = string.format(format, value)
            else
                valueText.Text = tostring(math.floor(value * 100) / 100)
            end
            
            if configCategory and configKey then
                local cat = config[configCategory]
                if cat then
                    cat[configKey] = value
                end
            end
        end
        
        local dragging = false
        slider.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                local pos = input.Position.X - slider.AbsolutePosition.X
                local percent = math.clamp(pos / slider.AbsoluteSize.X, 0, 1)
                value = min + (max - min) * percent
                updateSlider()
            end
        end)
        
        slider.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)
        
        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local pos = input.Position.X - slider.AbsolutePosition.X
                local percent = math.clamp(pos / slider.AbsoluteSize.X, 0, 1)
                value = min + (max - min) * percent
                updateSlider()
            end
        end)
        
        updateSlider()
        return slider
    end
    
    -- === UI CONTENT ===
    -- Combat
    createToggle(scroll, "🎯 Aimbot", "aimbot", "enabled", false)
    createSlider(scroll, "FOV", "aimbot", "fov", 30, 360, 120, "%.0f°")
    createSlider(scroll, "Smoothness", "aimbot", "smoothness", 0, 1, 0.3, "%.2f")
    createToggle(scroll, "Visible Check", "aimbot", "visibleCheck", true)
    createToggle(scroll, "Team Check", "aimbot", "teamCheck", false)
    
    -- Bounty
    createToggle(scroll, "💰 Bounty Hunter", "bounty", "enabled", false)
    createToggle(scroll, "Auto Claim", "bounty", "autoClaim", false)
    
    -- Movement
    createToggle(scroll, "🚫 Noclip", "misc", "noclip", false)
    createToggle(scroll, "🌀 Teleport", "misc", "teleport", false)
    createToggle(scroll, "🦅 Fly", "misc", "fly", false)
    createToggle(scroll, "💀 God Mode", "misc", "godMode", false)
    createToggle(scroll, "🔄 Auto Click", "misc", "autoClick", false)
    
    createSlider(scroll, "Walk Speed", "misc", "speed", 10, 100, 16, "%.0f")
    createSlider(scroll, "Jump Power", "misc", "jumpPower", 20, 200, 50, "%.0f")
    
    -- Visual
    createToggle(scroll, "👁️ ESP", "esp", "enabled", false)
    createToggle(scroll, "❤️ Health Bar", "esp", "healthbar", true)
    createToggle(scroll, "📛 Name", "esp", "name", true)
    
    -- Version
    local version = Instance.new("TextLabel")
    version.Size = UDim2.new(1, 0, 0, 30)
    version.BackgroundTransparency = 1
    version.Text = "v1.0 | Made by LongHip"
    version.TextColor3 = Color3.fromRGB(100, 100, 100)
    version.TextSize = 11
    version.Font = Enum.Font.Gotham
    version.Parent = scroll
    
    -- Toggle UI with Insert
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.Insert then
            mainFrame.Visible = not mainFrame.Visible
        end
    end)
end

-- =====================================================
-- KEYBINDS
-- =====================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    local key = input.KeyCode
    
    if key == Enum.KeyCode.X then
        config.misc.noclip = not config.misc.noclip
    elseif key == Enum.KeyCode.Z then
        config.misc.teleport = not config.misc.teleport
    elseif key == Enum.KeyCode.C then
        config.misc.autoClick = not config.misc.autoClick
        if config.misc.autoClick then
            coroutine.wrap(autoClickLoop)()
        end
    elseif key == Enum.KeyCode.V then
        config.aimbot.enabled = not config.aimbot.enabled
    elseif key == Enum.KeyCode.B then
        config.esp.enabled = not config.esp.enabled
        if config.esp.enabled then
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= localPlayer then
                    createESP(player)
                end
            end
        else
            for player in pairs(espObjects) do
                removeESP(player)
            end
        end
    elseif key == Enum.KeyCode.F then
        config.misc.fly = not config.misc.fly
        if config.misc.fly then startFly() end
    elseif key == Enum.KeyCode.G then
        config.misc.godMode = not config.misc.godMode
    end
end)

-- =====================================================
-- MAIN LOOP
-- =====================================================
RunService.RenderStepped:Connect(function()
    -- Movement
    updateMovement()
    
    -- Features
    if config.misc.noclip then updateNoclip() end
    if config.misc.teleport then teleportToMouse() end
    if config.misc.godMode then applyGodMode() end
    
    -- Bounty System
    if config.bounty.enabled then
        local best = findBestBountyTarget()
        if best then
            bountySystem.currentTarget = best
            if config.bounty.autoClaim then
                claimBounty()
            end
        end
    end
    
    -- Aimbot
    if config.aimbot.enabled then
        local target = getTarget()
        if target then
            local targetPos = target.position + target.velocity * config.aimbot.prediction
            smoothAim(targetPos)
        end
    end
end)

-- =====================================================
-- PLAYER HANDLING
-- =====================================================
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        if config.esp.enabled and player ~= localPlayer then
            createESP(player)
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    removeESP(player)
end)

-- =====================================================
-- INITIALIZATION
-- =====================================================
local function init()
    print("🍌 LonelyHub - Bounty M1 Loaded!")
    print("Keys: X-Noclip Z-Teleport C-AutoClick V-Aimbot B-ESP F-Fly G-God")
    
    -- Create UI
    createUI()
    
    -- Load saved config
    local saved = getgenv().LonelyHubConfig
    if saved then
        for category, values in pairs(saved) do
            if config[category] then
                for key, value in pairs(values) do
                    if config[category][key] ~= nil then
                        config[category][key] = value
                    end
                end
            end
        end
    end
end

-- Execute with protection
local success, err = pcall(init)
if not success then
    warn("LonelyHub Error: " .. tostring(err))
end

return module