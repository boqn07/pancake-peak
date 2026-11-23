--!strict
-- Draws the Great Yeti's Order: a huge Yeti stomps down into a zone's plaza (screen shake for anyone
-- nearby), chomps every time the order fills, shows an "order" bar with the time left, and either
-- jumps for joy (Snow Day!) or shuffles off sadly when time runs out. All numbers come from the
-- server (State.order); only the animation is local.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Zones = require(Shared:WaitForChild("Config"):WaitForChild("Zones"))
local YetiModel = require(Shared:WaitForChild("Util"):WaitForChild("YetiModel"))

local OrderRenderer = {}

local C: any
local hex = Color3.fromHex
local WHITE = hex("#FFFFFF")
local INK = hex("#24406B")
local SCALE = 2.2

local yeti: Model? = nil
local mouth: BasePart? = nil
local fill: Frame? = nil
local label: TextLabel? = nil
local shownFor: string? = nil -- zone id of the Yeti currently drawn
local base = CFrame.identity
local dropT = 1
local chomp = 0
local lastFilled = 0
local stomped = false

local function makeBar(adornee: BasePart)
	local g = Instance.new("BillboardGui")
	g.Name = "OrderBar"
	g.Size = UDim2.fromOffset(340, 74)
	g.StudsOffsetWorldSpace = Vector3.new(0, 14 * SCALE * 0.5, 0)
	g.AlwaysOnTop = true
	g.LightInfluence = 0
	g.MaxDistance = 420
	g.Adornee = adornee
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.5)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = WHITE
	title.TextStrokeColor3 = INK
	title.TextStrokeTransparency = 0
	title.Text = "THE GREAT YETI'S ORDER"
	title.Parent = g
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 0.42)
	back.Position = UDim2.fromScale(0, 0.55)
	back.BackgroundColor3 = hex("#FFF8EC")
	back.Parent = g
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0.5, 0)
	bc.Parent = back
	local bs = Instance.new("UIStroke")
	bs.Color = INK
	bs.Thickness = 3
	bs.Parent = back
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(0, 1)
	f.BackgroundColor3 = hex("#F2A33A")
	f.Parent = back
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(0.5, 0)
	fc.Parent = f
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.TextColor3 = INK
	l.ZIndex = 2
	l.Parent = back
	g.Parent = adornee
	fill, label = f, l
end

local function makeYeti(o: any)
	local zone = Zones.ById[o.zone]
	local y = if zone then zone.center.y else 0
	local pos = Vector3.new(o.x, y, o.z)
	-- Face the zone's entrance side (toward the hub), where chefs come from.
	local toward = Vector3.new(-o.x, 0, -o.z)
	if toward.Magnitude < 1 then
		toward = Vector3.new(0, 0, 1)
	end
	base = CFrame.lookAt(pos, pos + toward.Unit)
	local m = YetiModel.build(SCALE, "#FFFFFF", zone and zone.accent or "#9FD3F0")
	m.Name = "GreatYeti"
	m:PivotTo(base + Vector3.new(0, 90, 0))
	-- A chef's toque so it reads as the "boss" Yeti at a glance.
	local head = m:FindFirstChild("Head") :: BasePart
	for i = 0, 2 do
		local puff = Instance.new("Part")
		puff.Shape = Enum.PartType.Ball
		puff.Size = Vector3.new(2.2, 2, 2.2) * SCALE
		puff.CFrame = head.CFrame * CFrame.new((i - 1) * 1.3 * SCALE, 3.6 * SCALE, 0)
		puff.Color = WHITE
		puff.Anchored = true
		puff.CanCollide = false
		puff.CanQuery = false
		puff.CanTouch = false
		puff.Parent = m
	end
	local band = Instance.new("Part")
	band.Shape = Enum.PartType.Cylinder
	band.Size = Vector3.new(1.4 * SCALE, 4.2 * SCALE, 4.2 * SCALE)
	band.CFrame = head.CFrame * CFrame.new(0, 2.7 * SCALE, 0) * CFrame.Angles(0, 0, math.rad(90))
	band.Color = WHITE
	band.Anchored = true
	band.CanCollide = false
	band.CanQuery = false
	band.CanTouch = false
	band.Parent = m
	m.Parent = workspace
	yeti = m
	mouth = m:FindFirstChild("Mouth") :: BasePart?
	makeBar(head)
	dropT = 0
	stomped = false
end

local function clear()
	if yeti then
		yeti:Destroy()
	end
	yeti, mouth, fill, label = nil, nil, nil, nil
	shownFor = nil
end

local function near(pos: Vector3, radius: number): boolean
	local root = C.Effects:LocalRoot()
	return root ~= nil and (root.CFrame.Position - pos).Magnitude < radius
end

-- Filled: the Yeti jumps for joy in a shower of snow and syrup, then vanishes in a puff.
local function celebrate()
	local m = yeti
	if not m then
		return
	end
	local pos = base.Position
	if near(pos, 180) then
		C.Effects:Puff(pos + Vector3.new(0, 10, 0), 3, 30)
		for _ = 1, 4 do
			C.Effects:Crumbs(
				pos + Vector3.new(math.random(-8, 8), math.random(6, 18), math.random(-8, 8)),
				hex("#F2A33A"),
				20,
				2
			)
		end
		C.Effects:Pop(pos + Vector3.new(0, 30, 0), "SNOW DAY!", hex("#5CC8F0"), 2.6, -6)
		C.Effects:Punch(1)
		C.LightingFX:Flash(0.8)
		C.Audio:Play("Order", { pitch = 1.3 })
	end
	yeti = nil
	shownFor = nil
	task.spawn(function()
		for k = 1, 3 do
			for i = 0, 10 do
				local h = math.sin(i / 10 * math.pi) * 6
				m:PivotTo(base * CFrame.new(0, h, 0) * CFrame.Angles(0, k * math.pi * 2 * i / 30, 0))
				task.wait(1 / 30)
			end
		end
		m:Destroy()
	end)
end

-- Not filled in time: the Yeti turns around and shuffles off, fading away.
local function wanderOff()
	local m = yeti
	if not m then
		return
	end
	yeti = nil
	shownFor = nil
	local from = base * CFrame.Angles(0, math.pi, 0)
	task.spawn(function()
		local parts = {}
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(parts, d)
			end
		end
		for i = 0, 45 do
			local a = i / 45
			m:PivotTo(from * CFrame.new(0, math.abs(math.sin(i * 0.5)) * 0.8, -a * 30))
			for _, p in parts do
				p.Transparency = a
			end
			task.wait(1 / 30)
		end
		m:Destroy()
	end)
end

local function apply(o: any)
	if o.active then
		if shownFor ~= o.zone then
			clear()
			makeYeti(o)
			shownFor = o.zone
			lastFilled = o.filled
		end
		if o.filled > lastFilled then
			chomp = 1
			if near(base.Position, 120) then
				C.Audio:Play("Chomp", { pitch = 0.7 })
			end
		end
		lastFilled = o.filled
	elseif yeti then
		-- Inactive: filled if a Snow Day just started, otherwise it wandered off.
		if (o.snowEndsAt or 0) > workspace:GetServerTimeNow() + 1 then
			celebrate()
		else
			wanderOff()
		end
	end
end

function OrderRenderer:Init(controllers)
	C = controllers
end

function OrderRenderer:Start()
	C.State.OrderChanged:Connect(apply)
	apply(C.State.order)
	RunService.RenderStepped:Connect(function(dt)
		local o = C.State.order
		local m = yeti
		if not m or not o.active then
			return
		end
		local t = os.clock()
		if dropT < 1 then
			-- Falls from the sky and lands with a thump.
			dropT = math.min(dropT + dt / 1.1, 1)
			local h = 90 * (1 - dropT) ^ 2
			m:PivotTo(base + Vector3.new(0, h, 0))
			if dropT >= 1 and not stomped then
				stomped = true
				if near(base.Position, 200) then
					C.Effects:Puff(base.Position + Vector3.new(0, 2, 0), 3, 24)
					C.Effects:Punch(1.2)
					C.Audio:Play("Stomp", { pitch = 0.6 })
				end
			end
		else
			local breathe = math.sin(t * 1.3) * 0.25
			m:PivotTo(base * CFrame.new(0, breathe, 0) * CFrame.Angles(0, math.sin(t * 0.5) * 0.08, 0))
		end
		chomp *= math.exp(-dt * 6)
		local mo = mouth
		if mo then
			local by = (mo:GetAttribute("BaseY") :: number?) or 0.5
			local open = by * (1 + 3 * math.abs(math.sin(chomp * 10)) * chomp)
			mo.Size = Vector3.new(mo.Size.X, open, mo.Size.Z)
		end
		if fill and label then
			local frac = math.clamp(o.filled / math.max(o.target, 1), 0, 1)
			fill.Size = UDim2.fromScale(frac, 1)
			local left = math.max(0, math.floor((o.endsAt or 0) - workspace:GetServerTimeNow()))
			label.Text = string.format("%d / %d pancakes  ·  %ds", o.filled, o.target, left)
		end
	end)
end

-- Where served pancakes fly to (the Great Yeti's mouth), or nil when no Order is up.
function OrderRenderer:MouthPosition(): Vector3?
	local mo = mouth
	return if mo and yeti then mo.Position else nil
end

-- The Great Yeti's plaza position, or nil.
function OrderRenderer:Position(): Vector3?
	return if yeti then base.Position else nil
end

return OrderRenderer
