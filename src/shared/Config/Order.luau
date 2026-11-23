--!strict
-- The Great Yeti's Order: the co-op server event. The Great Yeti stomps into the plaza of the busiest
-- zone and wants a mountain of pancakes. Every pancake served to it (from within ServeReach of the
-- plaza) fills the shared order. Target = BaseLayers * (1 + LayersPerExtraPlayer * (players in the
-- zone - 1)), so a solo player fills it in about a minute and a group much faster. Filling it pays
-- every contributor and starts a server-wide Snow Day.
return {
	IntervalSeconds = 8 * 60,
	FirstDelaySeconds = 3 * 60,
	DurationSeconds = 120,
	BaseLayers = 45,
	LayersPerExtraPlayer = 0.6,
	-- Studs from the plaza center within which you can serve the Great Yeti.
	ServeReach = 30,
	-- Contributors who served at least MinShare of the order get RewardMinutes of estimated income.
	MinShare = 0.05,
	RewardMinutes = 3,
	RewardMin = 150,
	-- Snow Day (whole server): Maple × SnowMult and pancakes slide at SnowSlowFactor of their speed.
	SnowSeconds = 90,
	SnowMult = 2,
	SnowSlowFactor = 0.75,
}
