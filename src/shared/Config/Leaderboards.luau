--!strict
-- Global leaderboards shown on the Base Camp signboards. stat: see LeaderboardService STATS.
return {
	Boards = {
		{ title = "Most Maple", store = "PP_LifetimeMaple_v1", stat = "lifetimeMaple", color = "#F2A33A" },
		{ title = "Yeti Feasts", store = "PP_Rebirths_v1", stat = "rebirths", color = "#5CC8F0" },
		{ title = "Tallest Stack", store = "PP_TallestStack_v1", stat = "tallest", color = "#E5484D" },
	},
	Top = 10,
	RefreshSeconds = 120,
	-- Lifetime Maple can exceed what an OrderedDataStore holds, so it is stored as log10(x) * LogScale.
	LogScale = 1e6,
}
