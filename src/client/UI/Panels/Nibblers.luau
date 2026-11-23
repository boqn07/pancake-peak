--!strict
-- Inventory: grid of Nibblers (lightweight cards), detail pane with a 3D preview and actions.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Nibblers = require(Shared:WaitForChild("Config"):WaitForChild("Nibblers"))
local Game = require(Shared.Config:WaitForChild("Game"))
local Economy = require(Shared:WaitForChild("Logic"):WaitForChild("Economy"))
local Format = require(Shared.Logic:WaitForChild("Format"))

local FEATURE_GLYPH = {
	Ears = "🦊",
	LongEars = "🐰",
	RoundEars = "🐻",
	Tail = "🐿️",
	FluffyTail = "🐿️",
	Beak = "🐧",
	Wings = "🦉",
	Antlers = "🦌",
	Horns = "🐐",
	Tusks = "🐗",
	Horn = "🦄",
	ChefHat = "👨‍🍳",
	Scarf = "🧣",
	Mask = "🦝",
	Stripes = "🦡",
	Spots = "🐆",
	Crest = "🐦",
	Glow = "✨",
}

return function(C, Kit, Theme, _Root)
	local p = Kit.panel("Nibblers", Theme.Colors.pine, Vector2.new(980, 580))

	-- Top bar
	local top = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 64), Parent = p.body })
	local slotsLabel = Kit.label({
		Text = "",
		Size = UDim2.new(0.4, 0, 1, -12),
		Position = UDim2.fromOffset(4, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 28,
		Parent = top,
	})
	local equipBest = Kit.button({
		text = "Equip Best",
		color = Theme.Colors.pine,
		size = UDim2.fromOffset(200, 58),
		position = UDim2.new(0.62, -206, 0, 3),
		parent = top,
		onClick = function()
			C.ClientNet:Fire("EquipBest")
		end,
	})

	-- Grid (left) and detail (right)
	local grid = Kit.scroll(p.body, { Size = UDim2.new(0.62, -10, 1, -72), Position = UDim2.fromOffset(0, 72) })
	Kit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(130, 150),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	Kit.padding(6).Parent = grid
	local detail = Kit.card({ Size = UDim2.new(0.38, -6, 1, -8), Position = UDim2.new(0.62, 6, 0, 0), Parent = p.body })
	local previewHolder = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -20, 0, 190),
		Position = UDim2.fromOffset(10, 10),
		Parent = detail,
	})
	local nameLabel = Kit.label({
		Text = "Pick a Nibbler",
		Size = UDim2.new(1, -20, 0, 38),
		Position = UDim2.fromOffset(10, 200),
		MaxTextSize = 32,
		Parent = detail,
	})
	local rarityLabel = Kit.label({
		Text = "",
		Size = UDim2.new(1, -20, 0, 26),
		Position = UDim2.fromOffset(10, 238),
		MaxTextSize = 24,
		Parent = detail,
	})
	local statLabel = Kit.label({
		Text = "",
		TextColor3 = Theme.Colors.berry,
		Size = UDim2.new(1, -20, 0, 50),
		Position = UDim2.fromOffset(10, 266),
		MaxTextSize = 24,
		Parent = detail,
	})
	local equipBtn = Kit.button({
		text = "Equip",
		color = Theme.Colors.pine,
		size = UDim2.new(1, -24, 0, 66),
		position = UDim2.new(0, 12, 1, -150),
		parent = detail,
	})
	local releaseBtn = Kit.button({
		text = "Release",
		color = Theme.Colors.berry,
		size = UDim2.new(1, -24, 0, 60),
		position = UDim2.new(0, 12, 1, -76),
		parent = detail,
	})

	local selected: string? = nil
	local confirmRelease = false
	local cards: { [string]: Frame } = {}

	local function itemPower(item): number
		return Economy.nibblerPower(item)
	end

	local function showDetail()
		for _, ch in previewHolder:GetChildren() do
			ch:Destroy()
		end
		confirmRelease = false
		local data = C.State.data
		local item = selected and data.nibblers and data.nibblers[selected]
		if not item then
			nameLabel.Text = "Pick a Nibbler"
			rarityLabel.Text = ""
			statLabel.Text = ""
			equipBtn.Visible = false
			releaseBtn.Visible = false
			return
		end
		local def = Nibblers.ById[item.id]
		local vp = C.NibblerModels:Viewport(item.id, item.shiny, true)
		vp.Size = UDim2.fromScale(1, 1)
		vp.Parent = previewHolder
		nameLabel.Text = (if item.shiny then "Sparkly " else "") .. def.name
		rarityLabel.Text = def.rarity
		rarityLabel.TextColor3 = Theme.Rarity[def.rarity]
		local steady = Economy.nibblerSteady(item)
		statLabel.Text = string.format(
			"+%s%% Maple%s",
			Format.abbreviate(math.floor(itemPower(item) * 100)),
			if steady > 0 then string.format("\n+%.2f studs perfect window", steady) else ""
		)
		local equipped = table.find(data.equipped or {}, selected) ~= nil
		equipBtn.Visible = true
		releaseBtn.Visible = true
		Kit.setButton(
			equipBtn,
			if equipped then "Unequip" else "Equip",
			if equipped then Theme.Colors.white else Theme.Colors.pine,
			true
		)
		Kit.setButton(releaseBtn, "Release", Theme.Colors.berry, true)
	end

	equipBtn.Activated:Connect(function()
		if not selected then
			return
		end
		local equipped = table.find(C.State.data.equipped or {}, selected) ~= nil
		C.ClientNet:Fire(if equipped then "Unequip" else "Equip", selected)
	end)
	releaseBtn.Activated:Connect(function()
		if not selected then
			return
		end
		if not confirmRelease then
			confirmRelease = true
			Kit.setButton(releaseBtn, "Tap again to release", Theme.Colors.berry, true)
			task.delay(3, function()
				if confirmRelease then
					confirmRelease = false
					Kit.setButton(releaseBtn, "Release", Theme.Colors.berry, true)
				end
			end)
			return
		end
		C.ClientNet:Fire("Release", selected)
		selected = nil
	end)

	local function rebuildGrid()
		for _, ch in grid:GetChildren() do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
		table.clear(cards)
		local data = C.State.data
		local items = {}
		for uid, item in data.nibblers or {} do
			table.insert(items, { uid = uid, item = item, power = itemPower(item) })
		end
		local equippedSet = {}
		for _, uid in data.equipped or {} do
			equippedSet[uid] = true
		end
		table.sort(items, function(a, b)
			if (equippedSet[a.uid] == true) ~= (equippedSet[b.uid] == true) then
				return equippedSet[a.uid] == true
			end
			if a.power ~= b.power then
				return a.power > b.power
			end
			return tonumber(a.uid) > tonumber(b.uid)
		end)
		for i, e in items do
			local def = Nibblers.ById[e.item.id]
			local rc = Theme.Rarity[def.rarity]
			local card = Kit.new("TextButton", {
				LayoutOrder = i,
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = Theme.Colors.white,
				Selectable = true,
				Parent = grid,
			}, {
				Kit.corner(UDim.new(0, 16)),
				Kit.stroke(
					if equippedSet[e.uid] then Theme.Colors.berry else rc,
					if equippedSet[e.uid] then 4 else 2.5
				),
			})
			local orb = Kit.new("Frame", {
				Size = UDim2.fromOffset(70, 70),
				Position = UDim2.new(0.5, -35, 0, 10),
				BackgroundColor3 = Color3.fromHex(def.look.body),
				Parent = card,
			}, { Kit.corner(UDim.new(0.5, 0)), Kit.stroke(Color3.fromHex(def.look.accent), 4) })
			Kit.label({
				Text = FEATURE_GLYPH[def.look.features[1] or ""] or "🐾",
				Size = UDim2.fromScale(0.6, 0.6),
				Position = UDim2.fromScale(0.2, 0.2),
				Parent = orb,
			})
			if e.item.shiny then
				local g = {}
				for k, c in Theme.ShinyGradient do
					table.insert(g, ColorSequenceKeypoint.new((k - 1) / (#Theme.ShinyGradient - 1), c))
				end
				Kit.new("UIGradient", { Color = ColorSequence.new(g), Rotation = 45, Parent = orb })
			end
			Kit.label({
				Text = def.name,
				Size = UDim2.new(1, -8, 0, 24),
				Position = UDim2.fromOffset(4, 84),
				MaxTextSize = 20,
				Parent = card,
			})
			Kit.label({
				Text = "+" .. Format.abbreviate(math.floor(e.power * 100)) .. "%",
				TextColor3 = rc,
				Size = UDim2.new(1, -8, 0, 24),
				Position = UDim2.fromOffset(4, 110),
				MaxTextSize = 20,
				Parent = card,
			})
			if equippedSet[e.uid] then
				Kit.label({
					Text = "✔",
					TextColor3 = Theme.Colors.berry,
					Size = UDim2.fromOffset(28, 28),
					Position = UDim2.fromOffset(6, 4),
					Parent = card,
				})
			end
			card.Activated:Connect(function()
				C.Audio:Play("Click")
				selected = e.uid
				showDetail()
			end)
			cards[e.uid] = card
		end
		local slots = C.State.derived.slots or Game.BaseEquipSlots
		slotsLabel.Text =
			string.format("Equipped %d/%d  ·  Bag %d/%d", #(data.equipped or {}), slots, #items, Game.InventoryCap)
		if selected and not (data.nibblers or {})[selected] then
			selected = nil
		end
		showDetail()
	end

	return {
		root = p.root,
		scale = p.scale,
		refresh = function(keys)
			if keys.all or keys.nibblers or keys.equipped or keys.derived then
				rebuildGrid()
			end
		end,
		firstSelectable = function()
			return equipBest
		end,
	}
end
