--!strict
-- Mystery Eggs, the Nibbler inventory, equip/unequip/release, and publishing equipped Nibblers
-- so every client can draw followers.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Eggs = require(Shared.Config.Eggs)
local Nibblers = require(Shared.Config.Nibblers)
local Rarities = require(Shared.Config.Rarities)
local Zones = require(Shared.Config.Zones)
local Game = require(Shared.Config.Game)
local Hatch = require(Shared.Logic.Hatch)
local Inventory = require(Shared.Logic.Inventory)
local Economy = require(Shared.Logic.Economy)
local SafeNumber = require(Shared.Logic.SafeNumber)
local Validate = require(Shared.Logic.Validate)

local NibblerService = {}

local S: any
local lastOpen: { [Player]: number } = {}
local rng = Random.new()

function NibblerService:Init(services)
	S = services
end

-- Followers: "Pip:0,Muffin:1" (id:shiny) as a player attribute that every client reads.
function NibblerService:Publish(player: Player)
	local profile = S.Data:Get(player)
	if not profile then
		return
	end
	local parts = {}
	for _, item in Economy.equippedItems(profile) do
		table.insert(parts, item.id .. ":" .. (if item.shiny then "1" else "0"))
	end
	player:SetAttribute("Nibblers", table.concat(parts, ","))
end

-- Egg luck for a player: Lucky Yolk pass, Lucky boost and the Lucky Yolk perk multiply.
-- `lucky` (better Sparkly odds) comes from the pass or the boost.
function NibblerService:Luck(player: Player, profile: any): (number, boolean)
	local luck = 1 + Economy.perk(profile, "LuckyYolk")
	local lucky = false
	if S.Monetization:Owns(player, "LuckyYolk") then
		luck *= Eggs.LuckyPassLuck
		lucky = true
	end
	if (profile.boosts.Lucky or 0) > 0 then
		luck *= Eggs.LuckyBoostLuck
		lucky = true
	end
	return luck, lucky
end

local function changed(player: Player)
	S.Data:Changed(player, "nibblers", "equipped")
	S.Data:DerivedChanged(player)
	NibblerService:Publish(player)
end

local function validUid(uid: any): boolean
	return Validate.string(uid, 12)
end

function NibblerService:Start()
	S.Data.Loaded:Connect(function(player)
		self:Publish(player)
	end)
	S.Monetization.PassesChanged:Connect(function(player)
		local profile = S.Data:Get(player)
		if profile then
			Inventory.fitSlots(profile, Economy.equipSlots(profile, S.Economy:Context(player)))
			changed(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		lastOpen[p] = nil
	end)

	S.Net:On("HatchEgg", function(eggId, count)
		return Validate.key(eggId, Eggs.ById) and (count == 1 or count == 3)
	end, function(player, profile, eggId, count)
		local egg = Eggs.ById[eggId]
		if not profile.zones[egg.zone] then
			S.Net:Notify(player, "Unlock " .. Zones.ById[egg.zone].name .. " first", "error")
			return
		end
		if count == 3 and not S.Monetization:Owns(player, "TripleHatch") then
			S.Net:Notify(player, "Hatching 3 needs the Triple Hatch pass", "error")
			return
		end
		local fast = S.Monetization:Owns(player, "FastHatch")
		local cooldown = if fast then Eggs.OpenCooldownFast else Eggs.OpenCooldown
		local now = os.clock()
		if lastOpen[player] and now - lastOpen[player] < cooldown then
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local machine = S.World:Egg(eggId)
		if not root or not machine or (root.CFrame.Position - machine).Magnitude > Game.EggDistance then
			S.Net:Notify(player, "Walk up to the Mystery Egg to hatch it", "error")
			return
		end
		if not Inventory.hasRoom(profile, count) then
			S.Net:Notify(player, "Your Nibbler bag is full! Release some first.", "error")
			return
		end
		local ok, balance = SafeNumber.trySpend(profile.maple, egg.cost * count)
		if not ok then
			S.Net:Notify(player, "Not enough Maple", "error")
			return
		end
		lastOpen[player] = now
		profile.maple = balance
		local luck, lucky = self:Luck(player, profile)
		local results = {}
		for _ = 1, count do
			local id, shiny, rarity = Hatch.roll(eggId, luck, lucky, function()
				return rng:NextNumber()
			end)
			local uid = Inventory.add(profile, id, shiny, os.time())
			table.insert(results, { uid = uid, id = id, shiny = shiny, rarity = rarity })
			if Rarities.ById[rarity].announce or shiny then
				S.Net:FireAll(
					"Announce",
					string.format(
						"%s found a %s%s %s!",
						player.DisplayName,
						if shiny then "Sparkly " else "",
						rarity,
						Nibblers.ById[id].name
					),
					if shiny then "shiny" else string.lower(rarity)
				)
			end
		end
		profile.stats.hatches += count
		if profile.settings.autoEquip then
			Inventory.equipBest(profile, Economy.equipSlots(profile, S.Economy:Context(player)))
		end
		S.Data:Changed(player, "maple", "stats")
		changed(player)
		S.Net:Fire("EggResult", player, { eggId = eggId, results = results, fast = fast })
		S.Tutorial:Event(player, "egg")
	end)

	S.Net:On("Equip", validUid, function(player, profile, uid)
		local ok, why = Inventory.equip(profile, uid, Economy.equipSlots(profile, S.Economy:Context(player)))
		if not ok then
			if why == "no free slot" then
				S.Net:Notify(player, "All slots are full. Unequip one first.", "error")
			end
			return
		end
		changed(player)
	end)

	S.Net:On("Unequip", validUid, function(player, profile, uid)
		if Inventory.unequip(profile, uid) then
			changed(player)
		end
	end)

	S.Net:On("Release", validUid, function(player, profile, uid)
		if Inventory.release(profile, uid) then
			changed(player)
		end
	end)

	S.Net:On("EquipBest", function()
		return true
	end, function(player, profile)
		Inventory.equipBest(profile, Economy.equipSlots(profile, S.Economy:Context(player)))
		changed(player)
	end)
end

return NibblerService
