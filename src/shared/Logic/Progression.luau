--!strict
-- Upgrades, zones, Yeti Feast and Spatula perks as pure profile operations. Each returns (ok, reason?).
local Config = script.Parent.Parent.Config
local Upgrades = require(Config.Upgrades)
local Zones = require(Config.Zones)
local Rebirth = require(Config.Rebirth)
local Perks = require(Config.Perks)
local SafeNumber = require(script.Parent.SafeNumber)
local UpgradeMath = require(script.Parent.UpgradeMath)
local Economy = require(script.Parent.Economy)

local Progression = {}

function Progression.buyUpgrade(profile: any, id: string): (boolean, string?)
	local u = Upgrades.ById[id]
	if not u then
		return false, "Unknown upgrade"
	end
	local level = profile.upgrades[id] or 0
	if level >= u.maxLevel then
		return false, "Already maxed"
	end
	local ok, balance = SafeNumber.trySpend(profile.maple, UpgradeMath.cost(id, level))
	if not ok then
		return false, "Not enough Maple"
	end
	profile.maple = balance
	profile.upgrades[id] = level + 1
	return true, nil
end

function Progression.canUnlockZone(profile: any, id: string): (boolean, string?)
	local z = Zones.ById[id]
	if not z then
		return false, "Unknown zone"
	end
	if profile.zones[id] then
		return false, "Already unlocked"
	end
	local prev = Zones.List[z.order - 1]
	if prev and not profile.zones[prev.id] then
		return false, "Unlock " .. prev.name .. " first"
	end
	if profile.maple < z.unlockCost then
		return false, "Not enough Maple"
	end
	return true, nil
end

function Progression.unlockZone(profile: any, id: string): (boolean, string?)
	local ok, why = Progression.canUnlockZone(profile, id)
	if not ok then
		return false, why
	end
	local spent, balance = SafeNumber.trySpend(profile.maple, Zones.ById[id].unlockCost)
	if not spent then
		return false, "Not enough Maple"
	end
	profile.maple = balance
	profile.zones[id] = true
	return true, nil
end

function Progression.canRebirth(profile: any): (boolean, string?)
	if not profile.zones[Rebirth.RequiredZone] then
		return false, "Unlock " .. Zones.ById[Rebirth.RequiredZone].name .. " first"
	end
	if profile.maple < Economy.rebirthCost(profile.rebirths) then
		return false, "Not enough Maple"
	end
	return true, nil
end

-- Yeti Feast: reset Maple and upgrades; keep zones, Nibblers and perks.
-- Returns (ok, reasonOrNil, spatulasGained).
function Progression.rebirth(profile: any): (boolean, string?, number)
	local ok, why = Progression.canRebirth(profile)
	if not ok then
		return false, why, 0
	end
	local spatulas = Economy.spatulasFor(profile)
	profile.maple = 0
	for _, u in Upgrades.List do
		profile.upgrades[u.id] = 0
	end
	profile.rebirths += 1
	profile.spatulas += spatulas
	return true, nil, spatulas
end

function Progression.perkCost(id: string, level: number): number
	local p = Perks.ById[id]
	return p.baseCost + p.costStep * level
end

function Progression.buyPerk(profile: any, id: string): (boolean, string?)
	local p = Perks.ById[id]
	if not p then
		return false, "Unknown perk"
	end
	local level = profile.perks[id] or 0
	if level >= p.maxLevel then
		return false, "Already maxed"
	end
	local cost = Progression.perkCost(id, level)
	if profile.spatulas < cost then
		return false, "Not enough Golden Spatulas"
	end
	profile.spatulas -= cost
	profile.perks[id] = level + 1
	return true, nil
end

return Progression
