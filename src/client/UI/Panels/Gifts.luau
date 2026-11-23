--!strict
-- Playtime gifts for this session.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rewards = require(Shared:WaitForChild("Config"):WaitForChild("Rewards"))
local Format = require(Shared:WaitForChild("Logic"):WaitForChild("Format"))

local RewardText = require(script.Parent.Parent:WaitForChild("RewardText"))

return function(C, Kit, Theme, Root)
	local p = Kit.panel("Gifts", Theme.Colors.aurora, Vector2.new(940, 470))
	local row = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -10), Parent = p.body })
	Kit.list(row, 10, true)
	local tiles = {}
	local first: TextButton? = nil
	for i, gift in Rewards.Playtime do
		local tile = Kit.card({ LayoutOrder = i, Size = UDim2.fromOffset(118, 360), Parent = row })
		local glyph = Kit.label({
			Text = "🎁",
			Size = UDim2.new(1, -30, 0, 70),
			Position = UDim2.fromOffset(15, 14),
			MaxTextSize = 60,
			Parent = tile,
		})
		local desc = Kit.label({
			Text = "",
			TextColor3 = Theme.Colors.berry,
			TextWrapped = true,
			Size = UDim2.new(1, -10, 0, 80),
			Position = UDim2.fromOffset(5, 94),
			MaxTextSize = 20,
			Parent = tile,
		})
		local b = Kit.button({
			text = "",
			color = Theme.Colors.aurora,
			size = UDim2.new(1, -12, 0, 70),
			position = UDim2.new(0, 6, 1, -80),
			parent = tile,
			sound = "Purchase",
			onClick = function()
				C.ClientNet:Fire("ClaimPlaytime", i)
			end,
		})
		first = first or b
		tiles[i] = { glyph = glyph, desc = desc, button = b, gift = gift }
	end

	local function refresh()
		local elapsed = Root.Hud.SessionElapsed()
		for i, t in tiles do
			local g, d = RewardText.describe(t.gift.reward, C.State.derived.income)
			t.glyph.Text = g
			t.desc.Text = d
			local claimed = Root.Hud.GiftClaimed(i)
			local remaining = t.gift.unlockAt * 60 - elapsed
			if claimed then
				Kit.setButton(t.button, "✔", Theme.Colors.locked, false)
			elseif remaining <= 0 then
				Kit.setButton(t.button, "Claim", Theme.Colors.pine, true)
			else
				Kit.setButton(t.button, Format.clock(remaining), Theme.Colors.locked, false)
			end
		end
	end

	local open = false
	task.spawn(function()
		while true do
			task.wait(1)
			if open then
				refresh()
			end
		end
	end)

	return {
		root = p.root,
		scale = p.scale,
		onOpen = function()
			open = true
		end,
		onClose = function()
			open = false
		end,
		refresh = function()
			refresh()
		end,
		onReward = function(r)
			if r.source == "PlaytimeClaimed" and open then
				refresh()
			end
		end,
		firstSelectable = function()
			return first
		end,
	}
end
