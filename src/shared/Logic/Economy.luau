--!strict
-- All currency math: multipliers, perfect window, pan size, tray size, tower bonus, slots, speed,
-- reward scaling, Yeti Feast. Takes a plain profile table plus a context of things the profile doesn't
-- store (passes, friends, Snow Day).
local Config = script.Parent.Parent.Config
local Game = require(Config.Game)
local Zones = require(Config.Zones)
local Nibblers = require(Config.Nibblers)
local Rebirth = require(Config.Rebirth)
local Monetization = require(Config.Monetization)
local Order = require(Config.Order)
local Perks = require(Config.Perks)
local StackCfg = require(Config.Stack)
local UpgradeMath = require(script.Parent.UpgradeMath)
local Stack = require(script.Parent.Stack)

local Economy = {}

export type Context = {
	passes: { [string]: boolean },
	friends: number,
	snowDay: boolean,
}

export type Breakdown = {
	batter: number,
	nibblers: number,
	rebirth: number,
	syrup: number,
	friends: number,
	pass: number,
	boost: number,
	snow: number,
	total: number,
}

-- Income model used only to turn "minutes of income" rewards into Maple: a typical player serves a
-- stack this tall, this fluffy per pancake, once per cycle. Calibrated against the pacing model
-- (tests/PacingSim.luau); see docs/BALANCING.md.
Economy.TypicalHeight = 15
Economy.TypicalFluff = 1.05
Economy.TypicalCycleSeconds = 20

function Economy.emptyContext(): Context
	return { passes = {}, friends = 0, snowDay = false }
end

function Economy.nibblerPower(item: { id: string, shiny: boolean? }): number
	local d = Nibblers.ById[item.id]
	if not d then
		return 0
	end
	return d.power * (if item.shiny then Nibblers.ShinyMult else 1)
end

function Economy.nibblerSteady(item: { id: string, shiny: boolean? }): number
	local d = Nibblers.ById[item.id]
	if not d then
		return 0
	end
	return d.steady * (if item.shiny then Nibblers.ShinyMult else 1)
end

function Economy.perk(profile: any, id: string): number
	local p = Perks.ById[id]
	return (profile.perks and profile.perks[id] or 0) * p.perLevel
end

function Economy.rebirthMultiplier(rebirths: number): number
	return 1 + Rebirth.PerRebirth * rebirths
end

function Economy.friendMultiplier(friends: number): number
	return 1 + math.min(Game.FriendBonusMax, Game.FriendBonusPerFriend * math.max(0, friends))
end

function Economy.equippedItems(profile: any): { any }
	local out = {}
	for _, uid in profile.equipped do
		local item = profile.nibblers[uid]
		if item then
			table.insert(out, item)
		end
	end
	return out
end

function Economy.multipliers(profile: any, ctx: Context): Breakdown
	local batter = UpgradeMath.effect("Batter", profile.upgrades.Batter or 0)
	local nb = 1
	for _, item in Economy.equippedItems(profile) do
		nb += Economy.nibblerPower(item)
	end
	local reb = Economy.rebirthMultiplier(profile.rebirths)
	local syrup = 1 + Economy.perk(profile, "GoldenSyrup")
	local fr = Economy.friendMultiplier(ctx.friends)
	local pass = if ctx.passes.DoubleMaple then Monetization.DoubleMapleMult else 1
	local boost = if (profile.boosts.Maple2x or 0) > 0 then 2 else 1
	local snow = if ctx.snowDay then Order.SnowMult else 1
	return {
		batter = batter,
		nibblers = nb,
		rebirth = reb,
		syrup = syrup,
		friends = fr,
		pass = pass,
		boost = boost,
		snow = snow,
		total = batter * nb * reb * syrup * fr * pass * boost * snow,
	}
end

-- PERFECT window in studs: Steady Hands + equipped Nibblers (× Steady Spatula pass).
function Economy.perfectWindow(profile: any, ctx: Context): number
	local w = UpgradeMath.effect("Steady", profile.upgrades.Steady or 0)
	for _, item in Economy.equippedItems(profile) do
		w += Economy.nibblerSteady(item)
	end
	if ctx.passes.SteadySpatula then
		w *= Monetization.SteadySpatulaMult
	end
	return w
end

-- Pancake (pan) radius in studs.
function Economy.panRadius(profile: any): number
	return UpgradeMath.effect("Pan", profile.upgrades.Pan or 0)
end

-- Most pancakes the tray holds.
function Economy.trayMax(profile: any): number
	return math.floor(UpgradeMath.effect("Tray", profile.upgrades.Tray or 0))
end

-- Strength of the tower bonus (the `towerK` in Stack.towerBonus).
function Economy.towerK(profile: any): number
	return StackCfg.TowerK * (1 + Economy.perk(profile, "TowerSense"))
end

-- Slide speed multiplier for everyone (Snow Day slows pancakes down).
function Economy.slideFactor(ctx: Context): number
	return if ctx.snowDay then Order.SnowSlowFactor else 1
end

function Economy.walkSpeed(profile: any): number
	return UpgradeMath.effect("Boots", profile.upgrades.Boots or 0) * (1 + Economy.perk(profile, "SwiftSkis"))
end

function Economy.equipSlots(profile: any, ctx: Context): number
	local slots = Game.BaseEquipSlots + math.floor(Economy.perk(profile, "ExtraPocket"))
	for _, at in Rebirth.BonusSlotsAt do
		if profile.rebirths >= at then
			slots += 1
		end
	end
	if ctx.passes.ExtraPockets then
		slots += Monetization.ExtraPocketsSlots
	end
	return slots
end

-- Maple a served stack pays a player: base stack value (Stack.value) × their multipliers.
function Economy.serveReward(profile: any, ctx: Context, baseValue: number): number
	return baseValue * Economy.multipliers(profile, ctx).total
end

-- The most valuable zone the player owns.
function Economy.bestZone(profile: any): string
	local best = Zones.List[1]
	for _, z in Zones.List do
		if profile.zones[z.id] and z.order > best.order then
			best = z
		end
	end
	return best.id
end

-- Rough income estimate (Maple/second) used to scale "minutes of income" rewards and products.
function Economy.estimatedIncome(profile: any, ctx: Context): number
	local zone = Zones.ById[Economy.bestZone(profile)]
	local m = Economy.multipliers(profile, { passes = ctx.passes, friends = 0, snowDay = false })
	-- Boosts shouldn't inflate the estimate (or a 2x boost would double a purchased pack).
	local total = m.total / m.boost
	local h = math.min(Economy.TypicalHeight, Economy.trayMax(profile))
	local perStack = Stack.valueOf(h, h * Economy.TypicalFluff, zone.value, Economy.towerK(profile))
	return perStack / Economy.TypicalCycleSeconds * total
end

function Economy.scaledMaple(profile: any, ctx: Context, minutes: number, min: number): number
	local amount = Economy.estimatedIncome(profile, ctx) * 60 * minutes
	return math.floor(math.max(min, amount))
end

function Economy.rebirthCost(rebirths: number): number
	return Rebirth.BaseCost * Rebirth.CostGrowth ^ rebirths
end

-- Golden Spatulas a Yeti Feast would give right now.
function Economy.spatulasFor(profile: any): number
	local cost = Economy.rebirthCost(profile.rebirths)
	local extra = 0
	if profile.maple > cost then
		extra = math.floor(math.log10(profile.maple / cost))
	end
	return Rebirth.SpatulasBase + math.clamp(extra, 0, Rebirth.SpatulasMaxBonus)
end

return Economy
