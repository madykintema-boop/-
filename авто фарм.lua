local player = game.Players.LocalPlayer
local uis = game:GetService("UserInputService")
local rs = game:GetService("RunService")
local cam = workspace.CurrentCamera
local vim = game:GetService("VirtualInputManager")

local orbitHeight = -200
local orbitSpeed = 0.002
local extraDistance = 700
local clickInterval = 5

local orbiting = false
local connection = nil
local angle = 0
local currentOrbitRadius = 50
local lastSizeCheck = 0
local bestTornado = nil
local clickTask = nil

if not _G.FullBrightExecuted then
    _G.FullBrightEnabled = true
    _G.NormalLightingSettings = {
        Brightness = game:GetService("Lighting").Brightness,
        ClockTime = game:GetService("Lighting").ClockTime,
        FogEnd = game:GetService("Lighting").FogEnd,
        GlobalShadows = game:GetService("Lighting").GlobalShadows,
        Ambient = game:GetService("Lighting").Ambient
    }
    local Lighting = game:GetService("Lighting")
    Lighting.Brightness = 1
    Lighting.ClockTime = 12
    Lighting.FogEnd = 786543
    Lighting.GlobalShadows = false
    Lighting.Ambient = Color3.fromRGB(178, 178, 178)
    _G.FullBrightExecuted = true
end

local function equipCamera()
    local char = player.Character
    if not char then return false end
    if char:FindFirstChild("Handheld Camera") then return true end
    local camera = player.Backpack:FindFirstChild("Handheld Camera")
    if camera then
        camera.Parent = char
        task.wait(0.3)
        return true
    end
    return false
end

local function enableFirstPerson()
    vim:SendKeyEvent(true, Enum.KeyCode.I, false, game)
    task.wait(5)
    vim:SendKeyEvent(false, Enum.KeyCode.I, false, game)
end

local function setupCamera()
    if equipCamera() then
        task.wait(0.5)
        enableFirstPerson()
    end
end

local function startAutoClick()
    if clickTask then task.cancel(clickTask) end
    clickTask = task.spawn(function()
        while orbiting do
            local char = player.Character
            if char and char:FindFirstChild("Handheld Camera") then
                local viewport = cam.ViewportSize
                pcall(function()
                    vim:SendMouseButtonEvent(viewport.X/2, viewport.Y/2 + 5, 0, true, game, 1)
                    task.wait(0.05)
                    vim:SendMouseButtonEvent(viewport.X/2, viewport.Y/2 + 5, 0, false, game, 1)
                end)
            end
            task.wait(clickInterval)
        end
    end)
end

local function stopAutoClick()
    if clickTask then
        task.cancel(clickTask)
        clickTask = nil
    end
end

local function findBiggestTornado()
    local storms = workspace:FindFirstChild("storm_related")
    if not storms then return nil end
    local stormsFolder = storms:FindFirstChild("storms")
    if not stormsFolder then return nil end
    local biggest, biggestSize = nil, 0
    for _, storm in ipairs(stormsFolder:GetChildren()) do
        local rotation = storm:FindFirstChild("rotation")
        if rotation then
            for _, part in ipairs(rotation:GetDescendants()) do
                if part.Name == "tornado_scan" and part:IsA("BasePart") then
                    local size = (part.Size.X + part.Size.Z) / 2
                    if size > biggestSize then
                        biggestSize = size
                        biggest = part
                    end
                end
            end
        end
    end
    return biggest
end

local function stopOrbit()
    orbiting = false
    if connection then connection:Disconnect() connection = nil end
    stopAutoClick()
    workspace.Gravity = 196.2
end

local function startOrbit()
    setupCamera()
    bestTornado = findBiggestTornado()
    if not bestTornado then return false end
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    orbiting = true
    angle = 0
    currentOrbitRadius = (bestTornado.Size.X + bestTornado.Size.Z) / 2 + extraDistance
    workspace.Gravity = 0
    lastSizeCheck = tick()
    startAutoClick()

    connection = rs.Heartbeat:Connect(function()
        if not orbiting then return end

        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health <= 0 then
            game:GetService("ReplicatedStorage").events.plr_respawn:FireServer()
            task.wait(0.5)
            return
        end

        if tick() - lastSizeCheck > 1 then
            lastSizeCheck = tick()
            local newBest = findBiggestTornado()
            if newBest then
                local newSize = (newBest.Size.X + newBest.Size.Z) / 2
                local oldSize = bestTornado and ((bestTornado.Size.X + bestTornado.Size.Z) / 2) or 0
                if newSize > oldSize then
                    bestTornado = newBest
                    currentOrbitRadius = (bestTornado.Size.X + bestTornado.Size.Z) / 2 + extraDistance
                end
            end
        end

        if not bestTornado or not bestTornado.Parent then
            bestTornado = findBiggestTornado()
            if not bestTornado then return end
            currentOrbitRadius = (bestTornado.Size.X + bestTornado.Size.Z) / 2 + extraDistance
        end

        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        angle = angle + orbitSpeed
        local pos = bestTornado.Position + Vector3.new(math.cos(angle) * currentOrbitRadius, orbitHeight, math.sin(angle) * currentOrbitRadius)
        hrp.CFrame = CFrame.new(pos, bestTornado.Position)

        cam.CameraType = Enum.CameraType.Custom
        cam.CFrame = CFrame.new(cam.CFrame.Position, bestTornado.Position)
    end)
    return true
end

player.CharacterAdded:Connect(function()
    task.wait(1)
    setupCamera()
    if orbiting then
        bestTornado = findBiggestTornado()
        if bestTornado then
            local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                currentOrbitRadius = (bestTornado.Size.X + bestTornado.Size.Z) / 2 + extraDistance
                local pos = bestTornado.Position + Vector3.new(0, orbitHeight, currentOrbitRadius)
                hrp.CFrame = CFrame.new(pos, bestTornado.Position)
                task.wait(0.5)
                startOrbit()
            end
        end
    end
end)

uis.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.Z then
        if orbiting then stopOrbit() else startOrbit() end
    end
end)

local iPressed = false
local iHoldStart = 0
uis.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.I then
        iPressed = true
        iHoldStart = tick()
        task.spawn(function()
            while iPressed and tick() - iHoldStart < 5 do
                task.wait(0.1)
            end
            if iPressed and tick() - iHoldStart >= 5 then
                enableFirstPerson()
            end
        end)
    end
end)
uis.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.I then iPressed = false end
end)
