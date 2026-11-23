--!strict
-- Base Camp (the hub) and the five mountain zones. Zones are snowy plateaus (center + radius) on the
-- flanks of Pancake Peak, joined to Base Camp by ramps, above a sea of clouds. Each zone has its own
-- pancake flavor, value and three hungry Yetis. See Config/Stack for the shared stacking rules.
export type Zone = {
	id: string,
	name: string,
	order: number,
	unlockCost: number,
	center: { x: number, y: number, z: number },
	radius: number,
	-- Maple for one full-size, ordinary pancake served to this zone's Yetis (before the tower bonus
	-- and multipliers).
	value: number,
	flavor: string, -- pancake name shown in UI
	batter: string, -- pancake color (hex)
	crust: string, -- pancake edge color (hex)
	egg: string,
	accent: string,
	ground: string, -- plateau top color
	tagline: string,
}

local list: { Zone } = {
	{
		id = "MapleMeadow",
		name = "Maple Meadow",
		order = 1,
		unlockCost = 0,
		center = { x = 0, y = 4, z = -230 },
		radius = 90,
		value = 1,
		flavor = "Buttermilk",
		batter = "#F7C873",
		crust = "#C9822F",
		egg = "MapleEgg",
		accent = "#F2A33A",
		ground = "#F4F7FB",
		tagline = "Golden maples and the first hungry Yetis",
	},
	{
		id = "PineconeVillage",
		name = "Pinecone Village",
		order = 2,
		unlockCost = 1_200,
		center = { x = 225, y = 12, z = -60 },
		radius = 95,
		value = 5,
		flavor = "Blueberry",
		batter = "#B9A7E8",
		crust = "#6A55B3",
		egg = "PineconeEgg",
		accent = "#4F8A5B",
		ground = "#EEF4F8",
		tagline = "Chalets, pine trees and blueberry batter",
	},
	{
		id = "FrostyFalls",
		name = "Frosty Falls",
		order = 3,
		unlockCost = 35_000,
		center = { x = 150, y = 20, z = 215 },
		radius = 100,
		value = 25,
		flavor = "Strawberry",
		batter = "#FFB3C1",
		crust = "#E0607E",
		egg = "FrostEgg",
		accent = "#5CC8F0",
		ground = "#EAF6FF",
		tagline = "A frozen waterfall and strawberry stacks",
	},
	{
		id = "CocoaCliffs",
		name = "Cocoa Cliffs",
		order = 4,
		unlockCost = 800_000,
		center = { x = -155, y = 28, z = 210 },
		radius = 105,
		value = 125,
		flavor = "Chocolate",
		batter = "#9C6B4E",
		crust = "#5A3A28",
		egg = "CocoaEgg",
		accent = "#B5653A",
		ground = "#F3EEE9",
		tagline = "Steaming cocoa springs on red rock",
	},
	{
		id = "AuroraSummit",
		name = "Aurora Summit",
		order = 5,
		unlockCost = 80_000_000,
		center = { x = -260, y = 36, z = -60 },
		radius = 110,
		value = 625,
		flavor = "Starlight",
		batter = "#BFF3E6",
		crust = "#7B6CF0",
		egg = "AuroraEgg",
		accent = "#7B6CF0",
		ground = "#E8EEFF",
		tagline = "Crystal ice under the northern lights",
	},
}

local byId: { [string]: Zone } = {}
for _, z in list do
	byId[z.id] = z
end

return {
	List = list,
	ById = byId,
	Hub = { center = { x = 0, y = 4, z = 0 }, radius = 60 },
	RampWidth = 22,
	-- Three Yeti tables per zone on a ring (fraction of the zone radius), facing the zone center.
	YetiRing = 0.58,
	YetisPerZone = 3,
	-- The plaza in each zone's center (where the Great Yeti sits during an Order), radius in studs.
	PlazaRadius = 18,
	-- Anyone below this height (fell into the clouds) is carried back to land.
	CloudKillY = -12,
}
