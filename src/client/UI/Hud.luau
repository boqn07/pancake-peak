--!strict
-- Always-on HUD: Maple counter and multiplier, boost / Snow Day / Great Yeti's Order chips, the menu
-- columns, the big FLIP button with the tower meter, the SERVE button with the Yeti's craving and
-- what your tower is worth, and the zone banner.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Logic"):WaitForChild("Format"))
local Daily = require(Shared.Logic:WaitForChild("Daily"))
local Rewards = require(Shared:WaitForChild("Config"):WaitForChild("Rewards"))
local Zones = require(Shared.Config:WaitForChild("Zones"))
local OrderCfg = require(Shared.Config:WaitForChild("Order"))

local RewardText = require(script.Parent:WaitForChild("RewardText"))

local Hud = {}

local C: any, Kit: any, Theme: any, Root: any
local mapleLabel: TextLabel
local multLabel: TextLabel
local pillScale: UIScale
local chipRow: Frame
local banner: Frame
local bannerTitle: TextLabel
local bannerSub: TextLabel
local flipButton: TextButton
local flipScale: UIScale
local serveButton: TextButton
local serveScale: UIScale
local aimLabel: TextLabel
local valueLabel: TextLabel
local meterLabel: TextLabel
local setMeter: (number) -> ()
local buttons: { [string]: TextButton } = {}
local shownMaple = 0
local targetMaple = 0
local sessionStart = os.clock()
local claimedGifts: { [number]: boolean } = {}

Hud.Buttons = buttons

local function chip(text: string, color: Color3): Frame
	local f = Kit.new("Frame", {
		Size = UDim2.fromOffset(210, 40),
		BackgroundColor3 = color,
	}, { Kit.corner(UDim.new(0, 14)), Kit.stroke(Theme.Colors.ink, 3) })
	Kit.label({
		Text = text,
		TextColor3 = Theme.Colors.white,
		TextStrokeColor3 = Theme.Colors.ink,
		TextStrokeTransparency = 0,
		Size = UDim2.new(1, -16, 1, -10),
		Position = UDim2.fromOffset(8, 5),
		MaxTextSize = 22,
		Parent = f,
	})
	return f
end

local function refreshChips()
	for _, ch in chipRow:GetChildren() do
		if ch:IsA("Frame") then
			ch:Destroy()
		end
	end
	local boosts = C.State.data.boosts or {}
	for id, seconds in boosts do
		if seconds > 0 then
			chip(
				RewardText.boostGlyph(id) .. " " .. RewardText.boostName(id) .. " " .. Format.clock(seconds),
				Theme.Colors.aurora
			).Parent =
				chipRow
		end
	end
	local now = workspace:GetServerTimeNow()
	local order = C.State.order
	if C.State:SnowDay() then
		chip(
			string.format("❄️ Snow Day x%d  %s", OrderCfg.SnowMult, Format.clock(order.snowEndsAt - now)),
			Theme.Colors.ice
		).Parent =
			chipRow
	end
	if order.active then
		local zone = Zones.ById[order.zone]
		chip(
			string.format("👹 Great Yeti: %s  %s", if zone then zone.name else "?", Format.clock(order.endsAt - now)),
			Theme.Colors.berry
		).Parent =
			chipRow
	end
end

local function refreshDots()
	local data = C.State.data
	if data.daily then
		local can = Daily.status(data.daily, workspace:GetServerTimeNow(), #Rewards.Daily)
		local dot = buttons.Daily and buttons.Daily:FindFirstChild("Dot")
		if dot then
			(dot :: Frame).Visible = can
		end
	end
	local elapsed = (os.clock() - sessionStart) / 60
	local giftReady = false
	for i, gift in Rewards.Playtime do
		if not claimedGifts[i] and elapsed >= gift.unlockAt then
			giftReady = true
		end
	end
	local gdot = buttons.Gifts and buttons.Gifts:FindFirstChild("Dot")
	if gdot then
		(gdot :: Frame).Visible = giftReady
	end
end

function Hud.SessionElapsed(): number
	return os.clock() - sessionStart
end

function Hud.GiftClaimed(i: number): boolean
	return claimedGifts[i] == true
end

-- A gingham banner dropping in at the top ("FROSTY FALLS · icefalls and blueberry stacks").
function Hud.Banner(title: string, sub: string, color: Color3)
	bannerTitle.Text = title
	bannerSub.Text = sub
	banner.BackgroundColor3 = color
	banner.Visible = true
	banner.Position = UDim2.new(0.5, 0, 0, -140)
	TweenService:Create(banner, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 150),
	}):Play()
	local token = os.clock()
	banner:SetAttribute("Token", token)
	task.delay(2.6, function()
		if banner:GetAttribute("Token") == token then
			TweenService:Create(banner, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0.5, 0, 0, -140),
			}):Play()
		end
	end)
end

-- A big round enamel action button with a caption and a key hint.
local function actionButton(
	parent: Instance,
	name: string,
	text: string,
	color: Color3,
	size: number,
	hint: string
): (TextButton, UIScale)
	local b = Kit.new("TextButton", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		AutoButtonColor = false,
		Text = "",
		Selectable = true,
		Parent = parent,
	}, {
		Kit.corner(UDim.new(0.5, 0)),
		Kit.stroke(Theme.Colors.ink, 6),
		Kit.gradient(Color3.new(1, 1, 1), Color3.fromRGB(222, 205, 185)),
	})
	local scale = Kit.new("UIScale", { Parent = b })
	Kit.new("Frame", {
		Name = "Shine",
		Size = UDim2.fromScale(0.36, 0.2),
		Position = UDim2.fromScale(0.18, 0.12),
		Rotation = -25,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.35,
		Parent = b,
	}, { Kit.corner(UDim.new(0.5, 0)) })
	Kit.label({
		Text = text,
		Size = UDim2.fromScale(0.84, 0.36),
		Position = UDim2.fromScale(0.08, 0.3),
		TextColor3 = Theme.Colors.white,
		TextStrokeColor3 = Theme.Colors.ink,
		TextStrokeTransparency = 0,
		Rotation = -4,
		MaxTextSize = 56,
		Parent = b,
	})
	Kit.label({
		Name = "Key",
		Text = hint,
		Font = Theme.BodyFont,
		Size = UDim2.fromScale(0.6, 0.14),
		Position = UDim2.fromScale(0.2, 0.7),
		TextColor3 = Theme.Colors.ink,
		MaxTextSize = 18,
		Parent = b,
	})
	return b, scale
end

-- FLIP (big) and SERVE (smaller, above-left), the tower meter and the craving / value labels.
-- On touch screens they sit left of the mobile jump button.
local function buildActionButtons(hud: Frame)
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local pad = UserInputService.GamepadEnabled
	local holder = Kit.new("Frame", {
		Name = "Actions",
		AnchorPoint = Vector2.new(1, 1),
		Position = if touch then UDim2.new(1, -230, 1, -30) else UDim2.new(1, -40, 1, -30),
		Size = UDim2.fromOffset(330, 300),
		BackgroundTransparency = 1,
		Parent = hud,
	})
	aimLabel = Kit.label({
		Text = "",
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 0),
		TextColor3 = Theme.Colors.white,
		TextStrokeColor3 = Theme.Colors.ink,
		TextStrokeTransparency = 0,
		TextXAlignment = Enum.TextXAlignment.Right,
		MaxTextSize = 26,
		Parent = holder,
	})
	valueLabel = Kit.label({
		Text = "",
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(0, 30),
		TextColor3 = Theme.Colors.butter,
		TextStrokeColor3 = Theme.Colors.ink,
		TextStrokeTransparency = 0,
		TextXAlignment = Enum.TextXAlignment.Right,
		MaxTextSize = 24,
		Parent = holder,
	})
	flipButton, flipScale = actionButton(
		holder,
		"FlipButton",
		"FLIP!",
		Theme.Colors.maple,
		168,
		if touch then "" elseif pad then "E · R2" else "E · click"
	)
	flipButton.AnchorPoint = Vector2.new(1, 1)
	flipButton.Position = UDim2.fromScale(1, 1)
	serveButton, serveScale = actionButton(
		holder,
		"ServeButton",
		"SERVE",
		Theme.Colors.pine,
		112,
		if touch then "" elseif pad then "X" else "F"
	)
	serveButton.AnchorPoint = Vector2.new(1, 1)
	serveButton.Position = UDim2.new(1, -180, 1, -6)
	-- Tower meter: how full your tray is.
	local meter, set = Kit.bar(Theme.Colors.maple, UDim2.fromOffset(150, 26))
	meter.AnchorPoint = Vector2.new(1, 1)
	meter.Position = UDim2.new(1, -10, 1, -178)
	meter.Parent = holder
	setMeter = set
	meterLabel = Kit.label({
		Text = "0 / 15",
		Font = Theme.BodyFont,
		Size = UDim2.fromScale(1, 1),
		TextColor3 = Theme.Colors.ink,
		MaxTextSize = 18,
		Parent = meter,
	})
	meterLabel.ZIndex = 3
	flipButton.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			flipScale.Scale = 0.86
			Kit.springScale(flipScale, 1, 26, 0.4)
			C.StackInput:Flip()
		end
	end)
	-- Gamepad/keyboard selection activates it once.
	flipButton.Activated:Connect(function(_, count)
		if count == 1 and C.InputController:UsingGamepad() then
			C.StackInput:Flip()
		end
	end)
	serveButton.Activated:Connect(function()
		serveScale.Scale = 0.86
		Kit.springScale(serveScale, 1, 26, 0.4)
		C.StackInput:Serve()
	end)
	buttons.Flip = flipButton
	buttons.Serve = serveButton
end

local function refreshTower()
	local n = C.StackRenderer:MyCount()
	local max = C.State.derived.tray or 15
	meterLabel.Text = string.format("%d / %d", n, max)
	setMeter(n / math.max(max, 1))
	aimLabel.Text = C.StackInput:TargetText()
	valueLabel.Text = C.StackInput:ValueText()
	local canServe = C.StackInput:Target() ~= nil and n > 0
	serveButton.BackgroundTransparency = if canServe then 0 else 0.4
end

function Hud.Build(controllers, kit, theme, root, screen: Frame)
	C, Kit, Theme, Root = controllers, kit, theme, root
	local hud =
		Kit.new("Frame", { Name = "HUD", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = screen })

	-- Maple counter (top center): an enamel plaque with a maple-syrup coin.
	local pill = Kit.new("Frame", {
		Name = "Maple",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(360, 76),
		BackgroundColor3 = Theme.Colors.white,
		Parent = hud,
	}, {
		Kit.corner(UDim.new(0, 22)),
		Kit.stroke(Theme.Colors.ink, 4),
		Kit.gradient(Color3.new(1, 1, 1), Color3.fromRGB(246, 236, 218)),
	})
	pillScale = Kit.new("UIScale", { Parent = pill })
	local icon = Kit.mapleIcon(58)
	icon.Position = UDim2.fromOffset(12, 9)
	icon.Parent = pill
	mapleLabel = Kit.label({
		Text = "0",
		Size = UDim2.new(1, -90, 0, 46),
		Position = UDim2.fromOffset(80, 5),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 44,
		Parent = pill,
	})
	multLabel = Kit.label({
		Text = "x1",
		Font = Theme.BodyFont,
		TextColor3 = Theme.Colors.muted,
		Size = UDim2.new(1, -90, 0, 20),
		Position = UDim2.fromOffset(82, 50),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 18,
		Parent = pill,
	})

	chipRow = Kit.new("Frame", {
		Name = "Chips",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 92),
		Size = UDim2.fromOffset(860, 40),
		BackgroundTransparency = 1,
		Parent = hud,
	})
	Kit.list(chipRow, 8, true)

	-- Left menu column
	local left = Kit.new("Frame", {
		Name = "Left",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.45, 0),
		Size = UDim2.fromOffset(100, 600),
		BackgroundTransparency = 1,
		Parent = hud,
	})
	Kit.new("UIListLayout", {
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = left,
	})
	local leftDefs = {
		{ "Upgrades", "⚡", Theme.Colors.butter, "Upgrades" },
		{ "Nibblers", "🐾", Theme.Colors.pine, "Nibblers" },
		{ "Travel", "🏔️", Theme.Colors.ice, "Travel" },
		{ "Feast", "🥄", Theme.Colors.aurora, "Yeti Feast" },
		{ "Store", "🛒", Theme.Colors.berry, "Store" },
	}
	for i, def in leftDefs do
		local b, holder = Kit.roundButton(def[2], def[4], def[3], function()
			Root:Toggle(def[1])
		end)
		holder.LayoutOrder = i
		holder.Parent = left
		buttons[def[1]] = b
	end

	-- Right menu column (upper right, clear of the FLIP button)
	local right = Kit.new("Frame", {
		Name = "Right",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 90),
		Size = UDim2.fromOffset(100, 470),
		BackgroundTransparency = 1,
		Parent = hud,
	})
	Kit.new("UIListLayout", {
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = right,
	})
	local rightDefs = {
		{ "Daily", "📅", Theme.Colors.pine },
		{ "Gifts", "🎁", Theme.Colors.aurora },
		{ "Codes", "🎟️", Theme.Colors.ice },
		{ "Settings", "⚙️", Theme.Colors.locked },
	}
	for i, def in rightDefs do
		local b, holder = Kit.roundButton(def[2], def[1], def[3], function()
			Root:Toggle(def[1])
		end)
		holder.LayoutOrder = i
		holder.Parent = right
		buttons[def[1]] = b
	end

	buildActionButtons(hud)

	-- Zone banner.
	banner = Kit.new("Frame", {
		Name = "ZoneBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -140),
		Size = UDim2.fromOffset(540, 104),
		BackgroundColor3 = Theme.Colors.berry,
		Visible = false,
		Parent = hud,
	}, { Kit.corner(UDim.new(0, 22)), Kit.stroke(Theme.Colors.ink, 6) })
	bannerTitle = Kit.label({
		Text = "",
		Size = UDim2.new(1, -60, 0, 56),
		Position = UDim2.fromOffset(30, 6),
		TextColor3 = Theme.Colors.white,
		TextStrokeColor3 = Theme.Colors.ink,
		TextStrokeTransparency = 0,
		MaxTextSize = 52,
		Parent = banner,
	})
	bannerSub = Kit.label({
		Text = "",
		Font = Theme.BodyFont,
		Size = UDim2.new(1, -60, 0, 30),
		Position = UDim2.fromOffset(30, 64),
		TextColor3 = Theme.Colors.white,
		TextStrokeColor3 = Theme.Colors.ink,
		TextStrokeTransparency = 0.3,
		MaxTextSize = 24,
		Parent = banner,
	})

	-- State wiring
	C.State.Changed:Connect(function(keys)
		local data = C.State.data
		if keys.maple and data.maple then
			if data.maple > targetMaple and C.State.loaded then
				pillScale.Scale = 1.1
				Kit.springScale(pillScale, 1, 24, 0.4)
			end
			targetMaple = data.maple
		end
		if keys.derived then
			local d = C.State.derived
			if d.mult then
				multLabel.Text =
					string.format("%s Maple  ·  ≈%s/s", Format.mult(d.mult.total), Format.abbreviate(d.income or 0))
			end
			refreshTower()
		end
		if keys.boosts then
			refreshChips()
		end
		if keys.daily then
			refreshDots()
		end
	end)
	C.State.OrderChanged:Connect(refreshChips)
	C.ClientNet:On("Reward", function(r)
		if r.source == "Session" then
			sessionStart = os.clock()
			claimedGifts = {}
		elseif r.source == "PlaytimeClaimed" then
			claimedGifts[r.index] = true
			refreshDots()
		end
	end)
	C.WorldFX.ZoneChanged:Connect(function(id)
		local zone = Zones.ById[id]
		if zone and C.State:Owns(id) then
			Hud.Banner(zone.name, zone.tagline, Color3.fromHex(zone.accent))
		elseif id == "BaseCamp" then
			Hud.Banner("Base Camp", "Pick a trail and start flipping!", Theme.Colors.berry)
		end
	end)
	C.StackInput.TargetChanged:Connect(refreshTower)
	C.StackRenderer.HeightChanged:Connect(refreshTower)

	-- Count-up animation and the action buttons' idle bob.
	RunService.RenderStepped:Connect(function(dt)
		if shownMaple ~= targetMaple then
			local diff = targetMaple - shownMaple
			if math.abs(diff) < math.max(1, math.abs(targetMaple) * 1e-4) then
				shownMaple = targetMaple
			else
				shownMaple += diff * (1 - math.exp(-dt * 12))
			end
			mapleLabel.Text = Format.abbreviate(math.floor(shownMaple))
		end
		-- SERVE wiggles when you're at a Yeti with pancakes; FLIP wiggles while the tray is empty.
		local t = os.clock()
		local n = C.StackRenderer:MyCount()
		serveButton.Rotation = if n > 0 and C.StackInput:Target() then math.sin(t * 6) * 5 else 0
		flipButton.Rotation = if n == 0 then math.sin(t * 3) * 3 else 0
	end)
	-- Timers once a second.
	task.spawn(function()
		while true do
			task.wait(1)
			local boosts = C.State.data.boosts
			if boosts then
				for k, v in boosts do
					if v > 0 then
						boosts[k] = math.max(0, v - 1)
					end
				end
			end
			refreshChips()
			refreshDots()
			refreshTower()
		end
	end)
end

return Hud
