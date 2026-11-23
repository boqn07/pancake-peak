--!strict
-- Yeti Feast (rebirth). Resets Maple and upgrades; keeps zones, Nibblers, Spatulas and perks.
return {
	RequiredZone = "CocoaCliffs",
	BaseCost = 12_000_000,
	CostGrowth = 3.2,
	-- Permanent Maple multiplier per Feast (additive: 1 + PerRebirth * n).
	PerRebirth = 0.25,
	-- Golden Spatulas per Feast: Base + one per full power of ten of Maple banked above the cost.
	SpatulasBase = 3,
	SpatulasMaxBonus = 5,
	-- Extra Nibbler slot after these Feasts.
	BonusSlotsAt = { 1, 3, 6 },
}
