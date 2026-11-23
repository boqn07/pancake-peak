--!strict
-- Egg odds and rolls. The odds shown in UI come from `odds()`, the same function `roll()` uses,
-- so what players see is always what they get.
local Eggs = require(script.Parent.Parent.Config.Eggs)
local Rarities = require(script.Parent.Parent.Config.Rarities)

local Hatch = {}

export type OddsRow = { rarity: string, nibbler: string, chance: number }

-- Returns rows ordered Common -> Mythic with probabilities that sum to 1.
function Hatch.odds(eggId: string, luck: number, minRank: number?): { OddsRow }
	local egg = Eggs.ById[eggId]
	assert(egg, "unknown egg " .. tostring(eggId))
	luck = math.max(1, luck)
	local rows: { OddsRow } = {}
	local total = 0
	for _, r in Rarities.List do
		local base = egg.odds[r.id] or 0
		if minRank and r.rank < minRank then
			base = 0
		end
		local w = base * luck ^ ((r.rank - 1) * Eggs.LuckExponent)
		total += w
		table.insert(rows, { rarity = r.id, nibbler = egg.nibblers[r.id], chance = w })
	end
	for _, row in rows do
		row.chance = if total > 0 then row.chance / total else 0
	end
	return rows
end

function Hatch.shinyChance(lucky: boolean): number
	return if lucky then Eggs.ShinyChanceLucky else Eggs.ShinyChance
end

-- rng(): uniform number in [0, 1). Returns (nibblerId, shiny, rarity).
function Hatch.roll(
	eggId: string,
	luck: number,
	lucky: boolean,
	rng: () -> number,
	minRank: number?
): (string, boolean, string)
	local rows = Hatch.odds(eggId, luck, minRank)
	local x = rng()
	local acc = 0
	local picked = rows[#rows]
	for _, row in rows do
		acc += row.chance
		if x < acc then
			picked = row
			break
		end
	end
	-- Skip zero-chance tail rows if floating error landed past the end.
	if picked.chance <= 0 then
		for i = #rows, 1, -1 do
			if rows[i].chance > 0 then
				picked = rows[i]
				break
			end
		end
	end
	local shiny = rng() < Hatch.shinyChance(lucky)
	return picked.nibbler, shiny, picked.rarity
end

return Hatch
