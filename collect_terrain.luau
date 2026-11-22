local options = if type(getgenv) == "function" then getgenv().ENV_TERRAIN_OPTIONS or {} else {}
local terrain = workspace.Terrain
local http = game:GetService("HttpService")
assert(type(writefile) == "function", "writefile is required")
local center = workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position or Vector3.zero
local player = game:GetService("Players").LocalPlayer
local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
if root then center = root.Position end
local minimum = options.min or center - Vector3.new(128, 64, 128)
local maximum = options.max or center + Vector3.new(128, 64, 128)
assert(typeof(minimum) == "Vector3" and typeof(maximum) == "Vector3", "min and max must be Vector3 values")
local low = Vector3.new(math.floor(minimum.X / 4), math.floor(minimum.Y / 4), math.floor(minimum.Z / 4))
local high = Vector3.new(math.ceil(maximum.X / 4), math.ceil(maximum.Y / 4), math.ceil(maximum.Z / 4))
local size = high - low
local chunk = options.chunkCells or 16
assert(type(chunk) == "number" and chunk % 1 == 0 and chunk >= 1 and chunk <= 32, "chunkCells must be between one and 32")
assert(size.X > 0 and size.Y > 0 and size.Z > 0 and size.X * size.Y * size.Z <= (options.maxVoxels or 262144), "Capture bounds exceed the voxel budget")
local path = options.output or "terrain.json"
local report = {
    format = "EnvTerrainCapture", schemaVersion = 1,
    metadata = { complete = false, scope = "Bounded client terrain snapshot", placeId = game.PlaceId, gameId = game.GameId, robloxVersion = version(), min = { low.X, low.Y, low.Z }, max = { high.X, high.Y, high.Z }, cells = 0, chunks = 0 },
    terrain = { resolution = 4, regions = {}, colors = {}, water = {}, slots = {} },
    errors = {},
}
local function save() writefile(path, http:JSONEncode(report)) end
if type(identifyexecutor) == "function" then
    local ok, name, build = pcall(identifyexecutor)
    if ok then report.metadata.executor = tostring(name); report.metadata.executorVersion = tostring(build) end
end
for _, name in ipairs({ "Grass", "Slate", "Concrete", "Brick", "Sand", "WoodPlanks", "Rock", "Glacier", "Snow", "Sandstone", "Mud", "Basalt", "Ground", "CrackedLava", "Asphalt", "Cobblestone", "Ice", "LeafyGrass", "Salt", "Limestone", "Pavement" }) do
    local ok, color = pcall(function() return terrain:GetMaterialColor(Enum.Material[name]) end)
    if ok then report.terrain.colors[name] = { color.R, color.G, color.B } end
end
for _, name in ipairs({ "WaterColor", "WaterTransparency", "WaterReflectance", "WaterWaveSize", "WaterWaveSpeed", "Decoration", "GrassLength" }) do
    local ok, value = pcall(function() return terrain[name] end)
    if ok then report.terrain.water[name] = if typeof(value) == "Color3" then { value.R, value.G, value.B } else value end
end
for index = 2, 63 do
    local ok, material, variant, color = pcall(function() return terrain:GetMaterialSlot(index) end)
    if ok and material then report.terrain.slots[tostring(index)] = { material = material.Name, variant = variant, color = { color.R, color.G, color.B } } end
end
save()
for x = low.X, high.X - 1, chunk do
    for y = low.Y, high.Y - 1, chunk do
        for z = low.Z, high.Z - 1, chunk do
            local nx, ny, nz = math.min(chunk, high.X - x), math.min(chunk, high.Y - y), math.min(chunk, high.Z - z)
            local region = Region3.new(Vector3.new(x, y, z) * 4, Vector3.new(x + nx, y + ny, z + nz) * 4)
            local ok, channels = pcall(function() return terrain:ReadVoxelChannels(region, 4, { "SolidMaterial", "SolidOccupancy", "LiquidOccupancy", "SolidMaterialIndex" }) end)
            if not ok then ok, channels = pcall(function() return terrain:ReadVoxelChannels(region, 4, { "SolidMaterial", "SolidOccupancy", "LiquidOccupancy" }) end) end
            local materials, occupancies
            if not ok then
                local legacyOk, first, second = pcall(function() return terrain:ReadVoxels(region, 4) end)
                if not legacyOk then
                    table.insert(report.errors, { min = { x, y, z }, error = tostring(first) })
                    save()
                    error("Terrain voxel capture failed; partial results saved to " .. path, 0)
                end
                materials, occupancies = first, second
                report.metadata.legacyVoxels = true
            end
            local captured = { min = { x, y, z }, size = { nx, ny, nz }, cells = {} }
            for a = 1, nx do for b = 1, ny do for c = 1, nz do
                local material, solid, liquid
                if ok then material, solid, liquid = channels.SolidMaterial[a][b][c], channels.SolidOccupancy[a][b][c], channels.LiquidOccupancy[a][b][c]
                else
                    material, solid, liquid = materials[a][b][c], occupancies[a][b][c], 0
                    if material == Enum.Material.Water then material, solid, liquid = Enum.Material.Air, 0, solid end
                end
                if solid > 0 or liquid > 0 then
                    local index = ok and channels.SolidMaterialIndex and channels.SolidMaterialIndex[a][b][c]
                    if index and index ~= 0 and not report.terrain.slots[tostring(index)] then index = nil; report.metadata.materialIndicesIncomplete = true end
                    if not index then report.metadata.materialIndicesIncomplete = true end
                    table.insert(captured.cells, { a - 1, b - 1, c - 1, material.Name, solid, liquid, index })
                    report.metadata.cells += 1
                end
            end end end
            table.insert(report.terrain.regions, captured)
            report.metadata.chunks += 1
            save()
            task.wait()
        end
    end
end
report.metadata.complete = true
save()
print(string.format("Saved %d occupied cells across %d chunks to %s", report.metadata.cells, report.metadata.chunks, path))
