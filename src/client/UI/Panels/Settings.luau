--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logic"):WaitForChild("Format"))

local OPTIONS = {
	{ key = "music", label = "🎵 Music" },
	{ key = "sfx", label = "🔊 Sound effects" },
	{ key = "performance", label = "🚀 Performance mode" },
	{ key = "autoEquip", label = "🐾 Auto-equip best Nibblers" },
	{ key = "autoServe", label = "🤖 Auto Serve (with pass)" },
}

return function(C, Kit, Theme, _Root)
	local p = Kit.panel("Settings", Theme.Colors.aurora, Vector2.new(760, 600))
	local holder = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 400), Parent = p.body })
	Kit.list(holder, 8)
	local toggles = {}
	local first: TextButton? = nil
	for i, opt in OPTIONS do
		local row = Kit.card({ LayoutOrder = i, Size = UDim2.new(1, -12, 0, 70), Parent = holder })
		Kit.label({
			Text = opt.label,
			Size = UDim2.new(0.6, 0, 1, -16),
			Position = UDim2.fromOffset(16, 8),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 28,
			Parent = row,
		})
		local b = Kit.button({
			text = "",
			size = UDim2.fromOffset(150, 56),
			position = UDim2.new(1, -164, 0.5, -28),
			parent = row,
			onClick = function()
				local s = C.State.data.settings or {}
				C.ClientNet:Fire("SetSetting", opt.key, not s[opt.key])
			end,
		})
		first = first or b
		toggles[opt.key] = b
	end
	local stats = Kit.label({
		Text = "",
		TextColor3 = Theme.Colors.muted,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 110),
		Position = UDim2.fromOffset(0, 404),
		MaxTextSize = 22,
		Parent = p.body,
	})

	local function refresh()
		local s = C.State.data.settings or {}
		for key, b in toggles do
			local on = s[key] == true
			Kit.setButton(b, if on then "ON" else "OFF", if on then Theme.Colors.pine else Theme.Colors.locked, true)
		end
		local st = C.State.data.stats or {}
		stats.Text = string.format(
			"Pancakes: %s   ·   Perfects: %s   ·   Best combo: %s   ·   Tallest: %s\nServes: %s   ·   Cravings: %s   ·   Topples: %s   ·   Eggs: %s   ·   Orders: %s\nYeti Feasts: %d   ·   Time played: %s",
			Format.abbreviate(st.pancakes or 0),
			Format.abbreviate(st.perfects or 0),
			Format.abbreviate(st.bestCombo or 0),
			Format.abbreviate(st.tallest or 0),
			Format.abbreviate(st.serves or 0),
			Format.abbreviate(st.cravings or 0),
			Format.abbreviate(st.topples or 0),
			Format.abbreviate(st.hatches or 0),
			Format.abbreviate(st.orders or 0),
			C.State.data.rebirths or 0,
			Format.clock(st.playSeconds or 0)
		)
	end

	return {
		root = p.root,
		scale = p.scale,
		refresh = function(keys)
			if keys.all or keys.settings or keys.stats then
				refresh()
			end
		end,
		firstSelectable = function()
			return first
		end,
	}
end
