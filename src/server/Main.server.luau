--!strict
-- Server entry point. Services are initialised in dependency order, then started.
-- Init(): wire references, create instances, no yielding. Start(): connect events, start loops.
local Services = script.Parent:WaitForChild("Services")

local ORDER = {
	"NetService",
	"DataService",
	"MonetizationService",
	"WorldService",
	"OrderService",
	"EconomyService",
	"ZoneService",
	"TutorialService",
	"StackService",
	"UpgradeService",
	"NibblerService",
	"RebirthService",
	"RewardsService",
	"SettingsService",
	"LeaderboardService",
}

local registry: { [string]: any } = {}
for _, name in ORDER do
	registry[string.gsub(name, "Service$", "")] = require(Services:WaitForChild(name)) :: any
end

for _, name in ORDER do
	local service = registry[string.gsub(name, "Service$", "")]
	if service.Init then
		service:Init(registry)
	end
end
for _, name in ORDER do
	local service = registry[string.gsub(name, "Service$", "")]
	if service.Start then
		task.spawn(function()
			service:Start()
		end)
	end
end
