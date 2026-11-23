--!strict
-- Rarity tiers. Order matters: index 1 is the most common. Colors are hex so pure-Luau tests can read them.
export type Rarity = {
	id: string,
	name: string,
	rank: number,
	color: string,
	announce: boolean,
}

local list: { Rarity } = {
	{ id = "Common", name = "Common", rank = 1, color = "#A9BCC6", announce = false },
	{ id = "Uncommon", name = "Uncommon", rank = 2, color = "#4FD18B", announce = false },
	{ id = "Rare", name = "Rare", rank = 3, color = "#2EA8FF", announce = false },
	{ id = "Epic", name = "Epic", rank = 4, color = "#A66BFF", announce = false },
	{ id = "Legendary", name = "Legendary", rank = 5, color = "#FFB020", announce = true },
	{ id = "Mythic", name = "Mythic", rank = 6, color = "#FF4F8B", announce = true },
}

local byId: { [string]: Rarity } = {}
for _, r in list do
	byId[r.id] = r
end

return {
	List = list,
	ById = byId,
	-- Shiny ("Sparkly") is a variant that can roll on any Nibbler.
	Shiny = {
		name = "Sparkly",
		color = "#FFFFFF",
		gradient = { "#FFF3B0", "#BFEFFF", "#FFFFFF", "#FFD38A", "#D9CCFF" },
	},
}
