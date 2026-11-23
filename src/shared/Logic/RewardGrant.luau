--!strict
-- Applies a Reward (see Config/Rewards) to a profile. Used by daily, playtime, codes, the Great
-- Yeti's Order and products.
local Config = script.Parent.Parent.Config
local Zones = require(Config.Zones)
local Rarities = require(Config.Rarities)
local Economy = require(script.Parent.Economy)
local SafeNumber = require(script.Parent.SafeNumber)
local Boosts = require(script.Parent.Boosts)
local Hatch = require(script.Parent.Hatch)
local Inventory = require(script.Parent.Inventory)

local RewardGrant = {}

export type Result = {
	kind: string,
	amount: number?,
	boost: string?,
	seconds: number?,
	nibbler: string?,
	uid: string?,
	shiny: boolean?,
}

function RewardGrant.apply(profile: any, reward: any, ctx: Economy.Context, rng: () -> number, now: number): Result
	if reward.kind == "Maple" then
		local amount = Economy.scaledMaple(profile, ctx, reward.minutes or 0, reward.min or 0)
		profile.maple = SafeNumber.add(profile.maple, amount)
		profile.lifetimeMaple = SafeNumber.add(profile.lifetimeMaple, amount)
		return { kind = "Maple", amount = amount }
	elseif reward.kind == "Boost" then
		Boosts.add(profile, reward.boost, reward.seconds or 0)
		return { kind = "Boost", boost = reward.boost, seconds = reward.seconds }
	elseif reward.kind == "Nibbler" then
		if not Inventory.hasRoom(profile, 1) then
			-- Full inventory: never lose the reward, convert it to Maple instead.
			return RewardGrant.apply(profile, { kind = "Maple", minutes = 15, min = 1000 }, ctx, rng, now)
		end
		local zone = Zones.ById[Economy.bestZone(profile)]
		local minRank = Rarities.ById[reward.minRarity or "Common"].rank
		local id, shiny = Hatch.roll(zone.egg, 1, false, rng, minRank)
		local uid = Inventory.add(profile, id, shiny, now)
		return { kind = "Nibbler", nibbler = id, uid = uid, shiny = shiny }
	end
	return { kind = "None" }
end

return RewardGrant
