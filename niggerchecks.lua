local NetworkClient = game:GetService("Players")

local function terminateSession()
    pcall(function()
        local client = NetworkClient.LocalPlayer
        if client then
            client:Kick("Network protocol out of sync.")
        end
    end)
    task.wait(0.1)
    local stateLock = table.freeze({})
    stateLock[1] = 0
end

local function validateNativeSignature(target)
    if type(target) ~= "function" then return false end
    if debug and type(debug.info) == "function" then
        local s, loc = pcall(debug.info, target, "s")
        if s and loc ~= "[C]" then return false end
    end
    return true
end

local integritySequence = {
    function() return type(1) == "number" end,
    function() return type("") == "string" end,
    function() return type(true) == "boolean" end,
    function() return type({}) == "table" end,
    function() return type(function() end) == "function" end,
    function() return type(coroutine.create(function() end)) == "thread" end,
    function() return type(assert) == "function" end,
    function() return type(error) == "function" end,
    function() return type(pcall) == "function" end,
    function() return type(xpcall) == "function" end,
    function() return type(select) == "function" end,
    function() return type(tonumber) == "function" end,
    function() return type(tostring) == "function" end,
    function() return type(type) == "function" end,
    function() return typeof(1) == "number" end,
    function() return typeof("") == "string" end,
    function() return typeof(true) == "boolean" end,
    function() return typeof(CFrame.new()) == "CFrame" end,
    function() return typeof(Vector3.new()) == "Vector3" end,
    function() return typeof(Vector2.new()) == "Vector2" end,
    function() return typeof(Color3.new()) == "Color3" end,
    function() return typeof(UDim.new()) == "UDim" end,
    function() return typeof(UDim2.new()) == "UDim2" end,
    function() return typeof(Ray.new(Vector3.new(), Vector3.new())) == "Ray" end,
    function() return typeof(Region3.new(Vector3.new(), Vector3.new(1,1,1))) == "Region3" end,
    function() return typeof(Faces.new(Enum.NormalId.Front)) == "Faces" end,
    function() return typeof(Axes.new(Enum.Axis.X)) == "Axes" end,
    function() return typeof(NumberSequence.new(1)) == "NumberSequence" end,
    function() return typeof(ColorSequence.new(Color3.new())) == "ColorSequence" end,
    function() return typeof(NumberRange.new(1, 2)) == "NumberRange" end,
    function() return typeof(Rect.new(0, 0, 0, 0)) == "Rect" end,
    function() return typeof(PhysicalProperties.new(1, 1, 1)) == "PhysicalProperties" end,
    function() return typeof(Enum.Material) == "Enum" end,
    function() return typeof(Enum.Material.Plastic) == "EnumItem" end,

    function() return type(math) == "table" end,
    function() return type(math.abs) == "function" end,
    function() return type(math.floor) == "function" end,
    function() return type(math.ceil) == "function" end,
    function() return math.abs(-50) == 50 end,
    function() return math.floor(4.9) == 4 end,
    function() return math.ceil(4.1) == 5 end,
    function() return math.clamp(15, 0, 10) == 10 end,
    function() return math.min(5, 2, 9) == 2 end,
    function() return math.max(5, 2, 9) == 9 end,
    function() return math.sign(-42) == -1 end,
    function() return math.rad(180) == math.pi end,
    function() return math.deg(math.pi) == 180 end,
    function() return (0 / 0) ~= (0 / 0) end,
    function() return math.sqrt(16) == 4 end,
    function() return math.pow(2, 3) == 8 end,

    function() return type(string) == "table" end,
    function() return type(string.sub) == "function" end,
    function() return type(string.find) == "function" end,
    function() return type(string.match) == "function" end,
    function() return type(string.len) == "function" end,
    function() return string.len("hello") == 5 end,
    function() return string.sub("abcdef", 2, 4) == "bcd" end,
    function() return string.find("abcdef", "cd") == 3 end,
    function() return string.match("test123abc", "%d+") == "123" end,
    function() return string.rep("a", 3) == "aaa" end,
    function() return string.reverse("abc") == "cba" end,
    function() return string.lower("ABC") == "abc" end,
    function() return string.upper("abc") == "ABC" end,

    function() return type(table) == "table" end,
    function() return type(table.insert) == "function" end,
    function() return type(table.remove) == "function" end,
    function() return type(table.concat) == "function" end,
    function() return type(table.pack) == "function" end,
    function() return type(table.unpack) == "function" end,
    function() return type(table.sort) == "function" end,
    function() return type(table.clear) == "function" end,
    function() return type(table.freeze) == "function" end,
    function() return type(table.isfrozen) == "function" end,

    function()
        local dataBuffer = table.pack(10, 20, 30)
        return dataBuffer.n == 3 and dataBuffer[2] == 20
    end,
    function()
        local sequenceData = {3, 1, 2}
        table.sort(sequenceData)
        return sequenceData[1] == 1 and sequenceData[3] == 3
    end,
    function()
        local validationTable = {10, 20, 30}
        table.clear(validationTable)
        return #validationTable == 0
    end,
    function()
        local validationTable = {1, 2, 3}
        table.freeze(validationTable)
        return table.isfrozen(validationTable)
    end,
    function()
        local validationTable = {1, 2, 3}
        table.freeze(validationTable)
        local status = pcall(function() validationTable[1] = 99 end)
        return not status
    end,
    function()
        local status = pcall(function() math.abs = function() end end)
        return not status
    end,
    function()
        local status = pcall(function() string.sub = function() end end)
        return not status
    end,

    function() return validateNativeSignature(type) end,
    function() return validateNativeSignature(typeof) end,
    function() return validateNativeSignature(math.abs) end,
    function() return validateNativeSignature(math.floor) end,
    function() return validateNativeSignature(string.sub) end,
    function() return validateNativeSignature(string.find) end,
    function() return validateNativeSignature(table.insert) end,
    function() return validateNativeSignature(table.sort) end,
    function() return validateNativeSignature(pcall) end,
    function() return validateNativeSignature(xpcall) end,
    function() return validateNativeSignature(coroutine.create) end,
    function() return validateNativeSignature(coroutine.resume) end,

    function()
        local intercepted = false
        local p = newproxy(true)
        local m = getmetatable(p)
        m.__index = function() intercepted = true return 0 end
        m.__call = function() intercepted = true end
        pcall(function() math.abs(p) end)
        return not intercepted
    end,
    function()
        local intercepted = false
        local p = newproxy(true)
        local m = getmetatable(p)
        m.__index = function() intercepted = true return "" end
        pcall(function() string.sub(p, 1, 2) end)
        return not intercepted
    end,
    function()
        local intercepted = false
        local p = newproxy(true)
        local m = getmetatable(p)
        m.__index = function() intercepted = true return {} end
        pcall(function() table.insert(p, 1) end)
        return not intercepted
    end,

    function()
        local node = Instance.new("Part")
        local isInstanceType = typeof(node) == "Instance"
        node:Destroy()
        return isInstanceType
    end,
    function()
        local node = Instance.new("Part")
        node.Name = "TestNode"
        local matchName = node.Name == "TestNode"
        node:Destroy()
        return matchName
    end,
    function()
        local node = Instance.new("Part")
        node:SetAttribute("Flag", 42)
        local v = node:GetAttribute("Flag") == 42
        node:SetAttribute("Flag", nil)
        local v2 = node:GetAttribute("Flag") == nil
        node:Destroy()
        return v and v2
    end,
    function()
        local container = Instance.new("Folder")
        local node = Instance.new("Part")
        node.Parent = container
        local c = container:GetChildren()
        local v = #c == 1 and c[1] == node
        container:Destroy()
        return v
    end,
    function()
        local node = Instance.new("Part")
        node.CFrame = CFrame.new(15, 25, 35)
        local pos = node.Position
        node:Destroy()
        return pos.X == 15 and pos.Y == 25 and pos.Z == 35
    end,
    function()
        local node = Instance.new("Part")
        node.Size = Vector3.new(2, 2, 2)
        node.Size = node.Size * 2
        local s = node.Size
        node:Destroy()
        return s.X == 4 and s.Y == 4 and s.Z == 4
    end,
    function()
        local node = Instance.new("Part")
        node.CFrame = CFrame.Angles(math.pi/2, 0, 0)
        local lv = node.CFrame.LookVector
        node:Destroy()
        return math.abs(lv.Y - -1) < 0.01 or math.abs(lv.Y - 1) < 0.01
    end,
    function()
        local node = Instance.new("Part")
        local fired = false
        local con = node:GetPropertyChangedSignal("Name"):Connect(function() fired = true end)
        node.Name = "SignalTrigger"
        con:Disconnect()
        node:Destroy()
        return fired
    end,
    function()
        local node = Instance.new("Part")
        local fired = false
        local con = node:GetPropertyChangedSignal("Transparency"):Connect(function() fired = true end)
        node.Transparency = 0.5
        con:Disconnect()
        node:Destroy()
        return fired
    end,
    function()
        local node = Instance.new("Part")
        local s, r = pcall(function() node.ClassName = "Folder" end)
        node:Destroy()
        return (not s) and type(r) == "string" and string.find(r, "ClassName") ~= nil
    end,
    function()
        local s, r = pcall(Instance.new, "InvalidClassIdentifier")
        return (not s) and type(r) == "string"
    end,
    function()
        local node = Instance.new("Part")
        local s = pcall(function() node.Parent = node end)
        node:Destroy()
        return not s
    end,

    function() return game:IsA("DataModel") end,
    function() return game.Parent == nil end,
    function() return typeof(game) == "Instance" end,
    function()
        local s = pcall(function() local _ = game.Name; game.Name = "Tamper" end)
        return not s
    end,
    function()
        local s, r = pcall(function() return game:Clone() end)
        return (not s) or r == nil
    end,
    function()
        local s, w = pcall(game.GetService, game, "Workspace")
        return s and w ~= nil
    end,
    function()
        local s, w = pcall(game.GetService, game, "Players")
        return s and w ~= nil
    end,
    function()
        local s, w = pcall(game.GetService, game, "RunService")
        return s and w ~= nil
    end,
    function() return game:GetService("Players") == game:GetService("Players") end,

    function()
        local node = Instance.new("Part")
        node:Destroy()
        local status = pcall(function() node.Parent = game end)
        return not status
    end,
    function()
        local node = Instance.new("Part")
        local status, err = pcall(function() return node.NonExistentPropertyIdentifier end)
        node:Destroy()
        return (not status) and type(err) == "string" and string.find(err, "valid member") ~= nil
    end,
    function()
        return getmetatable(game) == "The metatable is locked"
    end,
    function()
        local node = Instance.new("Part")
        local status = pcall(setmetatable, node, {})
        node:Destroy()
        return not status
    end,
    function()
        local node = Instance.new("Part")
        node:SetAttribute("TestKey", 100)
        local attrTable = node:GetAttributes()
        attrTable["TestKey"] = 200
        local valid = node:GetAttribute("TestKey") == 100
        node:Destroy()
        return valid
    end,
    function()
        local transformFrame = CFrame.new(10, 20, 30)
        local worldPoint = transformFrame:PointToWorldSpace(Vector3.new(1, 2, 3))
        return worldPoint.X == 11 and worldPoint.Y == 22 and worldPoint.Z == 33
    end,
    function()
        local status, err = pcall(getfenv, math.abs)
        return (not status) and type(err) == "string" and string.find(err, "C function") ~= nil
    end,
    function()
        local colorRef = BrickColor.new("Bright red")
        local rawColor = colorRef.Color
        return rawColor.R > 0.7 and rawColor.G < 0.2 and rawColor.B < 0.2
    end,
    function()
        local parentContainer = Instance.new("Folder")
        parentContainer.Name = "ContainerNode"
        local childEntity = Instance.new("Part")
        childEntity.Name = "ChildNode"
        childEntity.Parent = parentContainer
        local fullName = childEntity:GetFullName()
        parentContainer:Destroy()
        return fullName == "ContainerNode.ChildNode"
    end,
    function()
        local parentContainer = Instance.new("Folder")
        local childEntity = Instance.new("Part")
        childEntity.Parent = parentContainer
        local isDescendant = childEntity:IsDescendantOf(parentContainer)
        parentContainer:Destroy()
        return isDescendant
    end,

    function()
        return type(game.JobId) == "string" and type(game.Name) == "string" and type(game.GameId) == "number"
    end,
    function()
        local status = pcall(function() game.JobId = "OverrideTest" end)
        return not status
    end,
    function()
        local status = pcall(function() game.GameId = 12345678 end)
        return not status
    end,
    function()
        local status = pcall(function() game.Name = "OverrideTest" end)
        return not status
    end,

    function()
        local status, err = pcall(Instance.new, "Workspace")
        return (not status) and type(err) == "string" and string.find(err, "cannot be created") ~= nil
    end,
    function()
        local status, err = pcall(Instance.new, "Players")
        return (not status) and type(err) == "string" and string.find(err, "cannot be created") ~= nil
    end,

    function()
        local node = Instance.new("Part")
        local status, err = pcall(function() node.Transparency = "InvalidType" end)
        node:Destroy()
        return (not status) and type(err) == "string" and string.find(err, "expected, got string") ~= nil
    end,
    function()
        local node = Instance.new("Part")
        local status, err = pcall(function() node.Anchored = "InvalidType" end)
        node:Destroy()
        return (not status) and type(err) == "string" and string.find(err, "expected, got string") ~= nil
    end,

    function()
        local vec = Vector3.new(1, 2, 3)
        local status = pcall(function() vec.X = 100 end)
        return not status
    end,
    function()
        local cf = CFrame.new(1, 2, 3)
        local status = pcall(function() cf.Position = Vector3.new(0,0,0) end)
        return not status
    end,

    function()
        local node = Instance.new("Part")
        local sig = node.Touched
        local isSignal = typeof(sig) == "RBXScriptSignal"
        local conn = sig:Connect(function() end)
        local isConn = typeof(conn) == "RBXScriptConnection"
        local isConnected = conn.Connected == true
        local writeLock = not pcall(function() conn.Connected = false end)
        conn:Disconnect()
        local isDisconnected = conn.Connected == false
        node:Destroy()
        return isSignal and isConn and isConnected and writeLock and isDisconnected
    end,

    function()
        local isEnums = typeof(Enum) == "Enums"
        local isEnum = typeof(Enum.PartType) == "Enum"
        local isItem = typeof(Enum.PartType.Block) == "EnumItem"
        local hasVal = type(Enum.PartType.Block.Value) == "number"
        local lockStatus = not pcall(function() Enum.PartType.Block = 123 end)
        return isEnums and isEnum and isItem and hasVal and lockStatus
    end,

    function()
        local noiseVal = math.noise(1.5, 2.5, 3.5)
        return type(noiseVal) == "number" and noiseVal ~= 0 and noiseVal == math.noise(1.5, 2.5, 3.5)
    end,

    function()
        local packed = string.pack("I4", 0xDEADBEEF)
        local unpacked = string.unpack("I4", packed)
        return unpacked == 0xDEADBEEF
    end,

    function()
        return type(task) == "table" and type(task.spawn) == "function" and type(task.defer) == "function" and validateNativeSignature(task.spawn)
    end,

    function() return type(coroutine) == "table" end,
    function() return type(coroutine.create) == "function" end,
    function() return type(coroutine.resume) == "function" end,
    function() return type(coroutine.status) == "function" end,
    function() return type(coroutine.yield) == "function" end,
    function()
        local processThread = coroutine.create(function() return 42 end)
        local status, result = coroutine.resume(processThread)
        return status and result == 42
    end,
    function()
        local processThread = coroutine.create(function() return 42 end)
        coroutine.resume(processThread)
        return coroutine.status(processThread) == "dead"
    end,
    function()
        local processThread = coroutine.create(function() coroutine.yield() end)
        coroutine.resume(processThread)
        return coroutine.status(processThread) == "suspended"
    end,

    function() return type(buffer) == "table" end,
    function() return type(buffer.create) == "function" end,
    function()
        local memoryBlock = buffer.create(4)
        return buffer.len(memoryBlock) == 4
    end,
    function()
        local memoryBlock = buffer.create(4)
        buffer.writeu8(memoryBlock, 0, 255)
        return buffer.readu8(memoryBlock, 0) == 255
    end,
    function()
        local memoryBlock = buffer.create(4)
        buffer.writef32(memoryBlock, 0, 1.5)
        return math.abs(buffer.readf32(memoryBlock, 0) - 1.5) < 1e-5
    end
}

for stepIndex, runStep in ipairs(integritySequence) do
    local executionStatus, evaluationResult = pcall(runStep)
    if not executionStatus or evaluationResult ~= true then
        print("check #" .. stepIndex .. " failed")
        terminateSession()
        return
    end
end

print("all passed")


