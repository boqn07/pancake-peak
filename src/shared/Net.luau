--!strict
-- The remote contract. The server creates these remotes at boot; the client waits for them.
-- rate = calls per second refilled, burst = max calls in a burst (token bucket per player).
return {
	FolderName = "Remotes",
	ClientToServer = {
		Drop = { rate = 6, burst = 8 }, -- (serverTime: number) drop the sliding pancake
		Serve = { rate = 2, burst = 4 }, -- () serve the stack to the nearest Yeti / the Great Yeti
		BuyUpgrade = { rate = 8, burst = 12 },
		BuyZone = { rate = 1, burst = 3 },
		BuyPerk = { rate = 2, burst = 4 },
		HatchEgg = { rate = 3, burst = 3 },
		Equip = { rate = 10, burst = 20 },
		Unequip = { rate = 10, burst = 20 },
		EquipBest = { rate = 1, burst = 3 },
		Release = { rate = 10, burst = 20 },
		Rebirth = { rate = 0.5, burst = 2 },
		ClaimDaily = { rate = 0.5, burst = 2 },
		ClaimPlaytime = { rate = 1, burst = 4 },
		RedeemCode = { rate = 0.5, burst = 3 },
		SetSetting = { rate = 4, burst = 10 },
		Teleport = { rate = 1, burst = 2 },
		SkipTutorial = { rate = 0.5, burst = 2 },
		StackSnapshot = { rate = 0.2, burst = 2 },
	},
	ServerToClient = {
		"State", -- (payload) changed profile keys + derived values, owner only
		"Stack", -- (all) userId, StackWire: one stack event (new stack, drop, topple, serve)
		"StackSnapshot", -- (one) { [userId]: full stack } for late joiners
		"ServeResult", -- (owner / tipped players) { amount, n, craving, tip, x, y, z, ... }
		"EggResult",
		"Reward",
		"Notify",
		"Announce",
		"Order", -- (all) Great Yeti's Order state
	},
	-- Stack event kinds (field `k` of a Stack event).
	StackKinds = { Reset = 0, Drop = 1, Topple = 2, Served = 3 },
}
