--!strict
-- Flip & Stack: the game's hook. See Logic/Stack for the math these numbers feed.
-- A pancake slides back and forth over the top of your stack; you drop it. Whatever hangs over
-- the edge is sliced off, so the next pancake is smaller. Perfect drops keep the full size.
-- All lengths are studs unless marked "× base" (multiples of the player's pan radius).
return {
	LayerHeight = 0.36,
	-- The sliding pancake swings this far past the top pancake's edge (× base) on each side.
	Overshoot = 0.75,
	-- Slide speed (studs per second, before multipliers). It speeds up with height:
	-- speed = SlideSpeed * (1 + SpeedPerLayer * layers) capped at MaxSpeedFactor, times zone/Snow Day.
	SlideSpeed = 4.4,
	SpeedPerLayer = 0.012,
	MaxSpeedFactor = 1.7,
	-- A new pancake appears this long after a drop.
	NextDelay = 0.28,
	-- Perfect: the drop lands within the perfect window (studs, from Steady Hands). It keeps the
	-- full size and counts toward the combo. From RegrowAfter perfects in a row, each perfect also
	-- grows the pancake back by RegrowFraction × base (never above base).
	RegrowAfter = 3,
	RegrowFraction = 0.05,
	-- A pancake smaller than MinRadius × base slips off: the tower topples.
	MinRadius = 0.16,
	-- Pancake value ("fluff") = (radius / base)² × PerfectMult if perfect × SprinkleMult if sprinkled.
	PerfectMult = 1.5,
	SprinkleChance = 0.04,
	SprinkleMult = 5,
	-- Tower bonus for n pancakes: 1 + towerK * (n - 1) ^ TowerExp. towerK = TowerK × Tower Sense.
	TowerK = 0.08,
	TowerExp = 1.25,
	-- A toppled tower still pays this share as crumbs.
	ToppleRefund = 0.25,
	-- Network: the client sends the server time of its tap. The server accepts times up to MaxLag
	-- seconds in the past (and clamps anything later than now). One drop per MinDropInterval.
	MaxLag = 0.6,
	MinDropInterval = 0.22,
	-- Serving: stand within ServeDistance of a Yeti (studs, horizontally) with at least one pancake.
	ServeDistance = 20,
	ServeCooldown = 0.8,
	MaxHeightDiff = 14,
	-- Cravings: every Yeti wants a height in a window; serving inside it pays CravingMult.
	-- Each of a zone's three Yetis uses one band; windows are CravingWidth tall and change every
	-- CravingPeriod seconds (the same everywhere: derived from the server clock).
	CravingBands = { { 5, 12 }, { 12, 22 }, { 22, 40 } },
	CravingWidth = 4,
	CravingPeriod = 120,
	CravingMult = 2,
	-- Tips: other active chefs within ShareRadius of a serve get ShareFraction of its value
	-- (with their own multipliers). Active = dropped a pancake in the last ShareActiveSeconds.
	ShareRadius = 40,
	ShareFraction = 0.15,
	ShareActiveSeconds = 30,
	-- Towers this tall are announced to the server.
	AnnounceHeight = 40,
	AnnounceCooldown = 20,
	-- Auto Serve pass: when the tray is full, the stack is served to your best zone automatically.
	AutoServeDelay = 0.6,
}
