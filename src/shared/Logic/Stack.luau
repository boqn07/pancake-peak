--!strict
-- Flip & Stack math (the hook). Pure: the server uses it to decide every drop and serve, the client
-- to draw sliding pancakes at the same place and to predict drops instantly, and the pacing model to
-- simulate a player.
--
-- The sliding pancake's position depends only on when it appeared (`start`) and its speed, so every
-- machine computes the same position from the shared server clock without per-frame replication:
--   amplitude A = top radius + Overshoot × base
--   s           = ((t - start) × speed) mod 4A
--   offset      = -A + s for s < 2A, else 3A - s     (a back-and-forth sweep, starting at -A)
-- It slides along X on even layers and Z on odd layers, centered on the top pancake.
--
-- Dropping it at offset d (distance from the top pancake's center):
--   d <= perfect window   PERFECT: same size, centered, combo + 1 (combo >= RegrowAfter regrows it)
--   otherwise             the overhang is sliced off. Two equal circles d apart overlap in a lens
--                         whose largest circle has radius r - d/2, centered halfway between them,
--                         so the new pancake is exactly that circle.
--   new radius < MinRadius × base: the tower topples.
local Cfg = require(script.Parent.Parent.Config.Stack)

local Stack = {}

export type Layer = {
	x: number,
	z: number,
	r: number,
	perfect: boolean,
	sprinkle: boolean,
	fluff: number, -- value weight: (r / base)² × perfect × sprinkle multipliers
	flavor: number, -- zone order where it was cooked (color only)
}

export type State = {
	baseR: number,
	layers: { Layer },
	topX: number,
	topZ: number,
	topR: number,
	combo: number,
	bestCombo: number,
	start: number, -- server time the current sliding pancake appeared
	speed: number, -- its speed (studs/s)
	sprinkle: boolean, -- the current sliding pancake is a sprinkle pancake
	toppled: boolean,
}

export type DropResult = {
	kind: string, -- "perfect" | "good" | "topple"
	offset: number, -- signed offset along the slide axis at the moment of the drop
	layer: Layer?, -- the new layer (nil on topple)
	cut: number, -- studs sliced off (0 when perfect)
}

function Stack.new(baseR: number): State
	return {
		baseR = baseR,
		layers = {},
		topX = 0,
		topZ = 0,
		topR = baseR,
		combo = 0,
		bestCombo = 0,
		start = 0,
		speed = Cfg.SlideSpeed,
		sprinkle = false,
		toppled = false,
	}
end

-- Slide speed for the pancake that goes on a stack of `n` layers. `factor` covers zone/Snow Day.
function Stack.speedFor(n: number, factor: number?): number
	return Cfg.SlideSpeed * math.min(1 + Cfg.SpeedPerLayer * n, Cfg.MaxSpeedFactor) * (factor or 1)
end

-- Start the next sliding pancake.
function Stack.arm(st: State, start: number, speed: number, sprinkle: boolean)
	st.start = start
	st.speed = speed
	st.sprinkle = sprinkle
end

-- Unit slide axis for the pancake that goes on a stack of `n` layers.
function Stack.axis(n: number): (number, number)
	if n % 2 == 0 then
		return 1, 0
	end
	return 0, 1
end

function Stack.amplitude(st: State): number
	return st.topR + Cfg.Overshoot * st.baseR
end

-- Signed offset of the sliding pancake from the top pancake's center at server time t.
function Stack.offsetAt(st: State, t: number): number
	local A = Stack.amplitude(st)
	if t <= st.start then
		return -A
	end
	local period = 4 * A
	local s = ((t - st.start) * st.speed) % period
	if s < 2 * A then
		return -A + s
	end
	return 3 * A - s
end

-- World-free position (tray space) of the sliding pancake at server time t.
function Stack.sliderPos(st: State, t: number): (number, number)
	local off = Stack.offsetAt(st, t)
	local ax, az = Stack.axis(#st.layers)
	return st.topX + ax * off, st.topZ + az * off
end

-- Seconds from `start` until the sliding pancake first crosses the center (handy for bots/tests).
function Stack.firstCenterTime(st: State): number
	return st.start + Stack.amplitude(st) / st.speed
end

function Stack.fluffOf(r: number, baseR: number, perfect: boolean, sprinkle: boolean): number
	local f = r / baseR
	return f * f * (if perfect then Cfg.PerfectMult else 1) * (if sprinkle then Cfg.SprinkleMult else 1)
end

-- Drop the sliding pancake at server time t. Mutates st. `window` is the perfect window (studs).
function Stack.drop(st: State, t: number, window: number, flavor: number): DropResult
	local off = Stack.offsetAt(st, t)
	local d = math.abs(off)
	local ax, az = Stack.axis(#st.layers)
	local perfect = d <= window
	local x, z, r
	if perfect then
		x, z, r = st.topX, st.topZ, st.topR
		st.combo += 1
		if st.combo >= Cfg.RegrowAfter then
			r = math.min(st.baseR, r + Cfg.RegrowFraction * st.baseR)
		end
		if st.combo > st.bestCombo then
			st.bestCombo = st.combo
		end
	else
		st.combo = 0
		r = st.topR - d / 2
		if r < Cfg.MinRadius * st.baseR then
			st.toppled = true
			return { kind = "topple", offset = off, layer = nil, cut = d }
		end
		x, z = st.topX + ax * off / 2, st.topZ + az * off / 2
	end
	local layer: Layer = {
		x = x,
		z = z,
		r = r,
		perfect = perfect,
		sprinkle = st.sprinkle,
		fluff = Stack.fluffOf(r, st.baseR, perfect, st.sprinkle),
		flavor = flavor,
	}
	table.insert(st.layers, layer)
	st.topX, st.topZ, st.topR = x, z, r
	return { kind = if perfect then "perfect" else "good", offset = off, layer = layer, cut = if perfect then 0 else d }
end

-- Tower bonus for a stack of n pancakes.
function Stack.towerBonus(n: number, towerK: number): number
	if n <= 1 then
		return 1
	end
	return 1 + towerK * (n - 1) ^ Cfg.TowerExp
end

function Stack.totalFluff(st: State): number
	local s = 0
	for _, l in st.layers do
		s += l.fluff
	end
	return s
end

-- Base Maple a stack is worth when served (before player multipliers).
function Stack.value(st: State, zoneValue: number, towerK: number, craving: boolean?): number
	local n = #st.layers
	if n == 0 then
		return 0
	end
	return zoneValue * Stack.totalFluff(st) * Stack.towerBonus(n, towerK) * (if craving then Cfg.CravingMult else 1)
end

-- Same as value() from plain numbers (UI previews, the income estimate, bots).
function Stack.valueOf(n: number, fluff: number, zoneValue: number, towerK: number): number
	if n <= 0 then
		return 0
	end
	return zoneValue * fluff * Stack.towerBonus(n, towerK)
end

-- The height window a Yeti craves right now. Deterministic from the server clock, so the server,
-- every client and the tests agree without any replication. yetiIndex 1..3 picks the band.
function Stack.craving(zoneOrder: number, yetiIndex: number, t: number): (number, number)
	local band = Cfg.CravingBands[yetiIndex] or Cfg.CravingBands[1]
	local p = math.floor(t / Cfg.CravingPeriod)
	local h = (p * 7919 + zoneOrder * 104729 + yetiIndex * 1299709) % 2147483647
	h = (h * 48271) % 2147483647
	h = (h * 48271) % 2147483647
	local span = math.max(1, band[2] - band[1] - Cfg.CravingWidth + 1)
	local lo = band[1] + h % span
	return lo, lo + Cfg.CravingWidth
end

-- Server time when the current cravings change.
function Stack.cravingEndsAt(t: number): number
	return (math.floor(t / Cfg.CravingPeriod) + 1) * Cfg.CravingPeriod
end

function Stack.inCraving(n: number, lo: number, hi: number): boolean
	return n >= lo and n <= hi
end

-- Clamp a client-reported drop time into what the server accepts.
function Stack.acceptTime(clientT: number, now: number, start: number): number
	local t = math.clamp(clientT, now - Cfg.MaxLag, now)
	return math.max(t, start)
end

return Stack
