--!strict
-- The Great Yeti's Order: the co-op server event. Every IntervalSeconds (or when someone buys one)
-- the Great Yeti stomps into the plaza of the busiest zone. Every pancake served to it fills one
-- shared order; filling it in time pays every contributor and starts a server-wide Snow Day
-- (2x Maple, slower pancakes).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Order = require(Shared.Config.Order)
local Zones = require(Shared.Config.Zones)
local ZoneGeo = require(Shared.Logic.ZoneGeo)
local RewardGrant = require(Shared.Logic.RewardGrant)

local OrderService = {}

type OrderState = {
	zone: string,
	x: number,
	z: number,
	filled: number,
	target: number,
	endsAt: number,
	contrib: { [Player]: number },
}

local S: any
local rng = Random.new()
local current: OrderState? = nil
local snowEndsAt = 0
local nextNatural = 0

function OrderService:Init(services)
	S = services
end

local function now(): number
	return workspace:GetServerTimeNow()
end

function OrderService:IsSnowDay(): boolean
	return now() < snowEndsAt
end

function OrderService:Current(): OrderState?
	return current
end

function OrderService:Reach(): number
	return Order.ServeReach
end

local function payload(): any
	local o = current
	if not o then
		return { active = false, snowEndsAt = snowEndsAt }
	end
	return {
		active = true,
		zone = o.zone,
		x = o.x,
		z = o.z,
		filled = o.filled,
		target = o.target,
		endsAt = o.endsAt,
		snowEndsAt = snowEndsAt,
	}
end

local function allDerivedChanged()
	for _, p in Players:GetPlayers() do
		S.Data:DerivedChanged(p)
	end
end

-- The zone with the most players (ties: the more valuable one); Maple Meadow if nobody is in one.
local function busiestZone(): string
	local pop = S.Zone:Population()
	local best, bestN = Zones.List[1].id, 0
	for _, z in Zones.List do
		local n = pop[z.id] or 0
		if n > bestN or (n == bestN and n > 0) then
			best, bestN = z.id, n
		end
	end
	return best
end

-- Start an Order now (while one is active, a bought one adds 30 s instead).
function OrderService:Trigger(_by: Player?)
	if current then
		current.endsAt += 30
		S.Net:FireAll("Order", payload())
		return
	end
	local id = busiestZone()
	local zone = Zones.ById[id]
	local plaza = ZoneGeo.landmarks(id).plaza
	local players = math.max(1, S.Zone:Population()[id] or 0)
	local target = math.floor(Order.BaseLayers * (1 + Order.LayersPerExtraPlayer * (players - 1)))
	current = {
		zone = id,
		x = plaza.x,
		z = plaza.z,
		filled = 0,
		target = target,
		endsAt = now() + Order.DurationSeconds,
		contrib = {},
	}
	nextNatural = now() + Order.IntervalSeconds
	S.Net:FireAll("Order", payload())
	S.Net:FireAll(
		"Announce",
		string.format("The Great Yeti stomped into %s! Serve it %d pancakes!", zone.name, target),
		"order"
	)
end

local function finish(filled: boolean)
	local o = current
	if not o then
		return
	end
	current = nil
	if filled then
		local total = 0
		for _, c in o.contrib do
			total += c
		end
		local rewarded = 0
		for player, c in o.contrib do
			local profile = S.Data:Get(player)
			if profile and player.Parent and total > 0 and c / total >= Order.MinShare then
				rewarded += 1
				local result = RewardGrant.apply(
					profile,
					{ kind = "Maple", minutes = Order.RewardMinutes, min = Order.RewardMin },
					S.Economy:Context(player),
					function()
						return rng:NextNumber()
					end,
					os.time()
				)
				profile.stats.orders += 1
				S.Data:Changed(player, "maple", "lifetimeMaple", "stats")
				S.Net:Fire("Reward", player, { source = "Order", results = { result } })
			end
		end
		snowEndsAt = now() + Order.SnowSeconds
		allDerivedChanged()
		S.Net:FireAll(
			"Announce",
			string.format("%d chefs filled the Great Yeti's order! SNOW DAY: x%d Maple!", rewarded, Order.SnowMult),
			"order"
		)
	end
	S.Net:FireAll("Order", payload())
end

-- Count pancakes served to the Great Yeti (StackService calls this after paying).
function OrderService:Contribute(player: Player, pancakes: number)
	local o = current
	if not o or pancakes <= 0 then
		return
	end
	o.filled += pancakes
	o.contrib[player] = (o.contrib[player] or 0) + pancakes
	if o.filled >= o.target then
		finish(true)
	else
		S.Net:FireAll("Order", payload())
	end
end

function OrderService:Start()
	nextNatural = now() + Order.FirstDelaySeconds
	S.Data.Loaded:Connect(function(player)
		S.Net:Fire("Order", player, payload())
	end)
	Players.PlayerRemoving:Connect(function(p)
		if current then
			current.contrib[p] = nil
		end
	end)

	local wasSnow = false
	while true do
		task.wait(0.5)
		local t = now()
		if not current and t >= nextNatural then
			self:Trigger(nil)
		end
		local o = current
		if o and t >= o.endsAt then
			finish(false)
			S.Net:FireAll("Announce", "The Great Yeti wandered off, still hungry... next time!", "info")
		end
		local snow = self:IsSnowDay()
		if wasSnow ~= snow then
			allDerivedChanged()
		end
		wasSnow = snow
	end
end

return OrderService
