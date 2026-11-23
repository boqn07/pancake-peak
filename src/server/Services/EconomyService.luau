--!strict
-- Maple income, multipliers, friend bonus, character speed and leaderstats.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Logic.Economy)
local SafeNumber = require(Shared.Logic.SafeNumber)
local Format = require(Shared.Logic.Format)
local Inventory = require(Shared.Logic.Inventory)

local EconomyService = {}

local S: any
local friendCount: { [Player]: number } = {}
local leaderstats: { [Player]: { maple: StringValue, rebirths: IntValue } } = {}

function EconomyService:Init(services)
	S = services
end

local function recountFriends()
	local list = Players:GetPlayers()
	for _, p in list do
		local n = 0
		for _, other in list do
			if other ~= p then
				local ok, isFriend = pcall(p.IsFriendsWith, p, other.UserId)
				if ok and isFriend then
					n += 1
				end
			end
		end
		if friendCount[p] ~= n then
			friendCount[p] = n
			S.Data:DerivedChanged(p)
		end
	end
end

local function makeLeaderstats(player: Player, profile: any)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local maple = Instance.new("StringValue")
	maple.Name = "Maple"
	maple.Value = Format.abbreviate(profile.maple)
	maple.Parent = folder
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Feasts"
	rebirths.Value = profile.rebirths
	rebirths.Parent = folder
	folder.Parent = player
	leaderstats[player] = { maple = maple, rebirths = rebirths }
end

-- Apply speed from Snow Boots and Swift Skis to the current character.
function EconomyService:ApplyCharacter(player: Player)
	local profile = S.Data:Get(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if profile and humanoid then
		humanoid.WalkSpeed = Economy.walkSpeed(profile)
	end
end

function EconomyService:Start()
	S.Data.Loaded:Connect(function(player, profile)
		makeLeaderstats(player, profile)
		-- Passes may have changed (bought on the website); drop extra equipped Nibblers if slots shrank.
		Inventory.fitSlots(profile, Economy.equipSlots(profile, self:Context(player)))
		self:ApplyCharacter(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			self:ApplyCharacter(player)
		end)
		task.spawn(recountFriends)
	end)
	S.Monetization.PassesChanged:Connect(function(player)
		S.Data:DerivedChanged(player)
	end)
	Players.PlayerRemoving:Connect(function(p)
		friendCount[p] = nil
		leaderstats[p] = nil
		task.defer(recountFriends)
	end)
	-- Leaderstats refresh (cheap, 1 Hz).
	task.spawn(function()
		while true do
			task.wait(1)
			for p, ls in leaderstats do
				local profile = S.Data:Get(p)
				if profile then
					ls.maple.Value = Format.abbreviate(profile.maple)
					ls.rebirths.Value = profile.rebirths
				end
			end
		end
	end)
end

function EconomyService:Context(player: Player): Economy.Context
	return {
		passes = S.Monetization:Passes(player),
		friends = friendCount[player] or 0,
		snowDay = S.Order:IsSnowDay(),
	}
end

function EconomyService:Multipliers(player: Player): Economy.Breakdown?
	local profile = S.Data:Get(player)
	if not profile then
		return nil
	end
	return Economy.multipliers(profile, self:Context(player))
end

-- The only way Maple is earned. Amount is sanitized; returns the amount actually added.
function EconomyService:AddMaple(player: Player, amount: number): number
	local profile = S.Data:Get(player)
	if not profile then
		return 0
	end
	amount = SafeNumber.currency(amount)
	local before = profile.maple
	profile.maple = SafeNumber.add(profile.maple, amount)
	profile.lifetimeMaple = SafeNumber.add(profile.lifetimeMaple, amount)
	S.Data:Changed(player, "maple", "lifetimeMaple")
	return profile.maple - before
end

-- Values the client shows but can't compute alone (it doesn't know passes/friends authoritatively).
function EconomyService:Derived(player: Player): any
	local profile = S.Data:Get(player)
	if not profile then
		return {}
	end
	local ctx = self:Context(player)
	return {
		mult = Economy.multipliers(profile, ctx),
		window = Economy.perfectWindow(profile, ctx),
		pan = Economy.panRadius(profile),
		tray = Economy.trayMax(profile),
		towerK = Economy.towerK(profile),
		slide = Economy.slideFactor(ctx),
		snowDay = ctx.snowDay,
		speed = Economy.walkSpeed(profile),
		slots = Economy.equipSlots(profile, ctx),
		passes = ctx.passes,
		friends = ctx.friends,
		rebirthCost = Economy.rebirthCost(profile.rebirths),
		income = Economy.estimatedIncome(profile, ctx),
	}
end

return EconomyService
