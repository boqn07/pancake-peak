--!strict
-- The saved player profile: defaults, versioned migrations and sanitizing.
-- Rules: never remove a migration; bump VERSION and append a step to MIGRATIONS when the shape changes.
local Config = script.Parent.Parent.Config
local Upgrades = require(Config.Upgrades)
local Perks = require(Config.Perks)
local Nibblers = require(Config.Nibblers)
local Zones = require(Config.Zones)
local SafeNumber = require(script.Parent.SafeNumber)

local Schema = {}

Schema.VERSION = 1

function Schema.default(): any
	local upgrades = {}
	for _, u in Upgrades.List do
		upgrades[u.id] = 0
	end
	local perks = {}
	for _, p in Perks.List do
		perks[p.id] = 0
	end
	return {
		version = Schema.VERSION,
		maple = 0,
		lifetimeMaple = 0,
		spatulas = 0,
		rebirths = 0,
		upgrades = upgrades,
		perks = perks,
		zones = { [Zones.List[1].id] = true },
		nibblers = {}, -- uid -> { id = string, shiny = boolean, t = unix time }
		equipped = {}, -- array of uids
		nextUid = 1,
		stats = {
			serves = 0,
			pancakes = 0,
			perfects = 0,
			tallest = 0,
			bestCombo = 0,
			topples = 0,
			cravings = 0,
			hatches = 0,
			orders = 0,
			playSeconds = 0,
		},
		daily = { streak = 0, lastDay = -1 },
		codes = {}, -- CODE -> true
		boosts = { Maple2x = 0, Lucky = 0 }, -- seconds remaining (counts down while online)
		settings = { music = true, sfx = true, performance = false, autoEquip = true, autoServe = true },
		tutorial = { step = 0, done = false },
		receipts = {}, -- recent PurchaseIds, oldest first
		firstJoin = 0,
	}
end

-- MIGRATIONS[n] upgrades a profile from version n to n + 1. Version 1 is the launch shape, so the
-- list is empty; the migration path itself is covered by tests with a sample migration.
Schema.MIGRATIONS = {} :: { (any) -> any }

-- Fill any missing keys from the defaults (deep, tables only), without overwriting existing values.
local function reconcile(target: any, template: any)
	for k, v in template do
		if target[k] == nil then
			if type(v) == "table" then
				local copy = {}
				reconcile(copy, v)
				target[k] = copy
			else
				target[k] = v
			end
		elseif type(v) == "table" and type(target[k]) == "table" and next(v) ~= nil then
			-- Only reconcile tables that have a fixed shape (non-empty template).
			reconcile(target[k], v)
		elseif type(v) == "table" and type(target[k]) ~= "table" then
			target[k] = {}
			reconcile(target[k], v)
		end
	end
end

-- Bring stored data up to `version` with `migrations`. Returns (profile, ok, err).
-- Data from a NEWER version (a rollback of the game) is refused rather than downgraded and saved.
function Schema.migrateWith(data: any, migrations: { (any) -> any }, version: number): (any, boolean, string?)
	if data == nil then
		local fresh = Schema.default()
		fresh.version = version
		return fresh, true, nil
	end
	if type(data) ~= "table" then
		return nil, false, "corrupt profile"
	end
	local v = tonumber(data.version) or 1
	if v > version then
		return nil, false, "profile is from a newer game version"
	end
	while v < version do
		local step = migrations[v]
		if not step then
			return nil, false, "missing migration from version " .. v
		end
		data = step(data)
		v += 1
		data.version = v
	end
	reconcile(data, Schema.default())
	data.version = version
	Schema.sanitize(data)
	return data, true, nil
end

function Schema.migrate(data: any): (any, boolean, string?)
	return Schema.migrateWith(data, Schema.MIGRATIONS, Schema.VERSION)
end

-- Repair invalid values in place (NaN/negative currency, unknown items, broken equip lists).
function Schema.sanitize(p: any)
	p.maple = SafeNumber.currency(p.maple)
	p.lifetimeMaple = SafeNumber.currency(p.lifetimeMaple)
	p.spatulas = math.floor(SafeNumber.currency(p.spatulas))
	p.rebirths = math.max(0, math.floor(SafeNumber.currency(p.rebirths)))
	for _, u in Upgrades.List do
		local lvl = tonumber(p.upgrades[u.id]) or 0
		p.upgrades[u.id] = math.clamp(math.floor(SafeNumber.currency(lvl)), 0, u.maxLevel)
	end
	for _, perk in Perks.List do
		local lvl = tonumber(p.perks[perk.id]) or 0
		p.perks[perk.id] = math.clamp(math.floor(SafeNumber.currency(lvl)), 0, perk.maxLevel)
	end
	for uid, item in p.nibblers do
		if type(item) ~= "table" or not Nibblers.ById[item.id] then
			p.nibblers[uid] = nil
		else
			item.shiny = item.shiny == true
		end
	end
	local seen = {}
	local cleaned = {}
	for _, uid in p.equipped do
		if type(uid) == "string" and p.nibblers[uid] and not seen[uid] then
			seen[uid] = true
			table.insert(cleaned, uid)
		end
	end
	p.equipped = cleaned
	for id in p.zones do
		if not Zones.ById[id] then
			p.zones[id] = nil
		end
	end
	p.zones[Zones.List[1].id] = true
	for k, v in p.boosts do
		p.boosts[k] = math.max(0, tonumber(v) or 0)
	end
	if type(p.receipts) ~= "table" then
		p.receipts = {}
	end
	-- uids must never be reused, even if nextUid was lost or rolled back.
	local nextUid = math.max(1, math.floor(tonumber(p.nextUid) or 1))
	for uid in p.nibblers do
		local n = tonumber(uid)
		if n and n >= nextUid then
			nextUid = math.floor(n) + 1
		end
	end
	p.nextUid = nextUid
end

return Schema
