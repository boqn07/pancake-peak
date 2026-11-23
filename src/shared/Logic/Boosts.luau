--!strict
local Monetization = require(script.Parent.Parent.Config.Monetization)

local Boosts = {}

function Boosts.add(profile: any, boost: string, seconds: number)
	local cur = profile.boosts[boost] or 0
	profile.boosts[boost] = math.min(Monetization.MaxBoostSeconds, cur + math.max(0, seconds))
end

-- Count boosts down while the player is online. Returns true if any boost just expired.
function Boosts.tick(profile: any, dt: number): boolean
	local expired = false
	for k, v in profile.boosts do
		if v > 0 then
			local nv = math.max(0, v - dt)
			profile.boosts[k] = nv
			if nv == 0 then
				expired = true
			end
		end
	end
	return expired
end

return Boosts
