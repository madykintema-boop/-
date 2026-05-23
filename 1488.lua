-- =========================================================
-- TWISTED TORNADO AUTO FARM - ORBIT MODE
-- =========================================================

-- Load Orion Library
local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/Qanuir/orion-ui/refs/heads/main/source.lua"))()

local player = game.Players.LocalPlayer
local userInput = game:GetService("UserInputService")
local runService = game:GetService("RunService")
local lighting = game:GetService("Lighting")

-- Variables
local autoFarm = false
local flyConnection = nil
local flySpeed = 150
local selectedTornadoId = nil
local tornadoList = {}
local safeDistance = 80
local currentTargetPosition = nil
local currentTargetPart = nil
local orbitAngle = 0
local orbitRadius = 50
local orbitHeight = 30
local orbitSpeed = 0.005

-- Smoothing variables
local currentVelocity = Vector3.zero
local SMOOTH_FACTOR = 0.15

-- Cache
local lastTargetUpdate = 0
local lastMoveUpdate = 0

-- Original lighting
local originalBrightness = lighting.Brightness
local originalAmbient = lighting.Ambient
local originalOutdoorAmbient = lighting.OutdoorAmbient
local originalGlobalShadows = lighting.GlobalShadows

-- Find all tornadoes
local function findAllTornadoes()
    local tornadoes = {}
    local storms = workspace:FindFirstChild("storm_related")
    if not storms then return tornadoes end
    
    local stormsFolder = storms:FindFirstChild("storms")
    if not stormsFolder then return tornadoes end
    
    for _, storm in ipairs(stormsFolder:GetChildren()) do
        local rotation = storm:FindFirstChild("rotation")
        if rotation then
            for _, part in ipairs(rotation:GetDescendants()) do
                if part.Name == "tornado_scan" and part:IsA("BasePart") then
                    local windSpeed = part:GetAttribute("winds") or 0
                    table.insert(tornadoes, {
                        Id = tostring(storm),
                        Part = part,
                        Position = part.Position,
                        Name = storm.Name,
                        Winds = windSpeed,
                        Size = (part.Size.X + part.Size.Z) / 2
                    })
                    break
                end
            end
        end
    end
    
    -- Sort by wind speed
    table.sort(tornadoes, function(a, b) return a.Winds > b.Winds end)
    
    return tornadoes
end

-- Refresh tornado list
local function refreshTornadoList(dropdown)
    tornadoList = findAllTornadoes()
    local options = {"Nearest (Auto)"}
    
    for _, tornado in ipairs(tornadoList) do
        local windText = ""
        if tornado.Winds > 0 then
            local windIcon = tornado.Winds > 150 and "🔴" or (tornado.Winds > 100 and "🟡" or "🟢")
            windText = string.format(" [%s %.0f mph]", windIcon, tornado.Winds)
        end
        options[#options + 1] = tornado.Name .. windText
    end
    
    if #tornadoList == 0 then
        options[2] = "No tornadoes found"
    end
    
    dropdown:Refresh(options, true)
    
    if selectedTornadoId then
        for _, tornado in ipairs(tornadoList) do
            if tornado.Id == selectedTornadoId then
                local windText = ""
                if tornado.Winds > 0 then
                    local windIcon = tornado.Winds > 150 and "🔴" or (tornado.Winds > 100 and "🟡" or "🟢")
                    windText = string.format(" [%s %.0f mph]", windIcon, tornado.Winds)
                end
                dropdown:SetValue(tornado.Name .. windText)
                break
            end
        end
    end
end

-- Get selected tornado
local function getSelectedTornado()
    if not selectedTornadoId then return nil end
    for _, tornado in ipairs(tornadoList) do
        if tornado.Id == selectedTornadoId then
            return tornado
        end
    end
    return nil
end

-- Get nearest tornado
local function getNearestTornado()
    local nearest = nil
    local nearestDist = math.huge
    
    local char = player.Character
    if not char then return nil end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
    for _, tornado in ipairs(tornadoList) do
        local dist = (tornado.Position - hrp.Position).Magnitude
        if dist < nearestDist then
            nearestDist = dist
            nearest = tornado
        end
    end
    
    return nearest
end

-- Get orbit position around tornado
local function getOrbitPosition(tornadoPos, radius, height, angle)
    local x = tornadoPos.X + math.cos(angle) * radius
    local z = tornadoPos.Z + math.sin(angle) * radius
    local y = tornadoPos.Y + height
    return Vector3.new(x, y, z)
end

-- Update target position with ORBIT
local function updateTargetPosition()
    local now = tick()
    if now - lastTargetUpdate < 0.3 then
        return currentTargetPosition ~= nil
    end
    lastTargetUpdate = now
    
    local targetTornado = selectedTornadoId and getSelectedTornado() or getNearestTornado()
    
    if targetTornado and targetTornado.Part and targetTornado.Part.Parent then
        currentTargetPart = targetTornado.Part
        
        -- Update orbit angle
        orbitAngle = orbitAngle + orbitSpeed
        
        -- Calculate orbit position
        local orbitPos = getOrbitPosition(
            targetTornado.Part.Position,
            orbitRadius,
            orbitHeight,
            orbitAngle
        )
        
        currentTargetPosition = orbitPos
        return true
    end
    
    return false
end

-- Stop farm
local function stopAutoFarm()
    autoFarm = false
    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end
    
    local char = player.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            pcall(function() 
                hrp.Velocity = Vector3.zero
                currentVelocity = Vector3.zero
            end)
        end
    end
    
    print("[STOP] Auto farm stopped")
end

-- Start farm with smooth movement
local function startAutoFarm()
    tornadoList = findAllTornadoes()
    if not updateTargetPosition() then
        print("[ERROR] Tornado not found!")
        return false
    end
    
    local char = player.Character
    if not char then
        print("[ERROR] Character not found!")
        return false
    end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        print("[ERROR] HumanoidRootPart not found!")
        return false
    end
    
    autoFarm = true
    currentVelocity = Vector3.zero
    orbitAngle = 0
    print("[START] Auto farm activated - ORBIT MODE")
    print("[ORBIT] Radius: " .. orbitRadius .. "m | Height: " .. orbitHeight .. "m")
    
    lastTargetUpdate = 0
    
    flyConnection = runService.RenderStepped:Connect(function()
        if not autoFarm then return end
        
        updateTargetPosition()
        
        if not currentTargetPosition then return end
        
        local char = player.Character
        if not char then
            stopAutoFarm()
            return
        end
        
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then
            stopAutoFarm()
            return
        end
        
        local direction = (currentTargetPosition - hrp.Position)
        local distance = direction.Magnitude
        
        -- Smooth movement to orbit point
        if distance > 5 then
            local desiredVel = direction.Unit * flySpeed
            currentVelocity = currentVelocity:Lerp(desiredVel, SMOOTH_FACTOR)
            
            pcall(function()
                hrp.Velocity = currentVelocity
                
                -- Face movement direction
                if direction.Magnitude > 0.1 then
                    local targetCFrame = CFrame.new(hrp.Position, hrp.Position + direction.Unit)
                    hrp.CFrame = hrp.CFrame:Lerp(targetCFrame, 0.25)
                end
            end)
        else
            -- Smooth stop at orbit point
            currentVelocity = currentVelocity:Lerp(Vector3.zero, 0.2)
            
            pcall(function()
                hrp.Velocity = currentVelocity
                
                -- Face tornado center
                if currentTargetPart then
                    local lookDir = currentTargetPart.Position - hrp.Position
                    lookDir = Vector3.new(lookDir.X, 0, lookDir.Z)
                    if lookDir.Magnitude > 0.1 then
                        local targetCFrame = CFrame.new(hrp.Position, hrp.Position + lookDir.Unit)
                        hrp.CFrame = hrp.CFrame:Lerp(targetCFrame, 0.2)
                    end
                end
            end)
        end
    end)
    
    return true
end

-- Fullbright
local function setFullbright(enabled)
    if enabled then
        lighting.Brightness = 3
        lighting.Ambient = Color3.fromRGB(255, 255, 255)
        lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        lighting.GlobalShadows = false
    else
        lighting.Brightness = originalBrightness
        lighting.Ambient = originalAmbient
        lighting.OutdoorAmbient = originalOutdoorAmbient
        lighting.GlobalShadows = originalGlobalShadows
    end
end

-- Create GUI
local Window = OrionLib:MakeWindow({
    Name = "Tornado Farm",
    HidePremium = false,
    SaveConfig = true,
    ConfigFolder = "TornadoFarm",
    IntroEnabled = false
})

local MainTab = Window:MakeTab({ Name = "Main", Icon = "rbxassetid://4483345998" })

MainTab:AddParagraph("Status", "Ready")
local statusParagraph = MainTab:AddParagraph("Auto Farm", "OFF")
local distanceParagraph = MainTab:AddParagraph("Distance", "--m")
local orbitInfoParagraph = MainTab:AddParagraph("Orbit", "Radius: 50m | Height: 30m")

local tornadoDropdown = MainTab:AddDropdown({
    Name = "Select Tornado",
    Default = "Nearest (Auto)",
    Options = {"Nearest (Auto)"},
    Callback = function(v)
        if v == "Nearest (Auto)" then
            selectedTornadoId = nil
        else
            for _, tornado in ipairs(tornadoList) do
                local windText = ""
                if tornado.Winds > 0 then
                    local windIcon = tornado.Winds > 150 and "🔴" or (tornado.Winds > 100 and "🟡" or "🟢")
                    windText = string.format(" [%s %.0f mph]", windIcon, tornado.Winds)
                end
                if tornado.Name .. windText == v or tornado.Name == v then
                    selectedTornadoId = tornado.Id
                    break
                end
            end
        end
    end
})

MainTab:AddButton({
    Name = "Refresh List",
    Callback = function()
        refreshTornadoList(tornadoDropdown)
    end
})

local startStopButton = MainTab:AddButton({
    Name = "START (Z)",
    Callback = function()
        if autoFarm then
            stopAutoFarm()
            startStopButton:SetName("START (Z)")
            statusParagraph:SetText("Auto Farm: OFF")
        else
            if startAutoFarm() then
                startStopButton:SetName("STOP (Z)")
                statusParagraph:SetText("Auto Farm: ON")
            end
        end
    end
})

-- Settings Tab
local SettingsTab = Window:MakeTab({ Name = "Settings", Icon = "rbxassetid://4483345998" })

SettingsTab:AddSlider({
    Name = "Fly Speed", Min = 50, Max = 400, Default = 150,
    Increment = 10, ValueName = "Speed",
    Callback = function(v) flySpeed = v end
})

SettingsTab:AddSlider({
    Name = "Orbit Radius", Min = 30, Max = 120, Default = 50,
    Increment = 5, ValueName = "Meters",
    Color = Color3.fromRGB(100, 200, 255),
    Callback = function(v)
        orbitRadius = v
        orbitInfoParagraph:SetText(string.format("Orbit: Radius: %dm | Height: %dm", orbitRadius, orbitHeight))
    end
})

SettingsTab:AddSlider({
    Name = "Orbit Height", Min = 20, Max = 80, Default = 30,
    Increment = 5, ValueName = "Meters",
    Color = Color3.fromRGB(100, 200, 100),
    Callback = function(v)
        orbitHeight = v
        orbitInfoParagraph:SetText(string.format("Orbit: Radius: %dm | Height: %dm", orbitRadius, orbitHeight))
    end
})

SettingsTab:AddSlider({
    Name = "Orbit Speed", Min = 1, Max = 20, Default = 5,
    Increment = 1, ValueName = "Speed",
    Color = Color3.fromRGB(255, 200, 100),
    Callback = function(v)
        orbitSpeed = v / 1000
    end
})

SettingsTab:AddSlider({
    Name = "Smooth Factor", Min = 5, Max = 50, Default = 15,
    Increment = 5, ValueName = "%",
    Color = Color3.fromRGB(255, 150, 100),
    Callback = function(v)
        SMOOTH_FACTOR = v / 100
    end
})

SettingsTab:AddToggle({
    Name = "Fullbright", Default = false,
    Callback = function(v) setFullbright(v) end
})

SettingsTab:AddParagraph("Info", "Orbit mode: Circles around tornado")

-- Update display
task.spawn(function()
    while true do
        if autoFarm and currentTargetPosition then
            local char = player.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local dist = (currentTargetPosition - hrp.Position).Magnitude
                    distanceParagraph:SetText("Distance: " .. math.floor(dist) .. "m")
                end
            end
        end
        task.wait(2)
    end
end)

-- Refresh list periodically
task.spawn(function()
    while true do
        refreshTornadoList(tornadoDropdown)
        task.wait(15)
    end
end)

-- Z key
userInput.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.Z then
        if autoFarm then
            stopAutoFarm()
            startStopButton:SetName("START (Z)")
            statusParagraph:SetText("Auto Farm: OFF")
        else
            if startAutoFarm() then
                startStopButton:SetName("STOP (Z)")
                statusParagraph:SetText("Auto Farm: ON")
            end
        end
    end
end)

-- Initial refresh
task.wait(1)
refreshTornadoList(tornadoDropdown)

print("========================================")
print("TORNADO FARM - ORBIT MODE")
print("========================================")
print("✓ Circles around tornado")
print("✓ Adjustable orbit radius/height/speed")
print("✓ Smooth movement")
print("Press Z to start/stop")
print("========================================")

OrionLib:Init()
