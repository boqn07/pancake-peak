-- A deterministic model of an average player, used to check that config numbers hit the GDD pacing
-- targets. Unlike a formula, it plays the real stacking rules (Logic/Stack): every pancake slides at
-- the configured speed and the bot drops it near the center with a human timing error, so slices,
-- perfects, combos, regrowth and topples all happen as in the game. It aims for a Yeti's craving it
-- can reach, serves, and spends Maple like a player would. Use it to compare balance changes, not as
-- ground truth.
local L = require("./Loader")

local Schema = L.get("Shared/Logic/Schema")
local Economy = L.get("Shared/Logic/Economy")
local Progression = L.get("Shared/Logic/Progression")
local UpgradeMath = L.get("Shared/Logic/UpgradeMath")
local Inventory = L.get("Shared/Logic/Inventory")
local Hatch = L.get("Shared/Logic/Hatch")
local Stack = L.get("Shared/Logic/Stack")
local SafeNumber = L.get("Shared/Logic/SafeNumber")
local Zones = L.get("Shared/Config/Zones")
local Eggs = L.get("Shared/Config/Eggs")
local Nibblers = L.get("Shared/Config/Nibblers")
local Upgrades = L.get("Shared/Config/Upgrades")
local Perks = L.get("Shared/Config/Perks")
local StackCfg = L.get("Shared/Config/Stack")

local Sim = {}

-- Human timing error (seconds, standard deviation) around the moment the pancake is centered.
Sim.TIMING_SD = 0.075
-- Chance a player lets the pancake pass once before dropping (hesitation).
Sim.HESITATE = 0.2
-- Seconds lost per serve (walking to a Yeti, lining up) beyond what stacking-while-walking hides.
Sim.SERVE_OVERHEAD = 4
-- Real players aren't stacking every second (camera, menus, chatting): time is stretched by this.
Sim.DISTRACTION = 1.25
-- Stop early when the top pancake is this small (× base) and the stack is at least SAFE_MIN tall.
Sim.SAFE_RADIUS = 0.42
Sim.SAFE_MIN = 6

-- Runs the bot for `seconds`; returns milestone times (seconds), the final profile, a log and stats.
function Sim.run(seconds: number, opts: { passes: { [string]: boolean }?, seed: number?, trace: number? }?)
	opts = opts or {}
	local profile = Schema.default()
	local ctx = { passes = opts.passes or {}, friends = 0, snowDay = false }
	local seed = opts.seed or 1
	local rng = function()
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	local function gauss()
		local u1, u2 = math.max(rng(), 1e-9), rng()
		return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
	end
	local milestones =
		{ firstDrop = nil, firstServe = nil, firstUpgrade = nil, firstEgg = nil, zones = {}, rebirths = {} }
	local log = {}
	local stats = { serves = 0, pancakes = 0, perfects = 0, topples = 0, cravings = 0, heightSum = 0, earned = 0 }
	local lastEarned, lastT = 0, 0
	local nextTrace = opts.trace or math.huge

	local function nextZone()
		for _, z in Zones.List do
			if not profile.zones[z.id] then
				return z
			end
		end
		return nil
	end

	local function earn(amount)
		profile.maple = SafeNumber.add(profile.maple, amount)
		profile.lifetimeMaple = SafeNumber.add(profile.lifetimeMaple, amount)
		stats.earned += amount
	end

	-- Spend Maple like a player: next zone first, then Feast, then the cheapest useful thing.
	local function shop(t)
		for _ = 1, 6 do
			local nz = nextZone()
			if nz and Progression.unlockZone(profile, nz.id) then
				milestones.zones[nz.id] = milestones.zones[nz.id] or t
				table.insert(log, string.format("%6.1f min  unlock %s", t / 60, nz.name))
				continue
			end
			local ok, _, spatulas = Progression.rebirth(profile)
			if ok then
				table.insert(milestones.rebirths, t)
				table.insert(
					log,
					string.format("%6.1f min  YETI FEAST #%d (+%d spatulas)", t / 60, profile.rebirths, spatulas)
				)
				while true do
					local bestP, bestCost = nil, math.huge
					for _, p in Perks.List do
						local lvl = profile.perks[p.id]
						if lvl < p.maxLevel then
							local c = Progression.perkCost(p.id, lvl)
							if c < bestCost then
								bestP, bestCost = p.id, c
							end
						end
					end
					if not bestP or not Progression.buyPerk(profile, bestP) then
						break
					end
				end
				continue
			end
			local budget = if nz then nz.unlockCost * 0.4 else Economy.rebirthCost(profile.rebirths) * 0.4
			local bestCost, bestAction = math.huge, nil
			for _, u in Upgrades.List do
				local lvl = profile.upgrades[u.id]
				if lvl < u.maxLevel then
					local c = UpgradeMath.cost(u.id, lvl)
					if c < bestCost then
						bestCost, bestAction = c, { kind = "upgrade", id = u.id }
					end
				end
			end
			local egg = Eggs.ById[Zones.ById[Economy.bestZone(profile)].egg]
			local fromBest = 0
			for _, item in profile.nibblers do
				if Nibblers.ById[item.id].egg == egg.id then
					fromBest += 1
				end
			end
			local wantEgg = fromBest < Economy.equipSlots(profile, ctx) * 2
			local effective = if wantEgg then egg.cost * 0.5 else egg.cost * 5
			if effective < bestCost and Inventory.hasRoom(profile, 1) then
				bestCost, bestAction = egg.cost, { kind = "egg", id = egg.id }
			end
			if not bestAction or bestCost > profile.maple or bestCost > math.max(budget, 15) then
				break
			end
			if bestAction.kind == "upgrade" then
				Progression.buyUpgrade(profile, bestAction.id)
				milestones.firstUpgrade = milestones.firstUpgrade or t
			else
				local spent, bal = SafeNumber.trySpend(profile.maple, egg.cost)
				if spent then
					profile.maple = bal
					local luck = if ctx.passes.LuckyYolk then Eggs.LuckyPassLuck else 1
					local id, shiny = Hatch.roll(egg.id, luck, ctx.passes.LuckyYolk == true, rng)
					Inventory.add(profile, id, shiny, t)
					Inventory.equipBest(profile, Economy.equipSlots(profile, ctx))
					milestones.firstEgg = milestones.firstEgg or t
				end
			end
		end
	end

	-- Pick the stack height to aim for: the highest Yeti craving the tray can reach (or the tray).
	local function pickTarget(t)
		local tray = Economy.trayMax(profile)
		local zone = Zones.ById[Economy.bestZone(profile)]
		local best, bestYeti = nil, nil
		for i = 1, Zones.YetisPerZone do
			local lo, hi = Stack.craving(zone.order, i, t)
			if lo <= tray then
				local want = math.min(hi, tray)
				if not best or want > best then
					best, bestYeti = want, i
				end
			end
		end
		return best or tray, bestYeti
	end

	local t = 0
	local autoServe = ctx.passes.AutoServe == true
	while t < seconds do
		local zone = Zones.ById[Economy.bestZone(profile)]
		local target, yeti = pickTarget(t)
		local st = Stack.new(Economy.panRadius(profile))
		local window = Economy.perfectWindow(profile, ctx)
		local towerK = Economy.towerK(profile)
		local tray = Economy.trayMax(profile)
		if autoServe then
			target = tray -- Auto Serve fires when the tray is full
		end
		local cycleStart = t
		Stack.arm(st, t + StackCfg.NextDelay, Stack.speedFor(0), rng() < StackCfg.SprinkleChance)
		while #st.layers < target do
			local crossing = Stack.firstCenterTime(st)
			if rng() < Sim.HESITATE then
				crossing += 2 * Stack.amplitude(st) / st.speed
			end
			local dropT = crossing + gauss() * Sim.TIMING_SD
			dropT = math.max(dropT, st.start + 0.05)
			local r = Stack.drop(st, dropT, window, zone.order)
			t = dropT
			milestones.firstDrop = milestones.firstDrop or t
			if r.kind == "topple" then
				break
			end
			stats.pancakes += 1
			if r.kind == "perfect" then
				stats.perfects += 1
			end
			if
				not autoServe
				and #st.layers >= Sim.SAFE_MIN
				and st.topR < Sim.SAFE_RADIUS * st.baseR
				and #st.layers < target
			then
				break -- getting wobbly: serve what we have
			end
			Stack.arm(st, t + StackCfg.NextDelay, Stack.speedFor(#st.layers), rng() < StackCfg.SprinkleChance)
		end
		local n = #st.layers
		local craving = false
		if not st.toppled and yeti and not autoServe then
			local lo, hi = Stack.craving(zone.order, yeti, t)
			craving = Stack.inCraving(n, lo, hi)
		end
		local base = Stack.value(st, zone.value, towerK, craving)
		if st.toppled then
			base *= StackCfg.ToppleRefund
			stats.topples += 1
		else
			stats.serves += 1
			stats.heightSum += n
			if craving then
				stats.cravings += 1
			end
		end
		earn(Economy.serveReward(profile, ctx, base))
		milestones.firstServe = milestones.firstServe or t
		t += if autoServe then StackCfg.AutoServeDelay + 0.5 else Sim.SERVE_OVERHEAD
		-- Distraction: stretch the whole cycle.
		t += (t - cycleStart) * (Sim.DISTRACTION - 1)
		shop(t)
		if t >= nextTrace then
			nextTrace += opts.trace :: number
			table.insert(
				log,
				string.format(
					"%6.1f min  %-15s maple=%-9s est/s=%-8s act/s=%-8s Ba=%d St=%d Pa=%d Tr=%d Bo=%d mult=%.1f avgH=%.1f perf=%.0f%%",
					t / 60,
					zone.id,
					string.format("%.3g", profile.maple),
					string.format("%.3g", Economy.estimatedIncome(profile, ctx)),
					string.format("%.3g", (stats.earned - lastEarned) / math.max(1, t - lastT)),
					profile.upgrades.Batter,
					profile.upgrades.Steady,
					profile.upgrades.Pan,
					profile.upgrades.Tray,
					profile.upgrades.Boots,
					Economy.multipliers(profile, ctx).total,
					if stats.serves > 0 then stats.heightSum / stats.serves else 0,
					100 * stats.perfects / math.max(1, stats.pancakes)
				)
			)
			lastEarned, lastT = stats.earned, t
		end
	end
	stats.avgHeight = if stats.serves > 0 then stats.heightSum / stats.serves else 0
	return milestones, profile, log, stats
end

return Sim
