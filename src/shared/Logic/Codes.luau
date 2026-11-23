--!strict
local Rewards = require(script.Parent.Parent.Config.Rewards)

local Codes = {}

function Codes.normalize(code: string): string
	return string.upper((string.gsub(code, "%s", "")))
end

-- Returns (ok, reasonOrNormalizedCode)
function Codes.check(profile: any, raw: any, now: number): (boolean, string)
	if type(raw) ~= "string" or #raw == 0 or #raw > Rewards.MaxCodeLength then
		return false, "Invalid code"
	end
	local code = Codes.normalize(raw)
	local def = Rewards.Codes[code]
	if not def then
		return false, "Invalid code"
	end
	if def.expires and now >= def.expires then
		return false, "This code has expired"
	end
	if profile.codes[code] then
		return false, "Already redeemed"
	end
	return true, code
end

return Codes
