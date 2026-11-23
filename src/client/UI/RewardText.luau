--!strict
-- Human-readable text for rewards (config entries and granted results).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Logic"):WaitForChild("Format"))
local Nibblers = require(Shared:WaitForChild("Config"):WaitForChild("Nibblers"))

local RewardText = {}

local BOOST_NAMES = { Maple2x = "2x Maple", Lucky = "Lucky" }
local BOOST_GLYPH = { Maple2x = "⚡", Lucky = "🍀" }

function RewardText.boostName(id: string): string
	return BOOST_NAMES[id] or id
end

function RewardText.boostGlyph(id: string): string
	return BOOST_GLYPH[id] or "✨"
end

-- Describe a reward definition before it's claimed. `income` = estimated Maple/second.
function RewardText.describe(reward: any, income: number?): (string, string)
	if reward.kind == "Maple" then
		local amount = math.max(reward.min or 0, (income or 0) * 60 * (reward.minutes or 0))
		return "🍁", Format.abbreviate(math.floor(amount)) .. " Maple"
	elseif reward.kind == "Boost" then
		return RewardText.boostGlyph(reward.boost),
			string.format("%s %s", RewardText.boostName(reward.boost), Format.clock(reward.seconds or 0))
	elseif reward.kind == "Nibbler" then
		return "🐾", (reward.minRarity or "Common") .. "+ Nibbler"
	elseif reward.kind == "Order" then
		return "👹", "The Great Yeti's Order for everyone"
	end
	return "❔", "Reward"
end

-- Describe a granted result.
function RewardText.result(r: any): string
	if r.kind == "Maple" then
		return "+" .. Format.abbreviate(r.amount or 0) .. " Maple"
	elseif r.kind == "Boost" then
		return string.format("%s boost +%s", RewardText.boostName(r.boost), Format.clock(r.seconds or 0))
	elseif r.kind == "Nibbler" then
		local d = Nibblers.ById[r.nibbler]
		return "New Nibbler: " .. (if r.shiny then "Sparkly " else "") .. (if d then d.name else "?")
	end
	return "Reward received"
end

return RewardText
