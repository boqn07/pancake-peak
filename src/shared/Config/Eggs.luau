--!strict
-- Mystery Eggs: one per zone, cracked in a giant frying pan. odds: rarity -> probability (sums to 1).
-- nibblers: rarity -> id. These are the exact odds the server rolls with; the egg window shows them
-- with luck applied.
export type Egg = {
	id: string,
	name: string,
	zone: string,
	cost: number,
	color: string,
	odds: { [string]: number },
	nibblers: { [string]: string },
}

local list: { Egg } = {
	{
		id = "MapleEgg",
		name = "Maple Egg",
		zone = "MapleMeadow",
		cost = 40,
		color = "#F2A33A",
		odds = { Common = 0.55, Uncommon = 0.28, Rare = 0.12, Epic = 0.04, Legendary = 0.009, Mythic = 0.001 },
		nibblers = {
			Common = "Pip",
			Uncommon = "Muffin",
			Rare = "Waffles",
			Epic = "SyrupFox",
			Legendary = "ChefPenguin",
			Mythic = "MapleStag",
		},
	},
	{
		id = "PineconeEgg",
		name = "Pinecone Egg",
		zone = "PineconeVillage",
		cost = 3_000,
		color = "#4F8A5B",
		odds = { Common = 0.52, Uncommon = 0.29, Rare = 0.13, Epic = 0.05, Legendary = 0.009, Mythic = 0.001 },
		nibblers = {
			Common = "Acorn",
			Uncommon = "Berry",
			Rare = "Hoot",
			Epic = "LumberBear",
			Legendary = "BlueJay",
			Mythic = "PineMoose",
		},
	},
	{
		id = "FrostEgg",
		name = "Frost Egg",
		zone = "FrostyFalls",
		cost = 100_000,
		color = "#5CC8F0",
		odds = { Common = 0.5, Uncommon = 0.3, Rare = 0.13, Epic = 0.058, Legendary = 0.0105, Mythic = 0.0015 },
		nibblers = {
			Common = "Sleet",
			Uncommon = "Puffin",
			Rare = "ArcticHare",
			Epic = "SnowOwl",
			Legendary = "Walrus",
			Mythic = "FrostDragon",
		},
	},
	{
		id = "CocoaEgg",
		name = "Cocoa Egg",
		zone = "CocoaCliffs",
		cost = 5_000_000,
		color = "#B5653A",
		odds = { Common = 0.48, Uncommon = 0.3, Rare = 0.14, Epic = 0.066, Legendary = 0.012, Mythic = 0.002 },
		nibblers = {
			Common = "Marsh",
			Uncommon = "Goatie",
			Rare = "RedPanda",
			Epic = "Ibex",
			Legendary = "CocoaYak",
			Mythic = "Lavaling",
		},
	},
	{
		id = "AuroraEgg",
		name = "Aurora Egg",
		zone = "AuroraSummit",
		cost = 350_000_000,
		color = "#7B6CF0",
		odds = { Common = 0.46, Uncommon = 0.3, Rare = 0.15, Epic = 0.073, Legendary = 0.0145, Mythic = 0.0025 },
		nibblers = {
			Common = "Twinkle",
			Uncommon = "Comet",
			Rare = "StarFox",
			Epic = "Reindeer",
			Legendary = "Narwhal",
			Mythic = "AuroraYeti",
		},
	},
}

local byId: { [string]: Egg } = {}
for _, e in list do
	byId[e.id] = e
end

return {
	List = list,
	ById = byId,
	-- Luck raises the weight of rarity rank r by luck^((r-1) * LuckExponent).
	LuckExponent = 0.5,
	LuckyPassLuck = 1.6,
	LuckyBoostLuck = 1.5,
	ShinyChance = 1 / 60,
	ShinyChanceLucky = 1 / 30,
	-- Seconds between hatches (server cooldown) and reveal lengths (client).
	OpenCooldown = 2.2,
	OpenCooldownFast = 0.9,
	RevealSeconds = 2.0,
	RevealSecondsFast = 0.7,
}
