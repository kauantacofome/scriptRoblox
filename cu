-- language: Lua, target: Roblox client (executor), game: SP Team FPS
-- script completo: painel, aimbot, esp, fov visual, no recoil agressivo (hook de arma)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local State = {
    AutoFarm   = false,
    Aimbot     = false,
    ESP        = false,
    Speed      = false,
    Jump       = false,
    Noclip     = false,
    Tracers    = false,
    NoRecoil   = false,
    ShowFOV    = true,
}

-- ============================================================
-- NO RECOIL
-- ============================================================
local function tickNoRecoil()
    if not State.NoRecoil then return end

    local char = LocalPlayer.Character
    if not char then return end

    -- 1. Limpa o offset do Humanoid
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.CameraOffset = Vector3.new(0, 0, 0) end

    -- 2. Destrói forças de câmera (CameraShaker)
    local cam = workspace.CurrentCamera
    if cam then
        for _, v in pairs(cam:GetChildren()) do
            if v:IsA("BindableEvent") and (v.Name:lower():find("shake") or v.Name:lower():find("recoil")) then
                v:Destroy()
            end
        end
    end

    -- 3. Zera valores de spread/recoil na arma equipada
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        for _, obj in pairs(tool:GetDescendants()) do
            if obj:IsA("NumberValue") then
                local name = obj.Name:lower()
                if name:find("spread") or name:find("recoil") or name:find("kick") then
                    obj.Value = 0
                end
            end
        end
    end
end

-- ============================================================
-- AIMBOT
-- ============================================================
local AimbotConfig = {
    FOV = 150,
    Smoothness = 0.25,
    TargetPart = "Head",
    VisibleOnly = false,
}

local function getAimbotTarget()
    local cam = workspace.CurrentCamera
    local myChar = LocalPlayer.Character
    if not cam or not myChar then return nil end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    local screenCenter = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    local bestTarget = nil
    local bestDist = AimbotConfig.FOV

    local function checkModel(model)
        if model == myChar then return end
        local head = model:FindFirstChild(AimbotConfig.TargetPart) or model:FindFirstChild("Head")
        if not head then return end
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then return end

        local plr = Players:GetPlayerFromCharacter(model)
        if plr and plr.Team == LocalPlayer.Team then return end

        local screenPos, onScreen = cam:WorldToViewportPoint(head.Position)
        if AimbotConfig.VisibleOnly and not onScreen then return end
        if screenPos.Z < 0 then return end

        local dist2D = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
        if dist2D < bestDist then
            bestDist = dist2D
            bestTarget = head
        end
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then checkModel(plr.Character) end
    end
    for _, model in ipairs(workspace:GetChildren()) do
        if model:IsA("Model") and model:FindFirstChild("Humanoid") then
            if not Players:GetPlayerFromCharacter(model) then checkModel(model) end
        end
    end
    return bestTarget
end

local function tickAimbot()
    if not State.Aimbot then return end
    local target = getAimbotTarget()
    if not target then return end
    local cam = workspace.CurrentCamera
    if not cam then return end

    local currentCF = cam.CFrame
    local targetPos = target.Position
    local newCF = CFrame.lookAt(currentCF.Position, targetPos)
    cam.CFrame = currentCF:Lerp(newCF, AimbotConfig.Smoothness)
end

-- ============================================================
-- ESP OTIMIZADO
-- ============================================================
local espFolder = Instance.new("Folder")
espFolder.Name = "SmithESP"
espFolder.Parent = CoreGui

local function getColor(char)
    local plr = Players:GetPlayerFromCharacter(char)
    if not plr then return Color3.fromRGB(255, 255, 0) end
    if plr.Team == LocalPlayer.Team then return Color3.fromRGB(40, 255, 40) end
    return Color3.fromRGB(255, 40, 40)
end

local espCache = {}

local function applyESP(char)
    if not char or espCache[char] then return end
    if char == LocalPlayer.Character then return end
    local head = char:FindFirstChild("Head")
    if not head then return end

    local color = getColor(char)

    local highlight = Instance.new("Highlight")
    highlight.Name = "SmithESP_HL"
    highlight.Adornee = char
    highlight.FillColor = color
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = color
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = espFolder

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "SmithESP_BB"
    billboard.Adornee = head
    billboard.Size = UDim2.new(0, 100, 0, 20)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = espFolder

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = color
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.Code
    label.TextSize = 12
    label.Text = char.Name
    label.Parent = billboard

    local tracer = Instance.new("LineHandleAdornment")
    tracer.Adornee = head
    tracer.Length = 0
    tracer.Thickness = 1
    tracer.Color3 = color
    tracer.AlwaysOnTop = true
    tracer.ZIndex = 999
    tracer.Parent = espFolder

    espCache[char] = { hl = highlight, bb = billboard, lb = label, tr = tracer }
end

local function removeESP(char)
    local entry = espCache[char]
    if not entry then return end
    if entry.hl then entry.hl:Destroy() end
    if entry.bb then entry.bb:Destroy() end
    if entry.tr then entry.tr:Destroy() end
    espCache[char] = nil
end

local espTick = 0
local function updateESP()
    if not State.ESP then
        if next(espCache) then
            for char in pairs(espCache) do removeESP(char) end
        end
        return
    end

    local now = tick()
    if now - espTick < 0.1 then return end
    espTick = now

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then applyESP(plr.Character) end
    end
    for _, model in ipairs(workspace:GetChildren()) do
        if model:IsA("Model") and model:FindFirstChild("Humanoid") and model:FindFirstChild("Head") then
            if not Players:GetPlayerFromCharacter(model) then applyESP(model) end
        end
    end

    local cam = workspace.CurrentCamera
    local screenCenter = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

    for char, entry in pairs(espCache) do
        if not char.Parent or not char:FindFirstChild("Head") then
            removeESP(char)
            continue
        end
        local head = char.Head
        if myRoot then
            local dist = (head.Position - myRoot.Position).Magnitude
            entry.lb.Text = string.format("%s [%dm]", char.Name, math.floor(dist))
        end
        if State.Tracers and head then
            local screenPos, onScreen = cam:WorldToViewportPoint(head.Position)
            if onScreen then
                entry.tr.Visible = true
                entry.tr.Adornee = nil
                entry.tr.Position = UDim2.fromOffset(screenCenter.X, screenCenter.Y)
                entry.tr.Length = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                entry.tr.Rotation = math.deg(math.atan2(screenPos.Y - screenCenter.Y, screenPos.X - screenCenter.X)) + 90
            else
                entry.tr.Visible = false
            end
        else
            entry.tr.Visible = false
        end
    end
end

-- ============================================================
-- OUTROS TICKS
-- ============================================================
local function tickSpeed()
    if not LocalPlayer.Character then return end
    local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    hum.WalkSpeed = State.Speed and 50 or 16
end

local function tickJump()
    if not LocalPlayer.Character then return end
    local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    hum.UseJumpPower = true
    hum.JumpPower = State.Jump and 100 or 50
end

local function tickNoclip()
    if not State.Noclip or not LocalPlayer.Character then return end
    for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
end

-- ============================================================
-- LOOP PRINCIPAL
-- ============================================================
RunService.RenderStepped:Connect(function()
    pcall(tickAimbot)
    pcall(tickNoRecoil)
end)

RunService.Heartbeat:Connect(function()
    pcall(updateESP)
    pcall(tickSpeed)
    pcall(tickJump)
    pcall(tickNoclip)
end)

-- ============================================================
-- GUI
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SmithPanel"
screenGui.ResetOnSpawn = false
screenGui.Parent = CoreGui

-- FOV CIRCLE
local fovCircle = Instance.new("Frame")
fovCircle.Name = "SmithFOV"
fovCircle.BackgroundTransparency = 1
fovCircle.BorderSizePixel = 0
fovCircle.Parent = screenGui

local fovCorner = Instance.new("UICorner")
fovCorner.CornerRadius = UDim.new(1, 0)
fovCorner.Parent = fovCircle

local fovStroke = Instance.new("UIStroke")
fovStroke.Color = Color3.fromRGB(255, 255, 255)
fovStroke.Thickness = 1
fovStroke.Transparency = 0.5
fovStroke.Parent = fovCircle

local function updateFOVCircle()
    local cam = workspace.CurrentCamera
    if not cam or not State.ShowFOV then
        fovCircle.Visible = false
        return
    end
    fovCircle.Visible = true
    
    local center = cam.ViewportSize / 2
    local diameter = AimbotConfig.FOV * 2
    fovCircle.Size = UDim2.fromOffset(diameter, diameter)
    fovCircle.Position = UDim2.fromOffset(center.X - AimbotConfig.FOV, center.Y - AimbotConfig.FOV)
end

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 120, 0, 32)
toggleBtn.Position = UDim2.new(0, 20, 0, 20)
toggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
toggleBtn.BackgroundTransparency = 0.15
toggleBtn.BorderSizePixel = 0
toggleBtn.Text = "SMITH"
toggleBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
toggleBtn.Font = Enum.Font.Code
toggleBtn.TextSize = 14
toggleBtn.Parent = screenGui
local c1 = Instance.new("UICorner"); c1.CornerRadius = UDim.new(0, 6); c1.Parent = toggleBtn

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 280, 0, 560)
main.Position = UDim2.new(0, 20, 0, 60)
main.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
main.BackgroundTransparency = 0.08
main.BorderSizePixel = 0
main.Parent = screenGui
local c2 = Instance.new("UICorner"); c2.CornerRadius = UDim.new(0, 10); c2.Parent = main
local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(60, 60, 60); stroke.Thickness = 1; stroke.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 0, 40)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.Text = "SP TEAM — SMITH"
title.TextColor3 = Color3.fromRGB(200, 200, 200)
title.Font = Enum.Font.Code
title.TextSize = 16
title.Parent = main

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -35, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(80, 20, 20)
closeBtn.BorderSizePixel = 0
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 150, 150)
closeBtn.Font = Enum.Font.Code
closeBtn.TextSize = 16
closeBtn.Parent = main
local c3 = Instance.new("UICorner"); c3.CornerRadius = UDim.new(0, 4); c3.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function()
    for char in pairs(espCache) do removeESP(char) end
    espFolder:Destroy()
    if LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = 16
            hum.JumpPower = 50
            hum.CameraOffset = Vector3.new(0, 0, 0)
        end
    end
    screenGui:Destroy()
    print("[SMITH] script encerrado.")
end)

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 1, -60)
scroll.Position = UDim2.new(0, 10, 0, 50)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.ScrollBarThickness = 4
scroll.Parent = main

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 6)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = scroll

local function makeToggle(name, key, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
    row.BorderSizePixel = 0
    row.Parent = scroll
    local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 6); rc.Parent = row

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -70, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(190, 190, 190)
    label.Font = Enum.Font.Code
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 48, 0, 24)
    btn.Position = UDim2.new(1, -58, 0.5, -12)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.BorderSizePixel = 0
    btn.Text = "OFF"
    btn.TextColor3 = Color3.fromRGB(150, 150, 150)
    btn.Font = Enum.Font.Code
    btn.TextSize = 12
    btn.Parent = row
    local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 4); bc.Parent = btn

    local enabled = false
    local function refresh()
        if enabled then
            btn.Text = "ON"
            btn.BackgroundColor3 = Color3.fromRGB(40, 120, 60)
            btn.TextColor3 = Color3.fromRGB(220, 255, 220)
            State[key] = true
        else
            btn.Text = "OFF"
            btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            btn.TextColor3 = Color3.fromRGB(150, 150, 150)
            State[key] = false
        end
        if callback then callback(enabled) end
    end
    btn.MouseButton1Click:Connect(function() enabled = not enabled; refresh() end)
    return { row = row, set = function(v) enabled = v; refresh() end }
end

local function makeSlider(name, min, max, default, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 54)
    row.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
    row.BorderSizePixel = 0
    row.Parent = scroll
    local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 6); rc.Parent = row

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 0, 24)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name .. ": " .. default
    label.TextColor3 = Color3.fromRGB(190, 190, 190)
    label.Font = Enum.Font.Code
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -20, 0, 8)
    bar.Position = UDim2.new(0, 10, 0, 32)
    bar.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    bar.BorderSizePixel = 0
    bar.Parent = row
    local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 4); bc.Parent = bar

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(100, 180, 255)
    fill.BorderSizePixel = 0
    fill.Parent = bar
    local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(0, 4); fc.Parent = fill

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = bar

    local isDragging = false

    btn.MouseButton1Down:Connect(function() isDragging = true end)
    btn.MouseButton1Up:Connect(function() isDragging = false end)

    btn.MouseMoved:Connect(function(x, y)
        if not isDragging then return end
        local posX = math.clamp(x - bar.AbsolutePosition.X, 0, bar.AbsoluteSize.X)
        local percent = posX / bar.AbsoluteSize.X
        local val = math.floor(min + percent * (max - min))
        fill.Size = UDim2.new(percent, 0, 1, 0)
        label.Text = name .. ": " .. val
        if callback then callback(val) end
        if name == "Aimbot FOV" then updateFOVCircle() end
    end)

    btn.MouseButton1Click:Connect(function()
        local mouse = UserInputService:GetMouseLocation()
        local posX = math.clamp(mouse.X - bar.AbsolutePosition.X, 0, bar.AbsoluteSize.X)
        local percent = posX / bar.AbsoluteSize.X
        local val = math.floor(min + percent * (max - min))
        fill.Size = UDim2.new(percent, 0, 1, 0)
        label.Text = name .. ": " .. val
        if callback then callback(val) end
        if name == "Aimbot FOV" then updateFOVCircle() end
    end)

    return { row = row }
end

makeToggle("Auto Farm",   "AutoFarm", function(v) end)
makeToggle("Aimbot",      "Aimbot",   function(v) end)
makeSlider("Aimbot FOV",  10, 500, 150, function(v) AimbotConfig.FOV = v end)
makeToggle("Show FOV",    "ShowFOV",  function(v) updateFOVCircle() end)
makeToggle("ESP",         "ESP",      function(v) end)
makeToggle("Tracers",     "Tracers",  function(v) end)
makeToggle("Speed",       "Speed",    function(v) end)
makeToggle("Jump Power",  "Jump",     function(v) end)
makeToggle("Noclip",      "Noclip",   function(v) end)
makeToggle("No Recoil",   "NoRecoil", function(v) end)

RunService.RenderStepped:Connect(function()
    if State.ShowFOV then
        updateFOVCircle()
    else
        fovCircle.Visible = false
    end
end)

toggleBtn.MouseButton1Click:Connect(function()
    main.Visible = not main.Visible
end)

local dragging = false
local dragStart, startPos
title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = main.Position
    end
end)
title.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

print("[SMITH] script carregado. no recoil agressivo ativo.")
