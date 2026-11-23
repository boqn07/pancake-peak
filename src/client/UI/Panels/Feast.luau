--!strict
-- Yeti Feast (rebirth) on the left, the Spatula Shop (permanent perks) on the right.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rebirth = require(Shared:WaitForChild("Config"):WaitForChild("Rebirth"))
local Zones = require(Shared.Config:WaitForChild("Zones"))
local Perks = require(Shared.Config:WaitForChild("Perks"))
local Economy = require(Shared:WaitForChild("Logic"):WaitForChild("Economy"))
local Progression = require(Shared.Logic:WaitForChild("Progression"))
local Format = require(Shared.Logic:WaitForChild("Format"))

return function(C, Kit, Theme, Root)
	local p = Kit.panel("Yeti Feast", Theme.Colors.aurora, Vector2.new(960, 560))
	local left = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0.5, -10, 1, 0),
		Parent = p.body,
	})
	local right = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0.5, -10, 1, 0),
		Position = UDim2.new(0.5, 10, 0, 0),
		Parent = p.body,
	})

	-- Yeti Feast ----------------------------------------------------------------------------------
	Kit.label({
		Text = "Throw the Yetis a feast: reset Maple and upgrades for a permanent Maple boost and Golden Spatulas.",
		Font = Theme.BodyFont,
		Size = UDim2.new(1, 0, 0, 56),
		MaxTextSize = 22,
		Parent = left,
	})
	local multLabel = Kit.label({
		Text = "",
		TextColor3 = Theme.Colors.berry,
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.fromOffset(0, 60),
		MaxTextSize = 34,
		Parent = left,
	})
	local spatulaGain = Kit.label({
		Text = "",
		TextColor3 = Theme.Colors.aurora,
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.fromOffset(0, 106),
		MaxTextSize = 24,
		Parent = left,
	})
	local reqZone = Kit.label({
		Text = "",
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(0, 140),
		MaxTextSize = 22,
		Parent = left,
	})
	local reqMaple = Kit.label({
		Text = "",
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(0, 170),
		MaxTextSize = 22,
		Parent = left,
	})
	local bar, setBar = Kit.bar(Theme.Colors.ice, UDim2.new(0.9, 0, 0, 24), left)
	bar.Position = UDim2.new(0.05, 0, 0, 204)
	Kit.label({
		Text = "Keeps: zones, Nibblers, Spatulas, perks, stats\nResets: Maple and upgrades",
		Font = Theme.BodyFont,
		TextColor3 = Theme.Colors.muted,
		Size = UDim2.new(1, 0, 0, 46),
		Position = UDim2.fromOffset(0, 238),
		MaxTextSize = 20,
		Parent = left,
	})
	local slotLabel = Kit.label({
		Text = "",
		TextColor3 = Theme.Colors.pine,
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(0, 290),
		MaxTextSize = 22,
		Parent = left,
	})
	local confirm = false
	local button
	button = Kit.button({
		text = "Yeti Feast",
		color = Theme.Colors.aurora,
		textColor = Theme.Colors.white,
		size = UDim2.fromOffset(330, 84),
		position = UDim2.new(0.5, -165, 1, -92),
		parent = left,
		onClick = function()
			local data = C.State.data
			local ok = Economy.rebirthCost(data.rebirths or 0) <= (data.maple or 0)
				and data.zones
				and data.zones[Rebirth.RequiredZone]
			if not ok then
				C.Audio:Play("Error")
				return
			end
			if not confirm then
				confirm = true
				Kit.setButton(button, "Tap again to confirm", Theme.Colors.berry, true)
				task.delay(3, function()
					confirm = false
				end)
				return
			end
			confirm = false
			C.ClientNet:Fire("Rebirth")
			Root:Close()
		end,
	})

	-- Spatula Shop ---------------------------------------------------------------------------------
	local shopHead = Kit.new("Frame", {
		BackgroundColor3 = Theme.Colors.white,
		Size = UDim2.new(1, 0, 0, 52),
		Parent = right,
	}, { Kit.corner(UDim.new(0, 14)), Kit.stroke(Theme.Colors.paperDark, 3) })
	local spatulaLabel = Kit.label({
		Text = "",
		Size = UDim2.new(1, -20, 1, -10),
		Position = UDim2.fromOffset(10, 5),
		MaxTextSize = 30,
		Parent = shopHead,
	})
	local list = Kit.scroll(right, { Size = UDim2.new(1, 0, 1, -62), Position = UDim2.fromOffset(0, 62) })
	Kit.list(list, 8)
	Kit.padding(4).Parent = list
	local rows: { [string]: { level: TextLabel, buy: TextButton } } = {}
	for i, perk in Perks.List do
		local card = Kit.card({ LayoutOrder = i, Size = UDim2.new(1, -12, 0, 92), Parent = list })
		local badge = Kit.badge(perk.glyph, Theme.Colors.butter, 60)
		badge.Position = UDim2.fromOffset(10, 16)
		badge.Parent = card
		Kit.label({
			Text = perk.name,
			Size = UDim2.new(1, -230, 0, 30),
			Position = UDim2.fromOffset(80, 8),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 26,
			Parent = card,
		})
		Kit.label({
			Text = perk.description,
			Font = Theme.BodyFont,
			TextColor3 = Theme.Colors.muted,
			Size = UDim2.new(1, -230, 0, 22),
			Position = UDim2.fromOffset(80, 38),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 18,
			Parent = card,
		})
		local level = Kit.label({
			Text = "",
			TextColor3 = Theme.Colors.navy,
			Size = UDim2.new(1, -230, 0, 22),
			Position = UDim2.fromOffset(80, 62),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 18,
			Parent = card,
		})
		local buy = Kit.button({
			text = "",
			color = Theme.Colors.aurora,
			textColor = Theme.Colors.white,
			size = UDim2.fromOffset(136, 64),
			position = UDim2.new(1, -146, 0.5, -32),
			parent = card,
			sound = "Purchase",
			onClick = function()
				C.ClientNet:Fire("BuyPerk", perk.id)
			end,
		})
		rows[perk.id] = { level = level, buy = buy }
	end

	local function refresh()
		local data = C.State.data
		if not data.zones then
			return
		end
		local r = data.rebirths or 0
		multLabel.Text = string.format(
			"%s  →  %s Maple",
			Format.mult(Economy.rebirthMultiplier(r)),
			Format.mult(Economy.rebirthMultiplier(r + 1))
		)
		spatulaGain.Text =
			string.format("+%d 🥄 Golden Spatulas (bank more Maple for extra)", Economy.spatulasFor(data))
		local zone = Zones.ById[Rebirth.RequiredZone]
		local hasZone = data.zones[Rebirth.RequiredZone] == true
		reqZone.Text = (if hasZone then "✔ " else "✖ ") .. "Unlock " .. zone.name
		reqZone.TextColor3 = if hasZone then Theme.Colors.pine else Theme.Colors.berry
		local cost = Economy.rebirthCost(r)
		local maple = data.maple or 0
		reqMaple.Text = string.format(
			"%s Have %s / %s Maple",
			if maple >= cost then "✔" else "✖",
			Format.abbreviate(maple),
			Format.abbreviate(cost)
		)
		reqMaple.TextColor3 = if maple >= cost then Theme.Colors.pine else Theme.Colors.berry
		setBar(maple / cost)
		local nextSlot = nil
		for _, at in Rebirth.BonusSlotsAt do
			if at > r then
				nextSlot = at
				break
			end
		end
		slotLabel.Text = if nextSlot
			then string.format("Yeti Feast #%d also gives +1 Nibbler slot", nextSlot)
			else "All bonus slots earned!"
		if not confirm then
			Kit.setButton(button, "Yeti Feast #" .. (r + 1), Theme.Colors.aurora, hasZone and maple >= cost)
		end

		local spatulas = data.spatulas or 0
		spatulaLabel.Text = "🥄 " .. Format.abbreviate(spatulas) .. " Golden Spatulas"
		for _, perk in Perks.List do
			local row = rows[perk.id]
			local lvl = (data.perks and data.perks[perk.id]) or 0
			row.level.Text = string.format("Level %d / %d", lvl, perk.maxLevel)
			if lvl >= perk.maxLevel then
				Kit.setButton(row.buy, "MAX", Theme.Colors.locked, false)
			else
				local pc = Progression.perkCost(perk.id, lvl)
				local can = spatulas >= pc
				Kit.setButton(row.buy, "🥄 " .. pc, if can then Theme.Colors.aurora else Theme.Colors.locked, can)
			end
		end
	end

	return {
		root = p.root,
		scale = p.scale,
		refresh = function(keys)
			if keys.all or keys.maple or keys.rebirths or keys.zones or keys.spatulas or keys.perks then
				refresh()
			end
		end,
		firstSelectable = function()
			return button
		end,
	}
end
