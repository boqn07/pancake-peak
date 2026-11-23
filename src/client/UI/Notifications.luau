--!strict
-- Toasts (personal) and announcement banners (server-wide). Both animate in and out.
local TweenService = game:GetService("TweenService")

local Notifications = {}

local Kit: any, Theme: any, C: any
local toastHolder: Frame
local bannerHolder: Frame
local MAX_TOASTS = 4

local STYLE_COLORS: { [string]: string } = {
	info = "ice",
	success = "pine",
	error = "berry",
	unlock = "maple",
	rebirth = "aurora",
	full = "berry",
}

local ANNOUNCE_COLORS: { [string]: Color3 } = {}

function Notifications.Init(controllers, kit, theme, screen: Frame)
	C, Kit, Theme = controllers, kit, theme
	toastHolder = Kit.new("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 120),
		Size = UDim2.fromOffset(420, 400),
		Parent = screen,
	})
	Kit.new("UIListLayout", {
		Padding = UDim.new(0, 8),
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = toastHolder,
	})
	bannerHolder = Kit.new("Frame", {
		Name = "Banners",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 150),
		Size = UDim2.fromOffset(720, 140),
		Parent = screen,
	})
	Kit.new("UIListLayout", {
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = bannerHolder,
	})
	ANNOUNCE_COLORS = {
		legendary = Theme.Rarity.Legendary,
		mythic = Theme.Rarity.Mythic,
		shiny = Theme.Colors.aurora,
		tower = Theme.Colors.maple,
		order = Theme.Colors.berry,
		zone = Theme.Colors.ice,
		rebirth = Theme.Colors.navy,
		info = Theme.Colors.navy,
	}
end

local order = 0

function Notifications.Toast(text: string, style: string?)
	local colorKey = STYLE_COLORS[style or "info"] or "sky"
	local color = Theme.Colors[colorKey]
	order += 1
	local toasts = {}
	for _, ch in toastHolder:GetChildren() do
		if ch:IsA("Frame") then
			table.insert(toasts, ch)
		end
	end
	if #toasts >= MAX_TOASTS then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		toasts[1]:Destroy()
	end
	local f = Kit.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(420, 58),
		BackgroundColor3 = Theme.Colors.white,
		Rotation = (order % 3 - 1) * 1.2,
		Parent = toastHolder,
	}, { Kit.corner(UDim.new(0, 16)), Kit.stroke(Theme.Colors.ink, 3) })
	-- A colored tab on the left edge says what kind of message it is.
	Kit.new("Frame", {
		Size = UDim2.new(0, 14, 1, -12),
		Position = UDim2.fromOffset(6, 6),
		BackgroundColor3 = color,
		Parent = f,
	}, { Kit.corner(UDim.new(0.5, 0)) })
	Kit.label({
		Text = text,
		Font = Theme.BodyFont,
		Size = UDim2.new(1, -40, 1, -14),
		Position = UDim2.fromOffset(28, 7),
		MaxTextSize = 26,
		Parent = f,
	})
	local scale = Kit.new("UIScale", { Scale = 0.3, Parent = f })
	Kit.springScale(scale, 1)
	if style == "error" then
		C.Audio:Play("Error")
	end
	task.delay(3.2, function()
		if f.Parent then
			Kit.springScale(scale, 0, 30, 1)
			task.delay(0.25, function()
				f:Destroy()
			end)
		end
	end)
end

function Notifications.Banner(text: string, style: string?)
	local color = ANNOUNCE_COLORS[style or ""] or Theme.Colors.butter
	order += 1
	local kids = bannerHolder:GetChildren()
	if #kids > 3 then
		for _, k in kids do
			if k:IsA("Frame") then
				k:Destroy()
				break
			end
		end
	end
	local f = Kit.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(720, 46),
		BackgroundColor3 = color,
		Parent = bannerHolder,
	}, { Kit.corner(UDim.new(0, 18)), Kit.stroke(Theme.Colors.ink, 4) })
	local label = Kit.label({
		Text = text,
		TextColor3 = Theme.Colors.white,
		TextStrokeColor3 = Theme.Colors.ink,
		TextStrokeTransparency = 0,
		Size = UDim2.new(1, -30, 1, -10),
		Position = UDim2.fromOffset(15, 5),
		MaxTextSize = 26,
		Parent = f,
	})
	if style == "shiny" then
		local g = {}
		for i, c in Theme.ShinyGradient do
			table.insert(g, ColorSequenceKeypoint.new((i - 1) / (#Theme.ShinyGradient - 1), c))
		end
		Kit.new("UIGradient", { Color = ColorSequence.new(g), Parent = f })
		f.BackgroundColor3 = Color3.new(1, 1, 1)
	end
	f.Position = UDim2.fromOffset(0, -20)
	label.TextTransparency = 1
	TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
	task.delay(4.5, function()
		if f.Parent then
			TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			TweenService:Create(f, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			task.delay(0.45, function()
				f:Destroy()
			end)
		end
	end)
end

return Notifications
