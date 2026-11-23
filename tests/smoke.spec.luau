-- End-to-end smoke test: builds the place with Rojo, boots the real server and client scripts in a
-- headless Roblox-like environment (tests/RobloxEnv), then plays: joins, flips pancakes through the
-- client (with local prediction) at well-timed and badly-timed moments, walks to a Yeti and serves,
-- buys things, sends malicious remote calls, hatches a Mystery Egg, fills the Great Yeti's Order
-- together and opens every UI panel.
local process = require("@lune/process")
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

return function(T)
	local built = pcall(process.exec, "rojo", { "build", "-o", "build/PancakePeak.rbxl" })
	if not built or not fs.isFile("build/PancakePeak.rbxl") then
		print("  (smoke test skipped: rojo not available)")
		return
	end
	local RobloxEnv = require("./RobloxEnv")
	local L = require("./Loader")
	local ZoneGeo = L.get("Shared/Logic/ZoneGeo")
	local Stack = L.get("Shared/Logic/Stack")
	local Zones = L.get("Shared/Config/Zones")
	local env = RobloxEnv.new("build/PancakePeak.rbxl")
	local place = env.place
	local Vector3, CFrame = roblox.Vector3, roblox.CFrame

	local function noErrors(label)
		if #RobloxEnv.errors > 0 then
			local msg = table.concat(RobloxEnv.errors, "\n\n")
			table.clear(RobloxEnv.errors)
			error(label .. ":\n" .. msg)
		end
	end

	local server = place:GetService("ServerScriptService").Server
	local client = place:GetService("StarterPlayer").StarterPlayerScripts.Client
	local S = {}
	local Cl = {}
	local player = env.localPlayer
	-- A client -> server remote call, as the engine would deliver it.
	local function fire(name, ...)
		place:GetService("ReplicatedStorage").Remotes[name].OnServerEvent:Fire(player, ...)
	end
	local function now()
		return place:GetService("Workspace"):GetServerTimeNow()
	end

	T.describe("smoke: server boot", function()
		T.it("runs Main and builds the mountain", function()
			env.runScript(server.Main)
			RobloxEnv.step(0.5, 0.1)
			noErrors("server boot")
			local map = place:GetService("Workspace"):FindFirstChild("Map")
			T.expect(map ~= nil).toBeTruthy()
			T.expect(#map:GetDescendants()).toBeGreaterThan(800)
			T.expect(#map.Gates:GetChildren()).toBe(4)
			T.expect(place:GetService("ReplicatedStorage"):FindFirstChild("Remotes") ~= nil).toBeTruthy()
			S.Data = env.require(server.Services.DataService)
			S.Stack = env.require(server.Services.StackService)
			S.World = env.require(server.Services.WorldService)
			S.Order = env.require(server.Services.OrderService)
			S.Zone = env.require(server.Services.ZoneService)
			for _, z in Zones.List do
				T.expect(S.World:Egg(z.egg) ~= nil).toBeTruthy()
				-- Every zone has its three Yeti tables.
				local folder = map:FindFirstChild(z.id)
				T.expect(folder ~= nil).toBeTruthy()
				T.expect(#folder.Yetis:GetChildren()).toBe(3)
			end
			for _, title in { "Most Maple", "Yeti Feasts", "Tallest Stack" } do
				T.expect(S.World:Board(title) ~= nil).toBeTruthy()
			end
		end)
	end)

	local character, root
	T.describe("smoke: join", function()
		T.it("loads a profile, boots the client and gets a tray", function()
			character = roblox.Instance.new("Model")
			character.Name = "Tester"
			root = roblox.Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Size = Vector3.new(2, 2, 1)
			root.CFrame = CFrame.new(0, 7, -26)
			root.Parent = character
			local hum = roblox.Instance.new("Humanoid")
			hum.Health = 100
			hum.MaxHealth = 100
			hum.HipHeight = 2
			hum.WalkSpeed = 16
			hum.Parent = character
			character.PrimaryPart = root
			character.Parent = place:GetService("Workspace")
			player.Character = character
			table.insert(RobloxEnv.players, player)
			env.services.Players.PlayerAdded:Fire(player)
			RobloxEnv.step(0.5, 0.1)
			noErrors("player load")
			T.expect(S.Data:Get(player) ~= nil).toBeTruthy()
			T.expect(S.Stack:Get(player) ~= nil).toBeTruthy()
			env.runScript(client.Main)
			RobloxEnv.step(1, 1 / 30)
			noErrors("client boot")
			Cl.State = env.require(client.Controllers.State)
			Cl.Stack = env.require(client.Controllers.StackRenderer)
			Cl.Input = env.require(client.Controllers.StackInput)
			Cl.WorldFX = env.require(client.Controllers.WorldFX)
			T.expect(Cl.State.loaded).toBeTruthy()
			T.expect(Cl.State.data.maple).toBe(0)
			-- The client mirrors the server's tray (from the Reset broadcast or the snapshot).
			T.expect(Cl.Stack:MyState() ~= nil).toBeTruthy()
			T.expect(Cl.Stack:MyCount()).toBe(0)
		end)
	end)

	-- Walk the root in small honest steps (≤ 1.6 studs per 0.1 s sample) towards a point.
	local function walkTo(x, z, y)
		local p = root.CFrame.Position
		local ty = y or p.Y
		local dx, dz, dy = x - p.X, z - p.Z, ty - p.Y
		local dist = math.sqrt(dx * dx + dz * dz)
		local n = math.max(1, math.ceil(dist / 1.6))
		for i = 1, n do
			local t = i / n
			local px, pz, py = p.X + dx * t, p.Z + dz * t, p.Y + dy * t
			root.CFrame = CFrame.lookAt(Vector3.new(px, py, pz), Vector3.new(px + dx, py, pz + dz))
			RobloxEnv.step(0.1, 0.1)
		end
	end

	-- The next server time (>= now) when the sliding pancake is `frac` of its swing past the
	-- center on the + side (frac 0 = dead center). The sweep repeats every 4A / speed.
	local function nextAt(st, frac: number): number
		local A = Stack.amplitude(st)
		local period = 4 * A / st.speed
		local t = st.start + (A + frac * A) / st.speed
		local n = now() + 0.02
		if t < n then
			t += math.ceil((n - t) / period) * period
		end
		return t
	end

	-- Wait until the sliding pancake is right over the stack and flip.
	local function flipPerfect(): boolean
		local st = Cl.Stack:MyState()
		local t = nextAt(st, 0)
		local wait = t - now()
		if wait > 0 then
			RobloxEnv.step(wait, wait)
		end
		local ok = Cl.Input:Flip()
		RobloxEnv.step(0.25, 0.05)
		return ok
	end
	-- Flip when the pancake is a given fraction of its swing away from the center.
	local function flipOffset(frac: number): boolean
		local st = Cl.Stack:MyState()
		local t = nextAt(st, frac)
		local wait = t - now()
		if wait > 0 then
			RobloxEnv.step(wait, wait)
		end
		local ok = Cl.Input:Flip()
		RobloxEnv.step(0.25, 0.05)
		return ok
	end

	T.describe("smoke: flip & stack", function()
		T.it("perfect drops keep full size, are predicted at once and confirmed by the server", function()
			local profile = S.Data:Get(player)
			local base = Cl.Stack:MyState().baseR
			for _ = 1, 3 do
				T.expect(flipPerfect()).toBeTruthy()
			end
			noErrors("perfect flips")
			local st = S.Stack:Get(player)
			T.expect(#st.layers).toBe(3)
			T.expect(st.combo).toBe(3)
			T.expect(st.topR).toBeNear(base, 1e-6)
			T.expect(profile.stats.perfects).toBe(3)
			T.expect(profile.tutorial.step).toBeGreaterThan(1)
			-- Client view matches the server after the confirmations.
			T.expect(Cl.Stack:MyCount()).toBe(3)
			T.expect(Cl.Stack:MyState().topR).toBeNear(base, 1e-6)
		end)

		T.it("off-center drops slice the overhang (lens rule) and a tiny pancake topples", function()
			local st = S.Stack:Get(player)
			local before = st.topR
			T.expect(flipOffset(0.4)).toBeTruthy()
			noErrors("slice")
			T.expect(#st.layers).toBe(4)
			T.expect(st.topR).toBeLessThan(before)
			T.expect(st.combo).toBe(0)
			T.expect(Cl.Stack:MyState().topR).toBeNear(st.topR, 1e-6)
			-- Keep dropping at the edge until it topples.
			local profile = S.Data:Get(player)
			for _ = 1, 12 do
				flipOffset(0.97)
				if profile.stats.topples > 0 then
					break
				end
			end
			RobloxEnv.step(1.2, 0.1)
			noErrors("topple")
			T.expect(profile.stats.topples).toBe(1)
			-- Crumbs refund and a fresh empty tray on both sides.
			T.expect(profile.maple).toBeGreaterThan(0)
			T.expect(#S.Stack:Get(player).layers).toBe(0)
			T.expect(Cl.Stack:MyCount()).toBe(0)
		end)

		T.it("drops faster than the cooldown or with forged timestamps gain nothing", function()
			local st = S.Stack:Get(player)
			RobloxEnv.step(1, 0.1)
			local n = #st.layers
			-- Two in the same instant (at dead center, so the first one surely lands): the second
			-- is rejected by the drop cooldown.
			local wait = nextAt(Cl.Stack:MyState(), 0) - now()
			RobloxEnv.step(wait, wait)
			fire("Drop", now())
			fire("Drop", now())
			RobloxEnv.step(0.05, 0.05)
			T.expect(#S.Stack:Get(player).layers).toBe(n + 1)
			-- A timestamp from the far past is clamped to the last MaxLag seconds (it can't pick a
			-- perfect moment from history), and junk types are ignored.
			RobloxEnv.step(0.5, 0.1)
			fire("Drop", 0)
			RobloxEnv.step(0.3, 0.1)
			fire("Drop", 0 / 0)
			fire("Drop", "soon")
			fire("Drop", math.huge)
			RobloxEnv.step(0.3, 0.1)
			noErrors("forged drops")
			T.expect(#S.Stack:Get(player).layers).toBeLessThan(n + 3)
		end)
	end)

	T.describe("smoke: serve", function()
		T.it("serving away from a Yeti does nothing", function()
			local profile = S.Data:Get(player)
			local serves = profile.stats.serves
			fire("Serve")
			RobloxEnv.step(1, 0.1)
			T.expect(profile.stats.serves).toBe(serves)
		end)

		T.it("walking to a Yeti in Maple Meadow and pressing SERVE pays Maple", function()
			local profile = S.Data:Get(player)
			-- Fresh tray with a few perfects.
			RobloxEnv.step(1, 0.1)
			for _ = 1, 4 do
				flipPerfect()
			end
			local n = #S.Stack:Get(player).layers
			T.expect(n).toBeGreaterThan(3)
			local zone = Zones.ById.MapleMeadow
			local lm = ZoneGeo.landmarks("MapleMeadow")
			walkTo(lm.entrance.x, lm.entrance.z, zone.center.y + 3)
			local y = ZoneGeo.yetis("MapleMeadow")[1]
			-- Stand a few studs in front of the table, toward the zone center.
			local fx, fz = y.faceX, y.faceZ
			walkTo(y.x + fx * 8, y.z + fz * 8, zone.center.y + 3)
			RobloxEnv.step(3.2, 0.25) -- let the movement check settle
			noErrors("walk")
			T.expect(Cl.WorldFX:CurrentZone()).toBe("MapleMeadow")
			T.expect(Cl.Input:Target() ~= nil).toBeTruthy()
			local before = profile.maple
			T.expect(Cl.Input:Serve()).toBeTruthy()
			RobloxEnv.step(1.5, 0.1)
			noErrors("serve")
			T.expect(profile.stats.serves).toBe(1)
			T.expect(profile.maple).toBeGreaterThan(before)
			T.expect(profile.stats.tallest).toBe(n)
			T.expect(Cl.State.data.maple).toBe(profile.maple)
			T.expect(Cl.Stack:MyCount()).toBe(0)
		end)

		T.it("serving the craving height pays double", function()
			local profile = S.Data:Get(player)
			local zone = Zones.ById.MapleMeadow
			local y = ZoneGeo.yetis("MapleMeadow")[1]
			local lo = Stack.craving(zone.order, y.index, now())
			-- Build exactly `lo` perfect layers (the tray holds 15+ at level 0, the band starts at 5).
			RobloxEnv.step(0.5, 0.1)
			for _ = 1, lo do
				flipPerfect()
			end
			-- The craving may have rolled over while stacking; check against the live window.
			local lo2, hi2 = Stack.craving(zone.order, y.index, now())
			local n = #S.Stack:Get(player).layers
			local cravings = profile.stats.cravings
			Cl.Input:Serve()
			RobloxEnv.step(1, 0.1)
			noErrors("craving serve")
			T.expect(profile.stats.serves).toBe(2)
			if n >= lo2 and n <= hi2 then
				T.expect(profile.stats.cravings).toBe(cravings + 1)
			end
		end)
	end)

	T.describe("smoke: progression", function()
		T.it("purchases go through remotes and validation", function()
			local profile = S.Data:Get(player)
			profile.maple = 1e7
			fire("BuyUpgrade", "Batter")
			fire("BuyUpgrade", "Pan")
			fire("BuyZone", "PineconeVillage")
			RobloxEnv.step(0.5, 0.1)
			T.expect(profile.upgrades.Batter).toBe(1)
			T.expect(profile.upgrades.Pan).toBe(1)
			T.expect(profile.zones.PineconeVillage).toBe(true)
			-- Buying a zone takes you there.
			T.expect(S.Zone:PlayerZone(player)).toBe("PineconeVillage")
			fire("RedeemCode", "flipflip")
			fire("ClaimDaily")
			fire("SetSetting", "performance", true)
			RobloxEnv.step(3, 0.1)
			T.expect(profile.codes.FLIPFLIP).toBe(true)
			T.expect(profile.daily.streak).toBe(1)
			T.expect(profile.settings.performance).toBe(true)
			-- A bigger pan reaches the next empty tray.
			T.expect(S.Stack:Get(player).baseR).toBeGreaterThan(1.6)
			fire("Teleport", "BaseCamp")
			RobloxEnv.step(3.5, 0.1)
			T.expect(S.Zone:PlayerZone(player)).toBe(nil)
			noErrors("purchases")
		end)

		T.it("walking into a locked zone bounces you back to Base Camp", function()
			local frosty = ZoneGeo.landmarks("FrostyFalls")
			root.CFrame = CFrame.new(frosty.spawn.x, Zones.ById.FrostyFalls.center.y + 3, frosty.spawn.z)
			RobloxEnv.step(0.6, 0.1)
			local p = root.CFrame.Position
			T.expect(ZoneGeo.zoneAt(p.X, p.Y, p.Z)).toBe(nil)
			RobloxEnv.step(3, 0.25)
		end)

		T.it("malicious remote calls change nothing and raise no errors", function()
			local profile = S.Data:Get(player)
			root.CFrame = CFrame.new(0, 7, -26)
			RobloxEnv.step(3, 0.25)
			local before = profile.maple
			local bad = { 0 / 0, math.huge, -1, {}, "x", string.rep("A", 5000), nil, true }
			for _, v in bad do
				for _, name in
					{
						"Serve",
						"BuyUpgrade",
						"BuyZone",
						"BuyPerk",
						"HatchEgg",
						"Equip",
						"Unequip",
						"Release",
						"ClaimPlaytime",
						"RedeemCode",
						"SetSetting",
						"Teleport",
						"StackSnapshot",
					}
				do
					fire(name, v, v)
				end
				RobloxEnv.step(1, 0.5)
			end
			fire("SetSetting", "maple", true)
			fire("HatchEgg", "MapleEgg", 3) -- no Triple Hatch pass
			fire("HatchEgg", "MapleEgg", 1) -- too far from the egg
			fire("Rebirth") -- Cocoa Cliffs not owned
			RobloxEnv.step(1, 0.5)
			T.expect(profile.maple).toBe(before)
			T.expect(profile.settings.maple).toBe(nil)
			T.expect(profile.rebirths).toBe(0)
			T.expect(profile.maple == profile.maple).toBeTruthy()
			noErrors("malicious calls")
		end)

		T.it("hatching a Mystery Egg works next to it", function()
			local profile = S.Data:Get(player)
			local egg = S.World:Egg("MapleEgg")
			T.expect(egg ~= nil).toBeTruthy()
			local zone = Zones.ById.MapleMeadow
			local lm = ZoneGeo.landmarks("MapleMeadow")
			walkTo(lm.entrance.x, lm.entrance.z, zone.center.y + 3)
			walkTo(egg.X + 12, egg.Z, zone.center.y + 3)
			RobloxEnv.step(3, 0.25)
			local before = profile.stats.hatches
			fire("HatchEgg", "MapleEgg", 1)
			RobloxEnv.step(1.5, 0.1)
			T.expect(profile.stats.hatches).toBe(before + 1)
			T.expect(#profile.equipped).toBeGreaterThan(0)
			T.expect(type(player:GetAttribute("Nibblers"))).toBe("string")
			T.expect(profile.tutorial.done).toBeTruthy()
			noErrors("egg")
		end)
	end)

	T.describe("smoke: the Great Yeti's Order", function()
		T.it("stomps into your zone, gets fed and starts a Snow Day", function()
			S.Order:Trigger(nil)
			RobloxEnv.step(0.5, 0.1)
			local o = S.Order:Current()
			T.expect(o ~= nil).toBeTruthy()
			T.expect(o.zone).toBe("MapleMeadow")
			T.expect(Cl.State.order.active).toBeTruthy()
			local zone = Zones.ById.MapleMeadow
			walkTo(o.x + 6, o.z, zone.center.y + 3)
			RobloxEnv.step(3.2, 0.25)
			local profile = S.Data:Get(player)
			local before = profile.maple
			for _ = 1, 40 do
				if S.Order:Current() == nil then
					break
				end
				for _ = 1, 12 do
					flipPerfect()
				end
				Cl.Input:Serve()
				RobloxEnv.step(1, 0.1)
			end
			noErrors("order")
			T.expect(S.Order:Current()).toBe(nil)
			T.expect(S.Order:IsSnowDay()).toBeTruthy()
			T.expect(profile.stats.orders).toBe(1)
			T.expect(profile.maple).toBeGreaterThan(before)
			T.expect(Cl.State:SnowDay()).toBeTruthy()
		end)
	end)

	T.describe("smoke: UI", function()
		T.it("every panel opens, refreshes and closes", function()
			local UIRoot = env.require(client.UI.UIRoot)
			for _, name in
				{
					"Upgrades",
					"Nibblers",
					"Egg",
					"Travel",
					"Feast",
					"Store",
					"Daily",
					"Gifts",
					"Codes",
					"Settings",
				}
			do
				UIRoot:Open(name)
				RobloxEnv.step(0.2, 1 / 30)
				noErrors("open " .. name)
				UIRoot:Close()
			end
			UIRoot:Open("Egg", { eggId = "AuroraEgg" })
			UIRoot:Open("Travel", { focus = "CocoaCliffs" })
			RobloxEnv.step(0.2, 1 / 30)
			noErrors("panel args")
		end)
		T.it("the egg reveal plays", function()
			local Reveal = env.require(client.Controllers.EggReveal)
			RobloxEnv.spawn(function()
				Reveal:Show("MapleEgg", {
					{ uid = "1", id = "Pip", shiny = true },
					{ uid = "2", id = "Muffin", shiny = false },
				}, false)
			end)
			RobloxEnv.step(6, 1 / 30)
			noErrors("reveal")
		end)
	end)

	T.describe("smoke: leave", function()
		T.it("leaving the game saves and cleans up", function()
			env.services.Players.PlayerRemoving:Fire(player)
			RobloxEnv.step(1, 0.1)
			noErrors("leave")
			T.expect(S.Data:Get(player)).toBe(nil)
			T.expect(S.Stack:Get(player)).toBe(nil)
		end)
		T.it("logs no unexpected warnings", function()
			local unexpected = {}
			for _, w in RobloxEnv.warnings or {} do
				if not string.find(w, "offline", 1, true) and not string.find(w, "DataStore", 1, true) then
					table.insert(unexpected, w)
				end
			end
			if #unexpected > 0 then
				error(table.concat(unexpected, "\n"))
			end
		end)
	end)
end
