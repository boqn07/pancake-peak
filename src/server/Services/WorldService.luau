--!strict
-- Builds the mountain once and exposes the important locations to other services.
local MapBuilder = require(script.Parent.Parent.World.MapBuilder)

local WorldService = {}

local built: MapBuilder.Built

function WorldService:Init()
	built = MapBuilder.Build()
end

function WorldService:HubSpawn(): CFrame
	return built.hubSpawn
end

function WorldService:ZoneSpawn(zoneId: string): CFrame?
	return built.zoneSpawns[zoneId]
end

-- Where a Mystery Egg sits (for the HatchEgg distance check).
function WorldService:Egg(eggId: string): Vector3?
	return built.eggs[eggId]
end

function WorldService:Board(name: string): SurfaceGui?
	return built.boards[name]
end

return WorldService
