--!strict
-- Maple upgrades and the Spatula Shop.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Upgrades = require(Shared.Config.Upgrades)
local Perks = require(Shared.Config.Perks)
local Progression = require(Shared.Logic.Progression)
local Validate = require(Shared.Logic.Validate)

local UpgradeService = {}

local S: any

function UpgradeService:Init(services)
	S = services
end

function UpgradeService:Start()
	S.Net:On("BuyUpgrade", function(id)
		return Validate.key(id, Upgrades.ById)
	end, function(player, profile, id)
		local ok, why = Progression.buyUpgrade(profile, id)
		if not ok then
			S.Net:Notify(player, why or "Can't buy", "error")
			return
		end
		S.Data:Changed(player, "maple", "upgrades")
		S.Data:DerivedChanged(player)
		if id == "Boots" then
			S.Economy:ApplyCharacter(player)
		elseif id == "Pan" then
			S.Stack:Refresh(player)
		end
		S.Tutorial:Event(player, "upgrade")
	end)

	S.Net:On("BuyPerk", function(id)
		return Validate.key(id, Perks.ById)
	end, function(player, profile, id)
		local ok, why = Progression.buyPerk(profile, id)
		if not ok then
			S.Net:Notify(player, why or "Can't buy", "error")
			return
		end
		S.Data:Changed(player, "spatulas", "perks")
		S.Data:DerivedChanged(player)
		if id == "SwiftSkis" then
			S.Economy:ApplyCharacter(player)
		end
		S.Net:Notify(player, Perks.ById[id].name .. " upgraded!", "success")
	end)
end

return UpgradeService
