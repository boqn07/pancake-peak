--!strict
-- The 30 Nibblers: snack-loving mountain critters that hop along behind you.
-- power: added to the Maple multiplier when equipped (+0.10 = +10%).
-- steady: added to the perfect window (studs) when equipped.
-- look: body/accent colors and features for the code-built model (client Controllers/NibblerModels).
-- meshId: optional uploaded mesh for the body (empty = code-built).
export type Nibbler = {
	id: string,
	name: string,
	rarity: string,
	egg: string,
	power: number,
	steady: number,
	look: { body: string, accent: string, size: number, features: { string } },
	meshId: string?,
}

local RARITY_POWER = {
	Common = 0.10,
	Uncommon = 0.18,
	Rare = 0.32,
	Epic = 0.60,
	Legendary = 1.2,
	Mythic = 2.5,
}
local EGG_FACTOR = {
	MapleEgg = 1,
	PineconeEgg = 2.4,
	FrostEgg = 5.5,
	CocoaEgg = 12,
	AuroraEgg = 26,
}

-- Optional uploaded meshes for Nibbler bodies: MESH_IDS.Pip = "rbxassetid://...".
-- Species without an entry keep the code-built look (client Controllers/NibblerModels).
local MESH_IDS: { [string]: string } = {}

local function n(id, name, rarity, egg, steady, body, accent, size, features): Nibbler
	return {
		id = id,
		name = name,
		rarity = rarity,
		egg = egg,
		power = math.floor(RARITY_POWER[rarity] * EGG_FACTOR[egg] * 100 + 0.5) / 100,
		steady = steady,
		look = { body = body, accent = accent, size = size, features = features },
		meshId = MESH_IDS[id] or "",
	}
end

-- Feature names understood by NibblerModels: Ears, LongEars, RoundEars, Tail, FluffyTail, Beak,
-- Wings, Antlers, Horns, Tusks, Horn, ChefHat, Scarf, Mask, Stripes, Spots, Crest, Glow.
local list: { Nibbler } = {
	-- Maple Meadow
	n("Pip", "Pip the Chick", "Common", "MapleEgg", 0, "#FFE07A", "#FF9F43", 0.8, { "Beak", "Wings" }),
	n("Muffin", "Muffin Mouse", "Uncommon", "MapleEgg", 0.02, "#D9B48C", "#FF9FB2", 0.85, { "RoundEars", "Tail" }),
	n("Waffles", "Waffles Pup", "Rare", "MapleEgg", 0, "#E8B46A", "#7A4A2A", 0.95, { "Ears", "Tail", "Spots" }),
	n("SyrupFox", "Syrup Fox", "Epic", "MapleEgg", 0.04, "#E07A2E", "#FFF3E0", 1.0, { "Ears", "FluffyTail" }),
	n(
		"ChefPenguin",
		"Chef Penguin",
		"Legendary",
		"MapleEgg",
		0,
		"#2B3A55",
		"#FFFFFF",
		1.05,
		{ "Beak", "ChefHat", "Wings" }
	),
	n("MapleStag", "Maple Stag", "Mythic", "MapleEgg", 0.06, "#C9822F", "#F2A33A", 1.25, { "Antlers", "Tail", "Glow" }),
	-- Pinecone Village
	n("Acorn", "Acorn Squirrel", "Common", "PineconeEgg", 0, "#B5733F", "#F3D9B5", 0.85, { "Ears", "FluffyTail" }),
	n("Berry", "Berry Bunny", "Uncommon", "PineconeEgg", 0.02, "#B9A7E8", "#FFFFFF", 0.9, { "LongEars", "Tail" }),
	n("Hoot", "Hoot the Owl", "Rare", "PineconeEgg", 0, "#8A6A4F", "#F7C873", 0.95, { "Beak", "Wings", "Crest" }),
	n("LumberBear", "Lumber Bear", "Epic", "PineconeEgg", 0.04, "#7A4F33", "#E5484D", 1.1, { "RoundEars", "Scarf" }),
	n(
		"BlueJay",
		"Bluebell Jay",
		"Legendary",
		"PineconeEgg",
		0,
		"#3C7DD9",
		"#FFFFFF",
		1.0,
		{ "Beak", "Wings", "Crest" }
	),
	n(
		"PineMoose",
		"Pine Moose",
		"Mythic",
		"PineconeEgg",
		0.07,
		"#6B4A33",
		"#4F8A5B",
		1.3,
		{ "Antlers", "Scarf", "Glow" }
	),
	-- Frosty Falls
	n("Sleet", "Sleet the Snowball", "Common", "FrostEgg", 0, "#F4FAFF", "#5CC8F0", 0.85, { "Scarf" }),
	n("Puffin", "Puffin Puff", "Uncommon", "FrostEgg", 0.03, "#2B3A55", "#FF8A3C", 0.9, { "Beak", "Wings" }),
	n("ArcticHare", "Arctic Hare", "Rare", "FrostEgg", 0, "#FFFFFF", "#FFB3C1", 0.95, { "LongEars", "Tail" }),
	n("SnowOwl", "Snowy Owl", "Epic", "FrostEgg", 0.05, "#F4F7FB", "#2B3A55", 1.05, { "Beak", "Wings", "Spots" }),
	n("Walrus", "Wally Walrus", "Legendary", "FrostEgg", 0, "#A8846A", "#FFFFFF", 1.15, { "Tusks", "Scarf" }),
	n(
		"FrostDragon",
		"Frost Dragon",
		"Mythic",
		"FrostEgg",
		0.08,
		"#8FD8FF",
		"#FFFFFF",
		1.3,
		{ "Wings", "Horns", "Glow" }
	),
	-- Cocoa Cliffs
	n("Marsh", "Marsh Mallow", "Common", "CocoaEgg", 0, "#FFF6EA", "#9C6B4E", 0.85, { "RoundEars" }),
	n("Goatie", "Goatie", "Uncommon", "CocoaEgg", 0.03, "#E9E1D6", "#7A5A44", 0.95, { "Horns", "Tail" }),
	n("RedPanda", "Red Panda", "Rare", "CocoaEgg", 0, "#C8562B", "#FFFFFF", 1.0, { "RoundEars", "FluffyTail", "Mask" }),
	n("Ibex", "Cliff Ibex", "Epic", "CocoaEgg", 0.05, "#B08A63", "#5A3A28", 1.1, { "Horns", "Tail" }),
	n("CocoaYak", "Cocoa Yak", "Legendary", "CocoaEgg", 0, "#5A3A28", "#F7C873", 1.2, { "Horns", "Scarf" }),
	n("Lavaling", "Lavaling", "Mythic", "CocoaEgg", 0.09, "#FF7A3C", "#FFD23F", 1.3, { "Horn", "Wings", "Glow" }),
	-- Aurora Summit
	n("Twinkle", "Twinkle Seal", "Common", "AuroraEgg", 0, "#E8EEFF", "#7B6CF0", 0.9, { "Spots" }),
	n("Comet", "Comet Kit", "Uncommon", "AuroraEgg", 0.03, "#BFF3E6", "#7B6CF0", 0.95, { "Ears", "FluffyTail" }),
	n("StarFox", "Star Fox", "Rare", "AuroraEgg", 0, "#7B6CF0", "#BFF3E6", 1.0, { "Ears", "FluffyTail", "Glow" }),
	n("Reindeer", "Rosy Reindeer", "Epic", "AuroraEgg", 0.06, "#A0705A", "#FF5F7A", 1.1, { "Antlers", "Scarf" }),
	n("Narwhal", "Nova Narwhal", "Legendary", "AuroraEgg", 0, "#9FB8FF", "#FFFFFF", 1.2, { "Horn", "Tail" }),
	n("AuroraYeti", "Aurora Yeti", "Mythic", "AuroraEgg", 0.1, "#FFFFFF", "#7BFFD8", 1.4, { "Horns", "Glow", "Scarf" }),
}

local byId: { [string]: Nibbler } = {}
for _, x in list do
	byId[x.id] = x
end

return {
	List = list,
	ById = byId,
	-- Sparkly (shiny) variant multiplies power and steady.
	ShinyMult = 2.5,
}
