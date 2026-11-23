-- Guards against config typos: every reference must resolve, odds must sum to 1, numbers must be
-- sane, and the mountain geometry must not overlap.
local L = require("./Loader")
return function(T)
	local Zones = L.get("Shared/Config/Zones")
	local Eggs = L.get("Shared/Config/Eggs")
	local Nibblers = L.get("Shared/Config/Nibblers")
	local Rarities = L.get("Shared/Config/Rarities")
	local Upgrades = L.get("Shared/Config/Upgrades")
	local Perks = L.get("Shared/Config/Perks")
	local Monet = L.get("Shared/Config/Monetization")
	local Rewards = L.get("Shared/Config/Rewards")
	local Rebirth = L.get("Shared/Config/Rebirth")
	local Order = L.get("Shared/Config/Order")
	local StackCfg = L.get("Shared/Config/Stack")
	local Assets = L.get("Shared/Config/Assets")
	local Boards = L.get("Shared/Config/Leaderboards")
	local Game = L.get("Shared/Config/Game")
	local ZoneGeo = L.get("Shared/Logic/ZoneGeo")
	local UpgradeMath = L.get("Shared/Logic/UpgradeMath")

	local function dist(ax, az, bx, bz)
		return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
	end

	T.describe("config integrity", function()
		T.it("zones are ordered, climb the mountain, grow in cost and value, and reference real eggs", function()
			for i, z in Zones.List do
				T.expect(z.order).toBe(i)
				T.expect(Eggs.ById[z.egg] ~= nil).toBeTruthy()
				T.expect(Eggs.ById[z.egg].zone).toBe(z.id)
				if i > 1 then
					local prev = Zones.List[i - 1]
					T.expect(z.unlockCost).toBeGreaterThan(prev.unlockCost)
					T.expect(z.value).toBeGreaterThan(prev.value)
					T.expect(z.center.y).toBeGreaterThan(prev.center.y)
				end
			end
			T.expect(Zones.List[1].unlockCost).toBe(0)
		end)
		T.it("zones do not overlap each other or Base Camp", function()
			for i, a in Zones.List do
				for j, b in Zones.List do
					if i < j then
						local d = dist(a.center.x, a.center.z, b.center.x, b.center.z)
						T.expect(d - a.radius - b.radius).toBeGreaterThan(20)
					end
				end
				local d = dist(a.center.x, a.center.z, 0, 0)
				T.expect(d - a.radius - Zones.Hub.radius).toBeGreaterThan(20)
			end
		end)
		T.it("ramps don't cross another zone and are walkable", function()
			for _, a in Zones.List do
				local r = ZoneGeo.ramp(a.id)
				-- Slope under ~25 degrees so characters walk up without trouble.
				T.expect(math.abs(r.by - r.ay) / r.length).toBeLessThan(0.45)
				for _, b in Zones.List do
					if b.id ~= a.id then
						local dx, dz = r.bx - r.ax, r.bz - r.az
						local len2 = dx * dx + dz * dz
						local t = math.clamp(((b.center.x - r.ax) * dx + (b.center.z - r.az) * dz) / len2, 0, 1)
						local px, pz = r.ax + dx * t, r.az + dz * t
						T.expect(dist(px, pz, b.center.x, b.center.z)).toBeGreaterThan(b.radius + Zones.RampWidth)
					end
				end
			end
		end)
		T.it("Yetis fit on their zone, clear of each other, the plaza, the egg and the entrance", function()
			for _, z in Zones.List do
				local lm = ZoneGeo.landmarks(z.id)
				local yetis = ZoneGeo.yetis(z.id)
				T.expect(#yetis).toBe(Zones.YetisPerZone)
				T.expect(#StackCfg.CravingBands).toBe(Zones.YetisPerZone)
				for i, a in yetis do
					local fromCenter = dist(a.x, a.z, z.center.x, z.center.z)
					T.expect(fromCenter + 14).toBeLessThan(z.radius)
					T.expect(fromCenter).toBeGreaterThan(Zones.PlazaRadius + StackCfg.ServeDistance)
					T.expect(dist(a.x, a.z, lm.egg.x, lm.egg.z)).toBeGreaterThan(24)
					T.expect(dist(a.x, a.z, lm.entrance.x, lm.entrance.z)).toBeGreaterThan(24)
					for j, b in yetis do
						if i < j then
							-- Serving areas must not overlap, so "nearest Yeti" is never ambiguous.
							T.expect(dist(a.x, a.z, b.x, b.z)).toBeGreaterThan(StackCfg.ServeDistance * 2)
						end
					end
				end
			end
		end)
		T.it("cravings are reachable: every band fits inside the biggest tray", function()
			local maxTray = UpgradeMath.effect("Tray", Upgrades.ById.Tray.maxLevel)
			for _, band in StackCfg.CravingBands do
				T.expect(band[2]).toBeLessThan(maxTray + 1)
				T.expect(band[2] - band[1]).toBeGreaterThan(StackCfg.CravingWidth - 1)
			end
			-- The low band is reachable with a brand-new tray.
			T.expect(StackCfg.CravingBands[1][2]).toBeLessThan(UpgradeMath.effect("Tray", 0) + 1)
		end)
		T.it("egg odds sum to 1 and every rarity maps to a Nibbler of that rarity from that egg", function()
			for _, e in Eggs.List do
				local sum = 0
				for _, r in Rarities.List do
					sum += e.odds[r.id] or 0
					local d = Nibblers.ById[e.nibblers[r.id]]
					T.expect(d ~= nil).toBeTruthy()
					T.expect(d.rarity).toBe(r.id)
					T.expect(d.egg).toBe(e.id)
				end
				T.expect(sum).toBeNear(1, 1e-9)
				T.expect(Zones.ById[e.zone] ~= nil).toBeTruthy()
			end
		end)
		T.it("Nibbler ids are unique and have looks", function()
			local seen = {}
			for _, d in Nibblers.List do
				T.expect(seen[d.id]).toBe(nil)
				seen[d.id] = true
				T.expect(type(d.look.body)).toBe("string")
				T.expect(#d.look.features).toBeGreaterThan(0)
				T.expect(d.power).toBeGreaterThan(0)
				T.expect(d.steady >= 0).toBeTruthy()
			end
			T.expect(#Nibblers.List).toBe(30)
		end)
		T.it("upgrades and perks have sane curves", function()
			for _, u in Upgrades.List do
				T.expect(u.growth).toBeGreaterThan(1)
				T.expect(u.baseCost).toBeGreaterThan(0)
				T.expect(u.maxLevel).toBeGreaterThan(0)
				T.expect(type(u.glyph)).toBe("string")
			end
			for _, p in Perks.List do
				T.expect(p.baseCost).toBeGreaterThan(0)
				T.expect(p.maxLevel).toBeGreaterThan(0)
			end
			-- Even a maxed perfect window stays smaller than the smallest pan (perfects stay a skill).
			local maxWindow = UpgradeMath.effect("Steady", Upgrades.ById.Steady.maxLevel) * Monet.SteadySpatulaMult
			T.expect(maxWindow).toBeLessThan(UpgradeMath.effect("Pan", 0) * 0.5)
		end)
		T.it("every product and pass is in its display order and has a grant", function()
			local n = 0
			for key in Monet.Passes do
				n += 1
				T.expect(table.find(Monet.PassOrder, key) ~= nil).toBeTruthy()
			end
			T.expect(n).toBe(#Monet.PassOrder)
			n = 0
			for key, p in Monet.Products do
				n += 1
				T.expect(table.find(Monet.ProductOrder, key) ~= nil).toBeTruthy()
				T.expect(type(p.grant.kind)).toBe("string")
				T.expect(type(p.id)).toBe("number")
			end
			T.expect(n).toBe(#Monet.ProductOrder)
		end)
		T.it("reward tables are well formed", function()
			T.expect(#Rewards.Daily).toBe(7)
			local last = 0
			for _, p in Rewards.Playtime do
				T.expect(p.unlockAt).toBeGreaterThan(last)
				last = p.unlockAt
			end
			for code, def in Rewards.Codes do
				T.expect(code).toBe(string.upper(code))
				T.expect(#def.rewards).toBeGreaterThan(0)
			end
		end)
		T.it("Yeti Feast references a real zone", function()
			T.expect(Zones.ById[Rebirth.RequiredZone] ~= nil).toBeTruthy()
		end)
		T.it("a solo player can fill the Great Yeti's Order in time", function()
			-- A solo chef stacks ~12 pancakes per ~26 s cycle.
			local perSecond = 12 / 26
			T.expect(Order.BaseLayers / perSecond).toBeLessThan(Order.DurationSeconds * 0.85)
			T.expect(Order.DurationSeconds).toBeLessThan(Order.IntervalSeconds)
			T.expect(Order.ServeReach).toBeLessThan(Zones.List[1].radius * Zones.YetiRing - StackCfg.ServeDistance)
		end)
		T.it("the Mystery Egg is close enough to its prompt to hatch", function()
			T.expect(Game.EggDistance).toBeGreaterThan(18)
		end)
		T.it("asset entries are strings and leaderboards have unique stores", function()
			for _, group in Assets do
				for _, v in group do
					T.expect(type(v)).toBe("string")
				end
			end
			local stores = {}
			for _, b in Boards.Boards do
				T.expect(stores[b.store]).toBe(nil)
				stores[b.store] = true
			end
		end)
	end)
end
