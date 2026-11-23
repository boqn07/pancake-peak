--!strict
-- Mystery Egg window: real odds (with the player's luck applied), cost, hatch x1 / x3.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Eggs = require(Shared:WaitForChild("Config"):WaitForChild("Eggs"))
local Nibblers = require(Shared.Config:WaitForChild("Nibblers"))
local Perks = require(Shared.Config:WaitForChild("Perks"))
local Hatch = require(Shared:WaitForChild("Logic"):WaitForChild("Hatch"))
local Economy = require(Shared.Logic:WaitForChild("Economy"))
local Format = require(Shared.Logic:WaitForChild("Format"))

return function(C, Kit, Theme, Root)
	local p = Kit.panel("Mystery Egg", Theme.Colors.maple, Vector2.new(900, 560))
	local eggId = Eggs.List[1].id

	local oddsList = Kit.scroll(p.body, { Size = UDim2.new(0.6, -10, 1, -40), Position = UDim2.fromOffset(0, 40) })
	Kit.list(oddsList, 6)
	Kit.padding(4).Parent = oddsList
	local luckLabel = Kit.label({
		Text = "",
		Font = Theme.BodyFont,
		TextColor3 = Theme.Colors.muted,
		Size = UDim2.new(0.6, -10, 0, 32),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 22,
		Parent = p.body,
	})

	local side = Kit.card({ Size = UDim2.new(0.4, -6, 1, -8), Position = UDim2.new(0.6, 6, 0, 0), Parent = p.body })
	local costLabel = Kit.label({
		Text = "",
		TextColor3 = Theme.Colors.berry,
		Size = UDim2.new(1, -20, 0, 44),
		Position = UDim2.fromOffset(10, 16),
		MaxTextSize = 36,
		Parent = side,
	})
	local balanceLabel = Kit.label({
		Text = "",
		TextColor3 = Theme.Colors.muted,
		Size = UDim2.new(1, -20, 0, 26),
		Position = UDim2.fromOffset(10, 62),
		MaxTextSize = 22,
		Parent = side,
	})
	local open1 = Kit.button({
		text = "Hatch 1",
		color = Theme.Colors.pine,
		size = UDim2.new(1, -24, 0, 84),
		position = UDim2.fromOffset(12, 110),
		parent = side,
		onClick = function()
			C.EggReveal:Request(eggId, 1)
		end,
	})
	local open3 = Kit.button({
		text = "Hatch 3",
		color = Theme.Colors.aurora,
		size = UDim2.new(1, -24, 0, 84),
		position = UDim2.fromOffset(12, 206),
		parent = side,
		onClick = function()
			local passes = C.State.derived.passes or {}
			if passes.TripleHatch then
				C.EggReveal:Request(eggId, 3)
			else
				Root:Open("Store")
			end
		end,
	})
	Kit.label({
		Text = "Eggs cost Maple only.\nOdds below are your real odds.",
		Font = Theme.BodyFont,
		TextColor3 = Theme.Colors.muted,
		Size = UDim2.new(1, -20, 0, 56),
		Position = UDim2.new(0, 10, 1, -70),
		MaxTextSize = 20,
		Parent = side,
	})

	local function luck(): (number, boolean)
		local passes = C.State.derived.passes or {}
		local boosts = C.State.data.boosts or {}
		local perks = C.State.data.perks or {}
		local l, lucky = 1 + (perks.LuckyYolk or 0) * Perks.ById.LuckyYolk.perLevel, false
		if passes.LuckyYolk then
			l *= Eggs.LuckyPassLuck
			lucky = true
		end
		if (boosts.Lucky or 0) > 0 then
			l *= Eggs.LuckyBoostLuck
			lucky = true
		end
		return l, lucky
	end

	local function rebuild()
		for _, ch in oddsList:GetChildren() do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
		local egg = Eggs.ById[eggId]
		p.title.Text = egg.name
		local l, lucky = luck()
		for i, row in Hatch.odds(eggId, l) do
			local def = Nibblers.ById[row.nibbler]
			local rc = Theme.Rarity[row.rarity]
			local card = Kit.card({ LayoutOrder = i, Size = UDim2.new(1, -12, 0, 72), Parent = oddsList })
			local vp = C.NibblerModels:Viewport(def.id, false, false)
			vp.Size = UDim2.fromOffset(64, 64)
			vp.Position = UDim2.fromOffset(6, 4)
			vp.Parent = card
			Kit.label({
				Text = def.name,
				Size = UDim2.new(0.45, 0, 0, 32),
				Position = UDim2.fromOffset(78, 6),
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 26,
				Parent = card,
			})
			Kit.label({
				Text = row.rarity .. "  ·  +" .. Format.abbreviate(math.floor(def.power * 100)) .. "%",
				TextColor3 = rc,
				Size = UDim2.new(0.45, 0, 0, 24),
				Position = UDim2.fromOffset(78, 40),
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 20,
				Parent = card,
			})
			Kit.label({
				Text = Format.percent(row.chance),
				TextColor3 = rc,
				Size = UDim2.new(0.28, 0, 0, 44),
				Position = UDim2.new(0.7, 0, 0, 14),
				MaxTextSize = 34,
				Parent = card,
			})
		end
		luckLabel.Text = string.format(
			"Luck x%.2f%s  ·  Sparkly %s",
			l,
			if lucky then " 🍀" else "",
			Format.percent(Hatch.shinyChance(lucky))
		)
	end

	local function refreshCost()
		local egg = Eggs.ById[eggId]
		local data = C.State.data
		local maple = data.maple or 0
		costLabel.Text = "🍁 " .. Format.abbreviate(egg.cost)
		balanceLabel.Text = "You have " .. Format.abbreviate(maple)
		local owned = data.zones and data.zones[egg.zone]
		Kit.setButton(
			open1,
			if owned then "Hatch 1" else "🔒 Zone locked",
			Theme.Colors.pine,
			owned and maple >= egg.cost
		)
		local passes = C.State.derived.passes or {}
		if passes.TripleHatch then
			Kit.setButton(
				open3,
				"Hatch 3  (🍁 " .. Format.abbreviate(egg.cost * 3) .. ")",
				Theme.Colors.aurora,
				owned and maple >= egg.cost * 3
			)
		else
			Kit.setButton(open3, "Hatch 3  ·  Get pass", Theme.Colors.aurora, true)
		end
	end

	return {
		root = p.root,
		scale = p.scale,
		onOpen = function(args)
			if args and args.eggId and Eggs.ById[args.eggId] then
				eggId = args.eggId
			elseif C.State.data.zones then
				local best = Economy.bestZone(C.State.data)
				for _, e in Eggs.List do
					if e.zone == best then
						eggId = e.id
					end
				end
			end
			rebuild()
		end,
		refresh = function(keys)
			if keys.all or keys.maple or keys.zones or keys.derived then
				refreshCost()
			end
			if keys.derived or keys.boosts or keys.perks then
				rebuild()
			end
		end,
		firstSelectable = function()
			return open1
		end,
		egg = function()
			return eggId
		end,
	}
end
