--!strict
-- ALL Robux products live here. IDs are placeholders (0) until you create them on the Creator Dashboard.
-- See docs/HUMAN_TASKS.md. A 0 id is treated as "not for sale yet" and never errors.
return {
	Passes = {
		DoubleMaple = {
			id = 0,
			name = "2x Maple",
			description = "Double every drop of Maple you earn, forever.",
			price = 299,
		},
		AutoServe = {
			id = 0,
			name = "Auto Serve",
			description = "A full tray is served to your best Yetis by itself. No walking.",
			price = 299,
		},
		SteadySpatula = {
			id = 0,
			name = "Steady Spatula",
			description = "+50% PERFECT window.",
			price = 199,
		},
		ExtraPockets = {
			id = 0,
			name = "Extra Pockets",
			description = "+3 Nibbler slots.",
			price = 349,
		},
		LuckyYolk = {
			id = 0,
			name = "Lucky Yolk",
			description = "Better odds for rare Nibblers.",
			price = 249,
		},
		TripleHatch = {
			id = 0,
			name = "Triple Hatch",
			description = "Hatch 3 eggs at once.",
			price = 199,
		},
		FastHatch = {
			id = 0,
			name = "Fast Hatch",
			description = "Much faster egg reveals.",
			price = 99,
		},
	},
	-- Order shown in the store.
	PassOrder = {
		"DoubleMaple",
		"AutoServe",
		"SteadySpatula",
		"ExtraPockets",
		"LuckyYolk",
		"TripleHatch",
		"FastHatch",
	},

	-- Developer products. grant: what the server does on a successful receipt.
	Products = {
		MaplePouch = {
			id = 0,
			name = "Maple Pouch",
			price = 25,
			grant = { kind = "Maple", minutes = 10, min = 500 },
		},
		MapleJar = {
			id = 0,
			name = "Maple Jar",
			price = 99,
			grant = { kind = "Maple", minutes = 60, min = 4_000 },
		},
		MapleBarrel = {
			id = 0,
			name = "Maple Barrel",
			price = 349,
			grant = { kind = "Maple", minutes = 300, min = 25_000 },
		},
		Boost2x = {
			id = 0,
			name = "2x Maple (15 min)",
			price = 39,
			grant = { kind = "Boost", boost = "Maple2x", seconds = 15 * 60 },
		},
		BoostLucky = {
			id = 0,
			name = "Lucky Boost (15 min)",
			price = 39,
			grant = { kind = "Boost", boost = "Lucky", seconds = 15 * 60 },
		},
		SummonYeti = { id = 0, name = "Summon the Great Yeti", price = 79, grant = { kind = "Order" } },
	},
	ProductOrder = { "MaplePouch", "MapleJar", "MapleBarrel", "Boost2x", "BoostLucky", "SummonYeti" },

	DoubleMapleMult = 2,
	SteadySpatulaMult = 1.5,
	ExtraPocketsSlots = 3,
	-- Boosts stack time, up to this many seconds.
	MaxBoostSeconds = 6 * 60 * 60,
}
