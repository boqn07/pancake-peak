-- Flip & Stack rules, economy and progression.
local L = require("./Loader")
return function(T)
	local Stack = L.get("Shared/Logic/Stack")
	local Cfg = L.get("Shared/Config/Stack")
	local Economy = L.get("Shared/Logic/Economy")
	local Progression = L.get("Shared/Logic/Progression")
	local Schema = L.get("Shared/Logic/Schema")
	local UpgradeMath = L.get("Shared/Logic/UpgradeMath")
	local Zones = L.get("Shared/Config/Zones")
	local Rebirth = L.get("Shared/Config/Rebirth")

	local function armed(baseR)
		local st = Stack.new(baseR or 2)
		Stack.arm(st, 10, 4, false)
		return st
	end

	T.describe("Stack: sliding pancake", function()
		T.it("starts at -A, sweeps through the center to +A and back", function()
			local st = armed(2)
			local A = Stack.amplitude(st)
			T.expect(A).toBeNear(2 + Cfg.Overshoot * 2)
			T.expect(Stack.offsetAt(st, 9)).toBeNear(-A)
			T.expect(Stack.offsetAt(st, 10)).toBeNear(-A)
			T.expect(Stack.offsetAt(st, Stack.firstCenterTime(st))).toBeNear(0, 1e-9)
			T.expect(Stack.offsetAt(st, 10 + 2 * A / 4)).toBeNear(A, 1e-9)
			T.expect(Stack.offsetAt(st, 10 + 3 * A / 4)).toBeNear(0, 1e-9)
			T.expect(Stack.offsetAt(st, 10 + 4 * A / 4)).toBeNear(-A, 1e-9)
		end)
		T.it("alternates the slide axis per layer", function()
			local st = armed(2)
			local x, z = Stack.sliderPos(st, 10)
			T.expect(z).toBeNear(0)
			T.expect(x).toBeLessThan(0)
			Stack.drop(st, Stack.firstCenterTime(st), 0.2, 1)
			Stack.arm(st, 20, 4, false)
			x, z = Stack.sliderPos(st, 20)
			T.expect(x).toBeNear(0)
			T.expect(z).toBeLessThan(0)
		end)
		T.it("speeds up with height, up to a cap", function()
			T.expect(Stack.speedFor(10)).toBeGreaterThan(Stack.speedFor(0))
			T.expect(Stack.speedFor(10000)).toBeNear(Cfg.SlideSpeed * Cfg.MaxSpeedFactor)
			T.expect(Stack.speedFor(0, 0.75)).toBeNear(Cfg.SlideSpeed * 0.75)
		end)
	end)

	T.describe("Stack: drops", function()
		T.it("a centered drop is PERFECT: full size, combo, more fluff", function()
			local st = armed(2)
			local r = Stack.drop(st, Stack.firstCenterTime(st), 0.2, 1)
			T.expect(r.kind).toBe("perfect")
			T.expect(r.layer.r).toBeNear(2)
			T.expect(r.layer.fluff).toBeNear(Cfg.PerfectMult)
			T.expect(st.combo).toBe(1)
			T.expect(#st.layers).toBe(1)
		end)
		T.it("an offset drop slices the overhang: radius r - d/2 centered halfway", function()
			local st = armed(2)
			local t = Stack.firstCenterTime(st) + 0.25 -- 1 stud past center at speed 4
			local r = Stack.drop(st, t, 0.2, 1)
			T.expect(r.kind).toBe("good")
			T.expect(r.offset).toBeNear(1, 1e-9)
			T.expect(r.layer.r).toBeNear(1.5, 1e-9)
			T.expect(r.layer.x).toBeNear(0.5, 1e-9)
			T.expect(r.layer.fluff).toBeNear((1.5 / 2) ^ 2, 1e-9)
			T.expect(st.combo).toBe(0)
			-- The new top is the sliced pancake; the next one slides around its center.
			T.expect(st.topX).toBeNear(0.5)
			T.expect(st.topR).toBeNear(1.5)
		end)
		T.it("the lens rule: the new circle fits inside both circles", function()
			local st = armed(2)
			local before = { x = st.topX, z = st.topZ, r = st.topR }
			local t = Stack.firstCenterTime(st) + 0.3
			local off = Stack.offsetAt(st, t)
			local r = Stack.drop(st, t, 0.1, 1)
			local l = r.layer
			-- Inside the old top...
			T.expect(math.abs(l.x - before.x) + l.r).toBeLessThan(before.r + 1e-9)
			-- ...and inside the dropped pancake (center at `off`).
			T.expect(math.abs(l.x - off) + l.r).toBeLessThan(before.r + 1e-9)
		end)
		T.it("a big miss topples the tower", function()
			local st = armed(2)
			local r = Stack.drop(st, 10, 0.2, 1) -- at the far edge (-A)
			T.expect(r.kind).toBe("topple")
			T.expect(st.toppled).toBeTruthy()
			T.expect(#st.layers).toBe(0)
		end)
		T.it("perfect streaks regrow the pancake but never past the pan", function()
			local st = armed(2)
			Stack.drop(st, Stack.firstCenterTime(st) + 0.2, 0.1, 1) -- shrink to 1.6
			local t = 20
			for _ = 1, 8 do
				Stack.arm(st, t, 4, false)
				Stack.drop(st, Stack.firstCenterTime(st), 0.1, 1)
				t += 5
			end
			T.expect(st.combo).toBe(8)
			T.expect(st.bestCombo).toBe(8)
			-- 6 regrows of 0.1 from 1.6 would be 2.2: capped at the pan's 2.
			T.expect(st.topR).toBeNear(2, 1e-9)
		end)
		T.it("sprinkle pancakes are worth SprinkleMult", function()
			local st = Stack.new(2)
			Stack.arm(st, 10, 4, true)
			local r = Stack.drop(st, Stack.firstCenterTime(st), 0.2, 1)
			T.expect(r.layer.sprinkle).toBeTruthy()
			T.expect(r.layer.fluff).toBeNear(Cfg.PerfectMult * Cfg.SprinkleMult)
		end)
		T.it("drop times are clamped to the accepted lag window", function()
			T.expect(Stack.acceptTime(100, 100.2, 0)).toBe(100)
			T.expect(Stack.acceptTime(50, 100, 0)).toBeNear(100 - Cfg.MaxLag)
			T.expect(Stack.acceptTime(200, 100, 0)).toBe(100)
			T.expect(Stack.acceptTime(99.9, 100, 99.95)).toBe(99.95)
		end)
	end)

	T.describe("Stack: value and cravings", function()
		T.it("taller stacks pay superlinearly", function()
			local k = Cfg.TowerK
			T.expect(Stack.towerBonus(1, k)).toBe(1)
			local v10 = Stack.valueOf(10, 10, 1, k)
			local v20 = Stack.valueOf(20, 20, 1, k)
			T.expect(v20).toBeGreaterThan(v10 * 2.2)
			T.expect(Stack.valueOf(0, 0, 1, k)).toBe(0)
		end)
		T.it("value() matches valueOf() and applies the craving bonus", function()
			local st = armed(2)
			for i = 1, 5 do
				Stack.arm(st, i * 10, 4, false)
				Stack.drop(st, Stack.firstCenterTime(st), 0.2, 1)
			end
			local v = Stack.value(st, 5, Cfg.TowerK, false)
			T.expect(v).toBeNear(Stack.valueOf(5, Stack.totalFluff(st), 5, Cfg.TowerK))
			T.expect(Stack.value(st, 5, Cfg.TowerK, true)).toBeNear(v * Cfg.CravingMult)
		end)
		T.it("cravings stay in their band, are deterministic and change each period", function()
			local changed = false
			for yeti = 1, 3 do
				local band = Cfg.CravingBands[yeti]
				local prevLo = nil
				for p = 0, 40 do
					local t = (14166667 + p) * Cfg.CravingPeriod + 1
					local lo, hi = Stack.craving(2, yeti, t)
					T.expect(lo >= band[1]).toBeTruthy()
					T.expect(hi <= band[2]).toBeTruthy()
					T.expect(hi - lo).toBe(Cfg.CravingWidth)
					local lo2 = Stack.craving(2, yeti, t + Cfg.CravingPeriod * 0.9)
					T.expect(lo2).toBe(lo)
					if prevLo and prevLo ~= lo then
						changed = true
					end
					prevLo = lo
				end
			end
			T.expect(changed).toBeTruthy()
			T.expect(Stack.cravingEndsAt(Cfg.CravingPeriod * 2.5)).toBe(Cfg.CravingPeriod * 3)
			T.expect(Stack.inCraving(10, 8, 12)).toBeTruthy()
			T.expect(Stack.inCraving(13, 8, 12)).toBeFalsy()
		end)
	end)

	T.describe("Economy", function()
		T.it("multipliers stack from every source", function()
			local p = Schema.default()
			local ctx = Economy.emptyContext()
			T.expect(Economy.multipliers(p, ctx).total).toBeNear(1)
			p.upgrades.Batter = 5
			p.rebirths = 2
			p.perks.GoldenSyrup = 2
			p.boosts.Maple2x = 30
			ctx.passes.DoubleMaple = true
			ctx.friends = 10
			ctx.snowDay = true
			local m = Economy.multipliers(p, ctx)
			T.expect(m.total).toBeNear(2 * 1.5 * 1.5 * 1.5 * 2 * 2 * 2)
		end)
		T.it("perfect window, pan, tray and tower bonus follow upgrades, Nibblers and passes", function()
			local p = Schema.default()
			local ctx = Economy.emptyContext()
			T.expect(Economy.perfectWindow(p, ctx)).toBeNear(UpgradeMath.effect("Steady", 0))
			p.nibblers["1"] = { id = "SyrupFox", shiny = false, t = 0 }
			p.equipped = { "1" }
			T.expect(Economy.perfectWindow(p, ctx)).toBeNear(UpgradeMath.effect("Steady", 0) + 0.04)
			ctx.passes.SteadySpatula = true
			T.expect(Economy.perfectWindow(p, ctx)).toBeNear((UpgradeMath.effect("Steady", 0) + 0.04) * 1.5)
			p.upgrades.Tray = 3
			T.expect(Economy.trayMax(p)).toBe(18)
			p.upgrades.Pan = 5
			T.expect(Economy.panRadius(p)).toBeNear(1.6 + 0.2)
			p.perks.TowerSense = 2
			T.expect(Economy.towerK(p)).toBeNear(Cfg.TowerK * 1.1)
			T.expect(Economy.slideFactor({ passes = {}, friends = 0, snowDay = true })).toBeLessThan(1)
		end)
		T.it("income estimate grows with the best zone and never counts boosts", function()
			local p = Schema.default()
			local ctx = Economy.emptyContext()
			local base = Economy.estimatedIncome(p, ctx)
			T.expect(base).toBeGreaterThan(0)
			p.boosts.Maple2x = 100
			T.expect(Economy.estimatedIncome(p, ctx)).toBeNear(base)
			p.zones.PineconeVillage = true
			T.expect(Economy.estimatedIncome(p, ctx)).toBeNear(base * 5)
			T.expect(Economy.scaledMaple(p, ctx, 0, 123)).toBe(123)
		end)
		T.it("slots grow with Feasts, perks and the pass", function()
			local p = Schema.default()
			T.expect(Economy.equipSlots(p, Economy.emptyContext())).toBe(3)
			p.rebirths = 3
			p.perks.ExtraPocket = 1
			T.expect(Economy.equipSlots(p, { passes = { ExtraPockets = true }, friends = 0, snowDay = false }))
				.toBe(3 + 2 + 1 + 3)
		end)
	end)

	T.describe("Progression", function()
		T.it("upgrades cost Maple and cap at max level", function()
			local p = Schema.default()
			local ok, why = Progression.buyUpgrade(p, "Batter")
			T.expect(ok).toBeFalsy()
			T.expect(why).toBe("Not enough Maple")
			p.maple = 1e9
			T.expect((Progression.buyUpgrade(p, "Batter"))).toBeTruthy()
			T.expect(p.upgrades.Batter).toBe(1)
			p.upgrades.Pan = 30
			T.expect((Progression.buyUpgrade(p, "Pan"))).toBeFalsy()
			T.expect((Progression.buyUpgrade(p, "Nope"))).toBeFalsy()
		end)
		T.it("zones unlock in order", function()
			local p = Schema.default()
			p.maple = 1e12
			T.expect((Progression.unlockZone(p, "FrostyFalls"))).toBeFalsy()
			T.expect((Progression.unlockZone(p, "PineconeVillage"))).toBeTruthy()
			T.expect((Progression.unlockZone(p, "FrostyFalls"))).toBeTruthy()
			T.expect((Progression.unlockZone(p, "FrostyFalls"))).toBeFalsy()
			T.expect(p.maple).toBe(1e12 - Zones.ById.PineconeVillage.unlockCost - Zones.ById.FrostyFalls.unlockCost)
		end)
		T.it("a Yeti Feast resets Maple and upgrades, keeps zones, gives Spatulas", function()
			local p = Schema.default()
			p.maple = Rebirth.BaseCost * 1000
			p.upgrades.Batter = 10
			T.expect((Progression.rebirth(p))).toBeFalsy()
			p.zones.PineconeVillage = true
			p.zones.FrostyFalls = true
			p.zones.CocoaCliffs = true
			local ok, _, spatulas = Progression.rebirth(p)
			T.expect(ok).toBeTruthy()
			T.expect(spatulas).toBe(Rebirth.SpatulasBase + 3)
			T.expect(p.maple).toBe(0)
			T.expect(p.upgrades.Batter).toBe(0)
			T.expect(p.zones.CocoaCliffs).toBe(true)
			T.expect(p.spatulas).toBe(spatulas)
			T.expect(Economy.rebirthCost(1)).toBeNear(Rebirth.BaseCost * Rebirth.CostGrowth)
		end)
		T.it("perks cost Spatulas", function()
			local p = Schema.default()
			T.expect((Progression.buyPerk(p, "GoldenSyrup"))).toBeFalsy()
			p.spatulas = 5
			T.expect((Progression.buyPerk(p, "GoldenSyrup"))).toBeTruthy()
			T.expect(p.spatulas).toBe(3)
			T.expect(Progression.perkCost("GoldenSyrup", 1)).toBe(3)
		end)
	end)
end
