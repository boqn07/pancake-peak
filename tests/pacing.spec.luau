-- Fails if a balance change pushes the modelled pacing outside the GDD targets (docs/GDD.md §6).
-- Egg luck moves a single run a lot, so targets are checked on the median of several seeds.
local Sim = require("./PacingSim")

local SEEDS = 8
local MINUTES = 180

local function median(list: { number }): number
	table.sort(list)
	local n = #list
	if n % 2 == 1 then
		return list[(n + 1) // 2]
	end
	return (list[n // 2] + list[n // 2 + 1]) / 2
end

local function medians(passes: { [string]: boolean }?)
	local acc = { firstServe = {}, firstUpgrade = {}, firstEgg = {}, pine = {}, frosty = {}, cocoa = {}, feast = {} }
	local each = {}
	for seed = 1, SEEDS do
		local m = Sim.run(MINUTES * 60, { seed = seed, passes = passes })
		table.insert(acc.firstServe, m.firstServe or math.huge)
		table.insert(acc.firstUpgrade, m.firstUpgrade or math.huge)
		table.insert(acc.firstEgg, m.firstEgg or math.huge)
		table.insert(acc.pine, (m.zones.PineconeVillage or math.huge) / 60)
		table.insert(acc.frosty, (m.zones.FrostyFalls or math.huge) / 60)
		table.insert(acc.cocoa, (m.zones.CocoaCliffs or math.huge) / 60)
		local f = (m.rebirths[1] or math.huge) / 60
		table.insert(acc.feast, f)
		table.insert(each, f)
	end
	local out = {}
	for k, list in acc do
		out[k] = median(list)
	end
	return out, each
end

return function(T)
	local m, each = medians(nil)
	T.describe("pacing (modelled average player, median of 8 seeds)", function()
		T.it("first serve within 30 s, first upgrade within a minute", function()
			T.expect(m.firstServe).toBeLessThan(30)
			T.expect(m.firstUpgrade).toBeLessThan(60)
		end)
		T.it("first egg within ~2 minutes", function()
			T.expect(m.firstEgg).toBeLessThan(130)
		end)
		T.it("Pinecone Village in 8-17 minutes", function()
			T.expect(m.pine).toBeBetween(8, 17)
		end)
		T.it("Frosty Falls in 15-40 minutes", function()
			T.expect(m.frosty).toBeBetween(15, 40)
		end)
		T.it("Cocoa Cliffs in 35-90 minutes", function()
			T.expect(m.cocoa).toBeBetween(35, 90)
		end)
		T.it("first Yeti Feast in 60-125 minutes", function()
			T.expect(m.feast).toBeBetween(60, 125)
		end)
		T.it("no seed is wildly off", function()
			for _, f in each do
				T.expect(f).toBeBetween(40, 160)
			end
		end)
		T.it("2x Maple pass speeds things up without skipping the game", function()
			local paid = medians({ DoubleMaple = true })
			T.expect(paid.feast).toBeBetween(25, m.feast - 10)
		end)
		T.it("Auto Serve and Steady Spatula help but don't break pacing", function()
			local paid = medians({ AutoServe = true, SteadySpatula = true })
			T.expect(paid.feast).toBeBetween(25, m.feast)
		end)
	end)
end
