-- Prints the script tree of a Rojo-built place to confirm everything lands where it should.
-- Usage: rojo build -o build/PancakePeak.rbxl && lune run tools/inspect-place
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local game = roblox.deserializePlace(fs.readFile("build/PancakePeak.rbxl"))
local function dump(inst, depth)
	if inst:IsA("LuaSourceContainer") or inst:IsA("Folder") then
		print(string.rep("  ", depth) .. inst.Name .. " (" .. inst.ClassName .. ")")
	end
	for _, c in inst:GetChildren() do
		dump(c, depth + 1)
	end
end
for _, svc in { "ReplicatedStorage", "ServerScriptService", "StarterPlayer" } do
	print(svc)
	dump(game:GetService(svc), 0)
end
print("StreamingEnabled:", game:GetService("Workspace").StreamingEnabled)
print("Lighting.ClockTime:", game:GetService("Lighting").ClockTime)
