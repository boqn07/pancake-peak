--!strict
-- Yeti Feast (rebirth).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Progression = require(Shared.Logic.Progression)
local Economy = require(Shared.Logic.Economy)

local RebirthService = {}

local S: any

local function ordinal(n: number): string
	local last = n % 10
	if n % 100 >= 11 and n % 100 <= 13 then
		return n .. "th"
	end
	return n .. (if last == 1 then "st" elseif last == 2 then "nd" elseif last == 3 then "rd" else "th")
end

function RebirthService:Init(services)
	S = services
end

function RebirthService:Start()
	S.Net:On("Rebirth", function()
		return true
	end, function(player, profile)
		local ok, why, spatulas = Progression.rebirth(profile)
		if not ok then
			S.Net:Notify(player, why or "Can't feast yet", "error")
			return
		end
		S.Data:Changed(player, "maple", "upgrades", "rebirths", "spatulas")
		S.Data:DerivedChanged(player)
		S.Economy:ApplyCharacter(player)
		S.Stack:Refresh(player)
		S.Net:Notify(
			player,
			string.format(
				"Yeti Feast! +%d Golden Spatulas, Maple x%.2f forever",
				spatulas,
				Economy.rebirthMultiplier(profile.rebirths)
			),
			"rebirth"
		)
		S.Net:FireAll(
			"Announce",
			string.format("%s threw their %s Yeti Feast! 🥞", player.DisplayName, ordinal(profile.rebirths)),
			"rebirth"
		)
	end)
end

return RebirthService
