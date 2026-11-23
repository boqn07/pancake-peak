--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rewards = require(Shared:WaitForChild("Config"):WaitForChild("Rewards"))
local Daily = require(Shared:WaitForChild("Logic"):WaitForChild("Daily"))
local Format = require(Shared.Logic:WaitForChild("Format"))

local RewardText = require(script.Parent.Parent:WaitForChild("RewardText"))

return function(C, Kit, Theme, _Root)
	local p = Kit.panel("Daily Rewards", Theme.Colors.pine, Vector2.new(940, 500))
	local row = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 230), Parent = p.body })
	Kit.list(row, 10, true)
	local tiles = {}
	for i, reward in Rewards.Daily do
		local tile = Kit.card({ LayoutOrder = i, Size = UDim2.fromOffset(118, 220), Parent = row })
		Kit.label({
			Text = "Day " .. i,
			Size = UDim2.new(1, -8, 0, 30),
			Position = UDim2.fromOffset(4, 8),
			MaxTextSize = 24,
			Parent = tile,
		})
		local glyph = Kit.label({
			Text = "",
			Size = UDim2.new(1, -30, 0, 70),
			Position = UDim2.fromOffset(15, 44),
			MaxTextSize = 60,
			Parent = tile,
		})
		local desc = Kit.label({
			Text = "",
			TextColor3 = Theme.Colors.berry,
			TextWrapped = true,
			Size = UDim2.new(1, -10, 0, 60),
			Position = UDim2.fromOffset(5, 120),
			MaxTextSize = 20,
			Parent = tile,
		})
		local check = Kit.label({
			Text = "✔",
			TextColor3 = Theme.Colors.pine,
			Visible = false,
			Size = UDim2.new(1, 0, 0, 34),
			Position = UDim2.new(0, 0, 1, -40),
			MaxTextSize = 30,
			Parent = tile,
		})
		tiles[i] = { tile = tile, glyph = glyph, desc = desc, check = check, reward = reward }
	end
	local status = Kit.label({
		Text = "",
		TextColor3 = Theme.Colors.muted,
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.fromOffset(0, 244),
		MaxTextSize = 26,
		Parent = p.body,
	})
	local claim = Kit.button({
		text = "Claim",
		color = Theme.Colors.pine,
		size = UDim2.fromOffset(320, 84),
		position = UDim2.new(0.5, -160, 1, -96),
		parent = p.body,
		sound = "Purchase",
		onClick = function()
			C.ClientNet:Fire("ClaimDaily")
		end,
	})

	local function refresh()
		local data = C.State.data
		if not data.daily then
			return
		end
		local now = workspace:GetServerTimeNow()
		local can, day = Daily.status(data.daily, now, #Rewards.Daily)
		local claimedThrough = if can then day - 1 else day
		for i, t in tiles do
			local g, d = RewardText.describe(t.reward, C.State.derived.income)
			t.glyph.Text = g
			t.desc.Text = d
			t.check.Visible = i <= claimedThrough
			local isToday = can and i == day
			local stroke = t.tile:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = if isToday then Theme.Colors.berry else Theme.Colors.ink
				stroke.Thickness = if isToday then 4 else 2.5
			end
		end
		if can then
			status.Text = "Your Day " .. day .. " reward is ready!"
			Kit.setButton(claim, "Claim Day " .. day, Theme.Colors.pine, true)
		else
			status.Text = "Next reward in " .. Format.clock(Daily.secondsUntilReset(now)) .. " · keep your streak!"
			Kit.setButton(claim, "Claimed ✔", Theme.Colors.locked, false)
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
		refresh = function(keys)
			if keys.all or keys.daily or keys.derived then
				refresh()
			end
		end,
		firstSelectable = function()
			return claim
		end,
	}
end
