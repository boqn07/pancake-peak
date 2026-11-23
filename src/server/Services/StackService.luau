--!strict
-- Flip & Stack (the hook), server side. The server owns every player's stack. The client only says
-- "drop at server time t" and "serve". The server clamps t to the last MaxLag seconds, decides the
-- slice / perfect / topple with Logic/Stack, and on Serve checks the player stands at a Yeti table of
-- a zone they own (or at the Great Yeti), then pays: zone value × fluff × tower bonus × craving ×
-- multipliers, with a tip for nearby chefs. Every change is broadcast so all clients draw all stacks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Zones = require(Shared.Config.Zones)
local Cfg = require(Shared.Config.Stack)
local Net = require(Shared.Net)
local Stack = require(Shared.Logic.Stack)
local ZoneGeo = require(Shared.Logic.ZoneGeo)
local Economy = require(Shared.Logic.Economy)
local SafeNumber = require(Shared.Logic.SafeNumber)

local StackService = {}

local K = Net.StackKinds
local S: any
local stacks: { [Player]: Stack.State } = {}
local lastDrop: { [Player]: number } = {}
local lastServe: { [Player]: number } = {}
local lastActive: { [Player]: number } = {}
local autoPending: { [Player]: boolean } = {}
local lastAnnounce = 0
local rng = Random.new()

function StackService:Init(services)
	S = services
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function rootOf(player: Player): BasePart?
	local c = player.Character
	local root = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then
		return nil
	end
	return root
end

-- Wire form of a whole stack (snapshots and resets).
local function wireLayers(st: Stack.State): { any }
	local out = table.create(#st.layers)
	for _, l in st.layers do
		table.insert(out, { l.x, l.z, l.r, if l.perfect then 1 else 0, if l.sprinkle then 1 else 0, l.flavor })
	end
	return out
end

local function wireFull(st: Stack.State): any
	return {
		k = K.Reset,
		base = st.baseR,
		layers = wireLayers(st),
		st = st.start,
		sp = st.speed,
		sk = st.sprinkle,
		combo = st.combo,
	}
end

function StackService:Get(player: Player): Stack.State?
	return stacks[player]
end

-- Arm the next sliding pancake on a stack.
local function armNext(player: Player, st: Stack.State, from: number)
	Stack.arm(
		st,
		from + Cfg.NextDelay,
		Stack.speedFor(#st.layers, Economy.slideFactor(S.Economy:Context(player))),
		rng:NextNumber() < Cfg.SprinkleChance
	)
end

-- Start a fresh, empty stack with the player's current pan size and tell everyone.
function StackService:Reset(player: Player)
	local profile = S.Data:Get(player)
	if not profile then
		return
	end
	local st = Stack.new(Economy.panRadius(profile))
	armNext(player, st, now())
	stacks[player] = st
	autoPending[player] = nil
	S.Net:FireAll("Stack", player.UserId, wireFull(st))
end

-- The Yeti (or Great Yeti) this player can serve right now: (zoneId, yetiIndex | "great", x, z).
function StackService:ServeTarget(player: Player, profile: any, root: BasePart?): (string?, any, number, number)
	local r = root or rootOf(player)
	if not r then
		return nil, nil, 0, 0
	end
	local pos = r.CFrame.Position
	local zoneId = S.Zone:PlayerZone(player)
	if not zoneId or not profile.zones[zoneId] then
		return nil, nil, 0, 0
	end
	local zone = Zones.ById[zoneId]
	if math.abs(pos.Y - zone.center.y) > Cfg.MaxHeightDiff + 6 then
		return nil, nil, 0, 0
	end
	local order = S.Order:Current()
	if order and order.zone == zoneId then
		local dx, dz = pos.X - order.x, pos.Z - order.z
		if dx * dx + dz * dz <= S.Order:Reach() ^ 2 then
			return zoneId, "great", order.x, order.z
		end
	end
	local yeti, d = ZoneGeo.nearestYeti(zoneId, pos.X, pos.Z)
	if d <= Cfg.ServeDistance then
		return zoneId, yeti.index, yeti.x, yeti.z
	end
	return nil, nil, 0, 0
end

-- Pay for a stack. `target` = yeti index, "great" or "auto". Returns the Maple paid.
function StackService:Pay(player: Player, profile: any, zoneId: string, target: any, x: number, z: number): number
	local st = stacks[player]
	if not st or #st.layers == 0 then
		return 0
	end
	local zone = Zones.ById[zoneId]
	local n = #st.layers
	local t = now()
	local craving = false
	if type(target) == "number" then
		local lo, hi = Stack.craving(zone.order, target, t)
		craving = Stack.inCraving(n, lo, hi)
	end
	local base = Stack.value(st, zone.value, Economy.towerK(profile), craving)
	local ctx = S.Economy:Context(player)
	local amount = SafeNumber.currency(Economy.serveReward(profile, ctx, base))
	S.Economy:AddMaple(player, amount)
	profile.stats.serves += 1
	if craving then
		profile.stats.cravings += 1
	end
	if n > profile.stats.tallest then
		profile.stats.tallest = n
	end
	S.Data:Changed(player, "stats")
	S.Tutorial:Event(player, "serve")

	local y = zone.center.y
	S.Net:FireAll("Stack", player.UserId, { k = K.Served, n = n, x = x, z = z, great = target == "great" })
	S.Net:Fire("ServeResult", player, {
		amount = amount,
		n = n,
		craving = craving,
		auto = target == "auto",
		great = target == "great",
		x = x,
		y = y,
		z = z,
	})
	if target == "great" then
		S.Order:Contribute(player, n)
	end
	if n >= Cfg.AnnounceHeight and os.clock() - lastAnnounce > Cfg.AnnounceCooldown then
		lastAnnounce = os.clock()
		S.Net:FireAll(
			"Announce",
			string.format("%s served a %d-pancake tower in %s!", player.DisplayName, n, zone.name),
			"tower"
		)
	end

	-- Tips: other active chefs nearby get a share, with their own multipliers.
	if target ~= "auto" then
		local center = Vector3.new(x, y, z)
		for _, other in Players:GetPlayers() do
			if other ~= player and lastActive[other] and os.clock() - lastActive[other] <= Cfg.ShareActiveSeconds then
				local otherProfile = S.Data:Get(other)
				local r = rootOf(other)
				if
					otherProfile
					and r
					and otherProfile.zones[zoneId]
					and (r.CFrame.Position - center).Magnitude <= Cfg.ShareRadius
				then
					local tip = SafeNumber.currency(
						Economy.serveReward(otherProfile, S.Economy:Context(other), base) * Cfg.ShareFraction
					)
					S.Economy:AddMaple(other, tip)
					S.Net:Fire("ServeResult", other, {
						amount = tip,
						n = n,
						tip = true,
						from = player.DisplayName,
						x = x,
						y = y,
						z = z,
					})
				end
			end
		end
	end

	-- A fresh, empty tray.
	local fresh = Stack.new(Economy.panRadius(profile))
	armNext(player, fresh, t + 0.4)
	stacks[player] = fresh
	S.Net:FireAll("Stack", player.UserId, wireFull(fresh))
	return amount
end

local function onDrop(player: Player, profile: any, clientT: number)
	local st = stacks[player]
	if not st or not rootOf(player) then
		return
	end
	local clock = os.clock()
	if lastDrop[player] and clock - lastDrop[player] < Cfg.MinDropInterval - 0.03 then
		return
	end
	if #st.layers >= Economy.trayMax(profile) then
		S.Net:Notify(player, "Your tray is full! Serve it to a Yeti 🍽️", "info")
		return
	end
	local t0 = now()
	if t0 < st.start then
		return -- the next pancake hasn't appeared yet
	end
	lastDrop[player] = clock
	lastActive[player] = clock
	local t = Stack.acceptTime(clientT, t0, st.start)
	local zoneId = S.Zone:PlayerZone(player)
	local flavor = if zoneId then Zones.ById[zoneId].order else Zones.ById[Economy.bestZone(profile)].order
	local result = Stack.drop(st, t, Economy.perfectWindow(profile, S.Economy:Context(player)), flavor)
	S.Tutorial:Event(player, "drop")
	if result.kind == "topple" then
		-- Crumbs: a share of what the tower was worth, then a fresh tray.
		local zone = Zones.ById[Economy.bestZone(profile)]
		local base = Stack.value(st, zone.value, Economy.towerK(profile), false) * Cfg.ToppleRefund
		local amount = SafeNumber.currency(Economy.serveReward(profile, S.Economy:Context(player), base))
		S.Economy:AddMaple(player, amount)
		profile.stats.topples += 1
		S.Data:Changed(player, "stats")
		S.Net:FireAll("Stack", player.UserId, { k = K.Topple, n = #st.layers, t = t, off = result.offset })
		S.Net:Fire("ServeResult", player, { amount = amount, n = #st.layers, topple = true })
		local fresh = Stack.new(Economy.panRadius(profile))
		armNext(player, fresh, t0 + 0.9)
		stacks[player] = fresh
		S.Net:FireAll("Stack", player.UserId, wireFull(fresh))
		return
	end
	local l = result.layer :: Stack.Layer
	profile.stats.pancakes += 1
	if result.kind == "perfect" then
		profile.stats.perfects += 1
		S.Tutorial:Event(player, "perfect")
	end
	if st.combo > profile.stats.bestCombo then
		profile.stats.bestCombo = st.combo
	end
	S.Data:Changed(player, "stats")
	armNext(player, st, t)
	S.Net:FireAll("Stack", player.UserId, {
		k = K.Drop,
		n = #st.layers,
		l = { l.x, l.z, l.r, if l.perfect then 1 else 0, if l.sprinkle then 1 else 0, l.flavor },
		t = t,
		off = result.offset,
		cut = result.cut,
		combo = st.combo,
		st = st.start,
		sp = st.speed,
		sk = st.sprinkle,
	})
	-- Auto Serve pass: a full tray goes to your best zone's Yetis by itself.
	if
		#st.layers >= Economy.trayMax(profile)
		and S.Monetization:Owns(player, "AutoServe")
		and profile.settings.autoServe ~= false
		and not autoPending[player]
	then
		autoPending[player] = true
		task.delay(Cfg.AutoServeDelay, function()
			autoPending[player] = nil
			local p = S.Data:Get(player)
			if p and stacks[player] == st and #st.layers > 0 then
				local best = Economy.bestZone(p)
				local y = ZoneGeo.yetis(best)[1]
				StackService:Pay(player, p, best, "auto", y.x, y.z)
			end
		end)
	end
end

function StackService:Start()
	S.Data.Loaded:Connect(function(player)
		self:Reset(player)
		player.CharacterAdded:Connect(function()
			-- A new character starts with an empty tray (the old tower fell with the old one).
			self:Reset(player)
		end)
	end)
	Players.PlayerRemoving:Connect(function(p)
		stacks[p] = nil
		lastDrop[p] = nil
		lastServe[p] = nil
		lastActive[p] = nil
		autoPending[p] = nil
		S.Net:FireAll("Stack", p.UserId, { k = K.Reset, gone = true })
	end)

	S.Net:On("Drop", function(t)
		return type(t) == "number" and t == t and t > -math.huge and t < math.huge
	end, onDrop)

	S.Net:On("Serve", function()
		return true
	end, function(player, profile)
		local st = stacks[player]
		if not st or #st.layers == 0 then
			return
		end
		local clock = os.clock()
		if lastServe[player] and clock - lastServe[player] < Cfg.ServeCooldown then
			return
		end
		if not S.Zone:IsHonest(player) then
			return
		end
		local zoneId, target, x, z = self:ServeTarget(player, profile)
		if not zoneId then
			S.Net:Notify(player, "Walk up to a Yeti's table to serve 🍽️", "error")
			return
		end
		lastServe[player] = clock
		self:Pay(player, profile, zoneId, target, x, z)
	end)

	S.Net:On("StackSnapshot", function()
		return true
	end, function(player)
		local all = {}
		for p, st in stacks do
			all[tostring(p.UserId)] = wireFull(st)
		end
		S.Net:Fire("StackSnapshot", player, all)
	end)
end

-- Called when upgrades change: if the tray is empty, rebuild it with the new pan size.
function StackService:Refresh(player: Player)
	local st = stacks[player]
	local profile = S.Data:Get(player)
	if st and profile and #st.layers == 0 and st.baseR ~= Economy.panRadius(profile) then
		self:Reset(player)
	end
end

return StackService
