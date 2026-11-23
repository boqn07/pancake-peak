--!strict
-- Client entry point. Controllers only draw and request; the server decides every outcome.
local Controllers = script.Parent:WaitForChild("Controllers")
local UI = script.Parent:WaitForChild("UI")

local ORDER = {
	{ Controllers, "ClientNet" },
	{ Controllers, "State" },
	{ Controllers, "Audio" },
	{ Controllers, "LightingFX" },
	{ Controllers, "Effects" },
	{ Controllers, "NibblerModels" },
	{ Controllers, "WorldFX" },
	{ Controllers, "StackRenderer" },
	{ Controllers, "Followers" },
	{ Controllers, "OrderRenderer" },
	{ UI, "UIRoot" },
	{ Controllers, "StackInput" },
	{ Controllers, "EggReveal" },
	{ Controllers, "Prompts" },
	{ Controllers, "InputController" },
}

local registry: { [string]: any } = {}
for _, entry in ORDER do
	registry[entry[2]] = require(entry[1]:WaitForChild(entry[2])) :: any
end
for _, entry in ORDER do
	local m = registry[entry[2]]
	if m.Init then
		m:Init(registry)
	end
end
for _, entry in ORDER do
	local m = registry[entry[2]]
	if m.Start then
		task.spawn(function()
			m:Start()
		end)
	end
end
