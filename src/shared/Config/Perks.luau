--!strict
-- Spatula Shop: permanent perks bought with Golden Spatulas (earned at a Yeti Feast). Never reset.
-- cost(level) = baseCost + costStep * level (Spatulas).
export type Perk = {
	id: string,
	name: string,
	description: string,
	perLevel: number,
	maxLevel: number,
	baseCost: number,
	costStep: number,
	glyph: string,
}

local list: { Perk } = {
	{
		id = "GoldenSyrup",
		name = "Golden Syrup",
		description = "+25% Maple per level",
		perLevel = 0.25,
		maxLevel = 20,
		baseCost = 2,
		costStep = 1,
		glyph = "🍯",
	},
	{
		id = "SwiftSkis",
		name = "Swift Skis",
		description = "+5% walk speed per level",
		perLevel = 0.05,
		maxLevel = 10,
		baseCost = 2,
		costStep = 1,
		glyph = "🎿",
	},
	{
		id = "LuckyYolk",
		name = "Lucky Yolk",
		description = "+10% egg luck per level",
		perLevel = 0.1,
		maxLevel = 10,
		baseCost = 3,
		costStep = 1,
		glyph = "🍀",
	},
	{
		id = "ExtraPocket",
		name = "Extra Pocket",
		description = "+1 Nibbler slot per level",
		perLevel = 1,
		maxLevel = 2,
		baseCost = 8,
		costStep = 8,
		glyph = "🎒",
	},
	{
		id = "TowerSense",
		name = "Tower Sense",
		description = "+5% tower bonus per level",
		perLevel = 0.05,
		maxLevel = 10,
		baseCost = 3,
		costStep = 2,
		glyph = "🗼",
	},
}

local byId: { [string]: Perk } = {}
for _, p in list do
	byId[p.id] = p
end

return { List = list, ById = byId }
