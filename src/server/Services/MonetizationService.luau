--!strict
-- Game passes (ownership cache) and developer products (idempotent ProcessReceipt).
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Monetization = require(Shared.Config.Monetization)
local Game = require(Shared.Config.Game)
local RewardGrant = require(Shared.Logic.RewardGrant)
local Signal = require(Shared.Util.Signal)
local ReceiptProcessor = require(script.Parent.Parent.Data.ReceiptProcessor)

local MonetizationService = {}
MonetizationService.PassesChanged = Signal.new() -- (player)

local S: any
local owned: { [Player]: { [string]: boolean } } = {}
local passByid: { [number]: string } = {}
local productById: { [number]: string } = {}

function MonetizationService:Init(services)
	S = services
	for key, p in Monetization.Passes do
		if p.id ~= 0 then
			passByid[p.id] = key
		end
	end
	for key, p in Monetization.Products do
		if p.id ~= 0 then
			productById[p.id] = key
		end
	end
end

local function checkPasses(player: Player)
	local set = owned[player] or {}
	for key, p in Monetization.Passes do
		if Game.StudioOwnsAllPasses and RunService:IsStudio() then
			set[key] = true
		elseif p.id ~= 0 and not set[key] then
			local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, p.id)
			if ok and has then
				set[key] = true
			end
		end
	end
	if not player.Parent then
		return -- left while the ownership checks were yielding
	end
	owned[player] = set
	MonetizationService.PassesChanged:Fire(player)
end

local function grant(userId: number, session: any, key: string): boolean
	local product = Monetization.Products[key]
	local player = Players:GetPlayerByUserId(userId)
	if not product or not player then
		return false
	end
	local g = product.grant
	if g.kind == "Order" then
		S.Order:Trigger(player)
		S.Net:FireAll(
			"Announce",
			string.format("%s summoned the Great Yeti for everyone! 🥞", player.DisplayName),
			"order"
		)
		return true
	end
	local result = RewardGrant.apply(session.data, g, S.Economy:Context(player), function()
		return math.random()
	end, os.time())
	S.Data:Changed(player, "maple", "lifetimeMaple", "boosts", "nibblers")
	S.Data:DerivedChanged(player)
	S.Net:Fire("Reward", player, { source = "Purchase", results = { result } })
	return true
end

function MonetizationService:Start()
	Players.PlayerAdded:Connect(function(p)
		task.spawn(checkPasses, p)
	end)
	for _, p in Players:GetPlayers() do
		task.spawn(checkPasses, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		owned[p] = nil
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local key = passByid[passId]
		if not key then
			return
		end
		-- Verify with Roblox instead of trusting the event payload.
		local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
		if ok and has then
			owned[player] = owned[player] or {}
			owned[player][key] = true
			MonetizationService.PassesChanged:Fire(player)
			S.Net:Notify(player, "Unlocked " .. Monetization.Passes[key].name .. "! Thank you!", "success")
		end
	end)

	MarketplaceService.ProcessReceipt = function(receipt)
		local decision = ReceiptProcessor.process({
			getSession = function(userId)
				return S.Data:GetSessionByUserId(userId)
			end,
			productKey = function(productId)
				return productById[productId]
			end,
			grant = grant,
			save = function(session)
				return S.Data:SaveNow(session)
			end,
			log = function(msg)
				warn("[Receipts] " .. msg)
			end,
		}, receipt)
		if decision == "Granted" then
			local player = Players:GetPlayerByUserId(receipt.PlayerId)
			if player then
				S.Net:Notify(player, "Purchase complete. Thank you!", "success")
			end
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

function MonetizationService:Owns(player: Player, key: string): boolean
	local set = owned[player]
	return set ~= nil and set[key] == true
end

function MonetizationService:Passes(player: Player): { [string]: boolean }
	return owned[player] or {}
end

return MonetizationService
