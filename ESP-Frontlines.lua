--Settings--
local ESP = {
    Enabled = false,
    Boxes = true,
    BoxShift = CFrame.new(0,-1.5,0),
    BoxSize = Vector3.new(4,6,0),
    Color = Color3.fromRGB(255, 170, 0),
    FaceCamera = false,
    Names = true,
    TeamColor = true,
    Thickness = 2,
    AttachShift = 1,
    TeamMates = true,
    Players = true,

    Objects = setmetatable({}, {__mode="kv"}),
    Overrides = {}
}

--Declarations--
local cam = workspace.CurrentCamera
local plrs = game:GetService("Players")
local plr = plrs.LocalPlayer

local WorldToViewportPoint = cam.WorldToViewportPoint

-- === Utility Functions ===
local function Draw(obj, props)
    local new = Drawing.new(obj)
    for i,v in pairs(props or {}) do
        new[i] = v
    end
    return new
end

local function IsOnScreen(pos)
    local screenPos, onScreen = cam:WorldToViewportPoint(pos)
    if not onScreen or screenPos.Z < 0 then
        return false
    end
    if screenPos.X < 0 or screenPos.X > cam.ViewportSize.X then
        return false
    end
    if screenPos.Y < 0 or screenPos.Y > cam.ViewportSize.Y then
        return false
    end
    return true
end

local function AnyPointOnScreen(points)
    for _, pos in ipairs(points) do
        if IsOnScreen(pos) then
            return true
        end
    end
    return false
end

--ESP Core--
function ESP:GetTeam(p)
    local ov = self.Overrides.GetTeam
    return ov and ov(p) or (p and p.Team)
end

function ESP:IsTeamMate(p)
    local ov = self.Overrides.IsTeamMate
    if ov then return ov(p) end
    return self:GetTeam(p) == self:GetTeam(plr)
end

function ESP:GetColor(obj)
    local ov = self.Overrides.GetColor
    if ov then return ov(obj) end
    local p = self:GetPlrFromChar(obj)
    return p and self.TeamColor and p.Team and p.Team.TeamColor.Color or self.Color
end

function ESP:GetPlrFromChar(char)
    local ov = self.Overrides.GetPlrFromChar
    return ov and ov(char) or plrs:GetPlayerFromCharacter(char)
end

function ESP:Toggle(bool)
    self.Enabled = bool
    if not bool then
        for _,v in pairs(self.Objects) do
            if v.Type == "Box" then
                if v.Temporary then
                    v:Remove()
                else
                    for _,comp in pairs(v.Components) do
                        comp.Visible = false
                    end
                end
            end
        end
    end
end

function ESP:GetBox(obj)
    return self.Objects[obj]
end

-- Box class --
local boxBase = {}
boxBase.__index = boxBase

function boxBase:Remove()
    ESP.Objects[self.Object] = nil
    for i,v in pairs(self.Components) do
        v.Visible = false
        v:Remove()
        self.Components[i] = nil
    end
end

function boxBase:Update()
    if not self.PrimaryPart then
        return self:Remove()
    end

    local color = self.Color or self.ColorDynamic and self:ColorDynamic() or ESP:GetColor(self.Object) or ESP.Color
    local allow = true

    if ESP.Overrides.UpdateAllow and not ESP.Overrides.UpdateAllow(self) then allow = false end
    if self.Player and not ESP.TeamMates and ESP:IsTeamMate(self.Player) then allow = false end
    if self.Player and not ESP.Players then allow = false end
    if self.IsEnabled and (type(self.IsEnabled)=="string" and not ESP[self.IsEnabled] or type(self.IsEnabled)=="function" and not self:IsEnabled()) then
        allow = false
    end
    if not workspace:IsAncestorOf(self.PrimaryPart) and not self.RenderInNil then
        allow = false
    end

    if not allow then
        for _,v in pairs(self.Components) do v.Visible = false end
        return
    end

    local cf = self.PrimaryPart.CFrame
    if ESP.FaceCamera then cf = CFrame.new(cf.p, cam.CFrame.p) end

    local size = self.Size
    local locs = {
        TopLeft = cf * ESP.BoxShift * CFrame.new(size.X/2,size.Y/2,0),
        TopRight = cf * ESP.BoxShift * CFrame.new(-size.X/2,size.Y/2,0),
        BottomLeft = cf * ESP.BoxShift * CFrame.new(size.X/2,-size.Y/2,0),
        BottomRight = cf * ESP.BoxShift * CFrame.new(-size.X/2,-size.Y/2,0),
        TagPos = cf * ESP.BoxShift * CFrame.new(0,size.Y/2,0),
        Torso = cf * ESP.BoxShift
    }

    -- BOX
    if ESP.Boxes then
        local points = {locs.TopLeft.p, locs.TopRight.p, locs.BottomLeft.p, locs.BottomRight.p}
        if AnyPointOnScreen(points) then
            local TopLeft = cam:WorldToViewportPoint(locs.TopLeft.p)
            local TopRight = cam:WorldToViewportPoint(locs.TopRight.p)
            local BottomLeft = cam:WorldToViewportPoint(locs.BottomLeft.p)
            local BottomRight = cam:WorldToViewportPoint(locs.BottomRight.p)

            self.Components.Quad.Visible = true
            self.Components.Quad.PointA = Vector2.new(TopRight.X, TopRight.Y)
            self.Components.Quad.PointB = Vector2.new(TopLeft.X, TopLeft.Y)
            self.Components.Quad.PointC = Vector2.new(BottomLeft.X, BottomLeft.Y)
            self.Components.Quad.PointD = Vector2.new(BottomRight.X, BottomRight.Y)
            self.Components.Quad.Color = color
        else
            self.Components.Quad.Visible = false
        end
    else
        self.Components.Quad.Visible = false
    end

    -- NAMES + DISTANCE
    if ESP.Names then
        if IsOnScreen(locs.TagPos.p) then
            local TagPos = cam:WorldToViewportPoint(locs.TagPos.p)
            self.Components.Name.Visible = true
            self.Components.Name.Position = Vector2.new(TagPos.X, TagPos.Y)
            self.Components.Name.Text = self.Name
            self.Components.Name.Color = color

            self.Components.Distance.Visible = true
            self.Components.Distance.Position = Vector2.new(TagPos.X, TagPos.Y + 14)
            self.Components.Distance.Text = math.floor((cam.CFrame.p - cf.p).magnitude).."m"
            self.Components.Distance.Color = color
        else
            self.Components.Name.Visible = false
            self.Components.Distance.Visible = false
        end
    else
        self.Components.Name.Visible = false
        self.Components.Distance.Visible = false
    end

    -- TRACERS
    if ESP.Tracers then
        if IsOnScreen(locs.Torso.p) then
            local TorsoPos = cam:WorldToViewportPoint(locs.Torso.p)
            self.Components.Tracer.Visible = true
            self.Components.Tracer.From = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/ESP.AttachShift)
            self.Components.Tracer.To = Vector2.new(TorsoPos.X, TorsoPos.Y)
            self.Components.Tracer.Color = color
        else
            self.Components.Tracer.Visible = false
        end
    else
        self.Components.Tracer.Visible = false
    end
end

function ESP:Add(obj, options)
    if not obj.Parent and not options.RenderInNil then return end

    local box = setmetatable({
        Name = options.Name or obj.Name,
        Type = "Box",
        Color = options.Color,
        Size = options.Size or self.BoxSize,
        Object = obj,
        Player = options.Player or plrs:GetPlayerFromCharacter(obj),
        PrimaryPart = options.PrimaryPart or obj.ClassName=="Model" and (obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")) or obj:IsA("BasePart") and obj,
        Components = {},
        IsEnabled = options.IsEnabled,
        Temporary = options.Temporary,
        ColorDynamic = options.ColorDynamic,
        RenderInNil = options.RenderInNil
    }, boxBase)

    if self:GetBox(obj) then self:GetBox(obj):Remove() end

    box.Components["Quad"] = Draw("Quad", {
        Thickness = self.Thickness,
        Transparency = 1,
        Filled = false,
        Visible = self.Enabled and self.Boxes
    })
    box.Components["Name"] = Draw("Text", {
        Center = true, Outline = true, Size = 19,
        Visible = self.Enabled and self.Names
    })
    box.Components["Distance"] = Draw("Text", {
        Center = true, Outline = true, Size = 19,
        Visible = self.Enabled and self.Names
    })
    box.Components["Tracer"] = Draw("Line", {
        Thickness = ESP.Thickness,
        Transparency = 1,
        Visible = self.Enabled and self.Tracers
    })

    self.Objects[obj] = box

    obj.AncestryChanged:Connect(function(_, parent)
        if parent == nil and ESP.AutoRemove ~= false then box:Remove() end
    end)
    obj:GetPropertyChangedSignal("Parent"):Connect(function()
        if obj.Parent == nil and ESP.AutoRemove ~= false then box:Remove() end
    end)

    local hum = obj:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Died:Connect(function()
            if ESP.AutoRemove ~= false then box:Remove() end
        end)
    end

    return box
end

-- Character/Player hook
local function CharAdded(char)
    local p = plrs:GetPlayerFromCharacter(char)
    if not p or p == plr then return end

    if not char:FindFirstChild("HumanoidRootPart") then
        local ev
        ev = char.ChildAdded:Connect(function(c)
            if c.Name == "HumanoidRootPart" then
                ev:Disconnect()
                ESP:Add(char, {Name = p.Name, Player = p, PrimaryPart = c})
            end
        end)
    else
        ESP:Add(char, {Name = p.Name, Player = p, PrimaryPart = char.HumanoidRootPart})
    end
end

local function PlayerAdded(p)
    p.CharacterAdded:Connect(CharAdded)
    if p.Character then CharAdded(p.Character) end
end

plrs.PlayerAdded:Connect(PlayerAdded)
for _,v in pairs(plrs:GetPlayers()) do if v ~= plr then PlayerAdded(v) end end

-- Render Loop
game:GetService("RunService").RenderStepped:Connect(function()
    cam = workspace.CurrentCamera
    for _,v in pairs(ESP.Objects) do
        if v.Update then
            local s,e = pcall(v.Update, v)
            if not s then warn("[ESP Error]", e) end
        end
    end
end)

return ESP
