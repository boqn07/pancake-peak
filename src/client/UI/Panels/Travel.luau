--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Zones = require(Shared:WaitForChild("Config"):WaitForChild("Zones"))
local Eggs = require(Shared.Config:WaitForChild("Eggs"))
local Format = require(Shared:WaitForChild("Logic"):WaitForChild("Format"))

return function(C, Kit, Theme, Root)
	local p = Kit.panel("Travel", Theme.Colors.ice, Vector2.new(860, 560))
	local PAD, GAP, PLAZA_HEIGHT, ROW_HEIGHT = 6, 10, 84, 104
	local list = Kit.scroll(p.body)
	Kit.list(list, GAP)
	Kit.padding(PAD).Parent = list
	local rows = {}
	local first: TextButton? = nil

	local plaza = Kit.card({ LayoutOrder = 0, Size = UDim2.new(1, -16, 0, PLAZA_HEIGHT), Parent = list })
	Kit.label({
		Text = "🏕️ Base Camp",
		Size = UDim2.new(0.6, 0, 0, 40),
		Position = UDim2.fromOffset(18, 8),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 30,
		Parent = plaza,
	})
	Kit.label({
		Text = "The hub: leaderboards, the cabin plaza and every mountain trail",
		Font = Theme.BodyFont,
		TextColor3 = Theme.Colors.muted,
		Size = UDim2.new(0.6, 0, 0, 26),
		Position = UDim2.fromOffset(18, 48),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 22,
		Parent = plaza,
	})
	first = Kit.button({
		text = "Go",
		color = Theme.Colors.ice,
		size = UDim2.fromOffset(180, 64),
		position = UDim2.new(1, -194, 0.5, -32),
		parent = plaza,
		onClick = function()
			C.ClientNet:Fire("Teleport", "BaseCamp")
			Root:Close()
		end,
	})

	for i, z in Zones.List do
		local accent = Color3.fromHex(z.accent)
		local card = Kit.card({ LayoutOrder = i, Size = UDim2.new(1, -16, 0, ROW_HEIGHT), Parent = list })
		Kit.new("Frame", {
			BackgroundColor3 = accent,
			Size = UDim2.new(0, 12, 1, -20),
			Position = UDim2.fromOffset(10, 10),
			Parent = card,
		}, { Kit.corner(UDim.new(0.5, 0)) })
		Kit.label({
			Text = z.name,
			TextColor3 = accent,
			Size = UDim2.new(0.55, 0, 0, 40),
			Position = UDim2.fromOffset(34, 8),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 32,
			Parent = card,
		})
		Kit.label({
			Text = z.tagline,
			Font = Theme.BodyFont,
			TextColor3 = Theme.Colors.muted,
			Size = UDim2.new(0.55, 0, 0, 24),
			Position = UDim2.fromOffset(34, 48),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 22,
			Parent = card,
		})
		Kit.label({
			Text = string.format(
				"🥞 x%s Maple per pancake  ·  %s",
				Format.abbreviate(z.value),
				Eggs.ById[z.egg].name
			),
			TextColor3 = Theme.Colors.berry,
			Size = UDim2.new(0.55, 0, 0, 22),
			Position = UDim2.fromOffset(34, 74),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 20,
			Parent = card,
		})
		local action = Kit.button({
			text = "",
			color = Theme.Colors.ice,
			size = UDim2.fromOffset(220, 72),
			position = UDim2.new(1, -234, 0.5, -36),
			parent = card,
			onClick = function()
				local data = C.State.data
				if data.zones and data.zones[z.id] then
					C.ClientNet:Fire("Teleport", z.id)
					Root:Close()
				else
					C.ClientNet:Fire("BuyZone", z.id)
				end
			end,
		})
		rows[z.id] = { card = card, button = action, index = i }
	end

	local function refresh()
		local data = C.State.data
		if not data.zones then
			return
		end
		for i, z in Zones.List do
			local row = rows[z.id]
			local owned = data.zones[z.id] == true
			local prevOwned = i == 1 or data.zones[Zones.List[i - 1].id] == true
			if owned then
				Kit.setButton(row.button, "Go", Theme.Colors.ice, true)
			elseif prevOwned then
				local can = (data.maple or 0) >= z.unlockCost
				Kit.setButton(
					row.button,
					"🔓 🍁 " .. Format.abbreviate(z.unlockCost),
					if can then Theme.Colors.pine else Theme.Colors.locked,
					can
				)
			else
				Kit.setButton(row.button, "🔒 Locked", Theme.Colors.locked, false)
			end
		end
	end

	return {
		root = p.root,
		scale = p.scale,
		onOpen = function(args)
			if args and args.focus and rows[args.focus] then
				local card = rows[args.focus].card
				local s = Kit.new("UIScale", { Scale = 1.08, Parent = card })
				Kit.springScale(s, 1, 10, 0.3)
				task.delay(1, function()
					s:Destroy()
				end)
				-- Rows have fixed heights, so the scroll offset is known without waiting for layout.
				local top = PAD + PLAZA_HEIGHT + GAP + (rows[args.focus].index - 1) * (ROW_HEIGHT + GAP)
				list.CanvasPosition = Vector2.new(0, math.max(0, top - 20))
			end
		end,
		refresh = function(keys)
			if keys.all or keys.maple or keys.zones then
				refresh()
			end
		end,
		firstSelectable = function()
			return first
		end,
	}
end
