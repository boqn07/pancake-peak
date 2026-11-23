--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Upgrades = require(Shared:WaitForChild("Config"):WaitForChild("Upgrades"))
local UpgradeMath = require(Shared:WaitForChild("Logic"):WaitForChild("UpgradeMath"))
local Format = require(Shared.Logic:WaitForChild("Format"))

local COLORS = { Batter = "maple", Steady = "ice", Pan = "cocoa", Tray = "wood", Boots = "pine" }

local function effectText(u: any, value: number): string
	if u.display == "mult" then
		return Format.mult(value)
	elseif u.display == "speed" then
		return string.format("%.1f speed", value)
	elseif u.display == "studs" then
		return string.format("%.2f studs", value)
	elseif u.display == "layers" then
		return string.format("%d pancakes", math.floor(value + 0.5))
	elseif u.display == "radius" then
		return string.format("%.2f stud pan", value)
	end
	return tostring(value)
end

return function(C, Kit, Theme, _Root)
	local p = Kit.panel("Upgrades", Theme.Colors.butter, Vector2.new(820, 540))
	local list = Kit.scroll(p.body)
	Kit.list(list, 10)
	Kit.padding(6).Parent = list
	local rows: { [string]: { level: TextLabel, effect: TextLabel, buy: TextButton, lastLevel: number } } = {}
	local first: TextButton? = nil

	for i, u in Upgrades.List do
		local card = Kit.card({ LayoutOrder = i, Size = UDim2.new(1, -16, 0, 104), Parent = list })
		local badge = Kit.badge(u.glyph or "✨", Theme.Colors[COLORS[u.id] or "maple"], 76)
		badge.Position = UDim2.fromOffset(14, 14)
		badge.Parent = card
		Kit.label({
			Text = u.name,
			Size = UDim2.new(0.45, 0, 0, 38),
			Position = UDim2.fromOffset(104, 10),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 32,
			Parent = card,
		})
		Kit.label({
			Text = u.description,
			Font = Theme.BodyFont,
			TextColor3 = Theme.Colors.muted,
			Size = UDim2.new(0.45, 0, 0, 24),
			Position = UDim2.fromOffset(104, 48),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 22,
			Parent = card,
		})
		local level = Kit.label({
			Text = "",
			TextColor3 = Theme.Colors.berry,
			Size = UDim2.new(0.3, 0, 0, 24),
			Position = UDim2.fromOffset(104, 74),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 22,
			Parent = card,
		})
		local effect = Kit.label({
			Text = "",
			TextColor3 = Theme.Colors.aurora,
			Size = UDim2.new(0.25, 0, 0, 30),
			Position = UDim2.new(0.5, 0, 0, 36),
			MaxTextSize = 26,
			Parent = card,
		})
		local buy = Kit.button({
			text = "",
			color = Theme.Colors.pine,
			size = UDim2.fromOffset(200, 76),
			position = UDim2.new(1, -214, 0.5, -38),
			parent = card,
			sound = "Purchase",
			onClick = function()
				C.ClientNet:Fire("BuyUpgrade", u.id)
			end,
		})
		first = first or buy
		rows[u.id] = { level = level, effect = effect, buy = buy, lastLevel = -1 }
	end

	local function refresh()
		local data = C.State.data
		if not data.upgrades then
			return
		end
		for _, u in Upgrades.List do
			local row = rows[u.id]
			local lvl = data.upgrades[u.id] or 0
			if row.lastLevel >= 0 and lvl > row.lastLevel then
				C.Effects:Punch(0.15)
			end
			row.lastLevel = lvl
			local maxed = lvl >= u.maxLevel
			row.level.Text = string.format("Level %d / %d", lvl, u.maxLevel)
			local now = UpgradeMath.effect(u.id, lvl)
			if maxed then
				row.effect.Text = effectText(u, now)
				Kit.setButton(row.buy, "MAX", Theme.Colors.locked, false)
			else
				row.effect.Text = effectText(u, now) .. " → " .. effectText(u, UpgradeMath.effect(u.id, lvl + 1))
				local cost = UpgradeMath.cost(u.id, lvl)
				local can = (data.maple or 0) >= cost
				Kit.setButton(
					row.buy,
					"🍁 " .. Format.abbreviate(cost),
					if can then Theme.Colors.pine else Theme.Colors.locked,
					can
				)
			end
		end
	end

	return {
		root = p.root,
		scale = p.scale,
		refresh = function(keys)
			if keys.all or keys.maple or keys.upgrades then
				refresh()
			end
		end,
		firstSelectable = function()
			return first
		end,
	}
end
