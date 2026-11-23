--!strict
local Upgrades = require(script.Parent.Parent.Config.Upgrades)

local UpgradeMath = {}

-- Cost of buying the next level when the upgrade is currently at `level`.
function UpgradeMath.cost(id: string, level: number): number
	local u = Upgrades.ById[id]
	assert(u, "unknown upgrade " .. tostring(id))
	return math.floor(u.baseCost * u.growth ^ level + 0.5)
end

function UpgradeMath.effect(id: string, level: number): number
	local u = Upgrades.ById[id]
	assert(u, "unknown upgrade " .. tostring(id))
	return u.base + u.perLevel * math.clamp(level, 0, u.maxLevel)
end

function UpgradeMath.isMaxed(id: string, level: number): boolean
	return level >= Upgrades.ById[id].maxLevel
end

return UpgradeMath
