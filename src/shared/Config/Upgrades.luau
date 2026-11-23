--!strict
-- Maple upgrades. effect(level) = base + perLevel * level; cost(level) = baseCost * growth^level.
-- display: how the panel formats the effect ("mult", "studs", "speed", "layers", "radius").
export type Upgrade = {
	id: string,
	name: string,
	description: string,
	glyph: string,
	base: number,
	perLevel: number,
	maxLevel: number,
	baseCost: number,
	growth: number,
	display: string,
}

local list: { Upgrade } = {
	{
		id = "Batter",
		name = "Fluffy Batter",
		description = "Every pancake is worth more Maple",
		glyph = "🥞",
		base = 1,
		perLevel = 0.2,
		maxLevel = 100,
		baseCost = 10,
		growth = 1.32,
		display = "mult",
	},
	{
		id = "Steady",
		name = "Steady Hands",
		description = "Wider window for PERFECT drops",
		glyph = "🎯",
		base = 0.16,
		perLevel = 0.008,
		maxLevel = 30,
		baseCost = 25,
		growth = 1.45,
		display = "studs",
	},
	{
		id = "Pan",
		name = "Big Pan",
		description = "Bigger pancakes: more room for wobbly drops",
		glyph = "🍳",
		base = 1.6,
		perLevel = 0.04,
		maxLevel = 30,
		baseCost = 40,
		growth = 1.48,
		display = "radius",
	},
	{
		id = "Tray",
		name = "Tall Tray",
		description = "Carry taller stacks",
		glyph = "🍽️",
		base = 15,
		perLevel = 1,
		maxLevel = 45,
		baseCost = 30,
		growth = 1.33,
		display = "layers",
	},
	{
		id = "Boots",
		name = "Snow Boots",
		description = "Walk faster",
		glyph = "🥾",
		base = 16,
		perLevel = 0.4,
		maxLevel = 35,
		baseCost = 35,
		growth = 1.45,
		display = "speed",
	},
}

local byId: { [string]: Upgrade } = {}
for _, u in list do
	byId[u.id] = u
end

return { List = list, ById = byId }
