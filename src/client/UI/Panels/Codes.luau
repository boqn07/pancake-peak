--!strict
return function(C, Kit, Theme, _Root)
	local p = Kit.panel("Codes", Theme.Colors.ice, Vector2.new(640, 400))
	Kit.label({
		Text = "Got a code? Type it here!",
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 10),
		MaxTextSize = 30,
		Parent = p.body,
	})
	local box = Kit.new("TextBox", {
		Size = UDim2.new(1, -40, 0, 74),
		Position = UDim2.fromOffset(20, 70),
		BackgroundColor3 = Theme.Colors.paperDark,
		PlaceholderText = "ENTER CODE",
		PlaceholderColor3 = Theme.Colors.muted,
		Text = "",
		TextColor3 = Theme.Colors.ink,
		Font = Theme.Font,
		TextSize = 34,
		ClearTextOnFocus = false,
		Parent = p.body,
	}, { Kit.corner(UDim.new(0, 18)), Kit.stroke(Theme.Colors.ice, 3) })
	local feedback = Kit.label({
		Text = "",
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.fromOffset(0, 154),
		MaxTextSize = 26,
		Parent = p.body,
	})
	local redeem = Kit.button({
		text = "Redeem",
		color = Theme.Colors.ice,
		size = UDim2.fromOffset(280, 80),
		position = UDim2.new(0.5, -140, 1, -92),
		parent = p.body,
		onClick = function()
			local text = box.Text
			if #text == 0 or #text > 24 then
				feedback.Text = "Type a code first"
				feedback.TextColor3 = Theme.Colors.berry
				return
			end
			C.ClientNet:Fire("RedeemCode", text)
		end,
	})
	return {
		root = p.root,
		scale = p.scale,
		onOpen = function()
			feedback.Text = "Codes are shared on our group and socials."
			feedback.TextColor3 = Theme.Colors.muted
		end,
		onReward = function(r)
			if r.source == "Code" then
				feedback.Text = "Redeemed! Enjoy ✨"
				feedback.TextColor3 = Theme.Colors.pine
				box.Text = ""
			elseif r.source == "CodeFailed" then
				feedback.Text = r.message or "Invalid code"
				feedback.TextColor3 = Theme.Colors.berry
			end
		end,
		firstSelectable = function()
			return redeem
		end,
	}
end
