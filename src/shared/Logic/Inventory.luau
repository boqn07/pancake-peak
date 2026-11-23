--!strict
-- Nibbler inventory operations on a profile. Each returns (ok, reason?). Pure and server-validated.
local Game = require(script.Parent.Parent.Config.Game)
local Economy = require(script.Parent.Economy)

local Inventory = {}

function Inventory.count(profile: any): number
	local n = 0
	for _ in profile.nibblers do
		n += 1
	end
	return n
end

function Inventory.hasRoom(profile: any, amount: number): boolean
	return Inventory.count(profile) + amount <= Game.InventoryCap
end

-- Adds a Nibbler and returns its uid.
function Inventory.add(profile: any, nibblerId: string, shiny: boolean, now: number): string
	local uid = tostring(profile.nextUid)
	profile.nextUid += 1
	profile.nibblers[uid] = { id = nibblerId, shiny = shiny, t = now }
	return uid
end

local function indexOf(list: { string }, uid: string): number?
	for i, v in list do
		if v == uid then
			return i
		end
	end
	return nil
end

function Inventory.isEquipped(profile: any, uid: string): boolean
	return indexOf(profile.equipped, uid) ~= nil
end

function Inventory.equip(profile: any, uid: string, slots: number): (boolean, string?)
	if not profile.nibblers[uid] then
		return false, "missing"
	end
	if indexOf(profile.equipped, uid) then
		return false, "already equipped"
	end
	if #profile.equipped >= slots then
		return false, "no free slot"
	end
	table.insert(profile.equipped, uid)
	return true, nil
end

function Inventory.unequip(profile: any, uid: string): (boolean, string?)
	local i = indexOf(profile.equipped, uid)
	if not i then
		return false, "not equipped"
	end
	table.remove(profile.equipped, i)
	return true, nil
end

-- Release (delete) a Nibbler. Equipped Nibblers are unequipped first.
function Inventory.release(profile: any, uid: string): (boolean, string?)
	if not profile.nibblers[uid] then
		return false, "missing"
	end
	Inventory.unequip(profile, uid)
	profile.nibblers[uid] = nil
	return true, nil
end

-- Equip the strongest Nibblers (by power, then steady) into all available slots.
function Inventory.equipBest(profile: any, slots: number)
	local all = {}
	for uid, item in profile.nibblers do
		table.insert(all, { uid = uid, power = Economy.nibblerPower(item), steady = Economy.nibblerSteady(item) })
	end
	table.sort(all, function(a, b)
		if a.power ~= b.power then
			return a.power > b.power
		end
		if a.steady ~= b.steady then
			return a.steady > b.steady
		end
		return a.uid < b.uid
	end)
	table.clear(profile.equipped)
	for i = 1, math.min(slots, #all) do
		table.insert(profile.equipped, all[i].uid)
	end
end

-- If slots shrank (e.g. a gamepass check failed), drop the extra equipped entries.
function Inventory.fitSlots(profile: any, slots: number)
	while #profile.equipped > slots do
		table.remove(profile.equipped)
	end
end

return Inventory
