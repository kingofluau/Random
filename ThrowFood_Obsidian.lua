local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local RunService = game:GetService("RunService")
local UserInput = game:GetService("UserInputService")
local inputOk, VirtualInput = pcall(game.GetService, game, "VirtualInputManager")
if not inputOk then
    VirtualInput = nil
end
local Player = Players.LocalPlayer
local Environment = getgenv and getgenv() or _G
local SessionKey = "ThrowFoodObsidianSession"

if Environment[SessionKey] and Environment[SessionKey].Unload then
    pcall(Environment[SessionKey].Unload)
end

local function child(parent, name)
    local result = parent and parent:WaitForChild(name, 25)
    assert(result, "Missing game object: " .. name)
    return result
end

local Controllers = child(child(child(Player, "PlayerScripts"), "Client"), "Controllers")
local Config = child(ReplicatedStorage, "Config")
local Shared = child(ReplicatedStorage, "Shared")
local Remotes = child(ReplicatedStorage, "Remotes")
local Data = require(child(Controllers, "DataController"))
local ClientState = require(child(Controllers, "ClientState"))
local Throw = require(child(Controllers, "ThrowController"))
local Meter = require(child(Controllers, "ThrowMeter"))
local Training = require(child(Controllers, "TrainingController"))
local Offline = require(child(Controllers, "OfflineEarnings"))
local Plot = require(child(Controllers, "PlotController"))
local Movement = require(child(Controllers, "Movement"))
local GameConfig = require(child(Config, "GameConfig"))
local Foods = require(child(Config, "FoodsConfig"))
local Stands = require(child(Config, "StandsConfig"))
local Fence = require(child(Config, "FenceConfig"))
local Rarities = require(child(Config, "RarityConfig"))
local Economy = require(child(Config, "AnimalEconomy"))
local Mutations = require(child(Shared, "Mutations"))
local Curve = require(child(Shared, "BalanceCurve"))
local MeterMath = require(child(Shared, "ThrowMeterMath"))
local Admin = require(child(Shared, "AdminAbuse"))
local IndexRewards = require(child(Shared, "IndexRewards"))

local readyDeadline = os.clock() + 40
while not Data:IsReady() and os.clock() < readyDeadline do
    task.wait(0.2)
end
assert(Data:IsReady(), "Player data is not ready. Run this again after loading into your plot.")
assert(type(loadstring) == "function", "This client must support loadstring and game:HttpGet.")

local Repository = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local function download(path)
    local source = game:HttpGet(Repository .. path)
    local chunk, failure = loadstring(source)
    assert(chunk, failure)
    return chunk()
end

local Library = download("Library.lua")
local Options = Library.Options
local Toggles = Library.Toggles
local Session = {
    Alive = true,
    Connections = {},
    Pending = {},
    Retry = {},
    Logs = {},
    LastRequest = -math.huge,
    NextRequestAt = 0,
    MaintenanceBusy = false,
    ActivityBusy = false,
    OwnTraining = false,
    Phase = "Train",
    ThrowsInCycle = 0,
    NextActivity = 0,
    Started = os.clock(),
    LastError = "None",
    Counts = {},
    Votes = {},
    LastAntiAfk = -math.huge,
    NextOfflineClaim = 0,
    BreakUntil = 0,
    LastJump = -math.huge,
    Stats = { Throws = 0, Placed = 0, Sold = 0, SaleCash = 0, Purchases = 0, Bonuses = 0, Claims = 0 },
}
Environment[SessionKey] = Session

local Window = Library:CreateWindow({
    Title = "Throw Food For Animals",
    Footer = "Obsidian | Automation",
    Icon = "paw-print",
    NotifySide = "Right",
    Center = true,
    AutoShow = true,
    Resizable = true,
    ShowCustomCursor = false,
})

local Tabs = {
    Main = Window:AddTab("Main", "house"),
    Player = Window:AddTab("Player", "user"),
    Misc = Window:AddTab("Misc", "settings"),
}
local MainLeft = Tabs.Main:AddLeftTabbox()
local MainRight = Tabs.Main:AddRightTabbox()
local Farm = MainLeft:AddTab("Throwing")
local Placement = MainLeft:AddTab("Pen")
local Buying = MainLeft:AddTab("Shopping")
local Train = MainRight:AddTab("Training")
local Selling = MainRight:AddTab("Selling")
local Protection = MainRight:AddTab("Keep")
local Budget = MainRight:AddTab("Budget")
local Status = Tabs.Main:AddLeftGroupbox("Your session")
local Preview = Tabs.Main:AddRightGroupbox("What would sell")
local SpeedControls = Tabs.Player:AddLeftGroupbox("Movement")
local Abilities = Tabs.Player:AddRightGroupbox("Jumping & collisions")
local Pacing = Tabs.Misc:AddLeftGroupbox("Pacing")
local Rewards = Tabs.Misc:AddLeftGroupbox("Free rewards")
local Voting = Tabs.Misc:AddRightGroupbox("Admin votes")
local Menu = Tabs.Misc:AddLeftGroupbox("Menu")
local Diagnostics = Tabs.Misc:AddRightGroupbox("Activity log")

Farm:AddToggle("Paused", { Text = "Pause automation", Default = false })
Farm:AddToggle("AutoThrow", { Text = "Auto throw", Default = false })
Farm:AddToggle("PerfectThrow", { Text = "Auto perfect throw", Default = false, Tooltip = "Also handles throws you start yourself." })
Farm:AddSlider("ThrowTarget", { Text = "Normal throw target", Default = 80, Min = 20, Max = 99, Rounding = 0, Suffix = "%" })
Farm:AddSlider("ThrowDelay", { Text = "Delay after throw", Default = 2, Min = 1.5, Max = 15, Rounding = 1, Suffix = "s" })
Farm:AddSlider("ThrowsPerCycle", { Text = "Throws per training cycle", Default = 5, Min = 1, Max = 50, Rounding = 0 })
Train:AddToggle("AutoTrain", { Text = "Auto train on bar", Default = false })
Train:AddToggle("AutoBonus", { Text = "Grab the 2x training boosts", Default = false, Tooltip = "Clicks each boost as it appears while you train." })
Train:AddSlider("TrainingDuration", { Text = "Training session", Default = 60, Min = 10, Max = 600, Rounding = 0, Suffix = "s" })
Train:AddLabel("Turn on throwing and training to switch between them automatically.", true)
Status:AddLabel("ActivityStatus", { Text = "Activity: Idle", DoesWrap = true })
Status:AddLabel("EconomyStatus", { Text = "Loading economy...", DoesWrap = true })
Status:AddLabel("SessionStatus", { Text = "No actions yet", DoesWrap = true })

Placement:AddToggle("AutoPlace", { Text = "Fill my pen automatically", Default = false, Tooltip = "Fills empty spots with your highest earners first." })
Placement:AddToggle("AutoEquipBest", { Text = "Keep my best animals equipped", Default = false, Tooltip = "Swaps weaker animals for stronger earners." })
Placement:AddToggle("AutoEquipFood", { Text = "Auto equip best owned food", Default = false })
Placement:AddSlider("InventoryInterval", { Text = "Check my animals every", Default = 3, Min = 1, Max = 20, Rounding = 0, Suffix = "s" })

local rarityNames = {}
for _, rarity in ipairs(Rarities.List) do
    table.insert(rarityNames, rarity.Name)
end
Selling:AddToggle("AutoSell", { Text = "Auto sell matching animals", Default = false })
Selling:AddDropdown("SellRule", { Text = "Sell when", Values = { "Selected rarity", "Below income minimum", "Either rule", "Both rules" }, Default = 1 })
Selling:AddDropdown("SellRarities", { Text = "Rarities to sell", Values = rarityNames, Multi = true, Searchable = true })
Selling:AddInput("MinimumIncome", { Text = "Keep at least $/second", Default = "0", Numeric = false, Finished = true, ClearTextOnFocus = false, Tooltip = "Below this value is eligible. Accepts 1500, 1.5k, 2m, 3b, 4t, 1e30." })
Selling:AddDropdown("IncomeBasis", { Text = "Income used by filter", Values = { "Base income", "With current cash multiplier" }, Default = 1 })
Selling:AddToggle("SellPlaced", { Text = "Include placed animals", Default = false })
Selling:AddSlider("SaleBatch", { Text = "Maximum sales per upkeep", Default = 3, Min = 1, Max = 15, Rounding = 0 })
Protection:AddToggle("KeepBest", { Text = "Keep my best pen lineup", Default = true, Tooltip = "Protects your top earners up to the current pen capacity, even when they are in your backpack." })
Protection:AddToggle("KeepEvent", { Text = "Keep event and Dream animals", Default = true })
Protection:AddToggle("KeepMutated", { Text = "Keep mutated animals", Default = true })
Protection:AddInput("KeepModels", { Text = "Always keep these animals", Default = "", Finished = true, ClearTextOnFocus = false, Tooltip = "Enter model names separated by commas. Capitalization does not matter." })
Protection:AddLabel("Purchased animals and animals marked locked or favorite are always kept.", true)
Preview:AddLabel("SalePreview", { Text = "No matching animals", DoesWrap = true })

Buying:AddToggle("AutoBuyFood", { Text = "Auto buy new food", Default = false })
Buying:AddDropdown("FoodStrategy", { Text = "Food purchase order", Values = { "Next upgrade", "Best affordable" }, Default = 1 })
Buying:AddToggle("AutoBuyBar", { Text = "Auto buy / upgrade bar", Default = false })
Buying:AddToggle("AutoUpgradePen", { Text = "Auto upgrade pen capacity", Default = false })
Buying:AddSlider("PurchaseInterval", { Text = "Purchase check interval", Default = 4, Min = 2, Max = 30, Rounding = 0, Suffix = "s" })
Budget:AddInput("CashReserve", { Text = "Cash to keep", Default = "0", Finished = true, ClearTextOnFocus = false })
Budget:AddSlider("MaxSpendPercent", { Text = "Max cash per purchase", Default = 100, Min = 1, Max = 100, Rounding = 0, Suffix = "%" })
Budget:AddLabel("UpgradeStatus", { Text = "Loading upgrade prices...", DoesWrap = true })

SpeedControls:AddToggle("CustomWalkSpeed", { Text = "Custom walkspeed", Default = false })
SpeedControls:AddSlider("WalkSpeed", { Text = "Walkspeed", Default = 16, Min = 0, Max = 200, Rounding = 0, Suffix = " studs/s" })
SpeedControls:AddToggle("CustomJumpPower", { Text = "Custom jump speed", Default = false })
SpeedControls:AddSlider("JumpPower", { Text = "Jump speed / power", Default = 50, Min = 0, Max = 250, Rounding = 0 })
SpeedControls:AddToggle("CFrameMovement", { Text = "CFrame movement", Default = false })
SpeedControls:AddSlider("CFrameSpeed", { Text = "Extra CFrame speed", Default = 30, Min = 0, Max = 200, Rounding = 0, Suffix = " studs/s", Tooltip = "Adds movement in the direction you are walking. Works with keyboard, controller, and the mobile thumbstick." })
SpeedControls:AddLabel("Movement settings pause during throws and training, then return when you are free to move.", true)
Abilities:AddToggle("InfiniteJump", { Text = "Infinite jump", Default = false })
Abilities:AddToggle("Noclip", { Text = "Noclip", Default = false })
Abilities:AddLabel("Turning these off restores your usual movement and collisions. They also work after respawning.", true)

Pacing:AddToggle("NaturalPacing", { Text = "Use natural pacing", Default = true, Tooltip = "Adds small variations to waits, training sessions, shopping checks, and boost reactions." })
Pacing:AddSlider("TimingVariation", { Text = "Timing variation", Default = 25, Min = 0, Max = 50, Rounding = 0, Suffix = "%" })
Pacing:AddToggle("ShortBreaks", { Text = "Take short breaks", Default = true })
Pacing:AddSlider("BreakEvery", { Text = "Break after about", Default = 25, Min = 5, Max = 100, Rounding = 0, Suffix = " throws" })
Pacing:AddSlider("BreakLength", { Text = "Break length", Default = 12, Min = 3, Max = 60, Rounding = 0, Suffix = "s" })

Rewards:AddToggle("AutoOffline", { Text = "Auto claim offline cash", Default = false })
Rewards:AddToggle("AutoIndex", { Text = "Auto claim Index rewards", Default = false })
Rewards:AddToggle("AntiAfk", { Text = "Anti-AFK", Default = false, Tooltip = "Sends a brief input every 50 seconds to reset Roblox and the game's idle detection." })
Rewards:AddLabel("Index rewards claim automatically. You can still choose which trail to wear.", true)
local voteNames = { "Most votes", "Random" }
for index, name in ipairs(Admin.Config.Vote.Names or {}) do
    table.insert(voteNames, tostring(index) .. ": " .. name)
end
Voting:AddToggle("AutoVote", { Text = "Auto vote during admin events", Default = false })
Voting:AddDropdown("VoteChoice", { Text = "Vote for", Values = voteNames, Default = 1 })
Voting:AddSlider("VoteDelay", { Text = "Wait after voting opens", Default = 5, Min = 0, Max = 60, Rounding = 0, Suffix = "s" })
Voting:AddLabel("VoteStatus", { Text = "Waiting for a vote", DoesWrap = true })

Menu:AddLabel("Menu key"):AddKeyPicker("MenuKey", { Default = "RightShift", NoUI = true, Text = "Menu key" })
Library.ToggleKeybind = Options.MenuKey
Diagnostics:AddLabel("LastAction", { Text = "Last action: Ready", DoesWrap = true })
Diagnostics:AddLabel("LastError", { Text = "Last error: None", DoesWrap = true })

local function enabled(name)
    return Session.Alive and not Toggles.Paused.Value and Toggles[name] and Toggles[name].Value == true
end

local function paced(seconds, minimum)
    if not Toggles.NaturalPacing.Value then
        return math.max(minimum or 0, seconds)
    end
    local spread = Options.TimingVariation.Value / 100
    local variation = (math.random() + math.random()) / 2
    return math.max(minimum or 0, seconds * (1 - spread + variation * spread * 2))
end

local function reactionDelay()
    return Toggles.NaturalPacing.Value and paced(0.4, 0.15) or 0
end

local function log(message, failure)
    local line = os.date("%H:%M:%S") .. " " .. tostring(message)
    table.insert(Session.Logs, line)
    if #Session.Logs > 60 then
        table.remove(Session.Logs, 1)
    end
    if Session.Alive then
        Options.LastAction:SetText("Last action: " .. tostring(message))
        if failure then
            Session.LastError = tostring(message)
            Options.LastError:SetText("Last error: " .. Session.LastError)
        end
    end
end

local function notify(message)
    if Session.Alive then
        Library:Notify(tostring(message), 5)
    end
end

local suffixes = { k = 1e3, m = 1e6, b = 1e9, t = 1e12, qa = 1e15, qi = 1e18, sx = 1e21, sp = 1e24, oc = 1e27, no = 1e30, dc = 1e33 }
local function amount(text)
    local value = tostring(text or ""):lower():gsub("[%s,$]", "")
    local parsed = tonumber(value)
    if not parsed then
        local digits, suffix = value:match("^([%d%.]+)(%a+)$")
        if digits and suffixes[suffix] then
            parsed = tonumber(digits) and tonumber(digits) * suffixes[suffix]
        end
    end
    if not parsed or parsed < 0 or parsed ~= parsed or parsed == math.huge then
        return nil
    end
    return parsed
end

local function format(value)
    value = tonumber(value) or 0
    if math.abs(value) >= 1e15 then
        return string.format("%.3g", value)
    end
    for _, scale in ipairs({ { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }) do
        if math.abs(value) >= scale[1] then
            return string.format("%.2f%s", value / scale[1], scale[2])
        end
    end
    return string.format("%.0f", value)
end

local function profile()
    return Data:GetPlayerData()
end

local function bestIncome(data)
    return tonumber(Player:GetAttribute("BestIncome")) or Mutations.BestIncome(data.Animals or {})
end

local function income(entry, data)
    local result = Mutations.IncomeOf(entry, bestIncome(data))
    if type(result) ~= "number" or result ~= result or result < 0 then
        return nil
    end
    return result
end

local function sortedAnimals(data)
    local result = {}
    for id, entry in pairs(data.Animals or {}) do
        if type(entry) == "table" and type(entry.ModelName) == "string" then
            local rate = income(entry, data)
            if rate then
                table.insert(result, { Id = id, Entry = entry, Income = rate })
            end
        end
    end
    table.sort(result, function(a, b)
        if a.Income == b.Income then
            if (a.Entry.Placed == true) ~= (b.Entry.Placed == true) then
                return a.Entry.Placed == true
            end
            return tostring(a.Id) < tostring(b.Id)
        end
        return a.Income > b.Income
    end)
    return result
end

local function saleCandidates(data)
    local threshold = amount(Options.MinimumIncome.Value)
    local rule = Options.SellRule.Value
    local needsIncome = rule ~= "Selected rarity"
    if needsIncome and not threshold then
        return {}, "Invalid income minimum"
    end
    local selected = Options.SellRarities.Value or {}
    local protectedModels = {}
    for model in tostring(Options.KeepModels.Value or ""):gmatch("[^,]+") do
        protectedModels[model:match("^%s*(.-)%s*$"):lower()] = true
    end
    local ordered = sortedAnimals(data)
    local keepIds = {}
    if Toggles.KeepBest.Value then
        for index = 1, math.min(#ordered, Fence.SlotsFor(data.FenceLevel or 0)) do
            keepIds[ordered[index].Id] = true
        end
    end
    local candidates = {}
    for _, animal in ipairs(ordered) do
        local entry = animal.Entry
        local info = Economy.Get(entry.ModelName)
        local protected = keepIds[animal.Id] or entry.Bought or entry.Locked or entry.Favorite or entry.Favourited or protectedModels[entry.ModelName:lower()]
        if entry.Placed and not Toggles.SellPlaced.Value then
            protected = true
        end
        if Toggles.KeepEvent.Value and (entry.Dream or #Mutations.EventOnlyNames(entry) > 0) then
            protected = true
        end
        local mutation = tostring(entry.Mutation or ""):lower()
        if Toggles.KeepMutated.Value and mutation ~= "" and mutation ~= "none" and mutation ~= "normal" then
            protected = true
        end
        if not protected and info and type(info.Rarity) == "string" then
            local rareMatch = selected[info.Rarity] == true
            local rate = animal.Income
            if Options.IncomeBasis.Value == "With current cash multiplier" then
                rate = rate * (Player:GetAttribute("CashMultiplier") or 1)
            end
            local lowIncome = threshold and threshold > 0 and rate < threshold or false
            local matches = (rule == "Selected rarity" and rareMatch)
                or (rule == "Below income minimum" and lowIncome)
                or (rule == "Either rule" and (rareMatch or lowIncome))
                or (rule == "Both rules" and rareMatch and lowIncome)
            if matches then
                animal.Rarity = info.Rarity
                animal.FilterIncome = rate
                table.insert(candidates, animal)
            end
        end
    end
    table.sort(candidates, function(a, b)
        if a.Income == b.Income then
            return tostring(a.Id) < tostring(b.Id)
        end
        return a.Income < b.Income
    end)
    return candidates
end

local function invoke(name, ...)
    if not Session.Alive then
        return { Ok = false, Reason = "Unloaded" }
    end
    local args = table.pack(...)
    local key = name .. ":" .. tostring(args[1] or "")
    if Session.Pending[name] then
        return { Ok = false, Reason = "Pending" }
    end
    local retry = Session.Retry[key]
    if retry and os.clock() < retry.At then
        return { Ok = false, Reason = "Backoff" }
    end
    local remote = Remotes:FindFirstChild(name)
    if not remote or not remote:IsA("RemoteFunction") then
        log("Missing RemoteFunction " .. name, true)
        return { Ok = false, Reason = "MissingRemote" }
    end
    local request = { Done = false }
    Session.Pending[name] = request
    local sendAt = math.max(os.clock(), Session.NextRequestAt)
    Session.NextRequestAt = sendAt + paced(0.5, 0.35)
    local gap = sendAt - os.clock()
    if gap > 0 then
        task.wait(gap)
    end
    if not Session.Alive or Toggles.Paused.Value then
        Session.Pending[name] = nil
        return { Ok = false, Reason = "Paused" }
    end
    Session.LastRequest = os.clock()
    task.spawn(function()
        local ok, response = pcall(remote.InvokeServer, remote, table.unpack(args, 1, args.n))
        request.Response = ok and type(response) == "table" and response or { Ok = false, Reason = ok and "BadResponse" or tostring(response) }
        request.Done = true
        if Session.Pending[name] == request then
            Session.Pending[name] = nil
        end
    end)
    local deadline = os.clock() + 10
    while Session.Alive and not request.Done and os.clock() < deadline do
        task.wait(0.05)
    end
    local response = request.Response or { Ok = false, Reason = "Timeout" }
    if response.Ok then
        Session.Retry[key] = nil
        log(name .. " succeeded")
    else
        local failures = (retry and retry.Failures or 0) + 1
        Session.Retry[key] = { Failures = failures, At = os.clock() + math.min(60, 2 ^ math.min(failures, 6)) }
        log(name .. ": " .. tostring(response.Reason), true)
    end
    return response
end

local function aliveCharacter()
    local character = Player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    return character and humanoid and humanoid.Health > 0
end

local function menuOpen()
    return ClientState.ShopOpen or ClientState.ExclusiveShopOpen or ClientState.IndexOpen
        or ClientState.AnimalsOpen or ClientState.SellOpen or ClientState.InventoryOpen
        or ClientState.ProtectedSellOpen or ClientState.TutorialActive or ClientState.ReleaseShow
end

local function idle()
    return aliveCharacter() and not ClientState.Busy and not Session.ActivityBusy
        and not ClientState.OfflineOpen and not menuOpen()
end

local originalMeterRun = Meter.Run
local originalAutoTap = Meter.TestAutoTap
local meterWrapper
meterWrapper = function(self, ...)
    local automate = enabled("PerfectThrow") or enabled("AutoThrow")
    local previous = Meter.TestAutoTap
    if automate then
        local target = enabled("PerfectThrow") and 0.995 or Options.ThrowTarget.Value / 100
        local speed = GameConfig.Throw.MeterBaseSpeed or 1
        local acceleration = (GameConfig.Throw.MeterTopSpeedFactor or 1) - 1
        local delay = acceleration > 0 and math.log(1 + acceleration * target) / (speed * acceleration) or target / speed
        if delay <= 0.35 then
            delay = MeterMath.HalfPeriod() * 2 - delay
        end
        Meter.TestAutoTap = delay
    end
    local result = table.pack(pcall(originalMeterRun, self, ...))
    if Session.Alive and Meter.Run == meterWrapper then
        Meter.TestAutoTap = previous
    end
    if not result[1] then
        error(result[2], 0)
    end
    return table.unpack(result, 2, result.n)
end
Meter.Run = meterWrapper

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(Session.Connections, connection)
    return connection
end

local MovementState = { Parts = {} }

local function restoreCollisions()
    for part, canCollide in pairs(MovementState.Parts) do
        pcall(function()
            part.CanCollide = canCollide
        end)
    end
    MovementState.Parts = {}
end

local function restoreMovement()
    local humanoid = MovementState.Humanoid
    if humanoid then
        pcall(function()
            if MovementState.WalkSpeed ~= nil then
                humanoid.WalkSpeed = MovementState.WalkSpeed
            end
            if MovementState.JumpPower ~= nil then
                humanoid.JumpPower = MovementState.JumpPower
                humanoid.JumpHeight = MovementState.JumpHeight
                humanoid.UseJumpPower = MovementState.UseJumpPower
            end
        end)
    end
    MovementState.WalkSpeed = nil
    MovementState.JumpPower = nil
    MovementState.JumpHeight = nil
    MovementState.UseJumpPower = nil
    MovementState.Humanoid = nil
    restoreCollisions()
end

local function canMove(character, humanoid, root)
    return Session.Alive and not Toggles.Paused.Value and character and humanoid and root
        and humanoid.Health > 0 and not root.Anchored and not humanoid.Sit
        and not humanoid.PlatformStand and not Session.MovementSuspended
        and not ClientState.Busy and not ClientState.OfflineOpen and not menuOpen()
        and not Movement.IsLocked()
end

local function updateMovement(delta)
    local character = Player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if humanoid ~= MovementState.Humanoid and MovementState.Humanoid then
        restoreMovement()
    end
    if not canMove(character, humanoid, root) then
        restoreMovement()
        return
    end
    MovementState.Humanoid = humanoid
    if enabled("CustomWalkSpeed") then
        if MovementState.WalkSpeed == nil then
            MovementState.WalkSpeed = humanoid.WalkSpeed
        end
        humanoid.WalkSpeed = Options.WalkSpeed.Value
    elseif MovementState.WalkSpeed ~= nil then
        humanoid.WalkSpeed = MovementState.WalkSpeed
        MovementState.WalkSpeed = nil
    end
    if enabled("CustomJumpPower") then
        if MovementState.JumpPower == nil then
            MovementState.JumpPower = humanoid.JumpPower
            MovementState.JumpHeight = humanoid.JumpHeight
            MovementState.UseJumpPower = humanoid.UseJumpPower
        end
        humanoid.UseJumpPower = true
        humanoid.JumpPower = Options.JumpPower.Value
    elseif MovementState.JumpPower ~= nil then
        humanoid.JumpPower = MovementState.JumpPower
        humanoid.JumpHeight = MovementState.JumpHeight
        humanoid.UseJumpPower = MovementState.UseJumpPower
        MovementState.JumpPower = nil
        MovementState.JumpHeight = nil
        MovementState.UseJumpPower = nil
    end
    if enabled("Noclip") then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                if MovementState.Parts[part] == nil then
                    MovementState.Parts[part] = part.CanCollide
                end
                part.CanCollide = false
            end
        end
    else
        restoreCollisions()
    end
    if enabled("CFrameMovement") and not UserInput:GetFocusedTextBox() then
        local direction = humanoid.MoveDirection
        if direction.Magnitude > 0 then
            root.CFrame = root.CFrame + direction * Options.CFrameSpeed.Value * math.min(math.max(delta or 0, 0), 0.1)
        end
    end
end

local originalMovementLock = Movement.Lock
local movementLockWrapper
movementLockWrapper = function(...)
    Session.MovementSuspended = true
    restoreMovement()
    local result = table.pack(pcall(originalMovementLock, ...))
    Session.MovementSuspended = false
    if not result[1] then
        error(result[2], 0)
    end
    return table.unpack(result, 2, result.n)
end
Movement.Lock = movementLockWrapper

connect(RunService.Stepped, function(_, delta)
    local ok, failure = pcall(updateMovement, delta)
    if not ok and os.clock() >= (Session.NextMovementError or 0) then
        Session.NextMovementError = os.clock() + 5
        log("Movement: " .. tostring(failure), true)
    end
end)

connect(UserInput.JumpRequest, function()
    local character = Player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if enabled("InfiniteJump") and canMove(character, humanoid, root)
        and not UserInput:GetFocusedTextBox() and os.clock() - Session.LastJump >= 0.12 then
        Session.LastJump = os.clock()
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

for _, name in ipairs({ "CustomWalkSpeed", "CustomJumpPower", "CFrameMovement", "InfiniteJump", "Noclip" }) do
    Toggles[name]:OnChanged(function()
        updateMovement(0)
    end)
end
for _, name in ipairs({ "WalkSpeed", "JumpPower", "CFrameSpeed" }) do
    Options[name]:OnChanged(function()
        updateMovement(0)
    end)
end

Abilities:AddButton({ Text = "Reset my movement", Func = function()
    for _, name in ipairs({ "CustomWalkSpeed", "CustomJumpPower", "CFrameMovement", "InfiniteJump", "Noclip" }) do
        Toggles[name]:SetValue(false)
    end
    restoreMovement()
end })

connect(Throw.Finished, function()
    if Session.Alive then
        Session.Stats.Throws = Session.Stats.Throws + 1
        Session.ThrowsInCycle = Session.ThrowsInCycle + 1
        if Toggles.ShortBreaks.Value and Session.Stats.Throws >= (Session.NextBreakAt or Options.BreakEvery.Value) then
            local duration = paced(Options.BreakLength.Value, 1)
            Session.BreakUntil = os.clock() + duration
            Session.NextBreakAt = Session.Stats.Throws + math.max(1, math.floor(paced(Options.BreakEvery.Value, 1) + 0.5))
            log("Taking a breather for " .. math.floor(duration + 0.5) .. " seconds")
        end
    end
end)

local clickedButtons = setmetatable({}, { __mode = "k" })
local bonusReadyAt = setmetatable({}, { __mode = "k" })
local pendingBonus
local function clickBonus()
    if not enabled("AutoBonus") or not Training.IsRunning() then
        return
    end
    local gui = Player:FindFirstChild("PlayerGui")
    local sequence = gui and gui:FindFirstChild("TrainingSequence")
    local layer = sequence and sequence:FindFirstChild("TapBonusLayer", true)
    local button = layer and layer:FindFirstChild("TapBonus")
    if button and button:IsA("GuiButton") and button.Visible and button.Active and not clickedButtons[button] then
        if not bonusReadyAt[button] then
            bonusReadyAt[button] = os.clock() + reactionDelay()
        end
        if os.clock() < bonusReadyAt[button] then
            return
        end
        if type(firesignal) == "function" then
            clickedButtons[button] = true
            local ok, failure = pcall(firesignal, button.Activated)
            if ok then
                Session.Stats.Bonuses = Session.Stats.Bonuses + 1
                pendingBonus = nil
                log("Clicked training boost")
            else
                clickedButtons[button] = nil
                log(failure, true)
            end
        elseif pendingBonus and pendingBonus.Expires > workspace:GetServerTimeNow() then
            local bonus = pendingBonus
            pendingBonus = nil
            local response = invoke("Training_TapBonus", bonus.Id)
            if response.Ok then
                Session.Stats.Bonuses = Session.Stats.Bonuses + 1
                clickedButtons[button] = true
                button.Visible = false
            end
        end
    end
end

local bonusEvent = Remotes:FindFirstChild("Training_Bonus")
if bonusEvent then
    connect(bonusEvent.OnClientEvent, function(id, expires)
        if type(expires) == "number" then
            pendingBonus = { Id = id, Expires = expires }
        end
    end)
end

local voteStateEvent = Remotes:FindFirstChild("AdminAbuse_VoteState")
if voteStateEvent then
    connect(voteStateEvent.OnClientEvent, function(state)
        if type(state) == "table" and type(state.Counts) == "table" then
            Session.Counts = state.Counts
        end
    end)
end

local function vote()
    local clock = Admin.Clock()
    local state = Admin.State(clock)
    if not state.VoteOpen then
        Options.VoteStatus:SetText("Waiting for a vote")
        return
    end
    Options.VoteStatus:SetText("Voting open | " .. Options.VoteChoice.Value)
    if not enabled("AutoVote") then
        return
    end
    local count = #Admin.Config.Vote.Images
    if count < 1 then
        return
    end
    local delay = Options.VoteDelay.Value
    local elapsed = Admin.RealSeconds(clock - (Admin.VoteOpenT or clock))
    local remaining = Admin.RealSeconds((Admin.VoteCloseT or clock) - clock)
    if elapsed < delay and remaining > 2 then
        return
    end
    local run = tostring(Admin.Start()) .. ":" .. tostring(Admin.Run())
    local selection = Options.VoteChoice.Value
    local key = run .. ":" .. selection
    if Session.Votes[key] then
        return
    end
    local choice = tonumber(selection:match("^(%d+):"))
    if selection == "Random" then
        choice = math.random(1, count)
    elseif selection == "Most votes" then
        local leaders = {}
        local highest = -1
        for index = 1, count do
            local votes = tonumber(Session.Counts[index] or Session.Counts[tostring(index)]) or 0
            if votes > highest then
                highest = votes
                leaders = { index }
            elseif votes == highest then
                table.insert(leaders, index)
            end
        end
        choice = leaders[math.random(1, #leaders)]
    end
    local remote = Remotes:FindFirstChild("AdminAbuse_Vote")
    if choice and choice <= count and remote then
        remote:FireServer(choice)
        Session.Votes[key] = true
        log("Voted for " .. tostring((Admin.Config.Vote.Names or {})[choice] or choice))
    end
end

local function antiAfk()
    if not enabled("AntiAfk") or os.clock() - Session.LastAntiAfk < 50 then
        return
    end
    Session.LastAntiAfk = os.clock()
    if VirtualInput then
        local sent = pcall(function()
            VirtualInput:SendKeyEvent(true, Enum.KeyCode.LeftControl, false, game)
            VirtualInput:SendKeyEvent(false, Enum.KeyCode.LeftControl, false, game)
        end)
        if sent then
            return
        end
    end
    local camera = workspace.CurrentCamera
    if not camera then
        return
    end
    VirtualUser:CaptureController()
    VirtualUser:Button2Down(Vector2.new(0, 0), camera.CFrame)
    VirtualUser:Button2Up(Vector2.new(0, 0), camera.CFrame)
end
connect(Player.Idled, function()
    Session.LastAntiAfk = -math.huge
    local ok, failure = pcall(antiAfk)
    if not ok then
        log(failure, true)
    end
end)

local function affordable(price, data)
    local reserve = amount(Options.CashReserve.Value)
    if not reserve then
        return false
    end
    local cash = tonumber(data.Money) or 0
    return type(price) == "number" and price >= 0 and price <= cash - reserve
        and price <= cash * Options.MaxSpendPercent.Value / 100
end

local function bestFood(data)
    local best = 0
    for _, food in ipairs(Foods.List) do
        local owned = data.OwnedFoods or {}
        if owned[food.Index] == true or owned[tostring(food.Index)] == true then
            best = math.max(best, food.Index)
        end
    end
    return best
end

local function buyFood()
    if not enabled("AutoBuyFood") then
        return
    end
    local data = profile()
    local best = bestFood(data)
    local choices = {}
    for _, food in ipairs(Foods.List) do
        if food.Index > best then
            table.insert(choices, food)
        end
    end
    table.sort(choices, function(a, b)
        return a.Index < b.Index
    end)
    local target
    for _, food in ipairs(choices) do
        if affordable(Curve.GetItemPrice(Player, food), data) then
            target = food
        end
        if Options.FoodStrategy.Value == "Next upgrade" then
            break
        end
    end
    if target then
        local response = invoke("Shop_Buy", target.Index)
        if response.Ok then
            Session.Stats.Purchases = Session.Stats.Purchases + 1
            invoke("Shop_Equip", target.Index)
        end
    end
end

local function buyBar()
    if enabled("AutoBuyBar") then
        local data = profile()
        local target = Stands.Get((data.Stand or 0) + 1)
        if target and affordable(Curve.GetItemPrice(Player, target), data) then
            if invoke("Stand_Upgrade").Ok then
                Session.Stats.Purchases = Session.Stats.Purchases + 1
            end
        end
    end
end

local function upgradePen()
    if enabled("AutoUpgradePen") then
        local data = profile()
        local target = Fence.Get((data.FenceLevel or 0) + 1)
        if target and affordable(target.Price, data) then
            if invoke("Plot_UpgradeFence").Ok then
                Session.Stats.Purchases = Session.Stats.Purchases + 1
            end
        end
    end
end

local function equipFood()
    if enabled("AutoEquipFood") then
        local data = profile()
        local target = bestFood(data)
        if target > 0 and target ~= data.EquippedFood then
            invoke("Shop_Equip", target)
        end
    end
end

local function equipBestNeeded(data)
    local sorted = sortedAnimals(data)
    local slots = Fence.SlotsFor(data.FenceLevel or 0)
    local wanted = {}
    for index = 1, math.min(slots, #sorted) do
        wanted[sorted[index].Id] = true
    end
    for _, animal in ipairs(sorted) do
        if (animal.Entry.Placed == true) ~= (wanted[animal.Id] == true) then
            return true
        end
    end
    return false
end

local function maintainAnimals()
    local data = profile()
    if enabled("AutoSell") then
        local candidates, failure = saleCandidates(data)
        if failure then
            log(failure, true)
            return
        end
        for index = 1, math.min(#candidates, Options.SaleBatch.Value) do
            if not enabled("AutoSell") then
                return
            end
            local target = candidates[index]
            local fresh = saleCandidates(profile())
            local valid = false
            for _, current in ipairs(fresh) do
                if current.Id == target.Id then
                    valid = true
                    break
                end
            end
            if valid then
                local response = invoke("Plot_SellAnimal", target.Id)
                if response.Ok then
                    Session.Stats.Sold = Session.Stats.Sold + 1
                    Session.Stats.SaleCash = Session.Stats.SaleCash + (tonumber(response.Money) or 0)
                end
            end
        end
    end
    data = profile()
    if enabled("AutoEquipBest") and equipBestNeeded(data) then
        local response = invoke("Plot_EquipBest")
        if response.Ok then
            Session.Stats.Placed = Session.Stats.Placed + (tonumber(response.Placed) or 0)
        end
    elseif enabled("AutoPlace") then
        local count = 0
        local target
        for _, animal in ipairs(sortedAnimals(data)) do
            if animal.Entry.Placed then
                count = count + 1
            elseif not target then
                target = animal
            end
        end
        if count < Fence.SlotsFor(data.FenceLevel or 0) and target then
            if invoke("Plot_EquipAnimal", target.Id).Ok then
                Session.Stats.Placed = Session.Stats.Placed + 1
            end
        end
    end
end

local function claimOffline()
    local data = profile()
    local pending = data.OfflinePending and (tonumber(data.OfflinePending.Base) or 0) or 0
    if Session.OfflineUIClaimPending and pending <= 0 then
        Session.Stats.Claims = Session.Stats.Claims + 1
        Session.OfflineUIClaimPending = false
    end
    if enabled("AutoOffline") and pending > 0 and os.clock() >= Session.NextOfflineClaim then
        if Offline.IsOpen() then
            Session.NextOfflineClaim = os.clock() + 10
            Session.OfflineUIClaimPending = true
            Offline.Claim()
            log("Requested offline cash through the popup")
        elseif not ClientState.Busy then
            Session.NextOfflineClaim = os.clock() + 10
            if invoke("Offline_Claim").Ok then
                Session.OfflineUIClaimPending = false
                Session.Stats.Claims = Session.Stats.Claims + 1
            end
        end
    end
end

local function claimIndex()
    if enabled("AutoIndex") then
        local claimable = IndexRewards.Claimable(profile())
        if claimable[1] and invoke("IndexRewards_Claim", claimable[1]).Ok then
            Session.Stats.Claims = Session.Stats.Claims + 1
        end
    end
end

local upkeepJobs = {
    { Run = maintainAnimals, Interval = function() return Options.InventoryInterval.Value end, At = 0 },
    { Run = buyFood, Interval = function() return Options.PurchaseInterval.Value end, At = 0 },
    { Run = buyBar, Interval = function() return Options.PurchaseInterval.Value end, At = 0 },
    { Run = upgradePen, Interval = function() return Options.PurchaseInterval.Value end, At = 0 },
    { Run = equipFood, Interval = function() return Options.PurchaseInterval.Value end, At = 0 },
    { Run = claimIndex, Interval = function() return 10 end, At = 0 },
}

local function runUpkeep()
    if not idle() or Session.MaintenanceBusy then
        return
    end
    Session.MaintenanceBusy = true
    for _, job in ipairs(upkeepJobs) do
        if not Session.Alive or Toggles.Paused.Value or not idle() then
            break
        end
        if os.clock() >= job.At then
            job.At = os.clock() + paced(job.Interval(), 0.5)
            local ok, failure = pcall(job.Run)
            if not ok then
                log(failure, true)
            end
        end
    end
    Session.MaintenanceBusy = false
end

local function activity()
    if Session.OwnTraining and Training.IsRunning() then
        local expired = os.clock() - (Session.TrainStarted or os.clock()) >= (Session.TrainDuration or Options.TrainingDuration.Value)
        if not enabled("AutoTrain") or expired then
            Training.Stop()
            Session.NextActivity = os.clock() + paced(2, 1)
            if enabled("AutoThrow") then
                Session.Phase = "Throw"
                Session.ThrowsInCycle = 0
                Session.CycleQuota = math.max(1, math.floor(paced(Options.ThrowsPerCycle.Value, 1) + 0.5))
            else
                Session.Phase = "Train"
            end
        end
        return
    end
    if not idle() or Session.MaintenanceBusy or os.clock() < Session.NextActivity or os.clock() < Session.BreakUntil then
        return
    end
    local autoThrow = enabled("AutoThrow")
    local autoTrain = enabled("AutoTrain")
    if not autoThrow and not autoTrain then
        return
    end
    if autoThrow and autoTrain and Session.Phase == "Throw" and Session.ThrowsInCycle >= (Session.CycleQuota or Options.ThrowsPerCycle.Value) then
        Session.Phase = "Train"
    end
    local train = autoTrain and (not autoThrow or Session.Phase == "Train")
    if train and (profile().Stand or 0) < 1 then
        if autoThrow then
            train = false
        else
            return
        end
    end
    Session.ActivityBusy = true
    Session.NextActivity = os.clock() + 2
    task.spawn(function()
        local delay = reactionDelay()
        if delay > 0 then
            task.wait(delay)
        end
        if not Session.Alive or Toggles.Paused.Value or not enabled(train and "AutoTrain" or "AutoThrow") then
            Session.ActivityBusy = false
            return
        end
        if train then
            Session.OwnTraining = true
            Session.TrainStarted = os.clock()
            Session.TrainDuration = paced(Options.TrainingDuration.Value, 5)
            local ok, failure = pcall(Training.Start)
            Session.OwnTraining = false
            if not ok then
                log(failure, true)
            end
        else
            local ok, failure = pcall(Throw.Start)
            if not ok then
                log(failure, true)
            end
        end
        Session.ActivityBusy = false
        Session.NextActivity = os.clock() + paced(train and 2 or Options.ThrowDelay.Value, train and 1 or 1.5)
    end)
end

local function refreshStatus()
    local data = profile()
    if not data then
        return
    end
    local placed, total = 0, 0
    for _, animal in pairs(data.Animals or {}) do
        total = total + 1
        if animal.Placed then
            placed = placed + 1
        end
    end
    local mode = Toggles.Paused.Value and "Paused" or tostring(ClientState.Busy or "Idle")
    if not Toggles.Paused.Value and not ClientState.Busy and os.clock() < Session.BreakUntil then
        mode = "Taking a breather (" .. math.ceil(Session.BreakUntil - os.clock()) .. "s)"
    end
    Options.ActivityStatus:SetText("Activity: " .. mode .. " | Cycle: " .. Session.Phase)
    Options.EconomyStatus:SetText("Cash: $" .. format(data.Money) .. "\nPen: " .. placed .. "/" .. Fence.SlotsFor(data.FenceLevel or 0) .. " | Backpack: " .. (total - placed))
    local stats = Session.Stats
    Options.SessionStatus:SetText("Throws: " .. stats.Throws .. " | Placed: " .. stats.Placed .. "\nSold: " .. stats.Sold .. " ($" .. format(stats.SaleCash) .. ")\nPurchases: " .. stats.Purchases .. " | Boosts: " .. stats.Bonuses)
    local candidates, failure = saleCandidates(data)
    local lines = {}
    if failure then
        lines[1] = failure
    else
        local value = 0
        for index, animal in ipairs(candidates) do
            value = value + Mutations.SellPrice(animal.Entry, bestIncome(data))
            if index <= 6 then
                table.insert(lines, animal.Entry.ModelName .. " | " .. animal.Rarity .. " | $" .. format(animal.FilterIncome) .. "/s")
            end
        end
        table.insert(lines, 1, #candidates .. " matching | Estimated sale: $" .. format(value))
        if #candidates > 6 then
            table.insert(lines, "+" .. (#candidates - 6) .. " more")
        end
    end
    Options.SalePreview:SetText(table.concat(lines, "\n"))
    local bar = Stands.Get((data.Stand or 0) + 1)
    local fence = Fence.Get((data.FenceLevel or 0) + 1)
    local food = Foods.Get(bestFood(data) + 1)
    Options.UpgradeStatus:SetText("Next food: " .. (food and food.Name .. " ($" .. format(Curve.GetItemPrice(Player, food)) .. ")" or "Max")
        .. "\nNext bar: " .. (bar and bar.Name .. " ($" .. format(Curve.GetItemPrice(Player, bar)) .. ")" or "Max")
        .. "\nNext pen: " .. (fence and fence.Slots .. " slots ($" .. format(fence.Price) .. ")" or "Max"))
end

local function oneShot(action)
    if not idle() or Session.MaintenanceBusy or Toggles.Paused.Value then
        notify("Pause your activity and close game menus before using this action.")
        return
    end
    Session.MaintenanceBusy = true
    task.spawn(function()
        local ok, failure = pcall(action)
        Session.MaintenanceBusy = false
        if not ok then
            log(failure, true)
            notify(failure)
        end
    end)
end

Placement:AddButton({ Text = "Equip best now", Func = function()
    oneShot(function() invoke("Plot_EquipBest") end)
end })
Placement:AddButton({ Text = "Go to my pen entrance", Func = function()
    oneShot(function()
        local part = Plot.GetPlotPart()
        if part and Player.Character then
            local position = part.Position + GameConfig.Plot.EntranceOffset
            Player.Character:PivotTo(CFrame.lookAt(position, position - Vector3.new(0, 0, 1)))
        end
    end)
end })
Preview:AddButton({ Text = "Refresh sale preview", Func = function()
    local ok, failure = pcall(refreshStatus)
    if not ok then notify(failure) end
end })
Menu:AddButton({ Text = "Stop everything", Func = function()
    for _, name in ipairs({ "AutoThrow", "PerfectThrow", "AutoTrain", "AutoBonus", "AutoPlace", "AutoEquipBest", "AutoEquipFood", "AutoSell", "AutoBuyFood", "AutoBuyBar", "AutoUpgradePen", "AutoOffline", "AutoIndex", "AntiAfk", "AutoVote", "CustomWalkSpeed", "CustomJumpPower", "CFrameMovement", "InfiniteJump", "Noclip" }) do
        Toggles[name]:SetValue(false)
    end
    if Session.OwnTraining then
        Training.Stop()
    end
    Session.BreakUntil = 0
    notify("Automation stopped. An active throw will finish normally.")
end })
Diagnostics:AddButton({ Text = "Copy action log", Func = function()
    if type(setclipboard) == "function" then
        setclipboard(table.concat(Session.Logs, "\n"))
        notify("Action log copied")
    else
        notify("Clipboard access is unavailable")
    end
end })

local function cleanup()
    if not Session.Alive then
        return
    end
    Session.Alive = false
    restoreMovement()
    if Session.OwnTraining then
        pcall(Training.Stop)
    end
    for _, connection in ipairs(Session.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    if Meter.Run == meterWrapper then
        Meter.Run = originalMeterRun
        Meter.TestAutoTap = originalAutoTap
    end
    if Movement.Lock == movementLockWrapper then
        Movement.Lock = originalMovementLock
    end
    if Environment[SessionKey] == Session then
        Environment[SessionKey] = nil
    end
end
Library:OnUnload(cleanup)
Session.Unload = function()
    Library:Unload()
    cleanup()
end
Menu:AddButton({ Text = "Unload", Func = Session.Unload })
Toggles.ShortBreaks:OnChanged(function()
    Session.BreakUntil = 0
    Session.NextBreakAt = Session.Stats.Throws + math.max(1, math.floor(paced(Options.BreakEvery.Value, 1) + 0.5))
end)
Options.BreakEvery:OnChanged(function()
    Session.NextBreakAt = Session.Stats.Throws + math.max(1, math.floor(paced(Options.BreakEvery.Value, 1) + 0.5))
end)
Toggles.Paused:OnChanged(function()
    updateMovement(0)
    if Toggles.Paused.Value and Session.OwnTraining then
        Training.Stop()
    end
end)

for _, name in ipairs({ "MinimumIncome", "CashReserve" }) do
    Options[name]:OnChanged(function()
        if not amount(Options[name].Value) then
            notify("Enter a valid nonnegative number, such as 1500, 1.5k, or 1e30.")
        end
    end)
end

local addonsOk, addonsFailure = pcall(function()
    local ThemeManager = download("addons/ThemeManager.lua")
    ThemeManager:SetLibrary(Library)
    ThemeManager:SetFolder("ThrowFoodObsidian")
    ThemeManager:ApplyToTab(Tabs.Misc)
    if type(isfolder) == "function" and type(makefolder) == "function" and type(writefile) == "function" and type(readfile) == "function" and type(listfiles) == "function" then
        local SaveManager = download("addons/SaveManager.lua")
        SaveManager:SetLibrary(Library)
        SaveManager:IgnoreThemeSettings()
        SaveManager:SetIgnoreIndexes({ "MenuKey", "Paused" })
        SaveManager:SetFolder("ThrowFoodObsidian/" .. tostring(game.PlaceId))
        SaveManager:BuildConfigSection(Tabs.Misc)
        SaveManager:LoadAutoloadConfig()
    end
end)
if not addonsOk then
    log("Theme/config addon: " .. tostring(addonsFailure), true)
end

task.spawn(function()
    local lastStatus = -math.huge
    local lastOffline = -math.huge
    while Session.Alive do
        local ok, failure = pcall(function()
            if not Toggles.Paused.Value and profile() then
                if os.clock() - lastOffline >= 2 then
                    lastOffline = os.clock()
                    claimOffline()
                end
                runUpkeep()
                if Session.Alive then
                    activity()
                end
            elseif Session.OwnTraining then
                Training.Stop()
            end
            if os.clock() - lastStatus >= 1 then
                lastStatus = os.clock()
                refreshStatus()
            end
        end)
        if not ok then
            log(failure, true)
        end
        task.wait(0.25)
    end
end)

task.spawn(function()
    while Session.Alive do
        for _, action in ipairs({ clickBonus, vote, antiAfk }) do
            local ok, failure = pcall(action)
            if not ok then
                log(failure, true)
            end
        end
        task.wait(0.15)
    end
end)

notify("Ready. Choose your automation toggles. RightShift opens the menu.")
