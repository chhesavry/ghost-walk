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

do
    local LocalPlayer     = Players.LocalPlayer
    local DEFAULT_GRAVITY = 196.2
    local SESSION_START   = tick()
    local UI_WIDTH        = 400
    local UI_HEIGHT       = 520
    local UI_BORDER       = 1

    local Config = {
        Speed        = 100,
        DefaultSpeed = 16,
        BoostActive  = false,
        GhostActive  = false,
        InvisActive  = false,
        GodMode      = false,
        FlyActive    = false,
        FlyHeight    = 25,
        TravelMode = "teleport",
        ReturnDelay = 1.0,
        FpsBoost = false,
        FreeCam      = false,
        FreeCamSpeed = 60,
        AutoPickup   = false,
        PickupRange  = 20,
        PickupDelay  = 0.25,
        PickupLimit  = 0,
        PickupCount  = 0,
        PickupWaitAfterLimit = 1.0,
        PickupESP        = false,
        PickupESPColor   = Color3.fromRGB(90, 200, 255),
        PickupESPSelected = false,
    }

    local LiveFPS, LivePing = 0, 0
    local fpsFrames, fpsLast = 0, tick()

    local Character, Humanoid, Root
    local NoclipConn, HeightConn, InvisConn, GodConn
    local SavedPoints      = {}
    local Teleporting      = false
    local WalkConn         = nil
    local StealLoopActive  = false
    local LockTarget, LockConn, LockMode, CurrentMode = nil, nil, "follow", "follow"
    local toastFn

    local function createInstance(class, props)
        local instance = Instance.new(class)
        for key, value in pairs(props or {}) do
            instance[key] = value
        end
        return instance
    end

    local function addCorner(parent, radius)
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, radius or 10)
        corner.Parent = parent
        return corner
    end

    local function addPadding(parent, top, right, bottom, left)
        local padding = Instance.new("UIPadding")
        padding.PaddingTop    = UDim.new(0, top or 0)
        padding.PaddingRight  = UDim.new(0, right or 0)
        padding.PaddingBottom = UDim.new(0, bottom or 0)
        padding.PaddingLeft   = UDim.new(0, left or 0)
        padding.Parent = parent
        return padding
    end

    local function addVerticalList(parent, gap)
        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Vertical
        layout.Padding       = UDim.new(0, gap or 8)
        layout.SortOrder     = Enum.SortOrder.LayoutOrder
        layout.Parent        = parent
        return layout
    end

    local function addHorizontalList(parent, gap)
        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.Padding       = UDim.new(0, gap or 6)
        layout.SortOrder     = Enum.SortOrder.LayoutOrder
        layout.Parent        = parent
        return layout
    end

    local function bindCharacter(char)
        Character = char
        Humanoid  = char:WaitForChild("Humanoid")
        Root      = char:WaitForChild("HumanoidRootPart")
        Config.DefaultSpeed = Humanoid.WalkSpeed
    end

    if LocalPlayer.Character then
        bindCharacter(LocalPlayer.Character)
    end

    local function enableGhostWalk()
        local lockedY = Root.Position.Y
        Workspace.Gravity = 0
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)

        NoclipConn = RunService.Stepped:Connect(function()
            for _, part in ipairs(Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end)

        HeightConn = RunService.Heartbeat:Connect(function()
            local velocity = Root.AssemblyLinearVelocity
            Root.CFrame = CFrame.new(Root.Position.X, lockedY, Root.Position.Z)
            Root.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, velocity.Z)
            Humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end)
    end

    local function disableGhostWalk()
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

    local function enableInvisibility()
        for _, part in ipairs(Character:GetDescendants()) do
            if part:IsA("BasePart") or part:IsA("Decal") then
                part.Transparency = 1
            end
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

    local function disableInvisibility()
        if InvisConn then
            InvisConn:Disconnect()
            InvisConn = nil
        end

        for _, part in ipairs(Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Transparency = (part.Name == "HumanoidRootPart") and 1 or 0
            elseif part:IsA("Decal") then
                part.Transparency = 0
            end
        end

        for _, accessory in ipairs(Character:GetChildren()) do
            if accessory:IsA("Accessory") then
                local handle = accessory:FindFirstChild("Handle")
                if handle then handle.Transparency = 0 end
            end
        end
    end

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
        local success, ping = pcall(function()
            return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        if success and typeof(ping) == "number" then
            LivePing = math.floor(ping + 0.5)
        end
    end)

    local function formatSession()
        local elapsed = math.floor(tick() - SESSION_START)
        local hours   = math.floor(elapsed / 3600)
        local minutes = math.floor((elapsed % 3600) / 60)
        local seconds = elapsed % 60

        if hours > 0 then
            return string.format("%dh %02dm", hours, minutes)
        end
        return string.format("%dm %02ds", minutes, seconds)
    end

    local FpsBoostSaved = nil

    local function enableFpsBoost()
        FpsBoostSaved = {
            quality       = settings().Rendering.QualityLevel,
            mesh          = settings().Rendering.MeshPartDetailLevel,
            globalShadows = Lighting.GlobalShadows,
            fogEnd        = Lighting.FogEnd,
            brightness    = Lighting.Brightness,
        }

        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
        end)

        pcall(function()
            Lighting.GlobalShadows = false
            Lighting.FogEnd        = 9e9
            Lighting.Brightness    = 1
        end)

        pcall(function()
            for _, effect in ipairs(Lighting:GetChildren()) do
                if effect:IsA("BlurEffect")
                or effect:IsA("SunRaysEffect")
                or effect:IsA("ColorCorrectionEffect")
                or effect:IsA("BloomEffect")
                or effect:IsA("DepthOfFieldEffect") then
                    effect.Enabled = false
                end
            end
        end)

        pcall(function()
            if setfpscap then setfpscap(999) end
        end)
        pcall(function()
            if typeof(setfps) == "function" then setfps(999) end
        end)
    end

    local function disableFpsBoost()
        if not FpsBoostSaved then return end

        pcall(function()
            settings().Rendering.QualityLevel = FpsBoostSaved.quality
            settings().Rendering.MeshPartDetailLevel = FpsBoostSaved.mesh
        end)

        pcall(function()
            Lighting.GlobalShadows = FpsBoostSaved.globalShadows
            Lighting.FogEnd        = FpsBoostSaved.fogEnd
            Lighting.Brightness    = FpsBoostSaved.brightness
        end)

        pcall(function()
            if setfpscap then setfpscap(60) end
        end)

        FpsBoostSaved = nil
    end

    local GodLoopStarted = false
    local GodAntiTPConn  = nil
    local GodLastCF      = nil
    local GodLastSafeCF  = nil
    local GodIgnoreTP    = false
    local GodForceUntil  = 0

    local function godMarkSafe()
        if Root and Root.Parent then
            GodLastSafeCF = Root.CFrame
            GodLastCF = Root.CFrame
        end
    end

    local function enableGodMode()
        Config.GodMode = true

        if GodConn then GodConn:Disconnect() GodConn = nil end
        if GodAntiTPConn then GodAntiTPConn:Disconnect() GodAntiTPConn = nil end
        if not Humanoid then return end

        pcall(function()
            Humanoid.MaxHealth = math.max(Humanoid.MaxHealth, 100)
            Humanoid.Health    = Humanoid.MaxHealth
        end)
        godMarkSafe()

        GodConn = Humanoid.HealthChanged:Connect(function()
            if Config.GodMode ~= true then return end
            if not Humanoid or not Humanoid.Parent then return end
            if Humanoid.Health < Humanoid.MaxHealth then
                Humanoid.Health = Humanoid.MaxHealth
            end
        end)

        GodAntiTPConn = RunService.Heartbeat:Connect(function()
            if not Config.GodMode or not Root or not Root.Parent then return end
            if GodIgnoreTP or Teleporting or StealLoopActive or WalkConn then
                godMarkSafe()
                return
            end

            local nowCF = Root.CFrame
            local now   = tick()

            if now < GodForceUntil and GodLastSafeCF then
                Root.CFrame = GodLastSafeCF
                Root.AssemblyLinearVelocity = Vector3.zero
                return
            end

            if GodLastCF then
                local distance = (nowCF.Position - GodLastCF.Position).Magnitude
                if distance > 20 and GodLastSafeCF then
                    GodForceUntil = now + 1.0
                    Root.CFrame = GodLastSafeCF
                    Root.AssemblyLinearVelocity = Vector3.zero

                    if Humanoid then
                        pcall(function()
                            Humanoid.Health = Humanoid.MaxHealth
                            Humanoid:ChangeState(Enum.HumanoidStateType.Running)
                        end)
                    end

                    if toastFn then
                        toastFn("Hazard blocked · position restored", Color3.fromRGB(255, 185, 70))
                    end
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
                            if Humanoid.Health < Humanoid.MaxHealth then
                                Humanoid.Health = Humanoid.MaxHealth
                            end
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

    local function disableGodMode()
        Config.GodMode = false

        if GodConn then GodConn:Disconnect() GodConn = nil end
        if GodAntiTPConn then GodAntiTPConn:Disconnect() GodAntiTPConn = nil end

        GodLastCF, GodLastSafeCF = nil, nil
        GodForceUntil = 0

        if Humanoid then
            pcall(function()
                Humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
            end)
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

        if Config.BoostActive and Humanoid then
            Humanoid.WalkSpeed = Config.Speed
        end
        if Config.InvisActive then
            task.wait(0.3)
            enableInvisibility()
        end
        if Config.FpsBoost then
            task.wait(0.2)
            enableFpsBoost()
        end
        if Config.GodMode then
            task.wait(0.25)
            enableGodMode()
        end
        if Config.PickupESP then
            task.defer(function()
                if _G.GhostRefreshESP then _G.GhostRefreshESP() end
            end)
        end
    end)

    local function stopPlayerLock()
        if LockConn then LockConn:Disconnect() LockConn = nil end
        LockTarget = nil

        if Humanoid then
            pcall(function()
                Humanoid:ChangeState(Enum.HumanoidStateType.Running)
            end)
        end
    end

    local function simulateClick()
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

    local function startPlayerLock(targetPlayer, mode)
        stopPlayerLock()
        LockTarget = targetPlayer
        LockMode   = mode or "follow"

        local attackTimer = 0
        LockConn = RunService.Heartbeat:Connect(function(dt)
            if not LockTarget or not Root or not Humanoid then return end

            local targetChar = LockTarget.Character
            if not targetChar then return end

            local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
            local targetHumanoid = targetChar:FindFirstChildOfClass("Humanoid")
            if not targetRoot then return end
            if targetHumanoid and targetHumanoid.Health <= 0 then return end

            local myPos     = Root.Position
            local targetPos = targetRoot.Position
            local distance  = (targetPos - myPos).Magnitude

            if distance > 3 then
                local direction = (targetPos - myPos).Unit
                local newPos    = myPos + direction * math.min(distance - 3, 4)
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

    local function iconBar(parent, width, height, color)
        local frame = createInstance("Frame", {
            Size = UDim2.new(0, width, 0, height),
            Position = UDim2.new(0.5, -width / 2, 0.5, -height / 2),
            BackgroundColor3 = color or Theme.TextDim,
            BorderSizePixel = 0,
            Parent = parent,
        })
        addCorner(frame, 1)
        return frame
    end

    local function iconX(parent, size, color)
        color = color or Theme.TextDim
        size  = size or 10

        local holder = createInstance("Frame", {
            Size = UDim2.new(0, size, 0, size),
            Position = UDim2.new(0.5, -size / 2, 0.5, -size / 2),
            BackgroundTransparency = 1,
            Parent = parent,
        })

        for _, rotation in ipairs({45, -45}) do
            local bar = createInstance("Frame", {
                Size = UDim2.new(1, 0, 0, 2),
                Position = UDim2.new(0, 0, 0.5, -1),
                BackgroundColor3 = color,
                BorderSizePixel = 0,
                Rotation = rotation,
                Parent = holder,
            })
            addCorner(bar, 1)
        end
        return holder
    end

    local function iconPlus(parent, size, color)
        color = color or Theme.Accent
        size  = size or 12

        local holder = createInstance("Frame", {
            Size = UDim2.new(0, size, 0, size),
            Position = UDim2.new(0.5, -size / 2, 0.5, -size / 2),
            BackgroundTransparency = 1,
            Parent = parent,
        })

        local horizontal = createInstance("Frame", {
            Size = UDim2.new(1, 0, 0, 2),
            Position = UDim2.new(0, 0, 0.5, -1),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Parent = holder,
        })
        addCorner(horizontal, 1)

        local vertical = createInstance("Frame", {
            Size = UDim2.new(0, 2, 1, 0),
            Position = UDim2.new(0.5, -1, 0, 0),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Parent = holder,
        })
        addCorner(vertical, 1)

        return holder
    end

    local function setIconColoim,
    Font = Theme.FontMedium,
    TextSize = 12,
    AutoButtonColor = false,
    Parent = travelPill,
})
addCorner(walkPill, 7)

local function setTravelMode(mode)
    Config.TravelMode = mode
    stopWalk()

    local isTeleport = mode == "teleport"
    TweenService:Create(teleportPill, TweenInfo.new(0.15), {
        BackgroundColor3 = isTeleport and Theme.Accent or Theme.Input,
        TextColor3       = isTeleport and Theme.Text or Theme.TextDim,
    }):Play()
    TweenService:Create(walkPill, TweenInfo.new(0.15), {
        BackgroundColor3 = (not isTeleport) and Theme.Accent or Theme.Input,
        TextColor3       = (not isTeleport) and Theme.Text or Theme.TextDim,
    }):Play()

    if toastFn then
        toastFn("Mode: " .. (isTeleport and "Teleport" or "Walk"), Theme.Accent)
    end
end

teleportPill.MouseButton1Click:Connect(function() setTravelMode("teleport") end)
walkPill.MouseButton1Click:Connect(function() setTravelMode("walk") end)

createNumberRow(PageTravel, {
    name = "Return Delay",
    desc = "Seconds before return after steal",
    order = 3,
    value = tostring(Config.ReturnDelay),
    callback = function(value) Config.ReturnDelay = value end,
})

createSection(PageTravel, "Free Cam", 4)

createToggleRow(PageTravel, {
    name = "Free Cam",
    desc = "Fly camera to scout · then Save position",
    order = 5,
    callback = function(state) toggleFreeCam(state) end,
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

local freeCamTip = createInstance("Frame", {
    Size = UDim2.new(1, 0, 0, 52),
    BackgroundColor3 = Theme.Card,
    BorderSizePixel = 0,
    LayoutOrder = 6,
    Parent = PageTravel,
})
addCorner(freeCamTip, 12)

createInstance("TextLabel", {
    Size = UDim2.new(1, -24, 1, -12),
    Position = UDim2.new(0, 12, 0, 6),
    BackgroundTransparency = 1,
    Text = "Phone: joystick + drag look + ▲▼ buttons\nPC: WASD · RMB look · E/Q up/down · Exit anytime",
    TextColor3 = Theme.TextMute,
    Font = Theme.Font,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    Parent = freeCamTip,
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

local savedRows = {}

local function refreshLocations()
    for _, row in ipairs(savedRows) do row:Destroy() end
    savedRows = {}

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

        local statusText = "Manual only"
        if data.onSteal then
            statusText = data.returnAfter and "Steal → Home → Back" or "Steal → Home"
        end

        createInstance("TextLabel", {
            Size = UDim2.new(1, -150, 0, 14),
            Position = UDim2.new(0, 28, 0, 30),
            BackgroundTransparency = 1,
            Text = statusText,
            TextColor3 = data.onSteal and Theme.Success or Theme.TextMute,
            Font = Theme.Font,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row,
        })

        local function makeChip(text, xOffset, bgColor)
            local chip = createInstance("TextButton", {
                Size = UDim2.new(0, 26, 0, 22),
                Position = UDim2.new(1, xOffset, 0.5, -11),
                BackgroundColor3 = bgColor,
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

        local autoBtn   = makeChip("A", -94, data.onSteal and Theme.Success or Theme.Off)
        local returnBtn = makeChip("R", -64, data.returnAfter and Theme.Accent or Theme.Off)
        returnBtn.Visible = data.onSteal

        local deleteBtn = createInstance("TextButton", {
            Size = UDim2.new(0, 26, 0, 22),
            Position = UDim2.new(1, -34, 0.5, -11),
            BackgroundColor3 = Theme.Off,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            Parent = row,
        })
        addCorner(deleteBtn, 6)
        local deleteIcon = iconX(deleteBtn, 9, Theme.TextDim)

        autoBtn.MouseButton1Click:Connect(function()
            data.onSteal = not data.onSteal
            if not data.onSteal then data.returnAfter = false end
            refreshLocations()
        end)

        returnBtn.MouseButton1Click:Connect(function()
            data.returnAfter = not data.returnAfter
            refreshLocations()
        end)

        deleteBtn.MouseButton1Click:Connect(function()
            SavedPoints[name] = nil
            refreshLocations()
            if toastFn then toastFn("Removed: " .. name, Theme.Danger) end
        end)

        deleteBtn.MouseEnter:Connect(function()
            TweenService:Create(deleteBtn, TweenInfo.new(0.1), { BackgroundColor3 = Theme.Danger }):Play()
            setIconColor(deleteIcon, Theme.Text)
        end)
        deleteBtn.MouseLeave:Connect(function()
            TweenService:Create(deleteBtn, TweenInfo.new(0.1), { BackgroundColor3 = Theme.Off }):Play()
            setIconColor(deleteIcon, Theme.TextDim)
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

        table.insert(savedRows, row)
    end
end

local addLocationBtn = createInstance("TextButton", {
    Size = UDim2.new(1, 0, 0, 44),
    BackgroundColor3 = Theme.Card,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
    LayoutOrder = 8,
    Parent = PageTravel,
})
addCorner(addLocationBtn, 12)

local addIconBg = createInstance("Frame", {
    Size = UDim2.new(0, 26, 0, 26),
    Position = UDim2.new(0, 12, 0.5, -13),
    BackgroundColor3 = Theme.Accent,
    BorderSizePixel = 0,
    Parent = addLocationBtn,
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
    Parent = addLocationBtn,
})

addLocationBtn.MouseEnter:Connect(function()
    TweenService:Create(addLocationBtn, TweenInfo.new(0.12), { BackgroundColor3 = Theme.CardHover }):Play()
end)
addLocationBtn.MouseLeave:Connect(function()
    TweenService:Create(addLocationBtn, TweenInfo.new(0.12), { BackgroundColor3 = Theme.Card }):Play()
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

    local autoOn, returnOn = false, false

    local function makePopupToggle(y, label)
        local frame = createInstance("Frame", {
            Size = UDim2.new(1, -28, 0, 36),
            Position = UDim2.new(0, 14, 0, y),
            BackgroundColor3 = Theme.Card,
            BorderSizePixel = 0,
            ZIndex = 42,
            Parent = popup,
        })
        addCorner(frame, 9)

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
            Parent = frame,
        })

        local toggle = createInstance("TextButton", {
            Size = UDim2.new(0, 38, 0, 20),
            Position = UDim2.new(1, -48, 0.5, -10),
            BackgroundColor3 = Theme.Off,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 43,
            Parent = frame,
        })
        addCorner(toggle, 10)

        local knob = createInstance("Frame", {
            Size = UDim2.new(0, 16, 0, 16),
            Position = UDim2.new(0, 2, 0.5, -8),
            BackgroundColor3 = Theme.Text,
            BorderSizePixel = 0,
            ZIndex = 44,
            Parent = toggle,
        })
        addCorner(knob, 8)

        return toggle, knob
    end

    local autoToggle, autoKnob       = makePopupToggle(94, "Auto on steal")
    local returnToggle, returnKnob   = makePopupToggle(140, "Return after")

    autoToggle.MouseButton1Click:Connect(function()
        autoOn = not autoOn
        TweenService:Create(autoToggle, TweenInfo.new(0.15), {
            BackgroundColor3 = autoOn and Theme.Success or Theme.Off,
        }):Play()
        TweenService:Create(autoKnob, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = autoOn and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
        }):Play()
    end)

    returnToggle.MouseButton1Click:Connect(function()
        returnOn = not returnOn
        TweenService:Create(returnToggle, TweenInfo.new(0.15), {
            BackgroundColor3 = returnOn and Theme.Accent or Theme.Off,
        }):Play()
        TweenService:Create(returnKnob, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = returnOn and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
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
            local camera = Workspace.CurrentCamera
            if camera then
                saveCF = CFrame.new(camera.CFrame.Position)
            end
        end
        if not saveCF and Root then
            saveCF = Root.CFrame
        end
        if not saveCF then return end

        SavedPoints[name] = {
            cframe      = saveCF,
            onSteal     = autoOn,
            returnAfter = autoOn and returnOn,
        }

        refreshLocations()

        local source = Config.FreeCam and " (free cam)" or ""
        if toastFn then toastFn("Saved: " .. name .. source, Theme.Success) end
        closePopup()
    end

    saveBtn.MouseButton1Click:Connect(saveLocation)
    nameInput.FocusLost:Connect(function(enterPressed)
        if enterPressed then saveLocation() end
    end)
    cancelBtn.MouseButton1Click:Connect(closePopup)
    overlay.MouseButton1Click:Connect(closePopup)
end

addLocationBtn.MouseButton1Click:Connect(openAddLocation)

-- ============================================================
-- PICKUP SYSTEM
-- ============================================================
local PickupConn      = nil
local PickupCount     = 0
local PickupModeAll   = true
local SelectedItems   = {}
local ScannedItems    = {}
local PickupFilterText = ""
local PickupListRows  = {}
local refreshPickupList
local PickupTraveling = false

local function firePrompt(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") then return false end
    if not prompt.Enabled then return false end

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

local function tryTouchPickup(part)
    if not part or not part:IsA("BasePart") or not Root then return end

    pcall(function()
        if firetouchinterest then
            firetouchinterest(part, Root, 0)
            firetouchinterest(part, Root, 1)
        end
    end)

    pcall(function()
        if part.Anchored == false then
            part.CFrame = Root.CFrame
        end
    end)
end

local function itemAllowed(name)
    if PickupModeAll then return true end
    return SelectedItems[name] == true
end

local function getItemPosition(object)
    if object:IsA("BasePart") then return object.Position end

    if object:IsA("Model") then
        local ok, pivot = pcall(function() return object:GetPivot().Position end)
        if ok then return pivot end
    end

    if object:IsA("ProximityPrompt") and object.Parent then
        return getItemPosition(object.Parent)
    end

    if object:IsA("Tool") then
        local handle = object:FindFirstChild("Handle")
        if handle then return handle.Position end
    end

    return nil
end

local function travelToPickup(targetPos, label)
    if not targetPos or not Root then return false end

    local targetCF = CFrame.new(targetPos)
    targetCF = CFrame.new(targetPos, Vector3.new(Root.Position.X, targetPos.Y, Root.Position.Z))
    return travelTo(targetCF, label)
end

local function scanServerItems()
    local itemMap = {}

    local function addItem(name, kind)
        if not name or name == "" then return end
        if not itemMap[name] then
            itemMap[name] = { count = 0, kind = kind or "Item" }
        end
        itemMap[name].count = itemMap[name].count + 1
    end

    for _, object in ipairs(Workspace:GetDescendants()) do
        if object:IsA("ProximityPrompt") and object.Enabled then
            local name = object.ObjectText ~= "" and object.ObjectText
                or (object.ActionText ~= "" and object.ActionText)
                or (object.Parent and object.Parent.Name)
                or "Prompt"
            addItem(name, "Prompt")
        elseif object:IsA("Tool") and object.Parent == Workspace then
            addItem(object.Name, "Tool")
        end
    end

    for _, object in ipairs(Workspace:GetChildren()) do
        if object:IsA("BasePart") or object:IsA("Model") then
            local lowerName = string.lower(object.Name)
            if string.find(lowerName, "coin")
            or string.find(lowerName, "gem")
            or string.find(lowerName, "cash")
            or string.find(lowerName, "pickup")
            or string.find(lowerName, "item")
            or string.find(lowerName, "orb")
            or string.find(lowerName, "token")
            or string.find(lowerName, "loot")
            or string.find(lowerName, "drop")
            or string.find(lowerName, "chest")
            or string.find(lowerName, "bag")
            or string.find(lowerName, "crate") then
                addItem(object.Name, "Drop")
            end
        end
    end

    ScannedItems = {}
    for name, data in pairs(itemMap) do
        table.insert(ScannedItems, { name = name, count = data.count, kind = data.kind })
    end

    table.sort(ScannedItems, function(a, b)
        return a.name:lower() < b.name:lower()
    end)

    return #ScannedItems
end

local function collectNearbyDirect()
    if not Root or not Root.Parent then return 0 end

    local origin = Root.Position
    local range  = tonumber(Config.PickupRange) or 20
    local found  = 0

    for _, object in ipairs(Workspace:GetDescendants()) do
        if object:IsA("ProximityPrompt") and object.Enabled then
            local name = object.ObjectText ~= "" and object.ObjectText
                or (object.ActionText ~= "" and object.ActionText)
                or (object.Parent and object.Parent.Name)
                or "Prompt"

            if itemAllowed(name) then
                local position = getItemPosition(object)
                if position and (position - origin).Magnitude <= range then
                    if firePrompt(object) then found = found + 1 end
                end
            end
        end
    end

    for _, object in ipairs(Workspace:GetChildren()) do
        if object:IsA("Tool") then
            if itemAllowed(object.Name) then
                local handle = object:FindFirstChild("Handle")
                if handle and handle:IsA("BasePart")
                and (handle.Position - origin).Magnitude <= range then
                    tryTouchPickup(handle)
                    pcall(function()
                        if LocalPlayer.Character then
                            object.Parent = LocalPlayer.Character
                        end
                    end)
                    found = found + 1
                end
            end
        elseif object:IsA("BasePart") or object:IsA("Model") then
            if itemAllowed(object.Name) then
                local position = getItemPosition(object)
                if position and (position - origin).Magnitude <= range then
                    local part = object:IsA("BasePart") and object
                        or object:FindFirstChildWhichIsA("BasePart", true)
                    if part then tryTouchPickup(part) end
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
    local best, bestDistance = nil, math.huge

    for _, object in ipairs(Workspace:GetDescendants()) do
        if object:IsA("ProximityPrompt") and object.Enabled then
            local name = object.ObjectText ~= "" and object.ObjectText
                or (object.ActionText ~= "" and object.ActionText)
                or (object.Parent and object.Parent.Name)
                or "Prompt"

            if itemAllowed(name) then
                local position = getItemPosition(object)
                if position then
                    local distance = (position - origin).Magnitude
                    if distance < bestDistance then
                        bestDistance = distance
                        best = { object = object, position = position, name = name, kind = "Prompt" }
                    end
                end
            end
        end
    end

    for _, object in ipairs(Workspace:GetChildren()) do
        if object:IsA("Tool") then
            if itemAllowed(object.Name) then
                local handle = object:FindFirstChild("Handle")
                if handle and handle:IsA("BasePart") then
                    local distance = (handle.Position - origin).Magnitude
                    if distance < bestDistance then
                        bestDistance = distance
                        best = { object = object, position = handle.Position, name = object.Name, kind = "Tool" }
                    end
                end
            end
        end
    end

    for _, object in ipairs(Workspace:GetChildren()) do
        if object:IsA("BasePart") or object:IsA("Model") then
            local lowerName = string.lower(object.Name)
            if string.find(lowerName, "coin")
            or string.find(lowerName, "gem")
            or string.find(lowerName, "cash")
            or string.find(lowerName, "pickup")
            or string.find(lowerName, "item")
            or string.find(lowerName, "orb")
            or string.find(lowerName, "token")
            or string.find(lowerName, "loot")
            or string.find(lowerName, "drop")
            or string.find(lowerName, "chest")
            or string.find(lowerName, "bag")
            or string.find(lowerName, "crate") then
                if itemAllowed(object.Name) then
                    local position = getItemPosition(object)
                    if position then
                        local distance = (position - origin).Magnitude
                        if distance < bestDistance then
                            bestDistance = distance
                            best = { object = object, position = position, name = object.Name, kind = "Drop" }
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
        local range    = tonumber(Config.PickupRange) or 20
        local limit    = tonumber(Config.PickupLimit) or 0

        if limit > 0 and Config.PickupCount >= limit then
            task.wait(Config.PickupWaitAfterLimit)

            if Config.AutoPickup then
                Config.PickupCount = 0
                PickupCount = 0
                if toastFn then
                    toastFn("Pickup limit reached · resetting cycle", Theme.Accent)
                end
            end
            task.wait(waitTime)
            continue
        end

        local direct = 0
        pcall(function() direct = collectNearbyDirect() end)
        if direct > 0 then
            PickupCount = PickupCount + direct
            Config.PickupCount = Config.PickupCount + direct
        end

        if not PickupTraveling and Root and Root.Parent then
            local closest = findClosestItem()
            if closest then
                local distance = (closest.position - Root.Position).Magnitude
                if distance > range then
                    PickupTraveling = true
                    local label = "pickup: " .. closest.name

                    task.spawn(function()
                        local success = travelToPickup(closest.position, label)
                        if success then
                            task.wait(0.1)

                            if closest.kind == "Prompt" then
                                pcall(function() firePrompt(closest.object) end)
                            elseif closest.kind == "Tool" then
                                local handle = closest.object:FindFirstChild("Handle")
                                if handle then
                                    pcall(function() tryTouchPickup(handle) end)
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
                                    pcall(function() tryTouchPickup(part) end)
                                end
                            end

                            PickupCount = PickupCount + 1
                            Config.PickupCount = Config.PickupCount + 1
                        end

                        PickupTraveling = false
                    end)
                end
            end
        end

        task.wait(waitTime)
    end
    PickupConn = nil
end

local function startAutoPickup()
    if PickupConn then return end
    Config.PickupCount = 0
    PickupCount = 0
    PickupConn = true
    task.spawn(pickupLoop)
end

local function stopAutoPickup()
    Config.AutoPickup = false
    PickupConn = nil
    PickupTraveling = false
    stopWalk()
end

-- ============================================================
-- PICKUP ESP
-- ============================================================
local ESPFolder = nil
local ESPItems  = {}   -- [object] = { billboard = ..., label = ..., conn = ... }
local ESPLoopRunning = false

local function shouldESP(name)
    if not Config.PickupESP then return false end
    if Config.PickupESPSelected and not SelectedItems[name] then
        return false
    end
    return itemAllowed(name)
end

local function resolveAdornee(object)
    if object:IsA("BasePart") then
        return object
    elseif object:IsA("Model") then
        return object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart", true)
    elseif object:IsA("Tool") then
        return object:FindFirstChild("Handle")
    elseif object:IsA("ProximityPrompt") then
        local parent = object.Parent
        if parent and parent:IsA("BasePart") then
            return parent
        elseif parent and parent:IsA("Model") then
            return parent.PrimaryPart or parent:FindFirstChildWhichIsA("BasePart", true)
        elseif parent and parent:IsA("Attachment") then
            return parent.Parent
        end
    end
    return nil
end

local function attachESP(object, name)
    if ESPItems[object] then
        local data = ESPItems[object]
        if data.label and data.label.Text ~= name then
            data.label.Text = name
        end
        return
    end

    local adornee = resolveAdornee(object)
    if not adornee then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "GhostESP"
    billboard.Adornee = adornee
    billboard.Size = UDim2.new(0, 160, 0, 30)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.MaxDistance = 500
    billboard.Parent = ESPFolder or Workspace

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Config.PickupESPColor
    label.TextStrokeTransparency = 0.3
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.Parent = billboard

    local cleanupConn
    cleanupConn = object.AncestryChanged:Connect(function()
        if not object:IsDescendantOf(game) then
            if billboard.Parent then billboard:Destroy() end
            if cleanupConn then cleanupConn:Disconnect() end
            ESPItems[object] = nil
        end
    end)

    ESPItems[object] = {
        billboard = billboard,
        label     = label,
        conn      = cleanupConn,
    }
end

local function scanESP()
    if not Config.PickupESP then return end

    for _, object in ipairs(Workspace:GetDescendants()) do
        if object:IsA("ProximityPrompt") and object.Enabled then
            local name = object.ObjectText ~= "" and object.ObjectText
                or (object.ActionText ~= "" and object.ActionText)
                or (object.Parent and object.Parent.Name)
                or "Prompt"
            if shouldESP(name) then
                attachESP(object, name)
            end
        elseif object:IsA("Tool") and object.Parent == Workspace then
            if shouldESP(object.Name) then
                attachESP(object, object.Name)
            end
        end
    end

    for _, object in ipairs(Workspace:GetChildren()) do
        if object:IsA("BasePart") or object:IsA("Model") then
            local lowerName = string.lower(object.Name)
            if string.find(lowerName, "coin")
            or string.find(lowerName, "gem")
            or string.find(lowerName, "cash")
            or string.find(lowerName, "pickup")
            or string.find(lowerName, "item")
            or string.find(lowerName, "orb")
            or string.find(lowerName, "token")
            or string.find(lowerName, "loot")
            or string.find(lowerName, "drop")
            or string.find(lowerName, "chest")
            or string.find(lowerName, "bag")
            or string.find(lowerName, "crate") then
                if shouldESP(object.Name) then
                    attachESP(object, object.Name)
                end
            end
        end
    end
end

local function clearESP()
    for object, data in pairs(ESPItems) do
        if data.billboard and data.billboard.Parent then
            data.billboard:Destroy()
        end
        if data.conn then
            pcall(function() data.conn:Disconnect() end)
        end
    end
    ESPItems = {}

    if ESPFolder then
        ESPFolder:Destroy()
        ESPFolder = nil
    end
end

local function startPickupESP()
    clearESP()

    ESPFolder = Instance.new("Folder")
    ESPFolder.Name = "GhostESPItems"
    ESPFolder.Parent = Workspace

    scanESP()

    if not ESPLoopRunning then
        ESPLoopRunning = true
        task.spawn(function()
            while true do
                if Config.PickupESP then
                    scanESP()
                    task.wait(0.5)
                else
                    ESPLoopRunning = false
                    break
                end
            end
        end)
    end
end

local function stopPickupESP()
    Config.PickupESP = false
    clearESP()
end

local function refreshESP()
    if Config.PickupESP then
        startPickupESP()
    end
end

_G.GhostRefreshESP = refreshESP

createSection(PagePickup, "Auto Pickup", 1)

createToggleRow(PagePickup, {
    name = "Auto Pickup",
    desc = "Travel (Teleport/Walk) + collect items in range",
    order = 2,
    callback = function(state)
        Config.AutoPickup = state
        if state then
            startAutoPickup()
            if toastFn then
                local mode = Config.TravelMode == "walk" and "Walking" or "Teleporting"
                toastFn("Auto Pickup ON · " .. mode, Theme.Success)
            end
        else
            stopAutoPickup()
            if toastFn then toastFn("Auto Pickup OFF", Theme.TextDim) end
        end
    end,
})

createToggleRow(PagePickup, {
    name = "Pickup ESP",
    desc = "Show item names floating in the world",
    order = 3,
    callback = function(state)
        Config.PickupESP = state
        if state then
            startPickupESP()
            if toastFn then toastFn("Pickup ESP ON", Theme.Success) end
        else
            stopPickupESP()
            if toastFn then toastFn("Pickup ESP OFF", Theme.TextDim) end
        end
    end,
})

createToggleRow(PagePickup, {
    name = "ESP: Selected only",
    desc = "Only show names for items you checked below",
    order = 4,
    callback = function(state)
        Config.PickupESPSelected = state
        refreshESP()
        if toastFn then
            toastFn(state and "ESP: selected only" or "ESP: all items", Theme.Accent)
        end
    end,
})

createNumberRow(PagePickup, {
    name = "Pickup Range",
    desc = "Studs around player (radius)",
    order = 5,
    value = tostring(Config.PickupRange),
    callback = function(value)
        Config.PickupRange = value
        if toastFn then toastFn("Pickup range: " .. tostring(value), Theme.Accent) end
    end,
})

createNumberRow(PagePickup, {
    name = "Scan Delay",
    desc = "Seconds between each scan",
    order = 6,
    value = tostring(Config.PickupDelay),
    callback = function(value)
        Config.PickupDelay = math.max(0.05, value)
    end,
})

createNumberRow(PagePickup, {
    name = "Pickup Limit",
    desc = "Items per cycle (0 = unlimited)",
    order = 7,
    value = tostring(Config.PickupLimit),
    callback = function(value)
        Config.PickupLimit = math.max(0, math.floor(value))
        Config.PickupCount = 0
        PickupCount = 0
        if toastFn then
            if Config.PickupLimit == 0 then
                toastFn("Pickup limit: UNLIMITED", Theme.Accent)
            else
                toastFn("Pickup limit: " .. tostring(Config.PickupLimit) .. " per cycle", Theme.Accent)
            end
        end
    end,
})

local pickupModeCard = createInstance("Frame", {
    Size = UDim2.new(1, 0, 0, 70),
    BackgroundColor3 = Theme.Card,
    BorderSizePixel = 0,
    LayoutOrder = 8,
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

local allItemsPill = createInstance("TextButton", {
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
addCorner(allItemsPill, 7)

local selectedPill = createInstance("TextButton", {
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
addCorner(selectedPill, 7)

local function setPickupMode(allMode)
    PickupModeAll = allMode
    TweenService:Create(allItemsPill, TweenInfo.new(0.15), {
        BackgroundColor3 = allMode and Theme.Accent or Theme.Input,
        TextColor3       = allMode and Theme.Text or Theme.TextDim,
    }):Play()
    TweenService:Create(selectedPill, TweenInfo.new(0.15), {
        BackgroundColor3 = (not allMode) and Theme.Accent or Theme.Input,
        TextColor3       = (not allMode) and Theme.Text or Theme.TextDim,
    }):Play()

    if toastFn then
        toastFn(allMode and "Pickup: ALL items" or "Pickup: SELECTED only", Theme.Accent)
    end

    refreshESP()
end

allItemsPill.MouseButton1Click:Connect(function() setPickupMode(true) end)
selectedPill.MouseButton1Click:Connect(function() setPickupMode(false) end)

createSection(PagePickup, "Server items", 9)

local filterCard = createInstance("Frame", {
    Size = UDim2.new(1, 0, 0, 44),
    BackgroundColor3 = Theme.Card,
    BorderSizePixel = 0,
    LayoutOrder = 10,
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

filterBox:GetPropertyChangedSignal("Text"):Connect(function()
    PickupFilterText = filterBox.Text
    if refreshPickupList then refreshPickupList() end
end)

local selectRow = createInstance("Frame", {
    Size = UDim2.new(1, 0, 0, 36),
    BackgroundTransparency = 1,
    LayoutOrder = 11,
    Parent = PagePickup,
})

local selectAllBtn = createInstance("TextButton", {
    Size = UDim2.new(0.5, -4, 1, 0),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = Theme.Card,
    BorderSizePixel = 0,
    Text = "Select all",
    TextColor3 = Theme.Text,
    Font = Theme.FontMedium,
    TextSize = 12,
    AutoButtonColor = false,
    Parent = selectRow,
})
addCorner(selectAllBtn, 10)

local clearSelectBtn = createInstance("TextButton", {
    Size = UDim2.new(0.5, -4, 1, 0),
    Position = UDim2.new(0.5, 4, 0, 0),
    BackgroundColor3 = Theme.Card,
    BorderSizePixel = 0,
    Text = "Clear select",
    TextColor3 = Theme.TextDim,
    Font = Theme.FontMedium,
    TextSize = 12,
    AutoButtonColor = false,
    Parent = selectRow,
})
addCorner(clearSelectBtn, 10)

local itemListHolder = createInstance("Frame", {
    Size = UDim2.new(1, 0, 0, 0),
    BackgroundTransparency = 1,
    AutomaticSize = Enum.AutomaticSize.Y,
    LayoutOrder = 12,
    Parent = PagePickup,
})
addVerticalList(itemListHolder, 6)

refreshPickupList = function()
    for _, row in ipairs(PickupListRows) do row:Destroy() end
    PickupListRows = {}

    local filter = string.lower(PickupFilterText or "")
    local order = 1

    for _, item in ipairs(ScannedItems) do
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

            local isChecked = SelectedItems[item.name] == true

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
                if SelectedItems[item.name] then
                    SelectedItems[item.name] = nil
                else
                    SelectedItems[item.name] = true
                    setPickupMode(false)
                end
                refreshPickupList()
                refreshESP()
            end)

            table.insert(PickupListRows, row)
        end
    end
end

scanBtn.MouseButton1Click:Connect(function()
    local count = scanServerItems()
    refreshPickupList()
    refreshESP()
    if toastFn then
        toastFn("Scanned " .. tostring(count) .. " item types", Theme.Success)
    end
end)

selectAllBtn.MouseButton1Click:Connect(function()
    for _, item in ipairs(ScannedItems) do
        SelectedItems[item.name] = true
    end
    setPickupMode(false)
    refreshPickupList()
    refreshESP()
    if toastFn then toastFn("Selected all scanned items", Theme.Accent) end
end)

clearSelectBtn.MouseButton1Click:Connect(function()
    SelectedItems = {}
    refreshPickupList()
    refreshESP()
    if toastFn then toastFn("Selection cleared", Theme.TextDim) end
end)

local pickupStatusCard = createInstance("Frame", {
    Size = UDim2.new(1, 0, 0, 56),
    BackgroundColor3 = Theme.Card,
    BorderSizePixel = 0,
    LayoutOrder = 13,
    Parent = PagePickup,
})
addCorner(pickupStatusCard, 12)

createInstance("TextLabel", {
    Size = UDim2.new(1, -20, 0, 16),
    Position = UDim2.new(0, 14, 0, 10),
    BackgroundTransparency = 1,
    Text = "Status",
    TextColor3 = Theme.TextMute,
    Font = Theme.Font,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = pickupStatusCard,
})

local pickupStatusValue = createInstance("TextLabel", {
    Size = UDim2.new(1, -20, 0, 18),
    Position = UDim2.new(0, 14, 0, 28),
    BackgroundTransparency = 1,
    Text = "OFF · range " .. tostring(Config.PickupRange),
    TextColor3 = Theme.TextDim,
    Font = Theme.FontBold,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = pickupStatusCard,
})

task.spawn(function()
    while pickupStatusCard and pickupStatusCard.Parent do
        local mode   = PickupModeAll and "ALL" or "SELECTED"
        local travel = Config.TravelMode == "walk" and "walk" or "tp"
        local limitText = Config.PickupLimit > 0
            and ("[" .. tostring(Config.PickupCount) .. "/" .. tostring(Config.PickupLimit) .. "]")
            or ""

        if Config.AutoPickup then
            pickupStatusValue.Text = "ON · " .. mode .. " · " .. travel
                .. " · r" .. tostring(Config.PickupRange) .. " · ~" .. tostring(PickupCount)
                .. " " .. limitText
            pickupStatusValue.TextColor3 = Theme.Success
        else
            pickupStatusValue.Text = "OFF · " .. mode .. " · r" .. tostring(Config.PickupRange)
            pickupStatusValue.TextColor3 = Theme.TextDim
        end

        task.wait(0.5)
    end
end)

createSection(PagePlayers, "Online", 1)

local playersHolder = createInstance("Frame", {
    Size = UDim2.new(1, 0, 0, 0),
    BackgroundTransparency = 1,
    AutomaticSize = Enum.AutomaticSize.Y,
    LayoutOrder = 2,
    Parent = PagePlayers,
})
addVerticalList(playersHolder, 8)

local playerRows = {}

local function refreshPlayers()
    for _, row in ipairs(playerRows) do row:Destroy() end
    playerRows = {}

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

            table.insert(playerRows, row)
        end
    end
end

refreshPlayers()
Players.PlayerAdded:Connect(function()
    task.wait(0.4)
    refreshPlayers()
end)
Players.PlayerRemoving:Connect(function(player)
    if LockTarget == player then stopPlayerLock() end
    task.wait(0.2)
    refreshPlayers()
end)

local ScriptLogLines = {}
local SCRIPT_LOG_MAX = 200
local ScriptRunning  = false
local refreshScriptLog

local function appendScriptLog(message, color)
    color = color or Theme.Text

    local now     = tick()
    local seconds = math.floor(now % 60)
    local minutes = math.floor((now / 60) % 60)
    local hours   = math.floor((now / 3600) % 24)
    local timestamp = string.format("%02d:%02d:%02d", hours, minutes, seconds)

    table.insert(ScriptLogLines, { text = "[" .. timestamp .. "] " .. tostring(message), color = color })
    if #ScriptLogLines > SCRIPT_LOG_MAX then
        table.remove(ScriptLogLines, 1)
    end

    if refreshScriptLog then refreshScriptLog() end
end

local function clearScriptLog()
    ScriptLogLines = {}
    if refreshScriptLog then refreshScriptLog() end
end

local function getScriptLogText()
    local parts = {}
    for _, entry in ipairs(ScriptLogLines) do
        table.insert(parts, entry.text)
    end
    return table.concat(parts, "\n")
end

local function copyToClipboard(text)
    local success = false
    pcall(function()
        if setclipboard then
            setclipboard(text)
            success = true
        elseif toclipboard then
            toclipboard(text)
            success = true
        elseif writeclipboard then
            writeclipboard(text)
            success = true
        end
    end)
    return success
end

local function runCustomScript(code)
    if ScriptRunning then
        appendScriptLog("Already running a script…", Theme.Warning)
        return
    end

    if not code or code:match("^%s*$") then
        appendScriptLog("No code to run", Theme.Warning)
        return
    end

    ScriptRunning = true
    appendScriptLog("Running script…", Theme.Accent)

    local oldPrint = print
    local oldWarn  = warn

    local function capturePrint(...)
        local args = { ... }
        local parts = {}
        for i = 1, #args do
            table.insert(parts, tostring(args[i]))
        end
        local message = table.concat(parts, "\t")
        appendScriptLog(message, Theme.Text)
        oldPrint(...)
    end

    local function captureWarn(...)
        local args = { ... }
        local parts = {}
        for i = 1, #args do
            table.insert(parts, tostring(args[i]))
        end
        local message = table.concat(parts, "\t")
        appendScriptLog("[WARN] " .. message, Theme.Warning)
        oldWarn(...)
    end

    print = capturePrint
    warn  = captureWarn

    local success, result = pcall(function()
        local loader = loadstring or load
        if not loader then
            error("loadstring / load not available on this executor")
        end
        local fn, loadError = loader(code)
        if not fn then
            error(loadError or "failed to compile script")
        end
        return fn()
    end)

    print = oldPrint
    warn  = oldWarn

    if success then
        appendScriptLog("Script finished successfully", Theme.Success)
        if result ~= nil then
            appendScriptLog("Return: " .. tostring(result), Theme.Accent2)
        end
    else
        appendScriptLog("ERROR: " .. tostring(result), Theme.Danger)
    end

    ScriptRunning = false
end

createSection(PageScript, "Editor", 1)

local editorCard = createInstance("Frame", {
    Size = UDim2.new(1, 0, 0, 220),
    BackgroundColor3 = Theme.Card,
    BorderSizePixel = 0,
    LayoutOrder = 2,
    Parent = PageScript,
})
addCorner(editorCard, 12)

local codeBox = createInstance("TextBox", {
    Size = UDim2.new(1, -16, 1, -16),
    Position = UDim2.new(0, 8, 0, 8),
    BackgroundColor3 = Theme.Input,
    BorderSizePixel = 0,
    Text = "",
    PlaceholderText = "-- Paste your Lua script here…\nprint(\"Hello from Ghost Walk\")",
    PlaceholderColor3 = Theme.TextMute,
    TextColor3 = Theme.Text,
    Font = Enum.Font.Code,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    ClearTextOnFocus = false,
    MultiLine = true,
    TextWrapped = true,
    Parent = editorCard,
})
addCorner(codeBox, 8)

local scriptButtonRow = createInstance("Frame", {
    Size = UDim2.new(1, 0, 0, 36),
    BackgroundTransparency = 1,
    LayoutOrder = 3,
    Parent = PageScript,
})

local runBtn = createInstance("TextButton", {
    Size = UDim2.new(0.32, -4, 1, 0),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = Theme.Success,
    BorderSizePixel = 0,
    Text = "▶ Run",
    TextColor3 = Theme.Text,
    Font = Theme.FontBold,
    TextSize = 12,
    AutoButtonColor = false,
    Parent = scriptButtonRow,
})
addCorner(runBtn, 9)

local clearCodeBtn = createInstance("TextButton", {
    Size = UDim2.new(0.32, -4, 1, 0),
    Position = UDim2.new(0.34, 0, 0, 0),
    BackgroundColor3 = Theme.Card,
    BorderSizePixel = 0,
    Text = "Clear",
    TextColor3 = Theme.TextDim,
    Font = Theme.FontMedium,
    TextSize = 12,
    AutoButtonColor = false,
    Parent = scriptButtonRow,
})
addCorner(clearCodeBtn, 9)

local loadFileBtn = createInstance("TextButton", {
    Size = UDim2.new(0.32, -4, 1, 0),
    Position = UDim2.new(0.68, 0, 0, 0),
    BackgroundColor3 = Theme.Accent,
    BorderSizePixel = 0,
    Text = "Upload",
    TextColor3 = Theme.Text,
    Font = Theme.FontBold,
    TextSize = 12,
    AutoButtonColor = false,
    Parent = scriptButtonRow,
})
addCorner(loadFileBtn, 9)

runBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        runCustomScript(codeBox.Text)
    end)
end)

clearCodeBtn.MouseButton1Click:Connect(function()
    codeBox.Text = ""
    if toastFn then toastFn("Editor cleared", Theme.TextDim) end
end)

loadFileBtn.MouseButton1Click:Connect(function()
    if ScreenGui:FindFirstChild("LoadFilePop") then return end

    local overlay = createInstance("TextButton", {
        Name = "LoadFilePop",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.5,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 40,
        Parent = ScreenGui,
    })

    local popup = createInstance("Frame", {
        Size = UDim2.new(0, 300, 0, 180),
        Position = UDim2.new(0.5, -150, 0.5, -90),
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
        Text = "Load Script from File",
        TextColor3 = Theme.Text,
        Font = Theme.FontBold,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 42,
        Parent = popup,
    })

    createInstance("TextLabel", {
        Size = UDim2.new(1, -28, 0, 28),
        Position = UDim2.new(0, 14, 0, 40),
        BackgroundTransparency = 1,
        Text = "Enter filename (workspace folder)\ne.g. myscript.lua or scripts/test.txt",
        TextColor3 = Theme.TextMute,
        Font = Theme.Font,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = 42,
        Parent = popup,
    })

    local inputFrame = createInstance("Frame", {
        Size = UDim2.new(1, -28, 0, 34),
        Position = UDim2.new(0, 14, 0, 80),
        BackgroundColor3 = Theme.Input,
        BorderSizePixel = 0,
        ZIndex = 42,
        Parent = popup,
    })
    addCorner(inputFrame, 8)

    local fileInput = createInstance("TextBox", {
        Size = UDim2.new(1, -12, 1, 0),
        Position = UDim2.new(0, 6, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        PlaceholderText = "filename.lua",
        PlaceholderColor3 = Theme.TextMute,
        TextColor3 = Theme.Text,
        Font = Theme.FontMedium,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        ZIndex = 43,
        Parent = inputFrame,
    })
    fileInput:CaptureFocus()

    local loadBtn = createInstance("TextButton", {
        Size = UDim2.new(0.5, -20, 0, 32),
        Position = UDim2.new(0, 14, 1, -46),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Text = "Load",
        TextColor3 = Theme.Text,
        Font = Theme.FontBold,
        TextSize = 12,
        AutoButtonColor = false,
        ZIndex = 42,
        Parent = popup,
    })
    addCorner(loadBtn, 8)

    local cancelLoadBtn = createInstance("TextButton", {
        Size = UDim2.new(0.5, -20, 0, 32),
        Position = UDim2.new(0.5, 6, 1, -46),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        Text = "Cancel",
        TextColor3 = Theme.TextDim,
        Font = Theme.FontMedium,
        TextSize = 12,
        AutoButtonColor = false,
        ZIndex = 42,
        Parent = popup,
    })
    addCorner(cancelLoadBtn, 8)

    local function closePopup() overlay:Destroy() end

    local function loadFile()
        local filename = fileInput.Text
        if filename == "" then return end

        local content
        local ok, err = pcall(function()
            if readfile then
                content = readfile(filename)
            else
                error("readfile not available on this executor")
            end
        end)

        if ok and content then
            codeBox.Text = content
            appendScriptLog("Loaded file: " .. filename .. " (" .. #content .. " chars)", Theme.Success)
            if toastFn then toastFn("Loaded: " .. filename, Theme.Success) end
            closePopup()
        else
            appendScriptLog("Failed to load: " .. tostring(err), Theme.Danger)
            if toastFn then toastFn("Load failed", Theme.Danger) end
        end
    end

    loadBtn.MouseButton1Click:Connect(loadFile)
    fileInput.FocusLost:Connect(function(enterPressed)
        if enterPressed then loadFile() end
    end)
    cancelLoadBtn.MouseButton1Click:Connect(closePopup)
    overlay.MouseButton1Click:Connect(closePopup)
end)

createSection(PageScript, "Output Log", 4)

local logCard = createInstance("Frame", {
    Size = UDim2.new(1, 0, 0, 180),
    BackgroundColor3 = Theme.Card,
    BorderSizePixel = 0,
    LayoutOrder = 5,
    Parent = PageScript,
})
addCorner(logCard, 12)

local logScroll = createInstance("ScrollingFrame", {
    Size = UDim2.new(1, -12, 1, -12),
    Position = UDim2.new(0, 6, 0, 6),
    BackgroundColor3 = Theme.Input,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = Theme.Accent,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    Parent = logCard,
})
addCorner(logScroll, 8)
addPadding(logScroll, 6, 6, 6, 6)
addVerticalList(logScroll, 2)

local logLabels = {}

refreshScriptLog = function()
    for _, label in ipairs(logLabels) do
        label:Destroy()
    end
    logLabels = {}

    for i, entry in ipairs(ScriptLogLines) do
        local label = createInstance("TextLabel", {
            Size = UDim2.new(1, -4, 0, 16),
            BackgroundTransparency = 1,
            Text = entry.text,
            TextColor3 = entry.color or Theme.Text,
            Font = Enum.Font.Code,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = true,
            LayoutOrder = i,
            Parent = logScroll,
        })
        label.Size = UDim2.new(1, -4, 0, math.max(16, math.ceil(#entry.text / 45) * 14))
        table.insert(logLabels, label)
    end

    task.defer(function()
        logScroll.CanvasPosition = Vector2.new(0, logScroll.AbsoluteCanvasSize.Y)
    end)
end

local logButtonRow = createInstance("Frame", {
    Size = UDim2.new(1, 0, 0, 36),
    BackgroundTransparency = 1,
    LayoutOrder = 6,
    Parent = PageScript,
})

local clearLogBtn = createInstance("TextButton", {
    Size = UDim2.new(0.48, -4, 1, 0),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = Theme.Card,
    BorderSizePixel = 0,
    Text = "Clear Log",
    TextColor3 = Theme.TextDim,
    Font = Theme.FontMedium,
    TextSize = 12,
    AutoButtonColor = false,
    Parent = logButtonRow,
})
addCorner(clearLogBtn, 9)

local copyLogBtn = createInstance("TextButton", {
    Size = UDim2.new(0.48, -4, 1, 0),
    Position = UDim2.new(0.52, 0, 0, 0),
    BackgroundColor3 = Theme.Accent,
    BorderSizePixel = 0,
    Text = "Copy Log",
    TextColor3 = Theme.Text,
    Font = Theme.FontBold,
    TextSize = 12,
    AutoButtonColor = false,
    Parent = logButtonRow,
})
addCorner(copyLogBtn, 9)

clearLogBtn.MouseButton1Click:Connect(function()
    clearScriptLog()
    if toastFn then toastFn("Log cleared", Theme.TextDim) end
end)

copyLogBtn.MouseButton1Click:Connect(function()
    local text = getScriptLogText()
    if text == "" then
        if toastFn then toastFn("Log is empty", Theme.Warning) end
        return
    end

    if copyToClipboard(text) then
        if toastFn then toastFn("Log copied to clipboard", Theme.Success) end
    else
        if toastFn then toastFn("Clipboard not available · select text below", Theme.Warning) end
        appendScriptLog("--- COPY BELOW ---", Theme.Accent2)
        appendScriptLog(text, Theme.Text)
    end
end)

appendScriptLog("Script executor ready", Theme.Success)

do
    local savedPosition = Shell.Position
    local hidden, animating = false, false

    local function restoreContent()
        minimized = false
        TabBar.Visible = true
        Header.Visible = true
        Shell.Size = UDim2.new(0, UI_WIDTH, 0, UI_HEIGHT)
        switchTab(ActiveTab or "main")
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

        minimized = false
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

        local floatTween = TweenService:Create(FloatBtn, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 46, 0, 46),
        })
        floatTween:Play()
        floatTween.Completed:Wait()

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
        minimized = not minimized
        if minimized then
            TabBar.Visible = false
            for _, data in pairs(Pages) do data.page.Visible = false end
            TweenService:Create(Shell, TweenInfo.new(0.22), {
                Size = UDim2.new(0, UI_WIDTH, 0, 54),
            }):Play()
        else
            TabBar.Visible = true
            switchTab(ActiveTab)
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

toastFn = function(message, color)
    color = color or Theme.Accent

    local toast = createInstance("Frame", {
        Size = UDim2.new(0, 260, 0, 38),
        Position = UDim2.new(0.5, -130, 0, -48),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        ZIndex = 80,
        Parent = ScreenGui,
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
w
toastFn("Ghost Walk v9.5 · ready", Theme.Success)
