-- url: https://chronix-gate.net/m?sid=2e2ba7d6cf279fc59441783ded16b0d2efd76e554bcb5fa4&n=main&z=786459007x52
-- bundled by build_bundle.py: shared libraries inlined, no network or workspace files required
local __CHRONIX_BUNDLE = {}
__CHRONIX_BUNDLE["lib_ember"] = [==[
--[[
    Ember UI Library v1.0
    Warm dashboard TILE-GRID library for Roblox executors.
    Every element is a card/tile laid out two per row.

    Usage:
        local Ember = loadstring(readfile("UI/Ember/Ember.lua"))()
        local Window = Ember:CreateWindow({ Name = "My Hub", ToggleKey = Enum.KeyCode.RightShift })
        local Tab = Window:CreateTab("Main")
        Tab:CreateToggle({ Name = "Auto Farm", Flag = "AutoFarm", Callback = function(v) end })

    Elements: Section, Label, Button, Toggle, Slider, Dropdown, Input, Keybind
    Extras:   Ember:Notify, Ember.Flags, Ember:SaveConfig / LoadConfig, Ember:Destroy
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

local Ember = {
    Flags = {},
    Windows = {},
    ToggleKey = Enum.KeyCode.RightShift,
    ConfigFolder = "EmberUI",
}

-- // Theme ------------------------------------------------------------------
local Theme = {
    Background = Color3.fromRGB(22, 19, 15),   -- charcoal
    Card       = Color3.fromRGB(33, 29, 24),
    CardHover  = Color3.fromRGB(42, 37, 30),
    Accent     = Color3.fromRGB(255, 122, 26), -- ember orange
    AccentDark = Color3.fromRGB(180, 80, 15),  -- deep amber
    Text       = Color3.fromRGB(245, 238, 228),
    Muted      = Color3.fromRGB(160, 148, 132),
    Stroke     = Color3.fromRGB(52, 45, 36),
}
Ember.Theme = Theme

-- // Helpers ----------------------------------------------------------------
local function New(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then inst[k] = v end
    end
    for _, child in ipairs(children or {}) do
        child.Parent = inst
    end
    if props and props.Parent then inst.Parent = props.Parent end
    return inst
end

local function Tween(inst, props, time)
    local t = TweenService:Create(inst, TweenInfo.new(time or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function Round(inst, radius)
    return New("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = inst })
end

local function Stroke(inst, color, thickness)
    return New("UIStroke", {
        Color = color or Theme.Stroke,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = inst,
    })
end

local function ProtectGui(gui)
    local function landed(fn)
        pcall(fn)
        return gui.Parent ~= nil
    end

    if typeof(gethui) == "function" then
        if landed(function() gui.Parent = gethui() end) then return end
    end

    if syn and syn.protect_gui then
        if landed(function()
            syn.protect_gui(gui)
            gui.Parent = game:GetService("CoreGui")
        end) then return end
    end

    if landed(function() gui.Parent = game:GetService("CoreGui") end) then return end

    landed(function()
        local lp = game:GetService("Players").LocalPlayer
        if not lp then return end
        local pg = lp:FindFirstChildOfClass("PlayerGui") or lp:WaitForChild("PlayerGui", 10)
        gui.Parent = pg
    end)
end

local function MakeDraggable(handle, target)
    local dragging, dragInput, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = target.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local function KeyName(keyCode)
    if not keyCode then return "None" end
    return keyCode.Name
end

-- // Root gui ---------------------------------------------------------------
local RootGui = New("ScreenGui", {
    Name = "EmberUI_" .. HttpService:GenerateGUID(false):sub(1, 8),
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    -- IgnoreGuiInset intentionally NOT set: popup positioning relies on a
    -- consistent AbsolutePosition space shared with every other element
})
ProtectGui(RootGui)

-- shared popup layer: dropdown lists render here, above everything
local PopupLayer = New("Frame", {
    Name = "EmberPopups",
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 1, 0),
    ZIndex = 100,
    Parent = RootGui,
})
local ActivePopup = nil
local function ClosePopup()
    if ActivePopup then
        ActivePopup.Visible = false
        ActivePopup = nil
    end
end
local function OpenPopup(popup)
    if ActivePopup == popup then
        ClosePopup()
        return
    end
    ClosePopup()
    popup.Visible = true
    ActivePopup = popup
end

-- // Notifications ----------------------------------------------------------
local NotifHolder = New("Frame", {
    Name = "Notifications",
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -16, 0, 16),
    Size = UDim2.new(0, 280, 1, -32),
    BackgroundTransparency = 1,
    ZIndex = 200,
    Parent = RootGui,
}, {
    New("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Top,
        Padding = UDim.new(0, 8),
    }),
})

function Ember:Notify(cfg)
    cfg = cfg or {}
    local duration = cfg.Duration or 4

    local frame = New("Frame", {
        BackgroundColor3 = Theme.Card,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 201,
        Parent = NotifHolder,
    })
    Round(frame, 10)
    Stroke(frame)

    local emberBar = New("Frame", { -- signature ember bar down the left edge
        BackgroundColor3 = Theme.Accent,
        Position = UDim2.new(0, 8, 0, 8),
        Size = UDim2.new(0, 3, 1, -16),
        BorderSizePixel = 0,
        ZIndex = 202,
        Parent = frame,
    })
    Round(emberBar, 2)

    local title = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 22, 0, 10),
        Size = UDim2.new(1, -34, 0, 18),
        Font = Enum.Font.GothamBold,
        Text = cfg.Title or "Ember",
        TextColor3 = Theme.Text,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTransparency = 1,
        ZIndex = 202,
        Parent = frame,
    })
    local body = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 22, 0, 30),
        Size = UDim2.new(1, -34, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Font = Enum.Font.GothamMedium,
        Text = cfg.Content or "",
        TextColor3 = Theme.Muted,
        TextSize = 13,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextTransparency = 1,
        ZIndex = 202,
        Parent = frame,
    })
    New("UIPadding", { PaddingBottom = UDim.new(0, 12), Parent = frame })

    Tween(frame, { BackgroundTransparency = 0.03 }, 0.25)
    Tween(title, { TextTransparency = 0 }, 0.25)
    Tween(body, { TextTransparency = 0.1 }, 0.25)

    task.delay(duration, function()
        if not frame.Parent then return end
        Tween(frame, { BackgroundTransparency = 1 }, 0.3)
        Tween(title, { TextTransparency = 1 }, 0.3)
        Tween(body, { TextTransparency = 1 }, 0.3)
        task.wait(0.32)
        frame:Destroy()
    end)
end

-- // Config saving ----------------------------------------------------------
local function CanUseFiles()
    return typeof(writefile) == "function" and typeof(readfile) == "function" and typeof(isfile) == "function"
end

function Ember:SaveConfig(name)
    if not CanUseFiles() then return false, "executor has no file API" end
    name = name or "default"
    local data = {}
    for flag, obj in pairs(Ember.Flags) do
        local v = obj:Get()
        if typeof(v) == "EnumItem" then
            data[flag] = { __keycode = v.Name }
        elseif typeof(v) == "Color3" then
            data[flag] = { __color = { v.R, v.G, v.B } }
        elseif typeof(v) == "boolean" or typeof(v) == "number" or typeof(v) == "string" or typeof(v) == "table" then
            data[flag] = v
        end
    end
    if typeof(isfolder) == "function" and typeof(makefolder) == "function" and not isfolder(Ember.ConfigFolder) then
        makefolder(Ember.ConfigFolder)
    end
    writefile(Ember.ConfigFolder .. "/" .. name .. ".json", HttpService:JSONEncode(data))
    return true
end

function Ember:LoadConfig(name)
    if not CanUseFiles() then return false, "executor has no file API" end
    name = name or "default"
    local path = Ember.ConfigFolder .. "/" .. name .. ".json"
    if not isfile(path) then return false, "no config file" end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok then return false, "corrupt config" end
    for flag, v in pairs(data) do
        local obj = Ember.Flags[flag]
        if obj then
            if typeof(v) == "table" and v.__keycode then
                obj:Set(Enum.KeyCode[v.__keycode])
            elseif typeof(v) == "table" and v.__color then
                obj:Set(Color3.new(v.__color[1], v.__color[2], v.__color[3]))
            else
                obj:Set(v)
            end
        end
    end
    return true
end

-- // Window -----------------------------------------------------------------
function Ember:CreateWindow(cfg)
    cfg = cfg or {}
    local windowName = cfg.Name or "Ember"
    if cfg.ToggleKey then Ember.ToggleKey = cfg.ToggleKey end

    local Main = New("Frame", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = cfg.Size or UDim2.new(0, 620, 0, 430),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Parent = RootGui,
    })
    Round(Main, 12)
    Stroke(Main)

    -- Top bar: title + underlined tab buttons + window controls
    local TopBar = New("Frame", {
        Name = "TopBar",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 48),
        Parent = Main,
    })

    New("TextLabel", { -- ember diamond mark
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 16, 0, 0),
        Size = UDim2.new(0, 14, 1, 0),
        Font = Enum.Font.GothamBold,
        Text = "◆",
        TextColor3 = Theme.Accent,
        TextSize = 13,
        Parent = TopBar,
    })
    New("TextLabel", { -- window title
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 34, 0, 0),
        Size = UDim2.new(0, 140, 1, 0),
        Font = Enum.Font.GothamBold,
        Text = windowName,
        TextColor3 = Theme.Text,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = TopBar,
    })

    local TabBar = New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 182, 0, 0),
        Size = UDim2.new(1, -182 - 76, 1, 0),
        Parent = TopBar,
    }, {
        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder = Enum.SortOrder.LayoutOrder,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 4),
        }),
    })

    local CloseBtn = New("TextButton", {
        BackgroundColor3 = Theme.Card,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.new(0, 26, 0, 26),
        Font = Enum.Font.GothamBold,
        Text = "×",
        TextColor3 = Theme.Muted,
        TextSize = 16,
        AutoButtonColor = false,
        Parent = TopBar,
    })
    Round(CloseBtn, 8)
    local HideBtn = New("TextButton", {
        BackgroundColor3 = Theme.Card,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -44, 0.5, 0),
        Size = UDim2.new(0, 26, 0, 26),
        Font = Enum.Font.GothamBold,
        Text = "—",
        TextColor3 = Theme.Muted,
        TextSize = 12,
        AutoButtonColor = false,
        Parent = TopBar,
    })
    Round(HideBtn, 8)

    New("Frame", { -- divider under top bar
        BackgroundColor3 = Theme.Stroke,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 12, 0, 48),
        Size = UDim2.new(1, -24, 0, 1),
        Parent = Main,
    })

    MakeDraggable(TopBar, Main)

    CloseBtn.MouseEnter:Connect(function() Tween(CloseBtn, { TextColor3 = Theme.Accent }) end)
    CloseBtn.MouseLeave:Connect(function() Tween(CloseBtn, { TextColor3 = Theme.Muted }) end)
    HideBtn.MouseEnter:Connect(function() Tween(HideBtn, { TextColor3 = Theme.Accent }) end)
    HideBtn.MouseLeave:Connect(function() Tween(HideBtn, { TextColor3 = Theme.Muted }) end)

    CloseBtn.MouseButton1Click:Connect(function()
        ClosePopup()
        RootGui:Destroy()
    end)
    HideBtn.MouseButton1Click:Connect(function()
        ClosePopup()
        Main.Visible = false
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Ember.ToggleKey then
            Main.Visible = not Main.Visible
            if not Main.Visible then ClosePopup() end
        end
    end)

    local Content = New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 49),
        Size = UDim2.new(1, 0, 1, -49),
        Parent = Main,
    })

    local Window = { Tabs = {}, Main = Main, Gui = RootGui }
    local firstTab = true

    -- // Tab -----------------------------------------------------------------
    function Window:CreateTab(tabName)
        local TabButton = New("TextButton", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 0, 0, 30),
            AutomaticSize = Enum.AutomaticSize.X,
            Font = Enum.Font.GothamMedium,
            Text = tabName,
            TextColor3 = Theme.Muted,
            TextSize = 14,
            AutoButtonColor = false,
            Parent = TabBar,
        })
        New("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = TabButton })
        local Underline = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.new(0.5, 0, 1, 0),
            Size = UDim2.new(1, -10, 0, 2),
            BackgroundColor3 = Theme.Accent,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Parent = TabButton,
        })
        Round(Underline, 1)

        local Page = New("ScrollingFrame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.AccentDark,
            BorderSizePixel = 0,
            Visible = false,
            Parent = Content,
        }, {
            New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }),
            New("UIPadding", {
                PaddingLeft = UDim.new(0, 14),
                PaddingRight = UDim.new(0, 14),
                PaddingTop = UDim.new(0, 12),
                PaddingBottom = UDim.new(0, 14),
            }),
        })

        local Tab = { Button = TabButton, Page = Page, Name = tabName }

        local function Select()
            for _, other in ipairs(Window.Tabs) do
                other.Page.Visible = false
                Tween(other.Button, { TextColor3 = Theme.Muted })
                Tween(other.Underline, { BackgroundTransparency = 1 })
            end
            Page.Visible = true
            Tween(TabButton, { TextColor3 = Theme.Accent })
            Tween(Underline, { BackgroundTransparency = 0 })
            ClosePopup()
        end
        Tab.Underline = Underline
        TabButton.MouseButton1Click:Connect(Select)
        table.insert(Window.Tabs, Tab)
        if firstTab then firstTab = false; Select() end

        -- // Tile-grid row manager -------------------------------------------
        -- The page is a UIListLayout of "rows". A row holds up to two tiles
        -- side by side; sections/labels are full-width rows and end pairing.
        local rowOrder = 0
        local pendingRow = nil -- { Frame = rowFrame } when the row has 1 tile

        local function NewRow(height)
            rowOrder = rowOrder + 1
            return New("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, height),
                LayoutOrder = rowOrder,
                Parent = Page,
            })
        end

        local function AddTile(height)
            local tile
            if pendingRow then
                local rowFrame = pendingRow.Frame
                pendingRow = nil
                if height > rowFrame.Size.Y.Offset then
                    rowFrame.Size = UDim2.new(1, 0, 0, height)
                end
                tile = New("Frame", {
                    Position = UDim2.new(0.5, 5, 0, 0),
                    Size = UDim2.new(0.5, -5, 0, height),
                    BackgroundColor3 = Theme.Card,
                    BorderSizePixel = 0,
                    Parent = rowFrame,
                })
            else
                local rowFrame = NewRow(height)
                pendingRow = { Frame = rowFrame }
                tile = New("Frame", {
                    Position = UDim2.new(0, 0, 0, 0),
                    Size = UDim2.new(0.5, -5, 0, height),
                    BackgroundColor3 = Theme.Card,
                    BorderSizePixel = 0,
                    Parent = rowFrame,
                })
            end
            Round(tile, 10)
            return tile, Stroke(tile)
        end

        local function EndPairing()
            pendingRow = nil
        end

        local function HoverFX(tile)
            tile.MouseEnter:Connect(function() Tween(tile, { BackgroundColor3 = Theme.CardHover }) end)
            tile.MouseLeave:Connect(function() Tween(tile, { BackgroundColor3 = Theme.Card }) end)
        end

        local function TileName(tile, text)
            return New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 9),
                Size = UDim2.new(1, -24, 0, 16),
                Font = Enum.Font.GothamMedium,
                Text = text,
                TextColor3 = Theme.Text,
                TextSize = 13,
                TextTruncate = Enum.TextTruncate.AtEnd,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = tile,
            })
        end

        -- // Section (full-width row) -----------------------------------------
        function Tab:CreateSection(text)
            EndPairing()
            local row = NewRow(22)
            New("Frame", { -- little ember tick
                BackgroundColor3 = Theme.Accent,
                Position = UDim2.new(0, 0, 0.5, -5),
                Size = UDim2.new(0, 3, 0, 10),
                BorderSizePixel = 0,
                Parent = row,
            })
            local lbl = New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 10, 0, 0),
                Size = UDim2.new(1, -10, 1, 0),
                Font = Enum.Font.GothamBold,
                Text = text,
                TextColor3 = Theme.Muted,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = row,
            })
            EndPairing()
            local obj = {}
            function obj:Set(t) lbl.Text = t end
            return obj
        end

        -- // Label (full-width card row) --------------------------------------
        function Tab:CreateLabel(text)
            EndPairing()
            local row = NewRow(34)
            local card = New("Frame", {
                BackgroundColor3 = Theme.Card,
                Size = UDim2.new(1, 0, 1, 0),
                BorderSizePixel = 0,
                Parent = row,
            })
            Round(card, 10)
            Stroke(card)
            local lbl = New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 0),
                Size = UDim2.new(1, -24, 1, 0),
                Font = Enum.Font.GothamMedium,
                Text = text,
                TextColor3 = Theme.Muted,
                TextSize = 13,
                TextTruncate = Enum.TextTruncate.AtEnd,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = card,
            })
            EndPairing()
            local obj = {}
            function obj:Set(t) lbl.Text = t end
            return obj
        end

        -- // Button tile ------------------------------------------------------
        function Tab:CreateButton(cfg2)
            cfg2 = cfg2 or {}
            local tile = AddTile(64)
            HoverFX(tile)
            TileName(tile, cfg2.Name or "Button")

            local chip = New("Frame", { -- "RUN ›" chip bottom-right
                AnchorPoint = Vector2.new(1, 1),
                Position = UDim2.new(1, -10, 1, -10),
                Size = UDim2.new(0, 62, 0, 22),
                BackgroundColor3 = Theme.AccentDark,
                BorderSizePixel = 0,
                Parent = tile,
            })
            Round(chip, 6)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Font = Enum.Font.GothamBold,
                Text = "RUN ›",
                TextColor3 = Theme.Text,
                TextSize = 12,
                Parent = chip,
            })

            local click = New("TextButton", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Text = "",
                Parent = tile,
            })
            click.MouseButton1Click:Connect(function()
                Tween(tile, { BackgroundColor3 = Theme.AccentDark }, 0.07)
                Tween(chip, { BackgroundColor3 = Theme.Accent }, 0.07)
                task.delay(0.12, function()
                    Tween(tile, { BackgroundColor3 = Theme.Card }, 0.25)
                    Tween(chip, { BackgroundColor3 = Theme.AccentDark }, 0.25)
                end)
                if cfg2.Callback then task.spawn(cfg2.Callback) end
            end)
            return { Frame = tile }
        end

        -- // Toggle tile ------------------------------------------------------
        function Tab:CreateToggle(cfg2)
            cfg2 = cfg2 or {}
            local state = cfg2.Default or false
            local tile, tileStroke = AddTile(64)
            HoverFX(tile)
            TileName(tile, cfg2.Name or "Toggle")

            local stateLabel = New("TextLabel", { -- dim status line
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 1, -26),
                Size = UDim2.new(1, -70, 0, 16),
                Font = Enum.Font.GothamMedium,
                Text = "off",
                TextColor3 = Theme.Muted,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = tile,
            })

            local pill = New("Frame", { -- big pill switch bottom-right
                AnchorPoint = Vector2.new(1, 1),
                Position = UDim2.new(1, -10, 1, -10),
                Size = UDim2.new(0, 42, 0, 22),
                BackgroundColor3 = Theme.Stroke,
                BorderSizePixel = 0,
                Parent = tile,
            })
            Round(pill, 11)
            local knob = New("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 3, 0.5, 0),
                Size = UDim2.new(0, 16, 0, 16),
                BackgroundColor3 = Theme.Text,
                BorderSizePixel = 0,
                Parent = pill,
            })
            Round(knob, 8)

            local obj = {}
            local function render()
                -- signature: whole tile border glows ember orange when ON
                Tween(tileStroke, {
                    Color = state and Theme.Accent or Theme.Stroke,
                    Transparency = state and 0.15 or 0,
                })
                Tween(pill, { BackgroundColor3 = state and Theme.Accent or Theme.Stroke })
                Tween(knob, { Position = state and UDim2.new(0, 23, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) })
                stateLabel.Text = state and "on" or "off"
                stateLabel.TextColor3 = state and Theme.Accent or Theme.Muted
            end
            function obj:Set(v)
                v = v and true or false
                if v == state then render() return end
                state = v
                render()
                if cfg2.Callback then task.spawn(cfg2.Callback, state) end
            end
            function obj:Get() return state end

            local click = New("TextButton", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Text = "",
                Parent = tile,
            })
            click.MouseButton1Click:Connect(function() obj:Set(not state) end)

            render()
            if state and cfg2.Callback then task.spawn(cfg2.Callback, state) end
            if cfg2.Flag then Ember.Flags[cfg2.Flag] = obj end
            return obj
        end

        -- // Slider tile ------------------------------------------------------
        function Tab:CreateSlider(cfg2)
            cfg2 = cfg2 or {}
            local min = cfg2.Min or 0
            local max = cfg2.Max or 100
            local increment = cfg2.Increment or 1
            local suffix = cfg2.Suffix or ""
            local value = math.clamp(cfg2.Default or min, min, max)

            local tile = AddTile(78)
            TileName(tile, cfg2.Name or "Slider")

            local valueLabel = New("TextLabel", { -- big orange value top-right
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -12, 0, 8),
                Size = UDim2.new(0, 110, 0, 20),
                Font = Enum.Font.GothamBold,
                Text = "",
                TextColor3 = Theme.Accent,
                TextSize = 17,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = tile,
            })

            local bar = New("Frame", { -- full-width bar along the bottom
                Position = UDim2.new(0, 12, 1, -22),
                Size = UDim2.new(1, -24, 0, 8),
                BackgroundColor3 = Theme.Background,
                BorderSizePixel = 0,
                Parent = tile,
            })
            Round(bar, 4)
            Stroke(bar)
            local fill = New("Frame", {
                Size = UDim2.new(0, 0, 1, 0),
                BackgroundColor3 = Theme.Accent,
                BorderSizePixel = 0,
                Parent = bar,
            })
            Round(fill, 4)

            local decimals = math.max(0, math.ceil(-math.log10(increment)))
            local obj = {}
            local function render()
                local alpha = (max == min) and 0 or (value - min) / (max - min)
                fill.Size = UDim2.new(alpha, 0, 1, 0)
                valueLabel.Text = string.format("%." .. decimals .. "f", value) .. (suffix ~= "" and (" " .. suffix) or "")
            end
            function obj:Set(v)
                v = math.clamp(math.floor(v / increment + 0.5) * increment, min, max)
                if v == value then render() return end
                value = v
                render()
                if cfg2.Callback then task.spawn(cfg2.Callback, value) end
            end
            function obj:Get() return value end

            local dragging = false
            local function updateFromInput(input)
                local alpha = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
                obj:Set(min + (max - min) * alpha)
            end
            bar.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    updateFromInput(input)
                end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    updateFromInput(input)
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = false
                end
            end)

            render()
            if cfg2.Flag then Ember.Flags[cfg2.Flag] = obj end
            return obj
        end

        -- // Dropdown tile (floating popup list) ------------------------------
        function Tab:CreateDropdown(cfg2)
            cfg2 = cfg2 or {}
            local options = cfg2.Options or {}
            local selected = cfg2.Default

            local tile = AddTile(64)
            HoverFX(tile)
            TileName(tile, cfg2.Name or "Dropdown")

            local chip = New("Frame", { -- selected-value chip along the bottom
                Position = UDim2.new(0, 10, 1, -32),
                Size = UDim2.new(1, -20, 0, 22),
                BackgroundColor3 = Theme.Background,
                BorderSizePixel = 0,
                Parent = tile,
            })
            Round(chip, 6)
            Stroke(chip)
            local selectedLabel = New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 8, 0, 0),
                Size = UDim2.new(1, -26, 1, 0),
                Font = Enum.Font.GothamMedium,
                Text = "",
                TextColor3 = Theme.Muted,
                TextSize = 12,
                TextTruncate = Enum.TextTruncate.AtEnd,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = chip,
            })
            New("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -6, 0, 0),
                Size = UDim2.new(0, 14, 1, 0),
                Font = Enum.Font.GothamBold,
                Text = "▾",
                TextColor3 = Theme.Accent,
                TextSize = 12,
                Parent = chip,
            })

            -- floating popup list on the shared popup layer (NOT inline:
            -- tiles sit in a grid, expanding one would break the layout)
            local popup = New("Frame", {
                BackgroundColor3 = Theme.CardHover,
                Size = UDim2.new(0, 200, 0, 0),
                Visible = false,
                ZIndex = 110,
                Parent = PopupLayer,
            })
            Round(popup, 8)
            Stroke(popup, Theme.AccentDark)
            local popupScroll = New("ScrollingFrame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                CanvasSize = UDim2.new(),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ScrollBarThickness = 2,
                ScrollBarImageColor3 = Theme.AccentDark,
                BorderSizePixel = 0,
                ZIndex = 110,
                Parent = popup,
            }, {
                New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
                New("UIPadding", {
                    PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4),
                    PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
                }),
            })

            local obj = {}
            local optionButtons = {}

            local function renderSelection()
                selectedLabel.Text = selected ~= nil and tostring(selected) or "Select…"
                selectedLabel.TextColor3 = selected ~= nil and Theme.Text or Theme.Muted
                for opt, btn in pairs(optionButtons) do
                    btn.TextColor3 = (opt == selected) and Theme.Accent or Theme.Muted
                end
            end

            local function buildOptions()
                for _, btn in pairs(optionButtons) do btn:Destroy() end
                optionButtons = {}
                for _, opt in ipairs(options) do
                    local btn = New("TextButton", {
                        BackgroundColor3 = Theme.Card,
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, 22),
                        Font = Enum.Font.GothamMedium,
                        Text = "  " .. tostring(opt),
                        TextColor3 = Theme.Muted,
                        TextSize = 12,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        AutoButtonColor = false,
                        ZIndex = 111,
                        Parent = popupScroll,
                    })
                    Round(btn, 5)
                    btn.MouseEnter:Connect(function() btn.BackgroundTransparency = 0 end)
                    btn.MouseLeave:Connect(function() btn.BackgroundTransparency = 1 end)
                    btn.MouseButton1Click:Connect(function()
                        obj:Set(opt)
                        ClosePopup()
                    end)
                    optionButtons[opt] = btn
                end
            end

            function obj:Set(opt)
                if selected == opt then renderSelection() return end
                selected = opt
                renderSelection()
                if cfg2.Callback then task.spawn(cfg2.Callback, selected) end
            end
            function obj:Get() return selected end
            function obj:Refresh(newOptions, keepSelection)
                options = newOptions or {}
                if not keepSelection then selected = nil end
                buildOptions()
                renderSelection()
            end

            local click = New("TextButton", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Text = "",
                Parent = tile,
            })
            click.MouseButton1Click:Connect(function()
                local listHeight = math.min(#options * 24 + 8, 170)
                popup.Position = UDim2.new(0, math.floor(chip.AbsolutePosition.X), 0, math.floor(chip.AbsolutePosition.Y + chip.AbsoluteSize.Y + 4))
                popup.Size = UDim2.new(0, math.floor(chip.AbsoluteSize.X), 0, listHeight)
                OpenPopup(popup)
            end)

            buildOptions()
            renderSelection()
            if cfg2.Flag then Ember.Flags[cfg2.Flag] = obj end
            return obj
        end

        function Tab:CreateMultiDropdown(cfg2)
            cfg2 = cfg2 or {}
            local options = cfg2.Options or {}
            local chosen = {}
            for _, v in ipairs(cfg2.Default or {}) do chosen[v] = true end

            local tile = AddTile(64)
            HoverFX(tile)
            TileName(tile, cfg2.Name or "Multi Select")

            local chip = New("Frame", {
                Position = UDim2.new(0, 10, 1, -32),
                Size = UDim2.new(1, -20, 0, 22),
                BackgroundColor3 = Theme.Background,
                BorderSizePixel = 0,
                Parent = tile,
            })
            Round(chip, 6)
            Stroke(chip)
            local selectedLabel = New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 8, 0, 0),
                Size = UDim2.new(1, -26, 1, 0),
                Font = Enum.Font.GothamMedium,
                Text = "",
                TextColor3 = Theme.Muted,
                TextSize = 12,
                TextTruncate = Enum.TextTruncate.AtEnd,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = chip,
            })
            New("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -6, 0, 0),
                Size = UDim2.new(0, 14, 1, 0),
                Font = Enum.Font.GothamBold,
                Text = "▾",
                TextColor3 = Theme.Accent,
                TextSize = 12,
                Parent = chip,
            })

            local popup = New("Frame", {
                BackgroundColor3 = Theme.CardHover,
                Size = UDim2.new(0, 200, 0, 0),
                Visible = false,
                ZIndex = 110,
                Parent = PopupLayer,
            })
            Round(popup, 8)
            Stroke(popup, Theme.AccentDark)
            local popupScroll = New("ScrollingFrame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                CanvasSize = UDim2.new(),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ScrollBarThickness = 2,
                ScrollBarImageColor3 = Theme.AccentDark,
                BorderSizePixel = 0,
                ZIndex = 110,
                Parent = popup,
            }, {
                New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
                New("UIPadding", {
                    PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4),
                    PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
                }),
            })

            local obj = {}
            local optionButtons = {}
            local clearBtn = nil
            local emptyText = cfg2.EmptyText or "None"

            local function list()
                local out = {}
                for _, opt in ipairs(options) do
                    if chosen[opt] then table.insert(out, opt) end
                end
                return out
            end

            local function renderSelection()
                local l = list()
                if #l == 0 then
                    selectedLabel.Text = emptyText
                    selectedLabel.TextColor3 = Theme.Muted
                else
                    local parts = {}
                    for _, v in ipairs(l) do table.insert(parts, tostring(v)) end
                    selectedLabel.Text = (#l == #options and #options > 1) and ("All (" .. #l .. ")") or table.concat(parts, ", ")
                    selectedLabel.TextColor3 = Theme.Text
                end
                for opt, btn in pairs(optionButtons) do
                    btn.TextColor3 = chosen[opt] and Theme.Accent or Theme.Muted
                    btn.Text = (chosen[opt] and "  + " or "     ") .. tostring(opt)
                end
            end

            local function fire()
                if cfg2.Callback then task.spawn(cfg2.Callback, list()) end
            end

            local function buildOptions()
                for _, btn in pairs(optionButtons) do btn:Destroy() end
                optionButtons = {}
                if clearBtn then clearBtn:Destroy() end
                clearBtn = New("TextButton", {
                    BackgroundColor3 = Theme.Card,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 22),
                    Font = Enum.Font.GothamBold,
                    Text = "  clear / select all",
                    TextColor3 = Theme.AccentDark,
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    AutoButtonColor = false,
                    LayoutOrder = 0,
                    ZIndex = 111,
                    Parent = popupScroll,
                })
                Round(clearBtn, 5)
                clearBtn.MouseButton1Click:Connect(function()
                    local any = next(chosen) ~= nil
                    chosen = {}
                    if not any then
                        for _, opt in ipairs(options) do chosen[opt] = true end
                    end
                    renderSelection()
                    fire()
                end)
                for i, opt in ipairs(options) do
                    local btn = New("TextButton", {
                        BackgroundColor3 = Theme.Card,
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, 22),
                        Font = Enum.Font.GothamMedium,
                        Text = "     " .. tostring(opt),
                        TextColor3 = Theme.Muted,
                        TextSize = 12,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        AutoButtonColor = false,
                        LayoutOrder = i,
                        ZIndex = 111,
                        Parent = popupScroll,
                    })
                    Round(btn, 5)
                    btn.MouseEnter:Connect(function() btn.BackgroundTransparency = 0 end)
                    btn.MouseLeave:Connect(function() btn.BackgroundTransparency = 1 end)
                    btn.MouseButton1Click:Connect(function()
                        chosen[opt] = (not chosen[opt]) or nil
                        renderSelection()
                        fire()
                    end)
                    optionButtons[opt] = btn
                end
            end

            function obj:Set(arr)
                chosen = {}
                if type(arr) == "table" then
                    for k, v in pairs(arr) do
                        if type(k) == "number" then chosen[v] = true elseif v == true then chosen[k] = true end
                    end
                end
                renderSelection()
                fire()
            end
            function obj:Get() return list() end
            function obj:Refresh(newOptions, keepSelection)
                options = newOptions or {}
                if not keepSelection then chosen = {} end
                buildOptions()
                renderSelection()
            end

            local click = New("TextButton", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Text = "",
                Parent = tile,
            })
            click.MouseButton1Click:Connect(function()
                local listHeight = math.min((#options + 1) * 24 + 8, 220)
                popup.Position = UDim2.new(0, math.floor(chip.AbsolutePosition.X), 0, math.floor(chip.AbsolutePosition.Y + chip.AbsoluteSize.Y + 4))
                popup.Size = UDim2.new(0, math.floor(chip.AbsoluteSize.X), 0, listHeight)
                OpenPopup(popup)
            end)

            buildOptions()
            renderSelection()
            if next(chosen) ~= nil then fire() end
            if cfg2.Flag then Ember.Flags[cfg2.Flag] = obj end
            return obj
        end

        -- // Input tile -------------------------------------------------------
        function Tab:CreateInput(cfg2)
            cfg2 = cfg2 or {}
            local tile = AddTile(64)
            TileName(tile, cfg2.Name or "Input")

            local boxHolder = New("Frame", {
                Position = UDim2.new(0, 10, 1, -32),
                Size = UDim2.new(1, -20, 0, 22),
                BackgroundColor3 = Theme.Background,
                BorderSizePixel = 0,
                Parent = tile,
            })
            Round(boxHolder, 6)
            local boxStroke = Stroke(boxHolder)
            local box = New("TextBox", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 8, 0, 0),
                Size = UDim2.new(1, -16, 1, 0),
                Font = Enum.Font.GothamMedium,
                Text = cfg2.Default or "",
                PlaceholderText = cfg2.Placeholder or "…",
                PlaceholderColor3 = Theme.Muted,
                TextColor3 = Theme.Text,
                TextSize = 12,
                ClearTextOnFocus = false,
                TextTruncate = Enum.TextTruncate.AtEnd,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = boxHolder,
            })
            box.Focused:Connect(function()
                Tween(boxStroke, { Color = Theme.Accent })
            end)
            box.FocusLost:Connect(function(enterPressed)
                Tween(boxStroke, { Color = Theme.Stroke })
                if cfg2.Callback then task.spawn(cfg2.Callback, box.Text, enterPressed) end
            end)

            local obj = {}
            function obj:Set(t)
                box.Text = tostring(t)
                if cfg2.Callback then task.spawn(cfg2.Callback, box.Text, false) end
            end
            function obj:Get() return box.Text end
            if cfg2.Flag then Ember.Flags[cfg2.Flag] = obj end
            return obj
        end

        -- // Keybind tile -----------------------------------------------------
        function Tab:CreateKeybind(cfg2)
            cfg2 = cfg2 or {}
            local key = cfg2.Default -- Enum.KeyCode or nil
            local listening = false

            local tile = AddTile(64)
            HoverFX(tile)
            TileName(tile, cfg2.Name or "Keybind")

            local keyBtn = New("TextButton", { -- keycap chip bottom-right
                AnchorPoint = Vector2.new(1, 1),
                Position = UDim2.new(1, -10, 1, -10),
                Size = UDim2.new(0, 88, 0, 22),
                BackgroundColor3 = Theme.Background,
                Font = Enum.Font.GothamBold,
                Text = KeyName(key),
                TextColor3 = Theme.Muted,
                TextSize = 11,
                AutoButtonColor = false,
                Parent = tile,
            })
            Round(keyBtn, 6)
            local keyStroke = Stroke(keyBtn)

            local obj = {}
            function obj:Set(newKey)
                key = newKey
                keyBtn.Text = KeyName(key)
            end
            function obj:Get() return key end

            keyBtn.MouseButton1Click:Connect(function()
                listening = true
                keyBtn.Text = "press key…"
                keyBtn.TextColor3 = Theme.Accent
                Tween(keyStroke, { Color = Theme.Accent })
            end)

            UserInputService.InputBegan:Connect(function(input, gameProcessed)
                if listening and input.UserInputType == Enum.UserInputType.Keyboard then
                    listening = false
                    keyBtn.TextColor3 = Theme.Muted
                    Tween(keyStroke, { Color = Theme.Stroke })
                    if input.KeyCode == Enum.KeyCode.Escape then
                        obj:Set(nil) -- Escape clears the bind
                    else
                        obj:Set(input.KeyCode)
                    end
                    return
                end
                if not gameProcessed and key and input.KeyCode == key then
                    if cfg2.Callback then task.spawn(cfg2.Callback, key) end
                end
            end)

            if cfg2.Flag then Ember.Flags[cfg2.Flag] = obj end
            return obj
        end

        return Tab
    end

    function Window:Destroy()
        ClosePopup()
        RootGui:Destroy()
    end

    table.insert(Ember.Windows, Window)
    return Window
end

function Ember:Destroy()
    ClosePopup()
    RootGui:Destroy()
end

return Ember
]==]
do
	local g = getgenv and getgenv() or _G
	local prevCHX, prevCX = g.__CHX, g.Chronix
	if type(prevCHX) == "table" and prevCHX.bundled then prevCHX = prevCHX.prev end
	if type(prevCX) == "table" and prevCX.bundled then prevCX = prevCX.prev end
	local cache = {}
	local chx = {
		sid = (type(prevCHX) == "table" and prevCHX.sid) or "bundle",
		slug = (type(prevCHX) == "table" and prevCHX.slug) or "bundle",
		bundled = true,
		prev = prevCHX,
	}
	chx.fetch = function(sid, name)
		local s = __CHRONIX_BUNDLE[name]
		if s then return s end
		if type(prevCHX) == "table" and type(prevCHX.fetch) == "function" then return prevCHX.fetch(sid, name) end
		return nil, "not bundled: " .. tostring(name)
	end
	setmetatable(chx, { __index = function(_, k) if type(prevCHX) == "table" then return prevCHX[k] end end })
	g.__CHX = chx
	local cx = { bundled = true, prev = prevCX }
	cx.require = function(name)
		if cache[name] ~= nil then return cache[name] end
		local s = __CHRONIX_BUNDLE[name]
		if not s then
			if type(prevCX) == "table" and type(prevCX.require) == "function" then return prevCX.require(name) end
			error("[bundle] module '" .. tostring(name) .. "' is not bundled", 2)
		end
		local fn, err = loadstring(s, "=bundle:" .. tostring(name))
		if not fn then error("[bundle] module '" .. tostring(name) .. "' failed to compile: " .. tostring(err), 2) end
		local ok, res = pcall(fn)
		if not ok then error("[bundle] module '" .. tostring(name) .. "' errored: " .. tostring(res), 2) end
		if res == nil then res = true end
		cache[name] = res
		return res
	end
	setmetatable(cx, { __index = function(_, k) if type(prevCX) == "table" then return prevCX[k] end end })
	g.Chronix = cx
end
if getgenv().Pyrite then
	pcall(function() getgenv().Pyrite.Unload() end)
end

local missing = {}
if type(getgenv) ~= "function" then table.insert(missing, "getgenv") end
if type(loadstring) ~= "function" then table.insert(missing, "loadstring") end
if not pcall(function() return game.HttpGet end) then table.insert(missing, "game:HttpGet") end
if #missing > 0 then
	local ex = "unknown executor"
	pcall(function() ex = identifyexecutor() end)
	warn("[Pyrite] " .. tostring(ex) .. " is missing: " .. table.concat(missing, ", ") .. " - cannot run")
	return
end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local PathfindingService = game:GetService("PathfindingService")
local LP = Players.LocalPlayer

local okE, Egg = pcall(function() return require(RS.Client.EggState) end)
local okA, AssetsMod = pcall(function() return require(RS.Data.Assets) end)
local NoRequire = false
if not okE or type(Egg) ~= "table" then
	local Net = RS:FindFirstChild("Packages") and RS.Packages:FindFirstChild("Networking")
	local function rf(name) return Net and Net:FindFirstChild(name) end
	if not rf("RF/EggWorld/AskFieldEggSnapshot") then
		warn("[Pyrite] game modules and remotes not found - wrong game or update, aborting")
		return
	end
	NoRequire = true
	local snap, snapAt = nil, -99
	local function inv(name, ...)
		local r = rf(name)
		if not r then return false, "missing remote" end
		local args = { ... }
		local ok, a, b, c = pcall(function() return r:InvokeServer(table.unpack(args)) end)
		if not ok then return false, tostring(a) end
		return a, b, c
	end
	local dummySignal = { Connect = function() return { Disconnect = function() end } end }
	Egg = {
		ReadFieldEggs = function()
			if snap and os.clock() - snapAt < 1 then return snap end
			local res = inv("RF/EggWorld/AskFieldEggSnapshot")
			if type(res) == "table" then snap = res snapAt = os.clock() end
			return snap or { Records = {} }
		end,
		ReadFieldEgg = function(uid)
			local s0 = Egg.ReadFieldEggs()
			local recs = type(s0) == "table" and (s0.Records or s0) or {}
			return recs[uid]
		end,
		ReadOwnerEggs = function() return nil end,
		CarryFieldEgg = function(uid, key) return inv("RF/EggWorld/AskFieldEggCarry", { Uid = uid, FirstAreaSlotKey = key }) end,
		DropFieldEgg = function(reason) return inv("RF/EggWorld/AskFieldEggDrop", { Reason = reason or "PlayerRequest" }) end,
		PlantEgg = function(uid, lc) return inv("RF/EggWorld/AskPlaceEgg", { Uid = uid, LocalCFrame = lc }) end,
		BeginHatch = function(uid) return inv("RF/EggWorld/AskHatch", uid) end,
		FinishHatch = function(uid) return inv("RF/EggWorld/AskFinishHatch", uid) end,
		WearEggTool = function(uid) return inv("RF/EggWorld/AskWearTool", uid) end,
		IsReadyToHatch = function() return false end,
		CarryChanged = dummySignal,
	}
	for _, n in ipairs({ "FieldRefreshed", "FieldGone", "FieldShifted", "FieldClaimed", "SnapshotRefreshed" }) do Egg[n] = dummySignal end
end
if not okA or type(AssetsMod) ~= "table" or type(AssetsMod.Directory) ~= "table" then
	NoRequire = true
	AssetsMod = { Directory = {} }
end
local AssetsDir = AssetsMod.Directory
local SlotIdentity
pcall(function() SlotIdentity = require(RS.Shared.Util.AreaEggSlotIdentity) end)
local PlotState
pcall(function() PlotState = require(RS.Client.PlotState) end)
local SaveMod, BasesMod, TreadMod, CycleMod
pcall(function() SaveMod = require(RS.Shared.Save) end)
pcall(function() BasesMod = require(RS.Data.Bases) end)
pcall(function() TreadMod = require(RS.Data.Treadmills) end)
pcall(function() CycleMod = require(RS.Shared.Util.AreaEggCycle) end)
local GuardsMod
pcall(function() GuardsMod = require(RS.Data.Guards) end)
local Remotes
pcall(function() Remotes = require(RS.Shared.Remotes) end)
local AssetRoster
pcall(function() AssetRoster = require(RS.Client.AssetRoster) end)

local Ember = (function()
	local C = getgenv().Chronix
	if type(C) == "table" and type(C.require) == "function" then
		local o, r = pcall(C.require, "lib_ember")
		if o and r then return r end
	end
	return loadstring((getgenv().__CHX.fetch(getgenv().__CHX.sid,"lib_ember")))()
end)()

local P = { Running = true, Conns = {}, Bills = {}, Enabled = false, MaxDist = 300, Dirty = false, Unloaded = false, FarmMinRarity = 0, FarmSkipParasite = true, FarmTreadmill = true, FastMove = true, PlaceBatch = 1, GlideSpeed = 80, AutoSpeed = true, SpeedFactor = 1.6, Banked = 0, Debug = false, DbgLog = {}, DbgLabels = {}, AutoSellRarity = 0, AutoCodex = false, AutoAway = false, AutoClearInv = false, ClearRarity = 3, AutoCull = false, KeepSpare = 3, NeedSell = false, OnlyUpgrades = false, BestFirst = false, GrabRange = 1200, GrabReach = 8.5, GrabWatch = 15, AutoBaseUp = false, AutoTreadUp = false, UpgradeReserve = 0, AutoFavEquipped = false, AutoHopMins = 0, GuardAvoid = true, GuardMargin = 1.25, GuardESP = false, AntiAfk = false, StepGen = 0, ShowCycle = false, SecretOnly = false, EspSecretOnly = false, SecretAlert = false, SecretHop = false, SecretWebhook = false, WebhookUrl = "", AutoTrailBuy = false, AutoTrailEquip = false, AutoMastery = false, TrailEquipped = nil, AutoScramble = false, ScrambleDrops = {}, ScrambleTried = {}, MasteryEnded = false }
getgenv().Pyrite = P
P.NoRequire = NoRequire
P.iso = function(fn, ...)
	local args = { ... }
	local out, done = nil, false
	task.spawn(function()
		out = table.pack(pcall(fn, table.unpack(args)))
		done = true
	end)
	local t0 = os.clock()
	while not done and os.clock() - t0 < 10 do task.wait() end
	if not out then return false end
	return table.unpack(out, 1, out.n)
end
P.LabelQ = {}
P.setLabel = function(lbl, txt)
	if lbl then P.LabelQ[lbl] = txt end
end
task.spawn(function()
	local shown = {}
	while P.Running do
		for lbl, txt in pairs(P.LabelQ) do
			if shown[lbl] ~= txt then
				shown[lbl] = txt
				pcall(function() lbl:Set(txt) end)
			end
		end
		task.wait(2)
	end
end)

local function notify(title, content)
	pcall(function() Ember:Notify({ Title = tostring(title), Content = tostring(content), Duration = 4 }) end)
end

local function conn(c)
	table.insert(P.Conns, c)
	return c
end

local DbgShown = {}
local function dbg(msg)
	msg = tostring(msg)
	local line = ("[%0.1f] %s"):format(os.clock() % 10000, msg)
	local L = P.DbgLog
	L[#L + 1] = line
	while #L > 200 do table.remove(L, 1) end
	P.DbgDirty = true
	if P.Debug then print("[Pyrite] " .. msg) end
end

task.spawn(function()
	while P.Running do
		if P.Debug and P.DbgDirty then
			P.DbgDirty = false
			local labels, L = P.DbgLabels, P.DbgLog
			local n = #labels
			for i = 1, n do
				local idx = #L - n + i
				local txt = idx >= 1 and L[idx] or ""
				if DbgShown[i] ~= txt then
					DbgShown[i] = txt
					P.setLabel(labels[i], txt)
				end
			end
		end
		task.wait(2)
	end
end)

local function getParent()
	local ok, ui = pcall(function() return gethui() end)
	if ok and typeof(ui) == "Instance" then return ui end
	local ok2, cg = pcall(function() return game:GetService("CoreGui") end)
	if ok2 and cg then return cg end
	return LP:WaitForChild("PlayerGui")
end

local function fmtMoney(n)
	n = tonumber(n) or 0
	if n >= 1e12 then return string.format("$%.1fT/s", n / 1e12) end
	if n >= 1e9 then return string.format("$%.1fB/s", n / 1e9) end
	if n >= 1e6 then return string.format("$%.1fM/s", n / 1e6) end
	if n >= 1e3 then return string.format("$%.1fK/s", n / 1e3) end
	return string.format("$%d/s", n)
end

local Rarities = {}
local RarityNumByName = {}
do
	local seen = {}
	for cat, a in pairs(AssetsDir) do
		if type(a) == "table" and type(a.Rarity) == "table" and a.Rarity.DisplayName then
			local nm = tostring(a.Rarity.DisplayName)
			local rn = tonumber(a.Rarity.RarityNumber) or 0
			if not seen[nm] then
				seen[nm] = true
				table.insert(Rarities, { name = nm, num = rn })
				RarityNumByName[nm] = rn
			end
		end
	end
	table.sort(Rarities, function(x, y) return x.num < y.num end)
end

local function catRarity(cat)
	local a = AssetsDir[cat]
	local r = type(a) == "table" and a.Rarity
	local num = (type(r) == "table" and tonumber(r.RarityNumber)) or 0
	local nm = (type(r) == "table" and tostring(r.DisplayName)) or "?"
	return num, nm
end

local SecretNames = { Secret = true, Eternal = true }
local SecretMinNum = math.huge
local SecretLabel = "Secret"
for _, r in ipairs(Rarities) do
	if SecretNames[r.name] and r.num < SecretMinNum then SecretMinNum = r.num SecretLabel = r.name end
end
if SecretMinNum == math.huge then
	local top = nil
	for _, r in ipairs(Rarities) do
		if not top or r.num > top.num then top = r end
	end
	if top then SecretMinNum = top.num SecretLabel = top.name end
end

local function isSecretCat(cat)
	local num, nm = catRarity(cat)
	if SecretNames[nm] then return true end
	return SecretMinNum < math.huge and num >= SecretMinNum
end

local function rarityAllows(cat)
	if P.SecretOnly then return isSecretCat(cat) end
	local num = catRarity(cat)
	return num >= (tonumber(P.FarmMinRarity) or 0)
end

local function eggInfo(rec)
	local cat = rec.AssetCategory
	local a = AssetsDir[cat]
	local name = cat
	local rate = 0
	local color = Color3.fromRGB(200, 200, 200)
	local rar = ""
	if a then
		name = a.DisplayName or cat
		rate = a.EarningRate or 0
		if a.Rarity then
			rar = a.Rarity.DisplayName or ""
			if typeof(a.Rarity.Color) == "Color3" then color = a.Rarity.Color end
		end
	end
	local mut = ""
	if type(rec.Mutations) == "table" and next(rec.Mutations) then
		local m = {}
		for k, v in pairs(rec.Mutations) do
			table.insert(m, type(v) == "string" and v or tostring(k))
		end
		mut = " [" .. table.concat(m, ",") .. "]"
	end
	if rec.HasParasite == true then
		mut = mut .. " [PARASITE]"
	end
	return name, rar, rate, color, mut
end

local AE = workspace:WaitForChild("AreaEggSlotsClient", 10)
if not AE then
	warn("[Pyrite] AreaEggSlotsClient missing - game update, aborting")
	return
end

local function fieldRecords()
	local ok, snap = pcall(Egg.ReadFieldEggs)
	if not ok or type(snap) ~= "table" then return nil, tostring(snap) end
	return snap.Records or snap
end

local function ownRecords()
	local ok, recs = pcall(Egg.ReadOwnerEggs, LP.UserId)
	if not ok or type(recs) ~= "table" then return nil end
	return recs
end

local AssetEarnings
pcall(function() AssetEarnings = require(RS.Shared.Util.AssetEarnings) end)
local function rateOf(rec)
	if type(rec) ~= "table" then return 0 end
	local cat = rec.AssetCategory or rec.Category
	local a = AssetsDir[cat]
	local base = (a and tonumber(a.EarningRate)) or 0
	local scale = tonumber(rec.AssetScale or rec.Scale) or 1
	if scale <= 0 then scale = 1 end
	if AssetEarnings and type(AssetEarnings.RatePerSecond) == "function" then
		local muts = {}
		if type(rec.Mutations) == "table" then
			for k, m in pairs(rec.Mutations) do
				if type(m) == "string" then table.insert(muts, m) elseif m == true and type(k) == "string" then table.insert(muts, k) end
			end
		end
		local ok, v = pcall(AssetEarnings.RatePerSecond, { Category = cat, Mutations = muts, BaseMutation = rec.BaseMutation, Scale = scale })
		if ok and tonumber(v) then return tonumber(v) end
	end
	local factor = scale > 5 and ((scale / 5) ^ 1.2 * 19.637875755794113) or (scale ^ 1.85)
	return base * factor
end

local UpgLabel, GuardLabel
local upgradeFloorCache = { at = 0, floor = 0, placed = 0, cap = 0 }
local function saveData()
	if not SaveMod then return nil end
	local ok, d = pcall(SaveMod.Peek or SaveMod.Get)
	if ok and type(d) == "table" then return d end
	return nil
end
local function baseCap(level)
	local t = BasesMod and BasesMod.BASES
	local row = t and t[tonumber(level) or 0]
	return row and tonumber(row.MaxAssets) or 0
end
local function baseFloor()
	local now = os.clock()
	if now - upgradeFloorCache.at < 2 then return upgradeFloorCache.floor, upgradeFloorCache.placed, upgradeFloorCache.cap end
	local d = saveData()
	local floor, placed, cap = nil, 0, 0
	if d then
		cap = baseCap(d.BaseUpgradeLevel)
		local inv = type(d.Inventory) == "table" and d.Inventory or {}
		for _, uid in pairs(type(d.EquippedAssets) == "table" and d.EquippedAssets or {}) do
			local rec = type(uid) == "table" and uid or inv[uid]
			if type(rec) == "table" then
				placed += 1
				local v = rateOf(rec)
				if not floor or v < floor then floor = v end
			end
		end
	end
	upgradeFloorCache.at = now
	upgradeFloorCache.floor = floor or 0
	upgradeFloorCache.placed = placed
	upgradeFloorCache.cap = cap
	return upgradeFloorCache.floor, placed, cap
end

local function isUpgrade(rec)
	if not P.OnlyUpgrades then return true end
	local floor, placed, cap = baseFloor()
	if placed < cap then return true end
	return rateOf(rec) > floor
end

local function fmtRate(n)
	n = tonumber(n) or 0
	if n >= 1e9 then return string.format("%.1fB", n / 1e9) end
	if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
	if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
	return tostring(math.floor(n))
end
P.baseFloor = baseFloor

local GuardCat = { at = 0, list = {} }
local function parseSpeedText(t)
	t = tostring(t or ""):gsub(",", "")
	local num, suf = t:match("([%d%.]+)%s*([KkMmBbTt]?)")
	num = tonumber(num)
	if not num then return nil end
	local mult = ({ k = 1e3, m = 1e6, b = 1e9, t = 1e12 })[suf:lower()] or 1
	return num * mult
end
local function guardAreas()
	local now = os.clock()
	if now - GuardCat.at < 5 and #GuardCat.list > 0 then return GuardCat.list end
	local list = {}
	pcall(function()
		local ga = workspace:FindFirstChild("World") or workspace:FindFirstChild("__OBJECTS")
		ga = ga and ga:FindFirstChild("Areas")
		ga = ga and ga:FindFirstChild("GuardAreas")
		if not ga then return end
		local dir = GuardsMod and type(GuardsMod.Directory) == "table" and GuardsMod.Directory or {}
		for _, area in ipairs(ga:GetChildren()) do
			local g = area:FindFirstChild("Guard")
			local gp = g and (g.PrimaryPart or g:FindFirstChildWhichIsA("BasePart"))
			local b = area:FindFirstChild("Bounds")
			if gp and b then
				local req
				local sign = area:FindFirstChild("RequiredSpeedSign")
				if sign then
					for _, d in ipairs(sign:GetDescendants()) do
						if d:IsA("TextLabel") then
							local v = parseSpeedText(d.Text)
							if v and (not req or v > req) then req = v end
						end
					end
				end
				local cfg = type(dir[area.Name]) == "table" and dir[area.Name] or {}
				list[#list + 1] = { name = area.Name, model = g, part = gp, hum = g:FindFirstChildWhichIsA("Humanoid"), bounds = b, req = req or 0, radius = tonumber(cfg.FlatRadius) or 20, hit = tonumber(cfg.HitDistance) or 5 }
			end
		end
		table.sort(list, function(x, y) return x.req < y.req end)
	end)
	GuardCat.at = now
	GuardCat.list = list
	return list
end
P.guardAreas = guardAreas
local function inBounds(b, pos)
	local c, sz = b.Position, b.Size
	return math.abs(pos.X - c.X) <= sz.X / 2 + 2 and math.abs(pos.Z - c.Z) <= sz.Z / 2 + 2
end
local function guardAreaAt(pos)
	for _, a in ipairs(guardAreas()) do
		if inBounds(a.bounds, pos) then return a end
	end
	return nil
end
local function mySpeedPower()
	local d = saveData()
	return d and tonumber(d.SpeedPower) or 0
end
local function canOutrunArea(a)
	if a.req <= 20 then return true end
	return mySpeedPower() >= a.req * (tonumber(P.GuardMargin) or 1.25)
end
local function guardAsleep(a)
	if not a or not a.model then return true end
	if a.model:GetAttribute("Sleeping") == true then return true end
	local st = a.model:GetAttribute("GuardState")
	if st == nil then return true end
	return tostring(st) == "Sleeping"
end
P.guardAsleep = guardAsleep

local function nestGuardOk(rec)
	if not P.GuardAvoid then return true end
	local pos = rec.BottomCFrame.Position
	local a = guardAreaAt(pos)
	if not a then return true end
	if not canOutrunArea(a) then return false end
	if guardAsleep(a) then return true end
	if a.hum and a.hum.WalkSpeed > 0 then
		local ch = LP.Character
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		local myWs = hum and hum.WalkSpeed or 16
		local d = ((a.part.Position - pos) * Vector3.new(1, 0, 1)).Magnitude
		if d < a.radius + 15 and a.hum.WalkSpeed * 1.2 > myWs then return false end
	end
	return true
end
local function guardSummary()
	local sp = mySpeedPower()
	local safe, unsafe = {}, {}
	for _, a in ipairs(guardAreas()) do
		if canOutrunArea(a) then safe[#safe + 1] = a.name else unsafe[#unsafe + 1] = a.name .. " (" .. fmtRate(a.req) .. ")" end
	end
	return ("speed power %s | can outrun: %s | too slow for: %s"):format(fmtRate(sp), #safe > 0 and table.concat(safe, ", ") or "none", #unsafe > 0 and table.concat(unsafe, ", ") or "none")
end
P.rateOf = rateOf

local RadarFolder
local function radarPart(uid, pos)
	if not RadarFolder or not RadarFolder.Parent then
		RadarFolder = Instance.new("Folder")
		RadarFolder.Name = "Effects" .. tostring(math.random(1000, 9999))
		RadarFolder.Parent = workspace.CurrentCamera or workspace
	end
	local p = RadarFolder:FindFirstChild(uid)
	if not p then
		p = Instance.new("Part")
		p.Name = uid
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.new(1, 1, 1)
		p.Parent = RadarFolder
	end
	p.CFrame = CFrame.new(pos)
	return p
end

local function killBill(uid)
	local b = P.Bills[uid]
	if b then
		P.Bills[uid] = nil
		pcall(function() b:Destroy() end)
	end
	if RadarFolder then
		local rp = RadarFolder:FindFirstChild(uid)
		if rp then pcall(function() rp:Destroy() end) end
	end
end

local function clearAll()
	for uid in pairs(P.Bills) do killBill(uid) end
	if RadarFolder then pcall(function() RadarFolder:ClearAllChildren() end) end
end

local function build(rec)
	if type(rec) ~= "table" or not rec.Uid then return end
	if P.EspSecretOnly and not isSecretCat(rec.AssetCategory) then killBill(rec.Uid) return end
	local model = AE:FindFirstChild(rec.Uid)
	local part = model and (model:FindFirstChild("Hitbox") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true))
	if not part and P.Radar and typeof(rec.BottomCFrame) == "CFrame" then
		part = radarPart(rec.Uid, rec.BottomCFrame.Position + Vector3.new(0, 2, 0))
	end
	if not part then killBill(rec.Uid) return end
	killBill(rec.Uid)
	local name, rar, rate, color, mut = eggInfo(rec)
	local bb = Instance.new("BillboardGui")
	bb.Name = rec.Uid
	bb.Adornee = part
	bb.Size = UDim2.new(0, 160, 0, 34)
	bb.StudsOffset = Vector3.new(0, 2.4, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = P.MaxDist
	local t1 = Instance.new("TextLabel")
	t1.Size = UDim2.new(1, 0, 0, 16)
	t1.BackgroundTransparency = 1
	t1.Font = Enum.Font.GothamBold
	t1.TextSize = 13
	t1.TextColor3 = color
	t1.TextStrokeTransparency = 0.2
	t1.Text = name .. (rar ~= "" and (" [" .. rar .. "]") or "") .. mut
	t1.Parent = bb
	local t2 = Instance.new("TextLabel")
	t2.Position = UDim2.new(0, 0, 0, 16)
	t2.Size = UDim2.new(1, 0, 0, 14)
	t2.BackgroundTransparency = 1
	t2.Font = Enum.Font.Gotham
	t2.TextSize = 12
	t2.TextColor3 = Color3.fromRGB(120, 255, 140)
	t2.TextStrokeTransparency = 0.3
	t2.Text = fmtMoney(rate)
	t2.Parent = bb
	bb.Parent = part
	P.Bills[rec.Uid] = bb
	P.Built = (P.Built or 0) + 1
end

local function doRebuild()
	clearAll()
	if not P.Enabled then return end
	local recs, err = fieldRecords()
	if not recs then
		P.LastErr = "snapshot: " .. tostring(err)
		return
	end
	for _, rec in pairs(recs) do
		if type(rec) == "table" then
			local okB, errB = pcall(build, rec)
			if not okB then P.LastErr = tostring(errB) end
		end
	end
end

task.spawn(function()
	local lastFull = 0
	while P.Running do
		if P.Enabled and os.clock() - lastFull >= 5 then
			lastFull = os.clock()
			P.Dirty = true
		end
		if P.Enabled and P.Dirty then
			P.Dirty = false
			pcall(doRebuild)
		elseif not P.Enabled and next(P.Bills) then
			pcall(clearAll)
		end
		task.wait(0.1)
	end
end)

local function markDirty()
	P.Dirty = true
end

local function parseCarry(a)
	if type(a) == "table" then
		if a.IsCarrying ~= nil then return a.IsCarrying == true end
		if a.Uid ~= nil then return true end
		return next(a) ~= nil
	end
	if type(a) == "boolean" then return a end
	if type(a) == "string" then return true end
	return a ~= nil
end

local okCC = pcall(function()
	conn(Egg.CarryChanged:Connect(function(a)
		P.Carrying = parseCarry(a)
	end))
end)
if not okCC then warn("[Pyrite] CarryChanged signal missing") end

local function carryStale()
	if P.Carrying and os.clock() - (P.CarryAt or 0) > 90 then
		dbg("carry flag looked stale, clearing")
		P.Carrying = false
	end
end

local function eggIsOthers(uid)
	if SlotIdentity then
		local okO, owner = pcall(SlotIdentity.FirstAreaOwnerUserId, uid)
		if okO and owner ~= nil then return tostring(owner) ~= tostring(LP.UserId) end
		local okF, isFirst = pcall(SlotIdentity.LooksLikeFirstAreaUid, uid)
		if okF and isFirst == false then return false end
	end
	local owner = tostring(uid):match("^FirstAreaEgg_(%d+)_")
	return owner ~= nil and owner ~= tostring(LP.UserId)
end

local function slotKeyFor(r)
	if not SlotIdentity then return nil end
	local okF, isFirst = pcall(SlotIdentity.LooksLikeFirstAreaUid, r.Uid)
	if okF and isFirst == true then
		local okK, sk = pcall(SlotIdentity.SlotKey, r.AreaId, r.NestId)
		if okK then return sk end
	end
	return nil
end

local grabCooldown = {}
local function tryGrab()
	if P.Farm then return end
	local char = LP.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	carryStale()
	if P.Carrying then return end
	local recs = fieldRecords()
	if not recs then return end
	local now = os.clock()
	local watch = tonumber(P.GrabWatch) or 15
	local reach = tonumber(P.GrabReach) or 8.5
	local best, bd, nearest
	local cands = {}
	for _, r in pairs(recs) do
		if type(r) == "table" and r.Uid and typeof(r.BottomCFrame) == "CFrame" then
			local st = tostring(r.State)
			if st == "Slot" or st == "Dropped" then
				local d0 = (r.BottomCFrame.Position - hrp.Position).Magnitude
				if d0 <= watch + 6 and not eggIsOthers(r.Uid) and isUpgrade(r) and rarityAllows(r.AssetCategory) then
					cands[#cands + 1] = { r = r, d = d0 }
				end
			end
		end
	end
	table.sort(cands, function(x, y) return x.d < y.d end)
	for i = 1, math.min(3, #cands) do
		local r = cands[i].r
		local m = AE:FindFirstChild(r.Uid)
		local part = m and (m:FindFirstChild("Hitbox") or m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true))
		if part then
			local d = (part.Position - hrp.Position).Magnitude
			if d <= watch and (not nearest or d < nearest) then nearest = d end
			if d <= reach and (grabCooldown[r.Uid] or 0) < now and (not bd or d < bd) then bd = d best = r end
		end
	end
	P.GrabNear = nearest
	if not best then return end
	local okC, res, err = pcall(Egg.CarryFieldEgg, best.Uid, slotKeyFor(best))
	if okC and res == true then
		P.Carrying = true
		P.CarryAt = os.clock()
		P.GrabCount = (P.GrabCount or 0) + 1
		grabCooldown[best.Uid] = nil
		dbg(("instant grab %s at %.1f st (#%d)"):format(tostring(best.AssetCategory), bd or 0, P.GrabCount))
		return
	end
	local e = tostring(err or res or ""):lower()
	P.LastGrabErr = err or res
	if e:find("closer") or e:find("range") or e:find("not found") then
		grabCooldown[best.Uid] = now + 0.3
	else
		grabCooldown[best.Uid] = now + 3
		dbg("instant grab refused: " .. tostring(err or res))
	end
end

task.spawn(function()
	while P.Running do
		if P.Grab then pcall(tryGrab) end
		task.wait((P.Grab and P.GrabNear) and 0.06 or 0.25)
	end
end)

local function httpRequest()
	if syn and type(syn.request) == "function" then return syn.request end
	if type(http_request) == "function" then return http_request end
	if fluxus and type(fluxus.request) == "function" then return fluxus.request end
	if type(request) == "function" then return request end
	return nil
end

local function sendWebhook(name, rar, rate)
	local url = tostring(P.WebhookUrl or "")
	if not P.SecretWebhook or url == "" or not url:find("^https?://") then return end
	local req = httpRequest()
	if not req then
		P.SecretWebhook = false
		local ex = "your executor"
		pcall(function() ex = identifyexecutor() end)
		notify("Webhook", tostring(ex) .. " has no http request function - webhook alerts disabled")
		return
	end
	local body = {
		username = "Pyrite",
		embeds = { {
			title = "Secret egg spotted",
			description = ("**%s** [%s]\n%s\nserver: `%s`"):format(tostring(name), tostring(rar), fmtMoney(tonumber(rate) or 0), tostring(game.JobId)),
			color = 16766720,
		} },
	}
	task.spawn(function()
		pcall(function()
			req({ Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = game:GetService("HttpService"):JSONEncode(body) })
		end)
	end)
end

local SecretSeen = {}
P.SecretCount = 0
task.spawn(function()
	while P.Running do
		if P.SecretAlert or P.SecretHop then
			local recs = fieldRecords()
			if recs then
				local found = false
				for _, r in pairs(recs) do
					if type(r) == "table" and r.Uid and not SecretSeen[r.Uid] then
						local st = tostring(r.State)
						if (st == "Slot" or st == "Dropped") and isSecretCat(r.AssetCategory) then
							SecretSeen[r.Uid] = true
							found = true
							P.SecretCount = (P.SecretCount or 0) + 1
							local nm, rar, rate = eggInfo(r)
							if P.SecretAlert then
								notify("Secret Egg", tostring(nm) .. " [" .. tostring(rar) .. "] is in the field")
							end
							pcall(sendWebhook, nm, rar, rate)
							dbg("secret spotted: " .. tostring(nm))
						end
					end
				end
				if P.SecretHop and not found then
					local n = 0
					for _, r in pairs(recs) do
						if type(r) == "table" and r.Uid and SecretSeen[r.Uid] then
							local st = tostring(r.State)
							if st == "Slot" or st == "Dropped" then n = n + 1 end
						end
					end
					if n == 0 then
						P.SecretHopAt = (P.SecretHopAt or os.clock())
						if os.clock() - P.SecretHopAt > 90 and P.serverHop and not P.Carrying then
							P.SecretHopAt = os.clock()
							notify("Secret Hunt", "no secret eggs here - hopping")
							task.spawn(function() pcall(P.serverHop) end)
						end
					else
						P.SecretHopAt = os.clock()
					end
				elseif found then
					P.SecretHopAt = os.clock()
				end
			end
		else
			P.SecretHopAt = nil
		end
		task.wait(3)
	end
end)

local function homePlot()
	if not PlotState then return nil end
	local okS, slot = pcall(PlotState.ResolveLocalSlot)
	if not okS or slot == nil then return nil end
	local plots = workspace:FindFirstChild("Plots")
	return plots and plots:FindFirstChild(tostring(slot))
end

local function localPlotData()
	if not PlotState then return nil end
	local okP, pd = pcall(PlotState.ResolvePlot, LP)
	if okP and type(pd) == "table" then return pd end
	return nil
end

local placeCooldown = {}
local function tryPlace()
	if not PlotState then return end
	local char = LP.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local okIn, inside = pcall(PlotState.ContainsLocalPoint, hrp.Position)
	if not okIn or inside ~= true then return end
	local recs = ownRecords()
	if not recs then return end
	local now = os.clock()
	local target, tkey
	local taken = {}
	local V = P.V14
	for uid, r in pairs(recs) do
		if type(r) == "table" then
			if r.Placement == nil and (placeCooldown[uid] or 0) < now then
				if not V or V.placeAllowed(r) then
					local k = V and V.placeKey(r) or 0
					if not target or k > tkey then target, tkey = uid, k end
				end
			elseif type(r.Placement) == "table" and typeof(r.Placement.LocalCFrame) == "CFrame" then
				table.insert(taken, r.Placement.LocalCFrame.Position)
			end
		end
	end
	if not target then return end
	local pd = localPlotData()
	if not pd or not pd.PetArea or not pd.CenterPoint then return end
	local pa = pd.PetArea
	local cp = pd.CenterPoint
	local y = pa.Position.Y + pa.Size.Y / 2
	placeCooldown[target] = now + 3
	local spots = {}
	local tries = 0
	local hx = pa.Size.X / 2 - 1.5
	local hz = pa.Size.Z / 2 - 1.5
	local nx = math.max(1, math.floor(hx / 1.4))
	local nz = math.max(1, math.floor(hz / 1.4))
	for dx = -nx, nx do
		for dz = -nz, nz do
			local wp = Vector3.new(pa.Position.X + dx * (hx / nx), y, pa.Position.Z + dz * (hz / nz))
			table.insert(spots, wp)
		end
	end
	table.sort(spots, function(a, b)
		return (a - hrp.Position).Magnitude < (b - hrp.Position).Magnitude
	end)
	for _, wp in ipairs(spots) do
		local lc = cp.CFrame:ToObjectSpace(CFrame.new(wp))
		local clear = true
		for _, p in ipairs(taken) do
			if (p - lc.Position).Magnitude < 2.6 then clear = false break end
		end
		if clear then
			tries = tries + 1
			local okP, res, err = pcall(Egg.PlantEgg, target, lc)
			if okP and res == true then return end
			if tries >= 6 then return end
			if type(err) == "string" and not err:lower():find("occup") and not err:lower():find("spot") and not err:lower():find("position") then return end
		end
	end
end

task.spawn(function()
	while P.Running do
		if P.Place and (not P.V14 or P.V14.placeRuleOk()) then pcall(tryPlace) end
		task.wait(0.8)
	end
end)

local hatchCooldown = {}
local function tryHatch()
	local recs = ownRecords()
	if not recs then return end
	local now = os.clock()
	for uid, rec in pairs(recs) do
		if type(uid) == "string" and (hatchCooldown[uid] or 0) < now and (not P.V14 or P.V14.hatchAllowed(rec)) then
			local okR, ready = pcall(Egg.IsReadyToHatch, uid)
			if okR and ready == true then
				hatchCooldown[uid] = now + 6
				local okH, res = pcall(Egg.BeginHatch, uid)
				if okH and res == true then
					task.wait(0.3)
					pcall(Egg.FinishHatch, uid)
				end
			end
		end
	end
end

task.spawn(function()
	while P.Running do
		if P.Hatch then pcall(tryHatch) end
		task.wait(1.5)
	end
end)

local function equipBest()
	if not Remotes or type(Remotes.Haul) ~= "table" then return end
	local w = Remotes.Haul.WearBest
	if typeof(w) ~= "Instance" then return end
	if w:IsA("RemoteEvent") then
		w:FireServer()
	elseif w:IsA("RemoteFunction") then
		w:InvokeServer()
	end
end

task.spawn(function()
	while P.Running do
		if P.EquipBest then pcall(equipBest) end
		task.wait(20)
	end
end)

P.trailOwnedSet = function(d)
	local set = {}
	local inv = d and d.TrailInventory
	if type(inv) == "table" then
		for k, v in pairs(inv) do
			if type(k) == "string" and v then set[k] = true end
			if type(v) == "string" then set[v] = true end
			if type(v) == "table" and type(v._id or v.Id) == "string" then set[v._id or v.Id] = true end
		end
	end
	return set
end

P.trailBuyBest = function()
	local ok, TrailsMod = pcall(function() return require(RS.Data.Trails) end)
	if not ok or not TrailsMod or type(TrailsMod.Directory) ~= "table" then return end
	local d = saveData()
	if not d or not d.Money then return end
	local money = tonumber(d.Money) or 0
	local owned = P.trailOwnedSet(d)
	local best_owned_mult = 0
	for key, trail_data in pairs(TrailsMod.Directory) do
		if type(trail_data) == "table" and owned[trail_data._id or key] then
			best_owned_mult = math.max(best_owned_mult, tonumber(trail_data.SpeedMultiplier) or 0)
		end
	end
	local best_candidate = nil
	local best_mult = best_owned_mult
	for key, trail_data in pairs(TrailsMod.Directory) do
		if type(trail_data) == "table" then
			local id = trail_data._id or key
			local price = tonumber(trail_data.Price) or 0
			local mult = tonumber(trail_data.SpeedMultiplier) or 0
			if price > 0 and trail_data.DisplayInShop ~= false and mult > best_mult and not owned[id] and price <= money - (tonumber(P.UpgradeReserve) or 0) then
				best_candidate = id
				best_mult = mult
			end
		end
	end
	if best_candidate then
		pcall(function()
			if Remotes and type(Remotes.Trailwear) == "table" and Remotes.Trailwear.AskPurchase then
				Remotes.Trailwear.AskPurchase:InvokeServer(best_candidate)
			end
		end)
	end
end

P.trailEquipBest = function()
	local ok, TrailsMod = pcall(function() return require(RS.Data.Trails) end)
	if not ok or not TrailsMod or type(TrailsMod.Directory) ~= "table" then return end
	local d = saveData()
	if not d then return end
	local owned = P.trailOwnedSet(d)
	local best_id = nil
	local best_mult = 0
	for key, trail_data in pairs(TrailsMod.Directory) do
		if type(trail_data) == "table" then
			local id = trail_data._id or key
			local mult = tonumber(trail_data.SpeedMultiplier) or 0
			if owned[id] and mult > best_mult then
				best_id = id
				best_mult = mult
			end
		end
	end
	if best_id and best_id ~= P.TrailEquipped then
		pcall(function()
			if Remotes and type(Remotes.Trailwear) == "table" and Remotes.Trailwear.AskChoose then
				local ok_choose = Remotes.Trailwear.AskChoose:InvokeServer(best_id)
				if ok_choose then P.TrailEquipped = best_id end
			end
		end)
	end
end

P.claimBossMastery = function()
	if P.MasteryEnded then
		if os.clock() - (P.MasteryEndedAt or 0) < 1800 then return end
		P.MasteryEnded = false
	end
	local ok, BossMod = pcall(function() return require(RS.Data.BossMastery) end)
	if not ok or not BossMod or type(BossMod.Milestones) ~= "table" then return end
	local d = saveData()
	if not d then return end
	local claimed = type(d.BossMastery) == "table" and d.BossMastery.ClaimedMilestoneIds or {}
	for _, m in pairs(BossMod.Milestones) do
		if type(m) == "table" and m.Id and claimed[m.Id] ~= true then
			local kills = (type(BossMod.GetMilestoneKills) == "function" and select(2, pcall(BossMod.GetMilestoneKills, m))) or m.Kills
			local mastery = tonumber((type(d.BossMastery) == "table" and d.BossMastery.Mastery) or 0) or 0
			if tonumber(kills) and tonumber(kills) <= mastery then
				pcall(function()
					if Remotes and type(Remotes.BossMastery) == "table" and Remotes.BossMastery.AskClaimMilestone then
						local ok_claim, res_msg = Remotes.BossMastery.AskClaimMilestone:InvokeServer(m.Id)
						if ok_claim == false and type(res_msg) == "string" and res_msg:find("ended") then
							P.MasteryEnded = true
							P.MasteryEndedAt = os.clock()
						end
					end
				end)
				if P.MasteryEnded then return end
				task.wait(0.5)
			end
		end
	end
end

task.spawn(function()
	while P.Running do
		if P.AutoTrailBuy then
			pcall(P.trailBuyBest)
			task.wait(5)
		else
			task.wait(0.5)
		end
	end
end)

task.spawn(function()
	while P.Running do
		if P.AutoTrailEquip then
			pcall(P.trailEquipBest)
			task.wait(5)
		else
			task.wait(0.5)
		end
	end
end)

task.spawn(function()
	while P.Running do
		if P.AutoMastery then
			pcall(P.claimBossMastery)
			task.wait(30)
		else
			task.wait(0.5)
		end
	end
end)

local function fakeInput()
	if not P.AntiAfk then return end
	pcall(function()
		local char = LP.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 and not P.Farm then
			local dir = Vector3.new(math.random(-10, 10) / 100, 0, math.random(-10, 10) / 100)
			hum:Move(dir, false)
			task.delay(0.15, function() pcall(function() hum:Move(Vector3.zero, false) end) end)
		end
		local cam = workspace.CurrentCamera
		if cam then cam.CFrame = cam.CFrame * CFrame.Angles(0, math.rad(0.08), 0) end
	end)
	P.LastFakeInput = os.clock()
end
pcall(function() table.insert(P.Conns, LP.Idled:Connect(function() if P.AntiAfk then fakeInput() end end)) end)
task.spawn(function()
	while P.Running do
		if P.AntiAfk then fakeInput() end
		task.wait(30 + math.random() * 15)
	end
end)

local Walker = { Token = 0 }

local function stopWalk()
	Walker.Token = Walker.Token + 1
	local char = LP.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hum and hrp then pcall(function() hum:MoveTo(hrp.Position) end) end
end

local function walkTo(dest, opts)
	opts = opts or {}
	Walker.Token = Walker.Token + 1
	local token = Walker.Token
	local arrive = opts.arrive or 5
	local deadline = os.clock() + (opts.timeout or 90)
	local computeFails = 0
	while os.clock() < deadline do
		if Walker.Token ~= token or not P.Running then return false end
		if opts.stopWhen and opts.stopWhen() then return false end
		local char = LP.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hum or not hrp then task.wait(0.5) else
			local flat = ((dest - hrp.Position) * Vector3.new(1, 0, 1)).Magnitude
			if flat <= arrive then return true end
			local path = PathfindingService:CreatePath({ AgentRadius = 2.5, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 6 })
			local okC = pcall(function() path:ComputeAsync(hrp.Position, dest) end)
			if not okC or path.Status ~= Enum.PathStatus.Success then
				computeFails = computeFails + 1
				if computeFails >= 4 then return false end
				hum:MoveTo(dest)
				task.wait(0.7)
			else
				computeFails = 0
				local wps = path:GetWaypoints()
				for i = 2, #wps do
					if Walker.Token ~= token or not P.Running then return false end
					if opts.stopWhen and opts.stopWhen() then return false end
					if os.clock() > deadline then return false end
					local wp = wps[i]
					if wp.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
					hum:MoveTo(wp.Position)
					local done = false
					local c = hum.MoveToFinished:Once(function() done = true end)
					local t0 = os.clock()
					local p0 = hrp.Position
					while not done and os.clock() - t0 < 3 do
						if Walker.Token ~= token or not P.Running then c:Disconnect() return false end
						if (hrp.Position - p0).Magnitude > 1 then P.LastProgress = os.clock() end
						task.wait(0.05)
					end
					c:Disconnect()
					if not done then
						hum.Jump = true
						if (hrp.Position - p0).Magnitude < 1 then break end
					end
					local f2 = ((dest - hrp.Position) * Vector3.new(1, 0, 1)).Magnitude
					if f2 <= arrive then return true end
				end
			end
		end
	end
	return false
end

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local StepGen = 0
local function farmStop()
	return not P.Farm or StepGen ~= P.StepGen
end

local function curChar()
	local ch = LP.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	return ch, hrp, hum
end

local function farmSpeed()
	local _, _, hum = curChar()
	local ws = (hum and hum.WalkSpeed) or 16
	local budget = ws * 1.7
	local want
	if P.AutoSpeed then
		want = math.max(ws * (tonumber(P.SpeedFactor) or 1.6), 20)
		return math.min(want, budget, 150)
	end
	want = math.max(tonumber(P.GlideSpeed) or 60, 20)
	return math.min(want, math.max(budget, 100), 150)
end

local function geo()
	if P.Geo then return P.Geo end
	local root = workspace:FindFirstChild("World") or workspace:FindFirstChild("__OBJECTS")
	local areas = root and root:FindFirstChild("Areas")
	if not areas then return nil end
	local line = areas:FindFirstChild("SeparationLine")
	local gate = areas:FindFirstChild("GameplayZ")
	if not line or not gate then return nil end
	local half = gate.Size.Z / 2 - 6
	P.Geo = {
		lineX = line.Position.X,
		gateZlo = gate.Position.Z - half,
		gateZhi = gate.Position.Z + half,
		gateMid = gate.Position.Z,
	}
	dbg(("geo: lineX=%.1f gateZ=%.0f..%.0f"):format(P.Geo.lineX, P.Geo.gateZlo, P.Geo.gateZhi))
	return P.Geo
end

local GlideRay
local function groundY(pos)
	if not GlideRay then
		GlideRay = RaycastParams.new()
		GlideRay.FilterType = Enum.RaycastFilterType.Exclude
	end
	GlideRay.FilterDescendantsInstances = { LP.Character }
	local r = workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -60, 0), GlideRay)
	return r and r.Position.Y or nil
end

local GlideFlags = 0
local GlideBlockUntil = 0
local GlideCleanAt = 0
local function glideFlag(why)
	GlideFlags = GlideFlags + 1
	P.GlideFlags = GlideFlags
	local back = math.min(20 * GlideFlags, 120)
	GlideBlockUntil = os.clock() + back
	P.GlideBlockUntil = GlideBlockUntil
	dbg(("SERVER ROLLBACK (%s) - flag #%d, walking only for %ds"):format(tostring(why), GlideFlags, back))
end
local function glideAllowed()
	if not P.FastMove then return false end
	if GlideFlags >= 6 then return false end
	return os.clock() >= GlideBlockUntil
end
P.glideAllowed = glideAllowed

local GlideDrive
local GlideGen = 0
local function glideStop()
	GlideGen = GlideGen + 1
	if GlideDrive then
		GlideDrive:Disconnect()
		GlideDrive = nil
	end
end
P.glideStop = glideStop

local function glideSegment(dest, speed, opts)
	opts = opts or {}
	local _, hrp = curChar()
	if not hrp then return false end
	local st = hrp.Position
	local flat = Vector3.new(dest.X - st.X, 0, dest.Z - st.Z)
	local dist = flat.Magnitude
	if dist < 1 then return true end
	local dir = flat.Unit
	local t0 = os.clock()
	glideStop()
	local myGen = GlideGen
	local rolled = false
	local blocked = false
	local prevActual
	local lastCmd
	GlideDrive = RunService.Heartbeat:Connect(function()
		if GlideGen ~= myGen or not P.Running or P.Unloaded then return end
		local _, q = curChar()
		if not q then return end
		local actual = Vector3.new(q.Position.X, 0, q.Position.Z)
		if prevActual then
			local backstep = (prevActual - actual):Dot(dir)
			if backstep > 15 then
				rolled = true
				return
			end
		end
		prevActual = actual
		if lastCmd then
			local b = Vector3.new(lastCmd.X, 0, lastCmd.Z)
			if (actual - b).Magnitude > 30 then
				blocked = true
				return
			end
		end
		local want = st + dir * math.min((os.clock() - t0) * speed, dist)
		local g = groundY(want)
		lastCmd = want
		q.CFrame = CFrame.new(Vector3.new(want.X, g and (g + 3.2) or q.Position.Y, want.Z)) * q.CFrame.Rotation
		q.AssemblyLinearVelocity = Vector3.zero
	end)
	local deadline = os.clock() + dist / speed + 0.3
	while os.clock() < deadline do
		if rolled or blocked or P.AbortStep or (opts.stopWhen and opts.stopWhen()) then break end
		task.wait()
	end
	glideStop()
	if rolled then
		glideFlag("snapped backwards mid-glide")
		return false
	end
	if blocked then
		dbg("glide hit something - walking this leg")
		return false
	end
	local _, q = curChar()
	if not q then return false end
	return (Vector3.new(q.Position.X, 0, q.Position.Z) - Vector3.new(dest.X, 0, dest.Z)).Magnitude < 14
end

local function holdAt(secs, predicate)
	local _, hrp = curChar()
	if not hrp then return false end
	local pos = hrp.Position
	glideStop()
	local myGen = GlideGen
	GlideDrive = RunService.Heartbeat:Connect(function()
		if GlideGen ~= myGen or not P.Running or P.Unloaded then return end
		local _, q = curChar()
		if not q then return end
		local g = groundY(pos)
		q.CFrame = CFrame.new(Vector3.new(pos.X, g and (g + 3.2) or pos.Y, pos.Z)) * q.CFrame.Rotation
		q.AssemblyLinearVelocity = Vector3.zero
	end)
	local t0 = os.clock()
	local hit = false
	while os.clock() - t0 < secs do
		if predicate and predicate() then hit = true break end
		task.wait(0.15)
	end
	glideStop()
	return hit
end

local Shield = { conns = {}, on = false }
local function shieldAvailable()
	return type(getconnections) == "function" and type(debug) == "table" and type(debug.info) == "function"
end
P.shieldAvailable = shieldAvailable
local function shieldUp()
	if Shield.on then return #Shield.conns > 0 end
	if not shieldAvailable() then return false end
	Shield.conns = {}
	for _, sig in ipairs({ RunService.Heartbeat, RunService.PreSimulation, RunService.PostSimulation }) do
		local okG, list = pcall(getconnections, sig)
		if okG and type(list) == "table" then
			for _, c in ipairs(list) do
				local okF, f = pcall(function() return c.Function end)
				if okF and type(f) == "function" then
					local okS, src = pcall(debug.info, f, "s")
					if okS and type(src) == "string" and src:find("UGI", 1, true) then
						if pcall(function() c:Disable() end) then table.insert(Shield.conns, c) end
					end
				end
			end
		end
	end
	Shield.on = true
	dbg(("turbo shield up (%d monitor connections paused)"):format(#Shield.conns))
	return #Shield.conns > 0
end
local function shieldDown()
	for _, c in ipairs(Shield.conns) do pcall(function() c:Enable() end) end
	if Shield.on then dbg("turbo shield down") end
	Shield.conns = {}
	Shield.on = false
end
P.shieldUp = shieldUp
P.shieldDown = shieldDown

local function turboSegment(dest, speed, opts)
	opts = opts or {}
	local _, hrp = curChar()
	if not hrp then return false end
	if not shieldUp() then return nil end
	local st = hrp.Position
	local flat = Vector3.new(dest.X - st.X, 0, dest.Z - st.Z)
	local dist = flat.Magnitude
	if dist < 1 then return true end
	local dir = flat.Unit
	glideStop()
	local myGen = GlideGen
	local rolled, arrived = false, false
	local prevActual
	GlideDrive = RunService.PreSimulation:Connect(function(dt)
		if GlideGen ~= myGen or not P.Running or P.Unloaded then return end
		local _, q = curChar()
		if not q then return end
		local actual = Vector3.new(q.Position.X, 0, q.Position.Z)
		if prevActual and (prevActual - actual):Dot(dir) > 15 then rolled = true return end
		prevActual = actual
		local g = groundY(q.Position) or groundY(dest)
		local target = Vector3.new(dest.X, (g and (g + 3.2)) or dest.Y, dest.Z)
		local delta = target - q.Position
		local mag = Vector3.new(delta.X, 0, delta.Z).Magnitude
		if mag <= 2 then arrived = true end
		local step = math.max(dt, 1 / 240)
		local v = mag > 0.05 and (Vector3.new(delta.X, 0, delta.Z).Unit * math.min(speed, mag / step)) or Vector3.zero
		local vy = math.clamp(delta.Y / math.max(step, 0.05), -60, 60)
		q.AssemblyLinearVelocity = Vector3.new(v.X, vy + workspace.Gravity * step * 0.5, v.Z)
		q.AssemblyAngularVelocity = Vector3.zero
	end)
	local deadline = os.clock() + dist / speed + 1.5
	while os.clock() < deadline do
		if rolled or arrived or P.AbortStep or (opts.stopWhen and opts.stopWhen()) then break end
		P.LastProgress = os.clock()
		task.wait()
	end
	glideStop()
	local _, q = curChar()
	if q then pcall(function() q.AssemblyLinearVelocity = Vector3.zero end) end
	if rolled then
		glideFlag("turbo snapped backwards")
		return false
	end
	if not q then return false end
	return (Vector3.new(q.Position.X, 0, q.Position.Z) - Vector3.new(dest.X, 0, dest.Z)).Magnitude < 14
end
P.turboSegment = turboSegment

local function tweenHRP(dest, speed, opts)
	opts = opts or {}
	local arrive = opts.arrive or 8
	if not glideAllowed() then
		return walkTo(dest, { arrive = arrive, timeout = opts.timeout or 90, stopWhen = opts.stopWhen })
	end
	speed = math.clamp(tonumber(speed) or farmSpeed(), 20, farmSpeed())
	local carryOk = P.TurboCarry == true and (function()
		local g = geo()
		local _, h0 = curChar()
		return g ~= nil and h0 ~= nil and math.abs(h0.Position.X - g.lineX) <= (tonumber(P.TurboCarryMax) or 400)
	end)()
	local turbo = P.Turbo == true and (not P.Carrying or carryOk) and P.shieldAvailable()
	if not turbo and P.shieldDown then P.shieldDown() end
	for hop = 1, 80 do
		local _, hrp, hum = curChar()
		if not hrp then return false end
		if P.AbortStep then return false end
		if opts.stopWhen and opts.stopWhen() then return false end
		local flat = Vector3.new(dest.X - hrp.Position.X, 0, dest.Z - hrp.Position.Z)
		local rem = flat.Magnitude
		if rem <= arrive then return true end
		local step = turbo and rem or math.min(55, rem)
		local before = hrp.Position
		if turbo then
			local tr = turboSegment(before + flat.Unit * step, math.clamp(tonumber(P.TurboSpeed) or 150, 30, 400), opts)
			if tr == nil then turbo = false end
		end
		if not turbo then glideSegment(before + flat.Unit * step, speed, opts) end
		if os.clock() < GlideBlockUntil then
			return walkTo(dest, { arrive = arrive, timeout = 60, stopWhen = opts.stopWhen })
		end
		if GlideCleanAt == 0 then GlideCleanAt = os.clock() end
		if GlideFlags > 0 and os.clock() - GlideCleanAt > 90 then
			GlideFlags = GlideFlags - 1
			P.GlideFlags = GlideFlags
			GlideCleanAt = os.clock()
		end
		local _, q = curChar()
		if not q then return false end
		local moved = (Vector3.new(q.Position.X, 0, q.Position.Z) - Vector3.new(before.X, 0, before.Z)).Magnitude
		if moved > 1 then P.LastProgress = os.clock() end
		if moved < step * 0.35 then
			if hum then hum.Jump = true end
			task.wait(0.25)
			local _, q2 = curChar()
			local moved2 = q2 and (Vector3.new(q2.Position.X, 0, q2.Position.Z) - Vector3.new(before.X, 0, before.Z)).Magnitude or 0
			if moved2 < step * 0.35 then
				P.GlideStuck = (P.GlideStuck or 0) + 1
				dbg(("glide blocked hop %d rem %.0f - walking"):format(hop, rem))
				return walkTo(dest, { arrive = arrive, timeout = 30, stopWhen = opts.stopWhen })
			end
		end
	end
	return false
end

local function crossInward(z, g)
	local _, hrp, hum = curChar()
	if not hrp or not hum then return false end
	local mid = g.gateMid or ((g.gateZlo + g.gateZhi) / 2)
	local lanes = { mid, z, mid - 20, mid + 20, mid - 40, mid + 40 }
	for _, lane in ipairs(lanes) do
		if farmStop() then return false end
		local _, h2 = curChar()
		if not h2 then return false end
		if math.abs(h2.Position.Z - lane) > 8 or h2.Position.X > g.lineX - 4 then
			tweenHRP(Vector3.new(g.lineX - 12, h2.Position.Y, lane), farmSpeed(), { arrive = 7, stopWhen = farmStop })
		end
		for _ = 1, 2 do
			if farmStop() then return false end
			local _, h3, hu3 = curChar()
			if not h3 or not hu3 then return false end
			hu3:MoveTo(Vector3.new(g.lineX + 20, h3.Position.Y, lane))
			local t0 = os.clock()
			while os.clock() - t0 < 2.5 do
				if farmStop() then return false end
				local _, h4 = curChar()
				if not h4 then return false end
				if h4.Position.X > g.lineX + 3 then
					P.LastProgress = os.clock()
					dbg(("crossed at z=%.0f"):format(lane))
					return true
				end
				task.wait(0.05)
			end
			local _, _, hu4 = curChar()
			if hu4 then hu4.Jump = true end
			task.wait(0.3)
		end
		dbg(("cross lane z=%.0f blocked"):format(lane))
	end
	local _, hf = curChar()
	return hf ~= nil and hf.Position.X > g.lineX + 3
end

local function leaveTreadmill()
	local _, hrp, hum = curChar()
	if not hrp or not hum then return end
	local pm = homePlot()
	local tb = pm and pm:FindFirstChild("TreadmillBottom")
	if not tb then return end
	if ((tb.Position - hrp.Position) * Vector3.new(1, 0, 1)).Magnitude < 4 then
		hum.Jump = true
		task.wait(0.2)
		hum:MoveTo(tb.Position + Vector3.new(10, 0, 0))
		task.wait(0.3)
		dbg("jumped off treadmill")
	end
end

local FarmBlacklist = {}

local function pickFarmTarget()
	local V = P.V14
	if V and P.WaitNight then
		local closed, why = V.fieldClosed()
		if closed then
			P.FieldClosed = why
			return nil
		end
	end
	P.FieldClosed = nil
	local recs = fieldRecords()
	if not recs then return nil end
	local char = LP.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	local now = os.clock()
	local best, bd, bv
	local considered = 0
	for _, r in pairs(recs) do
		if type(r) == "table" and r.Uid and typeof(r.BottomCFrame) == "CFrame" then
			local st = tostring(r.State)
			if (st == "Slot" or st == "Dropped")
				and (FarmBlacklist[r.Uid] or 0) < now
				and not eggIsOthers(r.Uid)
				and (not P.FarmSkipParasite or r.HasParasite ~= true) then
				local allow, boost = true, 0
				if V then allow, boost = V.stealAllowed(r) end
				if allow and (boost > 0 or (rarityAllows(r.AssetCategory) and isUpgrade(r))) and nestGuardOk(r) then
					considered += 1
					local d = (r.BottomCFrame.Position - hrp.Position).Magnitude
					local mode = P.BestFirst and "Highest Value" or (P.StealPriority or "Nearest")
					if boost > 0 or mode == "Nearest" or d <= (tonumber(P.GrabRange) or 400) then
						local base
						if P.BestFirst then base = rateOf(r) elseif V then base = V.stealScore(r, d) else base = -d end
						local sc = boost * 1e30 + base
						if not best or sc > bv or (sc == bv and d < bd) then bv = sc bd = d best = r end
					end
				end
			end
		end
	end
	if UpgLabel and now - (P.UpgLabelAt or 0) > 2 then
		P.UpgLabelAt = now
		local floor, placed, cap = baseFloor()
		local txt = ("base %d/%d - weakest $%s/s - %d eligible - next: %s"):format(placed, cap, fmtRate(floor), considered, best and ("$" .. fmtRate(rateOf(best)) .. "/s " .. fmtRate(bd or 0) .. " st") or "none")
		if txt ~= P.UpgLabelTxt then
			P.UpgLabelTxt = txt
			P.setLabel(UpgLabel, txt)
		end
	end
	if considered > 0 then P.LastEligibleAt = now end
	if GuardLabel and now - (P.GuardLabelAt or 0) > 3 then
		P.GuardLabelAt = now
		local txt = guardSummary()
		if txt ~= P.GuardLabelTxt then
			P.GuardLabelTxt = txt
			P.setLabel(GuardLabel, txt)
		end
	end
	return best
end
P.pickFarmTarget = pickFarmTarget

local function stillValid(uid)
	local ok, r = pcall(Egg.ReadFieldEgg, uid)
	if not ok or type(r) ~= "table" then return false end
	local st = tostring(r.State)
	return st == "Slot" or st == "Dropped"
end

local FarmLabel
local lastStatus = ""
local function setFarmStatus(s)
	if s == lastStatus then return end
	lastStatus = s
	P.FarmState = s
	if FarmLabel then P.setLabel(FarmLabel, "state: " .. s) end
end

local function goHome()
	carryStale()
	local pd = localPlotData()
	local pa = pd and pd.PetArea
	if not pa then
		setFarmStatus("no plot found")
		task.wait(1)
		return
	end
	setFarmStatus("carrying home")
	walkTo(pa.Position, { arrive = 6, timeout = 120, stopWhen = function()
		return farmStop() or not P.Carrying
	end })
	if not P.Farm then return end
	local t0 = os.clock()
	while P.Carrying and os.clock() - t0 < 6 do task.wait(0.2) end
	if not P.Carrying then
		local char = LP.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp and ((pa.Position - hrp.Position) * Vector3.new(1, 0, 1)).Magnitude > 6 then
			setFarmStatus("to pet area")
			walkTo(pa.Position, { arrive = 6, timeout = 60, stopWhen = function()
				return not P.Farm
			end })
		end
		if not P.Farm then return end
		setFarmStatus("placing")
		for _ = 1, 3 do
			pcall(tryPlace)
			task.wait(0.4)
		end
	end
end

local function treadmillStep()
	local pm = homePlot()
	local tb = pm and pm:FindFirstChild("TreadmillBottom")
	if not tb then
		setFarmStatus("no treadmill")
		task.wait(1)
		return
	end
	local _, hrp, hum = curChar()
	if not hum or not hrp then return end
	local flat = ((tb.Position - hrp.Position) * Vector3.new(1, 0, 1)).Magnitude
	if flat > 3 then
		setFarmStatus("to treadmill")
		local lastChk, seen = 0, false
		if P.FastMove then
			tweenHRP(tb.Position + Vector3.new(0, 3, 0), farmSpeed(), { arrive = 3, stopWhen = function()
				if not P.Farm or not P.FarmTreadmill then return true end
				if os.clock() - lastChk > 1 then lastChk = os.clock() seen = pickFarmTarget() ~= nil end
				return seen
			end })
		end
		lastChk = 0
		walkTo(tb.Position, { arrive = 1.5, timeout = 90, stopWhen = function()
			if not P.Farm or not P.FarmTreadmill then return true end
			if os.clock() - lastChk > 2 then
				lastChk = os.clock()
				seen = pickFarmTarget() ~= nil
			end
			return seen
		end })
	else
		setFarmStatus("treadmill +speed")
		local t0 = os.clock()
		while P.Farm and P.FarmTreadmill and os.clock() - t0 < 4 do
			task.wait(0.25)
			if pickFarmTarget() ~= nil then break end
			local f2 = ((tb.Position - hrp.Position) * Vector3.new(1, 0, 1)).Magnitude
			if f2 > 3 then hum:MoveTo(tb.Position) end
		end
		if pickFarmTarget() ~= nil then leaveTreadmill() end
	end
end

local placeFails = 0
local placeBackoffUntil = 0

local function unplacedCount()
	local recs = ownRecords()
	if type(recs) ~= "table" then return 0 end
	local n = 0
	for _, r in pairs(recs) do
		if type(r) == "table" and r.Placement == nil and (not P.V14 or P.V14.placeAllowed(r)) then n = n + 1 end
	end
	return n
end

local backoffLevel = 0
local BACKOFFS = { 30, 90, 180, 300, 300 }
local function farmFailed()
	P.GrabFails = (P.GrabFails or 0) + 1
	if P.GrabFails >= 6 then
		P.GrabFails = 0
		backoffLevel = math.min(backoffLevel + 1, #BACKOFFS)
		local dur = BACKOFFS[backoffLevel]
		placeBackoffUntil = math.max(placeBackoffUntil, os.clock() + dur)
		dbg(("carry refused repeatedly -> treadmill %ds (lvl %d)"):format(dur, backoffLevel))
	end
end

local function farmOk()
	P.GrabFails = 0
	backoffLevel = 0
end

local function placeBatch()
	if os.clock() < (P.PlaceSkipUntil or 0) then
		P.Banked = 0
		return
	end
	local pd = localPlotData()
	local pa = pd and pd.PetArea
	if not pa then P.Banked = 0 return end
	leaveTreadmill()
	setFarmStatus("placing")
	local _, hrp = curChar()
	if hrp and ((pa.Position - hrp.Position) * Vector3.new(1, 0, 1)).Magnitude > 8 then
		if P.FastMove then tweenHRP(pa.Position, farmSpeed(), { arrive = 6, stopWhen = farmStop }) end
		local _, h2 = curChar()
		if h2 and ((pa.Position - h2.Position) * Vector3.new(1, 0, 1)).Magnitude > 10 then
			walkTo(pa.Position, { arrive = 6, timeout = 25, stopWhen = farmStop })
		end
	end
	holdAt(1.2, function() return farmStop() end)
	local before = unplacedCount()
	for _ = 1, 6 do
		if farmStop() then break end
		pcall(tryPlace)
		holdAt(1.6, function() return unplacedCount() < before end)
		local left = unplacedCount()
		if left == 0 then break end
		if left >= before then break end
		before = left
	end
	P.Banked = 0
	local after = unplacedCount()
	if after > 0 and after >= before then
		placeFails = placeFails + 1
		if placeFails >= 2 then
			P.PlaceSkipUntil = os.clock() + 120
			placeFails = 0
			dbg("place rejected (pen full) - skipping placing 120s, still stealing")
		end
	else
		placeFails = 0
	end
	dbg("place pass: " .. after .. " left")
end

local function farmGrab(target)
	local key = slotKeyFor(target)
	if P.shieldDown and P.Turbo then
		P.shieldDown()
		holdAt(tonumber(P.TrustSettle) or 1.5, function() return farmStop() end)
	end
	P.LastGrabUid = target.Uid
	P.LastGrabInfo = { cat = target.AssetCategory, scale = target.AssetScale, muts = target.Mutations, area = target.AreaId }
	P.LastGrabArea = target.AreaId or (target.rec and target.rec.AreaId)
	local lastRes, lastErr
	local success = false
	holdAt(4.5, function()
		if farmStop() then return true end
		local okC, res, err = pcall(Egg.CarryFieldEgg, target.Uid, key)
		if okC and res == true then
			success = true
			return true
		end
		lastRes, lastErr = okC and res or ("pcall:" .. tostring(res)), err
		if okC and type(err) == "string" and err:lower():find("full") then P.NeedSell = true end
		return false
	end)
	if success then
		P.Carrying = true
		P.CarryAt = os.clock()
		P.LastProgress = os.clock()
		dbg("grab ok " .. tostring(target.Uid):sub(1, 10))
		return true
	end
	P.LastGrabErr = lastErr
	dbg("grab fail " .. tostring(target.Uid):sub(1, 10) .. " res=" .. tostring(lastRes) .. " err=" .. tostring(lastErr))
	return false
end

local function bankAtLine(z, g)
	local _, hrp = curChar()
	if not hrp then return false end
	tweenHRP(Vector3.new(g.lineX - 10, hrp.Position.Y, z), farmSpeed(), { arrive = 8, stopWhen = function() return not P.Carrying or farmStop() end })
	local t0 = os.clock()
	while os.clock() - t0 < 2.5 do
		if not P.Carrying then
			local dx = math.abs(hrp.Position.X - g.lineX)
			P.LastProgress = os.clock()
			if dx > 20 then
				P.Dropped = (P.Dropped or 0) + 1
				if P.LastGrabUid then FarmBlacklist[P.LastGrabUid] = os.clock() + 240 end
				P.DropsByArea = P.DropsByArea or {}
				if P.LastGrabArea then P.DropsByArea[P.LastGrabArea] = (P.DropsByArea[P.LastGrabArea] or 0) + 1 end
				dbg(("egg dropped short of the line (dx=%.0f), not counted"):format(dx))
				return false
			end
			P.Banked = P.Banked + 1
			P.TotalBanked = (P.TotalBanked or 0) + 1
			pcall(function()
				local i = P.LastGrabInfo
				if i and P.V14 then P.V14.sendStealWebhook(i.cat, i.scale, i.muts, i.area) end
			end)
			dbg(("banked #%d dx=%.0f"):format(P.Banked, dx))
			return true
		end
		task.wait(0.05)
	end
	return not P.Carrying
end

local function farmStepFast(g)
	carryStale()
	if P.Carrying then
		local _, hrp = curChar()
		if hrp and hrp.Position.X > g.lineX then
			bankAtLine(math.clamp(hrp.Position.Z, g.gateZlo, g.gateZhi), g)
		else
			goHome()
		end
		return
	end
	if os.clock() < placeBackoffUntil then
		P.Banked = 0
		setFarmStatus("cooldown - treadmill")
		if P.FarmTreadmill then treadmillStep() else task.wait(1) end
		return
	end
	local target = pickFarmTarget()
	if not target then
		if P.Banked > 0 then placeBatch() end
		if P.FieldClosed and not P.FarmTreadmill then setFarmStatus(P.FieldClosed) task.wait(0.6) return end
		if P.FarmTreadmill then treadmillStep() else setFarmStatus("no eggs match") task.wait(0.6) end
		if P.FieldClosed then setFarmStatus(P.FieldClosed .. " - treadmill") end
		return
	end
	leaveTreadmill()
	local ep = target.BottomCFrame.Position
	local cz = math.clamp(ep.Z, g.gateZlo, g.gateZhi)
	if P.GuardAvoid then
		local bestZ, bestScore
		for _, cand in ipairs({ cz, g.gateZlo + 10, g.gateZhi - 10, (g.gateZlo + g.gateZhi) / 2 }) do
			local pt = Vector3.new(g.lineX + 12, ep.Y, cand)
			local dmin = math.huge
			for _, a in ipairs(guardAreas()) do
				local d = ((a.part.Position - pt) * Vector3.new(1, 0, 1)).Magnitude
				if d < dmin then dmin = d end
			end
			local score = math.min(dmin, 80) - math.abs(cand - ep.Z) * 0.1
			if not bestScore or score > bestScore then bestZ = cand bestScore = score end
		end
		cz = bestZ
	end
	local _, hrp = curChar()
	if not hrp then return end
	local _, rn = catRarity(target.AssetCategory)
	local a = AssetsDir[target.AssetCategory]
	setFarmStatus("egg: " .. tostring(a and a.DisplayName or target.AssetCategory) .. " [" .. rn .. "]")
	if hrp.Position.X <= g.lineX + 2 then
		local lane = g.gateMid or cz
		if not tweenHRP(Vector3.new(g.lineX - 12, hrp.Position.Y, lane), farmSpeed(), { arrive = 8, stopWhen = farmStop }) then return end
		if farmStop() then return end
		if not crossInward(lane, g) then FarmBlacklist[target.Uid] = os.clock() + 10 return end
	end
	if farmStop() then return end
	if not stillValid(target.Uid) then FarmBlacklist[target.Uid] = os.clock() + 4 return end
	local svAt, svOk = os.clock(), true
	local okT = tweenHRP(Vector3.new(ep.X, ep.Y + 3, ep.Z), farmSpeed(), { arrive = 7, stopWhen = function()
		if farmStop() then return true end
		if os.clock() - svAt >= 0.5 then
			svAt = os.clock()
			svOk = stillValid(target.Uid)
		end
		return not svOk
	end })
	if farmStop() then return end
	if not stillValid(target.Uid) then FarmBlacklist[target.Uid] = os.clock() + 4 return end
	if not okT then FarmBlacklist[target.Uid] = os.clock() + 6 farmFailed() return end
	if not farmGrab(target) then
		if tostring(P.LastGrabErr or ""):lower():find("gameplay area") then
			FarmBlacklist[target.Uid] = os.clock() + 300
			dbg("egg needs area entry, skipping it 5m")
		else
			FarmBlacklist[target.Uid] = os.clock() + 8
			farmFailed()
		end
		return
	end
	farmOk()
	bankAtLine(cz, g)
	if P.Banked >= (tonumber(P.PlaceBatch) or 1) then placeBatch() end
end

local function farmStepWalk()
	if P.Carrying then
		goHome()
		return
	end
	local target = pickFarmTarget()
	if target then
		leaveTreadmill()
		local _, rn = catRarity(target.AssetCategory)
		local a = AssetsDir[target.AssetCategory]
		setFarmStatus("egg: " .. tostring(a and a.DisplayName or target.AssetCategory) .. " [" .. rn .. "]")
		local dest = target.BottomCFrame.Position
		local lastChk = 0
		local gone = false
		local okW = walkTo(dest, { arrive = 6, timeout = 90, stopWhen = function()
			if farmStop() or P.Carrying then return true end
			if os.clock() - lastChk > 2 then
				lastChk = os.clock()
				gone = not stillValid(target.Uid)
			end
			return gone
		end })
		if not P.Farm or P.Carrying then return end
		if gone or not stillValid(target.Uid) then
			FarmBlacklist[target.Uid] = os.clock() + 5
			return
		end
		if not okW then
			FarmBlacklist[target.Uid] = os.clock() + 15
			return
		end
		local _, hrp, hum = curChar()
		if hrp and hum and (dest - hrp.Position).Magnitude > 7.5 then
			hum:MoveTo(dest)
			task.wait(0.6)
		end
		local okC, res = pcall(Egg.CarryFieldEgg, target.Uid, slotKeyFor(target))
		if okC and res == true then
			P.Carrying = true
			P.CarryAt = os.clock()
		else
			FarmBlacklist[target.Uid] = os.clock() + 8
		end
	elseif P.FarmTreadmill then
		treadmillStep()
	else
		setFarmStatus("no eggs match")
		task.wait(1)
	end
end

local function farmStep(gen)
	StepGen = gen
	if P.FastMove then
		local g = geo()
		if g then farmStepFast(g) return end
	end
	farmStepWalk()
end

task.spawn(function()
	while P.Running do
		if P.Farm and P.HoldFarm then
			setFarmStatus("paused for mutation item")
			task.wait(0.5)
		elseif P.Farm then
			local ch = LP.Character
			if ch and ch:GetAttribute("IsTrapped") then
				setFarmStatus("caught by guard, waiting")
				local tt = os.clock()
				while P.Running and ch.Parent and ch:GetAttribute("IsTrapped") and os.clock() - tt < 25 do task.wait(0.2) end
			end
			local done = false
			P.AbortStep = false
			P.LastProgress = os.clock()
			P.StepGen = (P.StepGen or 0) + 1
			local gen = P.StepGen
			task.spawn(function() pcall(farmStep, gen) done = true end)
			local t0 = os.clock()
			local stall = tonumber(P.StallBudget) or 25
			local cap = tonumber(P.StepCap) or 150
			while not done and os.clock() - t0 < cap and os.clock() - (P.LastProgress or t0) < stall do task.wait(0.1) end
			if not done then
				dbg(("watchdog: %s after %ds (%ds without progress), aborting step"):format(os.clock() - t0 >= cap and "cap" or "stall", os.clock() - t0, os.clock() - (P.LastProgress or t0)))
				P.AbortStep = true
				P.StepAborts = (P.StepAborts or 0) + 1
				Walker.Token = Walker.Token + 1
				P.StepGen = P.StepGen + 1
				local t1 = os.clock()
				local warned = false
				while not done and P.Running do
					if not warned and os.clock() - t1 > 20 then
						warned = true
						dbg("watchdog: step ignored abort, waiting for it to finish")
					end
					task.wait(0.1)
				end
				P.AbortStep = false
			end
		end
		task.wait(0.25)
	end
end)

task.spawn(function()
	while P.Running do
		if P.AfkTreadmill and not P.Farm then
			pcall(function()
				local pm = homePlot()
				local tb = pm and pm:FindFirstChild("TreadmillBottom")
				local char = LP.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if tb and hum and hrp then
					local flat = ((tb.Position - hrp.Position) * Vector3.new(1, 0, 1)).Magnitude
					if flat > 3 then
						walkTo(tb.Position, { arrive = 1.5, timeout = 90, stopWhen = function()
							return not P.AfkTreadmill or P.Farm
						end })
					end
				end
			end)
		end
		task.wait(1)
	end
end)

local RarityIds = {}
do
	local seen = {}
	for _, a in pairs(AssetsDir) do
		if type(a) == "table" and type(a.Rarity) == "table" then
			local id = a.Rarity._id or a.Rarity.Id or a.Rarity.RarityId
			local num = tonumber(a.Rarity.RarityNumber) or 0
			local nm = tostring(a.Rarity.DisplayName or id or "?")
			if id ~= nil and not seen[tostring(id)] then
				seen[tostring(id)] = true
				table.insert(RarityIds, { num = num, id = id, name = nm })
			end
		end
	end
	table.sort(RarityIds, function(x, y) return x.num < y.num end)
end

local function remoteFire(family, name, ...)
	if type(Remotes) ~= "table" or type(Remotes[family]) ~= "table" then return false, "no family" end
	local r = Remotes[family][name]
	if typeof(r) ~= "Instance" then return false, "no remote" end
	local args = { ... }
	local ok, a, b, c = pcall(function()
		if r:IsA("RemoteFunction") then return r:InvokeServer(table.unpack(args)) end
		r:FireServer(table.unpack(args))
		return true
	end)
	return ok, a, b, c
end

local function applyAutoSell(maxNum)
	local map = {}
	if maxNum > 0 then
		for _, r in ipairs(RarityIds) do
			if r.num <= maxNum then map[r.id] = true end
		end
	end
	local ok = remoteFire("Haul", "WriteAutoSell", map)
	dbg(("auto-sell up to rarity %d: %s (%d rarities)"):format(maxNum, ok and "set" or "failed", (function() local n=0 for _ in pairs(map) do n=n+1 end return n end)()))
end

local function codexRedeemAll()
	local ok, s = remoteFire("Codex", "AskRedeemAll")
	dbg("codex redeem-all: " .. tostring(ok and s))
	return ok and s
end

local function codexRedeemLimitedEgg()
	local ok, s = remoteFire("Codex", "AskRedeemLimitedEgg")
	dbg("codex limited egg: " .. tostring(ok and s))
end

local FarmSave
pcall(function() FarmSave = require(RS.Shared.Save) end)

local function invCount()
	if not FarmSave then return 0 end
	local ok, d = pcall(function() return (FarmSave.Peek or FarmSave.Get)() end)
	if not ok or type(d) ~= "table" or type(d.Inventory) ~= "table" then return 0 end
	local n = 0
	for _ in pairs(d.Inventory) do n = n + 1 end
	return n
end
P.invCount = invCount

local function sellJunk()
	if not FarmSave then return end
	local okD, d = pcall(function() return (FarmSave.Peek or FarmSave.Get)() end)
	if not okD or type(d) ~= "table" or type(d.Inventory) ~= "table" then return end
	local worn = {}
	pcall(function()
		if not AssetRoster then return end
		local snap = AssetRoster.ReadSnapshot()
		for _, row in pairs(snap) do
			if type(row) == "table" and tostring(row.OwnerUserId) == tostring(LP.UserId) and type(row.Records) == "table" then
				for uid in pairs(row.Records) do worn[tostring(uid)] = true end
			end
		end
	end)
	local keepAbove = tonumber(P.ClearRarity) or 3
	local _, _, cap = baseFloor()
	local ranked = {}
	for uid, item in pairs(d.Inventory) do
		if type(item) == "table" then table.insert(ranked, { uid = uid, v = rateOf(item) }) end
	end
	table.sort(ranked, function(x, y) return x.v > y.v end)
	local protect = {}
	for i = 1, math.min(#ranked, math.max(cap, 1) + 2) do protect[tostring(ranked[i].uid)] = true end
	for _, uid in pairs(type(d.EquippedAssets) == "table" and d.EquippedAssets or {}) do protect[tostring(uid)] = true end
	local sell = {}
	for uid, item in pairs(d.Inventory) do
		if type(item) == "table" and item.InFuse ~= true and item.IsFavorite ~= true and item.Favorite ~= true and not worn[tostring(uid)] and not protect[tostring(uid)] then
			local a = item.Category and AssetsDir[item.Category]
			local rn = (a and type(a.Rarity) == "table" and tonumber(a.Rarity.RarityNumber)) or 0
			if rn <= keepAbove then
				table.insert(sell, uid)
				if #sell >= 200 then break end
			end
		end
	end
	P.NeedSell = false
	if #sell == 0 then return end
	local before = invCount()
	remoteFire("PetSatchel", "SellSelection", { Assets = sell, Eggs = {} })
	task.wait(1.5)
	dbg(("sold %d junk pets (inv %d -> %d)"):format(#sell, before, invCount()))
end

local function wornCount()
	local n = 0
	pcall(function()
		if not AssetRoster then return end
		local snap = AssetRoster.ReadSnapshot()
		for _, row in pairs(snap) do
			if type(row) == "table" and tostring(row.OwnerUserId) == tostring(LP.UserId) and type(row.Records) == "table" then
				for _ in pairs(row.Records) do n = n + 1 end
			end
		end
	end)
	return n
end

local function cullWeak()
	if not FarmSave then return end
	local okD, d = pcall(function() return (FarmSave.Peek or FarmSave.Get)() end)
	if not okD or type(d) ~= "table" or type(d.Inventory) ~= "table" then return end
	local worn = {}
	pcall(function()
		if not AssetRoster then return end
		local snap = AssetRoster.ReadSnapshot()
		for _, row in pairs(snap) do
			if type(row) == "table" and tostring(row.OwnerUserId) == tostring(LP.UserId) and type(row.Records) == "table" then
				for uid in pairs(row.Records) do worn[tostring(uid)] = true end
			end
		end
	end)
	local _, _, cap = baseFloor()
	cap = math.max(tonumber(cap) or 0, 1)
	local keep = cap + math.max(tonumber(P.KeepSpare) or 3, 0)
	local ranked = {}
	for uid, item in pairs(d.Inventory) do
		if type(item) == "table" then table.insert(ranked, { uid = uid, v = rateOf(item) }) end
	end
	table.sort(ranked, function(x, y) return x.v > y.v end)
	local protect = {}
	for i = 1, math.min(#ranked, keep) do protect[tostring(ranked[i].uid)] = true end
	for _, uid in pairs(type(d.EquippedAssets) == "table" and d.EquippedAssets or {}) do protect[tostring(uid)] = true end
	local sell, kept = {}, nil
	for i = 1, #ranked do
		local row = ranked[i]
		local item = d.Inventory[row.uid]
		if type(item) == "table" and item.InFuse ~= true and item.IsFavorite ~= true and item.Favorite ~= true
			and not worn[tostring(row.uid)] and not protect[tostring(row.uid)] then
			table.insert(sell, row.uid)
			if #sell >= 200 then break end
		elseif protect[tostring(row.uid)] then
			kept = row.v
		end
	end
	if #sell == 0 then return 0 end
	local before = invCount()
	remoteFire("PetSatchel", "SellSelection", { Assets = sell, Eggs = {} })
	task.wait(1.2)
	dbg(("culled %d weakest pets (inv %d -> %d, weakest kept $%s/s)"):format(#sell, before, invCount(), fmtRate(kept or 0)))
	pcall(equipBest)
	return #sell
end

local function awayCollect()
	local claimable = true
	if type(Remotes) == "table" and type(Remotes.AwayEarnings) == "table" and typeof(Remotes.AwayEarnings.FetchSummary) == "Instance" then
		local okS, sum = pcall(function() return Remotes.AwayEarnings.FetchSummary:InvokeServer() end)
		if okS and type(sum) == "table" then
			local amt = sum.ClaimableAmount or sum.AwardedAmount or sum.Amount or sum.Claimable or sum.Pending or sum.TotalAmount
			if type(amt) == "number" then claimable = amt > 0 end
		end
	end
	if not claimable then return false, 0 end
	local ok, s, _, res = remoteFire("AwayEarnings", "AskCollect", { Kind = "Claim" })
	local amt = type(res) == "table" and tonumber(res.AwardedAmount) or nil
	dbg("away collect: " .. tostring(ok and s) .. " amt=" .. tostring(amt or "?"))
	return (ok and s) == true, amt or 0
end

task.spawn(function()
	local lastCodex, lastAway, lastSell, lastCull = 0, 0, 0, 0
	while P.Running do
		if P.AutoCodex and os.clock() - lastCodex > 300 then
			lastCodex = os.clock()
			pcall(codexRedeemAll)
			pcall(codexRedeemLimitedEgg)
		end
		if P.AutoAway and os.clock() - lastAway > 120 then
			lastAway = os.clock()
			pcall(awayCollect)
		end
		if P.AutoCull and os.clock() - (lastCull or 0) > 45 then
			lastCull = os.clock()
			pcall(cullWeak)
		end
		if P.AutoClearInv and not P.AutoCull and os.clock() - lastSell > 12 and (P.NeedSell or (P.Farm and invCount() > 170)) then
			lastSell = os.clock()
			pcall(sellJunk)
		end
		task.wait(3)
	end
end)

for _, sigName in ipairs({ "FieldRefreshed", "FieldGone", "FieldShifted", "FieldClaimed", "SnapshotRefreshed" }) do
	pcall(function()
		conn(Egg[sigName]:Connect(markDirty))
	end)
end
conn(AE.ChildAdded:Connect(markDirty))
conn(AE.ChildRemoved:Connect(markDirty))

do
P.TargetAreas = {}
P.TargetEggs = {}
P.MinStealValue = 0
P.StealPriority = "Nearest"
P.IndexFirst = false
P.RiftFirst = false
P.WaitNight = true
P.PlaceRule = "Always"
P.PlaceOrder = "Highest Value"
P.PlaceMinRarity = 0
P.PlaceMinValue = 0
P.HatchMinRarity = 0
P.HatchMinValue = 0
P.HatchSpecies = {}
P.SellPetsOn = false
P.SellPetRule = "Rarity Only"
P.SellPetMaxRarity = 3
P.SellPetMaxValue = 0
P.SellKeepMutated = true
P.SellBlacklist = {}
P.SellEggsOn = false
P.SellEggRule = "Rarity Only"
P.SellEggMaxRarity = 3
P.SellEggMaxValue = 0
P.SellEggKeepMutated = true
P.FuseOn = false
P.FuseMaxRarity = 6
P.FuseSkipMutated = true
P.FuseSpecies = {}
P.FusePick = "Lowest Rarity"
P.FuseEject = true
P.FavOn = false
P.FavRule = "Match All"
P.FavMinRarity = 0
P.FavMinValue = 0
P.FavMutations = {}
P.FavAnyMutation = false
P.FavSpecies = {}
P.RiftOn = false
P.RiftReroll = false
P.BossShopOn = false
P.BossShopItems = { MutationConsumable = true }
P.BossKeep = 0
P.MutateOn = false
P.MutateSkipMutated = true
P.MutateMinRarity = 0
P.AntiRagdoll = false
P.AntiTrap = false
P.InstantPrompts = false
P.InfJump = false
P.AutoRejoin = true
P.AutoReload = true
P.HopMode = "Least Players"
P.StealWebhook = false
P.PlayerESP = false
P.HitAura = false
P.HitHoldersOnly = true

local V14 = {}
P.V14 = V14

local function setOf(list)
	local s = {}
	for _, v in ipairs(type(list) == "table" and list or {}) do s[v] = true end
	return s
end
V14.setOf = setOf

local function hasMutation(rec)
	if type(rec) ~= "table" then return false end
	if type(rec.BaseMutation) == "string" and rec.BaseMutation ~= "" then return true end
	return type(rec.Mutations) == "table" and next(rec.Mutations) ~= nil
end
V14.hasMutation = hasMutation

local function mutationSet(rec)
	local s = {}
	if type(rec) ~= "table" then return s end
	if type(rec.Mutations) == "table" then
		for k, v in pairs(rec.Mutations) do
			if type(v) == "string" then s[v] = true elseif v == true and type(k) == "string" then s[k] = true end
		end
	end
	if type(rec.BaseMutation) == "string" and rec.BaseMutation ~= "" then s[rec.BaseMutation] = true end
	return s
end
V14.mutationSet = mutationSet

local function catOf(rec)
	return rec and (rec.AssetCategory or rec.Category)
end

local function rarityNum(rec)
	local n = catRarity(catOf(rec))
	return n or 0
end
V14.rarityNum = rarityNum

local DisplayToCat, CatToDisplay, EggOptions = {}, {}, {}
do
	local rows = {}
	for cat, a in pairs(AssetsDir) do
		if type(a) == "table" and type(a.Rarity) == "table" and a.DontRoll ~= true then
			local rn = tonumber(a.Rarity.RarityNumber) or 0
			table.insert(rows, { cat = cat, name = tostring(a.DisplayName or cat), rar = tostring(a.Rarity.DisplayName or "?"), rn = rn })
		end
	end
	table.sort(rows, function(x, y)
		if x.rn ~= y.rn then return x.rn > y.rn end
		return x.name < y.name
	end)
	for _, r in ipairs(rows) do
		local label = r.name .. " [" .. r.rar .. "]"
		if DisplayToCat[label] then label = label .. " (" .. r.cat .. ")" end
		DisplayToCat[label] = r.cat
		CatToDisplay[r.cat] = label
		table.insert(EggOptions, label)
	end
end
V14.EggOptions = EggOptions
V14.labelsToCats = function(list)
	local s = {}
	for _, l in ipairs(type(list) == "table" and list or {}) do
		local c = DisplayToCat[l]
		if c then s[c] = true end
	end
	return s
end

local AreaOptions = {}
do
	local seen = {}
	local function add(n)
		n = tostring(n)
		if n ~= "" and not seen[n] then seen[n] = true table.insert(AreaOptions, n) end
	end
	for _, n in ipairs({ "Forest", "Lake", "Desert", "Jungle", "Snow", "Volcano", "Abyss Ocean", "Prehistoric", "Cosmic", "Cherry Blossom", "Titan Temple", "Light Dark", "Enchanted Forest" }) do add(n) end
	pcall(function()
		for name in pairs(GuardsMod and GuardsMod.Directory or {}) do add(name) end
	end)
	P.iso(function()
		local recs = fieldRecords()
		for _, r in pairs(recs or {}) do if type(r) == "table" and r.AreaId then add(r.AreaId) end end
	end)
end
V14.AreaOptions = AreaOptions

local MutationOptions = {}
local MutLabelToId = {}
P.iso(function()
	local M = require(RS.Shared.Modules.Mutations)
	local all = type(M.All) == "function" and M.All() or M.IdSet
	local ids = {}
	for k, v in pairs(all or {}) do
		local id = type(v) == "table" and (v.Id or k) or k
		local label = type(v) == "table" and v.Label or nil
		table.insert(ids, { id = tostring(id), label = tostring(label or id) })
	end
	table.sort(ids, function(a, b) return a.label < b.label end)
	for _, r in ipairs(ids) do
		local l = r.label ~= r.id and (r.label .. " (" .. r.id .. ")") or r.id
		MutLabelToId[l] = r.id
		table.insert(MutationOptions, l)
	end
end)
V14.MutationOptions = MutationOptions
V14.mutLabelsToIds = function(list)
	local s = {}
	for _, l in ipairs(type(list) == "table" and list or {}) do s[MutLabelToId[l] or l] = true end
	return s
end

local function serverNow()
	local ok, t = pcall(function() return workspace:GetServerTimeNow() end)
	return ok and t or tick()
end

local WallMod
pcall(function() WallMod = require(RS.Client.AreaEggResetWall) end)
V14.fieldClosed = function()
	if CycleMod and type(CycleMod.IsNightPhase) == "function" then
		local ok, night = pcall(CycleMod.IsNightPhase, serverNow())
		if ok and night == true then return true, "night - field is resetting" end
	end
	if WallMod and type(WallMod.IsSealed) == "function" then
		local ok, sealed = pcall(WallMod.IsSealed)
		if ok and sealed == true then return true, "reset wall is up" end
	end
	return false
end
V14.isNight = function()
	if CycleMod and type(CycleMod.IsNightPhase) == "function" then
		local ok, night = pcall(CycleMod.IsNightPhase, serverNow())
		return ok and night == true
	end
	return false
end

local IndexCache = { at = -99, missing = {} }
V14.indexMissing = function()
	if os.clock() - IndexCache.at < 6 then return IndexCache.missing end
	IndexCache.at = os.clock()
	local miss = {}
	local d = saveData()
	if d then
		local index = type(d.Index) == "table" and d.Index or {}
		local have = {}
		for _, item in pairs(type(d.Inventory) == "table" and d.Inventory or {}) do
			if type(item) == "table" and item.Category then have[tostring(item.Category)] = true end
		end
		for _, item in pairs(type(d.EggInventory) == "table" and d.EggInventory or {}) do
			if type(item) == "table" then
				local c = item.AssetCategory or item.Category
				if c then have[tostring(c)] = true end
			end
		end
		for cat, a in pairs(AssetsDir) do
			if type(a) == "table" and a.DontRoll ~= true and index[cat] ~= true and not have[tostring(cat)] then
				miss[tostring(cat)] = true
			end
		end
	end
	IndexCache.missing = miss
	return miss
end

local RiftState = { at = -99, state = nil, busy = false }
V14.riftState = function(force)
	if not force and RiftState.state and os.clock() - RiftState.at < ((P.RiftOn or P.RiftFirst or P.RiftReroll) and 8 or 30) then return RiftState.state end
	if RiftState.busy then return RiftState.state end
	RiftState.busy = true
	local ok, s = remoteFire("Rift", "AskState")
	if ok and type(s) == "table" then
		RiftState.state = s
		RiftState.at = os.clock()
	end
	RiftState.busy = false
	return RiftState.state
end
V14.riftNeeds = function()
	local need = {}
	local s = RiftState.state
	if type(s) ~= "table" or type(s.Requirements) ~= "table" then return need end
	local have = {}
	local d = saveData()
	if d then
		for _, item in pairs(type(d.Inventory) == "table" and d.Inventory or {}) do
			if type(item) == "table" and item.Category and item.IsFavorite ~= true and item.InFuse ~= true then
				have[tostring(item.Category)] = (have[tostring(item.Category)] or 0) + 1
			end
		end
	end
	for _, req in ipairs(s.Requirements) do
		local c = tostring(type(req) == "table" and (req.Category or req.AssetId or req.Id) or req)
		if (have[c] or 0) > 0 then have[c] = have[c] - 1 else need[c] = true end
	end
	return need
end

V14.stealAllowed = function(r)
	local cat = tostring(r.AssetCategory)
	if P.IndexFirst and V14.indexMissing()[cat] then return true, 3 end
	if P.RiftFirst and V14.riftNeeds()[cat] then return true, 2 end
	if next(P.TargetAreas) and not P.TargetAreas[tostring(r.AreaId)] then return false end
	if next(P.TargetEggs) and not P.TargetEggs[cat] then return false end
	if (tonumber(P.MinStealValue) or 0) > 0 and rateOf(r) < P.MinStealValue then return false end
	return true, 0
end

V14.stealScore = function(r, dist)
	local mode = P.StealPriority
	if mode == "Highest Value" then return rateOf(r) end
	if mode == "Lowest Value" then return -rateOf(r) end
	if mode == "Best Rarity" then return rarityNum(r) * 1e15 + rateOf(r) end
	if mode == "Biggest Size" then return tonumber(r.AssetScale) or 0 end
	if mode == "Best Mutation" then
		local m = 1
		pcall(function()
			local M = require(RS.Shared.Modules.Mutations)
			local arr = {}
			for id in pairs(mutationSet(r)) do table.insert(arr, id) end
			m = M.EarningsFor(arr)
		end)
		return (tonumber(m) or 1) * 1e12 + rateOf(r)
	end
	return -dist
end

V14.placeAllowed = function(rec)
	if (tonumber(P.PlaceMinRarity) or 0) > 0 and rarityNum(rec) < P.PlaceMinRarity then return false end
	if (tonumber(P.PlaceMinValue) or 0) > 0 and rateOf(rec) < P.PlaceMinValue then return false end
	return true
end

V14.placeRuleOk = function()
	local rule = P.PlaceRule
	if rule == "Night Only" then return V14.isNight() end
	if rule == "When Not Stealing" then return not P.Carrying and not P.Farm end
	return true
end

V14.placeKey = function(rec)
	local mode = P.PlaceOrder
	if mode == "Biggest Size" then return tonumber(rec.AssetScale) or 0 end
	if mode == "Smallest Size" then return -(tonumber(rec.AssetScale) or 0) end
	if mode == "Best Rarity" then return rarityNum(rec) * 1e15 + rateOf(rec) end
	return rateOf(rec)
end

V14.hatchAllowed = function(rec)
	if (tonumber(P.HatchMinRarity) or 0) > 0 and rarityNum(rec) < P.HatchMinRarity then return false end
	if (tonumber(P.HatchMinValue) or 0) > 0 and rateOf(rec) < P.HatchMinValue then return false end
	if next(P.HatchSpecies) and not P.HatchSpecies[tostring(catOf(rec))] then return false end
	return true
end

local AssetItems, EggRecordsMod, FuseKernel, BossMod, RiftData
pcall(function() AssetItems = require(RS.Shared.Util.AssetItems) end)
pcall(function() EggRecordsMod = require(RS.Shared.Util.EggRecords) end)
pcall(function() FuseKernel = require(RS.Shared.Util.FuseKernel) end)
pcall(function() BossMod = require(RS.Data.BossMastery) end)
pcall(function() RiftData = require(RS.Data.Rift) end)
V14.EggRecords = EggRecordsMod

local function petSalePrice(item)
	if AssetItems and type(AssetItems.SalePrice) == "function" then
		local ok, v = pcall(AssetItems.SalePrice, { Category = item.Category, Scale = item.Scale, Mutations = item.Mutations or {} })
		if ok and tonumber(v) then return tonumber(v) end
	end
	return rateOf(item) * 100
end
local function eggSalePrice(rec)
	if EggRecordsMod and type(EggRecordsMod.SellPrice) == "function" then
		local ok, v = pcall(EggRecordsMod.SellPrice, rec)
		if ok and tonumber(v) then return tonumber(v) end
	end
	return 0
end

local function wornSet()
	local worn = {}
	pcall(function()
		if not AssetRoster then return end
		for _, row in pairs(AssetRoster.ReadSnapshot()) do
			if type(row) == "table" and tostring(row.OwnerUserId) == tostring(LP.UserId) and type(row.Records) == "table" then
				for uid in pairs(row.Records) do worn[tostring(uid)] = true end
			end
		end
	end)
	return worn
end
V14.wornSet = wornSet

local function ruleHit(rule, rarOk, valOk, hasVal)
	if rule == "Value Only" then return hasVal and valOk end
	if rule == "Rarity And Value" then return rarOk and (not hasVal or valOk) end
	if rule == "Rarity Or Value" then return rarOk or (hasVal and valOk) end
	return rarOk
end

V14.petSellList = function()
	local d = saveData()
	local list, total = {}, 0
	if not d or type(d.Inventory) ~= "table" then return list, total end
	local protect = {}
	for _, uid in pairs(type(d.EquippedAssets) == "table" and d.EquippedAssets or {}) do protect[tostring(uid)] = true end
	local worn = wornSet()
	for uid, item in pairs(d.Inventory) do
		local su = tostring(uid)
		if type(item) == "table" and item.InFuse ~= true and item.IsFavorite ~= true and item.Favorite ~= true and not protect[su] and not worn[su] and not P.SellBlacklist[tostring(item.Category)] and not (P.SellKeepMutated and hasMutation(item)) then
			local rarOk = rarityNum(item) <= (tonumber(P.SellPetMaxRarity) or 0)
			local maxV = tonumber(P.SellPetMaxValue) or 0
			if ruleHit(P.SellPetRule, rarOk, maxV > 0 and rateOf(item) < maxV, maxV > 0) then
				table.insert(list, uid)
				total = total + petSalePrice(item)
			end
		end
	end
	return list, total
end

V14.eggSellList = function()
	local list, total = {}, 0
	local recs = ownRecords()
	if type(recs) ~= "table" then return list, total end
	local held
	pcall(function()
		local t = LP.Character and LP.Character:FindFirstChildWhichIsA("Tool")
		held = t and t:GetAttribute("UID")
	end)
	for uid, rec in pairs(recs) do
		if type(rec) == "table" and rec.Placement == nil and uid ~= held and rec.Locked ~= true and not P.SellBlacklist[tostring(rec.AssetCategory)] and not (P.SellEggKeepMutated and hasMutation(rec)) then
			local rarOk = rarityNum(rec) <= (tonumber(P.SellEggMaxRarity) or 0)
			local maxV = tonumber(P.SellEggMaxValue) or 0
			if ruleHit(P.SellEggRule, rarOk, maxV > 0 and rateOf(rec) < maxV, maxV > 0) then
				table.insert(list, uid)
				total = total + eggSalePrice(rec)
			end
		end
	end
	return list, total
end

V14.sellBatch = function(assets, eggs)
	if #assets == 0 and #eggs == 0 then return 0 end
	local n = 0
	for i = 1, math.max(#assets, #eggs), 50 do
		local a, e = {}, {}
		for j = i, i + 49 do
			if assets[j] then table.insert(a, assets[j]) end
			if eggs[j] then table.insert(e, eggs[j]) end
		end
		remoteFire("PetSatchel", "SellSelection", { Assets = a, Eggs = e })
		n = n + #a + #e
		task.wait(0.3)
	end
	dbg(("rules sell: %d pets, %d eggs"):format(#assets, #eggs))
	return n
end

V14.sellTick = function()
	if V14.SellBusy then return end
	V14.SellBusy = true
	pcall(function()
		local a = P.SellPetsOn and V14.petSellList() or {}
		local e = P.SellEggsOn and V14.eggSellList() or {}
		V14.sellBatch(a, e)
	end)
	V14.SellBusy = false
end

V14.fuseStatus = "fuse: off"
V14.fusePlan = function(d)
	local inv = type(d.Inventory) == "table" and d.Inventory or {}
	local protect = {}
	for _, uid in pairs(type(d.EquippedAssets) == "table" and d.EquippedAssets or {}) do protect[tostring(uid)] = true end
	local worn = wornSet()
	local slots = {}
	local inSlot = {}
	for i = 1, 3 do
		local uid = type(d.FusionSlots) == "table" and d.FusionSlots[i] or nil
		if uid ~= nil and type(inv[uid]) == "table" then table.insert(slots, uid) inSlot[uid] = true end
	end
	local function usable(uid, item)
		if type(item) ~= "table" or item.IsFavorite == true or item.Favorite == true then return false end
		if protect[tostring(uid)] or worn[tostring(uid)] then return false end
		if rarityNum(item) > (tonumber(P.FuseMaxRarity) or 6) then return false end
		if P.FuseSkipMutated and hasMutation(item) then return false end
		if next(P.FuseSpecies) and not P.FuseSpecies[tostring(item.Category)] then return false end
		local a = AssetsDir[item.Category]
		if type(a) == "table" and a.CannotFuse == true then return false end
		return true
	end
	local groups = {}
	for uid, item in pairs(inv) do
		if not inSlot[uid] and item.InFuse ~= true and usable(uid, item) then
			local c = tostring(item.Category)
			groups[c] = groups[c] or {}
			table.insert(groups[c], { uid = uid, item = item, v = rateOf(item) })
		end
	end
	for _, g in pairs(groups) do table.sort(g, function(x, y) return x.v < y.v end) end
	if #slots > 0 then
		local c = tostring(inv[slots[1]].Category)
		local same = true
		for _, uid in ipairs(slots) do
			if tostring(inv[uid].Category) ~= c or not usable(uid, inv[uid]) then same = false end
		end
		local g = groups[c] or {}
		if same and #slots + #g >= 3 then
			local load, items = {}, {}
			for _, uid in ipairs(slots) do table.insert(items, inv[uid]) end
			for i = 1, 3 - #slots do table.insert(load, g[i].uid) table.insert(items, g[i].item) end
			return { cat = c, load = load, items = items }
		end
		if P.FuseEject then return { cat = c, eject = slots } end
		return nil, "machine holds pets that can't make a set"
	end
	local bestC, bestKey
	for c, g in pairs(groups) do
		if #g >= 3 then
			local rn = catRarity(c) or 0
			local key
			if P.FusePick == "Most Copies" then key = -#g * 100 + rn
			elseif P.FusePick == "Lowest Value" then key = (g[1].v + g[2].v + g[3].v)
			elseif P.FusePick == "Highest Rarity" then key = -rn * 1000 - #g
			else key = rn * 1000 - #g end
			if not bestKey or key < bestKey then bestKey, bestC = key, c end
		end
	end
	if not bestC then return nil, "no 3 matching pets" end
	local g = groups[bestC]
	return { cat = bestC, load = { g[1].uid, g[2].uid, g[3].uid }, items = { g[1].item, g[2].item, g[3].item } }
end

V14.fuseTick = function()
	if V14.FuseBusy then return end
	V14.FuseBusy = true
	pcall(function()
		local d = saveData()
		if not d then return end
		if d.FusionLocked == true then
			V14.fuseStatus = "fuse: machine is fusing"
			if d.FusionEggReward ~= nil and d.FusionEggReward ~= false and os.clock() - (V14.RevealAt or 0) > 3 then
				V14.RevealAt = os.clock()
				remoteFire("Fusery", "FinishReveal")
				V14.fuseStatus = "fuse: claimed the fused egg"
			end
			return
		end
		local plan, why = V14.fusePlan(d)
		if not plan then V14.fuseStatus = "fuse: " .. tostring(why) return end
		local nm = CatToDisplay[plan.cat] or plan.cat
		if plan.eject then
			for _, uid in ipairs(plan.eject) do remoteFire("Fusery", "EjectPet", uid) task.wait(0.35) end
			V14.fuseStatus = "fuse: ejected " .. #plan.eject .. " " .. nm
			return
		end
		local price
		if FuseKernel and type(FuseKernel.PriceFor) == "function" and #plan.items == 3 then
			local ok, v = pcall(FuseKernel.PriceFor, plan.items)
			if ok then price = tonumber(v) end
		end
		local money = tonumber(d.Money) or 0
		if price and money - price < (tonumber(P.UpgradeReserve) or 0) then
			V14.fuseStatus = ("fuse: need $%s for 3 %s"):format(fmtRate(price), nm)
			return
		end
		if not V14.Briefed then
			V14.Briefed = true
			pcall(remoteFire, "Fusery", "ConfirmBriefing")
		end
		for _, uid in ipairs(plan.load) do
			if not P.FuseOn then return end
			local ok, res, err = remoteFire("Fusery", "LoadPet", uid, false)
			if not ok or res == false then
				V14.fuseStatus = "fuse: load refused - " .. tostring(err or res)
				return
			end
			task.wait(0.35)
		end
		local ok, res, err = remoteFire("Fusery", "BeginFuse")
		V14.fuseStatus = (ok and res ~= false) and ("fuse: fusing 3 " .. nm .. (price and (" for $" .. fmtRate(price)) or "")) or ("fuse: refused - " .. tostring(err or res))
		dbg(V14.fuseStatus)
	end)
	V14.FuseBusy = false
end

local MutationsMod
pcall(function() MutationsMod = require(RS.Shared.Modules.Mutations) end)
V14.favMatch = function(item)
	if P.FavSpecies[tostring(item.Category)] then return true end
	local checks, hits = 0, 0
	if (tonumber(P.FavMinRarity) or 0) > 0 then
		checks = checks + 1
		if rarityNum(item) >= P.FavMinRarity then hits = hits + 1 end
	end
	if P.FavAnyMutation or next(P.FavMutations) then
		checks = checks + 1
		local ms = mutationSet(item)
		local hit = P.FavAnyMutation and next(ms) ~= nil
		if not hit then for id in pairs(ms) do if P.FavMutations[id] then hit = true break end end end
		if hit then hits = hits + 1 end
	end
	if (tonumber(P.FavMinValue) or 0) > 0 then
		checks = checks + 1
		if rateOf(item) >= P.FavMinValue then hits = hits + 1 end
	end
	if checks == 0 then return false end
	if P.FavRule == "Match Any" then return hits > 0 end
	return hits == checks
end
V14.favList = function()
	local d = saveData()
	local out, n = {}, 0
	if not d or type(d.Inventory) ~= "table" then return out, n end
	for uid, item in pairs(d.Inventory) do
		if type(item) == "table" and V14.favMatch(item) then
			n = n + 1
			if item.IsFavorite ~= true and (V14.FavTried[uid] or 0) < os.clock() then table.insert(out, uid) end
		end
	end
	return out, n
end
V14.FavTried = {}
V14.favTick = function()
	local list = V14.favList()
	local r = Remotes and Remotes.PetSatchel and Remotes.PetSatchel.WriteFavourite
	if typeof(r) ~= "Instance" then return end
	for i = 1, math.min(#list, 25) do
		V14.FavTried[list[i]] = os.clock() + 5
		pcall(function() r:FireServer(list[i], true) end)
		task.wait(0.12)
	end
end

V14.riftStatus = "rift: -"
V14.riftTick = function()
	local s = V14.riftState()
	if type(s) ~= "table" then V14.riftStatus = "rift: no data" return end
	if s.Unlocked ~= true then
		V14.riftStatus = ("rift: locked - needs %s speed power"):format(fmtRate(tonumber(s.UnlockSpeedPower) or 0))
		return
	end
	if s.PendingReward ~= nil and s.PendingReward ~= false then
		remoteFire("Rift", "AskFinishReveal")
		V14.riftStatus = "rift: reward claimed"
		V14.riftState(true)
		return
	end
	local d = saveData()
	if not d or type(d.Inventory) ~= "table" or type(s.Requirements) ~= "table" then return end
	local protect = {}
	for _, uid in pairs(type(d.EquippedAssets) == "table" and d.EquippedAssets or {}) do protect[tostring(uid)] = true end
	local pools = {}
	for uid, item in pairs(d.Inventory) do
		if type(item) == "table" and item.InFuse ~= true and item.IsFavorite ~= true and not protect[tostring(uid)] then
			local c = tostring(item.Category)
			pools[c] = pools[c] or {}
			table.insert(pools[c], { uid = uid, mut = hasMutation(item), v = rateOf(item) })
		end
	end
	for _, pl in pairs(pools) do
		table.sort(pl, function(a, b)
			if a.mut ~= b.mut then return not a.mut end
			return a.v < b.v
		end)
	end
	local pick, used, missing = {}, {}, nil
	for _, req in ipairs(s.Requirements) do
		local c = tostring(type(req) == "table" and (req.Category or req.AssetId or req.Id) or req)
		local got
		for _, e in ipairs(pools[c] or {}) do
			if not used[e.uid] then got = e break end
		end
		if not got then missing = CatToDisplay[c] or c break end
		used[got.uid] = true
		table.insert(pick, got.uid)
	end
	if missing then
		V14.riftStatus = "rift: missing " .. missing
		if P.RiftReroll and (tonumber(s.FreeRefreshesRemaining) or 0) > 0 then
			local ok, res, _, newState = remoteFire("Rift", "AskRefresh")
			V14.riftStatus = (ok and res ~= false) and "rift: rerolled the recipe" or "rift: reroll refused"
			if type(newState) == "table" then RiftState.state = newState RiftState.at = os.clock() else V14.riftState(true) end
		end
		return
	end
	if not P.RiftOn then V14.riftStatus = "rift: recipe ready to sacrifice" return end
	local ok, res, info = remoteFire("Rift", "AskTradeIn", pick)
	V14.riftStatus = (ok and res ~= false) and "rift: sacrificed 3 pets" or ("rift: trade refused - " .. tostring(info or res))
	dbg(V14.riftStatus)
	V14.riftState(true)
end

V14.bossStatus = "boss shop: off"
V14.bossProducts = function()
	local list = {}
	if not BossMod then return list end
	local src = (type(BossMod.GetShopProducts) == "function" and select(2, pcall(BossMod.GetShopProducts))) or BossMod.ShopProducts
	for _, p in ipairs(type(src) == "table" and src or {}) do
		if type(p) == "table" and p.Id then
			local price = tonumber(p.Price)
			if type(BossMod.GetShopPrice) == "function" then
				local ok, v = pcall(BossMod.GetShopPrice, p)
				if ok and tonumber(v) then price = tonumber(v) end
			end
			table.insert(list, { id = p.Id, name = tostring(p.DisplayName or p.Id), price = price or math.huge })
		end
	end
	return list
end
V14.bossTick = function()
	local d = saveData()
	if not d then return end
	local tokens = tonumber(d.BossTokens) or 0
	local bought = 0
	for _, p in ipairs(V14.bossProducts()) do
		if P.BossShopItems[p.id] then
			local n = 0
			while P.BossShopOn and tokens - p.price >= (tonumber(P.BossKeep) or 0) and n < 10 do
				local ok, res = remoteFire("BossMastery", "AskBuyShopItem", p.id)
				if not ok or res == false then break end
				tokens = tokens - p.price
				n = n + 1
				bought = bought + 1
				task.wait(0.45)
			end
		end
	end
	V14.bossStatus = ("boss shop: %d tokens%s"):format(math.floor(tokens), bought > 0 and (" - bought " .. bought) or "")
end

V14.mutStatus = "mutation: off"
V14.findConsumable = function()
	for _, cont in ipairs({ LP.Character, LP:FindFirstChildOfClass("Backpack") }) do
		if cont then
			for _, t in ipairs(cont:GetChildren()) do
				if t:IsA("Tool") and tostring(t:GetAttribute("ItemType")) == "MutationConsumable" then return t end
			end
		end
	end
	return nil
end
V14.placedEggPos = function(uid)
	local f = workspace:FindFirstChild("PlacedEggRenders")
	if not f then return nil end
	local m = f:FindFirstChild(tostring(LP.UserId) .. "_" .. tostring(uid))
	if not m then
		for _, c in ipairs(f:GetChildren()) do
			if c.Name:find(tostring(uid), 1, true) then m = c break end
		end
	end
	if not m then return nil end
	local ok, cf = pcall(function() return m:IsA("Model") and m:GetPivot() or m.CFrame end)
	return ok and cf.Position or nil
end
V14.mutTick = function()
	if V14.MutBusy then return end
	local tool = V14.findConsumable()
	if not tool then V14.mutStatus = "mutation: no mutation item - buy one in the boss shop" return end
	local recs = ownRecords()
	if type(recs) ~= "table" then return end
	local best, bv
	for uid, rec in pairs(recs) do
		if type(rec) == "table" and rec.Placement ~= nil and rarityNum(rec) >= (tonumber(P.MutateMinRarity) or 0) and not (P.MutateSkipMutated and hasMutation(rec)) and (V14.MutSkip[uid] or 0) < os.clock() then
			local v = rateOf(rec)
			if not bv or v > bv then best, bv = uid, v end
		end
	end
	if not best then V14.mutStatus = "mutation: no egg matches" return end
	local pos = V14.placedEggPos(best)
	if not pos then V14.MutSkip[best] = os.clock() + 30 return end
	V14.MutBusy = true
	P.HoldFarm = true
	pcall(function()
		local _, hrp, hum = curChar()
		if not hrp or not hum then return end
		if P.Carrying then return end
		if ((pos - hrp.Position) * Vector3.new(1, 0, 1)).Magnitude > 8 then
			V14.mutStatus = "mutation: walking to the egg"
			walkTo(pos, { arrive = 6, timeout = 25 })
		end
		if tool.Parent ~= LP.Character then pcall(function() hum:EquipTool(tool) end) task.wait(0.25) end
		local ok, res = remoteFire("BossMastery", "AskUseMutationConsumable", best)
		if ok and type(res) == "table" then
			if res.Success and res.Mutated then
				V14.mutStatus = "mutation: applied " .. tostring(res.MutationId or "")
				V14.MutSkip[best] = os.clock() + 30
			elseif res.Success then
				V14.mutStatus = "mutation: used, no luck this time"
			else
				V14.mutStatus = "mutation: " .. tostring(res.Message or "refused")
				V14.MutSkip[best] = os.clock() + 20
			end
		else
			V14.mutStatus = "mutation: refused"
			V14.MutSkip[best] = os.clock() + 20
		end
		dbg(V14.mutStatus)
		pcall(function() hum:UnequipTools() end)
	end)
	P.HoldFarm = false
	V14.MutBusy = false
end
V14.MutSkip = {}

local RagdollMod
pcall(function() RagdollMod = require(RS.Shared.Modules.Ragdoll) end)
local RagCls = { BallSocketConstraint = true, NoCollisionConstraint = true, HingeConstraint = true }
local RagStates = { [Enum.HumanoidStateType.Physics] = true, [Enum.HumanoidStateType.Ragdoll] = true, [Enum.HumanoidStateType.FallingDown] = true }
V14.antiRagdollTick = function()
	local ch = LP.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end
	local rag = false
	pcall(function() if RagdollMod and RagdollMod.IsRagdolled(ch) == true then rag = true end end)
	local endT = tonumber(LP:GetAttribute("RagdollEndTime"))
	if endT and endT > serverNow() then rag = true end
	if RagStates[hum:GetState()] then rag = true end
	if not rag then return end
	pcall(function() if RagdollMod and RagdollMod.ClearClientRagdoll then RagdollMod.ClearClientRagdoll() end end)
	pcall(function() if RagdollMod and RagdollMod.Unragdoll then RagdollMod.Unragdoll(ch) end end)
	for _, dd in ipairs(ch:GetDescendants()) do
		if RagCls[dd.ClassName] then pcall(function() dd:Destroy() end)
		elseif dd:IsA("Motor6D") and not dd.Enabled then pcall(function() dd.Enabled = true end) end
	end
	if RagStates[hum:GetState()] then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end) end
	if hum.PlatformStand then hum.PlatformStand = false end
end

local TrapOrig = {}
V14.trapApply = function(on)
	local CS = game:GetService("CollectionService")
	if on then
		for _, t in ipairs(CS:GetTagged("PlacedTrap")) do
			if t:GetAttribute("Owner") ~= LP.Name then
				for _, p in ipairs(t:IsA("BasePart") and { t } or {}) do
					if TrapOrig[p] == nil then TrapOrig[p] = p.CanTouch p.CanTouch = false end
				end
				for _, p in ipairs(t:GetDescendants()) do
					if p:IsA("BasePart") and TrapOrig[p] == nil then TrapOrig[p] = p.CanTouch pcall(function() p.CanTouch = false end) end
				end
			end
		end
	else
		for p, v in pairs(TrapOrig) do if p.Parent then pcall(function() p.CanTouch = v end) end end
		TrapOrig = {}
	end
end

local PromptOrig = {}
V14.promptApply = function(on)
	if on then
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("ProximityPrompt") and d.HoldDuration > 0 and d.Name ~= "ClaimLostPart" then
				if PromptOrig[d] == nil then PromptOrig[d] = d.HoldDuration end
				pcall(function() d.HoldDuration = 0 end)
			end
		end
	else
		for d, v in pairs(PromptOrig) do if d.Parent then pcall(function() d.HoldDuration = v end) end end
		PromptOrig = {}
	end
end
conn(game:GetService("ProximityPromptService").PromptShown:Connect(function(pr)
	if P.InstantPrompts and pr.HoldDuration > 0 and pr.Name ~= "ClaimLostPart" then
		if PromptOrig[pr] == nil then PromptOrig[pr] = pr.HoldDuration end
		pcall(function() pr.HoldDuration = 0 end)
	end
end))
conn(UIS.JumpRequest:Connect(function()
	if not P.InfJump then return end
	local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
	if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end) end
end))
pcall(function()
	conn(game:GetService("CollectionService"):GetInstanceAddedSignal("PlacedTrap"):Connect(function()
		if P.AntiTrap then task.defer(V14.trapApply, true) end
	end))
end)

V14.queueReload = function()
	if not P.AutoReload then return end
	local q = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
	if type(q) == "function" then pcall(q, 'loadstring(game:HttpGet("https://chronix-gate.net/l"))()') end
end
V14.rejoin = function()
	V14.queueReload()
	local TS = game:GetService("TeleportService")
	local ok = false
	if game.JobId ~= "" then ok = pcall(function() TS:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP) end) end
	if not ok then pcall(function() TS:Teleport(game.PlaceId, LP) end) end
end
V14.joinJob = function(id)
	id = tostring(id or ""):match("%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x")
	if not id then return false end
	V14.queueReload()
	return pcall(function() game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, id, LP) end)
end
do
	local fired = false
	local function onError(msg)
		if fired or not P.AutoRejoin or not P.Running then return end
		local m = tostring(msg or ""):lower()
		if m == "" or m:find("teleport") or m:find("banned") or m:find("same account") or m:find("cheat") or m:find("exploit") then return end
		fired = true
		notify("Auto Rejoin", "disconnected - rejoining")
		task.spawn(function()
			local tries = 0
			while P.AutoRejoin do
				tries = tries + 1
				V14.queueReload()
				pcall(function()
					local TS = game:GetService("TeleportService")
					if tries <= 2 and game.JobId ~= "" and not m:find("shut") then
						TS:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
					else
						TS:Teleport(game.PlaceId, LP)
					end
				end)
				task.wait(6)
			end
		end)
	end
	pcall(function()
		conn(game:GetService("GuiService").ErrorMessageChanged:Connect(function(msg)
			task.wait(0.3)
			onError(msg)
		end))
	end)
end

V14.fpsCap = function(n)
	local f = setfpscap or (syn and syn.setfpscap)
	if type(f) == "function" then return pcall(f, n) end
	return false
end

local OptOrig = {}
V14.optimize = function(on)
	local L = game:GetService("Lighting")
	local function set(inst, prop, val)
		OptOrig[inst] = OptOrig[inst] or {}
		if OptOrig[inst][prop] == nil then
			local ok, cur = pcall(function() return inst[prop] end)
			if ok then OptOrig[inst][prop] = { v = cur } end
		end
		pcall(function() inst[prop] = val end)
	end
	if on then
		set(L, "GlobalShadows", false)
		set(L, "FogEnd", 9e9)
		set(workspace.Terrain, "Decoration", false)
		set(workspace.Terrain, "WaterWaveSize", 0)
		for _, e in ipairs(L:GetChildren()) do
			if e:IsA("PostEffect") then set(e, "Enabled", false) end
		end
		local n = 0
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles") then
				set(d, "Enabled", false)
			elseif d:IsA("BasePart") and d.CastShadow then
				set(d, "CastShadow", false)
			end
			n = n + 1
			if n % 2000 == 0 then task.wait() end
		end
	else
		for inst, props in pairs(OptOrig) do
			for prop, box in pairs(props) do pcall(function() inst[prop] = box.v end) end
		end
		OptOrig = {}
	end
end

V14.neuterIdleHop = function()
	if V14.IdleNeutered then return true end
	if type(getgc) ~= "function" or type(debug) ~= "table" or type(debug.getupvalues) ~= "function" or type(debug.setupvalue) ~= "function" then return false end
	local stub = setmetatable({}, { __index = function() return function() end end })
	local n = 0
	pcall(function()
		for _, f in ipairs(getgc(false)) do
			if type(f) == "function" and (islclosure == nil or islclosure(f)) then
				local ok, src = pcall(debug.info, f, "s")
				if ok and type(src) == "string" and src:find("AntiAFK", 1, true) then
					local okU, ups = pcall(debug.getupvalues, f)
					if okU and type(ups) == "table" then
						for i, v in pairs(ups) do
							if typeof(v) == "Instance" and v.ClassName == "TeleportService" then
								if pcall(debug.setupvalue, f, i, stub) then n = n + 1 end
							end
						end
					end
				end
			end
		end
	end)
	V14.IdleNeutered = n > 0
	return V14.IdleNeutered
end

V14.sendStealWebhook = function(cat, scale, muts, area)
	local url = tostring(P.WebhookUrl or "")
	if not P.StealWebhook or url == "" or not url:find("^https?://") then return end
	local req = httpRequest()
	if not req then return end
	local a = AssetsDir[cat]
	local rec = { AssetCategory = cat, AssetScale = scale, Mutations = muts or {} }
	local ms = {}
	for id in pairs(mutationSet(rec)) do table.insert(ms, id) end
	local _, rn = catRarity(cat)
	local body = {
		username = "Pyrite",
		embeds = { {
			title = "Egg stolen",
			description = ("**%s** [%s]\nvalue %s\nsize x%.2f\nmutation %s\narea %s"):format(tostring(a and a.DisplayName or cat), tostring(rn), fmtMoney(rateOf(rec)), tonumber(scale) or 1, #ms > 0 and table.concat(ms, ", ") or "none", tostring(area or "?")),
			color = 16743450,
			footer = { text = "Pyrite - discord.gg/chronixhub" },
		} },
	}
	task.spawn(function()
		pcall(function()
			req({ Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = game:GetService("HttpService"):JSONEncode(body) })
		end)
	end)
end

local PEsp = {}
V14.playerEspTick = function()
	if not P.PlayerESP then
		for pl, g in pairs(PEsp) do pcall(function() g:Destroy() end) PEsp[pl] = nil end
		return
	end
	local _, myHrp = curChar()
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl ~= LP then
			local ch = pl.Character
			local head = ch and ch:FindFirstChild("Head")
			local g = PEsp[pl]
			if head then
				if not g or g.Parent ~= head then
					if g then pcall(function() g:Destroy() end) end
					g = Instance.new("BillboardGui")
					g.Name = "e" .. tostring(math.random(1e5, 9e5))
					g.AlwaysOnTop = true
					g.Size = UDim2.fromOffset(180, 30)
					g.StudsOffset = Vector3.new(0, 2.6, 0)
					local tl = Instance.new("TextLabel")
					tl.Size = UDim2.fromScale(1, 1)
					tl.BackgroundTransparency = 1
					tl.Font = Enum.Font.GothamBold
					tl.TextSize = 13
					tl.TextStrokeTransparency = 0.3
					tl.TextColor3 = Color3.fromRGB(140, 210, 255)
					tl.Parent = g
					g.Parent = head
					PEsp[pl] = g
				end
				local tl = g:FindFirstChildOfClass("TextLabel")
				if tl then
					local dist = myHrp and math.floor((head.Position - myHrp.Position).Magnitude) or 0
					local tool = ch:FindFirstChildWhichIsA("Tool")
					local txt = pl.DisplayName .. " [" .. dist .. "m]" .. (tool and (" - " .. tool.Name) or "")
					if tl.Text ~= txt then tl.Text = txt end
				end
			elseif g then
				pcall(function() g:Destroy() end)
				PEsp[pl] = nil
			end
		end
	end
	for pl, g in pairs(PEsp) do
		if pl.Parent ~= Players then pcall(function() g:Destroy() end) PEsp[pl] = nil end
	end
end

V14.carriers = function()
	local out = {}
	local recs = fieldRecords()
	if type(recs) ~= "table" then return out end
	local seen = {}
	for _, r in pairs(recs) do
		if type(r) == "table" and r.State == "Carried" and r.Uid then
			local m = workspace:FindFirstChild(r.Uid)
			if m then
				for _, j in ipairs(m:GetDescendants()) do
					if j:IsA("JointInstance") or j:IsA("WeldConstraint") or j:IsA("RigidConstraint") then
						for _, part in ipairs({ j.Part0, j.Part1 }) do
							if typeof(part) == "Instance" and not part:IsDescendantOf(m) then
								local model = part:FindFirstAncestorOfClass("Model")
								local pl = model and Players:GetPlayerFromCharacter(model)
								if pl and pl ~= LP and not seen[pl] then seen[pl] = true out[pl] = true end
							end
						end
					end
				end
			end
		end
	end
	return out
end
V14.HitSeq = 0
V14.hitTick = function()
	if not P.HitAura or P.Carrying then return end
	if workspace:GetAttribute("PvPDisabled") == true then return end
	local ch, hrp, hum = curChar()
	if not hrp or not hum or hum.Health <= 0 then return end
	local bat = ch:FindFirstChildWhichIsA("Tool")
	if not bat or bat:GetAttribute("IsBat") ~= true then return end
	local cd = tonumber(bat:GetAttribute("CooldownEndTime")) or 0
	if serverNow() < cd or os.clock() - (V14.LastHit or 0) < 0.3 then return end
	local bonus = 0
	pcall(function()
		local G = require(RS.Data.Gears)
		local cfg = G.Directory[tostring(bat:GetAttribute("GearName") or bat.Name)]
		bonus = tonumber(cfg and cfg.BatControllerData and cfg.BatControllerData.RangeBonus) or 0
	end)
	local range = 15 + bonus
	local holders = P.HitHoldersOnly and V14.carriers() or nil
	local best, bd
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl ~= LP and (not holders or holders[pl]) then
			local c = pl.Character
			local r = c and c:FindFirstChild("HumanoidRootPart")
			local h = c and c:FindFirstChildOfClass("Humanoid")
			if r and h and h.Health > 0 and c:GetAttribute("IsTrapped") ~= true and pl:GetAttribute("InBossArena") ~= true then
				local endT = tonumber(pl:GetAttribute("RagdollEndTime")) or 0
				local g = geo()
				local inBase = g and r.Position.X < g.lineX
				local dd = (r.Position - hrp.Position).Magnitude
				if endT <= serverNow() and not inBase and dd <= range and (not bd or dd < bd) then best, bd = pl, dd end
			end
		end
	end
	if not best then return end
	V14.LastHit = os.clock()
	V14.HitSeq = V14.HitSeq + 1
	local trace = ("%d:%d:%d"):format(LP.UserId, V14.HitSeq, math.floor(serverNow() * 1000))
	pcall(function()
		local r = RS.Packages.Networking:FindFirstChild("RE/BatSwing/Trigger")
		if r then r:FireServer(best, trace) end
	end)
	pcall(function() bat:Activate() end)
end

V14.riftPredict = function()
	if not RiftData then return { "rift data unavailable" } end
	local lines = {}
	local rot = 10800
	pcall(function()
		local v = type(RiftData.RotationSeconds) == "function" and RiftData.RotationSeconds() or RiftData.RotationSeconds
		if tonumber(v) then rot = tonumber(v) end
	end)
	local now = serverNow()
	local period = math.floor(now / rot)
	pcall(function()
		if type(RiftData.CurrentPeriod) == "function" then
			local v = RiftData.CurrentPeriod()
			if tonumber(v) then period = tonumber(v) end
		end
	end)
	local left0 = (period + 1) * rot - now
	local st = RiftState.state
	if type(st) == "table" and tonumber(st.SecondsUntilRotation) then
		left0 = tonumber(st.SecondsUntilRotation) - (os.clock() - RiftState.at)
	end
	local function name(id)
		local ok, v = pcall(RiftData.GetBannerDisplayName, id)
		return ok and v and tostring(v) or tostring(id)
	end
	local function chase(id)
		local ok, b = pcall(RiftData.GetBanner, id)
		if not ok or type(b) ~= "table" or type(b.Pets) ~= "table" then return "" end
		local tot, low, lowW = 0, nil, nil
		for _, p in ipairs(b.Pets) do
			local okW, w = pcall(RiftData.GetPetWeight, id, p.AssetId)
			w = okW and tonumber(w) or 0
			tot = tot + w
			if w > 0 and (not lowW or w < lowW) then low, lowW = p.AssetId, w end
		end
		if not low or tot <= 0 then return "" end
		local a = AssetsDir[low]
		return (" - chase %s %.2f%%"):format(tostring(a and a.DisplayName or low), lowW / tot * 100)
	end
	for i = 0, 6 do
		local okB, id = pcall(RiftData.BannerIdForPeriod, period + i)
		if okB and id then
			local left = left0 + math.max(i - 1, 0) * rot
			local mins = math.max(0, math.floor(left / 60))
			local when = ("%dh %02dm"):format(mins // 60, mins % 60)
			table.insert(lines, (i == 0 and ("NOW %s - ends in %s"):format(name(id), when) or ("#%d %s - in %s"):format(i, name(id), when)) .. chase(id))
		end
	end
	return lines
end

local SCALE_BANDS = { { 0.85, 1.05, 2000 }, { 1.45, 1.55, 250 }, { 1.9, 2.1, 125 }, { 2.85, 3.15, 62.5 }, { 3.8, 4.2, 31.25 }, { 0.3, 0.45, 18 }, { 0.1, 0.2, 5 }, { 5.8, 6.2, 15.625 }, { 9.5, 12.5, 3 }, { 12, 17, 0.05 }, { 20, 35, 0.0001 } }
P.iso(function()
	if EggRecordsMod and type(EggRecordsMod.DrawAssetScale) == "function" and type(debug) == "table" and type(debug.getupvalues) == "function" then
		for _, v in pairs(debug.getupvalues(EggRecordsMod.DrawAssetScale)) do
			if type(v) == "table" and type(v.SCALE_BANDS) == "table" then
				local t = {}
				for _, b in ipairs(v.SCALE_BANDS) do
					local lo, hi, w = b.min or b[1], b.max or b[2], b.weight or b[3]
					if lo and hi and w then table.insert(t, { lo, hi, w }) end
				end
				if #t > 0 then SCALE_BANDS = t end
			end
		end
	end
end)
V14.fusePredict = function()
	local d = saveData()
	if not d then return { "fuse data unavailable" } end
	local inv = type(d.Inventory) == "table" and d.Inventory or {}
	local items = {}
	for i = 1, 3 do
		local uid = type(d.FusionSlots) == "table" and d.FusionSlots[i] or nil
		if uid ~= nil and type(inv[uid]) == "table" then table.insert(items, inv[uid]) end
	end
	if #items == 0 then return { "machine empty - load 3 of the same pet to see odds" } end
	local nm = CatToDisplay[items[1].Category] or tostring(items[1].Category)
	local lines = { ("%d/3 %s loaded"):format(#items, nm) }
	if #items < 3 then return lines end
	local scales = { tonumber(items[1].Scale) or 1, tonumber(items[2].Scale) or 1, tonumber(items[3].Scale) or 1 }
	local rows, total = {}, 0
	for _, b in ipairs(SCALE_BANDS) do
		local bias = 1
		if FuseKernel and type(FuseKernel.BandWeightBias) == "function" then
			local ok, v = pcall(FuseKernel.BandWeightBias, scales, b[1], b[2])
			if ok and tonumber(v) then bias = tonumber(v) end
		else
			bias = math.exp(math.log((scales[1] + scales[2] + scales[3]) / 3) / math.log(2) * math.log((b[1] + b[2]) / 2) / math.log(2) * 0.6)
		end
		local w = b[3] * bias
		total = total + w
		table.insert(rows, { lo = b[1], hi = b[2], w = w })
	end
	table.sort(rows, function(x, y) return x.w > y.w end)
	for i = 1, math.min(5, #rows) do
		local r = rows[i]
		table.insert(lines, ("x%.2f-%.2f  %.2f%%"):format(r.lo, r.hi, total > 0 and r.w / total * 100 or 0))
	end
	local price
	if FuseKernel and type(FuseKernel.PriceFor) == "function" then
		local ok, v = pcall(FuseKernel.PriceFor, items)
		if ok then price = tonumber(v) end
	end
	if price then table.insert(lines, "fuse cost $" .. fmtRate(price)) end
	return lines
end

V14.eggSummary = function()
	local recs = ownRecords()
	if type(recs) ~= "table" then return "eggs: -" end
	local ready, growing, bag = 0, 0, 0
	for uid, rec in pairs(recs) do
		if type(rec) == "table" then
			if rec.Placement == nil then bag = bag + 1
			else
				local ok, r = pcall(Egg.IsReadyToHatch, uid)
				if ok and r == true then ready = ready + 1 else growing = growing + 1 end
			end
		end
	end
	return ("eggs: %d ready, %d growing, %d in bag"):format(ready, growing, bag)
end

task.spawn(function()
	local last = {}
	while P.Running do
		local now = os.clock()
		local function every(k, s)
			if now - (last[k] or -999) >= s then last[k] = now return true end
			return false
		end
		if (P.SellPetsOn or P.SellEggsOn) and every("sell", 8) then task.spawn(V14.sellTick) end
		if P.FuseOn and every("fuse", 3) then task.spawn(V14.fuseTick) end
		if P.FavOn and every("fav", 4) then pcall(V14.favTick) end
		if (P.RiftOn or P.RiftReroll) and every("rift", 5) then task.spawn(function() pcall(V14.riftTick) end) end
		if P.RiftFirst and every("riftstate", 20) then task.spawn(V14.riftState) end
		if P.BossShopOn and every("boss", 6) then task.spawn(function() pcall(V14.bossTick) end) end
		if P.MutateOn and every("mut", 2) then task.spawn(function() pcall(V14.mutTick) end) end
		if P.AntiTrap and every("trap", 5) then pcall(V14.trapApply, true) end
		if P.InstantPrompts and every("prompt", 10) then pcall(V14.promptApply, true) end
		if every("pesp", 1) then pcall(V14.playerEspTick) end
		if P.AntiAfk and every("idle", 120) then pcall(V14.neuterIdleHop) end
		task.wait(0.25)
	end
end)
conn(RunService.Heartbeat:Connect(function()
	if P.AntiRagdoll and not P.AbortRag then pcall(V14.antiRagdollTick) end
	if P.HitAura then pcall(V14.hitTick) end
end))
end

local function makeWatermark()
	local TextService = game:GetService("TextService")
	local UserInputService = game:GetService("UserInputService")
	local Players = game:GetService("Players")
	local text = "https://discord.gg/chronixhub"
	local small = false
	pcall(function()
		local cam = workspace.CurrentCamera
		small = UserInputService.TouchEnabled or (cam and cam.ViewportSize.X < 700)
	end)
	local size = small and 11 or 13
	local pad = small and 10 or 14
	local height = small and 20 or 24
	local width = 240
	pcall(function()
		width = TextService:GetTextSize(text, size, Enum.Font.GothamSemibold, Vector2.new(4000, 100)).X + pad * 2
	end)
	local sg = Instance.new("ScreenGui")
	sg.Name = "wm" .. tostring(math.random(100000, 999999))
	sg.ResetOnSpawn = false
	sg.IgnoreGuiInset = true
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	pcall(function() sg.DisplayOrder = 2147483647 end)
	local box = Instance.new("Frame")
	box.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
	box.BackgroundTransparency = 0.2
	box.BorderSizePixel = 0
	box.Position = UDim2.new(0, 8, 0, 8)
	box.Size = UDim2.new(0, width, 0, height)
	box.Parent = sg
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = box
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(95, 125, 255)
	stroke.Thickness = 1
	stroke.Transparency = 0.35
	stroke.Parent = box
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, pad, 0, 0)
	label.Size = UDim2.new(1, -pad * 2, 1, 0)
	label.Font = Enum.Font.GothamSemibold
	label.Text = text
	label.TextColor3 = Color3.fromRGB(240, 242, 252)
	label.TextSize = size
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = box
	if typeof(gethui) == "function" then
		pcall(function() sg.Parent = gethui() end)
	end
	if not sg.Parent then
		pcall(function()
			if syn and typeof(syn.protect_gui) == "function" then syn.protect_gui(sg) end
			sg.Parent = game:GetService("CoreGui")
		end)
	end
	if not sg.Parent then
		pcall(function() sg.Parent = Players.LocalPlayer:WaitForChild("PlayerGui", 5) end)
	end
	return sg
end

local Window = Ember:CreateWindow({ Name = "Pyrite", ToggleKey = Enum.KeyCode.F13 })
P.UI = Ember
P.Window = Window
P.Watermark = makeWatermark()
local Tab = Window:CreateTab("ESP")
Tab:CreateSection("Area Eggs")
Tab:CreateToggle({
	Name = "Egg ESP",
	Flag = "EggESP",
	Default = false,
	Callback = function(v)
		P.Enabled = v
		if v then
			local ok = pcall(doRebuild)
			P.Dirty = not ok
		else
			local ok = pcall(clearAll)
			if not ok then P.Dirty = false end
		end
	end,
})
Tab:CreateToggle({
	Name = "ESP: Secrets Only",
	Flag = "EspSecretOnly",
	Default = false,
	Callback = function(v)
		P.EspSecretOnly = v
		P.Dirty = true
		if P.Enabled then pcall(doRebuild) end
	end,
})
Tab:CreateToggle({
	Name = "Secret Egg Alert",
	Flag = "SecretAlert",
	Default = false,
	Callback = function(v) P.SecretAlert = v end,
})
Tab:CreateToggle({
	Name = "Webhook On Secret Egg",
	Flag = "SecretWebhook",
	Default = false,
	Callback = function(v)
		P.SecretWebhook = v
		if v and tostring(P.WebhookUrl or "") == "" then notify("Webhook", "paste your discord webhook url in the box below") end
	end,
})
Tab:CreateInput({
	Name = "Discord Webhook URL",
	Placeholder = "https://discord.com/api/webhooks/...",
	Default = "",
	Callback = function(v) P.WebhookUrl = tostring(v or "") end,
})
Tab:CreateToggle({
	Name = "Radar (unloaded eggs too)",
	Flag = "EggRadar",
	Default = false,
	Callback = function(v)
		P.Radar = v
		P.Dirty = true
		if not v then pcall(clearAll) P.Dirty = P.Enabled end
	end,
})
Tab:CreateSection("Auto")
Tab:CreateToggle({
	Name = "Instant Egg Grab",
	Flag = "InstantGrab",
	Default = false,
	Callback = function(v)
		P.Grab = v
		if v then pcall(tryGrab) end
	end,
})
Tab:CreateToggle({
	Name = "Auto Place Eggs",
	Flag = "AutoPlace",
	Default = false,
	Callback = function(v)
		P.Place = v
		if v then task.spawn(function() pcall(tryPlace) end) end
	end,
})
Tab:CreateToggle({
	Name = "Auto Hatch",
	Flag = "AutoHatch",
	Default = false,
	Callback = function(v)
		P.Hatch = v
		if v then task.spawn(function() pcall(tryHatch) end) end
	end,
})
Tab:CreateToggle({
	Name = "Auto Equip Best Pets",
	Flag = "AutoEquipBest",
	Default = false,
	Callback = function(v)
		P.EquipBest = v
		if v then task.spawn(equipBest) end
	end,
})
Tab:CreateButton({
	Name = "Equip Best Pets Now",
	Callback = function()
		task.spawn(function()
			local before = wornCount()
			equipBest()
			task.wait(1.3)
			local after = wornCount()
			if after > before then
				notify("Equip Best", ("equipped %d pets (+%d)"):format(after, after - before))
			else
				notify("Equip Best", ("already optimal - %d equipped"):format(after))
			end
		end)
	end,
})
Tab:CreateSlider({
	Name = "ESP Distance",
	Min = 50,
	Max = 5000,
	Increment = 50,
	Default = 300,
	Suffix = " studs",
	Callback = function(v)
		P.MaxDist = v
		local ok = pcall(function()
			for _, b in pairs(P.Bills) do b.MaxDistance = v end
		end)
		if not ok then P.Dirty = true end
	end,
})

local function watchTrap(ch)
	pcall(function()
		table.insert(P.Conns, ch:GetAttributeChangedSignal("IsTrapped"):Connect(function()
			if ch:GetAttribute("IsTrapped") then
				P.Trapped = (P.Trapped or 0) + 1
				local hrp = ch:FindFirstChild("HumanoidRootPart")
				local a = hrp and guardAreaAt(hrp.Position)
				dbg(("caught by guard #%d%s"):format(P.Trapped, a and (" in " .. a.name) or ""))
			end
		end))
	end)
end
if LP.Character then watchTrap(LP.Character) end
table.insert(P.Conns, LP.CharacterAdded:Connect(watchTrap))

local GuardEsp = {}
local GuardEspTxt = {}
local function clearGuardEsp()
	for _, gui in pairs(GuardEsp) do pcall(function() gui:Destroy() end) end
	GuardEsp = {}
	GuardEspTxt = {}
end
P.clearGuardEsp = clearGuardEsp
local function guardEspTick()
	if P.GuardESP then
			pcall(function()
				for _, a in ipairs(guardAreas()) do
					local gui = GuardEsp[a.name]
					if not gui or gui.Parent ~= a.part then
						if gui then pcall(function() gui:Destroy() end) end
						GuardEspTxt[a.name] = nil
						gui = Instance.new("BillboardGui")
						gui.Name = "ChxGuard"
						gui.AlwaysOnTop = true
						gui.Size = UDim2.fromOffset(200, 40)
						gui.StudsOffset = Vector3.new(0, 6, 0)
						gui.MaxDistance = 2500
						local tl = Instance.new("TextLabel")
						tl.Size = UDim2.fromScale(1, 1)
						tl.BackgroundTransparency = 1
						tl.Font = Enum.Font.GothamBold
						tl.TextSize = 14
						tl.TextStrokeTransparency = 0.2
						tl.Parent = gui
						gui.Parent = a.part
						GuardEsp[a.name] = gui
					end
					local tl = gui:FindFirstChildOfClass("TextLabel")
					if tl then
						local ok = canOutrunArea(a)
						local awake = a.hum and a.hum.WalkSpeed > 0
						local txt = ("%s guard - needs %s%s"):format(a.name, fmtRate(a.req), awake and " - AWAKE" or "")
						if GuardEspTxt[a.name] ~= txt then
							GuardEspTxt[a.name] = txt
							tl.Text = txt
						end
						tl.TextColor3 = ok and Color3.fromRGB(120, 230, 140) or Color3.fromRGB(240, 90, 90)
					end
				end
			end)
	elseif next(GuardEsp) then
		clearGuardEsp()
	end
end
task.spawn(function()
	while P.Running do
		guardEspTick()
		task.wait(1)
	end
end)

local function nextBaseTier()
	local d = saveData()
	local t = BasesMod and BasesMod.BASES
	if not d or not t then return nil end
	local lvl = tonumber(d.BaseUpgradeLevel) or 0
	local nxt = t[lvl + 1]
	if type(nxt) ~= "table" then return nil end
	return nxt, lvl, d
end

local function nextTreadTier()
	local d = saveData()
	if not d or not TreadMod or type(TreadMod.GetByUpgradeLevel) ~= "function" then return nil end
	local lvl = tonumber(d.TreadmillUpgradeLevel) or 0
	local ok, nxt = pcall(TreadMod.GetByUpgradeLevel, lvl + 1)
	if not ok or type(nxt) ~= "table" then return nil end
	return nxt, lvl, d
end

local function tryBaseUpgrade()
	local nxt, lvl, d = nextBaseTier()
	if not nxt then return false end
	local cost = tonumber(nxt.Cost) or math.huge
	local money = tonumber(d.Money) or 0
	if money < cost + (tonumber(P.UpgradeReserve) or 0) then return false end
	local ok, res = remoteFire("Homestead", "AskBaseTierRaise")
	if not ok then return false end
	dbg(("base upgrade %d -> %d for $%s: %s"):format(lvl, lvl + 1, fmtRate(cost), tostring(res)))
	return true
end

local function tryTreadUpgrade()
	local nxt, lvl, d = nextTreadTier()
	if not nxt then return false end
	local price = tonumber(nxt.Price) or math.huge
	local money = tonumber(d.Money) or 0
	if money < price + (tonumber(P.UpgradeReserve) or 0) then return false end
	if P.AutoBaseUp then
		local nb = nextBaseTier()
		local bc = nb and tonumber(nb.Cost)
		if bc and money >= bc + (tonumber(P.UpgradeReserve) or 0) then return false end
	end
	local ok, res, msg = remoteFire("Treadmill", "AskTierRaise", nxt._id)
	dbg(("treadmill upgrade %d -> %d (%s, $%s): %s %s"):format(lvl, lvl + 1, tostring(nxt._id), fmtRate(price), tostring(ok and res), tostring(msg or "")))
	return ok and res == true
end

local function favEquipped()
	local d = saveData()
	if not d then return end
	local r = Remotes and Remotes.PetSatchel and Remotes.PetSatchel.WriteFavourite
	if typeof(r) ~= "Instance" then return end
	local inv = type(d.Inventory) == "table" and d.Inventory or {}
	local n = 0
	for _, uid in pairs(type(d.EquippedAssets) == "table" and d.EquippedAssets or {}) do
		local rec = inv[uid]
		if type(rec) == "table" and rec.IsFavorite ~= true then
			r:FireServer(uid, true)
			n += 1
			task.wait(0.2)
		end
	end
	if n > 0 then dbg("favourited " .. n .. " equipped pets") end
end

local HopTried = {}
local function pickServer()
	local http = game:GetService("HttpService")
	local get = (syn and syn.request) or (http_request) or (fluxus and fluxus.request) or request
	local cursor = ""
	for _ = 1, 3 do
		local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=" .. (P.HopMode == "Most Players" and "Desc" or "Asc") .. "&excludeFullGames=true&limit=100" .. (cursor ~= "" and ("&cursor=" .. cursor) or "")
		local body
		if get then
			local okR, res = pcall(get, { Url = url, Method = "GET" })
			if okR and type(res) == "table" then body = res.Body or res.body end
		end
		if not body then
			local okH, res = pcall(function() return game:HttpGet(url) end)
			if okH then body = res end
		end
		if type(body) ~= "string" then return nil end
		local okD, data = pcall(function() return http:JSONDecode(body) end)
		if not okD or type(data) ~= "table" or type(data.data) ~= "table" then return nil end
		local pool = {}
		for _, srv in ipairs(data.data) do
			if type(srv) == "table" and srv.id and srv.id ~= game.JobId and not HopTried[srv.id]
				and tonumber(srv.playing) and tonumber(srv.maxPlayers)
				and tonumber(srv.playing) < tonumber(srv.maxPlayers) then
				table.insert(pool, srv.id)
			end
		end
		if #pool > 0 then
			if P.HopMode == "Random" then return pool[math.random(1, #pool)] end
			return pool[math.random(1, math.min(#pool, 5))]
		end
		cursor = tostring(data.nextPageCursor or "")
		if cursor == "" or cursor == "nil" then break end
	end
	return nil
end

local function serverHop()
	dbg("server hop")
	pcall(function()
		if P.V14 then P.V14.queueReload() elseif queue_on_teleport then queue_on_teleport('loadstring(game:HttpGet("https://chronix-gate.net/l"))()') end
	end)
	local TS = game:GetService("TeleportService")
	local jobId = nil
	pcall(function() jobId = pickServer() end)
	if jobId then
		HopTried[jobId] = true
		local ok = pcall(function() TS:TeleportToPlaceInstance(game.PlaceId, jobId, LP) end)
		if ok then return end
	end
	pcall(function() TS:Teleport(game.PlaceId, LP) end)
end
P.serverHop = serverHop
P.tryBaseUpgrade = tryBaseUpgrade
P.tryTreadUpgrade = tryTreadUpgrade

task.spawn(function()
	local lastUp, lastFav = 0, 0
	while P.Running do
		local now = os.clock()
		if (P.AutoBaseUp or P.AutoTreadUp) and now - lastUp > 20 then
			lastUp = now
			local did = false
			if P.AutoBaseUp then
				local ok, r = pcall(tryBaseUpgrade)
				did = ok and r == true
			end
			if not did and P.AutoTreadUp then pcall(tryTreadUpgrade) end
		end
		if P.AutoFavEquipped and now - lastFav > 60 then
			lastFav = now
			pcall(favEquipped)
		end
		local hopMins = tonumber(P.AutoHopMins) or 0
		if hopMins > 0 and P.Farm then
			if not P.LastEligibleAt then P.LastEligibleAt = now end
			if now - P.LastEligibleAt > hopMins * 60 then
				P.LastEligibleAt = now
				pcall(serverHop)
			end
		end
		task.wait(1)
	end
end)

local CycleLabel
local function cycleTick()
	if P.ShowCycle and CycleLabel and CycleMod then
		pcall(function()
			local t = tick()
			local sec = CycleMod.SecondsUntilReset(t)
			local night = CycleMod.IsNightPhase(t)
			local txt = ("area eggs reset in %dm %02ds%s"):format(math.floor(sec / 60), math.floor(sec % 60), night and "  |  NIGHT - fast egg growth" or "")
			if txt ~= P.CycleLabelTxt then
				P.CycleLabelTxt = txt
				P.setLabel(CycleLabel, txt)
			end
		end)
	end
end
task.spawn(function()
	while P.Running do
		cycleTick()
		task.wait(5)
	end
end)

local TabF = Window:CreateTab("Farm")
TabF:CreateSection("Auto Farm")
FarmLabel = TabF:CreateLabel("state: off")
TabF:CreateToggle({
	Name = "Auto Farm Eggs",
	Flag = "AutoFarm",
	Default = false,
	Callback = function(v)
		P.Farm = v
		if v then
			setFarmStatus("scanning")
		else
			P.AbortStep = true
			pcall(glideStop)
			pcall(function() if P.shieldDown then P.shieldDown() end end)
			stopWalk()
			task.spawn(leaveTreadmill)
			setFarmStatus("off")
		end
	end,
})
local rarityOptions = {}
for _, r in ipairs(Rarities) do table.insert(rarityOptions, r.name) end
TabF:CreateDropdown({
	Name = "Min Rarity",
	Options = rarityOptions,
	Default = rarityOptions[1],
	Callback = function(opt)
		P.FarmMinRarity = RarityNumByName[tostring(opt)] or 0
	end,
})
TabF:CreateToggle({
	Name = "Secret Eggs Only",
	Flag = "SecretOnly",
	Default = false,
	Callback = function(v)
		P.SecretOnly = v
		if v then
			notify("Secret Only", "farm + instant grab will only take " .. tostring(SecretLabel) .. " or better")
		end
	end,
})
TabF:CreateLabel("secret only overrides min rarity, on farm AND instant grab")
TabF:CreateToggle({
	Name = "Only Grab Upgrades",
	Flag = "OnlyUpgrades",
	Default = false,
	Callback = function(v)
		P.OnlyUpgrades = v
		upgradeFloorCache.at = 0
	end,
})
TabF:CreateToggle({
	Name = "Auto Grab Best In Range",
	Flag = "BestFirst",
	Default = false,
	Callback = function(v) P.BestFirst = v end,
})
TabF:CreateSlider({
	Name = "Grab Range",
	Min = 50,
	Max = 5000,
	Default = 1200,
	Increment = 50,
	Suffix = " st",
	Flag = "GrabRange",
	Callback = function(v) P.GrabRange = v end,
})
UpgLabel = TabF:CreateLabel("base floor: -")
TabF:CreateLabel("$/s uses the game's own formula: rarity base x size x mutation (golden 2.5x, rainbow 3.5x, silver 1.2x). upgrades = beats your weakest placed pet; best in range = highest $/s first")
TabF:CreateToggle({
	Name = "Fast Movement (glide)",
	Flag = "FastMove",
	Default = true,
	Callback = function(v)
		P.FastMove = v
	end,
})
TabF:CreateToggle({
	Name = "Auto Speed (safe, follows your Speed stat)",
	Flag = "AutoSpeed",
	Default = true,
	Callback = function(v) P.AutoSpeed = v end,
})
TabF:CreateSlider({
	Name = "Glide Speed (manual, Auto Speed off)",
	Min = 20,
	Max = 100,
	Default = 60,
	Increment = 5,
	Suffix = " st/s",
	Flag = "GlideSpeed",
	Callback = function(v) P.GlideSpeed = v end,
})
TabF:CreateLabel("the game caps your real WalkSpeed from the Speed stat and reverts any change, so auto speed runs at 1.6x it - inside the anticheat's own budget. it gets faster as the treadmill raises your Speed. there is no fly, anything airborne is rolled back. a rollback drops the farm to walking on its own")
TabF:CreateToggle({
	Name = "Turbo Mode (burst)",
	Flag = "Turbo",
	Default = true,
	Callback = function(v)
		if v and not P.shieldAvailable() then
			local ex = "your executor"
			pcall(function() ex = identifyexecutor() end)
			notify("Turbo", tostring(ex) .. " has no getconnections - turbo needs it, staying on safe glide")
			P.Turbo = false
			return
		end
		P.Turbo = v
		if not v then pcall(P.shieldDown) end
	end,
})
TabF:CreateSlider({
	Name = "Turbo Speed",
	Min = 60,
	Max = 400,
	Default = 150,
	Increment = 10,
	Suffix = " st/s",
	Flag = "TurboSpeed",
	Callback = function(v) P.TurboSpeed = v end,
})
TabF:CreateToggle({
	Name = "Turbo Carry Home (short trips)",
	Flag = "TurboCarry",
	Default = true,
	Callback = function(v) P.TurboCarry = v end,
})
TabF:CreateSlider({
	Name = "Turbo Carry Max Distance",
	Min = 100,
	Max = 1500,
	Default = 400,
	Increment = 50,
	Suffix = " st",
	Flag = "TurboCarryMax",
	Callback = function(v) P.TurboCarryMax = v end,
})
TabF:CreateToggle({
	Name = "Treadmill When No Eggs",
	Flag = "FarmTreadmill",
	Default = true,
	Callback = function(v)
		P.FarmTreadmill = v
	end,
})
TabF:CreateToggle({
	Name = "Skip Parasite Eggs",
	Flag = "FarmSkipParasite",
	Default = true,
	Callback = function(v)
		P.FarmSkipParasite = v
	end,
})
TabF:CreateSlider({
	Name = "Place Every N Eggs",
	Min = 1,
	Max = 15,
	Increment = 1,
	Default = 1,
	Suffix = " eggs",
	Callback = function(v)
		P.PlaceBatch = v
	end,
})
TabF:CreateSection("Pen Management")
TabF:CreateToggle({
	Name = "Auto Sell Weakest Pets",
	Flag = "AutoCull",
	Default = false,
	Callback = function(v) P.AutoCull = v end,
})
TabF:CreateSlider({
	Name = "Keep Spares Above Pen Size",
	Min = 0,
	Max = 20,
	Default = 3,
	Increment = 1,
	Suffix = " spare",
	Flag = "KeepSpare",
	Callback = function(v) P.KeepSpare = v end,
})
TabF:CreateButton({
	Name = "Sell Weakest Now",
	Callback = function()
		task.spawn(function()
			local n = cullWeak()
			notify("Sell Weakest", (n and n > 0) and ("sold %d pets"):format(n) or "nothing worth selling")
		end)
	end,
})
TabF:CreateLabel("ranks every pet by real $/s and sells everything below your pen size + spares, then re-equips the best. never sells equipped, favourited or fusing pets")
TabF:CreateSection("Auto Upgrade")
TabF:CreateToggle({
	Name = "Auto Base Upgrade",
	Flag = "AutoBaseUp",
	Default = false,
	Callback = function(v) P.AutoBaseUp = v end,
})
TabF:CreateToggle({
	Name = "Auto Treadmill Upgrade",
	Flag = "AutoTreadUp",
	Default = false,
	Callback = function(v) P.AutoTreadUp = v end,
})
TabF:CreateInput({
	Name = "Keep At Least ($)",
	Default = 0,
	Numeric = true,
	Flag = "UpgradeReserve",
	Callback = function(v) P.UpgradeReserve = tonumber(v) or 0 end,
})
TabF:CreateLabel("upgrades only fire when you can afford them with cash - never a robux prompt. the pen wins whenever it is actually affordable right now, otherwise the treadmill buys, since more speed pays for the pen")
TabF:CreateToggle({
	Name = "Auto Favourite Equipped Pets",
	Flag = "AutoFavEquipped",
	Default = false,
	Callback = function(v) P.AutoFavEquipped = v end,
})
TabF:CreateSection("Trails")
TabF:CreateToggle({
	Name = "Auto Buy Best Trail",
	Flag = "AutoTrailBuy",
	Default = false,
	Callback = function(v) P.AutoTrailBuy = v if v then task.spawn(P.trailBuyBest) end end,
})
TabF:CreateToggle({
	Name = "Auto Equip Best Trail",
	Flag = "AutoTrailEquip",
	Default = false,
	Callback = function(v) P.AutoTrailEquip = v if v then task.spawn(P.trailEquipBest) end end,
})
TabF:CreateLabel("buys the highest speed multiplier trail you don't own, then equips the best trail you own")
TabF:CreateSection("Boss Mastery")
TabF:CreateToggle({
	Name = "Auto Claim Boss Mastery",
	Flag = "AutoMastery",
	Default = false,
	Callback = function(v) P.AutoMastery = v if v then task.spawn(P.claimBossMastery) end end,
})
TabF:CreateLabel("claims boss mastery milestones you have earned (only while the rift event runs)")
TabF:CreateSection("Events")
TabF:CreateButton({
	Name = "Claim Group Reward",
	Callback = function()
		task.spawn(function()
			local gid = 825735094
			pcall(function() gid = require(RS.Shared.Globals.Constants).GROUP_ID end)
			local inGroup = false
			pcall(function() inGroup = LP:IsInGroupAsync(gid) end)
			if not inGroup then
				pcall(function() inGroup = LP:IsInGroup(gid) end)
			end
			if not inGroup then
				notify("Group Reward", "join the game's group first")
				return
			end
			local d = saveData()
			if d and d.ClaimedGroupReward == true then
				notify("Group Reward", "group reward already claimed")
				return
			end
			pcall(function()
				if Remotes and type(Remotes.GroupPerk) == "table" and Remotes.GroupPerk.RedeemPerk then
					local ok, msg = Remotes.GroupPerk.RedeemPerk:InvokeServer(true)
					notify("Group Reward", tostring(msg or ok or "claimed"))
				end
			end)
		end)
	end,
})
P.findBat = function()
	local char = LP.Character
	for _, container in ipairs({ char, LP:FindFirstChildOfClass("Backpack") }) do
		if container then
			for _, t in ipairs(container:GetChildren()) do
				if t:IsA("Tool") and t:GetAttribute("IsBat") == true then return t end
			end
		end
	end
	return nil
end
P.nearestDrone = function(hrp)
	local folder = workspace:FindFirstChild("ScrambleLocalVisuals")
	if not folder then return nil end
	local best, bestD
	for _, m in ipairs(folder:GetDescendants()) do
		if m:IsA("Model") and m:GetAttribute("ScrambleDroneId") ~= nil then
			local hb = m:FindFirstChild("Hitbox", true)
			if hb and hb:IsA("BasePart") and (tonumber(hb:GetAttribute("Health")) or 0) > 0 and P.droneSafe(hb.Position) then
				local d = (hb.Position - hrp.Position).Magnitude
				if not bestD or d < bestD then best, bestD = hb, d end
			end
		end
	end
	return best, bestD
end
P.droneSafe = function(pos)
	local a = guardAreaAt(pos)
	if not a then return true end
	return canOutrunArea(a) or guardAsleep(a)
end
P.remoteDrones = function()
	if P.DroneSnap and os.clock() - (P.DroneSnapAt or -99) < 4 then return P.DroneSnap end
	P.DroneSnapAt = os.clock()
	local list = {}
	pcall(function()
		local snap = Remotes.Scramble.Request:InvokeServer("Snapshot")
		local ups = type(snap) == "table" and type(snap.Drones) == "table" and snap.Drones.Upserts
		if type(ups) ~= "table" then return end
		for _, d in pairs(ups) do
			if type(d) == "table" and tonumber(d.OwnerUserId) == LP.UserId and (tonumber(d.Health) or 0) > 0 and typeof(d.CFrame) == "CFrame" then
				table.insert(list, d.CFrame.Position)
			end
		end
	end)
	P.DroneSnap = list
	return list
end
P.dropBat = function(force)
	if not P.DroneBatOn and not force then return end
	P.DroneBatOn = false
	pcall(function()
		local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum:UnequipTools() end
	end)
end
P.droneHalt = function()
	pcall(function()
		local char = LP.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hum and hrp then hum:MoveTo(hrp.Position) end
	end)
end
P.droneTick = function()
	if not P.AutoDrone or P.DroneBusy then return end
	if workspace:GetAttribute("ScrambleOutbreakActive") ~= true then
		P.DroneStatus = "waiting for a scramble outbreak"
		P.dropBat()
		return
	end
	if P.Farm then
		P.DroneStatus = "paused - turn off Auto Farm to fight drones"
		return
	end
	P.DroneBusy = true
	pcall(function()
		local char = LP.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hum or not hrp or hum.Health <= 0 then return end
		local hb, d = P.nearestDrone(hrp)
		if hb and d <= 60 then
			local bat = P.findBat()
			if not bat then
				P.DroneStatus = "no bat - grab one in game first"
				return
			end
			if bat.Parent ~= char then pcall(function() hum:EquipTool(bat) end) end
			P.DroneBatOn = true
			if d > 9 then
				P.DroneStatus = ("closing in on a drone (%d studs)"):format(math.floor(d))
				hum:MoveTo(Vector3.new(hb.Position.X, hrp.Position.Y, hb.Position.Z))
			else
				P.DroneStatus = "fighting a drone"
				local cdEnd = tonumber(bat:GetAttribute("CooldownEndTime")) or 0
				if bat:GetAttribute("CooldownActive") ~= true and workspace:GetServerTimeNow() >= cdEnd and os.clock() - (P.DroneSwing or 0) >= 0.75 then
					P.DroneSwing = os.clock()
					pcall(function() bat:Activate() end)
				end
			end
			return
		end
		if hb then
			P.DroneStatus = ("walking to a drone (%d studs)"):format(math.floor(d))
			hum:MoveTo(Vector3.new(hb.Position.X, hrp.Position.Y, hb.Position.Z))
			return
		end
		local best, bestD
		local any = false
		for _, pos in ipairs(P.remoteDrones()) do
			any = true
			if P.droneSafe(pos) then
				local dist = (pos - hrp.Position).Magnitude
				if not best or dist < bestD then best, bestD = pos, dist end
			end
		end
		if not best then
			P.DroneStatus = any and "guards are awake near your drones - waiting" or "no drones left right now"
			return
		end
		local ends = tonumber(workspace:GetAttribute("ScrambleOutbreakEndsAt")) or 0
		local left = ends - workspace:GetServerTimeNow()
		if ends > 0 and bestD / math.max(hum.WalkSpeed, 1) > left - 5 then
			P.DroneStatus = "not enough time left to reach a drone"
			return
		end
		P.dropBat(true)
		P.DroneStatus = ("walking to a drone (%d studs)"):format(math.floor(bestD))
		walkTo(Vector3.new(best.X, hrp.Position.Y, best.Z), {
			arrive = 120,
			timeout = 45,
			stopWhen = function()
				if not P.AutoDrone or not P.Running or P.Farm or workspace:GetAttribute("ScrambleOutbreakActive") ~= true then return true end
				if not P.droneSafe(best) then return true end
				local c = LP.Character
				local r = c and c:FindFirstChild("HumanoidRootPart")
				local h2, d2 = r and P.nearestDrone(r)
				return h2 ~= nil and d2 <= 150
			end,
		})
	end)
	P.DroneBusy = false
end
TabF:CreateToggle({
	Name = "Auto Drone Fight",
	Flag = "AutoDrone",
	Default = false,
	Callback = function(v)
		P.AutoDrone = v
		if v then
			task.spawn(P.droneTick)
		else
			P.DroneStatus = "off"
			P.droneHalt()
			P.dropBat()
		end
	end,
})
P.DroneLabel = TabF:CreateLabel("drones: off")
TabF:CreateLabel("walks to your scramble drones, swings the bat and collects the drops during an outbreak")
local EventTimerLabel = TabF:CreateLabel("boss opens in -")
CycleLabel = TabF:CreateLabel("area eggs reset in -")
TabF:CreateToggle({
	Name = "Egg Reset Timer",
	Flag = "ShowCycle",
	Default = false,
	Callback = function(v)
		P.ShowCycle = v
		if v then task.spawn(cycleTick) end
	end,
})
TabF:CreateSection("Server")
TabF:CreateSlider({
	Name = "Auto Hop When Nothing Eligible (min)",
	Min = 0,
	Max = 30,
	Default = 0,
	Increment = 1,
	Suffix = " min",
	Flag = "AutoHopMins",
	Callback = function(v) P.AutoHopMins = v end,
})
TabF:CreateToggle({
	Name = "Hop Until Secret Egg",
	Flag = "SecretHop",
	Default = false,
	Callback = function(v)
		P.SecretHop = v
		P.SecretHopAt = os.clock()
		if v then notify("Secret Hunt", "hops to a new server when no secret egg is up for 90s") end
	end,
})
TabF:CreateButton({
	Name = "Server Hop Now",
	Callback = function() serverHop() end,
})
TabF:CreateSection("Guards")
TabF:CreateToggle({
	Name = "Only Steal Where You Can Outrun",
	Flag = "GuardAvoid",
	Default = true,
	Callback = function(v) P.GuardAvoid = v end,
})
TabF:CreateSlider({
	Name = "Speed Margin",
	Min = 1,
	Max = 2,
	Default = 1.25,
	Increment = 0.05,
	Suffix = "x",
	Flag = "GuardMargin",
	Callback = function(v) P.GuardMargin = v end,
})
GuardLabel = TabF:CreateLabel("speed power -")
TabF:CreateLabel("each guard area posts a recommended speed power. eggs in areas above your power x margin are skipped, exits pick the gate end away from the guard, and a trip never starts while you are trapped")
TabF:CreateToggle({
	Name = "Guard ESP",
	Flag = "GuardESP",
	Default = false,
	Callback = function(v)
		P.GuardESP = v
		if v then task.spawn(guardEspTick) else pcall(clearGuardEsp) end
	end,
})
TabF:CreateSection("Speed")
TabF:CreateToggle({
	Name = "Anti AFK",
	Flag = "AntiAfk",
	Default = false,
	Callback = function(v)
		P.AntiAfk = v
	end,
})
TabF:CreateToggle({
	Name = "AFK Treadmill (speed trainer)",
	Flag = "AfkTreadmill",
	Default = false,
	Callback = function(v)
		P.AfkTreadmill = v
		if not v then stopWalk() task.spawn(leaveTreadmill) end
	end,
})

local TabX = Window:CreateTab("Extras")
TabX:CreateSection("Auto Sell (native)")
local sellOptions = { "Off" }
for _, r in ipairs(Rarities) do table.insert(sellOptions, r.name) end
TabX:CreateDropdown({
	Name = "Auto-Sell Up To",
	Options = sellOptions,
	Default = "Off",
	Callback = function(opt)
		local n = (tostring(opt) ~= "Off" and RarityNumByName[tostring(opt)]) or 0
		P.AutoSellRarity = n
		applyAutoSell(n)
	end,
})
TabX:CreateLabel("sells everything at or below that rarity")
TabX:CreateLabel("favorite/equipped pets are kept")
P.sellEggs = function()
	local n = tonumber(P.AutoSellEggRarity) or 0
	if n <= 0 or P.EggSellBusy then return end
	P.EggSellBusy = true
	pcall(function()
		local d = saveData()
		local inv = d and d.EggInventory
		if type(inv) ~= "table" then return end
		local sell = {}
		for uid, item in pairs(inv) do
			if type(item) == "table" and item.Placement == nil and item.Placed ~= true and item.Locked ~= true and item.IsFavorite ~= true and item.Favorite ~= true then
				local cat = item.Category or item.AssetCategory
				local a = cat and AssetsDir[cat]
				local rn = (a and type(a.Rarity) == "table" and tonumber(a.Rarity.RarityNumber)) or nil
				if rn and rn <= n then
					table.insert(sell, item.Uid or item.UID or uid)
					if #sell >= 200 then break end
				end
			end
		end
		if #sell > 0 then
			remoteFire("PetSatchel", "SellSelection", { Assets = {}, Eggs = sell })
			dbg(("sold %d eggs"):format(#sell))
		end
	end)
	P.EggSellBusy = false
end
TabX:CreateDropdown({
	Name = "Auto-Sell Eggs Up To",
	Options = sellOptions,
	Default = "Off",
	Callback = function(opt)
		P.AutoSellEggRarity = (tostring(opt) ~= "Off" and RarityNumByName[tostring(opt)]) or 0
		if P.AutoSellEggRarity > 0 then task.spawn(P.sellEggs) end
	end,
})
TabX:CreateLabel("sells unplaced eggs at or below that rarity, favorites kept")
task.spawn(function()
	while P.Running do
		if (tonumber(P.AutoSellEggRarity) or 0) > 0 then pcall(P.sellEggs) end
		task.wait(10)
	end
end)
TabX:CreateToggle({
	Name = "Auto-Clear Inventory (farm sustain)",
	Flag = "AutoClearInv",
	Default = false,
	Callback = function(v)
		P.AutoClearInv = v
		if v then task.spawn(sellJunk) end
	end,
})
TabX:CreateLabel("when farming + inventory nearly full,")
TabX:CreateLabel("sells non-fav pets <=Rare so farm never stalls")
TabX:CreateSection("Free Claims")
TabX:CreateToggle({
	Name = "Auto Codex Rewards",
	Flag = "AutoCodex",
	Default = false,
	Callback = function(v)
		P.AutoCodex = v
		if v then task.spawn(codexRedeemAll) task.spawn(codexRedeemLimitedEgg) end
	end,
})
TabX:CreateButton({
	Name = "Redeem All Codex Now",
	Callback = function()
		task.spawn(function()
			local a = codexRedeemAll()
			local b = codexRedeemLimitedEgg()
			notify("Codex", (a or b) and "rewards redeemed" or "nothing to redeem")
		end)
	end,
})
TabX:CreateToggle({
	Name = "Auto Collect Offline Earnings",
	Flag = "AutoAway",
	Default = false,
	Callback = function(v)
		P.AutoAway = v
		if v then task.spawn(awayCollect) end
	end,
})
TabX:CreateButton({
	Name = "Collect Offline Earnings Now",
	Callback = function()
		task.spawn(function()
			local ok, amt = awayCollect()
			notify("Offline Earnings", ok and ("collected $%s"):format(fmtRate(amt or 0)) or "nothing to collect")
		end)
	end,
})

local TabD = Window:CreateTab("Debug")
TabD:CreateSection("Debug")
TabD:CreateToggle({
	Name = "Debug Log",
	Flag = "PyriteDebug",
	Default = false,
	Callback = function(v)
		P.Debug = v
		dbg(v and "debug on" or "debug off")
	end,
})
TabD:CreateButton({
	Name = "Copy Log",
	Callback = function()
		local ok = pcall(function()
			if setclipboard then setclipboard(table.concat(P.DbgLog, "\n")) end
		end)
		dbg(ok and "log copied" or "clipboard unavailable")
		notify("Debug Log", ok and ("copied %d lines"):format(#P.DbgLog) or "clipboard unavailable")
	end,
})
TabD:CreateButton({
	Name = "Clear Log",
	Callback = function()
		P.DbgLog = {}
		DbgShown = {}
		for _, l in ipairs(P.DbgLabels) do pcall(function() l:Set("") end) end
	end,
})
TabD:CreateSection("Live")
for i = 1, 12 do
	P.DbgLabels[i] = TabD:CreateLabel("")
end

pcall(function()
	if Remotes and type(Remotes.Scramble) == "table" then
		if Remotes.Scramble.Drops and typeof(Remotes.Scramble.Drops) == "Instance" then
			conn(Remotes.Scramble.Drops.OnClientEvent:Connect(function(drops)
				if type(drops) == "table" then
					for _, drop in pairs(drops) do
						if type(drop) == "table" and drop.Id then
							P.ScrambleDrops[drop.Id] = drop
						end
					end
				end
			end))
		end
		if Remotes.Scramble.RemoveDrops and typeof(Remotes.Scramble.RemoveDrops) == "Instance" then
			conn(Remotes.Scramble.RemoveDrops.OnClientEvent:Connect(function(ids)
				if type(ids) == "table" then
					for _, id in pairs(ids) do P.ScrambleDrops[id] = nil end
				elseif ids ~= nil then
					P.ScrambleDrops[ids] = nil
				end
			end))
		end
	end
end)

task.spawn(function()
	local lastTxt = ""
	while P.Running do
		local now = os.clock()
		local txt = ""
		pcall(function()
			local ok, secs = pcall(function() return require(RS.Data.BossEvent).SecondsUntilNextOpen() end)
			if ok and type(secs) == "number" then
				txt = ("boss opens in ~%d min"):format(math.ceil(secs / 60))
			else
				txt = "boss timer unknown"
			end
		end)
		local scrambleActive = workspace:GetAttribute("ScrambleOutbreakActive") == true
		if scrambleActive then
			txt = txt .. " | scramble: ACTIVE"
		else
			if os.clock() - (P.ScrambleNextFetched or -999) > 60 then
				P.ScrambleNextFetched = os.clock()
				pcall(function()
					local snap = Remotes.Scramble.Request:InvokeServer("Snapshot")
					local w = type(snap) == "table" and snap.Window
					if type(w) == "table" and tonumber(w.NextAt) then P.ScrambleNextAt = tonumber(w.NextAt) end
				end)
			end
			local srv = workspace:GetServerTimeNow()
			if P.ScrambleNextAt and P.ScrambleNextAt > srv then
				txt = txt .. (" | scramble in ~%d min"):format(math.ceil((P.ScrambleNextAt - srv) / 60))
			end
		end
		if txt ~= lastTxt then
			lastTxt = txt
			P.setLabel(EventTimerLabel, txt)
		end
		task.wait(5)
	end
end)

task.spawn(function()
	while P.Running do
		if (P.AutoScramble or P.AutoDrone) and workspace:GetAttribute("ScrambleOutbreakActive") == true then
			local now = workspace:GetServerTimeNow()
			local char = LP.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local collect = {}
				for id, drop in pairs(P.ScrambleDrops) do
					if type(drop) == "table" then
						local pos = drop.Position
						if typeof(pos) == "Vector3" then
							local radius = drop.Radius or 8
							local expiresAt = drop.ExpiresAt
							local collectAfter = drop.CollectAfter
							local ownerUserId = drop.OwnerUserId
							local shouldCollect = (expiresAt == nil or expiresAt > now) and (collectAfter == nil or collectAfter <= now) and (ownerUserId == nil or ownerUserId == LP.UserId) and ((hrp.Position - pos).Magnitude <= radius) and (P.ScrambleTried[id] == nil or now - P.ScrambleTried[id] >= 1)
							if shouldCollect then
								table.insert(collect, id)
								if #collect >= 8 then break end
							end
						end
					end
				end
				if #collect > 0 then
					for _, id in ipairs(collect) do
						P.ScrambleTried[id] = now
					end
					pcall(function()
						if Remotes and type(Remotes.Scramble) == "table" and Remotes.Scramble.Collect then
							Remotes.Scramble.Collect:FireServer(collect)
						end
					end)
				end
				local expiredIds = {}
				for id, drop in pairs(P.ScrambleDrops) do
					if type(drop) == "table" and drop.ExpiresAt and drop.ExpiresAt <= now then
						table.insert(expiredIds, id)
					end
				end
				for _, id in ipairs(expiredIds) do
					P.ScrambleDrops[id] = nil
				end
			end
		end
		task.wait(0.5)
	end
end)

task.spawn(function()
	while P.Running do
		if P.AutoDrone then pcall(P.droneTick) end
		task.wait(0.3)
	end
end)

task.spawn(function()
	local last = ""
	while P.Running do
		local n = workspace:GetAttribute("ScrambleActiveDrones")
		local txt = "drones: " .. tostring(P.AutoDrone and (P.DroneStatus or "starting") or "off") .. (n and (" | active " .. tostring(n)) or "")
		if txt ~= last then
			last = txt
			P.setLabel(P.DroneLabel, txt)
		end
		task.wait(2)
	end
end)

do
	local V14 = P.V14
	local function parseAmt(v)
		local s = tostring(v or ""):lower():gsub("[%s,%$/s]", "")
		if s == "" or s == "off" then return 0 end
		local num, suf = s:match("^([%d%.]+)([kmbtq]?)")
		num = tonumber(num)
		if not num then return 0 end
		return num * (({ k = 1e3, m = 1e6, b = 1e9, t = 1e12, q = 1e15 })[suf] or 1)
	end
	local rarAny = { "Any" }
	for _, r in ipairs(Rarities) do table.insert(rarAny, r.name) end
	local function rarNum(opt) return RarityNumByName[tostring(opt)] or 0 end
	local function rarName(n)
		for _, r in ipairs(Rarities) do if r.num == n then return r.name end end
		return rarAny[1]
	end

	local TabS = Window:CreateTab("Filters")
	TabS:CreateSection("Steal Filters (farm + instant grab)")
	TabS:CreateMultiDropdown({
		Name = "Target Areas",
		Options = V14.AreaOptions,
		EmptyText = "All areas",
		Flag = "V14TargetAreas",
		Callback = function(list) P.TargetAreas = V14.setOf(list) end,
	})
	TabS:CreateMultiDropdown({
		Name = "Target Specific Eggs",
		Options = V14.EggOptions,
		EmptyText = "All eggs",
		Flag = "V14TargetEggs",
		Callback = function(list) P.TargetEggs = V14.labelsToCats(list) end,
	})
	TabS:CreateInput({
		Name = "Min Steal Value ($/s)",
		Placeholder = "0, 250k, 50m, 1.5b",
		Default = "",
		Flag = "V14MinSteal",
		Callback = function(v) P.MinStealValue = parseAmt(v) end,
	})
	TabS:CreateDropdown({
		Name = "Steal Priority",
		Options = { "Nearest", "Highest Value", "Best Rarity", "Biggest Size", "Best Mutation", "Lowest Value" },
		Default = "Nearest",
		Flag = "V14StealPriority",
		Callback = function(v) P.StealPriority = tostring(v) end,
	})
	TabS:CreateToggle({
		Name = "Steal Missing Index Eggs First",
		Flag = "V14IndexFirst",
		Default = false,
		Callback = function(v) P.IndexFirst = v end,
	})
	TabS:CreateToggle({
		Name = "Steal Rift Recipe Eggs First",
		Flag = "V14RiftFirst",
		Default = false,
		Callback = function(v) P.RiftFirst = v if v then task.spawn(V14.riftState, true) end end,
	})
	TabS:CreateToggle({
		Name = "Wait Out Night / Reset Wall",
		Flag = "V14WaitNight",
		Default = true,
		Callback = function(v) P.WaitNight = v end,
	})
	TabS:CreateLabel("index and rift eggs skip the other filters and go first. priority picks inside your grab range; nearest ignores it")
	TabS:CreateSection("Place Rules")
	TabS:CreateDropdown({
		Name = "Place Rule",
		Options = { "Always", "When Not Stealing", "Night Only" },
		Default = "Always",
		Flag = "V14PlaceRule",
		Callback = function(v) P.PlaceRule = tostring(v) end,
	})
	TabS:CreateDropdown({
		Name = "Place Order",
		Options = { "Highest Value", "Best Rarity", "Biggest Size", "Smallest Size" },
		Default = "Highest Value",
		Flag = "V14PlaceOrder",
		Callback = function(v) P.PlaceOrder = tostring(v) end,
	})
	TabS:CreateDropdown({
		Name = "Place Min Rarity",
		Options = rarAny,
		Default = "Any",
		Flag = "V14PlaceMinRarity",
		Callback = function(v) P.PlaceMinRarity = rarNum(v) end,
	})
	TabS:CreateInput({
		Name = "Place Min Value ($/s)",
		Placeholder = "0 = off",
		Default = "",
		Flag = "V14PlaceMinValue",
		Callback = function(v) P.PlaceMinValue = parseAmt(v) end,
	})
	TabS:CreateSection("Hatch Filters")
	TabS:CreateDropdown({
		Name = "Hatch Min Rarity",
		Options = rarAny,
		Default = "Any",
		Flag = "V14HatchMinRarity",
		Callback = function(v) P.HatchMinRarity = rarNum(v) end,
	})
	TabS:CreateInput({
		Name = "Hatch Min Value ($/s)",
		Placeholder = "0 = off",
		Default = "",
		Flag = "V14HatchMinValue",
		Callback = function(v) P.HatchMinValue = parseAmt(v) end,
	})
	TabS:CreateMultiDropdown({
		Name = "Hatch Only These",
		Options = V14.EggOptions,
		EmptyText = "All eggs",
		Flag = "V14HatchSpecies",
		Callback = function(list) P.HatchSpecies = V14.labelsToCats(list) end,
	})

	local TabP = Window:CreateTab("Pets")
	TabP:CreateSection("Rules Sell")
	local rules = { "Rarity Only", "Value Only", "Rarity And Value", "Rarity Or Value" }
	local sellPreview = TabP:CreateLabel("preview: -")
	TabP:CreateToggle({ Name = "Auto Sell Pets (rules)", Flag = "V14SellPets", Default = false, Callback = function(v) P.SellPetsOn = v end })
	TabP:CreateDropdown({ Name = "Pet Sell Rule", Options = rules, Default = "Rarity Only", Flag = "V14SellPetRule", Callback = function(v) P.SellPetRule = tostring(v) end })
	TabP:CreateDropdown({ Name = "Pet Max Rarity", Options = rarAny, Default = rarName(3), Flag = "V14SellPetMaxRar", Callback = function(v) P.SellPetMaxRarity = rarNum(v) end })
	TabP:CreateInput({ Name = "Sell Pets Below ($/s)", Placeholder = "0 = off", Default = "", Flag = "V14SellPetMaxVal", Callback = function(v) P.SellPetMaxValue = parseAmt(v) end })
	TabP:CreateToggle({ Name = "Keep Mutated Pets", Flag = "V14KeepMutPets", Default = true, Callback = function(v) P.SellKeepMutated = v end })
	TabP:CreateToggle({ Name = "Auto Sell Eggs (rules)", Flag = "V14SellEggs", Default = false, Callback = function(v) P.SellEggsOn = v end })
	TabP:CreateDropdown({ Name = "Egg Sell Rule", Options = rules, Default = "Rarity Only", Flag = "V14SellEggRule", Callback = function(v) P.SellEggRule = tostring(v) end })
	TabP:CreateDropdown({ Name = "Egg Max Rarity", Options = rarAny, Default = rarName(3), Flag = "V14SellEggMaxRar", Callback = function(v) P.SellEggMaxRarity = rarNum(v) end })
	TabP:CreateInput({ Name = "Sell Eggs Below ($/s)", Placeholder = "0 = off", Default = "", Flag = "V14SellEggMaxVal", Callback = function(v) P.SellEggMaxValue = parseAmt(v) end })
	TabP:CreateToggle({ Name = "Keep Mutated Eggs", Flag = "V14KeepMutEggs", Default = true, Callback = function(v) P.SellEggKeepMutated = v end })
	TabP:CreateMultiDropdown({ Name = "Never Sell These", Options = V14.EggOptions, EmptyText = "None", Flag = "V14SellBlacklist", Callback = function(list) P.SellBlacklist = V14.labelsToCats(list) end })
	TabP:CreateButton({
		Name = "Sell Matching Now",
		Callback = function()
			task.spawn(function()
				local a = V14.petSellList()
				local e = V14.eggSellList()
				local n = V14.sellBatch(a, e)
				notify("Rules Sell", n > 0 and ("sold %d pets, %d eggs"):format(#a, #e) or "nothing matches")
			end)
		end,
	})
	TabP:CreateLabel("never sells equipped, favourited or fusing pets, or the egg in your hand")

	TabP:CreateSection("Auto Fuse Machine")
	local fuseLabel = TabP:CreateLabel("fuse: off")
	TabP:CreateToggle({ Name = "Auto Fuse", Flag = "V14Fuse", Default = false, Callback = function(v) P.FuseOn = v if v then task.spawn(V14.fuseTick) end end })
	TabP:CreateDropdown({ Name = "Fuse Pick", Options = { "Lowest Rarity", "Highest Rarity", "Most Copies", "Lowest Value" }, Default = "Lowest Rarity", Flag = "V14FusePick", Callback = function(v) P.FusePick = tostring(v) end })
	TabP:CreateDropdown({ Name = "Max Rarity To Fuse", Options = rarAny, Default = rarName(6), Flag = "V14FuseMaxRar", Callback = function(v) P.FuseMaxRarity = rarNum(v) > 0 and rarNum(v) or 99 end })
	TabP:CreateMultiDropdown({ Name = "Fuse Only These", Options = V14.EggOptions, EmptyText = "All species", Flag = "V14FuseSpecies", Callback = function(list) P.FuseSpecies = V14.labelsToCats(list) end })
	TabP:CreateToggle({ Name = "Skip Mutated Pets", Flag = "V14FuseSkipMut", Default = true, Callback = function(v) P.FuseSkipMutated = v end })
	TabP:CreateToggle({ Name = "Eject Pets That Can't Make A Set", Flag = "V14FuseEject", Default = true, Callback = function(v) P.FuseEject = v end })
	TabP:CreateLabel("fuses 3 of the same pet into an egg. cash only, gated by Keep At Least on the Farm tab. equipped and favourited pets are never used")

	TabP:CreateSection("Auto Favorite")
	local favLabel = TabP:CreateLabel("favorite: -")
	TabP:CreateToggle({ Name = "Auto Favorite (rules)", Flag = "V14Fav", Default = false, Callback = function(v) P.FavOn = v if v then task.spawn(V14.favTick) end end })
	TabP:CreateDropdown({ Name = "Favorite Rule", Options = { "Match All", "Match Any" }, Default = "Match All", Flag = "V14FavRule", Callback = function(v) P.FavRule = tostring(v) end })
	TabP:CreateDropdown({ Name = "Favorite Min Rarity", Options = rarAny, Default = "Any", Flag = "V14FavMinRar", Callback = function(v) P.FavMinRarity = rarNum(v) end })
	TabP:CreateMultiDropdown({ Name = "Favorite Mutations", Options = V14.MutationOptions, EmptyText = "Skip", Flag = "V14FavMuts", Callback = function(list) P.FavMutations = V14.mutLabelsToIds(list) end })
	TabP:CreateToggle({ Name = "Favorite Any Mutation", Flag = "V14FavAnyMut", Default = false, Callback = function(v) P.FavAnyMutation = v end })
	TabP:CreateInput({ Name = "Favorite Min Value ($/s)", Placeholder = "0 = skip", Default = "", Flag = "V14FavMinVal", Callback = function(v) P.FavMinValue = parseAmt(v) end })
	TabP:CreateMultiDropdown({ Name = "Always Favorite", Options = V14.EggOptions, EmptyText = "None", Flag = "V14FavSpecies", Callback = function(list) P.FavSpecies = V14.labelsToCats(list) end })

	local TabR = Window:CreateTab("Rift & Boss")
	TabR:CreateSection("Rift Machine")
	local riftLabel = TabR:CreateLabel("rift: -")
	TabR:CreateToggle({ Name = "Auto Rift Sacrifice", Flag = "V14Rift", Default = false, Callback = function(v) P.RiftOn = v if v then task.spawn(function() pcall(V14.riftTick) end) end end })
	TabR:CreateToggle({ Name = "Auto Reroll Recipe (free only)", Flag = "V14RiftReroll", Default = false, Callback = function(v) P.RiftReroll = v end })
	TabR:CreateLabel("trades the 3 pets the recipe asks for, cheapest unmutated first. rerolls only use free rerolls. claims the reward on its own")
	TabR:CreateSection("Boss Shop")
	local bossLabel = TabR:CreateLabel("boss shop: off")
	local prodNames, prodByName = {}, {}
	local okBP, bp = P.iso(V14.bossProducts)
	for _, p in ipairs(okBP and bp or {}) do
		local l = ("%s (%d tokens)"):format(p.name, math.floor(p.price))
		table.insert(prodNames, l)
		prodByName[l] = p.id
	end
	TabR:CreateToggle({ Name = "Auto Buy Boss Shop", Flag = "V14BossShop", Default = false, Callback = function(v) P.BossShopOn = v if v then task.spawn(function() pcall(V14.bossTick) end) end end })
	TabR:CreateMultiDropdown({
		Name = "Boss Shop Items",
		Options = prodNames,
		Default = (function() for l, id in pairs(prodByName) do if id == "MutationConsumable" then return { l } end end return {} end)(),
		EmptyText = "None",
		Flag = "V14BossItems",
		Callback = function(list)
			local s = {}
			for _, l in ipairs(list) do if prodByName[l] then s[prodByName[l]] = true end end
			P.BossShopItems = s
		end,
	})
	TabR:CreateSlider({ Name = "Keep Boss Tokens", Min = 0, Max = 20000, Default = 0, Increment = 50, Suffix = "", Flag = "V14BossKeep", Callback = function(v) P.BossKeep = v end })
	TabR:CreateSection("Mutation Items")
	local mutLabel = TabR:CreateLabel("mutation: off")
	TabR:CreateToggle({ Name = "Auto Use Mutation Items", Flag = "V14Mutate", Default = false, Callback = function(v) P.MutateOn = v end })
	TabR:CreateDropdown({ Name = "Mutation Min Rarity", Options = rarAny, Default = "Any", Flag = "V14MutMinRar", Callback = function(v) P.MutateMinRarity = rarNum(v) end })
	TabR:CreateToggle({ Name = "Skip Already Mutated Eggs", Flag = "V14MutSkip", Default = true, Callback = function(v) P.MutateSkipMutated = v end })
	TabR:CreateLabel("uses fractured / scrambled items on your best placed egg. walks to it in your base, pauses the farm while it does")

	local TabPl = Window:CreateTab("Player")
	TabPl:CreateSection("Character")
	TabPl:CreateToggle({ Name = "Anti Ragdoll", Flag = "V14AntiRag", Default = false, Callback = function(v) P.AntiRagdoll = v end })
	TabPl:CreateToggle({ Name = "Anti Trap", Flag = "V14AntiTrap", Default = false, Callback = function(v) P.AntiTrap = v pcall(V14.trapApply, v) end })
	TabPl:CreateToggle({ Name = "Instant Prompts", Flag = "V14Prompts", Default = false, Callback = function(v) P.InstantPrompts = v pcall(V14.promptApply, v) end })
	TabPl:CreateToggle({ Name = "Infinite Jump", Flag = "V14InfJump", Default = false, Callback = function(v) P.InfJump = v end })
	TabPl:CreateToggle({ Name = "Player ESP", Flag = "V14PlayerESP", Default = false, Callback = function(v) P.PlayerESP = v end })
	TabPl:CreateSection("Combat")
	TabPl:CreateToggle({ Name = "Hit Aura (hold a bat)", Flag = "V14HitAura", Default = false, Callback = function(v) P.HitAura = v end })
	TabPl:CreateToggle({ Name = "Only Hit Egg Carriers", Flag = "V14HitHolders", Default = true, Callback = function(v) P.HitHoldersOnly = v end })
	TabPl:CreateLabel("swings at the closest player in your bat's range who is in the field. carriers only makes them drop the egg so you can take it")

	local TabPr = Window:CreateTab("Predict")
	TabPr:CreateSection("Rift Schedule")
	local riftLines = {}
	for i = 1, 7 do riftLines[i] = TabPr:CreateLabel("") end
	TabPr:CreateSection("Fuse Odds (what's in the machine)")
	local fuseLines = {}
	for i = 1, 7 do fuseLines[i] = TabPr:CreateLabel("") end
	TabPr:CreateSection("Your Eggs")
	local eggLine = TabPr:CreateLabel("eggs: -")

	local TabSv = Window:CreateTab("Server")
	TabSv:CreateSection("Server")
	TabSv:CreateToggle({ Name = "Auto Rejoin On Disconnect", Flag = "V14AutoRejoin", Default = true, Callback = function(v) P.AutoRejoin = v end })
	TabSv:CreateToggle({ Name = "Reload Script After Teleport", Flag = "V14AutoReload", Default = true, Callback = function(v) P.AutoReload = v end })
	TabSv:CreateDropdown({ Name = "Server Hop Mode", Options = { "Least Players", "Most Players", "Random" }, Default = "Least Players", Flag = "V14HopMode", Callback = function(v) P.HopMode = tostring(v) end })
	local jobBox = TabSv:CreateInput({ Name = "Job ID", Placeholder = "paste a server job id", Default = "", Callback = function(v) P.JoinJob = tostring(v or "") end })
	TabSv:CreateButton({
		Name = "Join Job ID",
		Callback = function()
			if not V14.joinJob(P.JoinJob) then notify("Join", "paste a valid job id first") end
		end,
	})
	TabSv:CreateButton({
		Name = "Copy Current Job ID",
		Callback = function()
			local ok = pcall(function() (setclipboard or toclipboard)(game.JobId) end)
			pcall(function() jobBox:Set(game.JobId) end)
			notify("Job ID", ok and "copied" or game.JobId)
		end,
	})
	TabSv:CreateButton({ Name = "Rejoin Server", Callback = function() V14.rejoin() end })
	TabSv:CreateToggle({
		Name = "Floating Menu Button",
		Flag = "V14MenuButton",
		Default = UIS.TouchEnabled,
		Callback = function(v)
			P.ShowMenuButton = v
			if P.setMobileButton then P.setMobileButton(v) end
		end,
	})
	TabSv:CreateSection("Webhook")
	TabSv:CreateToggle({ Name = "Webhook On Stolen Egg", Flag = "V14StealHook", Default = false, Callback = function(v) P.StealWebhook = v if v and tostring(P.WebhookUrl or "") == "" then notify("Webhook", "paste your webhook url on the ESP tab") end end })
	TabSv:CreateLabel("uses the webhook url from the ESP tab")
	TabSv:CreateSection("Performance")
	TabSv:CreateSlider({
		Name = "FPS Cap",
		Min = 30,
		Max = 360,
		Default = 240,
		Increment = 10,
		Suffix = " fps",
		Flag = "V14FpsCap",
		Callback = function(v)
			if not V14.fpsCap(v) and not V14.FpsWarned then
				V14.FpsWarned = true
				local ex = "your executor"
				pcall(function() ex = identifyexecutor() end)
				notify("FPS Cap", tostring(ex) .. " has no setfpscap")
			end
		end,
	})
	TabSv:CreateToggle({ Name = "Optimizer (low graphics)", Flag = "V14Optimize", Default = false, Callback = function(v) task.spawn(V14.optimize, v) end })
	TabSv:CreateSection("Config")
	local cfgName = "Pyrite_" .. tostring(game.PlaceId)
	TabSv:CreateButton({
		Name = "Save Config",
		Callback = function()
			local ok, err = pcall(function() return Ember:SaveConfig(cfgName) end)
			local readOk = ok and pcall(function() return isfile and isfile(Ember.ConfigFolder .. "/" .. cfgName .. ".json") end)
			notify("Config", (ok and readOk) and "saved" or ("save failed: " .. tostring(err or "no file api")))
		end,
	})
	TabSv:CreateButton({
		Name = "Load Config",
		Callback = function()
			local ok, a, b = pcall(function() return Ember:LoadConfig(cfgName) end)
			notify("Config", (ok and a) and "loaded" or ("load failed: " .. tostring(b or a)))
		end,
	})
	TabSv:CreateToggle({
		Name = "Auto Load Config On Start",
		Flag = "V14AutoLoadCfg",
		Default = false,
		Callback = function(v)
			pcall(function()
				if typeof(writefile) == "function" then
					if typeof(isfolder) == "function" and not isfolder(Ember.ConfigFolder) then makefolder(Ember.ConfigFolder) end
					writefile(Ember.ConfigFolder .. "/" .. cfgName .. ".auto", v and "1" or "0")
				end
			end)
		end,
	})
	P.V14AutoLoad = function()
		pcall(function()
			local f = Ember.ConfigFolder .. "/" .. cfgName .. ".auto"
			if typeof(isfile) == "function" and isfile(f) and readfile(f) == "1" then
				Ember:LoadConfig(cfgName)
				notify("Config", "auto loaded")
			end
		end)
	end

	task.spawn(function()
		while P.Running do
			pcall(function()
				local a, ta = V14.petSellList()
				local e, te = V14.eggSellList()
				P.setLabel(sellPreview, ("preview: %d pets ($%s) + %d eggs ($%s) match"):format(#a, fmtRate(ta), #e, fmtRate(te)))
			end)
			P.setLabel(fuseLabel, P.FuseOn and V14.fuseStatus or "fuse: off")
			pcall(function()
				local _, n = V14.favList()
				P.setLabel(favLabel, ("favorite: %d pets match"):format(n))
			end)
			if not (P.RiftOn or P.RiftReroll) then
				pcall(function()
					local s = V14.riftState()
					if type(s) == "table" then
						local req = {}
						for _, r in ipairs(type(s.Requirements) == "table" and s.Requirements or {}) do
							local c = tostring(type(r) == "table" and (r.Category or r.AssetId) or r)
							local a = AssetsDir[c]
							table.insert(req, tostring(a and a.DisplayName or c))
						end
						V14.riftStatus = ("rift: %s - needs %s - pity %s/%s - free rerolls %s%s"):format(tostring(s.BannerDisplayName or s.BannerId or "?"), #req > 0 and table.concat(req, ", ") or "-", tostring(s.PityCount or 0), tostring(s.PityThreshold or 0), tostring(s.FreeRefreshesRemaining or 0), s.Unlocked == false and " - LOCKED" or "")
					end
				end)
			end
			P.setLabel(riftLabel, V14.riftStatus)
			P.setLabel(bossLabel, P.BossShopOn and V14.bossStatus or "boss shop: off")
			P.setLabel(mutLabel, P.MutateOn and V14.mutStatus or "mutation: off")
			pcall(function()
				local rl = V14.riftPredict()
				for i = 1, #riftLines do P.setLabel(riftLines[i], rl[i] or "") end
			end)
			pcall(function()
				local fl = V14.fusePredict()
				for i = 1, #fuseLines do P.setLabel(fuseLines[i], fl[i] or "") end
			end)
			pcall(function() P.setLabel(eggLine, V14.eggSummary()) end)
			task.wait(5)
		end
	end)
end

local Tab2 = Window:CreateTab("Index")
Tab2:CreateSection("Secrets & Eternals")
local dispToCat = {}
for cat, a in pairs(AssetsDir) do
	if type(a) == "table" then dispToCat[tostring(a.DisplayName or cat)] = cat end
end
local function recId(r)
	if type(r) ~= "table" then return nil end
	if r.AssetCategory then return r.AssetCategory end
	if type(r.ItemData) == "table" then
		return r.ItemData.id or r.ItemData.Id or r.ItemData.Category
	end
	return nil
end
local function ownedSet()
	local owned = {}
	pcall(function()
		local snap = AssetRoster.ReadSnapshot()
		for _, row in pairs(snap) do
			if type(row) == "table" and tostring(row.OwnerUserId) == tostring(LP.UserId) and type(row.Records) == "table" then
				for _, r in pairs(row.Records) do
					local id = recId(r)
					if id then owned[tostring(id)] = true end
				end
			end
		end
	end)
	pcall(function()
		local pen = AssetRoster.ReadOwnerPen(LP.UserId)
		if type(pen) == "table" then
			for _, r in pairs(pen) do
				local id = recId(r)
				if id then owned[tostring(id)] = true end
			end
		end
	end)
	pcall(function()
		local function scan(cont)
			for _, t in ipairs(cont:GetChildren()) do
				if t:IsA("Tool") then
					local nm = t.Name:gsub(" %([%d%.]+ kg%)$", "")
					local cat = dispToCat[nm]
					if cat then owned[cat] = true end
				end
			end
		end
		local bp = LP:FindFirstChild("Backpack")
		if bp then scan(bp) end
		if LP.Character then scan(LP.Character) end
	end)
	return owned
end
local idxTargets = {}
for cat, a in pairs(AssetsDir) do
	if type(a) == "table" and type(a.Rarity) == "table" then
		local rn = tostring(a.Rarity.DisplayName)
		if rn == "Secret" or rn == "Eternal" then
			table.insert(idxTargets, { cat = cat, name = tostring(a.DisplayName or cat), rar = rn })
		end
	end
end
table.sort(idxTargets, function(a, b)
	if a.rar ~= b.rar then return a.rar < b.rar end
	return a.name < b.name
end)
local idxHeader = Tab2:CreateLabel("press refresh")
local idxLabels = {}
local function refreshIndex()
	local owned = ownedSet()
	local got = 0
	for _, t in ipairs(idxTargets) do
		local has = owned[t.cat] == true
		if has then got = got + 1 end
		local l = idxLabels[t.cat]
		if l then
			pcall(function() l:Set((has and "[ OWNED ]  " or "[  --  ]  ") .. t.name .. "  (" .. t.rar .. ")") end)
		end
	end
	pcall(function() idxHeader:Set("you own " .. got .. " / " .. #idxTargets) end)
end
Tab2:CreateButton({
	Name = "Refresh",
	Callback = function()
		task.spawn(refreshIndex)
	end,
})
for _, t in ipairs(idxTargets) do
	idxLabels[t.cat] = Tab2:CreateLabel("[  --  ]  " .. t.name .. "  (" .. t.rar .. ")")
end
task.spawn(refreshIndex)

local cam = workspace.CurrentCamera
if cam then
	local vs = cam.ViewportSize
	local sc = math.min((vs.X - 20) / 620, (vs.Y - 60) / 430, 1)
	if sc < 1 then
		local s = Instance.new("UIScale")
		s.Scale = sc
		s.Parent = Window.Main
	end
end

local MobileGui
local function toggleMenu()
	if Window.Main then Window.Main.Visible = not Window.Main.Visible end
end
conn(UIS.InputBegan:Connect(function(input, gp)
	if input.KeyCode == Enum.KeyCode.RightShift and UIS:GetFocusedTextBox() == nil then
		toggleMenu()
	end
end))
P.setMobileButton = function(on)
	if not on then
		if MobileGui then pcall(function() MobileGui:Destroy() end) MobileGui = nil end
		getgenv().ChronixHasMobileToggle = nil
		return
	end
	if MobileGui and MobileGui.Parent then return end
	MobileGui = Instance.new("ScreenGui")
	MobileGui.Name = "m" .. tostring(math.random(100000, 999999))
	MobileGui.ResetOnSpawn = false
	MobileGui.IgnoreGuiInset = true
	pcall(function() MobileGui.DisplayOrder = 2147483646 end)
	getgenv().ChronixHasMobileToggle = true
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 52, 0, 52)
	btn.Position = UDim2.new(0, 10, 0.42, 0)
	btn.BackgroundColor3 = Color3.fromRGB(35, 30, 28)
	btn.TextColor3 = Color3.fromRGB(255, 150, 60)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 20
	btn.Text = "P"
	btn.AutoButtonColor = true
	btn.Active = true
	btn.Parent = MobileGui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = btn
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 122, 26)
	stroke.Thickness = 2
	stroke.Parent = btn
	local dragging, dragInput, startPos, startAt, moved = false, nil, nil, nil, false
	btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, moved = true, false
			dragInput = input
			startPos = btn.Position
			startAt = input.Position
		end
	end)
	conn(UIS.InputChanged:Connect(function(input)
		if not dragging or not startAt then return end
		if input == dragInput or input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - startAt
			if delta.Magnitude > 6 then moved = true end
			if moved then
				btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
			end
		end
	end))
	conn(UIS.InputEnded:Connect(function(input)
		if not dragging then return end
		if input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			if not moved then toggleMenu() end
		end
	end))
	MobileGui.Parent = getParent()
end
if UIS.TouchEnabled or P.ShowMenuButton then P.setMobileButton(true) end

function P.Unload()
	if P.Unloaded then return end
	P.AbortStep = true
	P.StepGen = (P.StepGen or 0) + 1
	P.Unloaded = true
	P.Running = false
	if P.AutoDrone then
		P.AutoDrone = false
		pcall(P.droneHalt)
		pcall(P.dropBat)
	end
	pcall(clearGuardEsp)
	P.Enabled = false
	P.Farm = false
	P.AfkTreadmill = false
	P.AutoCodex = false
	P.AutoAway = false
	P.AutoClearInv = false
	P.AutoCull = false
	P.SecretAlert = false
	P.SecretHop = false
	P.SecretWebhook = false
	P.MasteryEnded = false
	P.Grab = false
	P.Place = false
	P.Hatch = false
	P.EquipBest = false
	P.AntiAfk = false
	P.Debug = false
	P.DbgLabels = {}
	pcall(stopWalk)
	pcall(glideStop)
	pcall(function() if P.shieldDown then P.shieldDown() end end)
	P.Turbo = false
	P.HoldFarm = false
	P.AntiRagdoll = false
	P.HitAura = false
	P.AutoRejoin = false
	P.SellPetsOn = false
	P.SellEggsOn = false
	P.FuseOn = false
	P.FavOn = false
	P.RiftOn = false
	P.RiftReroll = false
	P.BossShopOn = false
	P.MutateOn = false
	P.PlayerESP = false
	pcall(function() P.V14.playerEspTick() end)
	pcall(function() if P.AntiTrap then P.V14.trapApply(false) end end)
	pcall(function() if P.InstantPrompts then P.V14.promptApply(false) end end)
	pcall(function() P.V14.optimize(false) end)
	P.AntiTrap = false
	P.InstantPrompts = false
	for _, c in ipairs(P.Conns) do
		pcall(function() c:Disconnect() end)
	end
	P.Conns = {}
	pcall(clearAll)
	pcall(function() if RadarFolder then RadarFolder:Destroy() end end)
	RadarFolder = nil
	if MobileGui then pcall(function() MobileGui:Destroy() end) end
	getgenv().ChronixHasMobileToggle = nil
	pcall(function() if P.Watermark then P.Watermark:Destroy() end end)
	P.Watermark = nil
	pcall(function() Window:Destroy() end)
	getgenv().Pyrite = nil
end

conn(Window.Gui.Destroying:Connect(function()
	task.defer(P.Unload)
end))
conn(Window.Gui.AncestryChanged:Connect(function(_, parent)
	if parent == nil then task.defer(P.Unload) end
end))

Ember:Notify({ Title = "Pyrite v14", Content = "loaded - turbo burst on, filters, fuse, rift and more", Duration = 3 })
if P.NoRequire then
	local ex = "your executor"
	pcall(function() ex = identifyexecutor() end)
	Ember:Notify({ Title = "Limited Mode", Content = tostring(ex) .. " can't read the game's modules - farm, grab and place run on raw remotes, names / values / filters are unavailable", Duration = 10 })
end
task.delay(1, function() pcall(P.V14AutoLoad) end)
