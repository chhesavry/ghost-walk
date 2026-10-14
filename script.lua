-- Ghost Walk v10.1

local Players                = game:GetService("Players")
local RunService             = game:GetService("RunService")
local UserInputService       = game:GetService("UserInputService")
local Workspace              = game:GetService("Workspace")
local CoreGui                = game:GetService("CoreGui")
local TweenService           = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local VirtualUser            = game:GetService("VirtualUser")
local VirtualInputManager    = game:GetService("VirtualInputManager")
local Stats                  = game:GetService("Stats")
local Lighting               = game:GetService("Lighting")

local LocalPlayer     = Players.LocalPlayer
local DEFAULT_GRAVITY = 196.2
local SESSION_START   = tick()

-- Helpers
function createInstance(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    return inst
end

function addCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 10)
    c.Parent = parent
    return c
end

function addPadding(parent, t, r, b, l)
    local p = Instance.new("UIPadding")
    p.PaddingTop, p.PaddingRight = UDim.new(0, t or 0), UDim.new(0, r or 0)
    p.PaddingBottom, p.PaddingLeft = UDim.new(0, b or 0), UDim.new(0, l or 0)
    p.Parent = parent
    return p
end

function addVerticalList(parent, gap)
    local l = Instance.new("UIListLayout")
    l.FillDirection = Enum.FillDirection.Vertical
    l.Padding = UDim.new(0, gap or 8)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = parent
    return l
end

function addHorizontalList(parent, gap)
    local l = Instance.new("UIListLayout")
    l.FillDirection = Enum.FillDirection.Horizontal
    l.Padding = UDim.new(0, gap or 6)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = parent
    return l
end

-- Config
local Config = {
    Speed        = 100,
    DefaultSpeed = 16,
    BoostActive  = false,
    GhostActive  = false,
    InvisActive  = false,
    GodMode      = false,
    FlyActive    = false,
    FlyHeight    = 25,
    TravelMode   = "teleport",
    ReturnDelay  = 1.0,
    FpsBoost     = false,
    FreeCam      = false,
    FreeCamSpeed = 60,
    AutoPickup   = false,
    PickupRange  = 20,
    PickupDelay  = 0.25,
    PickupLimit  = 0,
    PickupCount  = 0,
    PickupWaitAfterLimit = 1.0,
    InstantPickup = false,
}

-- Theme
local Theme = {
    Background = Color3.fromRGB(14, 14, 18),
    Header     = Color3.fromRGB(18, 18, 24),
    Card       = Color3.fromRGB(24, 24, 32),
    CardHover  = Color3.fromRGB(32, 32, 42),
    Surface    = Color3.fromRGB(20, 20, 28),
    Border     = Color3.fromRGB(48, 48, 62),
    Accent     = Color3.fromRGB(120, 95, 255),
    Accent2    = Color3.fromRGB(90, 200, 255),
    Text       = Color3.fromRGB(245, 245, 252),
    TextDim    = Color3.fromRGB(155, 155, 175),
    TextMute   = Color3.fromRGB(95, 95, 115),
    Off        = Color3.fromRGB(42, 42, 54),
    On         = Color3.fromRGB(120, 95, 255),
    Input      = Color3.fromRGB(16, 16, 22),
    Danger     = Color3.fromRGB(255, 90, 105),
    Success    = Color3.fromRGB(70, 215, 140),
    Warning    = Color3.fromRGB(255, 185, 70),
    Font       = Enum.Font.Gotham,
    FontMedium = Enum.Font.GothamMedium,
    FontBold   = Enum.Font.GothamBold,
}

-- State
LiveFPS, LivePing = 0, 0
fpsFrames, fpsLast = 0, tick()
Character, Humanoid, Root = nil, nil, nil
NoclipConn, HeightConn, InvisConn, GodConn = nil, nil, nil, nil
SavedPoints = {}
Teleporting = false
WalkConn = nil
StealLoopActive = false
LockTarget, LockConn, LockMode, CurrentMode = nil, nil, "follow", "follow"
toastFn = nil

-- Character
function bindCharacter(char)
    Character = char
    Humanoid = char:WaitForChild("Humanoid")
    Root = char:WaitForChild("HumanoidRootPart")
    Config.DefaultSpeed = Humanoid.WalkSpeed
end

if LocalPlayer.Character then bindCharacter(LocalPlayer.Character) end

-- Movement
function enableGhostWalk()
    local lockedY = Root.Position.Y
    Workspace.Gravity = 0
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)

    NoclipConn = RunService.Stepped:Connect(function()
        for _, part in ipairs(Character:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end)

    HeightConn = RunService.Heartbeat:Connect(function()
        local v = Root.AssemblyLinearVelocity
        Root.CFrame = CFrame.new(Root.Position.X, lockedY, Root.Position.Z)
        Root.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z)
        Humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end)
end

function disableGhostWalk()
    Workspace.Gravity = DEFAULT_GRAVITY
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
    if NoclipConn then NoclipConn:Disconnect() end
    if HeightConn then HeightConn:Disconnect() end
    for _, part in ipairs(Character:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.CanCollide = true
        end
    end
end

function enableInvisibility()
    for _, part in ipairs(Character:GetDescendants()) do
        if part:IsA("BasePart") or part:IsA("Decal") then part.Transparency = 1 end
    end
    if InvisConn then InvisConn:Disconnect() end
    InvisConn = RunService.Stepped:Connect(function()
        if not Character then return end
        for _, part in ipairs(Character:GetDescendants()) do
            if (part:IsA("BasePart") or part:IsA("Decal")) and part.Transparency ~= 1 then
                part.Transparency = 1
            end
        end
    end)
end

function disableInvisibility()
    if InvisConn then InvisConn:Disconnect() InvisConn = nil end
    for _, part in ipairs(Character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Transparency = (part.Name == "HumanoidRootPart") and 1 or 0
        elseif part:IsA("Decal") then
            part.Transparency = 0
        end
    end
    for _, acc in ipairs(Character:GetChildren()) do
        if acc:IsA("Accessory") then
            local h = acc:FindFirstChild("Handle")
            if h then h.Transparency = 0 end
        end
    end
end

-- Stats
RunService.RenderStepped:Connect(function()
    fpsFrames = fpsFrames + 1
    local now = tick()
    if now - fpsLast >= 0.5 then
        LiveFPS = math.floor(fpsFrames / (now - fpsLast) + 0.5)
        fpsFrames = 0
        fpsLast = now
    end
end)

RunService.Heartbeat:Connect(function()
    local ok, ping = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    if ok and typeof(ping) == "number" then LivePing = math.floor(ping + 0.5) end
end)

function formatSession()
    local e = math.floor(tick() - SESSION_START)
    local h, m, s = math.floor(e / 3600), math.floor((e % 3600) / 60), e % 60
    if h > 0 then return string.format("%dh %02dm", h, m) end
    return string.format("%dm %02ds", m, s)
end

-- FPS Boost
FpsBoostSaved = nil

function enableFpsBoost()
    FpsBoostSaved = {
        quality = settings().Rendering.QualityLevel,
        mesh = settings().Rendering.MeshPartDetailLevel,
        globalShadows = Lighting.GlobalShadows,
        fogEnd = Lighting.FogEnd,
        brightness = Lighting.Brightness,
    }
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
    end)
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.Brightness = 1
    end)
    pcall(function()
        for _, e in ipairs(Lighting:GetChildren()) do
            if e:IsA("BlurEffect") or e:IsA("SunRaysEffect") or e:IsA("ColorCorrectionEffect")
            or e:IsA("BloomEffect") or e:IsA("DepthOfFieldEffect") then
                e.Enabled = false
            end
        end
    end)
    pcall(function() if setfpscap then setfpscap(999) end end)
    pcall(function() if typeof(setfps) == "function" then setfps(999) end end)
end

function disableFpsBoost()
    if not FpsBoostSaved then return end
    pcall(function()
        settings().Rendering.QualityLevel = FpsBoostSaved.quality
        settings().Rendering.MeshPartDetailLevel = FpsBoostSaved.mesh
    end)
    pcall(function()
        Lighting.GlobalShadows = FpsBoostSaved.globalShadows
        Lighting.FogEnd = FpsBoostSaved.fogEnd
        Lighting.Brightness = FpsBoostSaved.brightness
    end)
    pcall(function() if setfpscap then setfpscap(60) end end)
    FpsBoostSaved = nil
end

-- God Mode
GodLoopStarted = false
GodAntiTPConn = nil
GodLastCF = nil
GodLastSafeCF = nil
GodIgnoreTP = false
GodForceUntil = 0

function godMarkSafe()
    if Root and Root.Parent then
        GodLastSafeCF = Root.CFrame
        GodLastCF = Root.CFrame
    end
end

function enableGodMode()
    Config.GodMode = true
    if GodConn then GodConn:Disconnect() GodConn = nil end
    if GodAntiTPConn then GodAntiTPConn:Disconnect() GodAntiTPConn = nil end
    if not Humanoid then return end

    pcall(function()
        Humanoid.MaxHealth = math.max(Humanoid.MaxHealth, 100)
        Humanoid.Health = Humanoid.MaxHealth
    end)
    godMarkSafe()

    GodConn = Humanoid.HealthChanged:Connect(function()
        if Config.GodMode ~= true then return end
        if not Humanoid or not Humanoid.Parent then return end
        if Humanoid.Health < Humanoid.MaxHealth then Humanoid.Health = Humanoid.MaxHealth end
    end)

    GodAntiTPConn = RunService.Heartbeat:Connect(function()
        if not Config.GodMode or not Root or not Root.Parent then return end
        if GodIgnoreTP or Teleporting or StealLoopActive or WalkConn then
            godMarkSafe()
            return
        end

        local nowCF = Root.CFrame
        local now = tick()

        if now < GodForceUntil and GodLastSafeCF then
            Root.CFrame = GodLastSafeCF
            Root.AssemblyLinearVelocity = Vector3.zero
            return
        end

        if GodLastCF then
            local d = (nowCF.Position - GodLastCF.Position).Magnitude
            if d > 20 and GodLastSafeCF then
                GodForceUntil = now + 1.0
                Root.CFrame = GodLastSafeCF
                Root.AssemblyLinearVelocity = Vector3.zero
                if Humanoid then
                    pcall(function()
                        Humanoid.Health = Humanoid.MaxHealth
                        Humanoid:ChangeState(Enum.HumanoidStateType.Running)
                    end)
                end
                if toastFn then toastFn("Hazard blocked", Theme.Warning) end
                return
            end
        end

        GodLastCF = nowCF
        if not GodLastSafeCF or (nowCF.Position - GodLastSafeCF.Position).Magnitude < 25 then
            GodLastSafeCF = nowCF
        end
    end)

    if not GodLoopStarted then
        GodLoopStarted = true
        task.spawn(function()
            while true do
                if Config.GodMode and Humanoid and Humanoid.Parent then
                    pcall(function()
                        if Humanoid.Health < Humanoid.MaxHealth then Humanoid.Health = Humanoid.MaxHealth end
                        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
                        if Humanoid:GetState() == Enum.HumanoidStateType.Dead then
                            Humanoid:ChangeState(Enum.HumanoidStateType.Running)
                        end
                    end)
                end
                task.wait(0.1)
            end
        end)
    end
end

function disableGodMode()
    Config.GodMode = false
    if GodConn then GodConn:Disconnect() GodConn = nil end
    if GodAntiTPConn then GodAntiTPConn:Disconnect() GodAntiTPConn = nil end
    GodLastCF, GodLastSafeCF = nil, nil
    GodForceUntil = 0
    if Humanoid then
        pcall(function() Humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true) end)
    end
end

LocalPlayer.CharacterAdded:Connect(function(char)
    if WalkConn then WalkConn:Disconnect() WalkConn = nil end
    if GodConn then GodConn:Disconnect() GodConn = nil end
    if GodAntiTPConn then GodAntiTPConn:Disconnect() GodAntiTPConn = nil end
    GodLastCF, GodLastSafeCF = nil, nil
    Teleporting, StealLoopActive = false, false

    bindCharacter(char)
    task.wait(0.5)
    if Config.BoostActive and Humanoid then Humanoid.WalkSpeed = Config.Speed end
    if Config.InvisActive then task.wait(0.3) enableInvisibility() end
    if Config.FpsBoost then task.wait(0.2) enableFpsBoost() end
    if Config.GodMode then task.wait(0.25) enableGodMode() end
end)

-- Player Lock
function stopPlayerLock()
    if LockConn then LockConn:Disconnect() LockConn = nil end
    LockTarget = nil
    if Humanoid then
        pcall(function() Humanoid:ChangeState(Enum.HumanoidStateType.Running) end)
    end
end

function simulateClick()
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton1(Vector2.new(0, 0))
    end)
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
        task.wait(0.02)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
    end)
end

function startPlayerLock(targetPlayer, mode)
    stopPlayerLock()
    LockTarget = targetPlayer
    LockMode = mode or "follow"

    local attackTimer = 0
    LockConn = RunService.Heartbeat:Connect(function(dt)
        if not LockTarget or not Root or not Humanoid then return end
        local targetChar = LockTarget.Character
        if not targetChar then return end
        local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
        local targetHumanoid = targetChar:FindFirstChildOfClass("Humanoid")
        if not targetRoot then return end
        if targetHumanoid and targetHumanoid.Health <= 0 then return end

        local myPos = Root.Position
        local targetPos = targetRoot.Position
        local distance = (targetPos - myPos).Magnitude

        if distance > 3 then
            local dir = (targetPos - myPos).Unit
            local newPos = myPos + dir * math.min(distance - 3, 4)
            newPos = Vector3.new(newPos.X, targetPos.Y + 2, newPos.Z)
            Root.CFrame = CFrame.new(newPos, Vector3.new(targetPos.X, newPos.Y, targetPos.Z))
        else
            Root.CFrame = CFrame.new(Root.Position, Vector3.new(targetPos.X, Root.Position.Y, targetPos.Z))
        end

        if LockMode == "attack" and distance <= 15 then
            attackTimer = attackTimer + dt
            if attackTimer >= 0.1 then
                attackTimer = 0
                simulateClick()
            end
        end
    end)
end

-- Pickup helpers
function firePrompt(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then return false end
    local success = false
    pcall(function()
        if fireproximityprompt then
            fireproximityprompt(prompt)
            success = true
        end
    end)
    if not success then
        pcall(function()
            prompt.HoldDuration = 0
            prompt:InputHoldBegin()
            task.wait(0.05)
            prompt:InputHoldEnd()
            success = true
        end)
    end
    return success
end

function getItemPosition(object)
    if object:IsA("BasePart") then return object.Position end
    if object:IsA("Model") then
        local ok, p = pcall(function() return object:GetPivot().Position end)
        if ok then return p end
    end
    if object:IsA("ProximityPrompt") and object.Parent then return getItemPosition(object.Parent) end
    if object:IsA("Tool") then
        local h = object:FindFirstChild("Handle")
        if h then return h.Position end
    end
    return nil
end

-- Instant Pickup
InstantPickupConns = {}
InstantPickupPrevHolds = {}

function enableInstantPickup()
    for _, c in ipairs(InstantPickupConns) do pcall(function() c:Disconnect() end) end
    InstantPickupConns = {}
    InstantPickupPrevHolds = {}

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            InstantPickupPrevHolds[obj] = obj.HoldDuration
            pcall(function() obj.HoldDuration = 0 end)
        end
    end

    table.insert(InstantPickupConns, Workspace.DescendantAdded:Connect(function(obj)
        if not Config.InstantPickup then return end
        if obj:IsA("ProximityPrompt") then
            InstantPickupPrevHolds[obj] = obj.HoldDuration
            pcall(function() obj.HoldDuration = 0 end)
        end
    end))

    table.insert(InstantPickupConns, ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
        if not Config.InstantPickup then return end
        if not prompt or not prompt.Enabled then return end
        pcall(function()
            prompt.HoldDuration = 0
            fireproximityprompt(prompt)
        end)
    end))

    table.insert(InstantPickupConns, RunService.Heartbeat:Connect(function()
        if not Config.InstantPickup then return end
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") and obj.HoldDuration ~= 0 then
                if InstantPickupPrevHolds[obj] == nil then
                    InstantPickupPrevHolds[obj] = obj.HoldDuration
                end
                obj.HoldDuration = 0
            end
        end
    end))
end

function disableInstantPickup()
    for _, c in ipairs(InstantPickupConns) do pcall(function() c:Disconnect() end) end
    InstantPickupConns = {}
    for prompt, original in pairs(InstantPickupPrevHolds) do
        if prompt and prompt.Parent then
            pcall(function() prompt.HoldDuration = original end)
        end
    end
    InstantPickupPrevHolds = {}
end

-- Travel
function stopWalk()
    if WalkConn then
        WalkConn:Disconnect()
        WalkConn = nil
    end
end

function doTeleport(targetCF)
    if not Root then return false end
    GodIgnoreTP = true
    Root.CFrame = targetCF
    godMarkSafe()
    task.defer(function()
        task.wait(0.15)
        GodIgnoreTP = false
        godMarkSafe()
    end)
    return true
end

function doWalk(targetCF, label)
    if not Root or not Humanoid then return false end
    stopWalk()

    local useFly = Config.FlyActive == true
    local flyHeight = Config.FlyHeight or 25
    local targetPos = targetCF.Position
    local cruiseY = targetPos.Y + flyHeight
    local phase = useFly and "ascend" or "ground"
    local startTime = tick()

    pcall(function()
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
    end)

    if toastFn and label then
        toastFn(useFly and ("Flying → " .. label) or ("Walking → " .. label), Theme.Accent)
    end

    GodIgnoreTP = true
    local doneEvent = Instance.new("BindableEvent")

    WalkConn = RunService.Heartbeat:Connect(function(dt)
        if not Root or not Root.Parent or not Humanoid or Humanoid.Health <= 0 then
            stopWalk() GodIgnoreTP = false doneEvent:Fire(false) return
        end
        if tick() - startTime > 35 then
            stopWalk() GodIgnoreTP = false doneEvent:Fire(false) return
        end

        local myPos = Root.Position
        local speed = Config.BoostActive and Config.Speed or (Config.DefaultSpeed or 16)
        local currentVel = Root.AssemblyLinearVelocity

        if useFly then
            if phase == "ascend" then
                local needUp = cruiseY - myPos.Y
                if needUp <= 2 then
                    phase = "cruise"
                else
                    local step = math.min(speed * dt, needUp)
                    local newPos = Vector3.new(myPos.X, myPos.Y + step, myPos.Z)
                    Root.CFrame = CFrame.new(newPos, Vector3.new(targetPos.X, newPos.Y, targetPos.Z))
                    Root.AssemblyLinearVelocity = Vector3.new(0, speed, 0)
                    Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
                    return
                end
            end

            if phase == "cruise" then
                local flatTarget = Vector3.new(targetPos.X, cruiseY, targetPos.Z)
                local d = (flatTarget - Vector3.new(myPos.X, cruiseY, myPos.Z)).Magnitude
                if d <= 4 then
                    phase = "descend"
                else
                    local dir = (Vector3.new(targetPos.X, myPos.Y, targetPos.Z) - Vector3.new(myPos.X, myPos.Y, myPos.Z)).Unit
                    local step = math.min(speed * dt, d)
                    local newPos = Vector3.new(myPos.X + dir.X * step, cruiseY, myPos.Z + dir.Z * step)
                    Root.CFrame = CFrame.new(newPos, Vector3.new(targetPos.X, newPos.Y, targetPos.Z))
                    Root.AssemblyLinearVelocity = Vector3.new(dir.X * speed, 0, dir.Z * speed)
                    Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
                    return
                end
            end

            if phase == "descend" then
                local needDown = myPos.Y - targetPos.Y
                if needDown <= 2 then
                    Root.CFrame = targetCF
                    Root.AssemblyLinearVelocity = Vector3.zero
                    stopWalk() GodIgnoreTP = false godMarkSafe() doneEvent:Fire(true) return
                else
                    local step = math.min(speed * dt, needDown)
                    local newPos = Vector3.new(targetPos.X, myPos.Y - step, targetPos.Z)
                    Root.CFrame = CFrame.new(newPos, Vector3.new(targetPos.X, newPos.Y, targetPos.Z + 1))
                    Root.AssemblyLinearVelocity = Vector3.new(0, -speed, 0)
                    Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
                    return
                end
            end
        else
            local flat = Vector3.new(targetPos.X, myPos.Y, targetPos.Z)
            local d = (flat - myPos).Magnitude

            if d <= 3.5 then
                Root.CFrame = targetCF
                Root.AssemblyLinearVelocity = Vector3.zero
                stopWalk() GodIgnoreTP = false godMarkSafe() doneEvent:Fire(true) return
            end

            local dir = (flat - myPos).Unit
            local step = math.min(speed * dt, d)
            local newPos = myPos + dir * step

            local isAirborne = false
            pcall(function()
                local state = Humanoid:GetState()
                isAirborne = (state == Enum.HumanoidStateType.Freefall
                    or state == Enum.HumanoidStateType.Jumping)
            end)

            local finalY

            if Config.GhostActive then
                finalY = myPos.Y
            elseif isAirborne then
                finalY = myPos.Y
            else
                local yd = targetPos.Y - myPos.Y
                finalY = myPos.Y + math.clamp(yd, -speed * dt, speed * dt)
            end

            newPos = Vector3.new(newPos.X, finalY, newPos.Z)
            Root.CFrame = CFrame.new(newPos, Vector3.new(flat.X, newPos.Y, flat.Z))

            if isAirborne then
                Root.AssemblyLinearVelocity = Vector3.new(dir.X * speed, currentVel.Y, dir.Z * speed)
            else
                Root.AssemblyLinearVelocity = Vector3.new(dir.X * speed, 0, dir.Z * speed)
                pcall(function()
                    Humanoid:ChangeState(Enum.HumanoidStateType.Running)
                end)
            end
        end
    end)

    local success = doneEvent.Event:Wait()
    doneEvent:Destroy()
    GodIgnoreTP = false
    godMarkSafe()
    return success
end

function travelTo(targetCF, label)
    if not targetCF or not Root then return false end
    if Config.TravelMode == "walk" then return doWalk(targetCF, label) end
    return doTeleport(targetCF)
end

function runStealAction(name, data)
    if StealLoopActive or not Root then return end
    StealLoopActive = true
    stopWalk()

    local stealCF = Root.CFrame
    local success = travelTo(data.cframe, name)

    if success and toastFn then
        local action = Config.TravelMode == "walk" and "Walked" or "Teleported"
        toastFn(action .. " → " .. name, Theme.Success)
    end

    if data.returnAfter then
        task.wait(Config.ReturnDelay)
        if Root and Root.Parent and Humanoid and Humanoid.Health > 0 then
            if travelTo(stealCF, "steal spot") and toastFn then
                toastFn("→ Back to steal spot", Theme.Accent)
            end
        end
    end
    StealLoopActive = false
end

lastStealTime = 0
ProximityPromptService.PromptTriggered:Connect(function(_, player)
    if player ~= LocalPlayer then return end
    if tick() - lastStealTime < 0.6 then return end
    lastStealTime = tick()
    if toastFn then toastFn("Steal detected", Theme.Warning) end
    for name, data in pairs(SavedPoints) do
        if data.onSteal and Root and data.cframe then
            task.spawn(function() runStealAction(name, data) end)
            break
        end
    end
end)

-- Toast
toastFn = function(message, color)
    color = color or Theme.Accent
    local screen = CoreGui:FindFirstChild("GhostWalkUI")
    if not screen then return end

    local toast = createInstance("Frame", {
        Size = UDim2.new(0, 260, 0, 38),
        Position = UDim2.new(0.5, -130, 0, -48),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        ZIndex = 80,
        Parent = screen,
    })
    addCorner(toast, 10)

    local dot = createInstance("Frame", {
        Size = UDim2.new(0, 6, 0, 6),
        Position = UDim2.new(0, 12, 0.5, -3),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        ZIndex = 81,
        Parent = toast,
    })
    addCorner(dot, 3)

    createInstance("TextLabel", {
        Size = UDim2.new(1, -36, 1, 0),
        Position = UDim2.new(0, 26, 0, 0),
        BackgroundTransparency = 1,
        Text = message,
        TextColor3 = Theme.Text,
        Font = Theme.FontMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 81,
        Parent = toast,
    })

    TweenService:Create(toast, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -130, 0, 16),
    }):Play()

    task.delay(1.3, function()
        local fade = TweenService:Create(toast, TweenInfo.new(0.2), {
            Position = UDim2.new(0.5, -130, 0, -48),
        })
        fade:Play()
        fade.Completed:Wait()
        toast:Destroy()
    end)
end

-- Shared UI state
SharedUI = {
    Pages = {},
    ActiveTab = "main",
    minimized = false,
    savedRows = {},
    playerRows = {},
    PickupListRows = {},
    ScannedItems = {},
    SelectedItems = {},
    PickupModeAll = true,
    PickupCount = 0,
    PickupFilterText = "",
    PickupConn = nil,
    PickupTraveling = false,
}

-- UI
do
    local UI_WIDTH, UI_HEIGHT = 400, 520
    local UI_BORDER = 1

    if CoreGui:FindFirstChild("GhostWalkUI") then CoreGui.GhostWalkUI:Destroy() end

    local ScreenGui = createInstance("ScreenGui", {
        Name = "GhostWalkUI",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        Parent = CoreGui,
    })

    local function iconBar(parent, width, height, color)
        local f = createInstance("Frame", {
            Size = UDim2.new(0, width, 0, height),
            Position = UDim2.new(0.5, -width / 2, 0.5, -height / 2),
            BackgroundColor3 = color or Theme.TextDim,
            BorderSizePixel = 0,
            Parent = parent,
        })
        addCorner(f, 1)
        return f
    end

    local function iconX(parent, size, color)
        color = color or Theme.TextDim
        size = size or 10
        local holder = createInstance("Frame", {
            Size = UDim2.new(0, size, 0, size),
            Position = UDim2.new(0.5, -size / 2, 0.5, -size / 2),
            BackgroundTransparency = 1,
            Parent = parent,
        })
        for _, rot in ipairs({45, -45}) do
            local bar = createInstance("Frame", {
                Size = UDim2.new(1, 0, 0, 2),
                Position = UDim2.new(0, 0, 0.5, -1),
                BackgroundColor3 = color,
                BorderSizePixel = 0,
                Rotation = rot,
                Parent = holder,
            })
            addCorner(bar, 1)
        end
        return holder
    end

    local function iconPlus(parent, size, color)
        color = color or Theme.Accent
        size = size or 12
        local holder = createInstance("Frame", {
            Size = UDim2.new(0, size, 0, size),
            Position = UDim2.new(0.5, -size / 2, 0.5, -size / 2),
            BackgroundTransparency = 1,
            Parent = parent,
        })
        local h = createInstance("Frame", {
            Size = UDim2.new(1, 0, 0, 2),
            Position = UDim2.new(0, 0, 0.5, -1),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Parent = holder,
        })
        addCorner(h, 1)
        local v = createInstance("Frame", {
            Size = UDim2.new(0, 2, 1, 0),
            Position = UDim2.new(0.5, -1, 0, 0),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Parent = holder,
        })
        addCorner(v, 1)
        return holder
    end

    local function setIconColor(holder, color)
        for _, c in ipairs(holder:GetDescendants()) do
            if c:IsA("Frame") then c.BackgroundColor3 = color end
        end
    end

    local FloatBtn = createInstance("TextButton", {
        Name = "Float",
        Size = UDim2.new(0, 46, 0, 46),
        Position = UDim2.new(0, 20, 0.5, -23),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Text = "G",
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamBlack,
        TextSize = 18,
        AutoButtonColor = false,
        Visible = false,
        Parent = ScreenGui,
    })
    addCorner(FloatBtn, 23)

    local Shell = createInstance("Frame", {
        Name = "Shell",
        Size = UDim2.new(0, UI_WIDTH, 0, UI_HEIGHT),
        Position = UDim2.new(0, 20, 0.5, -UI_HEIGHT / 2),
        BackgroundColor3 = Theme.Border,
        BorderSizePixel = 0,
        Active = true,
        Parent = ScreenGui,
    })
    addCorner(Shell, 14)

    local Window = createInstance("Frame", {
        Name = "Window",
        Size = UDim2.new(1, -UI_BORDER * 2, 1, -UI_BORDER * 2),
        Position = UDim2.new(0, UI_BORDER, 0, UI_BORDER),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Active = true,
        Parent = Shell,
    })
    addCorner(Window, 13)

    local Header = createInstance("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 52),
        BackgroundColor3 = Theme.Header,
        BorderSizePixel = 0,
        Active = true,
        Parent = Window,
    })
    addCorner(Header, 13)

    local logo = createInstance("Frame", {
        Size = UDim2.new(0, 32, 0, 32),
        Position = UDim2.new(0, 14, 0.5, -16),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = Header,
    })
    addCorner(logo, 9)

    createInstance("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "G",
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamBlack,
        TextSize = 16,
        Parent = logo,
    })

    createInstance("TextLabel", {
        Size = UDim2.new(1, -120, 0, 18),
        Position = UDim2.new(0, 54, 0, 10),
        BackgroundTransparency = 1,
        Text = "Ghost Walk",
        TextColor3 = Theme.Text,
        Font = Theme.FontBold,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Header,
    })

    createInstance("TextLabel", {
        Size = UDim2.new(1, -120, 0, 14),
        Position = UDim2.new(0, 54, 0, 28),
        BackgroundTransparency = 1,
        Text = "v10.1 · walk-jump",
        TextColor3 = Theme.TextMute,
        Font = Theme.Font,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Header,
    })

    local buttonBox = createInstance("Frame", {
        Size = UDim2.new(0, 68, 0, 28),
        Position = UDim2.new(1, -80, 0.5, -14),
        BackgroundTransparency = 1,
        Parent = Header,
    })
    addHorizontalList(buttonBox, 6)

    local MinimizeBtn = createInstance("TextButton", {
        Size = UDim2.new(0, 28, 0, 28),
        BackgroundColor3 = Theme.Off,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = 1,
        Parent = buttonBox,
    })
    addCorner(MinimizeBtn, 8)
    local minimizeBar = iconBar(MinimizeBtn, 12, 2, Theme.TextDim)

    local CloseBtn = createInstance("TextButton", {
        Size = UDim2.new(0, 28, 0, 28),
        BackgroundColor3 = Theme.Off,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = 2,
        Parent = buttonBox,
    })
    addCorner(CloseBtn, 8)
    local closeIcon = iconX(CloseBtn, 10, Theme.TextDim)

    MinimizeBtn.MouseEnter:Connect(function()
        TweenService:Create(MinimizeBtn, TweenInfo.new(0.12), { BackgroundColor3 = Theme.Accent }):Play()
        setIconColor(minimizeBar, Theme.Text)
    end)
    MinimizeBtn.MouseLeave:Connect(function()
        TweenService:Create(MinimizeBtn, TweenInfo.new(0.12), { BackgroundColor3 = Theme.Off }):Play()
        setIconColor(minimizeBar, Theme.TextDim)
    end)
    CloseBtn.MouseEnter:Connect(function()
        TweenService:Create(CloseBtn, TweenInfo.new(0.12), { BackgroundColor3 = Theme.Danger }):Play()
        setIconColor(closeIcon, Theme.Text)
    end)
    CloseBtn.MouseLeave:Connect(function()
        TweenService:Create(CloseBtn, TweenInfo.new(0.12), { BackgroundColor3 = Theme.Off }):Play()
        setIconColor(closeIcon, Theme.TextDim)
    end)

    local TabBar = createInstance("Frame", {
        Size = UDim2.new(1, -24, 0, 34),
        Position = UDim2.new(0, 12, 0, 58),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Parent = Window,
    })
    addCorner(TabBar, 10)
    addPadding(TabBar, 3, 3, 3, 3)
    addHorizontalList(TabBar, 4)

    local function makeTab(label, order)
        local b = createInstance("TextButton", {
            Size = UDim2.new(0.25, -3, 1, 0),
            BackgroundColor3 = Theme.Surface,
            BorderSizePixel = 0,
            Text = label,
            TextColor3 = Theme.TextMute,
            Font = Theme.FontMedium,
            TextSize = 11,
            AutoButtonColor = false,
            LayoutOrder = order,
            Parent = TabBar,
        })
        addCorner(b, 8)
        return b
    end

    local TabMain = makeTab("Main", 1)
    local TabTravel = makeTab("Travel", 2)
    local TabPickup = makeTab("Pickup", 3)
    local TabPlayers = makeTab("Players", 4)

    local function makePage()
        local page = createInstance("ScrollingFrame", {
            Size = UDim2.new(1, -8, 1, -104),
            Position = UDim2.new(0, 4, 0, 98),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.Accent,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false,
            Parent = Window,
        })
        addVerticalList(page, 8)
        addPadding(page, 4, 10, 14, 10)
        return page
    end

    local PageMain = makePage()
    local PageTravel = makePage()
    local PagePickup = makePage()
    local PagePlayers = makePage()

    SharedUI.Pages.main = { button = TabMain, page = PageMain }
    SharedUI.Pages.travel = { button = TabTravel, page = PageTravel }
    SharedUI.Pages.pickup = { button = TabPickup, page = PagePickup }
    SharedUI.Pages.players = { button = TabPlayers, page = PagePlayers }

    local function switchTab(id)
        SharedUI.ActiveTab = id
        for key, data in pairs(SharedUI.Pages) do
            local active = (key == id)
            data.page.Visible = active
            TweenService:Create(data.button, TweenInfo.new(0.15), {
                BackgroundColor3 = active and Theme.Accent or Theme.Surface,
                TextColor3 = active and Theme.Text or Theme.TextMute,
            }):Play()
        end
    end

    TabMain.MouseButton1Click:Connect(function() switchTab("main") end)
    TabTravel.MouseButton1Click:Connect(function() switchTab("travel") end)
    TabPickup.MouseButton1Click:Connect(function() switchTab("pickup") end)
    TabPlayers.MouseButton1Click:Connect(function() switchTab("players") end)
    switchTab("main")

    local function createSection(parent, text, order)
        local f = createInstance("Frame", {
            Size = UDim2.new(1, 0, 0, 18),
            BackgroundTransparency = 1,
            LayoutOrder = order,
            Parent = parent,
        })
        createInstance("TextLabel", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = string.upper(text),
            TextColor3 = Theme.TextMute,
            Font = Theme.FontBold,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = f,
        })
    end

    local function createToggleRow(parent, options)
        local row = createInstance("Frame", {
            Size = UDim2.new(1, 0, 0, 58),
            BackgroundColor3 = Theme.Card,
            BorderSizePixel = 0,
            LayoutOrder = options.order,
            Parent = parent,
        })
        addCorner(row, 12)

        createInstance("TextLabel", {
            Size = UDim2.new(1, -110, 0, 18),
            Position = UDim2.new(0, 14, 0, 12),
            BackgroundTransparency = 1,
            Text = options.name,
            TextColor3 = Theme.Text,
            Font = Theme.FontMedium,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row,
        })
        createInstance("TextLabel", {
            Size = UDim2.new(1, -110, 0, 14),
            Position = UDim2.new(0, 14, 0, 32),
            BackgroundTransparency = 1,
            Text = options.desc or "",
            TextColor3 = Theme.TextMute,
            Font = Theme.Font,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row,
        })

        if options.input then
            local inputBox = createInstance("Frame", {
                Size = UDim2.new(0, 48, 0, 26),
                Position = UDim2.new(1, -112, 0.5, -13),
                BackgroundColor3 = Theme.Input,
                BorderSizePixel = 0,
                Parent = row,
            })
            addCorner(inputBox, 7)
            local tb = createInstance("TextBox", {
                Size = UDim2.new(1, -8, 1, 0),
                Position = UDim2.new(0, 4, 0, 0),
                BackgroundTransparency = 1,
                Text = options.input.value,
                TextColor3 = Theme.Text,
                Font = Theme.FontMedium,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Center,
                ClearTextOnFocus = false,
                Parent = inputBox,
            })
            tb.FocusLost:Connect(function()
                local num = tonumber(tb.Text)
                if num and num > 0 then options.input.callback(num)
                else tb.Text = tostring(options.input.value) end
            end)
        end

        local toggle = createInstance("TextButton", {
            Size = UDim2.new(0, 44, 0, 24),
            Position = UDim2.new(1, -56, 0.5, -12),
            BackgroundColor3 = Theme.Off,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            Parent = row,
        })
        addCorner(toggle, 12)

        local knob = createInstance("Frame", {
            Size = UDim2.new(0, 18, 0, 18),
            Position = UDim2.new(0, 3, 0.5, -9),
            BackgroundColor3 = Theme.Text,
            BorderSizePixel = 0,
            Parent = toggle,
        })
        addCorner(knob, 9)

        local isOn = false
        local function setState(value, fire)
            isOn = value
            TweenService:Create(toggle, TweenInfo.new(0.18), {
                BackgroundColor3 = isOn and Theme.On or Theme.Off,
            }):Play()
            TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Position = isOn and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9),
            }):Play()
            if fire and options.callback then options.callback(isOn) end
        end

        toggle.MouseButton1Click:Connect(function() setState(not isOn, true) end)

        row.MouseEnter:Connect(function()
            TweenService:Create(row, TweenInfo.new(0.12), { BackgroundColor3 = Theme.CardHover }):Play()
        end)
        row.MouseLeave:Connect(function()
            TweenService:Create(row, TweenInfo.new(0.12), { BackgroundColor3 = Theme.Card }):Play()
        end)
    end

    local function createNumberRow(parent, options)
        local row = createInstance("Frame", {
            Size = UDim2.new(1, 0, 0, 52),
            BackgroundColor3 = Theme.Card,
            BorderSizePixel = 0,
            LayoutOrder = options.order,
            Parent = parent,
        })
        addCorner(row, 12)

        createInstance("TextLabel", {
            Size = UDim2.new(1, -70, 0, 16),
            Position = UDim2.new(0, 14, 0, 10),
            BackgroundTransparency = 1,
            Text = options.name,
            TextColor3 = Theme.Text,
            Font = Theme.FontMedium,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row,
        })
        createInstance("TextLabel", {
            Size = UDim2.new(1, -70, 0, 14),
            Position = UDim2.new(0, 14, 0, 28),
            BackgroundTransparency = 1,
            Text = options.desc or "",
            TextColor3 = Theme.TextMute,
            Font = Theme.Font,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row,
        })

        local inputBox = createInstance("Frame", {
            Size = UDim2.new(0, 50, 0, 26),
            Position = UDim2.new(1, -62, 0.5, -13),
            BackgroundColor3 = Theme.Input,
            BorderSizePixel = 0,
            Parent = row,
        })
        addCorner(inputBox, 7)
        local tb = createInstance("TextBox", {
            Size = UDim2.new(1, -8, 1, 0),
            Position = UDim2.new(0, 4, 0, 0),
            BackgroundTransparency = 1,
            Text = options.value,
            TextColor3 = Theme.Text,
            Font = Theme.FontMedium,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Center,
            ClearTextOnFocus = false,
            Parent = inputBox,
        })
        tb.FocusLost:Connect(function()
            local num = tonumber(tb.Text)
            if num and num >= 0 then
                options.callback(num)
                tb.Text = tostring(num)
            else
                tb.Text = options.value
            end
        end)
    end

    -- Main
    createSection(PageMain, "Account", 1)

    local userCard = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 118),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        LayoutOrder = 2,
        Parent = PageMain,
    })
    addCorner(userCard, 12)

    local avatarImg = createInstance("ImageLabel", {
        Size = UDim2.new(0, 48, 0, 48),
        Position = UDim2.new(0, 12, 0, 12),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(LocalPlayer.UserId) .. "&w=150&h=150",
        Parent = userCard,
    })
    addCorner(avatarImg, 10)

    createInstance("TextLabel", {
        Size = UDim2.new(1, -72, 0, 18),
        Position = UDim2.new(0, 70, 0, 14),
        BackgroundTransparency = 1,
        Text = LocalPlayer.DisplayName,
        TextColor3 = Theme.Text,
        Font = Theme.FontBold,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = userCard,
    })
    createInstance("TextLabel", {
        Size = UDim2.new(1, -72, 0, 14),
        Position = UDim2.new(0, 70, 0, 34),
        BackgroundTransparency = 1,
        Text = "@" .. LocalPlayer.Name,
        TextColor3 = Theme.TextMute,
        Font = Theme.Font,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = userCard,
    })

    local function createStatChip(parent, label, xScale, widthScale)
        local chip = createInstance("Frame", {
            Size = UDim2.new(widthScale, -6, 0, 40),
            Position = UDim2.new(xScale, 6, 0, 70),
            BackgroundColor3 = Theme.Surface,
            BorderSizePixel = 0,
            Parent = parent,
        })
        addCorner(chip, 8)
        createInstance("TextLabel", {
            Size = UDim2.new(1, 0, 0, 12),
            Position = UDim2.new(0, 0, 0, 5),
            BackgroundTransparency = 1,
            Text = label,
            TextColor3 = Theme.TextMute,
            Font = Theme.Font,
            TextSize = 9,
            Parent = chip,
        })
        local value = createInstance("TextLabel", {
            Size = UDim2.new(1, 0, 0, 16),
            Position = UDim2.new(0, 0, 0, 18),
            BackgroundTransparency = 1,
            Text = "--",
            TextColor3 = Theme.Text,
            Font = Theme.FontBold,
            TextSize = 12,
            Parent = chip,
        })
        return value
    end

    local fpsValue = createStatChip(userCard, "FPS", 0, 0.25)
    local pingValue = createStatChip(userCard, "PING", 0.25, 0.25)
    local sessionValue = createStatChip(userCard, "SESSION", 0.5, 0.25)
    local uidValue = createStatChip(userCard, "USER ID", 0.75, 0.25)
    uidValue.Text = tostring(LocalPlayer.UserId)
    uidValue.TextSize = 10

    task.spawn(function()
        while userCard and userCard.Parent do
            fpsValue.Text = tostring(LiveFPS)
            if LiveFPS >= 55 then fpsValue.TextColor3 = Theme.Success
            elseif LiveFPS >= 30 then fpsValue.TextColor3 = Theme.Warning
            else fpsValue.TextColor3 = Theme.Danger end

            pingValue.Text = LivePing > 0 and (LivePing .. " ms") or "--"
            if LivePing > 0 and LivePing < 80 then pingValue.TextColor3 = Theme.Success
            elseif LivePing < 150 then pingValue.TextColor3 = Theme.Warning
            else pingValue.TextColor3 = Theme.Danger end

            sessionValue.Text = formatSession()
            sessionValue.TextColor3 = Theme.Accent2
            task.wait(0.5)
        end
    end)

    createSection(PageMain, "Performance", 3)
    createToggleRow(PageMain, {
        name = "FPS Boost",
        desc = "Lower quality · disable effects · uncap FPS",
        order = 4,
        callback = function(state)
            Config.FpsBoost = state
            if state then enableFpsBoost() else disableFpsBoost() end
        end,
    })

    createSection(PageMain, "Movement", 5)

    createToggleRow(PageMain, {
        name = "Instant Pickup",
        desc = "Toggle ON → click any item in-game to pick up instantly",
        order = 6,
        callback = function(state)
            Config.InstantPickup = state
            if state then
                enableInstantPickup()
                if toastFn then toastFn("Instant Pickup ON · click items to grab", Theme.Success) end
            else
                disableInstantPickup()
                if toastFn then toastFn("Instant Pickup OFF", Theme.TextDim) end
            end
        end,
    })

    createToggleRow(PageMain, {
        name = "Ghost Walk",
        desc = "Noclip · no fall · height lock",
        order = 7,
        callback = function(state)
            Config.GhostActive = state
            if state then enableGhostWalk() else disableGhostWalk() end
        end,
    })

    createToggleRow(PageMain, {
        name = "Speed Boost",
        desc = "Override walk speed",
        order = 8,
        callback = function(state)
            Config.BoostActive = state
            if Humanoid then
                Humanoid.WalkSpeed = state and Config.Speed or Config.DefaultSpeed
            end
        end,
        input = {
            value = tostring(Config.Speed),
            callback = function(value)
                Config.Speed = value
                if Config.BoostActive and Humanoid then Humanoid.WalkSpeed = value end
            end,
        },
    })

    createToggleRow(PageMain, {
        name = "Invisibility",
        desc = "Hide character completely",
        order = 9,
        callback = function(state)
            Config.InvisActive = state
            if state then enableInvisibility() else disableInvisibility() end
        end,
    })

    createToggleRow(PageMain, {
        name = "God Mode",
        desc = "Infinite HP · block hazard teleport",
        order = 10,
        callback = function(state)
            Config.GodMode = state
            if state then enableGodMode() else disableGodMode() end
        end,
    })

    createToggleRow(PageMain, {
        name = "Fly",
        desc = "Walk-travel: rise by height (m), fly, then land",
        order = 11,
        callback = function(state)
            Config.FlyActive = state
            if toastFn then
                toastFn(state and ("Fly ON · height " .. tostring(Config.FlyHeight) .. "m") or "Fly OFF",
                    state and Theme.Success or Theme.TextDim)
            end
        end,
        input = {
            value = tostring(Config.FlyHeight or 25),
            callback = function(value)
                Config.FlyHeight = value
                if Config.FlyActive and toastFn then
                    toastFn("Fly height: " .. tostring(value) .. "m", Theme.Accent)
                end
            end,
        },
    })

    -- Free Cam
    do
        local FreeCamConn = nil
        local FreeCamInputConns = {}
        local FreeCamSaved = nil
        local FreeCamGui = nil
        local FreeCamTouch = {
            moveDir = Vector3.zero, upHeld = false, downHeld = false,
            lookTouchId = nil, lookLastPos = nil, joyTouchId = nil, joyOrigin = nil,
        }

        local function destroyFreeCamGui()
            if FreeCamGui then FreeCamGui:Destroy() FreeCamGui = nil end
        end

        local function stopFreeCam()
            if FreeCamConn then FreeCamConn:Disconnect() FreeCamConn = nil end
            for _, c in ipairs(FreeCamInputConns) do pcall(function() c:Disconnect() end) end
            FreeCamInputConns = {}
            destroyFreeCamGui()
            Config.FreeCam = false

            FreeCamTouch.moveDir = Vector3.zero
            FreeCamTouch.upHeld = false
            FreeCamTouch.downHeld = false
            FreeCamTouch.lookTouchId = nil
            FreeCamTouch.lookLastPos = nil
            FreeCamTouch.joyTouchId = nil
            FreeCamTouch.joyOrigin = nil

            local cam = Workspace.CurrentCamera
            if cam and FreeCamSaved then
                pcall(function()
                    cam.CameraType = FreeCamSaved.type or Enum.CameraType.Custom
                    if FreeCamSaved.subject then cam.CameraSubject = FreeCamSaved.subject
                    elseif Humanoid then cam.CameraSubject = Humanoid end
                end)
            end
            FreeCamSaved = nil

            if Character then
                for _, part in ipairs(Character:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        pcall(function() part.CanCollide = true end)
                    end
                end
            end
        end

        local function buildFreeCamGui()
            destroyFreeCamGui()
            FreeCamGui = createInstance("ScreenGui", {
                Name = "GhostFreeCamPad",
                ResetOnSpawn = false,
                ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
                IgnoreGuiInset = true,
                DisplayOrder = 50,
                Parent = CoreGui,
            })

            local exitBtn = createInstance("TextButton", {
                Size = UDim2.new(0, 120, 0, 36),
                Position = UDim2.new(0.5, -60, 0, 20),
                BackgroundColor3 = Theme.Danger,
                BorderSizePixel = 0,
                Text = "Exit Free Cam",
                TextColor3 = Theme.Text,
                Font = Theme.FontBold,
                TextSize = 13,
                AutoButtonColor = false,
                Parent = FreeCamGui,
            })
            addCorner(exitBtn, 10)

            exitBtn.MouseButton1Click:Connect(function()
                stopFreeCam()
                if toastFn then toastFn("Free Cam OFF", Theme.TextDim) end
            end)

            local joyBase = createInstance("Frame", {
                Size = UDim2.new(0, 130, 0, 130),
                Position = UDim2.new(0, 24, 1, -170),
                BackgroundColor3 = Color3.fromRGB(30, 30, 40),
                BackgroundTransparency = 0.35,
                BorderSizePixel = 0,
                Parent = FreeCamGui,
            })
            addCorner(joyBase, 65)

            local joyKnob = createInstance("Frame", {
                Size = UDim2.new(0, 52, 0, 52),
                Position = UDim2.new(0.5, -26, 0.5, -26),
                BackgroundColor3 = Theme.Accent,
                BackgroundTransparency = 0.15,
                BorderSizePixel = 0,
                Parent = joyBase,
            })
            addCorner(joyKnob, 26)

            local btnCol = createInstance("Frame", {
                Size = UDim2.new(0, 64, 0, 140),
                Position = UDim2.new(1, -88, 1, -180),
                BackgroundTransparency = 1,
                Parent = FreeCamGui,
            })

            local upBtn = createInstance("TextButton", {
                Size = UDim2.new(1, 0, 0, 64),
                BackgroundColor3 = Color3.fromRGB(30, 30, 40),
                BackgroundTransparency = 0.25,
                BorderSizePixel = 0,
                Text = "▲ UP",
                TextColor3 = Theme.Text,
                Font = Theme.FontBold,
                TextSize = 14,
                AutoButtonColor = false,
                Parent = btnCol,
            })
            addCorner(upBtn, 14)

            local downBtn = createInstance("TextButton", {
                Size = UDim2.new(1, 0, 0, 64),
                Position = UDim2.new(0, 0, 0, 76),
                BackgroundColor3 = Color3.fromRGB(30, 30, 40),
                BackgroundTransparency = 0.25,
                BorderSizePixel = 0,
                Text = "▼ DN",
                TextColor3 = Theme.Text,
                Font = Theme.FontBold,
                TextSize = 14,
                AutoButtonColor = false,
                Parent = btnCol,
            })
            addCorner(downBtn, 14)

            local function bindHold(button, flag)
                button.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Touch
                    or input.UserInputType == Enum.UserInputType.MouseButton1 then
                        FreeCamTouch[flag] = true
                        button.BackgroundColor3 = Theme.Accent
                    end
                end)
                button.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Touch
                    or input.UserInputType == Enum.UserInputType.MouseButton1 then
                        FreeCamTouch[flag] = false
                        button.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
                    end
                end)
            end

            bindHold(upBtn, "upHeld")
            bindHold(downBtn, "downHeld")

            local joyRadius = 50

            joyBase.InputBegan:Connect(function(input)
                if FreeCamTouch.joyTouchId then return end
                if input.UserInputType == Enum.UserInputType.Touch
                or input.UserInputType == Enum.UserInputType.MouseButton1 then
                    FreeCamTouch.joyTouchId = input
                    local ap = joyBase.AbsolutePosition
                    local as = joyBase.AbsoluteSize
                    FreeCamTouch.joyOrigin = Vector2.new(ap.X + as.X / 2, ap.Y + as.Y / 2)
                    local pos = Vector2.new(input.Position.X, input.Position.Y)
                    local delta = pos - FreeCamTouch.joyOrigin
                    if delta.Magnitude > joyRadius then delta = delta.Unit * joyRadius end
                    joyKnob.Position = UDim2.new(0.5, delta.X - 26, 0.5, delta.Y - 26)
                    FreeCamTouch.moveDir = Vector3.new(delta.X / joyRadius, 0, delta.Y / joyRadius)
                end
            end)

            table.insert(FreeCamInputConns, UserInputService.InputChanged:Connect(function(input)
                if not Config.FreeCam then return end
                if FreeCamTouch.joyTouchId and input == FreeCamTouch.joyTouchId and FreeCamTouch.joyOrigin then
                    local pos = Vector2.new(input.Position.X, input.Position.Y)
                    local delta = pos - FreeCamTouch.joyOrigin
                    if delta.Magnitude > joyRadius then delta = delta.Unit * joyRadius end
                    joyKnob.Position = UDim2.new(0.5, delta.X - 26, 0.5, delta.Y - 26)
                    FreeCamTouch.moveDir = Vector3.new(delta.X / joyRadius, 0, delta.Y / joyRadius)
                end
                if FreeCamTouch.lookTouchId and input == FreeCamTouch.lookTouchId and FreeCamTouch.lookLastPos then
                    local pos = Vector2.new(input.Position.X, input.Position.Y)
                    local delta = pos - FreeCamTouch.lookLastPos
                    FreeCamTouch.lookLastPos = pos
                    FreeCamTouch._lookDelta = (FreeCamTouch._lookDelta or Vector2.zero) + delta
                end
            end))

            table.insert(FreeCamInputConns, UserInputService.InputEnded:Connect(function(input)
                if FreeCamTouch.joyTouchId and input == FreeCamTouch.joyTouchId then
                    FreeCamTouch.joyTouchId = nil
                    FreeCamTouch.joyOrigin = nil
                    FreeCamTouch.moveDir = Vector3.zero
                    joyKnob.Position = UDim2.new(0.5, -26, 0.5, -26)
                end
                if FreeCamTouch.lookTouchId and input == FreeCamTouch.lookTouchId then
                    FreeCamTouch.lookTouchId = nil
                    FreeCamTouch.lookLastPos = nil
                end
            end))

            table.insert(FreeCamInputConns, UserInputService.InputBegan:Connect(function(input)
                if not Config.FreeCam then return end
                if input.UserInputType ~= Enum.UserInputType.Touch
                and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                local x, y = input.Position.X, input.Position.Y
                local vp = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600)
                if (x < 180 and y > vp.Y - 200) or (x > vp.X - 100 and y > vp.Y - 200)
                or (y < 70 and math.abs(x - vp.X / 2) < 80) then return end
                if FreeCamTouch.lookTouchId then return end
                FreeCamTouch.lookTouchId = input
                FreeCamTouch.lookLastPos = Vector2.new(x, y)
                FreeCamTouch._lookDelta = Vector2.zero
            end))
        end

        local function startFreeCam()
            stopFreeCam()
            local cam = Workspace.CurrentCamera
            if not cam then return end

            FreeCamSaved = { type = cam.CameraType, subject = cam.CameraSubject, cframe = cam.CFrame }
            cam.CameraType = Enum.CameraType.Scriptable

            local startCF = cam.CFrame
            if Root then
                startCF = CFrame.new(Root.Position + Vector3.new(0, 5, 0)) * (cam.CFrame - cam.CFrame.Position)
            end
            cam.CFrame = startCF

            if Character then
                for _, part in ipairs(Character:GetDescendants()) do
                    if part:IsA("BasePart") then pcall(function() part.CanCollide = false end) end
                end
            end

            Config.FreeCam = true
            FreeCamTouch.moveDir = Vector3.zero
            FreeCamTouch.upHeld = false
            FreeCamTouch.downHeld = false
            FreeCamTouch._lookDelta = Vector2.zero

            local lv = startCF.LookVector
            local lookAngles = Vector2.new(math.atan2(-lv.X, -lv.Z), math.asin(math.clamp(lv.Y, -1, 1)))
            local frozenPos = Root and Root.Position or startCF.Position

            buildFreeCamGui()

            FreeCamConn = RunService.RenderStepped:Connect(function(dt)
                if not Config.FreeCam then return end
                local c = Workspace.CurrentCamera
                if not c then return end

                if Root and Root.Parent then
                    Root.CFrame = CFrame.new(frozenPos)
                    Root.AssemblyLinearVelocity = Vector3.zero
                end

                local speed = Config.FreeCamSpeed or 60
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
                or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then speed = speed * 2.5 end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
                or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then speed = speed * 0.35 end

                local move = Vector3.zero
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + Vector3.new(0, 0, -1) end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move + Vector3.new(0, 0, 1) end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move + Vector3.new(-1, 0, 0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + Vector3.new(1, 0, 0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.E)
                or UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.Q) then move = move + Vector3.new(0, -1, 0) end

                local js = FreeCamTouch.moveDir
                if js.Magnitude > 0.05 then move = move + Vector3.new(js.X, 0, js.Z) end
                if FreeCamTouch.upHeld then move = move + Vector3.new(0, 1, 0) end
                if FreeCamTouch.downHeld then move = move + Vector3.new(0, -1, 0) end

                if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
                    local d = UserInputService:GetMouseDelta()
                    lookAngles = lookAngles + Vector2.new(-d.X * 0.004, -d.Y * 0.004)
                end
                if FreeCamTouch._lookDelta and FreeCamTouch._lookDelta.Magnitude > 0 then
                    local d = FreeCamTouch._lookDelta
                    FreeCamTouch._lookDelta = Vector2.zero
                    lookAngles = lookAngles + Vector2.new(-d.X * 0.006, -d.Y * 0.006)
                end

                lookAngles = Vector2.new(lookAngles.X, math.clamp(lookAngles.Y, -1.4, 1.4))

                local rot = CFrame.fromEulerAnglesYXZ(lookAngles.Y, lookAngles.X, 0)
                local pos = c.CFrame.Position

                if move.Magnitude > 0.01 then
                    pos = pos + rot:VectorToWorldSpace(move.Unit) * speed * dt
                end

                c.CFrame = CFrame.new(pos) * rot
            end)
        end

        local function toggleFreeCam(state)
            if state then
                startFreeCam()
                if toastFn then
                    local mobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
                    toastFn(mobile and "Free Cam ON · joystick + drag" or "Free Cam ON · WASD + RMB", Theme.Success)
                end
            else
                stopFreeCam()
                if toastFn then toastFn("Free Cam OFF", Theme.TextDim) end
            end
        end

        LocalPlayer.CharacterAdded:Connect(function()
            if Config.FreeCam then task.defer(stopFreeCam) end
        end)

        _G._toggleFreeCam = toggleFreeCam
    end

    -- Travel
    createSection(PageTravel, "Mode", 1)

    local travelModeCard = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 70),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        LayoutOrder = 2,
        Parent = PageTravel,
    })
    addCorner(travelModeCard, 12)

    createInstance("TextLabel", {
        Size = UDim2.new(1, -20, 0, 14),
        Position = UDim2.new(0, 14, 0, 10),
        BackgroundTransparency = 1,
        Text = "Travel method",
        TextColor3 = Theme.TextMute,
        Font = Theme.Font,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = travelModeCard,
    })

    local travelPill = createInstance("Frame", {
        Size = UDim2.new(1, -28, 0, 32),
        Position = UDim2.new(0, 14, 0, 28),
        BackgroundColor3 = Theme.Input,
        BorderSizePixel = 0,
        Parent = travelModeCard,
    })
    addCorner(travelPill, 9)

    local tpPill = createInstance("TextButton", {
        Size = UDim2.new(0.5, -4, 1, -6),
        Position = UDim2.new(0, 3, 0, 3),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Text = "Teleport",
        TextColor3 = Theme.Text,
        Font = Theme.FontBold,
        TextSize = 12,
        AutoButtonColor = false,
        Parent = travelPill,
    })
    addCorner(tpPill, 7)

    local walkPill = createInstance("TextButton", {
        Size = UDim2.new(0.5, -4, 1, -6),
        Position = UDim2.new(0.5, 1, 0, 3),
        BackgroundColor3 = Theme.Input,
        BorderSizePixel = 0,
        Text = "Walk",
        TextColor3 = Theme.TextDim,
        Font = Theme.FontMedium,
        TextSize = 12,
        AutoButtonColor = false,
        Parent = travelPill,
    })
    addCorner(walkPill, 7)

    local function setTravelMode(mode)
        Config.TravelMode = mode
        stopWalk()
        local isTp = mode == "teleport"
        TweenService:Create(tpPill, TweenInfo.new(0.15), {
            BackgroundColor3 = isTp and Theme.Accent or Theme.Input,
            TextColor3 = isTp and Theme.Text or Theme.TextDim,
        }):Play()
        TweenService:Create(walkPill, TweenInfo.new(0.15), {
            BackgroundColor3 = (not isTp) and Theme.Accent or Theme.Input,
            TextColor3 = (not isTp) and Theme.Text or Theme.TextDim,
        }):Play()
        if toastFn then toastFn("Mode: " .. (isTp and "Teleport" or "Walk"), Theme.Accent) end
    end

    tpPill.MouseButton1Click:Connect(function() setTravelMode("teleport") end)
    walkPill.MouseButton1Click:Connect(function() setTravelMode("walk") end)

    createNumberRow(PageTravel, {
        name = "Return Delay",
        desc = "Seconds before return after steal",
        order = 3,
        value = tostring(Config.ReturnDelay),
        callback = function(v) Config.ReturnDelay = v end,
    })

    createSection(PageTravel, "Free Cam", 4)
    createToggleRow(PageTravel, {
        name = "Free Cam",
        desc = "Fly camera to scout · then Save position",
        order = 5,
        callback = function(state)
            if _G._toggleFreeCam then _G._toggleFreeCam(state) end
        end,
        input = {
            value = tostring(Config.FreeCamSpeed),
            callback = function(value)
                Config.FreeCamSpeed = math.max(5, value)
                if Config.FreeCam and toastFn then
                    toastFn("Free Cam speed: " .. tostring(Config.FreeCamSpeed), Theme.Accent)
                end
            end,
        },
    })

    createSection(PageTravel, "Locations", 7)

    local locationHolder = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 10,
        Parent = PageTravel,
    })
    addVerticalList(locationHolder, 8)

    local function refreshLocations()
        for _, row in ipairs(SharedUI.savedRows) do row:Destroy() end
        SharedUI.savedRows = {}

        local order = 1
        for name, data in pairs(SavedPoints) do
            local row = createInstance("Frame", {
                Size = UDim2.new(1, 0, 0, 68),
                BackgroundColor3 = Theme.Card,
                BorderSizePixel = 0,
                LayoutOrder = order,
                Parent = locationHolder,
            })
            addCorner(row, 12)
            order = order + 1

            local hitArea = createInstance("TextButton", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                Parent = row,
            })

            createInstance("Frame", {
                Size = UDim2.new(0, 7, 0, 7),
                Position = UDim2.new(0, 14, 0, 16),
                BackgroundColor3 = data.onSteal and Theme.Success or Theme.TextMute,
                BorderSizePixel = 0,
                Parent = row,
            })

            createInstance("TextLabel", {
                Size = UDim2.new(1, -150, 0, 16),
                Position = UDim2.new(0, 28, 0, 12),
                BackgroundTransparency = 1,
                Text = name,
                TextColor3 = Theme.Text,
                Font = Theme.FontMedium,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = row,
            })

            createInstance("TextLabel", {
                Size = UDim2.new(1, -150, 0, 14),
                Position = UDim2.new(0, 28, 0, 30),
                BackgroundTransparency = 1,
                Text = data.onSteal and (data.returnAfter and "Steal → Home → Back" or "Steal → Home") or "Manual only",
                TextColor3 = data.onSteal and Theme.Success or Theme.TextMute,
                Font = Theme.Font,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = row,
            })

            local function makeChip(text, xOffset, bg)
                local chip = createInstance("TextButton", {
                    Size = UDim2.new(0, 26, 0, 22),
                    Position = UDim2.new(1, xOffset, 0.5, -11),
                    BackgroundColor3 = bg,
                    BorderSizePixel = 0,
                    Text = text,
                    TextColor3 = Theme.Text,
                    Font = Theme.FontBold,
                    TextSize = 11,
                    AutoButtonColor = false,
                    Parent = row,
                })
                addCorner(chip, 6)
                return chip
            end

            local autoBtn = makeChip("A", -94, data.onSteal and Theme.Success or Theme.Off)
            local retBtn = makeChip("R", -64, data.returnAfter and Theme.Accent or Theme.Off)
            retBtn.Visible = data.onSteal

            local delBtn = createInstance("TextButton", {
                Size = UDim2.new(0, 26, 0, 22),
                Position = UDim2.new(1, -34, 0.5, -11),
                BackgroundColor3 = Theme.Off,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
                Parent = row,
            })
            addCorner(delBtn, 6)
            local delIcon = iconX(delBtn, 9, Theme.TextDim)

            autoBtn.MouseButton1Click:Connect(function()
                data.onSteal = not data.onSteal
                if not data.onSteal then data.returnAfter = false end
                refreshLocations()
            end)

            retBtn.MouseButton1Click:Connect(function()
                data.returnAfter = not data.returnAfter
                refreshLocations()
            end)

            delBtn.MouseButton1Click:Connect(function()
                SavedPoints[name] = nil
                refreshLocations()
                if toastFn then toastFn("Removed: " .. name, Theme.Danger) end
            end)

            hitArea.MouseButton1Click:Connect(function()
                task.spawn(function()
                    if Teleporting or StealLoopActive then return end
                    Teleporting = true
                    stopWalk()
                    local label = Config.TravelMode == "walk" and "Walking" or "Teleporting"
                    for i = 3, 1, -1 do
                        if toastFn then toastFn(label .. " → " .. name .. " in " .. i, Theme.Accent) end
                        task.wait(1)
                    end
                    if Root and data.cframe then
                        if travelTo(data.cframe, name) and toastFn then
                            toastFn("Arrived: " .. name, Theme.Success)
                        end
                    end
                    Teleporting = false
                end)
            end)

            table.insert(SharedUI.savedRows, row)
        end
    end

    _G._refreshLocations = refreshLocations

    local addLocBtn = createInstance("TextButton", {
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = 8,
        Parent = PageTravel,
    })
    addCorner(addLocBtn, 12)

    local addIconBg = createInstance("Frame", {
        Size = UDim2.new(0, 26, 0, 26),
        Position = UDim2.new(0, 12, 0.5, -13),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = addLocBtn,
    })
    addCorner(addIconBg, 7)
    iconPlus(addIconBg, 12, Theme.Text)

    createInstance("TextLabel", {
        Size = UDim2.new(1, -50, 1, 0),
        Position = UDim2.new(0, 46, 0, 0),
        BackgroundTransparency = 1,
        Text = "Save current position",
        TextColor3 = Theme.Text,
        Font = Theme.FontMedium,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = addLocBtn,
    })

    addLocBtn.MouseEnter:Connect(function()
        TweenService:Create(addLocBtn, TweenInfo.new(0.12), { BackgroundColor3 = Theme.CardHover }):Play()
    end)
    addLocBtn.MouseLeave:Connect(function()
        TweenService:Create(addLocBtn, TweenInfo.new(0.12), { BackgroundColor3 = Theme.Card }):Play()
    end)

    local function openAddLocation()
        if ScreenGui:FindFirstChild("AddPop") then return end

        local overlay = createInstance("TextButton", {
            Name = "AddPop",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 0.5,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 40,
            Parent = ScreenGui,
        })

        local popup = createInstance("Frame", {
            Size = UDim2.new(0, 280, 0, 280),
            Position = UDim2.new(0.5, -140, 0.5, -140),
            BackgroundColor3 = Theme.Background,
            BorderSizePixel = 0,
            ZIndex = 41,
            Parent = overlay,
        })
        addCorner(popup, 14)

        createInstance("TextLabel", {
            Size = UDim2.new(1, -28, 0, 22),
            Position = UDim2.new(0, 14, 0, 14),
            BackgroundTransparency = 1,
            Text = "Save Location",
            TextColor3 = Theme.Text,
            Font = Theme.FontBold,
            TextSize = 15,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 42,
            Parent = popup,
        })

        local inputFrame = createInstance("Frame", {
            Size = UDim2.new(1, -28, 0, 36),
            Position = UDim2.new(0, 14, 0, 46),
            BackgroundColor3 = Theme.Input,
            BorderSizePixel = 0,
            ZIndex = 42,
            Parent = popup,
        })
        addCorner(inputFrame, 9)

        local nameInput = createInstance("TextBox", {
            Size = UDim2.new(1, -16, 1, 0),
            Position = UDim2.new(0, 8, 0, 0),
            BackgroundTransparency = 1,
            Text = "",
            PlaceholderText = "Name…",
            PlaceholderColor3 = Theme.TextMute,
            TextColor3 = Theme.Text,
            Font = Theme.FontMedium,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false,
            ZIndex = 43,
            Parent = inputFrame,
        })
        nameInput:CaptureFocus()

        local autoOn, retOn = false, false

        local function makePopupToggle(y, label)
            local f = createInstance("Frame", {
                Size = UDim2.new(1, -28, 0, 36),
                Position = UDim2.new(0, 14, 0, y),
                BackgroundColor3 = Theme.Card,
                BorderSizePixel = 0,
                ZIndex = 42,
                Parent = popup,
            })
            addCorner(f, 9)
            createInstance("TextLabel", {
                Size = UDim2.new(1, -56, 1, 0),
                Position = UDim2.new(0, 12, 0, 0),
                BackgroundTransparency = 1,
                Text = label,
                TextColor3 = Theme.Text,
                Font = Theme.FontMedium,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 43,
                Parent = f,
            })
            local t = createInstance("TextButton", {
                Size = UDim2.new(0, 38, 0, 20),
                Position = UDim2.new(1, -48, 0.5, -10),
                BackgroundColor3 = Theme.Off,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
                ZIndex = 43,
                Parent = f,
            })
            addCorner(t, 10)
            local k = createInstance("Frame", {
                Size = UDim2.new(0, 16, 0, 16),
                Position = UDim2.new(0, 2, 0.5, -8),
                BackgroundColor3 = Theme.Text,
                BorderSizePixel = 0,
                ZIndex = 44,
                Parent = t,
            })
            addCorner(k, 8)
            return t, k
        end

        local aT, aK = makePopupToggle(94, "Auto on steal")
        local rT, rK = makePopupToggle(140, "Return after")

        aT.MouseButton1Click:Connect(function()
            autoOn = not autoOn
            TweenService:Create(aT, TweenInfo.new(0.15), { BackgroundColor3 = autoOn and Theme.Success or Theme.Off }):Play()
            TweenService:Create(aK, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Position = autoOn and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
            }):Play()
        end)

        rT.MouseButton1Click:Connect(function()
            retOn = not retOn
            TweenService:Create(rT, TweenInfo.new(0.15), { BackgroundColor3 = retOn and Theme.Accent or Theme.Off }):Play()
            TweenService:Create(rK, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Position = retOn and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
            }):Play()
        end)

        local saveBtn = createInstance("TextButton", {
            Size = UDim2.new(0.5, -20, 0, 34),
            Position = UDim2.new(0, 14, 1, -50),
            BackgroundColor3 = Theme.Accent,
            BorderSizePixel = 0,
            Text = "Save",
            TextColor3 = Theme.Text,
            Font = Theme.FontBold,
            TextSize = 13,
            AutoButtonColor = false,
            ZIndex = 42,
            Parent = popup,
        })
        addCorner(saveBtn, 9)

        local cancelBtn = createInstance("TextButton", {
            Size = UDim2.new(0.5, -20, 0, 34),
            Position = UDim2.new(0.5, 6, 1, -50),
            BackgroundColor3 = Theme.Card,
            BorderSizePixel = 0,
            Text = "Cancel",
            TextColor3 = Theme.TextDim,
            Font = Theme.FontMedium,
            TextSize = 13,
            AutoButtonColor = false,
            ZIndex = 42,
            Parent = popup,
        })
        addCorner(cancelBtn, 9)

        local function closePopup() overlay:Destroy() end

        local function saveLocation()
            local name = nameInput.Text
            if name == "" or SavedPoints[name] then return end
            local saveCF
            if Config.FreeCam then
                local cam = Workspace.CurrentCamera
                if cam then saveCF = CFrame.new(cam.CFrame.Position) end
            end
            if not saveCF and Root then saveCF = Root.CFrame end
            if not saveCF then return end

            SavedPoints[name] = { cframe = saveCF, onSteal = autoOn, returnAfter = autoOn and retOn }
            if _G._refreshLocations then _G._refreshLocations() end
            if toastFn then
                toastFn("Saved: " .. name .. (Config.FreeCam and " (free cam)" or ""), Theme.Success)
            end
            closePopup()
        end

        saveBtn.MouseButton1Click:Connect(saveLocation)
        nameInput.FocusLost:Connect(function(enter) if enter then saveLocation() end end)
        cancelBtn.MouseButton1Click:Connect(closePopup)
        overlay.MouseButton1Click:Connect(closePopup)
    end

    addLocBtn.MouseButton1Click:Connect(openAddLocation)

    -- Pickup
    local function itemAllowed(name)
        if SharedUI.PickupModeAll then return true end
        return SharedUI.SelectedItems[name] == true
    end

    local function travelToPickup(targetPos, label)
        if not targetPos or not Root then return false end
        local targetCF = CFrame.new(targetPos, Vector3.new(Root.Position.X, targetPos.Y, Root.Position.Z))
        return travelTo(targetCF, label)
    end

    local function scanServerItems()
        local itemMap = {}
        local function addItem(name, kind)
            if not name or name == "" then return end
            if not itemMap[name] then itemMap[name] = { count = 0, kind = kind or "Item" } end
            itemMap[name].count = itemMap[name].count + 1
        end

        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") and obj.Enabled then
                local name = obj.ObjectText ~= "" and obj.ObjectText
                    or (obj.ActionText ~= "" and obj.ActionText)
                    or (obj.Parent and obj.Parent.Name) or "Prompt"
                addItem(name, "Prompt")
            elseif obj:IsA("Tool") and obj.Parent == Workspace then
                addItem(obj.Name, "Tool")
            end
        end

        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj:IsA("BasePart") or obj:IsA("Model") then
                local n = string.lower(obj.Name)
                if string.find(n, "coin") or string.find(n, "gem") or string.find(n, "cash")
                or string.find(n, "pickup") or string.find(n, "item") or string.find(n, "orb")
                or string.find(n, "token") or string.find(n, "loot") or string.find(n, "drop")
                or string.find(n, "chest") or string.find(n, "bag") or string.find(n, "crate") then
                    addItem(obj.Name, "Drop")
                end
            end
        end

        SharedUI.ScannedItems = {}
        for name, data in pairs(itemMap) do
            table.insert(SharedUI.ScannedItems, { name = name, count = data.count, kind = data.kind })
        end
        table.sort(SharedUI.ScannedItems, function(a, b) return a.name:lower() < b.name:lower() end)
        return #SharedUI.ScannedItems
    end

    local function collectNearbyDirect()
        if not Root or not Root.Parent then return 0 end
        local origin = Root.Position
        local range = tonumber(Config.PickupRange) or 20
        local found = 0

        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") and obj.Enabled then
                local name = obj.ObjectText ~= "" and obj.ObjectText
                    or (obj.ActionText ~= "" and obj.ActionText)
                    or (obj.Parent and obj.Parent.Name) or "Prompt"
                if itemAllowed(name) then
                    local pos = getItemPosition(obj)
                    if pos and (pos - origin).Magnitude <= range then
                        if firePrompt(obj) then found = found + 1 end
                    end
                end
            end
        end

        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj:IsA("Tool") then
                if itemAllowed(obj.Name) then
                    local h = obj:FindFirstChild("Handle")
                    if h and h:IsA("BasePart") and (h.Position - origin).Magnitude <= range then
                        pcall(function()
                            if firetouchinterest then
                                firetouchinterest(h, Root, 0)
                                firetouchinterest(h, Root, 1)
                            end
                        end)
                        pcall(function()
                            if LocalPlayer.Character then obj.Parent = LocalPlayer.Character end
                        end)
                        found = found + 1
                    end
                end
            elseif obj:IsA("BasePart") or obj:IsA("Model") then
                if itemAllowed(obj.Name) then
                    local pos = getItemPosition(obj)
                    if pos and (pos - origin).Magnitude <= range then
                        local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
                        if part then
                            pcall(function()
                                if firetouchinterest then
                                    firetouchinterest(part, Root, 0)
                                    firetouchinterest(part, Root, 1)
                                end
                            end)
                        end
                        found = found + 1
                    end
                end
            end
        end
        return found
    end

    local function findClosestItem()
        if not Root or not Root.Parent then return nil end
        local origin = Root.Position
        local best, bestD = nil, math.huge

        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") and obj.Enabled then
                local name = obj.ObjectText ~= "" and obj.ObjectText
                    or (obj.ActionText ~= "" and obj.ActionText)
                    or (obj.Parent and obj.Parent.Name) or "Prompt"
                if itemAllowed(name) then
                    local pos = getItemPosition(obj)
                    if pos then
                        local d = (pos - origin).Magnitude
                        if d < bestD then
                            bestD = d
                            best = { object = obj, position = pos, name = name, kind = "Prompt" }
                        end
                    end
                end
            end
        end

        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj:IsA("Tool") then
                if itemAllowed(obj.Name) then
                    local h = obj:FindFirstChild("Handle")
                    if h and h:IsA("BasePart") then
                        local d = (h.Position - origin).Magnitude
                        if d < bestD then
                            bestD = d
                            best = { object = obj, position = h.Position, name = obj.Name, kind = "Tool" }
                        end
                    end
                end
            end
        end

        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj:IsA("BasePart") or obj:IsA("Model") then
                local n = string.lower(obj.Name)
                if string.find(n, "coin") or string.find(n, "gem") or string.find(n, "cash")
                or string.find(n, "pickup") or string.find(n, "item") or string.find(n, "orb")
                or string.find(n, "token") or string.find(n, "loot") or string.find(n, "drop")
                or string.find(n, "chest") or string.find(n, "bag") or string.find(n, "crate") then
                    if itemAllowed(obj.Name) then
                        local pos = getItemPosition(obj)
                        if pos then
                            local d = (pos - origin).Magnitude
                            if d < bestD then
                                bestD = d
                                best = { object = obj, position = pos, name = obj.Name, kind = "Drop" }
                            end
                        end
                    end
                end
            end
        end
        return best
    end

    local function pickupLoop()
        while Config.AutoPickup do
            local waitTime = tonumber(Config.PickupDelay) or 0.25
            local range = tonumber(Config.PickupRange) or 20
            local limit = tonumber(Config.PickupLimit) or 0

            if limit > 0 and Config.PickupCount >= limit then
                task.wait(Config.PickupWaitAfterLimit)
                if Config.AutoPickup then
                    Config.PickupCount = 0
                    SharedUI.PickupCount = 0
                    if toastFn then toastFn("Pickup limit reached · resetting", Theme.Accent) end
                end
                task.wait(waitTime)
                continue
            end

            local direct = 0
            pcall(function() direct = collectNearbyDirect() end)
            if direct > 0 then
                SharedUI.PickupCount = SharedUI.PickupCount + direct
                Config.PickupCount = Config.PickupCount + direct
            end

            if not SharedUI.PickupTraveling and Root and Root.Parent then
                local closest = findClosestItem()
                if closest then
                    local d = (closest.position - Root.Position).Magnitude
                    if d > range then
                        SharedUI.PickupTraveling = true
                        task.spawn(function()
                            local ok = travelToPickup(closest.position, "pickup: " .. closest.name)
                            if ok then
                                task.wait(0.1)
                                if closest.kind == "Prompt" then
                                    pcall(function() firePrompt(closest.object) end)
                                elseif closest.kind == "Tool" then
                                    local h = closest.object:FindFirstChild("Handle")
                                    if h then
                                        pcall(function()
                                            if firetouchinterest then
                                                firetouchinterest(h, Root, 0)
                                                firetouchinterest(h, Root, 1)
                                            end
                                        end)
                                        pcall(function()
                                            if LocalPlayer.Character then
                                                closest.object.Parent = LocalPlayer.Character
                                            end
                                        end)
                                    end
                                elseif closest.kind == "Drop" then
                                    local part = closest.object:IsA("BasePart") and closest.object
                                        or closest.object:FindFirstChildWhichIsA("BasePart", true)
                                    if part then
                                        pcall(function()
                                            if firetouchinterest then
                                                firetouchinterest(part, Root, 0)
                                                firetouchinterest(part, Root, 1)
                                            end
                                        end)
                                    end
                                end
                                SharedUI.PickupCount = SharedUI.PickupCount + 1
                                Config.PickupCount = Config.PickupCount + 1
                            end
                            SharedUI.PickupTraveling = false
                        end)
                    end
                end
            end
            task.wait(waitTime)
        end
        SharedUI.PickupConn = nil
    end

    local function startAutoPickup()
        if SharedUI.PickupConn then return end
        Config.PickupCount = 0
        SharedUI.PickupCount = 0
        SharedUI.PickupConn = true
        task.spawn(pickupLoop)
    end

    local function stopAutoPickup()
        Config.AutoPickup = false
        SharedUI.PickupConn = nil
        SharedUI.PickupTraveling = false
        stopWalk()
    end

    createSection(PagePickup, "Auto Pickup", 1)
    createToggleRow(PagePickup, {
        name = "Auto Pickup",
        desc = "Travel + collect items in range (toggle controlled)",
        order = 2,
        callback = function(state)
            Config.AutoPickup = state
            if state then
                startAutoPickup()
                if toastFn then
                    toastFn("Auto Pickup ON · " .. (Config.TravelMode == "walk" and "Walking" or "Teleporting"), Theme.Success)
                end
            else
                stopAutoPickup()
                if toastFn then toastFn("Auto Pickup OFF", Theme.TextDim) end
            end
        end,
    })

    createNumberRow(PagePickup, {
        name = "Pickup Range",
        desc = "Studs around player (radius)",
        order = 3,
        value = tostring(Config.PickupRange),
        callback = function(v)
            Config.PickupRange = v
            if toastFn then toastFn("Pickup range: " .. tostring(v), Theme.Accent) end
        end,
    })

    createNumberRow(PagePickup, {
        name = "Scan Delay",
        desc = "Seconds between each scan",
        order = 4,
        value = tostring(Config.PickupDelay),
        callback = function(v) Config.PickupDelay = math.max(0.05, v) end,
    })

    createNumberRow(PagePickup, {
        name = "Pickup Limit",
        desc = "Items per cycle (0 = unlimited)",
        order = 5,
        value = tostring(Config.PickupLimit),
        callback = function(v)
            Config.PickupLimit = math.max(0, math.floor(v))
            Config.PickupCount = 0
            SharedUI.PickupCount = 0
            if toastFn then
                toastFn(Config.PickupLimit == 0 and "Pickup limit: UNLIMITED"
                    or ("Pickup limit: " .. tostring(Config.PickupLimit)), Theme.Accent)
            end
        end,
    })

    local pickupModeCard = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 70),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        LayoutOrder = 6,
        Parent = PagePickup,
    })
    addCorner(pickupModeCard, 12)

    createInstance("TextLabel", {
        Size = UDim2.new(1, -20, 0, 14),
        Position = UDim2.new(0, 14, 0, 8),
        BackgroundTransparency = 1,
        Text = "Pickup target",
        TextColor3 = Theme.TextMute,
        Font = Theme.Font,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = pickupModeCard,
    })

    local pickupPill = createInstance("Frame", {
        Size = UDim2.new(1, -28, 0, 32),
        Position = UDim2.new(0, 14, 0, 28),
        BackgroundColor3 = Theme.Input,
        BorderSizePixel = 0,
        Parent = pickupModeCard,
    })
    addCorner(pickupPill, 9)

    local allPill = createInstance("TextButton", {
        Size = UDim2.new(0.5, -4, 1, -6),
        Position = UDim2.new(0, 3, 0, 3),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Text = "All items",
        TextColor3 = Theme.Text,
        Font = Theme.FontBold,
        TextSize = 11,
        AutoButtonColor = false,
        Parent = pickupPill,
    })
    addCorner(allPill, 7)

    local selPill = createInstance("TextButton", {
        Size = UDim2.new(0.5, -4, 1, -6),
        Position = UDim2.new(0.5, 1, 0, 3),
        BackgroundColor3 = Theme.Input,
        BorderSizePixel = 0,
        Text = "Selected only",
        TextColor3 = Theme.TextDim,
        Font = Theme.FontMedium,
        TextSize = 11,
        AutoButtonColor = false,
        Parent = pickupPill,
    })
    addCorner(selPill, 7)

    local function setPickupMode(allMode)
        SharedUI.PickupModeAll = allMode
        TweenService:Create(allPill, TweenInfo.new(0.15), {
            BackgroundColor3 = allMode and Theme.Accent or Theme.Input,
            TextColor3 = allMode and Theme.Text or Theme.TextDim,
        }):Play()
        TweenService:Create(selPill, TweenInfo.new(0.15), {
            BackgroundColor3 = (not allMode) and Theme.Accent or Theme.Input,
            TextColor3 = (not allMode) and Theme.Text or Theme.TextDim,
        }):Play()
        if toastFn then
            toastFn(allMode and "Pickup: ALL items" or "Pickup: SELECTED only", Theme.Accent)
        end
    end

    allPill.MouseButton1Click:Connect(function() setPickupMode(true) end)
    selPill.MouseButton1Click:Connect(function() setPickupMode(false) end)

    createSection(PagePickup, "Server items", 7)

    local filterCard = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        LayoutOrder = 8,
        Parent = PagePickup,
    })
    addCorner(filterCard, 12)

    local filterBox = createInstance("TextBox", {
        Size = UDim2.new(1, -110, 0, 28),
        Position = UDim2.new(0, 10, 0.5, -14),
        BackgroundColor3 = Theme.Input,
        BorderSizePixel = 0,
        Text = "",
        PlaceholderText = "Filter name…",
        PlaceholderColor3 = Theme.TextMute,
        TextColor3 = Theme.Text,
        Font = Theme.FontMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Parent = filterCard,
    })
    addCorner(filterBox, 8)

    local scanBtn = createInstance("TextButton", {
        Size = UDim2.new(0, 70, 0, 28),
        Position = UDim2.new(1, -80, 0.5, -14),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Text = "Scan",
        TextColor3 = Theme.Text,
        Font = Theme.FontBold,
        TextSize = 12,
        AutoButtonColor = false,
        Parent = filterCard,
    })
    addCorner(scanBtn, 8)

    local itemListHolder = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 10,
        Parent = PagePickup,
    })
    addVerticalList(itemListHolder, 6)

    local refreshPickupList
    refreshPickupList = function()
        for _, row in ipairs(SharedUI.PickupListRows) do row:Destroy() end
        SharedUI.PickupListRows = {}

        local filter = string.lower(SharedUI.PickupFilterText or "")
        local order = 1

        for _, item in ipairs(SharedUI.ScannedItems) do
            if filter == "" or string.find(string.lower(item.name), filter, 1, true) then
                local row = createInstance("Frame", {
                    Size = UDim2.new(1, 0, 0, 48),
                    BackgroundColor3 = Theme.Card,
                    BorderSizePixel = 0,
                    LayoutOrder = order,
                    Parent = itemListHolder,
                })
                addCorner(row, 10)
                order = order + 1

                local isChecked = SharedUI.SelectedItems[item.name] == true
                local check = createInstance("TextButton", {
                    Size = UDim2.new(0, 22, 0, 22),
                    Position = UDim2.new(0, 12, 0.5, -11),
                    BackgroundColor3 = isChecked and Theme.Success or Theme.Off,
                    BorderSizePixel = 0,
                    Text = isChecked and "✓" or "",
                    TextColor3 = Theme.Text,
                    Font = Theme.FontBold,
                    TextSize = 12,
                    AutoButtonColor = false,
                    Parent = row,
                })
                addCorner(check, 6)

                createInstance("TextLabel", {
                    Size = UDim2.new(1, -120, 0, 16),
                    Position = UDim2.new(0, 44, 0, 8),
                    BackgroundTransparency = 1,
                    Text = item.name,
                    TextColor3 = Theme.Text,
                    Font = Theme.FontMedium,
                    TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Parent = row,
                })

                createInstance("TextLabel", {
                    Size = UDim2.new(1, -120, 0, 14),
                    Position = UDim2.new(0, 44, 0, 26),
                    BackgroundTransparency = 1,
                    Text = item.kind .. " · x" .. tostring(item.count),
                    TextColor3 = Theme.TextMute,
                    Font = Theme.Font,
                    TextSize = 11,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = row,
                })

                check.MouseButton1Click:Connect(function()
                    if SharedUI.SelectedItems[item.name] then
                        SharedUI.SelectedItems[item.name] = nil
                    else
                        SharedUI.SelectedItems[item.name] = true
                        setPickupMode(false)
                    end
                    refreshPickupList()
                end)

                table.insert(SharedUI.PickupListRows, row)
            end
        end
    end

    filterBox:GetPropertyChangedSignal("Text"):Connect(function()
        SharedUI.PickupFilterText = filterBox.Text
        refreshPickupList()
    end)

    scanBtn.MouseButton1Click:Connect(function()
        local count = scanServerItems()
        refreshPickupList()
        if toastFn then toastFn("Scanned " .. tostring(count) .. " item types", Theme.Success) end
    end)

    -- Players
    createSection(PagePlayers, "Online", 1)

    local playersHolder = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 2,
        Parent = PagePlayers,
    })
    addVerticalList(playersHolder, 8)

    local function refreshPlayers()
        for _, row in ipairs(SharedUI.playerRows) do row:Destroy() end
        SharedUI.playerRows = {}

        local order = 1
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local row = createInstance("Frame", {
                    Size = UDim2.new(1, 0, 0, 56),
                    BackgroundColor3 = Theme.Card,
                    BorderSizePixel = 0,
                    LayoutOrder = order,
                    Parent = playersHolder,
                })
                addCorner(row, 12)
                order = order + 1

                local isTarget = LockTarget == player
                if isTarget then row.BackgroundColor3 = Theme.CardHover end

                local avatar = createInstance("ImageLabel", {
                    Size = UDim2.new(0, 34, 0, 34),
                    Position = UDim2.new(0, 10, 0.5, -17),
                    BackgroundColor3 = Theme.Surface,
                    BorderSizePixel = 0,
                    Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150",
                    Parent = row,
                })
                addCorner(avatar, 9)

                createInstance("TextLabel", {
                    Size = UDim2.new(1, -130, 0, 16),
                    Position = UDim2.new(0, 52, 0, 12),
                    BackgroundTransparency = 1,
                    Text = player.DisplayName,
                    TextColor3 = Theme.Text,
                    Font = Theme.FontMedium,
                    TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Parent = row,
                })
                createInstance("TextLabel", {
                    Size = UDim2.new(1, -130, 0, 14),
                    Position = UDim2.new(0, 52, 0, 30),
                    BackgroundTransparency = 1,
                    Text = "@" .. player.Name,
                    TextColor3 = Theme.TextMute,
                    Font = Theme.Font,
                    TextSize = 11,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = row,
                })

                local followBtn = createInstance("TextButton", {
                    Size = UDim2.new(0, 28, 0, 24),
                    Position = UDim2.new(1, -68, 0.5, -12),
                    BackgroundColor3 = (isTarget and CurrentMode == "follow") and Theme.Success or Theme.Off,
                    BorderSizePixel = 0,
                    Text = "F",
                    TextColor3 = Theme.Text,
                    Font = Theme.FontBold,
                    TextSize = 12,
                    AutoButtonColor = false,
                    Parent = row,
                })
                addCorner(followBtn, 7)

                local attackBtn = createInstance("TextButton", {
                    Size = UDim2.new(0, 28, 0, 24),
                    Position = UDim2.new(1, -36, 0.5, -12),
                    BackgroundColor3 = (isTarget and CurrentMode == "attack") and Theme.Danger or Theme.Off,
                    BorderSizePixel = 0,
                    Text = "X",
                    TextColor3 = Theme.Text,
                    Font = Theme.FontBold,
                    TextSize = 12,
                    AutoButtonColor = false,
                    Parent = row,
                })
                addCorner(attackBtn, 7)

                followBtn.MouseButton1Click:Connect(function()
                    if LockTarget == player and CurrentMode == "follow" then
                        stopPlayerLock()
                    else
                        startPlayerLock(player, "follow")
                        CurrentMode = "follow"
                        if toastFn then toastFn("Following: " .. player.DisplayName, Theme.Success) end
                    end
                    refreshPlayers()
                end)

                attackBtn.MouseButton1Click:Connect(function()
                    if LockTarget == player and CurrentMode == "attack" then
                        stopPlayerLock()
                    else
                        startPlayerLock(player, "attack")
                        CurrentMode = "attack"
                        if toastFn then toastFn("Attacking: " .. player.DisplayName, Theme.Danger) end
                    end
                    refreshPlayers()
                end)

                table.insert(SharedUI.playerRows, row)
            end
        end
    end

    refreshPlayers()
    Players.PlayerAdded:Connect(function() task.wait(0.4) refreshPlayers() end)
    Players.PlayerRemoving:Connect(function(player)
        if LockTarget == player then stopPlayerLock() end
        task.wait(0.2)
        refreshPlayers()
    end)

    -- Window controls
    local savedPosition = Shell.Position
    local hidden, animating = false, false

    local function restoreContent()
        SharedUI.minimized = false
        TabBar.Visible = true
        Header.Visible = true
        Shell.Size = UDim2.new(0, UI_WIDTH, 0, UI_HEIGHT)
        switchTab(SharedUI.ActiveTab or "main")
    end

    local function showWindow()
        if animating or not hidden then return end
        animating = true
        Shell.Position = savedPosition
        Shell.Visible = true
        restoreContent()

        Shell.Size = UDim2.new(0, UI_WIDTH, 0, 0)
        local tween = TweenService:Create(Shell, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, UI_WIDTH, 0, UI_HEIGHT),
        })
        tween:Play()
        tween.Completed:Wait()
        restoreContent()
        hidden, animating = false, false
    end

    local function hideWindow()
        if animating or hidden then return end
        animating = true
        SharedUI.minimized = false
        TabBar.Visible = true

        local tween = TweenService:Create(Shell, TweenInfo.new(0.18), {
            Size = UDim2.new(0, UI_WIDTH, 0, 0),
        })
        tween:Play()
        tween.Completed:Wait()

        Shell.Visible = false
        Shell.Size = UDim2.new(0, UI_WIDTH, 0, UI_HEIGHT)
        FloatBtn.Visible = true
        FloatBtn.Size = UDim2.new(0, 0, 0, 0)

        local ft = TweenService:Create(FloatBtn, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 46, 0, 46),
        })
        ft:Play()
        ft.Completed:Wait()
        hidden, animating = true, false
    end

    CloseBtn.MouseButton1Click:Connect(function()
        savedPosition = Shell.Position
        hideWindow()
    end)

    FloatBtn.MouseButton1Click:Connect(function()
        task.spawn(function()
            local tween = TweenService:Create(FloatBtn, TweenInfo.new(0.12), {
                Size = UDim2.new(0, 0, 0, 0),
            })
            tween:Play()
            tween.Completed:Wait()
            FloatBtn.Visible = false
            showWindow()
        end)
    end)

    MinimizeBtn.MouseButton1Click:Connect(function()
        SharedUI.minimized = not SharedUI.minimized
        if SharedUI.minimized then
            TabBar.Visible = false
            for _, data in pairs(SharedUI.Pages) do data.page.Visible = false end
            TweenService:Create(Shell, TweenInfo.new(0.22), {
                Size = UDim2.new(0, UI_WIDTH, 0, 54),
            }):Play()
        else
            TabBar.Visible = true
            switchTab(SharedUI.ActiveTab)
            TweenService:Create(Shell, TweenInfo.new(0.22), {
                Size = UDim2.new(0, UI_WIDTH, 0, UI_HEIGHT),
            }):Play()
        end
    end)

    local dragging, dragStart, dragStartPos
    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            dragStartPos = Shell.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            Shell.Position = UDim2.new(
                dragStartPos.X.Scale, dragStartPos.X.Offset + delta.X,
                dragStartPos.Y.Scale, dragStartPos.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputState == Enum.UserInputState.End and dragging then
            dragging = false
            savedPosition = Shell.Position
        end
    end)

    local floating, floatStart, floatStartPos
    FloatBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            floating = true
            floatStart = input.Position
            floatStartPos = FloatBtn.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not floating then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - floatStart
            FloatBtn.Position = UDim2.new(
                floatStartPos.X.Scale, floatStartPos.X.Offset + delta.X,
                floatStartPos.Y.Scale, floatStartPos.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function()
        floating = false
    end)
end

toastFn("Ghost Walk v10.1 · ready", Theme.Success)
