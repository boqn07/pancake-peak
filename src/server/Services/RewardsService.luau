--!strict
-- Daily streak, playtime gifts, codes, boost timers and play time.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Rewards = require(Shared.Config.Rewards)
local Daily = require(Shared.Logic.Daily)
local Codes = require(Shared.Logic.Codes)
local Boosts = require(Shared.Logic.Boosts)
local RewardGrant = require(Shared.Logic.RewardGrant)
local Validate = require(Shared.Logic.Validate)

local RewardsService = {}

local S: any
local sessionStart: { [Player]: number } = {}
local playtimeClaimed: { [Player]: { [number]: boolean } } = {}
local rng = Random.new()

function RewardsService:Init(services)
	S = services
end

local function grantAll(player: Player, profile: any, rewards: { any }, source: string)
	local results = {}
	local ctx = S.Economy:Context(player)
	for _, r in rewards do
		table.insert(
			results,
			RewardGrant.apply(profile, r, ctx, function()
				return rng:NextNumber()
			end, os.time())
		)
	end
	S.Data:Changed(player, "maple", "lifetimeMaple", "boosts", "nibblers", "daily", "codes")
	S.Data:DerivedChanged(player)
	S.Net:Fire("Reward", player, { source = source, results = results })
	S.Nibbler:Publish(player)
end

function RewardsService:Start()
	S.Data.Loaded:Connect(function(player)
		sessionStart[player] = os.clock()
		playtimeClaimed[player] = {}
		S.Net:Fire("Reward", player, { source = "Session", claimed = {}, elapsed = 0 })
	end)
	Players.PlayerRemoving:Connect(function(p)
		sessionStart[p] = nil
		playtimeClaimed[p] = nil
	end)

	S.Net:On("ClaimDaily", function()
		return true
	end, function(player, profile)
		local day = Daily.claim(profile.daily, os.time(), #Rewards.Daily)
		if not day then
			S.Net:Notify(player, "Come back tomorrow for your next reward!", "info")
			return
		end
		grantAll(player, profile, { Rewards.Daily[day] }, "Daily")
	end)

	S.Net:On("ClaimPlaytime", function(index)
		return Validate.int(index, 1, #Rewards.Playtime)
	end, function(player, profile, index)
		local claimed = playtimeClaimed[player]
		local start = sessionStart[player]
		if not claimed or not start or claimed[index] then
			return
		end
		local gift = Rewards.Playtime[index]
		if os.clock() - start < gift.unlockAt * 60 then
			return
		end
		claimed[index] = true
		grantAll(player, profile, { gift.reward }, "Playtime")
		S.Net:Fire("Reward", player, { source = "PlaytimeClaimed", index = index })
	end)

	S.Net:On("RedeemCode", function(code)
		return Validate.string(code, Rewards.MaxCodeLength)
	end, function(player, profile, code)
		local ok, result = Codes.check(profile, code, os.time())
		if not ok then
			S.Net:Notify(player, result, "error")
			S.Net:Fire("Reward", player, { source = "CodeFailed", message = result })
			return
		end
		profile.codes[result] = true
		grantAll(player, profile, Rewards.Codes[result].rewards, "Code")
	end)

	-- 1 Hz: boost timers and play time.
	while true do
		task.wait(1)
		for player, profile in S.Data:Players() do
			profile.stats.playSeconds += 1
			local hadBoost = false
			for _, v in profile.boosts do
				if v > 0 then
					hadBoost = true
				end
			end
			if hadBoost and Boosts.tick(profile, 1) then
				S.Data:Changed(player, "boosts")
				S.Data:DerivedChanged(player)
			end
		end
	end
end

return RewardsService
