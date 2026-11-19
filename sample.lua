-- Loom sample: stdlib calls, closures, varargs and a metatable.
local t = {}
for i = 1, 5 do t[#t + 1] = i * i end
print("squares", table.concat(t, ","))
print("format", string.format("%d-%s", 42, "ok"))
print("pcall", pcall(error, "x") == false)
print("select", select("#", 1, 2, 3))
local mt = setmetatable({}, { __index = function(_, k) return k .. "!" end })
print("meta", mt.hello)
print("math", math.floor(2.7), math.max(3, 9))
print("loom sample ok")
