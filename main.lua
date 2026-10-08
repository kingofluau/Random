-- url: https://chronix-gate.net/m?sid=81b2a57f307d8adf938f4bdf4f0ba9eb856c7be6a3ba2563&n=main&z=145536447x105
local MYTOKEN = {}
local GENV = (type(getgenv) == "function" and getgenv()) or _G
if GENV.Topaz and GENV.Topaz.destroy then
    pcall(GENV.Topaz.destroy)
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local LP = Players.LocalPlayer

local EXEC = "Unknown"
pcall(function() if type(identifyexecutor) == "function" then EXEC = tostring((identifyexecutor())) end end)
local EXEC_LO = string.lower(EXEC)
local WEAK_EXEC = EXEC_LO:find("xeno", 1, true) ~= nil or EXEC_LO:find("solara", 1, true) ~= nil

local CACHE = GENV.ChronixCache
if type(CACHE) ~= "table" then CACHE = {} GENV.ChronixCache = CACHE end
local PKEY = tostring(game.PlaceId)
if type(CACHE[PKEY]) ~= "table" then CACHE[PKEY] = {} end
local PC = CACHE[PKEY]

local function parentGui(sg)
    local ok = pcall(function() sg.Parent = gethui and gethui() or nil end)
    if ok and sg.Parent then return true end
    ok = pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(sg) end
        sg.Parent = CoreGui
    end)
    if ok and sg.Parent then return true end
    ok = pcall(function() sg.Parent = CoreGui end)
    if ok and sg.Parent then return true end
    pcall(function() sg.Parent = LP:FindFirstChildOfClass("PlayerGui") end)
    return sg.Parent ~= nil
end

local function sweepOrphans()
    local roots = {}
    pcall(function() if gethui then table.insert(roots, gethui()) end end)
    pcall(function() table.insert(roots, CoreGui) end)
    pcall(function() table.insert(roots, LP:FindFirstChildOfClass("PlayerGui")) end)
    for _, r in ipairs(roots) do
        if r then
            pcall(function()
                for _, c in ipairs(r:GetChildren()) do
                    if c:IsA("ScreenGui") and c.Name:sub(1, 6) == "CHXTPZ" then c:Destroy() end
                end
            end)
        end
    end
end

local Prism = {}
Prism.__index = Prism

local THEME = {
    bg = Color3.fromRGB(11, 13, 18),
    panel = Color3.fromRGB(17, 20, 27),
    row = Color3.fromRGB(23, 27, 36),
    rowhi = Color3.fromRGB(30, 35, 46),
    line = Color3.fromRGB(38, 44, 58),
    text = Color3.fromRGB(232, 236, 245),
    dim = Color3.fromRGB(138, 148, 168),
    a1 = Color3.fromRGB(88, 214, 255),
    a2 = Color3.fromRGB(150, 122, 255),
    a3 = Color3.fromRGB(255, 122, 200),
}

local function irid()
    return ColorSequence.new({
        ColorSequenceKeypoint.new(0, THEME.a1),
        ColorSequenceKeypoint.new(0.5, THEME.a2),
        ColorSequenceKeypoint.new(1, THEME.a3),
    })
end

local function mk(class, props, parent)
    local i = Instance.new(class)
    for k, v in pairs(props) do i[k] = v end
    if parent then i.Parent = parent end
    return i
end

local function corner(p, r)
    return mk("UICorner", { CornerRadius = UDim.new(0, r or 8) }, p)
end

local function stroke(p, c, t, tr)
    return mk("UIStroke", { Color = c or THEME.line, Thickness = t or 1, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, p)
end

local function grad(p, rot)
    return mk("UIGradient", { Color = irid(), Rotation = rot or 0 }, p)
end

local function pad(p, l, r, t, b)
    return mk("UIPadding", {
        PaddingLeft = UDim.new(0, l or 0), PaddingRight = UDim.new(0, r or 0),
        PaddingTop = UDim.new(0, t or 0), PaddingBottom = UDim.new(0, b or 0),
    }, p)
end

local function glyph(parent, kind, size, color, z)
    local g = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, size, 0, size), ZIndex = z or 2 }, parent)
    local function bar(w, h, x, y, rot)
        local b = mk("Frame", {
            BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = (z or 2),
            AnchorPoint = Vector2.new(0.5, 0.5), Rotation = rot or 0,
            Position = UDim2.new(0.5, x, 0.5, y), Size = UDim2.new(0, w, 0, h),
        }, g)
        mk("UICorner", { CornerRadius = UDim.new(0, 1) }, b)
        return b
    end
    if kind == "down" then
        bar(size * 0.52, 1.6, -size * 0.16, 0, 45)
        bar(size * 0.52, 1.6, size * 0.16, 0, -45)
    elseif kind == "check" then
        bar(size * 0.34, 1.8, -size * 0.18, size * 0.12, 45)
        bar(size * 0.58, 1.8, size * 0.1, -size * 0.02, -45)
    elseif kind == "close" then
        bar(size * 0.7, 1.6, 0, 0, 45)
        bar(size * 0.7, 1.6, 0, 0, -45)
    elseif kind == "minus" then
        bar(size * 0.7, 1.6, 0, 0, 0)
    elseif kind == "dots" then
        for i = -1, 1 do bar(2.6, 2.6, i * 5, 0, 0) end
    end
    return g
end

local function tw(o, t, props)
    local ok, res = pcall(function()
        return TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    end)
    if ok and res then res:Play() return res end
end

function Prism.new(opts)
    local self = setmetatable({}, Prism)
    self.conns = {}
    self.tabs = {}
    self.paint = {}
    self.closers = {}
    self.open = true

    local waitStart = os.clock()
    while os.clock() - waitStart < 6 do
        local cam = Workspace.CurrentCamera
        if cam and cam.ViewportSize.X >= 400 and cam.ViewportSize.Y >= 300 then break end
        task.wait(0.1)
    end
    local vp = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
    local touch = UserInputService.TouchEnabled or GENV.ChronixForceMobile
    local W = math.clamp(opts.Width or 620, 300, math.max(300, vp.X - 24))
    local H = math.clamp(opts.Height or 430, 260, math.max(260, vp.Y - 24))
    self.small = touch or vp.X < 700

    local sg = mk("ScreenGui", {
        Name = "CHXTPZ_" .. tostring(math.random(10000, 99999)),
        ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 9999,
    })
    parentGui(sg)
    self.Gui = sg

    local root = mk("Frame", {
        Name = "Main", BackgroundColor3 = THEME.bg, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, W, 0, H), ClipsDescendants = true,
    }, sg)
    corner(root, 12)
    stroke(root, THEME.line, 1)
    self.Main = root
    local fitCam = Workspace.CurrentCamera
    if fitCam then
        table.insert(self.conns, fitCam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            local v = fitCam.ViewportSize
            if v.X < 50 or v.Y < 50 then return end
            root.Size = UDim2.new(0, math.clamp(opts.Width or 620, 300, math.max(300, v.X - 24)), 0, math.clamp(opts.Height or 430, 260, math.max(260, v.Y - 24)))
        end))
    end

    local glow = mk("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 2), ZIndex = 5,
    }, root)
    local gg = grad(glow, 0)
    self.shimmer = gg

    local bar = mk("Frame", {
        BackgroundColor3 = THEME.panel, BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 2), Size = UDim2.new(1, 0, 0, 40), ZIndex = 3,
    }, root)
    mk("Frame", { BackgroundColor3 = THEME.line, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), ZIndex = 3 }, bar)

    local dot = mk("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 4,
        Position = UDim2.new(0, 14, 0.5, -5), Size = UDim2.new(0, 10, 0, 10),
    }, bar)
    corner(dot, 5)
    grad(dot, 35)

    mk("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 32, 0, 0), Size = UDim2.new(1, -110, 1, 0),
        Font = Enum.Font.GothamBold, Text = opts.Name or "Prism", TextColor3 = THEME.text,
        TextSize = self.small and 13 or 14, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
    }, bar)

    local function barbtn(x, kind)
        local b = mk("TextButton", {
            BackgroundColor3 = THEME.row, BackgroundTransparency = 1, BorderSizePixel = 0,
            Position = UDim2.new(1, x, 0.5, -11), Size = UDim2.new(0, 22, 0, 22),
            Text = "", AutoButtonColor = false, ZIndex = 4,
        }, bar)
        corner(b, 6)
        glyph(b, kind, 12, THEME.dim, 5).Position = UDim2.new(0.5, -6, 0.5, -6)
        b.MouseEnter:Connect(function() tw(b, 0.12, { BackgroundTransparency = 0 }) end)
        b.MouseLeave:Connect(function() tw(b, 0.12, { BackgroundTransparency = 1 }) end)
        return b
    end

    local btnClose = barbtn(-30, "close")
    local btnMin = barbtn(-58, "minus")

    local side = mk("ScrollingFrame", {
        BackgroundColor3 = THEME.panel, BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 42), Size = UDim2.new(0, self.small and 104 or 132, 1, -42),
        ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 2,
    }, root)
    pad(side, 8, 8, 8, 8)
    mk("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, side)
    self.side = side
    mk("Frame", { BackgroundColor3 = THEME.line, BorderSizePixel = 0, Position = UDim2.new(0, (self.small and 104 or 132) - 1, 0, 42), Size = UDim2.new(0, 1, 1, -42), ZIndex = 2 }, root)

    local body = mk("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, self.small and 104 or 132, 0, 42),
        Size = UDim2.new(1, self.small and -104 or -132, 1, -42),
    }, root)
    self.body = body

    local drag, dragStart, startPos = false, nil, nil
    local function beginDrag(inp)
        drag = true dragStart = inp.Position startPos = root.Position
    end
    bar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then beginDrag(inp) end
    end)
    table.insert(self.conns, UserInputService.InputChanged:Connect(function(inp)
        if drag and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local d = inp.Position - dragStart
            root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end))
    table.insert(self.conns, UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then drag = false end
    end))

    local bubble = mk("TextButton", {
        Name = "Bubble", BackgroundColor3 = THEME.panel, BorderSizePixel = 0, Visible = false,
        Position = UDim2.new(0, 14, 0.5, -24), Size = UDim2.new(0, 48, 0, 48),
        Text = "", AutoButtonColor = false, ZIndex = 20,
    }, sg)
    corner(bubble, 24)
    local bst = stroke(bubble, Color3.new(1, 1, 1), 2)
    mk("UIGradient", { Color = irid(), Rotation = 45 }, bst)
    local bd = mk("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 16, 0, 16), ZIndex = 21 }, bubble)
    corner(bd, 8)
    grad(bd, 35)

    local bdrag, bstart, bpos, bmoved = false, nil, nil, false
    bubble.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            bdrag = true bmoved = false bstart = inp.Position bpos = bubble.Position
        end
    end)
    table.insert(self.conns, UserInputService.InputChanged:Connect(function(inp)
        if bdrag and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local d = inp.Position - bstart
            if math.abs(d.X) > 4 or math.abs(d.Y) > 4 then bmoved = true end
            bubble.Position = UDim2.new(bpos.X.Scale, bpos.X.Offset + d.X, bpos.Y.Scale, bpos.Y.Offset + d.Y)
        end
    end))
    table.insert(self.conns, UserInputService.InputEnded:Connect(function(inp)
        if bdrag and (inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch) then
            bdrag = false
            if not bmoved then self:Toggle(true) end
        end
    end))
    self.bubble = bubble

    btnMin.MouseButton1Click:Connect(function() self:Toggle(false) end)
    btnClose.MouseButton1Click:Connect(function() self:Destroy() end)

    self.toggleKey = opts.ToggleKey or Enum.KeyCode.RightControl
    table.insert(self.conns, UserInputService.InputBegan:Connect(function(inp)
        if inp.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if UserInputService:GetFocusedTextBox() then return end
        if inp.KeyCode == self.toggleKey or inp.KeyCode == Enum.KeyCode.Insert then
            self:Toggle(not self.open)
        end
    end))

    task.spawn(function()
        while sg.Parent do
            self.shimmer.Rotation = (self.shimmer.Rotation + 2) % 360
            task.wait(0.06)
        end
    end)

    self.notifyHolder = mk("Frame", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -12, 1, -12), Size = UDim2.new(0, 260, 1, -24), ZIndex = 30,
    }, sg)
    mk("UIListLayout", { Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder }, self.notifyHolder)

    return self
end

function Prism:Toggle(state)
    self.open = state
    self.Main.Visible = state
    self.bubble.Visible = not state
end

function Prism:OnClose(fn)
    table.insert(self.closers, fn)
end

function Prism:Notify(o)
    local card = mk("Frame", {
        BackgroundColor3 = THEME.panel, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 31,
    }, self.notifyHolder)
    corner(card, 8)
    stroke(card, THEME.line, 1)
    local acc = mk("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.new(0, 3, 1, 0), ZIndex = 32 }, card)
    grad(acc, 90)
    local stack = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 11, 0, 0), Size = UDim2.new(1, -20, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 32 }, card)
    mk("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, stack)
    pad(stack, 0, 0, 8, 8)
    mk("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 15), Font = Enum.Font.GothamBold,
        Text = o.Title or "Topaz", TextColor3 = THEME.text, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 32, LayoutOrder = 1,
    }, stack)
    mk("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        Font = Enum.Font.Gotham, Text = o.Content or "", TextColor3 = THEME.dim, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, ZIndex = 32, LayoutOrder = 2,
    }, stack)
    task.delay(o.Duration or 3, function()
        if card and card.Parent then
            tw(card, 0.18, { BackgroundTransparency = 1 })
            task.wait(0.2)
            pcall(function() card:Destroy() end)
        end
    end)
end

function Prism:Destroy()
    for _, fn in ipairs(self.closers) do pcall(fn) end
    for _, c in ipairs(self.conns) do pcall(function() c:Disconnect() end) end
    self.conns = {}
    pcall(function() self.Gui:Destroy() end)
end

local Tab = {}
Tab.__index = Tab

function Prism:Tab(name)
    local win = self
    local t = setmetatable({ win = self, rows = 0 }, Tab)

    local btn = mk("TextButton", {
        BackgroundColor3 = THEME.row, BackgroundTransparency = 1, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 30), Text = "", AutoButtonColor = false, ZIndex = 3,
    }, self.side)
    corner(btn, 7)
    local tick = mk("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0.5, -8), Size = UDim2.new(0, 3, 0, 16), ZIndex = 4,
    }, btn)
    corner(tick, 2)
    grad(tick, 90)
    local lbl = mk("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -16, 1, 0),
        Font = Enum.Font.GothamMedium, Text = name, TextColor3 = THEME.dim,
        TextSize = self.small and 11 or 12, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4,
    }, btn)

    local page = mk("ScrollingFrame", {
        BackgroundTransparency = 1, Visible = false, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0), ScrollBarThickness = 2,
        ScrollBarImageColor3 = THEME.line, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 2,
    }, self.body)
    pad(page, 12, 12, 12, 16)
    mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, page)

    t.page = page
    t.btn = btn

    local function select()
        for _, o in ipairs(win.tabs) do
            o.page.Visible = false
            o.btn.BackgroundTransparency = 1
            o.lbl.TextColor3 = THEME.dim
            o.tick.BackgroundTransparency = 1
        end
        page.Visible = true
        btn.BackgroundTransparency = 0
        lbl.TextColor3 = THEME.text
        tick.BackgroundTransparency = 0
    end
    btn.MouseButton1Click:Connect(select)
    t.lbl = lbl
    t.tick = tick
    t.select = select

    table.insert(self.tabs, t)
    if #self.tabs == 1 then select() end
    return t
end

function Tab:_row(h)
    local r = mk("Frame", {
        BackgroundColor3 = THEME.row, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, h or 34), ZIndex = 3,
    }, self.page)
    corner(r, 7)
    stroke(r, THEME.line, 1, 0.4)
    return r
end

function Tab:Section(text)
    local f = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), ZIndex = 3 }, self.page)
    local l = mk("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -30, 1, 0), Position = UDim2.new(0, 2, 0, 0),
        Font = Enum.Font.GothamBold, Text = string.upper(text), TextColor3 = THEME.dim,
        TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
    }, f)
    local ln = mk("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 3), Size = UDim2.new(0, 22, 0, 2), ZIndex = 4 }, f)
    corner(ln, 1)
    grad(ln, 0)
    return l
end

function Tab:Label(text)
    local r = self:_row(0)
    r.BackgroundTransparency = 1
    r.AutomaticSize = Enum.AutomaticSize.Y
    local l = mk("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 4, 0, 0), Size = UDim2.new(1, -8, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, Font = Enum.Font.Gotham, Text = text,
        TextColor3 = THEME.dim, TextSize = 11, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
    }, r)
    return { Set = function(_, v) l.Text = v end, obj = l }
end

function Tab:Button(o)
    local r = self:_row(34)
    local b = mk("TextButton", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = "",
        AutoButtonColor = false, ZIndex = 4,
    }, r)
    mk("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -40, 1, 0),
        Font = Enum.Font.GothamMedium, Text = o.Name, TextColor3 = THEME.text, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5,
    }, b)
    local ar = mk("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, 14, 0, 2), ZIndex = 5 }, b)
    corner(ar, 1)
    grad(ar, 0)
    b.MouseEnter:Connect(function() tw(r, 0.12, { BackgroundColor3 = THEME.rowhi }) end)
    b.MouseLeave:Connect(function() tw(r, 0.12, { BackgroundColor3 = THEME.row }) end)
    b.MouseButton1Click:Connect(function() task.spawn(function() pcall(o.Callback) end) end)
    return b
end

function Tab:Toggle(o)
    local r = self:_row(34)
    local state = o.Default and true or false
    local b = mk("TextButton", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = "", AutoButtonColor = false, ZIndex = 4 }, r)
    mk("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -66, 1, 0),
        Font = Enum.Font.GothamMedium, Text = o.Name, TextColor3 = o.Danger and Color3.fromRGB(255, 120, 120) or THEME.text,
        TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5,
    }, b)
    local track = mk("Frame", {
        BackgroundColor3 = THEME.line, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, 38, 0, 20), ZIndex = 5,
    }, b)
    corner(track, 10)
    local fill = mk("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0), ZIndex = 5,
    }, track)
    corner(fill, 10)
    grad(fill, 0)
    local knob = mk("Frame", {
        BackgroundColor3 = Color3.fromRGB(240, 244, 252), BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.new(0, 14, 0, 14), ZIndex = 6,
    }, track)
    corner(knob, 7)

    local function render(inst)
        local d = inst and 0 or 0.16
        if state then
            tw(fill, d, { BackgroundTransparency = 0 })
            tw(knob, d, { Position = UDim2.new(1, -17, 0.5, 0) })
        else
            tw(fill, d, { BackgroundTransparency = 1 })
            tw(knob, d, { Position = UDim2.new(0, 3, 0.5, 0) })
        end
    end
    render(true)

    local api = {}
    function api:Set(v, silent)
        state = v and true or false
        render()
        if not silent and o.Callback then task.spawn(function() pcall(o.Callback, state) end) end
    end
    function api:Get() return state end

    b.MouseButton1Click:Connect(function() api:Set(not state) end)
    b.MouseEnter:Connect(function() tw(r, 0.12, { BackgroundColor3 = THEME.rowhi }) end)
    b.MouseLeave:Connect(function() tw(r, 0.12, { BackgroundColor3 = THEME.row }) end)
    if o.Flag then self.win.paint[o.Flag] = api end
    return api
end

function Tab:Slider(o)
    local r = self:_row(46)
    local minv, maxv = o.Min or 0, o.Max or 100
    local dec = o.Decimals or 0
    local val = math.clamp(o.Default or minv, minv, maxv)

    mk("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 6), Size = UDim2.new(1, -70, 0, 14),
        Font = Enum.Font.GothamMedium, Text = o.Name, TextColor3 = THEME.text, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5,
    }, r)
    local vb = mk("TextLabel", {
        BackgroundColor3 = THEME.bg, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 5), Size = UDim2.new(0, 48, 0, 16),
        Font = Enum.Font.GothamBold, Text = "", TextColor3 = THEME.text, TextSize = 11, ZIndex = 5,
    }, r)
    corner(vb, 4)

    local track = mk("Frame", {
        BackgroundColor3 = THEME.line, BorderSizePixel = 0,
        Position = UDim2.new(0, 12, 0, 30), Size = UDim2.new(1, -24, 0, 5), ZIndex = 5,
    }, r)
    corner(track, 3)
    local fill = mk("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.new(0, 0, 1, 0), ZIndex = 6 }, track)
    corner(fill, 3)
    grad(fill, 0)
    local knob = mk("Frame", {
        BackgroundColor3 = Color3.fromRGB(240, 244, 252), BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0, 12, 0, 12), ZIndex = 7,
    }, track)
    corner(knob, 6)

    local function fmt(v)
        if dec <= 0 then return tostring(math.floor(v + 0.5)) end
        return string.format("%." .. dec .. "f", v)
    end
    local function render()
        local a = (maxv - minv) == 0 and 0 or (val - minv) / (maxv - minv)
        fill.Size = UDim2.new(a, 0, 1, 0)
        knob.Position = UDim2.new(a, 0, 0.5, 0)
        vb.Text = fmt(val) .. (o.Suffix or "")
    end

    local api = {}
    function api:Set(v, silent)
        local step = o.Increment
        if step and step > 0 then v = math.floor(v / step + 0.5) * step end
        val = math.clamp(v, minv, maxv)
        render()
        if not silent and o.Callback then task.spawn(function() pcall(o.Callback, val) end) end
    end
    function api:Get() return val end
    render()

    local sliding = false
    local function setFromX(x)
        local a = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
        api:Set(minv + a * (maxv - minv))
    end
    local hit = mk("TextButton", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, -10), Size = UDim2.new(1, 0, 0, 25),
        Text = "", AutoButtonColor = false, ZIndex = 8,
    }, track)
    hit.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            sliding = true setFromX(inp.Position.X)
        end
    end)
    table.insert(self.win.conns, UserInputService.InputChanged:Connect(function(inp)
        if sliding and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            setFromX(inp.Position.X)
        end
    end))
    table.insert(self.win.conns, UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then sliding = false end
    end))
    if o.Flag then self.win.paint[o.Flag] = api end
    return api
end

function Tab:Dropdown(o)
    local r = self:_row(34)
    local win = self.win
    local multi = o.Multi and true or false
    local options = o.Options or {}
    local sel = multi and {} or (o.Default or (options[1] or ""))
    if multi and type(o.Default) == "table" then for _, v in ipairs(o.Default) do sel[v] = true end end

    local b = mk("TextButton", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = "", AutoButtonColor = false, ZIndex = 4 }, r)
    mk("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(0.45, -12, 1, 0),
        Font = Enum.Font.GothamMedium, Text = o.Name, TextColor3 = THEME.text, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5,
    }, b)
    local cur = mk("TextLabel", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -28, 0.5, 0), Size = UDim2.new(0.5, -24, 1, 0),
        Font = Enum.Font.Gotham, Text = "", TextColor3 = THEME.dim, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5,
    }, b)
    local chev = glyph(b, "down", 12, THEME.dim, 5)
    chev.AnchorPoint = Vector2.new(1, 0.5)
    chev.Position = UDim2.new(1, -12, 0.5, 0)

    local function summary()
        if not multi then return tostring(sel == "" and "-" or sel) end
        local n, first = 0, nil
        for k, v in pairs(sel) do if v then n = n + 1 first = first or k end end
        if n == 0 then return "none" end
        if n == 1 then return tostring(first) end
        return n .. " selected"
    end

    local pop
    local function close()
        if pop then pcall(function() pop:Destroy() end) pop = nil end
        tw(chev, 0.12, { Rotation = 0 })
    end

    local api = {}
    function api:Get() return sel end
    function api:Set(v, silent)
        sel = v
        cur.Text = summary()
        if not silent and o.Callback then task.spawn(function() pcall(o.Callback, sel) end) end
    end
    function api:Refresh(list, keep)
        options = list or {}
        if not keep then
            if multi then sel = {} else sel = options[1] or "" end
        end
        cur.Text = summary()
        if pop then close() end
    end
    cur.Text = summary()

    local function build()
        close()
        pop = mk("Frame", {
            Name = "Pop", BackgroundColor3 = THEME.panel, BorderSizePixel = 0, ZIndex = 40,
            Position = UDim2.new(0, r.AbsolutePosition.X, 0, r.AbsolutePosition.Y + r.AbsoluteSize.Y + 4),
            Size = UDim2.new(0, r.AbsoluteSize.X, 0, 0),
        }, win.Gui)
        corner(pop, 7)
        stroke(pop, THEME.line, 1)
        local list = mk("ScrollingFrame", {
            BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0),
            ScrollBarThickness = 2, ScrollBarImageColor3 = THEME.line,
            CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 41,
        }, pop)
        pad(list, 4, 4, 4, 4)
        mk("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, list)

        local h = math.min(#options * 26 + 8, 170)
        tw(pop, 0.14, { Size = UDim2.new(0, r.AbsoluteSize.X, 0, h) })
        tw(chev, 0.14, { Rotation = 180 })

        for _, opt in ipairs(options) do
            local ob = mk("TextButton", {
                BackgroundColor3 = THEME.row, BackgroundTransparency = 1, BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 24), Text = "", AutoButtonColor = false, ZIndex = 42,
            }, list)
            corner(ob, 5)
            local ol = mk("TextLabel", {
                BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 0), Size = UDim2.new(1, -30, 1, 0),
                Font = Enum.Font.Gotham, Text = tostring(opt), TextSize = 11,
                TextColor3 = THEME.dim, TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 43,
            }, ob)
            local ck = glyph(ob, "check", 12, THEME.a1, 43)
            ck.AnchorPoint = Vector2.new(1, 0.5)
            ck.Position = UDim2.new(1, -8, 0.5, 0)

            local function paint()
                local on = multi and sel[opt] or (not multi and sel == opt)
                ck.Visible = on and true or false
                ol.TextColor3 = on and THEME.text or THEME.dim
                ob.BackgroundTransparency = on and 0 or 1
            end
            paint()
            ob.MouseButton1Click:Connect(function()
                if multi then
                    sel[opt] = not sel[opt] or nil
                    paint()
                    cur.Text = summary()
                    if o.Callback then task.spawn(function() pcall(o.Callback, sel) end) end
                else
                    sel = opt
                    cur.Text = summary()
                    close()
                    if o.Callback then task.spawn(function() pcall(o.Callback, sel) end) end
                end
            end)
        end
    end

    b.MouseButton1Click:Connect(function()
        if pop then close() else build() end
    end)
    b.MouseEnter:Connect(function() tw(r, 0.12, { BackgroundColor3 = THEME.rowhi }) end)
    b.MouseLeave:Connect(function() tw(r, 0.12, { BackgroundColor3 = THEME.row }) end)
    table.insert(win.closers, close)
    if o.Flag then win.paint[o.Flag] = api end
    return api
end

local WM
local function watermark()
    local sg = mk("ScreenGui", { Name = "CHXTPZ_WM", ResetOnSpawn = false, DisplayOrder = 10000 })
    parentGui(sg)
    local vp = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
    local small = UserInputService.TouchEnabled or GENV.ChronixForceMobile or vp.X < 700
    local f = mk("Frame", {
        BackgroundColor3 = Color3.fromRGB(14, 16, 22), BorderSizePixel = 0,
        Position = UDim2.new(0, 8, 0, 8), Size = UDim2.new(0, small and 168 or 200, 0, small and 22 or 26),
    }, sg)
    corner(f, small and 11 or 13)
    stroke(f, Color3.fromRGB(88, 160, 255), 1.5)
    mk("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Font = Enum.Font.GothamMedium,
        Text = "https://discord.gg/chronixhub", TextColor3 = Color3.fromRGB(226, 234, 248),
        TextSize = small and 10 or 12,
    }, f)
    WM = sg
    return sg
end

local G = {}

function G.clientFunctions()
    if PC.CF then return PC.CF end
    local ok, cf = pcall(function()
        return require(ReplicatedStorage.Assets.Modules.Client.Functions.ClientFunctions)
    end)
    if ok and type(cf) == "table" then PC.CF = cf return cf end
    return nil
end

function G.gameId()
    local rep = LP:FindFirstChild("Replicated")
    local gid = rep and rep:FindFirstChild("GameID")
    return gid and gid.Value or nil
end

function G.teamId()
    local rep = LP:FindFirstChild("Replicated")
    local t = rep and rep:FindFirstChild("TeamID")
    return t and t.Value or nil
end

function G.remotes()
    local gid = G.gameId()
    if not gid or gid == "" then return nil, nil end
    for _, root in ipairs({ ReplicatedStorage:FindFirstChild("Games"), ReplicatedStorage:FindFirstChild("MiniGames") }) do
        if root then
            local f = root:FindFirstChild(gid)
            if f then
                local ev = f:FindFirstChild("ReEvent")
                local fn = f:FindFirstChild("ReFunction")
                if ev then return ev, fn end
            end
        end
    end
    return nil, nil
end

local FIRELOG = { t = 0, n = 0, last = {} }
function G.fireOk(action)
    local L = FIRELOG
    local now = os.clock()
    if now - L.t >= 1 then L.t, L.n = now, 0 end
    if L.n >= 12 then return false end
    if action and now - (L.last[action] or 0) < 0.1 then return false end
    L.n = L.n + 1
    if action then L.last[action] = now end
    return true
end

function G.fire(action, ...)
    local ev = G.remotes()
    if not ev then return false end
    if not G.fireOk(action) then return false end
    local args = table.pack(...)
    local ok = pcall(function() ev:FireServer("Mechanics", action, table.unpack(args, 1, args.n)) end)
    return ok
end

function G.invoke(action, ...)
    local _, fn = G.remotes()
    if not fn then return nil end
    if not G.fireOk(action) then return nil end
    local args = table.pack(...)
    local ok, res = pcall(function() return fn:InvokeServer("Mechanics", action, table.unpack(args, 1, args.n)) end)
    if ok then return res end
    return nil
end

function G.gameFolder()
    local gid = G.gameId()
    if not gid or gid == "" then return nil end
    for _, root in ipairs({ Workspace:FindFirstChild("Games"), Workspace:FindFirstChild("MiniGames") }) do
        if root then
            local f = root:FindFirstChild(gid)
            if f then return f end
        end
    end
    local gs = Workspace:FindFirstChild("Games")
    if gs then return gs:GetChildren()[1] end
    return nil
end

function G.char()
    local c = LP.Character
    if not c then return nil, nil, nil end
    return c, c:FindFirstChild("HumanoidRootPart"), c:FindFirstChildOfClass("Humanoid")
end

function G.activeCarrier()
    if not G.sv then return nil end
    if G.sv("BallInAir") == true then return nil end
    local p = G.sv("ActiveCarrier")
    if typeof(p) == "Instance" and p:IsA("Player") and p ~= LP and p.Character then return p end
    return nil
end

function G.carrier()
    local ac = G.activeCarrier()
    if ac then return ac end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and p.Character:FindFirstChild("Football") then return p end
    end
    return nil
end

function G.teamOf(p)
    local rep = p and p:FindFirstChild("Replicated")
    local t = rep and rep:FindFirstChild("TeamID")
    local v = t and t.Value or nil
    if v == "" or v == "Unpicked" then return nil end
    return v
end

function G.relation(p)
    if not p or p == LP then return "self" end
    local mine = G.teamOf(LP)
    local theirs = G.teamOf(p)
    if not mine or not theirs then return "unknown" end
    local myGid = G.gameId()
    local rep = p:FindFirstChild("Replicated")
    local g = rep and rep:FindFirstChild("GameID")
    if myGid and g and g.Value ~= myGid then return "unknown" end
    if theirs == mine then return "team" end
    return "enemy"
end

function G.isEnemy(p)
    return G.relation(p) == "enemy"
end

function G.carrierBy(who)
    local ac = G.activeCarrier()
    if ac then
        local r = G.relation(ac)
        if who == "Any" or (who == "Teammate" and r == "team") or (who ~= "Teammate" and who ~= "Any" and r == "enemy") then
            return ac
        end
        return nil
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and p.Character:FindFirstChild("Football") then
            local r = G.relation(p)
            if who == "Any" or (who == "Teammate" and r == "team") or (who ~= "Teammate" and who ~= "Any" and r == "enemy") then
                return p
            end
        end
    end
    return nil
end

function G.carrying()
    local c = LP.Character
    if c and c:FindFirstChild("Football") then return true end
    if G.sv and G.sv("ActiveCarrier") == LP and G.sv("BallInAir") ~= true then return true end
    return false
end

local ballScan = { part = nil, t = 0 }
function G.ball()
    local c = LP.Character
    if c then
        local b = c:FindFirstChild("Football")
        if b then
            if b:IsA("BasePart") then return b end
            local h = b:FindFirstChildWhichIsA("BasePart")
            if h then return h end
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        local ch = p.Character
        if ch then
            local b = ch:FindFirstChild("Football")
            if b then
                if b:IsA("BasePart") then return b end
                local h = b:FindFirstChildWhichIsA("BasePart")
                if h then return h end
            end
        end
    end
    local gf = G.gameFolder()
    if gf then
        local rep = gf:FindFirstChild("Replicated")
        if rep then
            local b = rep:FindFirstChild("Football")
            if b and b:IsA("BasePart") then return b end
            for _, c in ipairs(rep:GetChildren()) do
                if c:IsA("BasePart") and c.Name:match("^%x+%-%x+%-%x+%-%x+%-%x+$") then return c end
            end
        end
    end
    if ballScan.part and ballScan.part.Parent and ballScan.part:IsDescendantOf(Workspace) then return ballScan.part end
    if G.sv and G.sv("BallInAir") ~= true then return nil end
    local now = os.clock()
    if now - ballScan.t < 3 then return nil end
    ballScan.t = now
    ballScan.part = nil
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("BasePart") and d.Name == "Football" then
            local replay = false
            local a = d.Parent
            while a and a ~= Workspace do
                if a.Name:match("^Replay") then replay = true break end
                a = a.Parent
            end
            if not replay then ballScan.part = d return d end
        end
    end
    return nil
end

function G.hitboxes()
    local gf = G.gameFolder()
    if not gf then return nil end
    local rep = gf:FindFirstChild("Replicated")
    return rep and rep:FindFirstChild("Hitboxes") or nil
end

function G.footballMath()
    if PC.FM then return PC.FM end
    local ok, m = pcall(function()
        return require(ReplicatedStorage.Assets.Modules.Shared.Services.FootballMath)
    end)
    if ok and type(m) == "table" then PC.FM = m return m end
    return nil
end

local AC = { orig = nil, on = false }
function AC.enable()
    if AC.on then return true end
    local cf = G.clientFunctions()
    if not cf or type(cf.Performance) ~= "table" then return false end
    if type(cf.Performance.PlayerTracking) ~= "function" then return false end
    AC.orig = cf.Performance.PlayerTracking
    cf.Performance.PlayerTracking = function() end
    AC.on = true
    return true
end
function AC.disable()
    if not AC.on then return end
    local cf = G.clientFunctions()
    if cf and type(cf.Performance) == "table" and AC.orig then
        cf.Performance.PlayerTracking = AC.orig
    end
    AC.on = false
end

local CFG_RAW = {
    bypass = true,
    walk = false, walkVal = 24,
    cwalk = false, cwalkVal = 23,
    hbShow = false,
    autoTD = false, tdGlide = 0, tdInt = true, landCatch = true,
    jump = false, jumpVal = 55,
    stamina = false,
    pull = false, pullMax = 35, pullOffset = 15, pullAuto = false, pullSmooth = 0.2,
    legit = false, legitSpeed = 23,
    dmags = false, dmagsDist = 120, dmagsShow = false, dmagsCatch = true,
    fly = false, flySpeed = 50, noclip = false,
    ttb = false, ttbPower = 5, ttbSmooth = 0.3, headSink = false, sinkStrength = 0.8, sinkDepth = 3, sinkBoost = 60, headManip = false, headManipSubtle = true, headFollow = false, boostJump = false, boostJumpPower = 25, sideFling = false, flingPower = 300, flingUp = 55, flingCD = 0.5, contactBoost = false, contactPower = 66, contactCD = 0.15, landBoost = false, landBoostPower = 90, diveForce = false, diveForcePower = 50, fastFall = false, hipHeight = false, hipValue = 2,
    autoCatch = false, catchRadius = 14,
    apv = false, apvMode = "Landing Spot", apvOffset = 12, apvStart = 45, apvMaxTime = 6000, apvMinSpeed = 20, apvCool = 0.5,
    apvMax = 500, apvMaxJump = 80, apvReturn = false, apvBack = 1500, apvPasses = true, apvKicks = true, apvEnemyOnly = false, apvSmooth = 1, apvFreeze = true,
    apvFG = false, apvReturner = true, apvAhead = 4,
    autoHike = false,
    follow = false, followBlat = 0.5, followWho = "Enemy",
    autoDive = false,
    hitbox = false, hitboxSize = 6, hitboxTrans = 0.75, hitboxEnemy = true,
    reach = false, reachDist = 5,
    bighead = false, bigheadSize = 4,
    espBall = false, espCarrier = false, espPlayers = false,
    antiAdmin = true, antiAfk = true, autoload = false,
    rush = false, intercept = false, interceptRange = 80, autoBlock = false, blockRange = 8, landEsp = false,
    kickAngle = 44, kickPower = 15, kickAim = 0, cfgVer = 12,
    aimPower = 85, aimLead = 1, aimMode = "Game Auto-Throw",
    gpWalk = false, gpWalkVal = 18, gpJump = false, gpJumpVal = 53.5, gpDive = false, gpDiveVal = 1.9,
    gpRegen = false, gpRegenVal = 10, gpDrain = false, gpDrainVal = 10, gravity = false, gravityVal = 196.2,
    ownHb = false, ownX = 2.52, ownY = 5.4, ownZ = 1.41, ownTrans = 0.7, ownPreset = "Default (2.52)",
    headClone = false, headCloneSize = 1.5, headCloneTrans = 0.7,
    sticky = false, stickyRange = 10, stickySmooth = 12, stickyStrength = 12, stickyEnemy = true,
    safeArc = false, catchRing = false, hideArc = false, smooth = false, mapClean = false, noAds = false,
    jpv = false, jpvPull = 1, jpvDist = 10, kbJpv = "", aimSafe = true, aimSafeSwitch = true,
    kbOwnHb = "", kbSticky = "", kbHitbox = "", kbPre1 = "", kbPre2 = "", kbPre3 = "", kbPre4 = "",
}

local CFGIO = { path = "Chronix/Topaz.json", dirty = false, off = false, last = 0 }

local function cfgWrite()
    if CFGIO.off then return end
    if not (writefile and isfolder and makefolder) then return end
    pcall(function()
        if not isfolder("Chronix") then makefolder("Chronix") end
        writefile(CFGIO.path, game:GetService("HttpService"):JSONEncode(CFG_RAW))
    end)
end

local function cfgRead()
    if not (readfile and isfile) then return end
    pcall(function()
        if not isfile(CFGIO.path) then return end
        local t = game:GetService("HttpService"):JSONDecode(readfile(CFGIO.path))
        if type(t) ~= "table" then return end
        for k, v in pairs(t) do
            if CFG_RAW[k] ~= nil and type(v) == type(CFG_RAW[k]) then CFG_RAW[k] = v end
        end
        local ver = tonumber(t.cfgVer) or 1
        if ver < 5 then
            if t.desync == true then CFG_RAW.apv = true end
            if type(t.desyncOffset) == "number" then CFG_RAW.apvOffset = t.desyncOffset end
            if type(t.desyncFreeze) == "boolean" then CFG_RAW.apvFreeze = t.desyncFreeze end
            if CFG_RAW.pullMax < 40 then CFG_RAW.pullMax = 40 end
        end
        if ver < 6 then
            CFG_RAW.apvMode = "Landing Spot"
        end
        if ver < 7 then
            CFG_RAW.apvReturner = true
        end
        if ver < 8 then
            if CFG_RAW.cwalkVal > 30 then CFG_RAW.cwalkVal = 23 end
            if CFG_RAW.tdGlide > 40 then CFG_RAW.tdGlide = 0 end
            CFG_RAW.antiAfk = true
        end
        if ver < 9 then
            CFG_RAW.aimMode = "Game Auto-Throw"
            if CFG_RAW.walkVal > 41 then CFG_RAW.walkVal = 41 end
            if CFG_RAW.cwalkVal > 41 then CFG_RAW.cwalkVal = 41 end
        end
        if ver < 10 then CFG_RAW.apvMaxJump = 80 end
        if ver < 11 then CFG_RAW.stickyEnemy = true CFG_RAW.sticky = false end
        if ver < 12 then CFG_RAW.pullOffset = 15 CFG_RAW.pullMax = 35 end
        CFG_RAW.cfgVer = 12
    end)
end

cfgRead()

local CFG = setmetatable({}, {
    __index = CFG_RAW,
    __newindex = function(_, k, v)
        if CFG_RAW[k] == v then return end
        CFG_RAW[k] = v
        CFGIO.dirty = true
    end,
})

task.spawn(function()
    while not CFGIO.off do
        task.wait(1)
        if CFGIO.dirty and not CFGIO.off then
            CFGIO.dirty = false
            cfgWrite()
        end
    end
end)

local RT = { conns = {}, hl = {}, alive = true }

local function bind(key, conn)
    if RT.conns[key] then pcall(function() RT.conns[key]:Disconnect() end) end
    RT.conns[key] = conn
end
local function unbind(key)
    if RT.conns[key] then pcall(function() RT.conns[key]:Disconnect() end) RT.conns[key] = nil end
end

local function highlight(key, inst, fill, outline)
    local old = RT.hl[key]
    if not inst then
        if old then pcall(function() old:Destroy() end) RT.hl[key] = nil end
        return
    end
    if old and old.Parent and old.Adornee == inst then return end
    if old then pcall(function() old:Destroy() end) RT.hl[key] = nil end
    local h = Instance.new("Highlight")
    h.Name = "CHXTPZ_HL"
    h.FillColor = fill
    h.OutlineColor = outline or fill
    h.FillTransparency = 0.55
    h.OutlineTransparency = 0
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Adornee = inst
    local ok = pcall(function() h.Parent = RT.hlRoot end)
    if not ok then h.Parent = inst end
    RT.hl[key] = h
end

local function clearHighlights()
    for k, h in pairs(RT.hl) do pcall(function() h:Destroy() end) RT.hl[k] = nil end
end

local F = {}

function F.walk()
    unbind("walk")
    local _, _, hum = G.char()
    if not CFG.walk then
        if hum then pcall(function() hum.WalkSpeed = 18 end) end
        return
    end
    local function apply()
        local _, _, h = G.char()
        if h then pcall(function() h.WalkSpeed = CFG.walkVal end) end
    end
    apply()
    if hum then bind("walk", hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if CFG.walk then
            local _, _, h = G.char()
            if h and math.abs(h.WalkSpeed - CFG.walkVal) > 0.01 then h.WalkSpeed = CFG.walkVal end
        end
    end)) end
end

function F.jump()
    unbind("jump")
    if not CFG.jump then return end
    local _, hrp, hum = G.char()
    if not hum or not hrp then return end
    bind("jump", hum.Jumping:Connect(function(active)
        if not active or not CFG.jump then return end
        local _, r = G.char()
        if r then
            r.AssemblyLinearVelocity = Vector3.new(r.AssemblyLinearVelocity.X, CFG.jumpVal, r.AssemblyLinearVelocity.Z)
        end
    end))
end

function G.mechanics()
    if PC.MECH then return PC.MECH end
    local ok, m = pcall(function()
        return require(ReplicatedStorage.Assets.Modules.Client.Mechanics)
    end)
    if ok and type(m) == "table" then PC.MECH = m return m end
    return nil
end

function F.stamina()
    unbind("stamina")
    if not CFG.stamina then return end
    local m = G.mechanics()
    local cf = G.clientFunctions()
    local vars = cf and cf.Variables
    if not m and not vars then return end
    bind("stamina", RunService.Heartbeat:Connect(function()
        if not CFG.stamina then return end
        pcall(function()
            if m and type(m.Stamina) == "number" then m.Stamina = 100 end
            if vars and type(vars.Stamina) == "number" then vars.Stamina = 100 end
        end)
    end))
end

function G.mhBall()
    local pm = Workspace:FindFirstChild("ParkMap")
    local fields = pm and pm:FindFirstChild("Replicated") and pm.Replicated:FindFirstChild("Fields")
    if fields then
        for _, n in ipairs({ "LeftField", "RightField", "BLeftField", "BRightField", "HighField", "TLeftField", "TRightField" }) do
            local f = fields:FindFirstChild(n)
            local r = f and f:FindFirstChild("Replicated")
            local b = r and r:FindFirstChild("Football")
            if b and b:IsA("BasePart") then return b end
        end
    end
    local pmm = Workspace:FindFirstChild("ParkMatchMap")
    local mf = pmm and pmm:FindFirstChild("Replicated") and pmm.Replicated:FindFirstChild("Fields")
    mf = mf and mf:FindFirstChild("MatchField")
    local mr = mf and mf:FindFirstChild("Replicated")
    local mb = mr and mr:FindFirstChild("Football")
    if mb and mb:IsA("BasePart") then return mb end
    local list = {}
    local own = G.gameFolder()
    if own then list[1] = own end
    local games = Workspace:FindFirstChild("Games")
    if games then for _, g in ipairs(games:GetChildren()) do if g ~= own then list[#list + 1] = g end end end
    for _, g in ipairs(list) do
        local r = g:FindFirstChild("Replicated")
        if r then
            for _, c in ipairs(r:GetChildren()) do
                if c:IsA("BasePart") and (c.Name == "Football" or c.Name:match("^%x+%-%x+%-%x+%-%x+%-%x+$")) then return c end
            end
        end
    end
    return nil
end

function F.pullTo(instant)
    if G.carrying() then return end
    local b = G.mhBall()
    local _, hrp = G.char()
    if not b or not hrp then return end
    if (b.Position - hrp.Position).Magnitude > CFG.pullMax then return end
    local now = os.clock()
    if instant then
        if now - (RT.mpT or 0) < 0.05 then return end
        RT.mpT = now
    end
    RT.mp = RT.mp or {}
    local vel = b.AssemblyLinearVelocity
    local off = CFG.pullOffset
    if instant and CFG.pullAuto then
        local m = vel.Magnitude
        off = m > 80 and 12 or m > 50 and 8 or m > 25 and 5 or 3
    end
    local lead = vel.Magnitude > 0 and vel.Unit * off or Vector3.zero
    local target = b.Position + lead + Vector3.new(0, 3, 0)
    if target.Y < hrp.Position.Y then target = Vector3.new(target.X, hrp.Position.Y, target.Z) end
    local flat = (b.Position - hrp.Position) * Vector3.new(1, 0, 1)
    if flat.Magnitude < 0.1 then flat = hrp.CFrame.LookVector * Vector3.new(1, 0, 1) end
    if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
    local goal = CFrame.new(target, target + flat.Unit)
    pcall(function()
        if instant then
            hrp.CFrame = goal
        else
            hrp.CFrame = hrp.CFrame:Lerp(goal, math.clamp(CFG.pullSmooth, 0.01, 1))
        end
    end)
end

local BALL_G = Vector3.new(0, -28, 0)

function G.ballAt(b, t)
    return b.Position + b.AssemblyLinearVelocity * t + BALL_G * (0.5 * t * t)
end

function G.pingLead()
    local p = 0.1
    pcall(function() p = LP:GetNetworkPing() end)
    if type(p) ~= "number" or p ~= p or p < 0 then p = 0.1 end
    return math.clamp(p * 2 + 0.15, 0.2, 0.9)
end

function G.closestApproach(b, pos, horizon)
    local best, bestT = math.huge, 0
    local steps = math.floor(horizon / 0.05)
    for i = 0, steps do
        local t = i * 0.05
        local d = (G.ballAt(b, t) - pos).Magnitude
        if d < best then best, bestT = d, t end
    end
    return best, bestT
end

function G.ballLive(b)
    if not b or not b.Parent then return false end
    local holder = b:FindFirstAncestorOfClass("Model")
    if holder and Players:GetPlayerFromCharacter(holder) then return false end
    local lv = b:FindFirstChildOfClass("LinearVelocity")
    if lv and lv.Enabled == false then return false end
    return true
end

function G.catchWanted(b, pos, radius)
    if not G.ballLive(b) then return false end
    if (b.Position - pos).Magnitude <= (radius or 15) then return true end
    if b.AssemblyLinearVelocity.Magnitude < 5 then return false end
    local d = G.closestApproach(b, pos, 1.2)
    return d <= 6
end

function G.stepJump(hrp, target, st)
    local maxJump = math.max(20, tonumber(CFG.apvMaxJump) or 80)
    local off = target.Position - hrp.Position
    if off.Magnitude <= maxJump then return target end
    local now = os.clock()
    if st and st.lastStep and now - st.lastStep < 0.25 then return nil end
    if st then st.lastStep = now end
    local p = hrp.Position + off.Unit * maxJump
    return CFrame.lookAt(p, p + (target.LookVector.Magnitude > 0 and target.LookVector or off.Unit))
end

function G.fireCatch()
    local now = os.clock()
    if now - (RT.lastCatch or 0) < 0.15 then return false end
    if G.boxFlag and G.boxFlag("Catching") == true then return false end
    RT.lastCatch = now
    return G.fire("Catching", true)
end

function G.groundHrpY(hrp, hum)
    local ignore = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then ignore[#ignore + 1] = p.Character end
    end
    local gf = G.gameFolder()
    local rep = gf and gf:FindFirstChild("Replicated")
    if rep then
        local hb = rep:FindFirstChild("Hitboxes")
        if hb then ignore[#ignore + 1] = hb end
        for _, ch in ipairs(rep:GetChildren()) do
            if ch:IsA("BasePart") then ignore[#ignore + 1] = ch end
        end
    end
    if RT.landPart then ignore[#ignore + 1] = RT.landPart end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local extra = (hum and hum.HipHeight or 2) + hrp.Size.Y / 2
    for _ = 1, 8 do
        params.FilterDescendantsInstances = ignore
        local res = Workspace:Raycast(hrp.Position + Vector3.new(0, 2, 0), Vector3.new(0, -400, 0), params)
        if not res then break end
        if res.Instance.CanCollide then return res.Position.Y + extra end
        ignore[#ignore + 1] = res.Instance
    end
    return 3.4
end

function F.autoCatch()
    unbind("catch")
    if not CFG.autoCatch then return end
    bind("catch", RunService.Heartbeat:Connect(function()
        if not CFG.autoCatch or RT.ds or RT.mp then return end
        if G.carrying() or G.sv("BallInAir") ~= true then return end
        local b = G.ball()
        local _, hrp = G.char()
        if not b or not hrp then return end
        if (b.Position - hrp.Position).Magnitude > 150 then return end
        if G.catchWanted(b, hrp.Position, CFG.catchRadius) then G.fireCatch() end
    end))
end

function F.desync()
    unbind("desync")
    if RT.ds then
        local _, hrp = G.char()
        if hrp and RT.ds.moved and CFG.apvReturn then pcall(function() hrp.CFrame = RT.ds.origin end) end
        RT.ds = nil
    end
    RT.dsCool = nil
    RT.apEdge = 0
    RT.apTried = nil
    if not CFG.apv then G.dsUnfreeze() return end
    bind("desync", RunService.Heartbeat:Connect(function()
        if not CFG.apv then return end
        pcall(G.apvStep)
    end))
end

function G.apvEdge()
    local air = G.sv("BallInAir") == true
    if air and not RT.apAirPrev then
        RT.apEdge = (RT.apEdge or 0) + 1
        RT.apAirOff = G.sv("Offense")
        RT.apAirState = G.state()
        local k = G.sv("ActiveKicker")
        RT.apAirKicker = (typeof(k) == "Instance" and k:IsA("Player")) and k or nil
        local t = G.sv("ActiveCarrier")
        RT.apAirThrower = (typeof(t) == "Instance" and t:IsA("Player")) and t or nil
        local r = G.sv("ActiveReturner")
        RT.apAirReturner = (typeof(r) == "Instance" and r:IsA("Player")) and r or nil
        RT.apWarned = nil
    end
    RT.apAirPrev = air
    return air
end

function G.apvKind(b)
    local s = string.lower(RT.apAirState or "")
    if s:find("field") then return "fg" end
    if s:find("kick") or s:find("punt") or s:find("onside") then return "kick" end
    if RT.apAirKicker ~= nil or (b and b.Name ~= "Football") then return "kick" end
    return "pass"
end

function G.apvAllowed(b)
    if RT.apAirKicker == LP or RT.apAirThrower == LP then return false end
    local kind = G.apvKind(b)
    local mine = G.teamOf(LP)
    if kind == "fg" or kind == "kick" then
        if kind == "fg" and not CFG.apvFG then return false end
        if kind == "kick" and not CFG.apvKicks then return false end
        local kt = RT.apAirKicker and G.teamOf(RT.apAirKicker) or RT.apAirOff
        if mine and kt == mine then return false end
        if kind == "kick" and RT.apAirReturner and RT.apAirReturner ~= LP then
            if CFG.apvReturner then return false end
            if not RT.apWarned then
                RT.apWarned = true
                if RT.notify then RT.notify("Auto PullVector", "You are not the kick returner - the game only lets the returner catch kickoffs", 3) end
            end
        end
        return true
    end
    if not CFG.apvPasses then return false end
    if CFG.apvEnemyOnly then
        local src = RT.apAirThrower
        if src then
            if G.relation(src) ~= "enemy" then return false end
        elseif mine and RT.apAirOff == mine then
            return false
        end
    end
    return true
end

function G.apvFace(from, to)
    local f = to - from
    f = Vector3.new(f.X, 0, f.Z)
    if f.Magnitude < 0.1 then return Vector3.new(1, 0, 0) end
    return f.Unit
end

function G.apvClampY(st, p)
    local top = 3
    return Vector3.new(p.X, math.clamp(p.Y, st.gy, st.gy + top), p.Z)
end

function G.apvContest(b, horizon)
    local first
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LP then
            local ch = pl.Character
            local r = ch and ch:FindFirstChild("HumanoidRootPart")
            if r and (r.Position - b.Position).Magnitude < 400 then
                local d, t = G.closestApproach(b, r.Position, horizon)
                if d <= 7 and (not first or t < first) then first = t end
            end
        end
    end
    return first
end

function G.apvGoal(b, st)
    local now = os.clock()
    if st.landing then
        local spot = G.landingSpot(st.gy)
        if spot then
            local goal = spot
            if b then
                local sp = b.AssemblyLinearVelocity.Magnitude
                if sp > 5 then
                    local _, tb = G.closestApproach(b, spot, 6)
                    local tUp = tb - CFG.apvAhead / sp
                    if not st.tcT or now - st.tcT > 0.1 then
                        st.tc = G.apvContest(b, tb)
                        st.tcT = now
                    end
                    local tc = st.tc
                    if tc and tc < tUp then
                        tUp = math.max(tc - (CFG.apvAhead + 2) / sp, G.pingLead())
                    end
                    if tUp > 0.05 and tUp < tb then
                        local p = G.ballAt(b, tUp)
                        goal = Vector3.new(p.X, math.clamp(p.Y, st.gy, st.gy + 6), p.Z)
                    end
                end
            end
            goal = G.clampField(goal)
            local face = b and G.apvFace(goal, b.Position) or (st.lastFace or Vector3.new(1, 0, 0))
            st.lastGoal, st.lastFace, st.lastGoalT, st.lastSpot = goal, face, now, true
            return goal, true
        end
    end
    if b then
        local sp = b.AssemblyLinearVelocity.Magnitude
        local t = G.pingLead() + (sp > 1 and CFG.apvOffset / sp or 0)
        local p = G.clampField(G.apvClampY(st, G.ballAt(b, t)))
        st.lastGoal, st.lastFace, st.lastGoalT, st.lastSpot = p, G.apvFace(p, b.Position), now, false
        return p, false
    end
    if st.lastGoal and now - (st.lastGoalT or 0) < 1.5 then return st.lastGoal, st.lastSpot end
    return nil
end

function G.apvEnd(now, caught)
    local st = RT.ds
    RT.ds = nil
    RT.dsCool = now
    RT.dsN = (RT.dsN or 0) + 1
    if caught then RT.dsCaught = (RT.dsCaught or 0) + 1 end
    if st and st.moved and CFG.apvReturn and not caught then
        local origin = st.origin
        task.delay(math.max(CFG.apvBack / 1000, 0), function()
            if not RT.alive then return end
            local _, hrp = G.char()
            if hrp and not G.carrying() then
                pcall(function()
                    hrp.CFrame = origin
                    hrp.AssemblyLinearVelocity = Vector3.zero
                end)
            end
        end)
    end
end

function G.apvStep()
    local air = G.apvEdge()
    local _, hrp, hum = G.char()
    if not hrp or not hum or hum.Health <= 0 then return end
    local now = os.clock()
    local st = RT.ds
    if st then
        if RT.pullOwner == "manual" then return end
        if G.carrying() then
            pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
            G.apvEnd(now, true)
            return
        end
        if now - st.t0 > CFG.apvMaxTime / 1000 then G.apvEnd(now, false) return end
        if not air then
            st.airOff = st.airOff or now
            if now - st.airOff > 0.35 then G.apvEnd(now, false) end
            return
        end
        st.airOff = nil
        if G.sv("DeadPlay") == true then G.apvEnd(now, false) return end
        local ac = G.sv("ActiveCarrier")
        if typeof(ac) == "Instance" and ac:IsA("Player") and ac ~= LP and ac ~= RT.apAirKicker and ac ~= RT.apAirThrower then G.apvEnd(now, false) return end
        local b = G.ball()
        if b and b.Position.Y < -500 then b = nil end
        if b then
            local holder = b:FindFirstAncestorOfClass("Model")
            if holder and holder ~= LP.Character and Players:GetPlayerFromCharacter(holder) then G.apvEnd(now, false) return end
            if b.AssemblyLinearVelocity.Magnitude < 2 then
                st.slow = st.slow or now
                if now - st.slow > 0.3 then G.apvEnd(now, false) return end
            else
                st.slow = nil
            end
        end
        local goal, fromSpot = G.apvGoal(b, st)
        if not goal then return end
        if st.phase == "wait" then
            if not b then return end
            local v = b.AssemblyLinearVelocity
            if st.kind ~= "pass" and v.Y > 0 then return end
            if fromSpot then
                local startD = math.max(CFG.apvStart, v.Magnitude * (G.pingLead() + 0.25))
                if (b.Position - goal).Magnitude > startD then return end
            elseif now - st.t0 < 0.6 then
                return
            end
            st.phase = "hold"
        end
        if not st.hold then
            st.hold = CFrame.lookAt(goal, goal + (st.lastFace or Vector3.new(1, 0, 0)))
        elseif b then
            local d, tb = G.closestApproach(b, st.hold.Position, 3)
            if d > 3 then
                local p = G.clampField(G.apvClampY(st, G.ballAt(b, tb)))
                if (p - st.hold.Position).Magnitude > 3 then
                    st.hold = CFrame.lookAt(p, p + G.apvFace(p, b.Position))
                end
            end
        end
        st.moved = true
        pcall(function()
            local target = st.hold
            if CFG.apvSmooth < 0.99 then target = hrp.CFrame:Lerp(st.hold, CFG.apvSmooth) end
            target = G.stepJump(hrp, target, st)
            if target then
                hrp.CFrame = target
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
        end)
        if b then
            if G.catchWanted(b, hrp.Position, math.max(CFG.catchRadius, 15)) then G.fireCatch() end
            local rel = b.Position - hrp.Position
            local v = b.AssemblyLinearVelocity
            if v.Magnitude > 2 and rel:Dot(v) > 0 and rel.Magnitude > 10 then
                st.passed = st.passed or now
                if now - st.passed > 0.35 then G.apvEnd(now, false) return end
            else
                st.passed = nil
            end
        end
        return
    end
    if RT.dsCool then
        if now - RT.dsCool < CFG.apvCool then return end
        RT.dsCool = nil
        G.dsUnfreeze()
    end
    if not air or G.carrying() then return end
    if RT.pullOwner == "manual" then return end
    if RT.apArmed == RT.apEdge then return end
    local b = G.ball()
    if not b or b.Position.Y < -500 then return end
    local holder = b:FindFirstAncestorOfClass("Model")
    if holder and Players:GetPlayerFromCharacter(holder) then return end
    if b.AssemblyLinearVelocity.Magnitude < CFG.apvMinSpeed then return end
    if CFG.apvMax > 0 and (b.Position - hrp.Position).Magnitude > CFG.apvMax then return end
    if not G.apvAllowed(b) then return end
    RT.apArmed = RT.apEdge
    G.dsFreeze(hum)
    local kind = G.apvKind(b)
    local landing = kind ~= "pass" or CFG.apvMode == "Landing Spot"
    RT.ds = { origin = hrp.CFrame, t0 = now, edge = RT.apEdge, kind = kind, landing = landing, gy = G.groundHrpY(hrp, hum), phase = landing and "wait" or "hold" }
end

function G.dsFreeze(hum)
    if not CFG.apvFreeze or RT.dsFreeze then return end
    RT.dsFreeze = true
    if CFG.walk then
        unbind("walk")
        if hum then pcall(function() hum.WalkSpeed = 18 end) end
    end
end

function G.dsUnfreeze()
    if not RT.dsFreeze then return end
    RT.dsFreeze = nil
    if CFG.walk and RT.alive then F.walk() end
end

function F.autoHike()
    unbind("hike")
    if not CFG.autoHike then return end
    local last = 0
    bind("hike", RunService.Heartbeat:Connect(function()
        if not CFG.autoHike then return end
        if tick() - last < 1.5 then return end
        if LP.Character and LP.Character:FindFirstChild("Football") then return end
        local gf = G.gameFolder()
        local rep = gf and gf:FindFirstChild("Replicated")
        if not (rep and rep:FindFirstChild("ScrimmageLine")) then return end
        last = tick()
        G.fire("Hiked")
    end))
end

function F.follow()
    unbind("follow")
    if not CFG.follow then return end
    bind("follow", RunService.Heartbeat:Connect(function()
        if RT.rushing or RT.intercepting then return end
        if not CFG.follow then RT.followGoal = nil return end
        if RT.ds then RT.followGoal = nil return end
        local p = G.carrierBy(CFG.followWho)
        if not p or not p.Character then RT.followGoal = nil return end
        local tr = p.Character:FindFirstChild("HumanoidRootPart")
        local _, hrp, hum = G.char()
        if not tr or not hrp or not hum then RT.followGoal = nil return end
        local flat = Vector3.new(tr.Position.X - hrp.Position.X, 0, tr.Position.Z - hrp.Position.Z)
        local dist = flat.Magnitude
        if dist < 3 then
            RT.followGoal = nil
            hum:Move(Vector3.zero)
            return
        end
        local spd = hum.WalkSpeed
        if CFG.cwalk then spd = math.max(spd, CFG.cwalkVal) end
        local lead = math.min(dist / math.max(1, spd), 1.5)
        local v = tr.AssemblyLinearVelocity
        local t = tr.Position + Vector3.new(v.X, 0, v.Z) * lead * math.clamp(CFG.followBlat, 0, 1)
        local goal = Vector3.new(t.X, hrp.Position.Y, t.Z)
        RT.followGoal = goal
        RT.followGoalT = os.clock()
        hum:MoveTo(goal)
    end))
end

function F.autoDive()
    unbind("dive")
    if not CFG.autoDive then return end
    local last = 0
    bind("dive", RunService.Heartbeat:Connect(function()
        if not CFG.autoDive then return end
        if tick() - last < 1.1 then return end
        local b = G.ball()
        local _, hrp = G.char()
        if not b or not hrp then return end
        if (b.Position - hrp.Position).Magnitude <= 10 then
            last = tick()
            G.fire("Dive")
        end
    end))
end

RT.hbOrig = RT.hbOrig or {}
function G.hbRestore(part)
    local o = RT.hbOrig[part]
    if not o then return end
    RT.hbOrig[part] = nil
    pcall(function()
        part.Size = o.Size
        part.Transparency = o.Transparency
        part.Material = o.Material
        part.Color = o.Color
    end)
end

function G.hbRestoreAll()
    for part in pairs(RT.hbOrig) do G.hbRestore(part) end
end

function G.hbApply()
    local h = G.hitboxes()
    if not h then return end
    local carrying = G.carrying()
    for _, p in ipairs(h:GetChildren()) do
        if p:IsA("BasePart") and p.Name ~= LP.Name then
            local ok = not carrying
            if ok and CFG.hitboxEnemy then
                local pl = Players:FindFirstChild(p.Name)
                ok = pl ~= nil and G.isEnemy(pl)
            end
            if ok then
                if not RT.hbOrig[p] then
                    RT.hbOrig[p] = { Size = p.Size, Transparency = p.Transparency, Material = p.Material, Color = p.Color }
                end
                local o = RT.hbOrig[p].Size
                local s = CFG.hitboxSize
                pcall(function()
                    p.Size = Vector3.new(math.max(o.X, s), math.max(o.Y, s), math.max(o.Z, s))
                    p.Transparency = math.clamp(CFG.hitboxTrans, 0, 1)
                    p.Material = Enum.Material.Neon
                    p.Color = Color3.fromRGB(255, 70, 90)
                end)
            elseif RT.hbOrig[p] then
                G.hbRestore(p)
            end
        end
    end
    for part in pairs(RT.hbOrig) do
        if not part.Parent then RT.hbOrig[part] = nil end
    end
end

function F.hitbox()
    unbind("hitbox")
    if not CFG.hitbox then
        G.hbRestoreAll()
        return
    end
    G.hbApply()
    local last = 0
    bind("hitbox", RunService.Heartbeat:Connect(function()
        if not CFG.hitbox then return end
        local now = os.clock()
        local carrying = G.carrying()
        if carrying ~= RT.hbCarry then
            RT.hbCarry = carrying
            last = 0
        end
        if now - last < 0.25 then return end
        last = now
        G.hbApply()
    end))
end

function F.cwalk()
    unbind("cwalk")
    if not CFG.cwalk then return end
    bind("cwalk", RunService.Heartbeat:Connect(function(dt)
        if not CFG.cwalk then return end
        if RT.ds or RT.dsFreeze then return end
        local _, hrp, hum = G.char()
        if not hrp or not hum then return end
        if hum.Health <= 0 or hum.Sit then return end
        local base = hum.WalkSpeed
        if base <= 0 then return end
        local extra = math.min(CFG.cwalkVal, 30) - base
        if extra <= 0 then return end
        local step = math.min(extra * dt, 8)
        local dir
        if RT.followGoal and os.clock() - (RT.followGoalT or 0) < 0.25 then
            local g = RT.followGoal
            local flat = Vector3.new(g.X - hrp.Position.X, 0, g.Z - hrp.Position.Z)
            local left = flat.Magnitude - base * dt - 2
            if left <= 0 then return end
            step = math.min(step, left)
            dir = flat.Unit
        else
            local md = hum.MoveDirection
            if md.Magnitude < 0.1 then return end
            dir = md.Unit
        end
        pcall(function() hrp.CFrame = hrp.CFrame + dir * step end)
    end))
end

local function hbClear()
    if RT.hbAdorn then
        for _, a in pairs(RT.hbAdorn) do pcall(function() a:Destroy() end) end
    end
    RT.hbAdorn = {}
    if RT.pullBall then pcall(function() RT.pullBall:Destroy() end) end
    RT.pullBall = nil
end

function F.hbShow()
    unbind("hbshow")
    if not CFG.hbShow then hbClear() return end
    RT.hbAdorn = RT.hbAdorn or {}
    local last = 0
    bind("hbshow", RunService.Heartbeat:Connect(function()
        if not CFG.hbShow then return end
        local now = os.clock()
        if now - last < 0.2 then return end
        last = now
        local h = G.hitboxes()
        if h then
            for _, part in ipairs(h:GetChildren()) do
                if part:IsA("BasePart") then
                    local a = RT.hbAdorn[part]
                    if not a or not a.Parent then
                        a = Instance.new("SelectionBox")
                        a.LineThickness = 0.045
                        a.Transparency = 0.15
                        a.SurfaceTransparency = 0.88
                        a.Adornee = part
                        a.Parent = part
                        RT.hbAdorn[part] = a
                    end
                    local mine = part.Name == LP.Name
                    a.Color3 = mine and Color3.fromRGB(90, 200, 255) or Color3.fromRGB(255, 80, 95)
                    a.SurfaceColor3 = a.Color3
                end
            end
            for part, a in pairs(RT.hbAdorn) do
                if not part.Parent or part.Parent ~= h then
                    pcall(function() a:Destroy() end)
                    RT.hbAdorn[part] = nil
                end
            end
        end
        local _, hrp = G.char()
        if hrp then
            if not RT.pullBall or not RT.pullBall.Parent then
                pcall(function()
                    local b = Instance.new("Part")
                    b.Name = "TZrange"
                    b.Shape = Enum.PartType.Ball
                    b.Anchored = true
                    b.CanCollide = false
                    b.CanTouch = false
                    pcall(function() b.CanQuery = false end)
                    b.Material = Enum.Material.ForceField
                    b.Color = Color3.fromRGB(120, 190, 255)
                    b.Transparency = 0.82
                    b.Parent = Workspace
                    RT.pullBall = b
                end)
            end
            if RT.pullBall then
                local r = CFG.pull and CFG.pullMax or CFG.catchRadius
                pcall(function()
                    RT.pullBall.Size = Vector3.new(r * 2, r * 2, r * 2)
                    RT.pullBall.CFrame = CFrame.new(hrp.Position)
                end)
            end
        end
    end))
end

function F.attackDir()
    local gf = G.gameFolder()
    local rep = gf and gf:FindFirstChild("Replicated")
    if not rep then return RT.tdDir end
    local sc = rep:FindFirstChild("ScrimmageLine")
    sc = sc and sc:FindFirstChild("Scrimmage")
    local fd = rep:FindFirstChild("FirstDownLine")
    fd = fd and fd:FindFirstChild("FirstDown")
    if sc and fd then
        local d = fd.Position.X - sc.Position.X
        if math.abs(d) > 0.5 then
            RT.tdDir = d > 0 and 1 or -1
        end
    end
    return RT.tdDir
end

function F.tdDir()
    local mine = G.teamOf(LP)
    local ib = G.sv("InterceptedBy")
    local intPlay = ib == LP or G.sv("IsInterceptionPlay") == true
    if intPlay and not CFG.tdInt then return nil end
    if mine then
        local ns, ss = G.sv("NorthScorer"), G.sv("SouthScorer")
        if ns == mine then return -1 end
        if ss == mine then return 1 end
    end
    local dir = F.attackDir()
    if not dir then return nil end
    local pso = G.sv("PlayStartOffense")
    if intPlay or (mine ~= nil and pso ~= nil and pso ~= "" and pso ~= mine) then dir = -dir end
    return dir
end

function F.endzoneX()
    local dir = F.tdDir()
    if not dir then return nil end
    local gf = G.gameFolder()
    local loc = gf and gf:FindFirstChild("Local")
    local ez = loc and loc:FindFirstChild("Endzones")
    local north = ez and ez:FindFirstChild("NorthEndzone")
    local south = ez and ez:FindFirstChild("SouthEndzone")
    if north and south then
        return dir > 0 and math.max(north.Position.X, south.Position.X) or math.min(north.Position.X, south.Position.X)
    end
    return dir > 0 and 165 or -165
end

function F.landCatch()
    unbind("land")
    RT.landDone = nil
    if not CFG.landCatch then return end
    bind("land", RunService.Heartbeat:Connect(function()
        if not CFG.landCatch then return end
        if not G.carrying() then RT.landDone = nil RT.landGy = nil return end
        local _, hrp, hum = G.char()
        if not hrp or not hum then return end
        if not RT.landDone then
            RT.landDone = true
            RT.landGy = G.groundHrpY(hrp, hum)
            RT.tdGround = RT.landGy
        end
        local gy = RT.landGy or hrp.Position.Y
        if hrp.Position.Y - gy <= 1.5 then return end
        local v = hrp.AssemblyLinearVelocity
        if v.Y < -28 then
            pcall(function() hrp.AssemblyLinearVelocity = Vector3.new(v.X, -28, v.Z) end)
        end
    end))
end

function F.autoTD()
    unbind("autotd")
    if not CFG.autoTD then return end
    bind("autotd", RunService.Heartbeat:Connect(function(dt)
        if not CFG.autoTD then return end
        if RT.ds then return end
        if not G.carrying() then RT.tdGround = nil return end
        local _, hrp, hum = G.char()
        if not hrp then return end
        local ex = F.endzoneX()
        if not ex then return end
        if not RT.tdGround then RT.tdGround = G.groundHrpY(hrp, hum) end
        local y = hrp.Position.Y
        if y - RT.tdGround > 6 then y = RT.tdGround end
        local goal = Vector3.new(ex, y, hrp.Position.Z)
        local off = goal - hrp.Position
        if off.Magnitude < 2 then return end
        pcall(function()
            if CFG.tdGlide <= 0 then
                RT.tdStep = RT.tdStep or {}
                local target = G.stepJump(hrp, CFrame.new(goal, goal + Vector3.new(off.X > 0 and 1 or -1, 0, 0)), RT.tdStep)
                if target then hrp.CFrame = target end
            else
                local step = math.min(math.min(CFG.tdGlide, 40) * dt, off.Magnitude)
                hrp.CFrame = hrp.CFrame + off.Unit * step
            end
        end)
    end))
end

function F.reach()
    unbind("reach")
    if not CFG.reach then return end
    bind("reach", RunService.Heartbeat:Connect(function()
        if not CFG.reach then return end
        local h = G.hitboxes()
        local _, hrp = G.char()
        if not h or not hrp then return end
        local p = G.carrierBy("Enemy")
        if not p then return end
        local box = h:FindFirstChild(p.Name)
        if not box or not box:IsA("BasePart") then return end
        if (box.Position - hrp.Position).Magnitude <= CFG.reachDist then
            pcall(function() box.CFrame = hrp.CFrame end)
        end
    end))
end

function G.rsGame()
    local gid = G.gameId()
    if not gid or gid == "" then return nil end
    for _, root in ipairs({ ReplicatedStorage:FindFirstChild("Games"), ReplicatedStorage:FindFirstChild("MiniGames") }) do
        if root then
            local f = root:FindFirstChild(gid)
            if f then return f end
        end
    end
    return nil
end

function G.state()
    local s = G.rsGame()
    local v = s and s:FindFirstChild("ActiveState")
    return v and v:IsA("ValueBase") and tostring(v.Value) or ""
end

function G.fieldBounds()
    local gid = G.gameId() or ""
    RT.fb = RT.fb or {}
    local fb = RT.fb[gid]
    if fb then return fb end
    local gf = G.gameFolder()
    local ff = gf and gf:FindFirstChild("FieldFloor", true)
    if ff and ff:IsA("BasePart") then
        local c, sz = ff.Position, ff.Size
        fb = { c.X - sz.X / 2 + 1, c.X + sz.X / 2 - 1, c.Z - sz.Z / 2 + 1, c.Z + sz.Z / 2 - 1 }
    else
        fb = { -179, 179, -79, 79 }
    end
    RT.fb[gid] = fb
    return fb
end

function G.clampField(p)
    local fb = G.fieldBounds()
    return Vector3.new(math.clamp(p.X, fb[1], fb[2]), p.Y, math.clamp(p.Z, fb[3], fb[4]))
end

function G.sv(name)
    local s = G.rsGame()
    local gs = s and s:FindFirstChild("GameStatus")
    local v = gs and gs:FindFirstChild(name)
    if v and v:IsA("ValueBase") then return v.Value end
    return nil
end

function G.landingSpot(destY)
    local s = G.rsGame()
    local gs = s and s:FindFirstChild("GameStatus")
    local bi = gs and gs:FindFirstChild("BallInfo")
    if not bi then return nil end
    local t, o, p = bi:FindFirstChild("Target"), bi:FindFirstChild("Origin"), bi:FindFirstChild("Power")
    if not (t and o and p) then return nil end
    local sig = tostring(t.Value) .. tostring(o.Value) .. tostring(p.Value)
    local air = G.sv("BallInAir") == true
    local lsNow = os.clock()
    if air and (not RT.lsAir or lsNow - (RT.lsLast or 0) > 0.5) then
        RT.lsSig = sig
        RT.lsT = lsNow
    end
    RT.lsAir = air
    RT.lsLast = lsNow
    if air and sig == RT.lsSig and os.clock() - (RT.lsT or 0) < 0.3 then return nil end
    local fm = G.footballMath()
    if not fm or type(fm.GetLandingSpot) ~= "function" then return nil end
    local y = destY
    if not y then
        pcall(function()
            y = s.GameInstance.Value.Replicated.PrimaryPart.Position.Y + 0.4
        end)
    end
    if not y then
        local _, hrp = G.char()
        y = hrp and hrp.Position.Y - 2.5 or 0
    end
    local ok, cf = pcall(function() return fm:GetLandingSpot(t.Value, o.Value, p.Value, y) end)
    if not ok then return nil end
    if typeof(cf) == "CFrame" then return cf.Position end
    if typeof(cf) == "Vector3" then return cf end
    return nil
end

function G.ballAir()
    return G.sv("BallInAir") == true and not G.carrying() and G.carrier() == nil
end

function G.moveGoal(hum, hrp, pos)
    local goal = Vector3.new(pos.X, hrp.Position.Y, pos.Z)
    RT.followGoal = goal
    RT.followGoalT = os.clock()
    hum:MoveTo(goal)
end

function G.boxFlag(name)
    local rep = LP:FindFirstChild("Replicated")
    local tb = rep and rep:FindFirstChild("TackleBox")
    local box = tb and tb.Value
    if not box then return nil end
    local c = box:FindFirstChild(name)
    if c and c:IsA("ValueBase") then return c.Value end
    return box:GetAttribute(name)
end

function F.landEsp()
    unbind("landesp")
    if RT.landPart then pcall(function() RT.landPart:Destroy() end) RT.landPart = nil end
    if not CFG.landEsp then return end
    local part = Instance.new("Part")
    part.Name = "TZland"
    part.Anchored = true
    part.CanCollide = false
    pcall(function() part.CanQuery = false end)
    pcall(function() part.CanTouch = false end)
    part.Shape = Enum.PartType.Cylinder
    part.Size = Vector3.new(0.4, 7, 7)
    part.Material = Enum.Material.Neon
    part.Color = Color3.fromRGB(90, 200, 255)
    part.Transparency = 1
    part.Parent = Workspace.CurrentCamera or Workspace
    RT.landPart = part
    local last = 0
    bind("landesp", RunService.Heartbeat:Connect(function()
        if not CFG.landEsp then return end
        local now = os.clock()
        if now - last < 0.05 then return end
        last = now
        local pos = G.ballAir() and G.landingSpot() or nil
        if pos then
            part.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
            part.Transparency = 0.35
        else
            part.Transparency = 1
        end
    end))
end

function G.halt()
    local _, hrp, hum = G.char()
    RT.followGoal = nil
    if hrp and hum then pcall(function() hum:MoveTo(hrp.Position) end) end
end

function G.rushStep()
    if not CFG.rush or RT.ds then return end
    if G.sv("Hiked") ~= true or G.sv("BallInAir") == true then return end
    local mine = G.teamOf(LP)
    local off = G.sv("Offense")
    if not mine or not off or off == mine then return end
    local target = G.sv("ActiveCarrier")
    if typeof(target) ~= "Instance" or not target:IsA("Player") then target = G.sv("ActiveQuarterback") end
    if typeof(target) ~= "Instance" or not target:IsA("Player") or not G.isEnemy(target) then return end
    local tc = target.Character
    local tr = tc and tc:FindFirstChild("HumanoidRootPart")
    local _, hrp, hum = G.char()
    if not tr or not hrp or not hum or hum.Health <= 0 then return end
    RT.rushing = true
    local v = tr.AssemblyLinearVelocity
    local dist = (tr.Position - hrp.Position).Magnitude
    local spd = math.max(hum.WalkSpeed, CFG.cwalk and CFG.cwalkVal or 0, 1)
    local lead = math.min(dist / spd, 1)
    G.moveGoal(hum, hrp, tr.Position + Vector3.new(v.X, 0, v.Z) * lead)
end

function F.rush()
    unbind("rush")
    if RT.rushing then G.halt() end
    RT.rushing = false
    if not CFG.rush then return end
    bind("rush", RunService.Heartbeat:Connect(function()
        local was = RT.rushing
        RT.rushing = false
        G.rushStep()
        if was and not RT.rushing then G.halt() end
    end))
end

function G.interceptStep()
    if not CFG.intercept or RT.ds then return end
    if not G.ballAir() then return end
    local mine = G.teamOf(LP)
    local off = G.sv("Offense")
    if not mine or not off or off == mine then return end
    local thrower = G.sv("ActiveCarrier")
    if typeof(thrower) ~= "Instance" or not thrower:IsA("Player") or not G.isEnemy(thrower) then return end
    local spot = G.landingSpot()
    local _, hrp, hum = G.char()
    if not spot or not hrp or not hum or hum.Health <= 0 then return end
    if (spot - hrp.Position).Magnitude > CFG.interceptRange then return end
    RT.intercepting = true
    G.moveGoal(hum, hrp, spot)
    local b = G.ball()
    if b and G.catchWanted(b, hrp.Position, CFG.catchRadius) then G.fireCatch() end
end

function F.intercept()
    unbind("intercept")
    if RT.intercepting then G.halt() end
    RT.intercepting = false
    if not CFG.intercept then return end
    bind("intercept", RunService.Heartbeat:Connect(function()
        local was = RT.intercepting
        RT.intercepting = false
        G.interceptStep()
        if was and not RT.intercepting then G.halt() end
    end))
end

function F.autoBlock()
    unbind("block")
    if not CFG.autoBlock then return end
    local last = 0
    bind("block", RunService.Heartbeat:Connect(function()
        if not CFG.autoBlock then return end
        local now = os.clock()
        if now - last < 1.6 then return end
        if G.sv("Hiked") ~= true or G.sv("BallInAir") == true or G.carrying() then return end
        if G.boxFlag("Blocking") == true then return end
        if G.boxFlag("BlockingCooldown") == false then return end
        local _, hrp = G.char()
        if not hrp then return end
        local near = false
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character and G.isEnemy(p) then
                local r = p.Character:FindFirstChild("HumanoidRootPart")
                if r and (r.Position - hrp.Position).Magnitude <= CFG.blockRange then near = true break end
            end
        end
        if not near then return end
        last = now
        G.fire("Blocking", true)
    end))
end

function F.bighead()
    unbind("bighead")
    RT.headOrig = RT.headOrig or {}
    if not CFG.bighead then
        for hd, o in pairs(RT.headOrig) do
            pcall(function()
                hd.Size = o[1]
                hd.Transparency = o[2]
                hd.CanCollide = o[3]
            end)
            RT.headOrig[hd] = nil
        end
        return
    end
    local last = 0
    bind("bighead", RunService.Heartbeat:Connect(function()
        if not CFG.bighead then return end
        local now = os.clock()
        if now - last < 0.25 then return end
        last = now
        local s = CFG.bigheadSize
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p.Character then
                local hd = p.Character:FindFirstChild("Head")
                if hd and hd:IsA("BasePart") then
                    if not RT.headOrig[hd] then
                        RT.headOrig[hd] = { hd.Size, hd.Transparency, hd.CanCollide }
                    end
                    pcall(function() hd.Size = Vector3.new(s, s, s) hd.Transparency = 0.5 hd.CanCollide = true end)
                end
            end
        end
    end))
end

function F.esp()
    unbind("esp")
    if not (CFG.espBall or CFG.espCarrier or CFG.espPlayers) then
        clearHighlights()
        return
    end
    local last = 0
    bind("esp", RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if now - last < 0.15 then return end
        last = now
        if CFG.espBall then
            local b = G.ball()
            highlight("ball", b, Color3.fromRGB(255, 190, 60))
        else highlight("ball", nil) end

        if CFG.espCarrier then
            local p = G.carrier()
            highlight("carrier", p and p.Character or nil, Color3.fromRGB(255, 70, 90))
        else highlight("carrier", nil) end

        if CFG.espPlayers then
            local mine = G.teamId()
            local seen = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and p.Character then
                    local key = "p_" .. p.Name
                    seen[key] = true
                    local rep = p:FindFirstChild("Replicated")
                    local tid = rep and rep:FindFirstChild("TeamID")
                    local same = tid and mine and tid.Value == mine
                    highlight(key, p.Character, same and Color3.fromRGB(90, 220, 150) or Color3.fromRGB(110, 170, 255))
                end
            end
            for k in pairs(RT.hl) do
                if k:sub(1, 2) == "p_" and not seen[k] then highlight(k, nil) end
            end
        else
            for k in pairs(RT.hl) do
                if k:sub(1, 2) == "p_" then highlight(k, nil) end
            end
        end
    end))
end

function F.antiAdmin(notify)
    unbind("admin")
    unbind("admin2")
    if not CFG.antiAdmin then return end
    local cb = ReplicatedStorage:FindFirstChild("CBAdmin")
    local staff = cb and cb:FindFirstChild("Staff")
    if not staff then return end
    RT.staffSeen = RT.staffSeen or {}
    local function alert(who)
        who = tostring(who)
        if RT.staffSeen[who] then return end
        RT.staffSeen[who] = true
        notify("Staff detected", who .. " is in this server")
    end
    local found = {}
    for _, s in ipairs(staff:GetChildren()) do
        if not RT.staffSeen[s.Name] then RT.staffSeen[s.Name] = true table.insert(found, s.Name) end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local r = p:FindFirstChild("CBAdminTempRank")
            if r and r.Value ~= "" then
                local k = p.Name .. " (" .. r.Value .. ")"
                if not RT.staffSeen[k] then RT.staffSeen[k] = true table.insert(found, k) end
            end
        end
    end
    if #found > 0 then
        local shown = {}
        for i = 1, math.min(#found, 3) do shown[i] = found[i] end
        notify("Staff in server", table.concat(shown, ", ") .. (#found > 3 and (" (+" .. (#found - 3) .. ")") or ""), 6)
    end
    bind("admin", staff.ChildAdded:Connect(function(c) alert(c.Name) end))
    bind("admin2", Players.PlayerAdded:Connect(function(p)
        task.delay(2, function()
            local r = p:FindFirstChild("CBAdminTempRank")
            if r and r.Value ~= "" then alert(p.Name .. " (" .. r.Value .. ")") end
        end)
    end))
end

function G.afkNudge()
    pcall(function()
        local vu = game:GetService("VirtualUser")
        vu:CaptureController()
        vu:ClickButton2(Vector2.new())
    end)
end

function G.afkGameConns(disable)
    if type(getconnections) ~= "function" then return 0 end
    local ok, list = pcall(getconnections, LP.Idled)
    if not ok or type(list) ~= "table" then return 0 end
    local n = 0
    for _, c in ipairs(list) do
        local f
        pcall(function() f = c.Function end)
        if type(f) == "function" then
            local src = ""
            pcall(function() src = tostring(debug.info(f, "s")) end)
            if src:find("PlayerEvents") then
                pcall(function() if disable then c:Disable() else c:Enable() end end)
                n = n + 1
            end
        end
    end
    return n
end

function F.antiAfk()
    unbind("afk")
    RT.afkLoop = nil
    if not CFG.antiAfk then
        if RT.afkDisabled then G.afkGameConns(false) RT.afkDisabled = nil end
        return
    end
    bind("afk", LP.Idled:Connect(G.afkNudge))
    if G.afkGameConns(true) > 0 then RT.afkDisabled = true end
    local token = {}
    RT.afkLoop = token
    task.spawn(function()
        local last = os.clock()
        while RT.alive and CFG.antiAfk and RT.afkLoop == token do
            task.wait(5)
            if not (RT.alive and CFG.antiAfk and RT.afkLoop == token) then break end
            if os.clock() - last >= 60 then
                last = os.clock()
                G.afkNudge()
                if G.afkGameConns(true) > 0 then RT.afkDisabled = true end
            end
            local rep = LP:FindFirstChild("Replicated")
            local afk = rep and rep:FindFirstChild("AFK")
            if afk and afk.Value == true and os.clock() - (RT.afkClearT or 0) > 10 then
                RT.afkClearT = os.clock()
                local ev = G.remotes()
                if ev then pcall(function() ev:FireServer("AFK") end) end
            end
        end
    end)
end

function F.aimTarget()
    local mine = G.teamId()
    local cam = Workspace.CurrentCamera
    local touch = UserInputService.TouchEnabled or GENV.ChronixForceMobile
    local m = (not touch) and LP:GetMouse() or nil
    local _, me = G.char()
    local mates, foes = {}, {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local rel = G.relation(p)
                if rel == "team" or (not mine and rel ~= "enemy") then
                    mates[#mates + 1] = { p = p, hrp = hrp }
                elseif rel == "enemy" then
                    foes[#foes + 1] = hrp
                end
            end
        end
    end
    local best, bestScore = nil, -math.huge
    for _, e in ipairs(mates) do
        local score
        if m and cam then
            local sp, vis = cam:WorldToViewportPoint(e.hrp.Position)
            if vis then score = -(Vector2.new(m.X, m.Y) - Vector2.new(sp.X, sp.Y)).Magnitude end
        else
            local nearest = math.huge
            for _, f in ipairs(foes) do nearest = math.min(nearest, (f.Position - e.hrp.Position).Magnitude) end
            if nearest == math.huge then nearest = 100 end
            local dist = me and (e.hrp.Position - me.Position).Magnitude or 0
            score = math.min(nearest, 40) - dist * 0.1
        end
        if score and score > bestScore then best, bestScore = e.p, score end
    end
    return best
end

function G.fieldY()
    local s = G.rsGame()
    local y
    pcall(function() y = s.GameInstance.Value.Replicated.Center.CFrame.Y + 0.5 end)
    if not y then pcall(function() y = s.GameInstance.Value.Replicated.PrimaryPart.Position.Y + 0.4 end) end
    return y
end

function G.passSolve(origin, dest, vel, power)
    local caps = { math.clamp(power, 30, 100) * 0.95, 95 }
    for _, cap in ipairs(caps) do
        local t = 0.15
        while t <= 6 do
            local d = dest + vel * t
            local v = (d - origin) / t - BALL_G * (0.5 * t)
            if v.Magnitude <= cap then
                return v.Unit, math.clamp(v.Magnitude / 0.95, 30, 100), t
            end
            t = t + 0.02
        end
    end
    return nil
end

function G.passPlan(p)
    local hrp = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
    local _, me = G.char()
    if not hrp or not me then return nil end
    local origin = me.Position + Vector3.new(0, 1.5, 0)
    local gy = G.fieldY() or (hrp.Position.Y - 3)
    local dest = Vector3.new(hrp.Position.X, gy + 3, hrp.Position.Z)
    local v = hrp.AssemblyLinearVelocity
    local lead = Vector3.new(v.X, 0, v.Z) * CFG.aimLead
    local dir, pw, t = G.passSolve(origin, dest, lead, CFG.aimPower)
    if not dir then return nil end
    return { origin = origin, dir = dir, power = pw, time = t }
end

function G.passRisk(plan)
    local a = { origin = plan.origin, velocity = plan.dir * plan.power * 0.95, gravity = BALL_G, flightTime = plan.time }
    local who, when
    for _, q in ipairs(Players:GetPlayers()) do
        if q ~= LP and G.isEnemy(q) then
            local d = G.arcDefender(q)
            if d then
                local t = G.arcIntercept(a, d)
                if t and t > 0.1 and t < plan.time - 0.15 and (not when or t < when) then who, when = q, t end
            end
        end
    end
    return who, when
end

local MH_NOLEAD = {
    [120] = { { 324, 230 }, { 335, 250 }, { 355, 320 }, { 360, 370 }, { 380, 420 }, { 317, 260 } },
    [100] = { { 40, 6 }, { 50, 9 }, { 60, 13 }, { 70, 17 }, { 80, 21 }, { 90, 23 }, { 100, 24 }, { 110, 28 }, { 120, 32 }, { 130, 36 }, { 140, 40 }, { 150, 44 }, { 160, 50 }, { 170, 55 }, { 178, 65 }, { 190, 75 }, { 200, 85 }, { 220, 95 }, { 233, 105 }, { 264, 140 }, { 274, 170 }, { 317, 200 }, { 332, 220 }, { 360, 270 } },
    [80] = { { 4, 2 }, { 13, 4 }, { 31, 6 }, { 33, 7 }, { 40, 8 }, { 50, 13 }, { 60, 15 }, { 68, 18 }, { 75, 20 }, { 80, 12 }, { 89, 13 }, { 100, 15 }, { 150, 38 }, { 170, 55 }, { 185, 70 }, { 200, 120 }, { 233, 140 }, { 264, 180 }, { 274, 210 }, { 317, 220 }, { 332, 250 } },
}
local MH_LEAD = {
    [120] = { { 324, 250 }, { 335, 270 }, { 355, 340 }, { 360, 390 } },
    [100] = { { 40, 15 }, { 45, 15 }, { 50, 16 }, { 55, 17 }, { 60, 18 }, { 65, 18 }, { 70, 20 }, { 75, 21 }, { 80, 22 }, { 85, 23 }, { 90, 25 }, { 95, 27 }, { 100, 28 }, { 105, 30 }, { 110, 32 }, { 115, 34 }, { 120, 36 }, { 125, 39 }, { 130, 41 }, { 135, 44 }, { 140, 46 }, { 145, 49 }, { 150, 52 }, { 155, 55 }, { 160, 58 }, { 165, 61 }, { 170, 64 }, { 175, 68 }, { 180, 71 }, { 185, 75 }, { 190, 79 }, { 195, 82 }, { 200, 86 }, { 205, 90 }, { 210, 95 }, { 215, 99 }, { 220, 103 }, { 225, 108 }, { 230, 112 }, { 235, 117 }, { 240, 122 }, { 245, 127 }, { 250, 132 }, { 255, 137 }, { 260, 142 }, { 265, 148 }, { 270, 153 }, { 275, 159 }, { 280, 165 }, { 285, 171 }, { 290, 176 }, { 295, 183 }, { 300, 189 }, { 305, 195 }, { 310, 201 }, { 315, 208 }, { 320, 214 }, { 325, 221 }, { 330, 228 }, { 332, 231 }, { 335, 235 } },
    [80] = { { 4, 7 }, { 13, 7 }, { 31, 9 }, { 33, 10 }, { 40, 11 }, { 50, 13 }, { 54, 14 }, { 60, 16 }, { 80, 23 }, { 89, 26 }, { 100, 31 }, { 150, 61 }, { 170, 76 }, { 185, 88 }, { 200, 102 } },
}
local MH_GRAV = Workspace.Gravity or 196.2
RT.mhState = {}
RT.mhHist = {}

function G.mhInterp(tbl, power, d)
    local pts = tbl[power]
    if not pts then return 3 end
    if d <= pts[1][1] then return pts[1][2] end
    if d >= pts[#pts][1] then return pts[#pts][2] end
    for j = 2, #pts do
        local y0, x0, y1, x1 = pts[j - 1][2], pts[j - 1][1], pts[j][2], pts[j][1]
        if d == x1 then return y1 end
        if d < x1 then return y0 + (d - x0) / (x1 - x0) * (y1 - y0) end
    end
    return pts[#pts][2]
end

function G.mhTrack(p, pos, vel)
    local s = RT.mhState[p] or { lastPos = pos, lastVel = vel, acc = Vector3.new(), history = {} }
    local acc = vel - s.lastVel
    table.insert(s.history, 1, vel)
    if #s.history > 5 then table.remove(s.history) end
    local sum = Vector3.new(0, 0, 0)
    for _, v in ipairs(s.history) do sum = sum + v end
    s.lastPos, s.lastVel, s.acc, s.avgVel = pos, vel, acc, sum / #s.history
    RT.mhState[p] = s
    return s
end

function G.mhRoute(h)
    if #h < 4 then return "unknown", false end
    local a, prev, prev2, b = h[#h], h[#h - 1], h[#h - 2], h[#h - 3]
    local dir = (a - b).Unit
    local ang = math.acos(math.clamp(dir:Dot((a - prev).Unit), -1, 1)) * (180 / math.pi)
    local comeback = ang > 60 and (a - prev).Magnitude < (prev2 - b).Magnitude * 0.7
    local r
    if math.abs(dir.X) < 0.3 and dir.Z > 0.7 then r = "streak"
    elseif dir.X > 0.7 and dir.Z > 0.5 then r = "corner_right"
    elseif dir.X < -0.7 and dir.Z > 0.5 then r = "corner_left"
    elseif dir.X > 0.7 and math.abs(dir.Z) < 0.3 then r = "out_right"
    elseif dir.X < -0.7 and math.abs(dir.Z) < 0.3 then r = "out_left"
    elseif dir.X > 0.7 and dir.Z < -0.5 then r = "slant_right"
    elseif dir.X < -0.7 and dir.Z < -0.5 then r = "slant_left"
    elseif dir.Z < -0.5 and ang > 90 then r = "curl"
    else r = "streak" end
    return r, comeback
end

function G.mhSolve(from, to, power)
    local speed = 40 + power / 100 * 80
    local unit = (to - from).Unit
    local horiz = Vector3.new(to.X - from.X, 0, to.Z - from.Z).Magnitude
    local bestErr, bestT, landing = math.huge, nil, nil
    for i = math.rad(5), math.rad(85), math.rad(0.25) do
        local vx = speed * math.cos(i)
        local t = horiz / vx
        local err = math.abs(from.Y + speed * math.sin(i) * t - 0.5 * MH_GRAV * t ^ 2 - to.Y)
        if err < bestErr then
            bestErr, bestT = err, t
            landing = Vector3.new(from.X + unit.X * vx * t, 3, from.Z + unit.Z * vx * t)
        end
    end
    return landing, bestT
end

function G.mhNearestMouse()
    local m = LP:GetMouse()
    local cam = Workspace.CurrentCamera
    local best, bd = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp and cam then
                local sp, vis = cam:WorldToViewportPoint(hrp.Position)
                if vis then
                    local d = (Vector2.new(m.X, m.Y) - Vector2.new(sp.X, sp.Y)).Magnitude
                    if d < bd then bd, best = d, p end
                end
            end
        end
    end
    return best
end

function G.mhFireThrow(aim, power)
    local payload = { Target = aim, AutoThrow = false, Power = power }
    local RS = game:GetService("ReplicatedStorage")
    local mg = Workspace:FindFirstChild("MiniGames")
    if mg and #mg:GetChildren() > 0 then
        for _, m in ipairs(mg:GetChildren()) do
            local r = m:IsA("Model") and m:FindFirstChild("Replicated")
            local st = r and r:IsA("Model") and r:FindFirstChild("SpotTags")
            if st and st:IsA("Folder") then
                local f = RS:FindFirstChild("MiniGames") and RS.MiniGames:FindFirstChild(m.Name)
                local ev = f and f:FindFirstChild("ReEvent")
                if ev then ev:FireServer("Mechanics", "ThrowBall", payload) return true end
            end
        end
    end
    local games = Workspace:FindFirstChild("Games")
    if games and #games:GetChildren() > 0 then
        for _, g in ipairs(games:GetChildren()) do
            local r = g:IsA("Model") and g:FindFirstChild("Replicated")
            local sp = r and r:IsA("Model") and r:FindFirstChild("ActiveSpots")
            if sp and sp:IsA("Folder") then
                local f = RS:FindFirstChild("Games") and RS.Games:FindFirstChild(g.Name)
                local ev = f and f:FindFirstChild("ReEvent")
                if ev then ev:FireServer("Mechanics", "ThrowBall", payload) return true end
            end
        end
    end
    return G.fire("ThrowBall", payload)
end

function F.throwTo(p)
    if not p then return false, "no player selected - press H first" end
    local ch = Workspace:FindFirstChild(LP.Name)
    local ball = ch and ch:FindFirstChild("Football")
    if not ball then return false, "no football found" end
    local bp = ball.Position
    local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false, "target has no character" end
    local tp = hrp.Position
    local s = G.mhTrack(p, tp, hrp.Velocity)
    local spd = s.avgVel and s.avgVel.Magnitude or 0
    local dist = (bp - tp).Magnitude
    table.insert(RT.mhHist, tp)
    if #RT.mhHist > 5 then table.remove(RT.mhHist, 1) end
    local route, comeback = G.mhRoute(RT.mhHist)
    local power
    if dist < 80 and (route == "curl" or route == "comeback" or route == "out_right" or route == "out_left") then
        power = 80
    elseif dist > 200 then
        power = 120
    elseif spd > 3 then
        power = 100
    else
        power = 80
    end
    local aim
    if spd > 3 then
        local a = tp
        for _ = 1, 3 do
            local _, ft = G.mhSolve(bp, a, power)
            ft = ft or 0
            if comeback then
                a = tp + s.avgVel.Unit * math.min(s.avgVel.Magnitude, 12)
            elseif route == "streak" then
                a = tp + s.avgVel * ft * 1.1
            elseif route == "corner_right" or route == "corner_left" or route == "slant_right" or route == "slant_left" or route == "out_right" or route == "out_left" then
                a = tp + s.avgVel * ft * 2.05
            elseif route == "curl" or route == "comeback" then
                a = tp
            else
                a = tp + s.avgVel * ft
            end
        end
        local fd = (Vector3.new(a.X, bp.Y, a.Z) - bp).Magnitude
        local h = G.mhInterp(MH_LEAD, power, fd)
        if route == "streak" then h = h - 6 elseif fd > 280 then h = h + 6.2 elseif fd > 150 then h = h + 4.2 end
        aim = Vector3.new(a.X, h, a.Z)
    else
        aim = Vector3.new(tp.X, G.mhInterp(MH_NOLEAD, power, (tp - bp).Magnitude), tp.Z)
    end
    RT.lastThrow = { target = p.Name, power = power, route = route, aim = aim, t = os.clock() }
    if not G.mhFireThrow(aim, power) then return false, "throw remote not found" end
    return true
end

sweepOrphans()

local Win = Prism.new({ Name = "Topaz v2.0  ·  Ultimate Football", Width = 620, Height = 430 })
RT.hlRoot = Win.Gui
watermark()

local function notify(title, content, dur)
    Win:Notify({ Title = title, Content = content, Duration = dur or 3 })
end
RT.notify = notify

local GP_MAP = {
    { "gpWalk", "gpWalkVal", "WalkSpeed" },
    { "gpJump", "gpJumpVal", "JumpPower" },
    { "gpDive", "gpDiveVal", "DivePower" },
    { "gpRegen", "gpRegenVal", "SprintStaminaRegenRate" },
    { "gpDrain", "gpDrainVal", "SprintStaminaDepleteRate" },
}

function G.gpFolder()
    local s = G.rsGame()
    local f = s and s:FindFirstChild("GameParams")
    if f then return f end
    for _, n in ipairs({ "Games", "MiniGames" }) do
        local r = ReplicatedStorage:FindFirstChild(n)
        if r then
            for _, c in ipairs(r:GetChildren()) do
                local g = c:FindFirstChild("GameParams")
                if g then return g end
            end
        end
    end
    return nil
end

function G.gpRestore(all)
    RT.gpOrig = RT.gpOrig or {}
    for v, o in pairs(RT.gpOrig) do
        local active = false
        if not all then
            for _, e in ipairs(GP_MAP) do
                if e[3] == v.Name and CFG[e[1]] then active = true end
            end
        end
        if not active then
            if v.Parent then RT.gpWriting = true pcall(function() v.Value = o end) RT.gpWriting = false end
            RT.gpOrig[v] = nil
        end
    end
end

function G.gpApply()
    local f = G.gpFolder()
    if not f then return end
    RT.gpOrig = RT.gpOrig or {}
    RT.gpConn = RT.gpConn or {}
    for _, e in ipairs(GP_MAP) do
        local v = f:FindFirstChild(e[3])
        if v and v:IsA("NumberValue") and CFG[e[1]] then
            if RT.gpOrig[v] == nil then RT.gpOrig[v] = v.Value end
            if not RT.gpConn[v] then
                RT.gpConn[v] = v:GetPropertyChangedSignal("Value"):Connect(function()
                    if RT.gpWriting or not RT.alive then return end
                    for _, x in ipairs(GP_MAP) do
                        if x[3] == v.Name and CFG[x[1]] and v.Value ~= CFG[x[2]] then
                            RT.gpWriting = true pcall(function() v.Value = CFG[x[2]] end) RT.gpWriting = false
                        end
                    end
                end)
            end
            if v.Value ~= CFG[e[2]] then RT.gpWriting = true pcall(function() v.Value = CFG[e[2]] end) RT.gpWriting = false end
        end
    end
end

function F.gameParams()
    unbind("gp")
    unbind("gpHum")
    G.gpRestore(false)
    if RT.gpConn then
        for v, c in pairs(RT.gpConn) do
            if not v.Parent or RT.gpOrig[v] == nil then pcall(function() c:Disconnect() end) RT.gpConn[v] = nil end
        end
    end
    if CFG.gravity then
        if RT.gravOrig == nil then RT.gravOrig = Workspace.Gravity end
        Workspace.Gravity = CFG.gravityVal
        bind("gravity", Workspace:GetPropertyChangedSignal("Gravity"):Connect(function()
            if CFG.gravity and Workspace.Gravity ~= CFG.gravityVal then Workspace.Gravity = CFG.gravityVal end
        end))
    else
        unbind("gravity")
        if RT.gravOrig ~= nil then Workspace.Gravity = RT.gravOrig RT.gravOrig = nil end
    end
    local any = false
    for _, e in ipairs(GP_MAP) do if CFG[e[1]] then any = true end end
    if not any then
        if RT.gpHumOrig and RT.gpHum and RT.gpHum.Parent and not CFG.walk then pcall(function() RT.gpHum.WalkSpeed = RT.gpHumOrig end) end
        RT.gpHum, RT.gpHumOrig = nil, nil
        return
    end
    G.gpApply()
    local last = 0
    bind("gp", RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if CFG.gpWalk and not CFG.walk then
            local _, _, hum = G.char()
            if hum and hum ~= RT.gpHum then
                unbind("gpHum")
                RT.gpHum = hum
                RT.gpHumOrig = RT.gpHumOrig or hum.WalkSpeed
                bind("gpHum", hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
                    if CFG.gpWalk and not CFG.walk and math.abs(hum.WalkSpeed - CFG.gpWalkVal) > 0.01 then hum.WalkSpeed = CFG.gpWalkVal end
                end))
            end
            if hum and math.abs(hum.WalkSpeed - CFG.gpWalkVal) > 0.01 then pcall(function() hum.WalkSpeed = CFG.gpWalkVal end) end
        end
        if now - last < 1 then return end
        last = now
        G.gpApply()
    end))
end

function G.ownHbParts()
    local t = {}
    local rep = LP:FindFirstChild("Replicated")
    local tb = rep and rep:FindFirstChild("TackleBox")
    local v = tb and tb.Value
    if v and v:IsA("BasePart") then t[#t + 1] = v end
    local h = G.hitboxes()
    local m = h and h:FindFirstChild(LP.Name)
    if m and m:IsA("BasePart") and m ~= v then t[#t + 1] = m end
    return t
end

function G.ownHbRestore()
    RT.ownOrig = RT.ownOrig or {}
    for p, o in pairs(RT.ownOrig) do
        if RT.ownConn and RT.ownConn[p] then
            for _, c in ipairs(RT.ownConn[p]) do pcall(function() c:Disconnect() end) end
            RT.ownConn[p] = nil
        end
        if p.Parent then
            RT.ownWriting = true
            pcall(function() p.Size = o.Size p.Transparency = o.Transparency end)
            RT.ownWriting = false
        end
        RT.ownOrig[p] = nil
    end
end

function G.ownHbSet(p)
    local s = Vector3.new(CFG.ownX, CFG.ownY, CFG.ownZ)
    RT.ownWriting = true
    pcall(function()
        if p.Size ~= s then p.Size = s end
        if p.Transparency ~= CFG.ownTrans then p.Transparency = CFG.ownTrans end
    end)
    RT.ownWriting = false
end

function G.ownHbApply()
    RT.ownOrig = RT.ownOrig or {}
    RT.ownConn = RT.ownConn or {}
    for _, p in ipairs(G.ownHbParts()) do
        if not RT.ownOrig[p] then
            RT.ownOrig[p] = { Size = p.Size, Transparency = p.Transparency }
            local function back()
                if RT.ownWriting or not CFG.ownHb then return end
                task.delay(0.05, function() if CFG.ownHb and p.Parent then G.ownHbSet(p) end end)
            end
            RT.ownConn[p] = {
                p:GetPropertyChangedSignal("Size"):Connect(back),
                p:GetPropertyChangedSignal("Transparency"):Connect(back),
            }
        end
        G.ownHbSet(p)
    end
    for p in pairs(RT.ownOrig) do
        if not p.Parent then
            if RT.ownConn[p] then for _, c in ipairs(RT.ownConn[p]) do pcall(function() c:Disconnect() end) end RT.ownConn[p] = nil end
            RT.ownOrig[p] = nil
        end
    end
end

function F.ownHb()
    unbind("ownHb")
    if not CFG.ownHb then G.ownHbRestore() return end
    G.ownHbApply()
    local last = 0
    bind("ownHb", RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if now - last < 0.5 then return end
        last = now
        G.ownHbApply()
    end))
end

local OWN_PRESETS = {
    ["Default (2.52)"] = { 2.52, 5.4, 1.41 },
    ["Small (2.7)"] = { 2.7, 5.8, 1.65 },
    ["Medium (3.1)"] = { 3.1, 5.8, 1.7 },
    ["Tiny (0.1)"] = { 0.1, 0.1, 0.1 },
}
local OWN_PRESET_ORDER = { "Default (2.52)", "Small (2.7)", "Medium (3.1)", "Tiny (0.1)" }
local ownSliders = {}

function G.ownPreset(name)
    local p = OWN_PRESETS[name]
    if not p then return end
    CFG.ownX, CFG.ownY, CFG.ownZ = p[1], p[2], p[3]
    if ownSliders.x then ownSliders.x:Set(p[1], true) ownSliders.y:Set(p[2], true) ownSliders.z:Set(p[3], true) end
    if CFG.ownHb then G.ownHbApply() end
end

function G.hcStrip(c)
    for _, d in ipairs(c:GetDescendants()) do
        if d:IsA("Decal") or d:IsA("Texture") or d:IsA("SurfaceAppearance") or d:IsA("JointInstance") or d:IsA("Constraint") or d:IsA("Script") or d:IsA("LocalScript") then
            d:Destroy()
        elseif d:IsA("SpecialMesh") then
            pcall(function() d.TextureId = "" end)
        end
    end
    if c:IsA("MeshPart") then pcall(function() c.TextureID = "" end) end
end

function G.hcClearAll()
    if RT.hc then for _, c in pairs(RT.hc) do pcall(function() c:Destroy() end) end end
    RT.hc = {}
    for _, p in ipairs(Players:GetPlayers()) do
        local ch = p.Character
        if ch then for _, d in ipairs(ch:GetChildren()) do if d.Name == "TZhead" then pcall(function() d:Destroy() end) end end end
    end
end

function F.headClone()
    unbind("headClone")
    G.hcClearAll()
    if not CFG.headClone then return end
    local last = 0
    bind("headClone", RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if now - last < 0.3 then return end
        last = now
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                local ch = p.Character
                local hd = ch and ch:FindFirstChild("Head")
                local c = RT.hc[p]
                if hd and hd:IsA("BasePart") then
                    if not (c and c.Parent == ch) then
                        if c then pcall(function() c:Destroy() end) end
                        c = nil
                        local arch = hd.Archivable
                        hd.Archivable = true
                        local ok, cl = pcall(function() return hd:Clone() end)
                        hd.Archivable = arch
                        if ok and cl and cl:IsA("BasePart") then
                            cl.Name = "TZhead"
                            G.hcStrip(cl)
                            cl.CFrame = hd.CFrame
                            cl.Parent = ch
                            local w = Instance.new("WeldConstraint")
                            w.Part0 = hd
                            w.Part1 = cl
                            w.Parent = cl
                            c = cl
                            RT.hc[p] = cl
                        end
                    end
                    if c then
                        pcall(function()
                            for _, k in ipairs({ "Anchored", "Massless", "CanCollide", "CanTouch", "CanQuery", "CastShadow", "CollisionGroup", "Color", "Material" }) do
                                if c[k] ~= hd[k] then c[k] = hd[k] end
                            end
                            local s = hd.Size * CFG.headCloneSize
                            if c.Size ~= s then c.Size = s end
                            if c.Transparency ~= CFG.headCloneTrans then c.Transparency = CFG.headCloneTrans end
                            c.LocalTransparencyModifier = 0
                        end)
                    end
                elseif c then
                    pcall(function() c:Destroy() end)
                    RT.hc[p] = nil
                end
            end
        end
        for p, c in pairs(RT.hc) do
            if not p.Parent then pcall(function() c:Destroy() end) RT.hc[p] = nil end
        end
    end))
end

function F.sticky()
    unbind("sticky")
    if not CFG.sticky then return end
    bind("sticky", RunService.Heartbeat:Connect(function()
        if not CFG.sticky or RT.ds then return end
        local _, hrp, hum = G.char()
        if not hrp or not hum or hum.Health <= 0 then return end
        local best, bd = nil, CFG.stickyRange
        local qb = G.sv("ActiveQuarterback")
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p.Character and p ~= qb and (not CFG.stickyEnemy or G.isEnemy(p)) then
                local r = p.Character:FindFirstChild("HumanoidRootPart")
                local hd = p.Character:FindFirstChild("Head")
                if r and hd then
                    local d = (hrp.Position - r.Position).Magnitude
                    if d < bd then bd = d best = hd.Position + Vector3.new(0, 2.5, 0) end
                end
            end
        end
        if not best then return end
        local a = math.clamp((CFG.stickySmooth / 100) * (CFG.stickyStrength / 12), 0.01, 1)
        local np = hrp.Position:Lerp(best, a)
        pcall(function() hrp.CFrame = CFrame.new(np) * (hrp.CFrame - hrp.CFrame.Position) end)
    end))
end

function G.localFolder(needArc)
    local gf = G.gameFolder()
    local l = gf and gf:FindFirstChild("Local")
    local c = l and l:FindFirstChild("Center")
    if c and (not needArc or c:FindFirstChild("ThrowingArc", true)) then return l, c end
    for _, n in ipairs({ "Games", "MiniGames" }) do
        local r = Workspace:FindFirstChild(n)
        if r then
            for _, g in ipairs(r:GetChildren()) do
                local lf = g:FindFirstChild("Local")
                local cc = lf and lf:FindFirstChild("Center")
                local bm = cc and cc:FindFirstChild("ThrowingArc", true)
                if bm and bm:IsA("Beam") then return lf, cc end
            end
        end
    end
    return nil, nil
end

function G.attCF(a)
    if not (a and a.Parent) then return nil end
    local ok, v = pcall(function() return a.WorldCFrame end)
    if ok and typeof(v) == "CFrame" then return v end
    if a:IsA("Attachment") and a.Parent:IsA("BasePart") then return a.Parent.CFrame * a.CFrame end
    return nil
end

function G.beamArc(center, needEnabled)
    local beam = center and center:FindFirstChild("ThrowingArc", true)
    if not (beam and beam:IsA("Beam")) then return nil end
    if needEnabled and not beam.Enabled then return nil end
    local c0 = G.attCF(beam.Attachment0 or center:FindFirstChild("C2", true))
    local c1 = G.attCF(beam.Attachment1 or center:FindFirstChild("C3", true))
    if not (c0 and c1) then return nil end
    local p0 = c0.Position
    local p1 = p0 + c0.RightVector * beam.CurveSize0
    local p3 = c1.Position
    local p2 = p3 - c1.RightVector * beam.CurveSize1
    local g = Vector3.new(0, -28, 0)
    local acc = 3 * ((p3 - p2) - (p1 - p0))
    local tsq = acc.Y / g.Y
    if tsq <= 1e-6 then return nil end
    local T = math.sqrt(tsq)
    local vel = 3 * (p1 - p0) / T
    local fin = p0 + vel * T + 0.5 * g * T * T
    if (fin - p3).Magnitude > 0.2 then return nil end
    return { beam = beam, origin = p0, velocity = vel, gravity = g, flightTime = T, landY = p3.Y }
end

function G.arcAt(a, t)
    return a.origin + a.velocity * t + 0.5 * a.gravity * t * t
end

function G.arcDefender(p)
    local ch = p.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    local root = ch and ch:FindFirstChild("HumanoidRootPart")
    if not (hum and root) or hum.Health <= 0 then return nil end
    local box
    pcall(function()
        local v = p.Replicated.TackleBox.Value
        if v and v.Parent then
            if v:IsA("BasePart") then box = v else
                for _, n in ipairs({ "CatchBox", "PlayerCollisionBox" }) do
                    local x = v:FindFirstChild(n, true)
                    if x and x:IsA("BasePart") then box = x break end
                end
            end
        end
    end)
    local g = math.max(Workspace.Gravity, 1e-3)
    local jh = hum.UseJumpPower and (hum.JumpPower * hum.JumpPower) / (2 * g) or hum.JumpHeight
    local rise = hum.UseJumpPower and math.max(0, hum.JumpPower) / g or math.sqrt(2 * math.max(0, jh) / g)
    local spd = math.max(21, hum.WalkSpeed)
    local v = root.AssemblyLinearVelocity
    v = Vector3.new(v.X, 0, v.Z)
    if v.Magnitude > spd then v = v.Unit * spd end
    return { player = p, position = box and box.Position or root.Position, velocity = v, size = box and box.Size or root.Size, speed = spd, jump = jh, rise = math.max(1e-4, rise) }
end

function G.arcIntercept(a, d)
    local hr = math.max(d.size.X, d.size.Z) * 0.5
    local lo, up = -d.size.Y * 0.5, d.size.Y * 0.5
    local react = 0.12
    local fv = Vector3.new(a.velocity.X, 0, a.velocity.Z)
    local fwd = fv.Magnitude > 1e-6 and fv.Unit or nil
    local n = math.clamp(math.ceil(a.flightTime * 60), 48, 360)
    for i = 0, n do
        local t = a.flightTime * i / n
        local bp = G.arcAt(a, t)
        local ok = true
        if fwd then
            local dlt = bp - a.origin
            if Vector3.new(dlt.X, 0, dlt.Z):Dot(fwd) < -0.05 then ok = false end
        end
        if ok then
            local dp = d.position + d.velocity * math.min(t, react)
            local run = math.max(0, t - react)
            local dx, dz = dp.X - bp.X, dp.Z - bp.Z
            if math.sqrt(dx * dx + dz * dz) <= hr + d.speed * run then
                local jt = math.max(0, t - react)
                local j = jt >= d.rise and d.jump or d.jump * (2 * (jt / d.rise) - (jt / d.rise) ^ 2)
                if bp.Y >= dp.Y + j + lo and bp.Y <= dp.Y + j + up then return t, bp end
            end
        end
    end
    return nil
end

function G.arcRestore()
    if RT.arcCol then
        for b, c in pairs(RT.arcCol) do if b.Parent then pcall(function() b.Color = c end) end end
    end
    RT.arcCol = {}
end

function F.safeArc()
    unbind("safeArc")
    G.arcRestore()
    RT.arcInfo = nil
    if not CFG.safeArc then return end
    local last = 0
    bind("safeArc", RunService.RenderStepped:Connect(function()
        local now = os.clock()
        if now - last < 0.08 then return end
        last = now
        local _, center = G.localFolder(true)
        local a = G.beamArc(center, true)
        if not a then G.arcRestore() RT.arcInfo = nil return end
        local bad, who, when = false, nil, nil
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and G.isEnemy(p) then
                local d = G.arcDefender(p)
                if d then
                    local t = G.arcIntercept(a, d)
                    if t and (not when or t < when) then bad, who, when = true, p, t end
                end
            end
        end
        RT.arcCol = RT.arcCol or {}
        if RT.arcCol[a.beam] == nil then RT.arcCol[a.beam] = a.beam.Color end
        pcall(function()
            a.beam.Color = bad and ColorSequence.new(Color3.fromRGB(255, 70, 70)) or ColorSequence.new(Color3.fromRGB(70, 255, 120))
        end)
        RT.arcInfo = bad and (who.Name .. " can pick it at " .. string.format("%.2f", when) .. "s") or "safe"
    end))
end

function G.ringMake()
    local m = Instance.new("Model")
    m.Name = "TZring"
    local col = Color3.fromRGB(255, 45, 45)
    local function style(p)
        p.Anchored = true p.CanCollide = false p.CastShadow = false
        pcall(function() p.CanTouch = false p.CanQuery = false end)
    end
    local c = Instance.new("Part")
    c.Name = "Center"
    c.Shape = Enum.PartType.Ball
    c.Size = Vector3.new(3, 3, 3)
    c.Material = Enum.Material.SmoothPlastic
    c.Color = col
    c.Transparency = 0.5
    style(c)
    c.Parent = m
    m.PrimaryPart = c
    local rad, thick, arc, seg = 3, 0.28, math.rad(74), 12
    local len = 2 * (rad + thick * 0.5) * math.tan((arc / seg) * 0.5)
    for piece = 0, 2 do
        local pc = piece * (math.pi * 2 / 3)
        for s = 1, seg do
            local ang = pc - arc * 0.5 + arc * ((s - 0.5) / seg)
            local p = Instance.new("Part")
            p.Size = Vector3.new(len, 0.14, thick)
            p.Material = Enum.Material.Neon
            p.Color = col
            style(p)
            p.CFrame = CFrame.Angles(0, ang, 0) * CFrame.new(0, 0, -rad)
            p.Parent = m
        end
    end
    m.Parent = Workspace.CurrentCamera or Workspace
    return m
end

function G.groundY(pos, fallback)
    local ex = {}
    for _, p in ipairs(Players:GetPlayers()) do if p.Character then ex[#ex + 1] = p.Character end end
    if RT.ring then ex[#ex + 1] = RT.ring end
    local h = G.hitboxes()
    if h then ex[#ex + 1] = h end
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.IgnoreWater = true
    pcall(function() rp.RespectCanCollide = true end)
    for _ = 1, 12 do
        rp.FilterDescendantsInstances = ex
        local r = Workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -512, 0), rp)
        if not r then return fallback end
        local mdl = r.Instance
        while mdl and mdl ~= Workspace and not mdl:FindFirstChildOfClass("Humanoid") do mdl = mdl.Parent end
        if not mdl or mdl == Workspace then return r.Position.Y end
        ex[#ex + 1] = mdl
    end
    return fallback
end

function G.playActive()
    if G.sv("DeadPlay") == true then return false end
    if G.sv("Hiked") == false then return false end
    return true
end

function G.catchPoint()
    local _, center = G.localFolder(true)
    local a = G.beamArc(center, true)
    if a then
        local ty = a.landY + 14.3
        local A, B, C = 0.5 * a.gravity.Y, a.velocity.Y, a.origin.Y - ty
        local disc = B * B - 4 * A * C
        local ct
        if disc >= 0 then
            local r = math.sqrt(disc)
            for _, t in ipairs({ (-B - r) / (2 * A), (-B + r) / (2 * A) }) do
                if t >= 0 and t <= a.flightTime + 0.02 and (not ct or t > ct) then ct = t end
            end
        end
        if not ct then ct = math.clamp(-a.velocity.Y / a.gravity.Y, 0, a.flightTime) end
        return G.arcAt(a, ct), a.landY
    end
    if G.sv("BallInAir") == true then
        local s = G.landingSpot()
        if s then return s, s.Y end
    end
    return nil
end

function F.catchRing()
    unbind("catchRing")
    if RT.ring then pcall(function() RT.ring:Destroy() end) RT.ring = nil end
    if not CFG.catchRing then return end
    local rot, last = 0, 0
    bind("catchRing", RunService.RenderStepped:Connect(function(dt)
        local now = os.clock()
        rot = (rot + math.rad(90) * dt) % (math.pi * 2)
        local pos, fy
        if now - last >= 0.05 then
            last = now
            if G.playActive() then pos, fy = G.catchPoint() end
            if not pos then
                if RT.ring then pcall(function() RT.ring:Destroy() end) RT.ring = nil end
                RT.ringPos = nil
                return
            end
            local gy = G.groundY(pos, fy or pos.Y)
            RT.ringPos = Vector3.new(pos.X, (gy or pos.Y) + 0.07, pos.Z)
        end
        if not RT.ringPos then return end
        if not (RT.ring and RT.ring.Parent) then RT.ring = G.ringMake() end
        pcall(function() RT.ring:PivotTo(CFrame.new(RT.ringPos) * CFrame.Angles(0, rot, 0)) end)
    end))
end

local ARC_ROOTS = { Center = true, BallMarker = true, LandingMarker = true }

function G.isArcVisual(inst)
    local a = inst
    while a and a ~= Workspace do
        if a.Name == "ClonedCenter" then return false end
        if ARC_ROOTS[a.Name] then return a.Parent and a.Parent.Name == "Local" end
        a = a.Parent
    end
    return false
end

function G.hideProp(inst)
    if inst:IsA("BasePart") or inst:IsA("Decal") or inst:IsA("Texture") then return "Transparency", 1 end
    if inst:IsA("Beam") or inst:IsA("Trail") or inst:IsA("ParticleEmitter") then return "Transparency", NumberSequence.new(1) end
    if inst:IsA("Attachment") or inst:IsA("GuiObject") then return "Visible", false end
    if inst:IsA("Highlight") or inst:IsA("Light") or inst:IsA("BillboardGui") or inst:IsA("SurfaceGui") then return "Enabled", false end
    return nil
end

function G.hideTrack(inst)
    if not CFG.hideArc or RT.hideRec[inst] or not G.isArcVisual(inst) then return end
    local prop, hv = G.hideProp(inst)
    if not prop then return end
    local ok, cur = pcall(function() return inst[prop] end)
    if not ok then return end
    local rec = { prop = prop, hv = hv, keep = cur }
    RT.hideRec[inst] = rec
    rec.conn = inst:GetPropertyChangedSignal(prop):Connect(function()
        if not CFG.hideArc then return end
        local ok2, now = pcall(function() return inst[prop] end)
        if not ok2 or now == hv then return end
        rec.keep = now
        pcall(function() inst[prop] = hv end)
    end)
    pcall(function() inst[prop] = hv end)
end

function G.hideRestore()
    RT.hideRec = RT.hideRec or {}
    for inst, rec in pairs(RT.hideRec) do
        pcall(function() rec.conn:Disconnect() end)
        if inst.Parent then pcall(function() inst[rec.prop] = rec.keep end) end
        RT.hideRec[inst] = nil
    end
end

function F.hideArc()
    unbind("hideArcW") unbind("hideArcG") unbind("hideArcM")
    G.hideRestore()
    if not CFG.hideArc then return end
    local function watch(key, root)
        if not root then return end
        for _, d in ipairs(root:GetDescendants()) do G.hideTrack(d) end
        bind(key, root.DescendantAdded:Connect(G.hideTrack))
    end
    watch("hideArcG", Workspace:FindFirstChild("Games"))
    watch("hideArcM", Workspace:FindFirstChild("MiniGames"))
    bind("hideArcW", Workspace.ChildAdded:Connect(function(c)
        if c.Name == "Games" then watch("hideArcG", c) elseif c.Name == "MiniGames" then watch("hideArcM", c) end
    end))
end

function F.smooth()
    unbind("smoothAdd")
    RT.matOrig = RT.matOrig or {}
    if not CFG.smooth then
        for p, m in pairs(RT.matOrig) do if p.Parent then pcall(function() p.Material = m end) end RT.matOrig[p] = nil end
        return
    end
    local function ap(p)
        if p:IsA("BasePart") and RT.matOrig[p] == nil and p.Material ~= Enum.Material.SmoothPlastic then
            RT.matOrig[p] = p.Material
            pcall(function() p.Material = Enum.Material.SmoothPlastic end)
        end
    end
    for _, d in ipairs(Workspace:GetDescendants()) do ap(d) end
    bind("smoothAdd", Workspace.DescendantAdded:Connect(function(d) if CFG.smooth then ap(d) end end))
end

function G.cleanTargets()
    local t = {}
    local gf = G.gameFolder()
    local rep = gf and gf:FindFirstChild("Replicated")
    if rep then
        for _, n in ipairs({ "Spawn", "Voting" }) do t[#t + 1] = { rep, n } end
    end
    for _, n in ipairs({ "Set", "PinkDiamondStage", "Pack", "Packs" }) do t[#t + 1] = { Workspace, n } end
    return t
end

function G.stash(key, inst, parent)
    RT[key] = RT[key] or {}
    for _, e in ipairs(RT[key]) do if e.i == inst then return end end
    table.insert(RT[key], { i = inst, p = parent })
    pcall(function() inst.Parent = nil end)
end

function G.unstash(key)
    for _, e in ipairs(RT[key] or {}) do
        if e.i and e.i.Parent == nil and e.p and e.p.Parent then pcall(function() e.i.Parent = e.p end) end
    end
    RT[key] = {}
end

function F.mapClean()
    unbind("mapClean")
    if not CFG.mapClean then G.unstash("cleaned") return end
    local function run()
        for _, e in ipairs(G.cleanTargets()) do
            local x = e[1]:FindFirstChild(e[2])
            if x then G.stash("cleaned", x, e[1]) end
        end
    end
    run()
    local last = 0
    bind("mapClean", RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if now - last < 2 then return end
        last = now
        run()
    end))
end

function F.noAds()
    unbind("noAds")
    if not CFG.noAds then G.unstash("ads") return end
    local function run()
        local gf = G.gameFolder()
        local rep = gf and gf:FindFirstChild("Replicated")
        local ads = rep and rep:FindFirstChild("Ads")
        if not ads then return end
        for _, c in ipairs(ads:GetChildren()) do
            if c:IsA("Model") then G.stash("ads", c, ads) end
        end
    end
    run()
    local last = 0
    bind("noAds", RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if now - last < 2 then return end
        last = now
        run()
    end))
end

function F.jpv()
    unbind("jpv")
    RT.jpvN = RT.jpvN or 0
    if not CFG.jpv then return end
    bind("jpv", RunService.Heartbeat:Connect(function()
        if not CFG.jpv or RT.ds then return end
        local _, hrp, hum = G.char()
        if not hrp or not hum or hum.Health <= 0 then return end
        local st = hum:GetState()
        if st ~= Enum.HumanoidStateType.Freefall and st ~= Enum.HumanoidStateType.Jumping then return end
        if G.carrying() then return end
        local b = G.ball()
        if not b or not G.ballLive(b) then return end
        local aim = G.ballAt(b, math.min(G.pingLead(), 0.4))
        local d = aim - hrp.Position
        if d.Magnitude > CFG.jpvDist or d.Magnitude < 0.5 then return end
        local v = hrp.AssemblyLinearVelocity
        local pull = math.clamp(CFG.jpvPull, 0.01, 2)
        local want = d.Unit * math.min(d.Magnitude * 8 * pull, 45 * pull)
        local flat = Vector3.new(want.X, 0, want.Z)
        local nv = Vector3.new(v.X, v.Y, v.Z):Lerp(Vector3.new(flat.X, v.Y + math.clamp(want.Y, -10, 10) * 0.25, flat.Z), math.clamp(pull * 0.5, 0.05, 1))
        pcall(function() hrp.AssemblyLinearVelocity = nv end)
        RT.jpvN = RT.jpvN + 1
        if G.catchWanted(b, hrp.Position, math.max(CFG.catchRadius, 8)) then G.fireCatch() end
    end))
end

function G.mhPingLead()
    local ms = 0
    pcall(function() ms = LP:GetNetworkPing() * 1000 end)
    if ms > 250 then return 2.5 elseif ms > 200 then return 2 elseif ms > 150 then return 1.7 elseif ms > 100 then return 1.4 elseif ms > 50 then return 1.2 end
    return 1
end

function G.dmHook()
    if RT.dmHooked then return true end
    if WEAK_EXEC then return false end
    if type(hookmetamethod) ~= "function" or type(checkcaller) ~= "function" then return false end
    local ok = pcall(function()
        local old
        local fn = function(self, key)
            if RT.dmSpoof and key == "CFrame" and self == RT.dmHrp and not checkcaller() then
                return RT.dmSaved
            end
            return old(self, key)
        end
        if type(newcclosure) == "function" then fn = newcclosure(fn) end
        old = hookmetamethod(game, "__index", fn)
    end)
    RT.dmHooked = ok
    return ok
end

function G.dmViz(on, b)
    if not on or not b then
        if RT.dmViz then pcall(function() RT.dmViz:Destroy() end) RT.dmViz = nil end
        return
    end
    if not RT.dmViz or not RT.dmViz.Parent then
        pcall(function()
            local p = Instance.new("Part")
            p.Name = "TZmag"
            p.Anchored = true
            p.CanCollide = false
            p.CanTouch = false
            pcall(function() p.CanQuery = false end)
            p.Transparency = 0.7
            p.Material = Enum.Material.ForceField
            p.Color = Color3.fromRGB(138, 43, 226)
            p.CastShadow = false
            p.Shape = Enum.PartType.Ball
            p.Parent = Workspace
            RT.dmViz = p
        end)
    end
    if RT.dmViz then
        local d = CFG.dmagsDist * 2
        pcall(function()
            RT.dmViz.Size = Vector3.new(d, d, d)
            RT.dmViz.CFrame = b.CFrame
        end)
    end
end

function F.dmags()
    unbind("dmags")
    RT.dmSpoof = false
    G.dmViz(false)
    if not CFG.dmags then return end
    if not G.dmHook() and RT.notify then
        RT.notify("Desync Mags", EXEC .. " has no safe hookmetamethod - mags still work, only the position spoof is off", 5)
    end
    RT.dmPrev = {}
    bind("dmags", RunService.Heartbeat:Connect(function()
        if not CFG.dmags or RT.dmBusy then return end
        local b = G.mhBall()
        local _, hrp = G.char()
        G.dmViz(CFG.dmagsShow and hrp ~= nil, b)
        if not b or not hrp then RT.dmPrev = {} return end
        if not G.ballLive(b) or G.carrying() then RT.dmPrev = {} return end
        local air = G.sv("BallInAir")
        if air == false then RT.dmPrev = {} return end
        if air == nil and b.AssemblyLinearVelocity.Magnitude < 2 then return end
        local cur = b.Position
        local prev = RT.dmPrev[b] or cur
        RT.dmPrev = { [b] = cur }
        if (hrp.Position - cur).Magnitude > CFG.dmagsDist then return end
        local delta = cur - prev
        local lead = G.mhPingLead()
        local tgt
        if delta.Magnitude > 0.1 then
            tgt = cur + delta.Unit * 8 * lead
        else
            tgt = cur + Vector3.new(5, 0, 5) * lead
        end
        tgt = Vector3.new(tgt.X, math.max(tgt.Y, cur.Y), tgt.Z)
        RT.dmBusy = true
        RT.dmHrp = hrp
        RT.dmSaved = hrp.CFrame
        RT.dmSpoof = true
        pcall(function() hrp.CFrame = CFrame.new(tgt) end)
        if CFG.dmagsCatch then G.fireCatch() end
        RT.dmN = (RT.dmN or 0) + 1
        RunService.RenderStepped:Wait()
        pcall(function() if hrp.Parent then hrp.CFrame = RT.dmSaved end end)
        RT.dmSpoof = false
        RT.dmBusy = false
    end))
end

function F.fly()
    unbind("fly")
    if RT.flyBV then pcall(function() RT.flyBV:Destroy() end) RT.flyBV = nil end
    if RT.flyBG then pcall(function() RT.flyBG:Destroy() end) RT.flyBG = nil end
    if not CFG.fly then return end
    bind("fly", RunService.Heartbeat:Connect(function()
        if not CFG.fly then return end
        local _, hrp, hum = G.char()
        if not hrp then return end
        if not RT.flyBV or RT.flyBV.Parent ~= hrp then
            if RT.flyBV then pcall(function() RT.flyBV:Destroy() end) end
            if RT.flyBG then pcall(function() RT.flyBG:Destroy() end) end
            local bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(100000, 100000, 100000)
            bv.Velocity = Vector3.new(0, 0, 0)
            bv.Parent = hrp
            local bg = Instance.new("BodyGyro")
            bg.MaxTorque = Vector3.new(100000, 100000, 100000)
            bg.P = 1000
            bg.D = 100
            bg.CFrame = hrp.CFrame
            bg.Parent = hrp
            RT.flyBV, RT.flyBG = bv, bg
        end
        local cam = Workspace.CurrentCamera
        if not cam then return end
        local v = Vector3.new(0, 0, 0)
        if not UserInputService:GetFocusedTextBox() then
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then v = v + cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then v = v - cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then v = v - cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then v = v + cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then v = v + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then v = v - Vector3.new(0, 1, 0) end
        end
        if v.Magnitude == 0 and hum and hum.MoveDirection.Magnitude > 0 then
            local md = hum.MoveDirection
            local look = cam.CFrame.LookVector
            local flatLook = Vector3.new(look.X, 0, look.Z)
            local y = 0
            if flatLook.Magnitude > 0.01 then y = look.Y * md:Dot(flatLook.Unit) end
            v = md + Vector3.new(0, y, 0)
        end
        RT.flyBV.Velocity = v.Magnitude > 0 and v.Unit * CFG.flySpeed or Vector3.new(0, 0, 0)
        RT.flyBG.CFrame = cam.CFrame
    end))
end

function F.noclip()
    unbind("noclip")
    if RT.ncOrig then
        for part, was in pairs(RT.ncOrig) do
            if part.Parent then pcall(function() part.CanCollide = was end) end
        end
        RT.ncOrig = nil
    end
    if not CFG.noclip then return end
    RT.ncOrig = {}
    bind("noclip", RunService.Stepped:Connect(function()
        if not CFG.noclip then return end
        local c = LP.Character
        if not c then return end
        for _, d in ipairs(c:GetDescendants()) do
            if d:IsA("BasePart") and d.CanCollide then
                if RT.ncOrig[d] == nil then RT.ncOrig[d] = true end
                d.CanCollide = false
            end
        end
    end))
end

RT.fear = RT.fear or {}

function F.ttb()
	unbind("fearTTB")
	if RT.fear.ttbGyro then RT.fear.ttbGyro:Destroy(); RT.fear.ttbGyro = nil end
	if not CFG.ttb then return end
	if RT.fear.isSinking == nil then RT.fear.isSinking = false end

	RT.fear.lastTTBBoost = RT.fear.lastTTBBoost or 0

	local function ttbHeartbeat()
		local c, root, hum = G.char()
		if not c or not root or not hum then return end
		if CFG.headSink and RT.fear.isSinking then return end

		if not RT.fear.ttbGyro or not RT.fear.ttbGyro.Parent then
			if RT.fear.ttbGyro then RT.fear.ttbGyro:Destroy() end
			RT.fear.ttbGyro = Instance.new("BodyGyro")
			RT.fear.ttbGyro.MaxTorque = Vector3.new(0, 4000, 0)
			RT.fear.ttbGyro.P = 3000
			RT.fear.ttbGyro.D = 500
			RT.fear.ttbGyro.CFrame = root.CFrame
			RT.fear.ttbGyro.Parent = root
		end

		if hum.MoveDirection.Magnitude > 0.1 or UserInputService:IsKeyDown(Enum.KeyCode.Space) or hum.Jump then
			RT.fear.ttbGyro.CFrame = root.CFrame
			return
		end

		local bestTarget, bestScore = nil, 0
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LP and p.Character then
				local oRoot = p.Character:FindFirstChild("HumanoidRootPart")
				local oHead = p.Character:FindFirstChild("Head")
				if oRoot and oHead then
					local dist = (root.Position - oHead.Position).Magnitude
					local yDiff = root.Position.Y - oHead.Position.Y
					if dist < 7 and yDiff > 0 and yDiff < 5 then
						local score = (7 - dist) * 3 + yDiff * 2
						if score > bestScore then
							bestScore = score
							bestTarget = {root = oRoot, head = oHead}
						end
					end
				end
			end
		end

		if bestTarget then
			local headPos = bestTarget.head.Position
			local dir = headPos - root.Position
			local dist = dir.Magnitude
			if dist > 0.5 and dist < 7 then
				local horiz = Vector3.new(dir.X, 0, dir.Z)
				if horiz.Magnitude > 0.2 then
					local tCF = CFrame.lookAt(root.Position, root.Position + horiz.Unit)
					RT.fear.ttbGyro.CFrame = RT.fear.ttbGyro.CFrame:Lerp(tCF, CFG.ttbSmooth)
				end
				local now = os.clock()
				if dist < 3.5 and now - RT.fear.lastTTBBoost > 0.4 and root.Velocity.Y < 3 then
					root.Velocity = Vector3.new(root.Velocity.X, root.Velocity.Y + CFG.ttbPower * 4, root.Velocity.Z)
					RT.fear.lastTTBBoost = now
				end
			end
		else
			RT.fear.ttbGyro.CFrame = root.CFrame
		end
	end

	bind("fearTTB", RunService.Heartbeat:Connect(ttbHeartbeat))
end

function F.headSink()
	unbind("fearSink")
	RT.fear.isSinking = false
	if RT.fear.sinkBodyVel then RT.fear.sinkBodyVel:Destroy(); RT.fear.sinkBodyVel = nil end
	if RT.fear.sinkBodyGyro then RT.fear.sinkBodyGyro:Destroy(); RT.fear.sinkBodyGyro = nil end
	if not CFG.headSink then return end

	local function sinkHeartbeat()
		local c, root, hum = G.char()
		if not c or not root or not hum then
			if RT.fear.sinkBodyVel then RT.fear.sinkBodyVel.Velocity = Vector3.new(0, 0, 0) end
			RT.fear.isSinking = false
			RT.fear.sinkTarget = nil
			return
		end

		if RT.fear.isSinking == nil then RT.fear.isSinking = false end

		if not RT.fear.sinkBodyVel or not RT.fear.sinkBodyVel.Parent then
			if RT.fear.sinkBodyVel then RT.fear.sinkBodyVel:Destroy() end
			RT.fear.sinkBodyVel = Instance.new("BodyVelocity")
			RT.fear.sinkBodyVel.MaxForce = Vector3.new(5000, 5000, 5000)
			RT.fear.sinkBodyVel.Velocity = Vector3.new(0, 0, 0)
			RT.fear.sinkBodyVel.P = 2000
			RT.fear.sinkBodyVel.Parent = root
		end

		if not RT.fear.sinkBodyGyro or not RT.fear.sinkBodyGyro.Parent then
			if RT.fear.sinkBodyGyro then RT.fear.sinkBodyGyro:Destroy() end
			RT.fear.sinkBodyGyro = Instance.new("BodyGyro")
			RT.fear.sinkBodyGyro.MaxTorque = Vector3.new(0, 4000, 0)
			RT.fear.sinkBodyGyro.P = 3000
			RT.fear.sinkBodyGyro.D = 500
			RT.fear.sinkBodyGyro.CFrame = root.CFrame
			RT.fear.sinkBodyGyro.Parent = root
		end

		if hum.MoveDirection.Magnitude > 0.1 or UserInputService:IsKeyDown(Enum.KeyCode.Space) or hum.Jump then
			RT.fear.sinkBodyVel.Velocity = RT.fear.sinkBodyVel.Velocity:Lerp(Vector3.new(0, 0, 0), 0.5)
			RT.fear.sinkBodyGyro.CFrame = root.CFrame
			RT.fear.isSinking = false
			RT.fear.sinkTarget = nil
			return
		end

		local bestTarget, bestScore = nil, 0
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LP and p.Character then
				local oHead = p.Character:FindFirstChild("Head")
				local oHum = p.Character:FindFirstChild("Humanoid")
				if oHead and oHum then
					local dist = (root.Position - oHead.Position).Magnitude
					local yDiff = root.Position.Y - oHead.Position.Y
					if dist < 6 and yDiff > 0 and yDiff < 8 then
						local score = (6 - dist) * 2 + yDiff
						if oHum:GetState() == Enum.HumanoidStateType.Jumping then score = score * 2 end
						if score > bestScore then
							bestScore = score
							bestTarget = {head = oHead, hum = oHum}
						end
					end
				end
			end
		end

		if bestTarget then
			RT.fear.sinkTarget = bestTarget
			local headPos = bestTarget.head.Position
			if bestTarget.hum:GetState() == Enum.HumanoidStateType.Jumping then
				RT.fear.isSinking = false
				local boost = Vector3.new(0, CFG.sinkBoost, 0)
				local horiz = Vector3.new(headPos.X - root.Position.X, 0, headPos.Z - root.Position.Z)
				if horiz.Magnitude > 0.1 then boost = boost + horiz.Unit * 15 end
				RT.fear.sinkBodyVel.Velocity = boost
				RT.fear.sinkBodyGyro.CFrame = root.CFrame
				hum:ChangeState(Enum.HumanoidStateType.Jumping)
			else
				RT.fear.isSinking = true
				local targetY = headPos.Y - CFG.sinkDepth
				local yDiff = targetY - root.Position.Y
				local sinkYVel = math.clamp(yDiff * CFG.sinkStrength * 3, -30, -3)
				local horiz = Vector3.new(headPos.X - root.Position.X, 0, headPos.Z - root.Position.Z)
				local vel = Vector3.new(0, sinkYVel, 0)
				if horiz.Magnitude > 1 then vel = vel + horiz.Unit * math.min(horiz.Magnitude * 3, 15) end
				RT.fear.sinkBodyVel.Velocity = vel
				RT.fear.sinkBodyGyro.CFrame = root.CFrame
				if math.abs(yDiff) > 3 then hum:ChangeState(Enum.HumanoidStateType.Freefall) end
			end
		else
			RT.fear.isSinking = false
			RT.fear.sinkTarget = nil
			RT.fear.sinkBodyVel.Velocity = RT.fear.sinkBodyVel.Velocity:Lerp(Vector3.new(0, 0, 0), 0.3)
			RT.fear.sinkBodyGyro.CFrame = root.CFrame
		end
	end

	bind("fearSink", RunService.Heartbeat:Connect(sinkHeartbeat))
end

function F.headManip()
	unbind("fearManip")
	if not CFG.headManip then return end

	local function manipHeartbeat()
		local c, root, hum = G.char()
		if not c or not root or not hum then return end

		if hum:GetState() ~= Enum.HumanoidStateType.Freefall then return end
		if root.Velocity.Y > 3 or hum.MoveDirection.Magnitude > 0.5 then return end

		local nearest, nearDist = nil, 18
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LP and p.Character then
				local h = p.Character:FindFirstChild("Head")
				if h then
					local dist = (root.Position - h.Position).Magnitude
					local yDiff = h.Position.Y - root.Position.Y
					if dist < nearDist and yDiff < 3 and yDiff > -8 then
						nearDist = dist
						nearest = h
					end
				end
			end
		end

		if nearest and nearDist > 2 and nearDist < 18 and CFG.headManipSubtle then
			local dir = Vector3.new(nearest.Position.X - root.Position.X, 0, nearest.Position.Z - root.Position.Z).Unit
			local strength = math.clamp(1 - (nearDist / 18), 0.1, 0.5)
			local force = dir * 25 * strength
			root.Velocity = Vector3.new(root.Velocity.X * 0.9 + force.X * 0.1, root.Velocity.Y, root.Velocity.Z * 0.9 + force.Z * 0.1)
		end
	end

	bind("fearManip", RunService.Heartbeat:Connect(manipHeartbeat))
end

function F.headFollow()
	unbind("fearFollow")
	if not CFG.headFollow then return end

	local function followHeartbeat()
		local c, root, hum = G.char()
		if not c or not root or not hum then return end

		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LP and p.Character then
				local oRoot = p.Character:FindFirstChild("HumanoidRootPart")
				local oHum = p.Character:FindFirstChild("Humanoid")
				if oRoot and oHum and oHum:GetState() == Enum.HumanoidStateType.Jumping then
					local dist = (root.Position - oRoot.Position).Magnitude
					if dist < 25 then
						local dir = (oRoot.Position + Vector3.new(0, 3, 0) - root.Position).Unit
						local force = dir * 100
						root.Velocity = Vector3.new(root.Velocity.X * 0.4 + force.X * 0.6, root.Velocity.Y, root.Velocity.Z * 0.4 + force.Z * 0.6)
						break
					end
				end
			end
		end
	end

	bind("fearFollow", RunService.Heartbeat:Connect(followHeartbeat))
end

function F.boostJump()
	unbind("fearBoostJump")
	if not CFG.boostJump then return end

	RT.fear.boostCooldowns = RT.fear.boostCooldowns or {}

	local function boostJumpHeartbeat()
		local c, root, hum = G.char()
		if not c or not root or not hum then return end

		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LP and p.Character then
				local oHum = p.Character:FindFirstChild("Humanoid")
				local oRoot = p.Character:FindFirstChild("HumanoidRootPart")
				if oHum and oRoot and oHum:GetState() == Enum.HumanoidStateType.Jumping then
					local dist = (root.Position - oRoot.Position).Magnitude
					local yDiff = root.Position.Y - oRoot.Position.Y
					if dist < 5 and yDiff > 1.5 and yDiff < 5 then
						local last = RT.fear.boostCooldowns[p.Name]
						if not last or os.clock() - last > 1 then
							local bv = Instance.new("BodyVelocity")
							bv.MaxForce = Vector3.new(0, math.huge, 0)
							bv.Velocity = Vector3.new(0, CFG.boostJumpPower, 0)
							bv.Parent = root
							RT.fear.boostCooldowns[p.Name] = os.clock()
							task.delay(0.3, function() if bv and bv.Parent then bv:Destroy() end end)
						end
					end
				end
			end
		end
	end

	bind("fearBoostJump", RunService.Heartbeat:Connect(boostJumpHeartbeat))
end

function F.sideFling()
	unbind("fearFlingTouch")
	unbind("fearFlingAdd")
	if not CFG.sideFling then return end

	RT.fear.canFling = true

	local function doSideFling(dir)
		if not CFG.sideFling or not RT.fear.canFling then return end
		local c, root, hum = G.char()
		if not c or not root then return end
		RT.fear.canFling = false
		local old = root:FindFirstChild("SideFling")
		if old then old:Destroy() end
		local bv = Instance.new("BodyVelocity")
		bv.Name = "SideFling"
		bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
		bv.Velocity = dir * CFG.flingPower + Vector3.new(0, CFG.flingUp, 0)
		bv.Parent = root
		task.delay(0.25, function() if bv and bv.Parent then bv:Destroy() end end)
		task.delay(CFG.flingCD, function() RT.fear.canFling = true end)
	end

	local function touchHandler(hit)
		if not CFG.sideFling then return end
		local c, root, hum = G.char()
		if not root then return end
		local model = hit:FindFirstAncestorOfClass("Model")
		if not model or model == c then return end
		if not model:FindFirstChild("Humanoid") then return end
		doSideFling(root.CFrame.RightVector)
	end

	local function addCharHandler()
		local c, root, hum = G.char()
		if not c then return end
		hum = c:WaitForChild("Humanoid", 10)
		if not hum then return end
		task.wait(0.5)
		F.sideFling()
	end

	local c, root, hum = G.char()
	if c and hum then
		bind("fearFlingTouch", hum.Touched:Connect(touchHandler))
	end
	bind("fearFlingAdd", LP.CharacterAdded:Connect(addCharHandler))
end

function F.contactBoost()
	unbind("fearContactTouch")
	unbind("fearContactAdd")
	unbind("fearContactInput")
	if not CFG.contactBoost then return end

	RT.fear.boostArmed = false
	RT.fear.contactCooldowns = RT.fear.contactCooldowns or {}

	local function touchHandler(hit)
		if not CFG.contactBoost or not RT.fear.boostArmed then return end
		RT.fear.boostArmed = false
		local c, root, hum = G.char()
		if not root or not hum then return end
		local model = hit.Parent
		local op = Players:GetPlayerFromCharacter(model)
		if op and op ~= LP then
			local enemyHead = model:FindFirstChild("Head")
			if enemyHead and enemyHead.CanCollide then
				local last = RT.fear.contactCooldowns[op.Name]
				if not last or os.clock() - last > CFG.contactCD then
					local bv = Instance.new("BodyVelocity")
					bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
					bv.Velocity = Vector3.new(hum.MoveDirection.X * 5, CFG.contactPower, hum.MoveDirection.Z * 5)
					bv.Parent = root
					RT.fear.contactCooldowns[op.Name] = os.clock()
					task.delay(0.1, function() if bv and bv.Parent then bv:Destroy() end end)
				end
			end
		end
	end

	local function addCharHandler()
		local c, root, hum = G.char()
		if not c then return end
		hum = c:WaitForChild("Humanoid", 10)
		if not hum then return end
		task.wait(0.5)
		F.contactBoost()
	end

	local function inputHandler(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.R and CFG.contactBoost then
			RT.fear.boostArmed = true
		end
	end

	local c, root, hum = G.char()
	if c and hum then
		bind("fearContactTouch", hum.Touched:Connect(touchHandler))
	end
	bind("fearContactAdd", LP.CharacterAdded:Connect(addCharHandler))
	bind("fearContactInput", UserInputService.InputBegan:Connect(inputHandler))
end

function F.landBoost()
	unbind("fearLandTouch")
	unbind("fearLandAdd")
	if not CFG.landBoost then return end

	RT.fear.lastLandingBoost = RT.fear.lastLandingBoost or 0

	local function touchHandler(hit)
		if not CFG.landBoost then return end
		local c, root, hum = G.char()
		if not root then return end
		local model = hit.Parent
		if not model or model == c then return end
		if not model:FindFirstChildOfClass("Humanoid") then return end
		if os.clock() - RT.fear.lastLandingBoost < 0.25 then return end
		local v = root.AssemblyLinearVelocity
		if v.Y > -2 then return end
		RT.fear.lastLandingBoost = os.clock()
		root.AssemblyLinearVelocity = Vector3.new(v.X, CFG.landBoostPower, v.Z)
	end

	local function addCharHandler()
		local c, root, hum = G.char()
		if not c then return end
		hum = c:WaitForChild("Humanoid", 10)
		if not hum then return end
		task.wait(0.5)
		F.landBoost()
	end

	local c, root, hum = G.char()
	if c and hum then
		bind("fearLandTouch", hum.Touched:Connect(touchHandler))
	end
	bind("fearLandAdd", LP.CharacterAdded:Connect(addCharHandler))
end

function F.diveForce()
	unbind("fearDiveInput")
	if not CFG.diveForce then return end

	local function inputHandler(input, gp)
		if gp then return end
		if UserInputService:GetFocusedTextBox() then return end
		if (input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX) and CFG.diveForce then
			local c, root, hum = G.char()
			if not root then return end
			local lv = root.CFrame.LookVector
			local cur = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(lv.X * CFG.diveForcePower, cur.Y, lv.Z * CFG.diveForcePower)
		end
	end

	bind("fearDiveInput", UserInputService.InputBegan:Connect(inputHandler))
end

function F.fastFall()
	unbind("fearFastFall")
	if not CFG.fastFall then
		pcall(function() Workspace.Gravity = 196.2 end)
		return
	end

	pcall(function() Workspace.Gravity = 400 end)
end

function F.hipHeight()
	unbind("fearHipHeight")
	unbind("fearHipAdd")
	local c, root, hum = G.char()

	if not CFG.hipHeight then
		if hum and RT.fear.hipOrig then
			pcall(function() hum.HipHeight = RT.fear.hipOrig end)
		end
		RT.fear.hipOrig = nil
		return
	end

	if hum and RT.fear.hipOrig == nil then
		RT.fear.hipOrig = hum.HipHeight
	end

	local function hipHeartbeat()
		local c, root, hum = G.char()
		if not hum then return end
		pcall(function() hum.HipHeight = CFG.hipValue end)
	end

	local function addCharHandler()
		local c, root, hum = G.char()
		if not c then return end
		hum = c:WaitForChild("Humanoid", 10)
		if not hum then return end
		task.wait(0.5)
		RT.fear.hipOrig = nil
		F.hipHeight()
	end

	bind("fearHipHeight", RunService.Heartbeat:Connect(hipHeartbeat))
	bind("fearHipAdd", LP.CharacterAdded:Connect(addCharHandler))
end

function F.fearOff()
	for _, key in ipairs({ "ttb", "headSink", "headManip", "headFollow", "boostJump", "sideFling", "contactBoost", "landBoost", "diveForce", "fastFall", "hipHeight" }) do
		CFG[key] = false
	end
	F.ttb()
	F.headSink()
	F.headManip()
	F.headFollow()
	F.boostJump()
	F.sideFling()
	F.contactBoost()
	F.landBoost()
	F.diveForce()
	F.fastFall()
	F.hipHeight()
end

local function fearUI(tab)
	tab:Section("Head Tech")
	tab:Toggle({
		Name = "TTB",
		Default = CFG.ttb,
		Callback = function(v) CFG.ttb = v; F.ttb() end
	})
	tab:Slider({
		Name = "TTB Power",
		Min = 1,
		Max = 10,
		Default = CFG.ttbPower,
		Increment = 1,
		Callback = function(v) CFG.ttbPower = v end
	})
	tab:Slider({
		Name = "TTB Smoothness",
		Min = 0.05,
		Max = 1,
		Default = CFG.ttbSmooth,
		Increment = 0.05,
		Decimals = 2,
		Callback = function(v) CFG.ttbSmooth = v end
	})

	tab:Toggle({
		Name = "Head Sink",
		Default = CFG.headSink,
		Callback = function(v) CFG.headSink = v; F.headSink() end
	})
	tab:Slider({
		Name = "Sink Strength",
		Min = 0.1,
		Max = 2,
		Default = CFG.sinkStrength,
		Increment = 0.05,
		Decimals = 2,
		Callback = function(v) CFG.sinkStrength = v end
	})
	tab:Slider({
		Name = "Sink Depth",
		Min = 1,
		Max = 6,
		Default = CFG.sinkDepth,
		Increment = 0.5,
		Decimals = 1,
		Callback = function(v) CFG.sinkDepth = v end
	})
	tab:Slider({
		Name = "Boost Power",
		Min = 30,
		Max = 150,
		Default = CFG.sinkBoost,
		Increment = 5,
		Callback = function(v) CFG.sinkBoost = v end
	})

	tab:Toggle({
		Name = "Head Manipulation",
		Default = CFG.headManip,
		Callback = function(v) CFG.headManip = v; F.headManip() end
	})
	tab:Toggle({
		Name = "Subtle Mode",
		Default = CFG.headManipSubtle,
		Callback = function(v) CFG.headManipSubtle = v end
	})

	tab:Toggle({
		Name = "Head Follow",
		Default = CFG.headFollow,
		Callback = function(v) CFG.headFollow = v; F.headFollow() end
	})

	tab:Section("Boosts")
	tab:Toggle({
		Name = "Boost On Jump",
		Default = CFG.boostJump,
		Callback = function(v) CFG.boostJump = v; F.boostJump() end
	})
	tab:Slider({
		Name = "Boost Height",
		Min = 10,
		Max = 100,
		Default = CFG.boostJumpPower,
		Increment = 1,
		Callback = function(v) CFG.boostJumpPower = v end
	})

	tab:Toggle({
		Name = "Side Fling",
		Default = CFG.sideFling,
		Callback = function(v) CFG.sideFling = v; F.sideFling() end
	})
	tab:Slider({
		Name = "Fling Power",
		Min = 50,
		Max = 800,
		Default = CFG.flingPower,
		Increment = 10,
		Callback = function(v) CFG.flingPower = v end
	})
	tab:Slider({
		Name = "Up Power",
		Min = 0,
		Max = 200,
		Default = CFG.flingUp,
		Increment = 5,
		Callback = function(v) CFG.flingUp = v end
	})
	tab:Slider({
		Name = "Fling Cooldown",
		Min = 0.1,
		Max = 3,
		Default = CFG.flingCD,
		Increment = 0.1,
		Decimals = 1,
		Suffix = " sec",
		Callback = function(v) CFG.flingCD = v end
	})

	tab:Toggle({
		Name = "Contact Boost",
		Default = CFG.contactBoost,
		Callback = function(v) CFG.contactBoost = v; F.contactBoost() end
	})
	tab:Slider({
		Name = "Boost Power",
		Min = 10,
		Max = 200,
		Default = CFG.contactPower,
		Increment = 5,
		Callback = function(v) CFG.contactPower = v end
	})
	tab:Slider({
		Name = "Boost Cooldown",
		Min = 0,
		Max = 2,
		Default = CFG.contactCD,
		Increment = 0.05,
		Decimals = 2,
		Suffix = " sec",
		Callback = function(v) CFG.contactCD = v end
	})
	tab:Label("Press R then land on an enemy head")

	tab:Toggle({
		Name = "Landing Boost",
		Default = CFG.landBoost,
		Callback = function(v) CFG.landBoost = v; F.landBoost() end
	})
	tab:Slider({
		Name = "Boost Power",
		Min = 20,
		Max = 220,
		Default = CFG.landBoostPower,
		Increment = 5,
		Callback = function(v) CFG.landBoostPower = v end
	})

	tab:Section("Movement Extras")
	tab:Toggle({
		Name = "Dive Force",
		Default = CFG.diveForce,
		Callback = function(v) CFG.diveForce = v; F.diveForce() end
	})
	tab:Slider({
		Name = "Dive Power",
		Min = 10,
		Max = 150,
		Default = CFG.diveForcePower,
		Increment = 5,
		Callback = function(v) CFG.diveForcePower = v end
	})

	tab:Toggle({
		Name = "Fast Fall",
		Default = CFG.fastFall,
		Callback = function(v) CFG.fastFall = v; F.fastFall() end
	})
	tab:Label("Sets gravity to 400 while on")

	tab:Toggle({
		Name = "Hip Height",
		Default = CFG.hipHeight,
		Callback = function(v) CFG.hipHeight = v; F.hipHeight() end
	})
	tab:Slider({
		Name = "Hip Height",
		Min = 0,
		Max = 20,
		Default = CFG.hipValue,
		Increment = 0.5,
		Decimals = 1,
		Callback = function(v) CFG.hipValue = v end
	})
end

local KB_LIST = {
    { "kbJpv", "Jump Pull Vector" },
    { "kbOwnHb", "Your Hitbox" },
    { "kbSticky", "Sticky Head" },
    { "kbHitbox", "Hitbox Expander" },
    { "kbPre1", "Preset Default" },
    { "kbPre2", "Preset Small" },
    { "kbPre3", "Preset Medium" },
    { "kbPre4", "Preset Tiny" },
}
local kbLabels = {}
local hotToggles = {}

function G.kbText(k)
    local v = CFG[k]
    return (v == nil or v == "") and "none" or v
end

function G.kbFire(name)
    if name == "kbJpv" then
        CFG.jpv = not CFG.jpv F.jpv()
        if hotToggles.jpv then hotToggles.jpv:Set(CFG.jpv, true) end
        notify("Hotkey", "Jump Pull Vector " .. (CFG.jpv and "ON" or "OFF"), 1.5)
    elseif name == "kbOwnHb" then
        CFG.ownHb = not CFG.ownHb F.ownHb()
        if hotToggles.ownHb then hotToggles.ownHb:Set(CFG.ownHb, true) end
        notify("Hotkey", "Your Hitbox " .. (CFG.ownHb and "ON" or "OFF"), 1.5)
    elseif name == "kbSticky" then
        CFG.sticky = not CFG.sticky F.sticky()
        if hotToggles.sticky then hotToggles.sticky:Set(CFG.sticky, true) end
        notify("Hotkey", "Sticky Head " .. (CFG.sticky and "ON" or "OFF"), 1.5)
    elseif name == "kbHitbox" then
        CFG.hitbox = not CFG.hitbox F.hitbox()
        if hotToggles.hitbox then hotToggles.hitbox:Set(CFG.hitbox, true) end
        notify("Hotkey", "Hitbox Expander " .. (CFG.hitbox and "ON" or "OFF"), 1.5)
    else
        local i = tonumber(name:sub(-1))
        local pn = OWN_PRESET_ORDER[i]
        if pn then
            G.ownPreset(pn)
            if hotToggles.preset then hotToggles.preset:Set(pn, true) end
            notify("Hotkey", "Hitbox preset " .. pn, 1.5)
        end
    end
end

bind("hotkeys", UserInputService.InputBegan:Connect(function(inp, gpe)
    if UserInputService:GetFocusedTextBox() then return end
    if RT.kbCap then
        if inp.UserInputType ~= Enum.UserInputType.Keyboard then return end
        local cap = RT.kbCap
        RT.kbCap = nil
        local kn = inp.KeyCode.Name
        if inp.KeyCode == Enum.KeyCode.Backspace or inp.KeyCode == Enum.KeyCode.Escape then kn = "" end
        for _, e in ipairs(KB_LIST) do
            if e[1] ~= cap and CFG[e[1]] == kn and kn ~= "" then CFG[e[1]] = "" if kbLabels[e[1]] then kbLabels[e[1]].Text = e[2] .. ": none" end end
        end
        CFG[cap] = kn
        for _, e in ipairs(KB_LIST) do
            if e[1] == cap and kbLabels[cap] then kbLabels[cap].Text = e[2] .. ": " .. G.kbText(cap) end
        end
        return
    end
    if gpe or inp.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local kn = inp.KeyCode.Name
    for _, e in ipairs(KB_LIST) do
        if CFG[e[1]] ~= "" and CFG[e[1]] == kn then G.kbFire(e[1]) end
    end
end))

local tMain = Win:Tab("Main")
local tPlayer = Win:Tab("Player")
local tMech = Win:Tab("Mechanics")
local tBox = Win:Tab("Hitbox")
local tVis = Win:Tab("Visuals")
local tHead = Win:Tab("Head Tech")
local tMisc = Win:Tab("Misc")

fearUI(tHead)

tMain:Section("Protection")
local bypassLbl = tMain:Label("")
tMain:Toggle({
    Name = "Silent Tracking Bypass", Default = CFG.bypass,
    Callback = function(v)
        CFG.bypass = v
        if v then
            local ok = AC.enable()
            bypassLbl:Set(ok and "Active - speed/jump/height reports blocked" or "FAILED - module not found, stay under the limits")
            if not ok then notify("Bypass", "Could not hook the tracker", 5) end
        else
            AC.disable()
            bypassLbl:Set("OFF - you are reported above WalkSpeed 25 / height 12")
        end
    end,
})

tMain:Section("Ball")
tMain:Toggle({ Name = "Pull Vector (hold M1)", Default = CFG.pull, Callback = function(v) CFG.pull = v end })
tMain:Toggle({ Name = "Legit Pull (runs at sprint speed)", Default = CFG.legit, Callback = function(v) CFG.legit = v end })
tMain:Toggle({ Name = "Auto Offset Distance", Default = CFG.pullAuto, Callback = function(v) CFG.pullAuto = v end })
tMain:Slider({ Name = "Offset Distance", Min = 0, Max = 30, Default = CFG.pullOffset, Increment = 1, Suffix = " st", Callback = function(v) CFG.pullOffset = v end })
tMain:Slider({ Name = "Max Pull Distance", Min = 1, Max = 100, Default = CFG.pullMax, Increment = 1, Suffix = " st", Callback = function(v) CFG.pullMax = v end })
tMain:Slider({ Name = "Vector Smoothing", Min = 0.01, Max = 1, Default = CFG.pullSmooth, Increment = 0.01, Decimals = 2, Callback = function(v) CFG.pullSmooth = v end })
tMain:Label("Hold M1. Pull snaps you in front of the ball every 0.05s, Legit lerps you there (lower smoothing = smoother).")
tMain:Toggle({ Name = "Auto Catch", Default = CFG.autoCatch, Callback = function(v) CFG.autoCatch = v F.autoCatch() end })
tMain:Slider({ Name = "Catch Radius", Min = 3, Max = 40, Default = CFG.catchRadius, Increment = 1, Suffix = " st", Callback = function(v) CFG.catchRadius = v end })
tMain:Section("Desync Mags")
hotToggles.dmags = tMain:Toggle({ Name = "Desync Mags", Default = CFG.dmags, Callback = function(v) CFG.dmags = v F.dmags() end })
tMain:Slider({ Name = "Magnet Distance", Min = 0, Max = 120, Default = CFG.dmagsDist, Increment = 1, Suffix = " st", Callback = function(v) CFG.dmagsDist = v end })
tMain:Toggle({ Name = "Show Hitbox", Default = CFG.dmagsShow, Callback = function(v) CFG.dmagsShow = v if not v then G.dmViz(false) end end })
tMain:Toggle({ Name = "Fire Catch For Me", Default = CFG.dmagsCatch, Callback = function(v) CFG.dmagsCatch = v end })
tMain:Label("The server sees you at the ball for a frame, your screen keeps you home. Mags the ball when it is inside the distance.")
tMain:Section("Jump Pull Vector")
hotToggles.jpv = tMain:Toggle({ Name = "Jump Pull Vector (pulls you mid-jump)", Default = CFG.jpv, Callback = function(v) CFG.jpv = v F.jpv() end })
tMain:Slider({ Name = "Pull Strength", Min = 0.01, Max = 2, Default = CFG.jpvPull, Increment = 0.01, Decimals = 2, Callback = function(v) CFG.jpvPull = v end })
tMain:Slider({ Name = "Pull Distance", Min = 1, Max = 50, Default = CFG.jpvDist, Increment = 1, Suffix = " st", Callback = function(v) CFG.jpvDist = v end })
tMain:Label("Jump near the ball and it bends you onto it with velocity, no teleport. Fires the catch for you.")
tMain:Section("Ball Magnet (Mags) / Auto PullVector")
tMain:Label("Mags = you get pulled onto the ball and the catch fires for you. No script can move the game's ball - the server owns it.")
tMain:Toggle({ Name = "Ball Magnet / Auto PullVector", Default = CFG.apv, Callback = function(v) CFG.apv = v F.desync() end })
tMain:Toggle({ Name = "Passes", Default = CFG.apvPasses, Callback = function(v) CFG.apvPasses = v end })
tMain:Toggle({ Name = "Kicks", Default = CFG.apvKicks, Callback = function(v) CFG.apvKicks = v end })
tMain:Toggle({ Name = "Enemy Throws Only", Default = CFG.apvEnemyOnly, Callback = function(v) CFG.apvEnemyOnly = v end })
tMain:Toggle({ Name = "Only When I'm The Returner", Default = CFG.apvReturner, Callback = function(v) CFG.apvReturner = v end })
tMain:Toggle({ Name = "Chase Field Goals", Default = CFG.apvFG, Callback = function(v) CFG.apvFG = v end })
tMain:Label("Kicks: only the kick returner can catch a kickoff. Waits where the ball comes down; your own team's kicks are skipped.")
tMain:Dropdown({ Name = "Target Mode", Options = { "Chase Ball", "Landing Spot" }, Default = CFG.apvMode, Callback = function(v)
    CFG.apvMode = v
    if RT.ds and RT.ds.kind == "pass" then
        RT.ds.landing = v == "Landing Spot"
        RT.ds.phase = RT.ds.landing and "wait" or "hold"
        RT.ds.hold = nil
        RT.ds.t0 = os.clock()
    end
end })
tMain:Label("Landing Spot = waits, then stands where the ball comes down. Chase Ball = jumps in front of the ball on its path.")
tMain:Slider({ Name = "Lead Offset", Min = 0, Max = 40, Default = CFG.apvOffset, Increment = 1, Suffix = " st", Callback = function(v) CFG.apvOffset = v end })
tMain:Slider({ Name = "Smoothing (1 = snap)", Min = 0.02, Max = 1, Default = CFG.apvSmooth, Increment = 0.01, Decimals = 2, Callback = function(v) CFG.apvSmooth = v end })
tMain:Slider({ Name = "Max Distance (0 = anywhere)", Min = 0, Max = 600, Default = CFG.apvMax, Increment = 10, Suffix = " st", Callback = function(v) CFG.apvMax = v end })
tMain:Slider({ Name = "Max Jump Per Step (anti-kick)", Min = 20, Max = 150, Default = CFG.apvMaxJump, Increment = 5, Suffix = " st", Callback = function(v) CFG.apvMaxJump = v end })
tMain:Slider({ Name = "Landing Start Radius", Min = 5, Max = 80, Default = CFG.apvStart, Increment = 1, Suffix = " st", Callback = function(v) CFG.apvStart = v end })
tMain:Slider({ Name = "Get In Front By", Min = 0, Max = 12, Default = CFG.apvAhead, Increment = 1, Suffix = " st", Callback = function(v) CFG.apvAhead = v end })
tMain:Slider({ Name = "Min Ball Speed", Min = 0, Max = 150, Default = CFG.apvMinSpeed, Increment = 5, Suffix = " st/s", Callback = function(v) CFG.apvMinSpeed = v end })
tMain:Slider({ Name = "Max Pull Time", Min = 500, Max = 8000, Default = CFG.apvMaxTime, Increment = 100, Suffix = " ms", Callback = function(v) CFG.apvMaxTime = v end })
tMain:Slider({ Name = "Cooldown", Min = 0, Max = 5, Default = CFG.apvCool, Increment = 0.1, Decimals = 1, Suffix = " s", Callback = function(v) CFG.apvCool = v end })
tMain:Toggle({ Name = "Return Home On Miss", Default = CFG.apvReturn, Callback = function(v) CFG.apvReturn = v end })
tMain:Slider({ Name = "Return Delay", Min = 0, Max = 4000, Default = CFG.apvBack, Increment = 50, Suffix = " ms", Callback = function(v) CFG.apvBack = v end })
tMain:Toggle({ Name = "Pause Speed While Pulling", Default = CFG.apvFreeze, Callback = function(v)
    CFG.apvFreeze = v
    if not v then G.dsUnfreeze() end
end })
tMain:Section("Offense")
tMain:Toggle({ Name = "Auto Hike (QB)", Default = CFG.autoHike, Callback = function(v) CFG.autoHike = v F.autoHike() end })
tMain:Toggle({ Name = "Auto Touchdown", Default = CFG.autoTD, Danger = true, Callback = function(v) CFG.autoTD = v F.autoTD() end })
tMain:Toggle({ Name = "Also After Interceptions", Default = CFG.tdInt, Callback = function(v) CFG.tdInt = v end })
tMain:Toggle({ Name = "Soft Landing After Catch", Default = CFG.landCatch, Callback = function(v) CFG.landCatch = v F.landCatch() end })
tMain:Label("Slows a fast fall after a high catch. Never moves you - the old version snapped you into the ground.")
tMain:Slider({ Name = "Touchdown Glide (0 = instant)", Min = 0, Max = 40, Default = CFG.tdGlide, Increment = 1, Suffix = " st/s", Callback = function(v) CFG.tdGlide = v end })
tMain:Label("0 = one jump to the endzone. Glides are capped at 40 st/s - anything faster gets you kicked for 'high latency'.")

tMain:Section("QB Aimbot")
tMain:Label("H = select player nearest your mouse, T = throw (route read + arc lead)")
local aimLbl = tMain:Label("target: none")
tMain:Button({ Name = "Lock Nearest Teammate", Callback = function()
    local p = F.aimTarget()
    RT.aim = p
    aimLbl:Set("target: " .. (p and p.Name or "none"))
end })
tMain:Button({ Name = "Throw To Target", Callback = function()
    if not RT.aim then notify("Aimbot", "No target locked") return end
    local ok, why = F.throwTo(RT.aim)
    if not ok then notify("Aimbot", "Throw failed - " .. tostring(why)) end
end })

tPlayer:Section("Movement")
local wsLbl = tPlayer:Label("Reported above 25. Bypass handles it.")
tPlayer:Toggle({ Name = "WalkSpeed", Default = CFG.walk, Callback = function(v) CFG.walk = v F.walk() end })
tPlayer:Slider({ Name = "WalkSpeed Value", Min = 18, Max = 41, Default = CFG.walkVal, Increment = 1, Callback = function(v)
    CFG.walkVal = v
    wsLbl:Set(v > 25 and ("Over the limit (" .. v .. " > 25) - keep the bypass ON") or "Under the reporting limit")
    if CFG.walk and not RT.dsFreeze then F.walk() end
end })
tPlayer:Toggle({ Name = "CFrame Speed (safer)", Default = CFG.cwalk, Callback = function(v) CFG.cwalk = v F.cwalk() end })
tPlayer:Slider({ Name = "CFrame Speed Value", Min = 18, Max = 30, Default = CFG.cwalkVal, Increment = 1, Suffix = " st/s", Callback = function(v) CFG.cwalkVal = v end })
tPlayer:Label("23 = the game's sprint speed. The server kicks for 'high latency' when you keep moving faster than that.")
tPlayer:Toggle({ Name = "Jump Boost", Default = CFG.jump, Callback = function(v) CFG.jump = v F.jump() end })
tPlayer:Slider({ Name = "Jump Power", Min = 20, Max = 140, Default = CFG.jumpVal, Increment = 1, Callback = function(v) CFG.jumpVal = v end })
tPlayer:Toggle({ Name = "Infinite Stamina", Default = CFG.stamina, Callback = function(v) CFG.stamina = v F.stamina() end })
hotToggles.fly = tPlayer:Toggle({ Name = "Fly", Default = CFG.fly, Danger = true, Callback = function(v) CFG.fly = v F.fly() end })
tPlayer:Slider({ Name = "Fly Speed", Min = 10, Max = 200, Default = CFG.flySpeed, Increment = 1, Callback = function(v) CFG.flySpeed = v end })
tPlayer:Toggle({ Name = "Anti Block (No Collide)", Default = CFG.noclip, Callback = function(v) CFG.noclip = v F.noclip() end })

tPlayer:Section("Game Params (the game's own values)")
tPlayer:Toggle({ Name = "Game WalkSpeed", Default = CFG.gpWalk, Callback = function(v) CFG.gpWalk = v F.gameParams() end })
tPlayer:Slider({ Name = "Game WalkSpeed Value", Min = 0, Max = 41, Default = CFG.gpWalkVal, Increment = 1, Callback = function(v) CFG.gpWalkVal = v if CFG.gpWalk then G.gpApply() end end })
tPlayer:Toggle({ Name = "Game Jump Power", Default = CFG.gpJump, Callback = function(v) CFG.gpJump = v F.gameParams() end })
tPlayer:Slider({ Name = "Game Jump Power Value", Min = 0, Max = 300, Default = CFG.gpJumpVal, Increment = 0.5, Decimals = 1, Callback = function(v) CFG.gpJumpVal = v if CFG.gpJump then G.gpApply() end end })
tPlayer:Toggle({ Name = "Dive Power", Default = CFG.gpDive, Callback = function(v) CFG.gpDive = v F.gameParams() end })
tPlayer:Slider({ Name = "Dive Power Value", Min = 0, Max = 15, Default = CFG.gpDiveVal, Increment = 0.1, Decimals = 1, Callback = function(v) CFG.gpDiveVal = v if CFG.gpDive then G.gpApply() end end })
tPlayer:Toggle({ Name = "Stamina Gain", Default = CFG.gpRegen, Callback = function(v) CFG.gpRegen = v F.gameParams() end })
tPlayer:Slider({ Name = "Stamina Gain Value", Min = 0, Max = 50, Default = CFG.gpRegenVal, Increment = 0.5, Decimals = 1, Callback = function(v) CFG.gpRegenVal = v if CFG.gpRegen then G.gpApply() end end })
tPlayer:Toggle({ Name = "Stamina Loss", Default = CFG.gpDrain, Callback = function(v) CFG.gpDrain = v F.gameParams() end })
tPlayer:Slider({ Name = "Stamina Loss Value", Min = 0, Max = 50, Default = CFG.gpDrainVal, Increment = 1, Callback = function(v) CFG.gpDrainVal = v if CFG.gpDrain then G.gpApply() end end })
tPlayer:Toggle({ Name = "Gravity", Default = CFG.gravity, Callback = function(v) CFG.gravity = v F.gameParams() end })
tPlayer:Slider({ Name = "Gravity Value", Min = 0, Max = 1000, Default = CFG.gravityVal, Increment = 0.1, Decimals = 1, Callback = function(v) CFG.gravityVal = v if CFG.gravity then Workspace.Gravity = v end end })
tPlayer:Label("Sets the match's GameParams values. WalkSpeed is capped at 41 (kicks above 43).")

tPlayer:Section("Sticky Head")
hotToggles.sticky = tPlayer:Toggle({ Name = "Sticky Head", Default = CFG.sticky, Danger = true, Callback = function(v) CFG.sticky = v F.sticky() end })
tPlayer:Toggle({ Name = "Enemies Only", Default = CFG.stickyEnemy, Callback = function(v) CFG.stickyEnemy = v end })
tPlayer:Slider({ Name = "Range", Min = 1, Max = 50, Default = CFG.stickyRange, Increment = 1, Suffix = " st", Callback = function(v) CFG.stickyRange = v end })
tPlayer:Slider({ Name = "Smoothness", Min = 1, Max = 100, Default = CFG.stickySmooth, Increment = 1, Callback = function(v) CFG.stickySmooth = v end })
tPlayer:Slider({ Name = "Strength", Min = 1, Max = 100, Default = CFG.stickyStrength, Increment = 1, Callback = function(v) CFG.stickyStrength = v end })

tPlayer:Section("Assist")
tPlayer:Toggle({ Name = "Auto Follow Ball Carrier", Default = CFG.follow, Callback = function(v) CFG.follow = v F.follow() end })
tPlayer:Dropdown({ Name = "Follow Who", Options = { "Enemy", "Teammate", "Any" }, Default = CFG.followWho, Callback = function(v) CFG.followWho = v end })
tPlayer:Slider({ Name = "Follow Blatancy", Min = 0, Max = 1, Default = CFG.followBlat, Increment = 0.05, Decimals = 2, Callback = function(v) CFG.followBlat = v end })
tPlayer:Button({ Name = "Teleport To Ball", Callback = function()
    local b = G.ball()
    local _, hrp = G.char()
    if b and hrp then hrp.CFrame = CFrame.new(b.Position + Vector3.new(0, 2, 0)) else notify("Teleport", "No ball found") end
end })
tPlayer:Button({ Name = "Teleport Forward 8", Callback = function()
    local _, hrp = G.char()
    if hrp then hrp.CFrame = hrp.CFrame + hrp.CFrame.LookVector * 8 end
end })

local function mech(tab, label, action, payload)
    tab:Button({ Name = label, Callback = function()
        local ok
        if payload == "vec" then
            local _, hrp = G.char()
            if not hrp then return end
            ok = G.fire(action, { VecCoordinate = hrp.Position })
        elseif payload == "spin" then
            ok = G.fire(action, true)
            task.delay(0.4, function() G.fire(action, false) end)
        elseif payload ~= nil then
            ok = G.fire(action, payload)
        else
            ok = G.fire(action)
        end
        if not ok then notify("Mechanics", action .. " failed - no game remote") end
    end })
end

tMech:Section("Offense")
mech(tMech, "Hike", "Hiked")
mech(tMech, "Dive", "Dive")
mech(tMech, "Spin Move Left", "SpinMoveLeft", "spin")
mech(tMech, "Spin Move Right", "SpinMoveRight", "spin")
mech(tMech, "Handoff", "Handoff", true)
mech(tMech, "QB Kneel", "QBKneel", "vec")
mech(tMech, "QB Slide", "QBSlide", "vec")
tMech:Button({ Name = "Trucking (server gated)", Callback = function()
    local r = G.invoke("Trucking", true)
    notify("Trucking", r and "server allowed" or "server refused")
end })
tMech:Button({ Name = "Hit Stick (server gated)", Callback = function()
    local r = G.invoke("HitStick", true)
    notify("Hit Stick", r and "server allowed" or "server refused")
end })

tMech:Section("Defense / Special")
mech(tMech, "Catch", "Catching", true)
mech(tMech, "Fair Catch", "FairCatch", "vec")
mech(tMech, "Block", "Blocking", true)
mech(tMech, "Pull Flag", "PullFlag", true)
mech(tMech, "Timeout", "Timeout")
mech(tMech, "Spawn Ball", "BallControl", "SpawnBall")

tMech:Section("Automation")
tMech:Toggle({ Name = "Auto Dive Near Ball", Default = CFG.autoDive, Callback = function(v) CFG.autoDive = v F.autoDive() end })

tMech:Section("Auto Defense")
tMech:Toggle({ Name = "Auto Rush QB", Default = CFG.rush, Callback = function(v) CFG.rush = v F.rush() end })
tMech:Toggle({ Name = "Auto Intercept", Default = CFG.intercept, Callback = function(v) CFG.intercept = v F.intercept() end })
tMech:Slider({ Name = "Intercept Range", Min = 20, Max = 200, Default = CFG.interceptRange, Increment = 5, Suffix = " st", Callback = function(v) CFG.interceptRange = v end })
tMech:Toggle({ Name = "Auto Block", Default = CFG.autoBlock, Callback = function(v) CFG.autoBlock = v F.autoBlock() end })
tMech:Slider({ Name = "Block Range", Min = 3, Max = 20, Default = CFG.blockRange, Increment = 1, Suffix = " st", Callback = function(v) CFG.blockRange = v end })
tMech:Label("Rush and Intercept only run while the other team has the ball")

tBox:Section("Player Hitboxes")
tBox:Toggle({ Name = "Show Hitboxes + Range", Default = CFG.hbShow, Callback = function(v) CFG.hbShow = v F.hbShow() end })
hotToggles.hitbox = tBox:Toggle({ Name = "Hitbox Expander", Default = CFG.hitbox, Danger = true, Callback = function(v) CFG.hitbox = v F.hitbox() end })
tBox:Slider({ Name = "Hitbox Size", Min = 1, Max = 30, Default = CFG.hitboxSize, Increment = 0.5, Decimals = 1, Callback = function(v)
    CFG.hitboxSize = v
    if CFG.hitbox then G.hbApply() end
end })
tBox:Slider({ Name = "Hitbox Transparency", Min = 0, Max = 1, Default = CFG.hitboxTrans, Increment = 0.05, Decimals = 2, Callback = function(v)
    CFG.hitboxTrans = v
    if CFG.hitbox then G.hbApply() end
end })
tBox:Toggle({ Name = "Expand Enemies Only", Default = CFG.hitboxEnemy, Callback = function(v)
    CFG.hitboxEnemy = v
    if CFG.hitbox then G.hbApply() end
end })
tBox:Label("Expander pauses while you carry the ball")
tBox:Toggle({ Name = "Tackle Reach", Default = CFG.reach, Danger = true, Callback = function(v) CFG.reach = v F.reach() end })
tBox:Slider({ Name = "Reach Distance", Min = 1, Max = 20, Default = CFG.reachDist, Increment = 1, Suffix = " st", Callback = function(v) CFG.reachDist = v end })
tBox:Section("Heads")
tBox:Toggle({ Name = "Big Head", Default = CFG.bighead, Danger = true, Callback = function(v) CFG.bighead = v F.bighead() end })
tBox:Slider({ Name = "Head Size", Min = 1, Max = 12, Default = CFG.bigheadSize, Increment = 1, Callback = function(v) CFG.bigheadSize = v end })
tBox:Toggle({ Name = "Head Clone (safer big head)", Default = CFG.headClone, Callback = function(v) CFG.headClone = v F.headClone() end })
tBox:Slider({ Name = "Head Clone Size", Min = 1, Max = 4, Default = CFG.headCloneSize, Increment = 0.1, Decimals = 1, Suffix = "x", Callback = function(v) CFG.headCloneSize = v end })
tBox:Slider({ Name = "Head Clone Transparency", Min = 0, Max = 1, Default = CFG.headCloneTrans, Increment = 0.05, Decimals = 2, Callback = function(v) CFG.headCloneTrans = v end })
tBox:Label("Server validation on these is UNTESTED. Default off, use on an alt first.")

tBox:Section("Your Hitbox")
hotToggles.ownHb = tBox:Toggle({ Name = "Your Hitbox Size Lock", Default = CFG.ownHb, Danger = true, Callback = function(v) CFG.ownHb = v F.ownHb() end })
hotToggles.preset = tBox:Dropdown({ Name = "Preset", Options = OWN_PRESET_ORDER, Default = CFG.ownPreset, Callback = function(v) CFG.ownPreset = v G.ownPreset(v) end })
ownSliders.x = tBox:Slider({ Name = "Size X", Min = 0.1, Max = 50, Default = CFG.ownX, Increment = 0.01, Decimals = 2, Callback = function(v) CFG.ownX = v if CFG.ownHb then G.ownHbApply() end end })
ownSliders.y = tBox:Slider({ Name = "Size Y", Min = 0.1, Max = 50, Default = CFG.ownY, Increment = 0.01, Decimals = 2, Callback = function(v) CFG.ownY = v if CFG.ownHb then G.ownHbApply() end end })
ownSliders.z = tBox:Slider({ Name = "Size Z", Min = 0.1, Max = 50, Default = CFG.ownZ, Increment = 0.01, Decimals = 2, Callback = function(v) CFG.ownZ = v if CFG.ownHb then G.ownHbApply() end end })
tBox:Slider({ Name = "Transparency", Min = 0, Max = 1, Default = CFG.ownTrans, Increment = 0.05, Decimals = 2, Callback = function(v) CFG.ownTrans = v if CFG.ownHb then G.ownHbApply() end end })
tBox:Label("Locks the size of your own tackle box. The game snaps it back, this re-applies it.")

tVis:Section("ESP")
tVis:Toggle({ Name = "Ball Highlight", Default = CFG.espBall, Callback = function(v) CFG.espBall = v F.esp() end })
tVis:Toggle({ Name = "Ball Carrier", Default = CFG.espCarrier, Callback = function(v) CFG.espCarrier = v F.esp() end })
tVis:Toggle({ Name = "Player ESP (team colored)", Default = CFG.espPlayers, Callback = function(v) CFG.espPlayers = v F.esp() end })
tVis:Toggle({ Name = "Ball Landing Spot", Default = CFG.landEsp, Callback = function(v) CFG.landEsp = v F.landEsp() end })
tVis:Section("Throw Arc")
tVis:Toggle({ Name = "Safe QB Arc (red = pickable)", Default = CFG.safeArc, Callback = function(v) CFG.safeArc = v F.safeArc() end })
tVis:Toggle({ Name = "Catch Point Ring", Default = CFG.catchRing, Callback = function(v) CFG.catchRing = v F.catchRing() end })
tVis:Toggle({ Name = "Hide Game Arc", Default = CFG.hideArc, Callback = function(v) CFG.hideArc = v F.hideArc() end })
tVis:Label("Safe QB Arc turns your aim arc red when a defender can reach the ball, green when it is clear.")

tVis:Section("Map")
tVis:Toggle({ Name = "Smooth Plastic (anti material)", Default = CFG.smooth, Callback = function(v) CFG.smooth = v F.smooth() end })
tVis:Toggle({ Name = "Map Cleaner", Default = CFG.mapClean, Callback = function(v) CFG.mapClean = v F.mapClean() end })
tVis:Toggle({ Name = "Remove Ads", Default = CFG.noAds, Callback = function(v) CFG.noAds = v F.noAds() end })

tVis:Section("Performance")
tVis:Button({ Name = "FPS Boost", Callback = function()
    pcall(function()
        local L = game:GetService("Lighting")
        L.GlobalShadows = false
        L.FogEnd = 1e9
        for _, v in ipairs(L:GetChildren()) do if v:IsA("PostEffect") then v.Enabled = false end end
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        for _, v in ipairs(Workspace:GetDescendants()) do
            if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
                v.Enabled = false
            elseif v:IsA("Decal") or v:IsA("Texture") then
                v.Transparency = 1
            end
        end
    end)
    notify("Visuals", "FPS boost applied")
end })

tMisc:Section("Hotkeys")
for _, e in ipairs(KB_LIST) do
    local key = e[1]
    local btn
    btn = tMisc:Button({ Name = e[2] .. ": " .. G.kbText(key), Callback = function()
        RT.kbCap = key
        local l = kbLabels[key]
        if l then l.Text = e[2] .. ": press a key (Backspace clears)" end
    end })
    kbLabels[key] = btn:FindFirstChildOfClass("TextLabel")
end
tMisc:Label("Click a row, then press a key. Backspace or Esc clears it.")

tMisc:Section("Safety")
tMisc:Toggle({ Name = "Staff Watcher", Default = CFG.antiAdmin, Callback = function(v) CFG.antiAdmin = v F.antiAdmin(notify) end })
tMisc:Toggle({ Name = "Anti AFK", Default = CFG.antiAfk, Callback = function(v) CFG.antiAfk = v F.antiAfk() end })
tMisc:Label("Blocks the game's own 10-minute idle-server teleport and Roblox's 20-minute kick.")
function F.autoload(quiet)
    if not CFG.autoload then return end
    local q = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
    if type(q) ~= "function" then
        if not quiet then notify("Topaz", EXEC .. " has no queue_on_teleport - add the loader to your autoexec instead", 6) end
        return
    end
    local src = [[task.spawn(function()
if not game:IsLoaded() then game.Loaded:Wait() end
local P = game:GetService("Players")
local lp = P.LocalPlayer
while not lp do task.wait(0.2) lp = P.LocalPlayer end
if not lp.Character then lp.CharacterAdded:Wait() end
lp:WaitForChild("PlayerGui", 30)
lp:WaitForChild("Replicated", 30)
game:GetService("ReplicatedStorage"):WaitForChild("Assets", 30)
task.wait(2)
local g = getgenv and getgenv() or _G
if g.Topaz or g.__TopazAL == game.JobId then return end
g.__TopazAL = game.JobId
local on = true
pcall(function()
if isfile and isfile("Chronix/Topaz.json") then
local c = game:GetService("HttpService"):JSONDecode(readfile("Chronix/Topaz.json"))
if type(c) == "table" and c.autoload == false then on = false end
end
end)
if not on then return end
pcall(function() loadstring(game:HttpGet("https://chronix-gate.net/l"))() end)
end)]]
    if RT.alQueued then return end
    if pcall(q, src) then
        RT.alQueued = true
        if not quiet then notify("Topaz", "Autoload armed - Topaz reloads on every new server", 4) end
    end
end
tMisc:Toggle({ Name = "Autoload On Server Join", Default = CFG.autoload, Callback = function(v)
    CFG.autoload = v
    if v then F.autoload() end
end })
tMisc:Section("Info")
tMisc:Label("Executor: " .. EXEC)
tMisc:Label("Place: " .. tostring(game.PlaceId))
local gidLbl = tMisc:Label("GameID: -")
tMisc:Button({ Name = "Unload Topaz", Callback = function() Win:Destroy() end })


function F.perfectKick()
    local ev = G.remotes()
    if not ev then return false end
    local p, va, aim = CFG.kickPower, math.clamp(60 - math.floor((60 - CFG.kickAngle) / 4 + 0.5) * 4, 30, 60), CFG.kickAim
    local ok = pcall(function()
        ev:FireServer("Mechanics", "KickPowerSet", p)
        ev:FireServer("Mechanics", "KickAngleChanged", p, va, aim)
        ev:FireServer("Mechanics", "KickAccuracySet", va)
        ev:FireServer("Mechanics", "KickHiked", va, p, 0)
    end)
    return ok
end

tMech:Section("Kicking")
tMech:Label("Power 15 = max. Game angle starts at 60, each click = 4 deg. 44 = max distance.")
tMech:Slider({ Name = "Kick Power", Min = -75, Max = 15, Default = CFG.kickPower, Increment = 1, Callback = function(v) CFG.kickPower = v end })
tMech:Slider({ Name = "Kick Angle", Min = 32, Max = 60, Default = CFG.kickAngle, Increment = 4, Suffix = " deg", Callback = function(v) CFG.kickAngle = v end })
tMech:Slider({ Name = "Horizontal Aim", Min = -60, Max = 60, Default = CFG.kickAim, Increment = 1, Callback = function(v) CFG.kickAim = v end })
tMech:Button({ Name = "Perfect Kick", Callback = function()
    if not F.perfectKick() then notify("Kick", "No game remote - are you the kicker?") end
end })

local hold = false
local touchUi = UserInputService.TouchEnabled or GENV.ChronixForceMobile
bind("pullHold", UserInputService.InputBegan:Connect(function(inp, gp)
    if gp then return end
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or (inp.UserInputType == Enum.UserInputType.Touch and not touchUi) then
        hold = true
    elseif inp.UserInputType == Enum.UserInputType.Keyboard then
        if UserInputService:GetFocusedTextBox() then return end
        if inp.KeyCode == Enum.KeyCode.H then
            local p = touchUi and F.aimTarget() or G.mhNearestMouse()
            RT.aim = p
            aimLbl:Set("target: " .. (p and p.Name or "none"))
            notify("Aimbot", p and ("Selected: " .. p.Name) or "No player found", 2)
        elseif inp.KeyCode == Enum.KeyCode.T then
            if not RT.aim then notify("Aimbot", "No target locked - press H", 2) return end
            local ok, why = F.throwTo(RT.aim)
            if not ok then notify("Aimbot", "Throw failed - " .. tostring(why), 2) end
        end
    end
end))
bind("pullRelease", UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or (inp.UserInputType == Enum.UserInputType.Touch and not touchUi) then
        hold = false
    end
end))

bind("mainLoop", RunService.Heartbeat:Connect(function()
    if not RT.alive then return end
    RT.pullOwner = (hold and (CFG.pull or CFG.legit)) and "manual" or nil
    if not hold then RT.mp = nil end
    if hold then
        if CFG.pull then
            F.pullTo(true)
        elseif CFG.legit then
            F.pullTo(false)
        end
    end
end))

bind("charAdded", LP.CharacterAdded:Connect(function()
    task.wait(1)
    if not RT.alive then return end
    if CFG.walk and not RT.dsFreeze then F.walk() end
    if CFG.jump then F.jump() end
end))

task.spawn(function()
    local lastTxt
    while RT.alive do
        local gid = G.gameId()
        local txt = "GameID: " .. ((gid and gid ~= "") and gid or "-")
        if txt ~= lastTxt then
            lastTxt = txt
            pcall(function() gidLbl:Set(txt) end)
        end
        task.wait(4)
    end
end)

if not UserInputService.KeyboardEnabled or UserInputService.TouchEnabled or GENV.ChronixForceMobile then
    local mob = mk("ScreenGui", { Name = "CHXTPZ_MOB", ResetOnSpawn = false, DisplayOrder = 9998 })
    parentGui(mob)
    RT.mob = mob
    local holder = mk("Frame", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.new(0, 84, 0, 352),
    }, mob)
    mk("UIListLayout", { Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Bottom }, holder)
    local grip = mk("TextLabel", {
        BackgroundColor3 = THEME.panel, BackgroundTransparency = 0.3, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 16),
        Font = Enum.Font.GothamBold, Text = "· · ·", TextColor3 = THEME.text, TextSize = 12, LayoutOrder = -1,
    }, holder)
    corner(grip, 8)
    local gripStart, gripPos
    grip.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
            gripStart, gripPos = inp.Position, holder.Position
        end
    end)
    bind("mobDrag", UserInputService.InputChanged:Connect(function(inp)
        if gripStart and (inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseMovement) then
            local d = inp.Position - gripStart
            holder.Position = UDim2.new(gripPos.X.Scale, gripPos.X.Offset + d.X, gripPos.Y.Scale, gripPos.Y.Offset + d.Y)
        end
    end))
    bind("mobDragEnd", UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then gripStart = nil end
    end))
    local function mbtn(text, fn)
        local b = mk("TextButton", {
            BackgroundColor3 = THEME.panel, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 46),
            Font = Enum.Font.GothamBold, Text = text, TextColor3 = THEME.text, TextSize = 12,
            AutoButtonColor = false,
        }, holder)
        corner(b, 12)
        local st = stroke(b, Color3.new(1, 1, 1), 1.5)
        mk("UIGradient", { Color = irid(), Rotation = 45 }, st)
        b.MouseButton1Down:Connect(function() tw(b, 0.1, { BackgroundColor3 = THEME.rowhi }) end)
        b.MouseButton1Up:Connect(function() tw(b, 0.1, { BackgroundColor3 = THEME.panel }) end)
        b.MouseButton1Click:Connect(function() task.spawn(fn) end)
        return b
    end
    local pullBtn = mbtn("PULL (hold)", function() end)
    pullBtn.MouseButton1Down:Connect(function() hold = true end)
    pullBtn.MouseButton1Up:Connect(function() hold = false end)
    pullBtn.MouseLeave:Connect(function() hold = false end)
    pullBtn.InputEnded:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.Touch then hold = false end end)
    mbtn("CATCH", function() G.fire("Catching", true) end)
    local function mtoggle(label, key, fn)
        local b
        b = mbtn(label, function()
            CFG[key] = not CFG[key]
            fn()
            if hotToggles[key] then pcall(function() hotToggles[key]:Set(CFG[key], true) end) end
        end)
        local function paint()
            b.Text = label .. (CFG[key] and " ON" or "")
            b.TextColor3 = CFG[key] and Color3.fromRGB(90, 230, 120) or THEME.text
        end
        paint()
        task.spawn(function()
            local was
            while RT.alive and b.Parent do
                if CFG[key] ~= was then was = CFG[key] paint() end
                task.wait(0.5)
            end
        end)
    end
    mtoggle("MAGS", "dmags", F.dmags)
    mtoggle("FLY", "fly", F.fly)
    mbtn("LOCK", function()
        local p = F.aimTarget() RT.aim = p
        aimLbl:Set("target: " .. (p and p.Name or "none"))
    end)
    mbtn("THROW", function()
        if not RT.aim then notify("Aimbot", "No target locked - tap LOCK", 2) return end
        local ok, why = F.throwTo(RT.aim)
        if not ok then notify("Aimbot", "Throw failed - " .. tostring(why), 2) end
    end)
end

local function destroy()
    local reg = GENV.Topaz
    if reg and reg.token ~= MYTOKEN then return end
    if RT.dead then return end
    RT.dead = true
    RT.alive = false
    CFGIO.off = true
    RT.afkLoop = nil
    if RT.afkDisabled then pcall(G.afkGameConns, false) RT.afkDisabled = nil end
    for k in pairs(RT.conns) do unbind(k) end
    clearHighlights()
    hbClear()
    if RT.landPart then pcall(function() RT.landPart:Destroy() end) RT.landPart = nil end
    AC.disable()
    CFG_RAW.walk = false CFG_RAW.jump = false CFG_RAW.hitbox = false CFG_RAW.bighead = false
    CFG_RAW.cwalk = false CFG_RAW.autoTD = false CFG_RAW.hbShow = false
    if RT.ds then
        local _, dhrp = G.char()
        if dhrp and RT.ds.moved then pcall(function() dhrp.CFrame = RT.ds.origin end) end
        RT.ds = nil
    end
    F.walk() F.hitbox() F.bighead()
    for _, k in ipairs({ "gpWalk", "gpJump", "gpDive", "gpRegen", "gpDrain", "gravity", "ownHb", "headClone", "sticky", "safeArc", "catchRing", "hideArc", "smooth", "mapClean", "noAds", "jpv", "dmags", "fly", "noclip" }) do CFG_RAW[k] = false end
    RT.kbCap = nil
    for _, fn in ipairs({ F.gameParams, F.ownHb, F.headClone, F.sticky, F.safeArc, F.catchRing, F.hideArc, F.smooth, F.mapClean, F.noAds, F.jpv, F.dmags, F.fly, F.noclip, F.fearOff }) do pcall(fn) end
    RT.dmSpoof = false
    if RT.gpConn then for _, c in pairs(RT.gpConn) do pcall(function() c:Disconnect() end) end RT.gpConn = nil end
    pcall(function() if WM then WM:Destroy() end end)
    pcall(function() if RT.mob then RT.mob:Destroy() end end)
    pcall(function() Win.Gui:Destroy() end)
    if GENV.Topaz and GENV.Topaz.token == MYTOKEN then GENV.Topaz = nil end
end

Win:OnClose(destroy)
bind("guiGone", Win.Gui.Destroying:Connect(function() task.spawn(destroy) end))
bind("guiAnc", Win.Gui.AncestryChanged:Connect(function(_, parent)
    if not parent then task.spawn(destroy) end
end))

GENV.Topaz = { token = MYTOKEN, destroy = destroy, cfg = CFG, win = Win, G = G, F = F, RT = RT }

if CFG.bypass then
    if AC.enable() then
        bypassLbl:Set("Active - speed/jump/height reports blocked")
    else
        bypassLbl:Set("Waiting for the game tracker - retrying")
        task.spawn(function()
            local tries = 0
            while RT.alive and CFG.bypass and not AC.on and tries < 60 do
                task.wait(2)
                tries = tries + 1
                if RT.alive and CFG.bypass and AC.enable() then
                    pcall(function() bypassLbl:Set("Active - speed/jump/height reports blocked") end)
                end
            end
            if RT.alive and CFG.bypass and not AC.on then
                pcall(function() bypassLbl:Set("FAILED - module not found, stay under the limits") end)
            end
        end)
    end
else
    bypassLbl:Set("OFF - you are reported above WalkSpeed 25 / height 12")
end
if not G.clientFunctions() then
    task.delay(6, function()
        if RT.alive and not G.clientFunctions() then
            notify("Topaz", EXEC .. ": could not require the game's ClientFunctions - bypass and stamina may not work", 6)
        end
    end)
end
F.antiAdmin(notify)
do
    local miss = {}
    if WEAK_EXEC or type(hookmetamethod) ~= "function" or type(checkcaller) ~= "function" then miss[#miss + 1] = "hookmetamethod (Desync Mags spoof)" end
    if type(getconnections) ~= "function" then miss[#miss + 1] = "getconnections (game idle kick block)" end
    if type(queue_on_teleport) ~= "function" and not (syn and syn.queue_on_teleport) then miss[#miss + 1] = "queue_on_teleport (autoload)" end
    if type(writefile) ~= "function" or type(readfile) ~= "function" then miss[#miss + 1] = "writefile (settings save)" end
    if #miss > 0 then
        task.delay(2, function()
            if RT.alive then notify("Topaz on " .. EXEC, "Missing: " .. table.concat(miss, ", ") .. ". Everything else works.", 7) end
        end)
    end
end
task.spawn(function()
    local arm = {
        { "walk", F.walk }, { "cwalk", F.cwalk }, { "jump", F.jump }, { "stamina", F.stamina },
        { "autoCatch", F.autoCatch }, { "apv", F.desync }, { "autoHike", F.autoHike }, { "follow", F.follow },
        { "autoDive", F.autoDive }, { "hitbox", F.hitbox }, { "reach", F.reach },
        { "bighead", F.bighead }, { "hbShow", F.hbShow }, { "autoTD", F.autoTD }, { "antiAfk", F.antiAfk },
        { "rush", F.rush }, { "intercept", F.intercept }, { "autoBlock", F.autoBlock }, { "landEsp", F.landEsp },
        { "landCatch", F.landCatch },
        { "gpWalk", F.gameParams }, { "gpJump", F.gameParams }, { "gpDive", F.gameParams }, { "gpRegen", F.gameParams },
        { "gpDrain", F.gameParams }, { "gravity", F.gameParams }, { "ownHb", F.ownHb }, { "headClone", F.headClone },
        { "sticky", F.sticky }, { "safeArc", F.safeArc }, { "catchRing", F.catchRing }, { "hideArc", F.hideArc },
        { "smooth", F.smooth }, { "mapClean", F.mapClean }, { "noAds", F.noAds }, { "jpv", F.jpv },
        { "dmags", F.dmags }, { "fly", F.fly }, { "noclip", F.noclip },
        { "ttb", F.ttb }, { "headSink", F.headSink }, { "headManip", F.headManip }, { "headFollow", F.headFollow }, { "boostJump", F.boostJump }, { "sideFling", F.sideFling }, { "contactBoost", F.contactBoost }, { "landBoost", F.landBoost }, { "diveForce", F.diveForce }, { "fastFall", F.fastFall }, { "hipHeight", F.hipHeight },
    }
    local n = 0
    for _, e in ipairs(arm) do
        if CFG_RAW[e[1]] and type(e[2]) == "function" then
            n = n + 1
            pcall(e[2])
        end
    end
    if CFG_RAW.espBall or CFG_RAW.espCarrier or CFG_RAW.espPlayers then
        n = n + 1
        pcall(F.esp)
    end
    if n > 0 then notify("Topaz", "Restored " .. n .. " saved setting" .. (n == 1 and "" or "s"), 4) end
    if CFG_RAW.autoload then pcall(F.autoload, true) end
end)
task.delay(1, function()
    if not RT.alive then return end
    local gid = G.gameId()
    if not gid or gid == "" then
        notify("Topaz", "No live match yet - features arm when you join one", 5)
    end
end)
if not (writefile and readfile and isfile and isfolder and makefolder) then
    notify("Topaz", EXEC .. " has no file access - settings will not save between servers", 6)
end
notify("Topaz", "Loaded on " .. EXEC, 4)
