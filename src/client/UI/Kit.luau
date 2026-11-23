--!strict
-- UI building blocks: create(), chunky enamel buttons with spring press/hover, camp-mug panels
-- (cream enamel, ink-blue rim, speckles), red gingham headers, badges, bars.
-- All motion runs through one spring updater so every widget feels the same.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spring = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logic"):WaitForChild("Spring"))
local Theme = require(script.Parent:WaitForChild("Theme"))

local Kit = {}

local C: any -- controllers, set by UIRoot
function Kit.bind(controllers)
	C = controllers
end

-- Generic instance factory: Kit.new("Frame", { Size = ... }, { children })
function Kit.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			else
				(inst :: any)[k] = v
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Kit.corner(radius: UDim?): UICorner
	return Kit.new("UICorner", { CornerRadius = radius or Theme.Corner })
end

function Kit.stroke(color: Color3?, thickness: number?): UIStroke
	return Kit.new("UIStroke", {
		Color = color or Theme.Colors.ink,
		Thickness = thickness or Theme.StrokeThickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Kit.gradient(top: Color3, bottom: Color3): UIGradient
	return Kit.new("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = 90 })
end

function Kit.padding(px: number): UIPadding
	local u = UDim.new(0, px)
	return Kit.new("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function Kit.label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextColor3 = Theme.Colors.ink,
		TextScaled = true,
		Text = "",
	}
	for k, v in props do
		if k ~= "MaxTextSize" then
			defaults[k] = v
		end
	end
	local l = Kit.new("TextLabel", defaults)
	Kit.new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 40, Parent = l })
	return l
end

---------------------------------------------------------------------------------------------------
-- Springs
---------------------------------------------------------------------------------------------------
type Driven = { spring: any, apply: (number) -> () }
local driven: { [any]: Driven } = {}

RunService.RenderStepped:Connect(function(dt)
	for key, d in driven do
		local v = Spring.step(d.spring, dt)
		d.apply(v)
		if Spring.isResting(d.spring, 1e-3) then
			d.apply(d.spring.target)
			driven[key] = nil
		end
	end
end)

-- Animate a number on `key` toward `target` with a spring; `apply` receives each value.
function Kit.spring(key: any, from: number, target: number, apply: (number) -> (), speed: number?, damping: number?)
	local d = driven[key]
	if d then
		d.spring.target = target
		d.apply = apply
		return
	end
	local s = Spring.new(from, speed or 22, damping or 0.55)
	s.target = target
	driven[key] = { spring = s, apply = apply }
end

function Kit.springScale(scale: UIScale, target: number, speed: number?, damping: number?)
	Kit.spring(scale, scale.Scale, target, function(v)
		scale.Scale = v
	end, speed, damping)
end

---------------------------------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------------------------------
export type ButtonProps = {
	text: string?,
	color: Color3?,
	textColor: Color3?,
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	icon: string?, -- emoji/glyph shown left of the text
	onClick: (() -> ())?,
	layoutOrder: number?,
	parent: Instance?,
	sound: string?,
}

function Kit.button(p: ButtonProps): TextButton
	local color = p.color or Theme.Colors.butter
	local b = Kit.new("TextButton", {
		Size = p.size or UDim2.fromOffset(220, Theme.TouchTarget),
		Position = p.position,
		AnchorPoint = p.anchor or Vector2.zero,
		BackgroundColor3 = color,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = p.layoutOrder or 0,
		Selectable = true,
	}, {
		Kit.corner(UDim.new(0, 18)),
		Kit.stroke(Theme.Colors.ink, 4),
		Kit.gradient(Color3.new(1, 1, 1), Color3.fromRGB(222, 212, 196)),
	})
	local scale = Kit.new("UIScale", { Parent = b })
	-- Enamel shine across the top, and a chunky "lip" along the bottom.
	Kit.new("Frame", {
		Name = "Shine",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.6,
		Size = UDim2.new(1, -24, 0, 6),
		Position = UDim2.fromOffset(12, 6),
		Parent = b,
	}, { Kit.corner(UDim.new(0.5, 0)) })
	Kit.new("Frame", {
		Name = "Lip",
		BackgroundColor3 = Theme.Colors.ink,
		BackgroundTransparency = 0.8,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 8),
		Position = UDim2.new(0, 0, 1, -8),
		Parent = b,
	}, { Kit.corner(UDim.new(0, 18)) })
	local label = Kit.label({
		Name = "Label",
		Text = (if p.icon then p.icon .. "  " else "") .. (p.text or ""),
		TextColor3 = p.textColor or Theme.Colors.ink,
		Size = UDim2.new(1, -16, 1, -14),
		Position = UDim2.fromOffset(8, 7),
		MaxTextSize = 34,
		Parent = b,
	})
	label.ZIndex = 2
	b.MouseEnter:Connect(function()
		Kit.springScale(scale, 1.06)
		if C then
			C.Audio:Play("Hover")
		end
	end)
	b.MouseLeave:Connect(function()
		Kit.springScale(scale, 1)
	end)
	b.SelectionGained:Connect(function()
		Kit.springScale(scale, 1.06)
	end)
	b.SelectionLost:Connect(function()
		Kit.springScale(scale, 1)
	end)
	b.MouseButton1Down:Connect(function()
		Kit.springScale(scale, 0.9, 30, 0.5)
	end)
	b.MouseButton1Up:Connect(function()
		Kit.springScale(scale, 1.04)
	end)
	b.Activated:Connect(function()
		scale.Scale = 0.88
		Kit.springScale(scale, 1, 26, 0.45)
		if C then
			C.Audio:Play(p.sound or "Click")
		end
		if p.onClick then
			p.onClick()
		end
	end)
	if p.parent then
		b.Parent = p.parent
	end
	return b
end

function Kit.setButton(b: TextButton, text: string, color: Color3?, enabled: boolean?)
	local label = b:FindFirstChild("Label") :: TextLabel
	label.Text = text
	if color then
		b.BackgroundColor3 = color
	end
	if enabled ~= nil then
		b.AutoButtonColor = false
		b.BackgroundTransparency = if enabled then 0 else 0.35
		label.TextTransparency = if enabled then 0 else 0.35
	end
end

-- Round HUD button: big badge with an emoji glyph and a caption underneath.
function Kit.roundButton(glyph: string, caption: string, color: Color3, onClick: () -> ()): (TextButton, Frame)
	local holder = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(96, 112) })
	local b = Kit.new("TextButton", {
		Size = UDim2.fromOffset(Theme.TouchTarget, Theme.TouchTarget),
		Position = UDim2.fromScale(0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = color,
		AutoButtonColor = false,
		Text = "",
		Selectable = true,
		Parent = holder,
	}, {
		Kit.corner(UDim.new(0.5, 0)),
		Kit.stroke(Theme.Colors.ink, 4),
		Kit.gradient(Color3.new(1, 1, 1), Color3.fromRGB(222, 212, 196)),
	})
	local scale = Kit.new("UIScale", { Parent = b })
	Kit.label({
		Text = glyph,
		Size = UDim2.fromScale(0.62, 0.62),
		Position = UDim2.fromScale(0.19, 0.17),
		MaxTextSize = 48,
		Parent = b,
	})
	Kit.label({
		Name = "Caption",
		Text = caption,
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.fromOffset(0, Theme.TouchTarget + 2),
		TextColor3 = Theme.Colors.white,
		TextStrokeColor3 = Theme.Colors.ink,
		TextStrokeTransparency = 0,
		MaxTextSize = 22,
		Parent = holder,
	})
	local dot = Kit.new("Frame", {
		Name = "Dot",
		Visible = false,
		Size = UDim2.fromOffset(24, 24),
		Position = UDim2.new(1, -20, 0, -4),
		BackgroundColor3 = Theme.Colors.berry,
		Parent = b,
	}, { Kit.corner(UDim.new(0.5, 0)), Kit.stroke() })
	dot.ZIndex = 3
	b.MouseEnter:Connect(function()
		Kit.springScale(scale, 1.1)
	end)
	b.MouseLeave:Connect(function()
		Kit.springScale(scale, 1)
	end)
	b.SelectionGained:Connect(function()
		Kit.springScale(scale, 1.1)
	end)
	b.SelectionLost:Connect(function()
		Kit.springScale(scale, 1)
	end)
	b.Activated:Connect(function()
		scale.Scale = 0.85
		Kit.springScale(scale, 1, 26, 0.4)
		if C then
			C.Audio:Play("Click")
		end
		onClick()
	end)
	return b, holder
end

-- A horizontal progress bar. Returns the frame and a setter (0..1, animated).
function Kit.bar(color: Color3, size: UDim2, parent: Instance?): (Frame, (number) -> ())
	local back = Kit.new("Frame", {
		Size = size,
		BackgroundColor3 = Theme.Colors.paperDark,
		Parent = parent,
	}, { Kit.corner(UDim.new(0.5, 0)), Kit.stroke() })
	local fill = Kit.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = color,
		Parent = back,
	}, { Kit.corner(UDim.new(0.5, 0)), Kit.gradient(Color3.new(1, 1, 1), Color3.fromRGB(222, 212, 196)) })
	local current = 0
	return back,
		function(v: number)
			v = math.clamp(v, 0, 1)
			Kit.spring(fill, current, v, function(x)
				current = x
				fill.Size = UDim2.fromScale(math.clamp(x, 0, 1), 1)
			end, 18, 0.9)
		end
end

-- A red-gingham picnic-cloth banner (panel headers, banners): a woven check of see-through white
-- bands over the accent color, with an ink rim.
function Kit.gingham(color: Color3, size: UDim2): Frame
	local f = Kit.new("Frame", {
		Name = "Gingham",
		Size = size,
		BackgroundColor3 = color,
	}, { Kit.corner(UDim.new(0, 16)), Kit.stroke(Theme.Colors.ink, 4) })
	local weave = Kit.new("Frame", {
		Name = "Weave",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = f,
	}, { Kit.corner(UDim.new(0, 16)) })
	for i = 0, 9 do
		Kit.new("Frame", {
			Size = UDim2.fromScale(0.05, 1),
			Position = UDim2.fromScale(0.025 + i * 0.1, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.6,
			BorderSizePixel = 0,
			Parent = weave,
		})
	end
	for i = 0, 1 do
		Kit.new("Frame", {
			Size = UDim2.fromScale(1, 0.22),
			Position = UDim2.fromScale(0, 0.14 + i * 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.6,
			BorderSizePixel = 0,
			Parent = weave,
		})
	end
	return f
end

-- Little dark enamel chips scattered on a panel, like a well-loved camp mug.
local function speckle(parent: Instance, seed: number)
	local rng = Random.new(seed)
	for _ = 1, 14 do
		local d = rng:NextInteger(3, 6)
		Kit.new("Frame", {
			Size = UDim2.fromOffset(d, d),
			Position = UDim2.fromScale(rng:NextNumber(0.04, 0.96), rng:NextNumber(0.1, 0.95)),
			BackgroundColor3 = Theme.Colors.ink,
			BackgroundTransparency = rng:NextNumber(0.7, 0.85),
			BorderSizePixel = 0,
			ZIndex = 0,
			Parent = parent,
		}, { Kit.corner(UDim.new(0.5, 0)) })
	end
end

-- A titled modal panel. Returns { root, body, title } — root is hidden until opened by UIRoot.
function Kit.panel(
	title: string,
	accent: Color3,
	size: Vector2?
): { root: Frame, body: Frame, title: TextLabel, scale: UIScale }
	local s = size or Vector2.new(820, 520)
	-- The root is an invisible container so the shadow can sit behind the paper as a sibling.
	local root = Kit.new("Frame", {
		Name = title,
		Size = UDim2.fromOffset(s.X, s.Y),
		Position = UDim2.fromScale(0.5, 0.52),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = false,
	})
	Kit.new("Frame", {
		Name = "Shadow",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, 12),
		BackgroundColor3 = Theme.Colors.ink,
		BackgroundTransparency = 0.5,
		ZIndex = 0,
		Parent = root,
	}, { Kit.corner(UDim.new(0, 26)) })
	local paper = Kit.new("Frame", {
		Name = "Paper",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.paper,
		ZIndex = 0,
		Parent = root,
	}, {
		Kit.corner(UDim.new(0, 30)),
		Kit.stroke(Theme.Colors.ink, Theme.StickerBorder),
		Kit.gradient(Color3.new(1, 1, 1), Color3.fromRGB(246, 236, 218)),
	})
	-- Enamel look: a thin inner rim line, a soft shine stripe and a few chipped speckles.
	Kit.new("Frame", {
		Name = "InnerRim",
		Size = UDim2.new(1, -18, 1, -18),
		Position = UDim2.fromOffset(9, 9),
		BackgroundTransparency = 1,
		Parent = paper,
	}, { Kit.corner(UDim.new(0, 24)), Kit.stroke(Theme.Colors.paperDark, 2) })
	Kit.new("Frame", {
		Name = "Gloss",
		Size = UDim2.new(1, -60, 0, 8),
		Position = UDim2.fromOffset(30, 16),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.3,
		Parent = paper,
	}, { Kit.corner(UDim.new(0.5, 0)) })
	speckle(paper, #title * 7919)
	local scale = Kit.new("UIScale", { Parent = root })
	-- Header: a gingham banner in the panel's accent color, sitting on the top rim.
	local header = Kit.gingham(accent, UDim2.new(0.56, 0, 0, 62))
	header.Name = "Header"
	header.Position = UDim2.new(0.5, 0, 0, -28)
	header.AnchorPoint = Vector2.new(0.5, 0)
	header.Parent = root
	local titleLabel = Kit.label({
		Text = title,
		TextColor3 = Theme.Colors.white,
		TextStrokeColor3 = Theme.Colors.ink,
		TextStrokeTransparency = 0,
		Size = UDim2.new(1, -24, 1, -12),
		Position = UDim2.fromOffset(12, 6),
		MaxTextSize = 40,
		Parent = header,
	})
	titleLabel.ZIndex = 3
	local body = Kit.new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -40, 1, -70),
		Position = UDim2.fromOffset(20, 50),
		Parent = root,
	})
	return { root = root, body = body, title = titleLabel, scale = scale }
end

-- Scrolling list area with automatic canvas size.
function Kit.scroll(parent: Instance, props: { [string]: any }?): ScrollingFrame
	local defaults = {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Theme.Colors.berry,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		BorderSizePixel = 0,
		Parent = parent,
	}
	if props then
		for k, v in props do
			defaults[k] = v
		end
	end
	return Kit.new("ScrollingFrame", defaults)
end

-- Rounded card used by list rows.
function Kit.card(props: { [string]: any }?): Frame
	local defaults = { BackgroundColor3 = Theme.Colors.white, Size = UDim2.new(1, -12, 0, 96) }
	if props then
		for k, v in props do
			defaults[k] = v
		end
	end
	return Kit.new("Frame", defaults, { Kit.corner(UDim.new(0, 18)), Kit.stroke(Theme.Colors.paperDark, 3) })
end

-- Glyph badge (emoji in a colored circle).
function Kit.badge(glyph: string, color: Color3, size: number): Frame
	local f = Kit.new("Frame", {
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
	}, { Kit.corner(UDim.new(0.5, 0)), Kit.stroke() })
	Kit.label({ Text = glyph, Size = UDim2.fromScale(0.64, 0.64), Position = UDim2.fromScale(0.18, 0.18), Parent = f })
	return f
end

-- The Maple currency icon: a code-built maple-syrup coin (amber disc, ink rim, a five-point leaf
-- built from rotated rounded petals, a glossy shine).
function Kit.mapleIcon(size: number): Frame
	local coin = Kit.new("Frame", {
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Theme.Colors.maple,
	}, {
		Kit.corner(UDim.new(0.5, 0)),
		Kit.stroke(Theme.Colors.ink, 2),
		Kit.gradient(Color3.fromRGB(255, 220, 150), Color3.fromRGB(226, 140, 40)),
	})
	for i = -2, 2 do
		Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Size = UDim2.fromScale(0.2, 0.36),
			Position = UDim2.fromScale(0.5, 0.6),
			Rotation = i * 45,
			BackgroundColor3 = Theme.Colors.berry,
			BorderSizePixel = 0,
			Parent = coin,
		}, { Kit.corner(UDim.new(0.5, 0)) })
	end
	Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromScale(0.07, 0.24),
		Position = UDim2.fromScale(0.5, 0.56),
		BackgroundColor3 = Theme.Colors.berry,
		BorderSizePixel = 0,
		Parent = coin,
	})
	Kit.new("Frame", {
		Size = UDim2.fromScale(0.22, 0.12),
		Position = UDim2.fromScale(0.22, 0.14),
		Rotation = -30,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Parent = coin,
	}, { Kit.corner(UDim.new(0.5, 0)) })
	return coin
end

function Kit.list(parent: Instance, padding: number, horizontal: boolean?): UIListLayout
	return Kit.new("UIListLayout", {
		Padding = UDim.new(0, padding),
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = parent,
	})
end

return Kit
