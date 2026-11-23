--!strict
-- Robux store: game passes and developer products. Prompts go to Roblox; the server grants.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Monetization = require(Shared:WaitForChild("Config"):WaitForChild("Monetization"))

local RewardText = require(script.Parent.Parent:WaitForChild("RewardText"))

local PASS_GLYPH = {
	DoubleMaple = "⚡",
	AutoServe = "🤖",
	SteadySpatula = "🎯",
	ExtraPockets = "🎒",
	LuckyYolk = "🍀",
	TripleHatch = "🥚",
	FastHatch = "⏩",
}
local PRODUCT_GLYPH = {
	MaplePouch = "👝",
	MapleJar = "🍯",
	MapleBarrel = "🛢️",
	Boost2x = "⚡",
	BoostLucky = "🍀",
	SummonYeti = "👹",
}

return function(C, Kit, Theme, Root)
	local p = Kit.panel("Store", Theme.Colors.berry, Vector2.new(980, 580))
	local tab = "Passes"
	local tabs = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 62), Parent = p.body })
	Kit.list(tabs, 12, true)
	local list = Kit.scroll(p.body, { Size = UDim2.new(1, 0, 1, -70), Position = UDim2.fromOffset(0, 70) })
	Kit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(290, 210),
		CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = list,
	})
	Kit.padding(6).Parent = list
	local first: TextButton? = nil

	local function prompt(kind: string, key: string)
		local def = if kind == "pass" then Monetization.Passes[key] else Monetization.Products[key]
		if not def or def.id == 0 then
			Root:Toast("This item isn't on sale yet.", "info")
			return
		end
		if kind == "pass" then
			MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, def.id)
		else
			MarketplaceService:PromptProductPurchase(Players.LocalPlayer, def.id)
		end
	end

	local function item(
		order: number,
		glyph: string,
		title: string,
		desc: string,
		price: number,
		owned: boolean,
		color: Color3,
		onBuy: () -> ()
	)
		local card = Kit.card({ LayoutOrder = order, Size = UDim2.fromOffset(290, 210), Parent = list })
		local badge = Kit.badge(glyph, color, 64)
		badge.Position = UDim2.fromOffset(12, 12)
		badge.Parent = card
		Kit.label({
			Text = title,
			Size = UDim2.new(1, -96, 0, 34),
			Position = UDim2.fromOffset(86, 14),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 28,
			Parent = card,
		})
		Kit.label({
			Text = desc,
			Font = Theme.BodyFont,
			TextColor3 = Theme.Colors.muted,
			Size = UDim2.new(1, -24, 0, 50),
			Position = UDim2.fromOffset(12, 84),
			TextWrapped = true,
			MaxTextSize = 20,
			Parent = card,
		})
		local b = Kit.button({
			text = if owned then "Owned ✔" else "R$ " .. price,
			color = if owned then Theme.Colors.locked else Theme.Colors.pine,
			size = UDim2.new(1, -24, 0, 58),
			position = UDim2.new(0, 12, 1, -68),
			parent = card,
			sound = "Purchase",
			onClick = function()
				if not owned then
					onBuy()
				end
			end,
		})
		first = first or b
	end

	local function rebuild()
		for _, ch in list:GetChildren() do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
		first = nil
		local passes = C.State.derived.passes or {}
		if tab == "Passes" then
			for i, key in Monetization.PassOrder do
				local def = Monetization.Passes[key]
				item(
					i,
					PASS_GLYPH[key] or "⭐",
					def.name,
					def.description,
					def.price,
					passes[key] == true,
					Theme.Colors.berry,
					function()
						prompt("pass", key)
					end
				)
			end
		else
			local income = C.State.derived.income or 0
			for i, key in Monetization.ProductOrder do
				local def = Monetization.Products[key]
				local _, desc = RewardText.describe(def.grant, income)
				if def.grant.kind == "Maple" then
					desc = "≈ " .. desc .. " (scales with your progress)"
				elseif def.grant.kind == "Order" then
					desc = "The Great Yeti stomps in for the whole server: fill its order together for a Snow Day!"
				end
				item(i, PRODUCT_GLYPH[key] or "⭐", def.name, desc, def.price, false, Theme.Colors.butter, function()
					prompt("product", key)
				end)
			end
		end
	end

	local tabButtons = {}
	for i, name in { "Passes", "Boosts & Maple" } do
		tabButtons[name] = Kit.button({
			text = name,
			color = if i == 1 then Theme.Colors.berry else Theme.Colors.white,
			size = UDim2.fromOffset(260, 56),
			layoutOrder = i,
			parent = tabs,
			onClick = function()
				tab = if i == 1 then "Passes" else "Products"
				for n, b in tabButtons do
					b.BackgroundColor3 = if n == name then Theme.Colors.berry else Theme.Colors.white
				end
				rebuild()
			end,
		})
	end

	return {
		root = p.root,
		scale = p.scale,
		onOpen = rebuild,
		refresh = function(keys)
			if keys.derived then
				rebuild()
			end
		end,
		firstSelectable = function()
			return first
		end,
	}
end
