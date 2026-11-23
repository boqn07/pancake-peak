--!strict
-- Daily streak, playtime gifts and codes.
-- Reward shapes (shared by all three and by developer products):
--   { kind = "Maple", minutes = number, min = number } -- `minutes` of estimated income, at least `min`
--   { kind = "Boost", boost = "Maple2x" | "Lucky", seconds = number }
--   { kind = "Nibbler", minRarity = string }          -- rolled from the best egg the player has unlocked
export type Reward = {
	kind: string,
	minutes: number?,
	min: number?,
	boost: string?,
	seconds: number?,
	minRarity: string?,
}

local Daily: { Reward } = {
	{ kind = "Maple", minutes = 3, min = 100 },
	{ kind = "Maple", minutes = 5, min = 250 },
	{ kind = "Boost", boost = "Maple2x", seconds = 10 * 60 },
	{ kind = "Maple", minutes = 10, min = 600 },
	{ kind = "Boost", boost = "Lucky", seconds = 15 * 60 },
	{ kind = "Maple", minutes = 20, min = 1500 },
	{ kind = "Nibbler", minRarity = "Rare" },
}

-- Playtime gifts per session: unlockAt is minutes since joining.
local Playtime: { { unlockAt: number, reward: Reward } } = {
	{ unlockAt = 2, reward = { kind = "Maple", minutes = 1, min = 40 } },
	{ unlockAt = 5, reward = { kind = "Maple", minutes = 2, min = 120 } },
	{ unlockAt = 10, reward = { kind = "Boost", boost = "Maple2x", seconds = 5 * 60 } },
	{ unlockAt = 15, reward = { kind = "Maple", minutes = 4, min = 400 } },
	{ unlockAt = 25, reward = { kind = "Boost", boost = "Lucky", seconds = 10 * 60 } },
	{ unlockAt = 40, reward = { kind = "Maple", minutes = 8, min = 1500 } },
	{ unlockAt = 60, reward = { kind = "Nibbler", minRarity = "Rare" } },
}

-- Codes are matched case-insensitively. expires = unix time (UTC) or nil for never.
local Codes: { [string]: { rewards: { Reward }, expires: number? } } = {
	LAUNCH = { rewards = { { kind = "Maple", minutes = 5, min = 200 } } },
	FLIPFLIP = { rewards = { { kind = "Boost", boost = "Maple2x", seconds = 15 * 60 } } },
	YETI = { rewards = { { kind = "Boost", boost = "Lucky", seconds = 15 * 60 } } },
	SYRUP = { rewards = { { kind = "Maple", minutes = 10, min = 500 } }, expires = 1830297600 }, -- 2028-01-01
}

return {
	Daily = Daily,
	Playtime = Playtime,
	Codes = Codes,
	MaxCodeLength = 24,
}
